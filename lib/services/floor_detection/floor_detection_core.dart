import 'dart:async';
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/barometer/barometer_service.dart';
import 'package:learning/services/gps_altitude_service.dart';
import 'package:learning/services/weather_station/weather_station_service.dart';
import 'package:learning/services/filtering/altitude_kalman_filter.dart';
import 'package:learning/services/calibration/pressure_calibration_service.dart';
import 'package:learning/utils/app_logger.dart';

/// Core floor detection logic: barometer priority, weather service fallback (no sensor fusion)
class FloorDetectionCore {
  static final StreamController<FloorDetectionResult> _resultController =
      StreamController<FloorDetectionResult>.broadcast();
  static Timer? _detectionTimer;
  static bool _isMonitoring = false;
  static final AltitudeKalmanFilter _kalmanFilter = AltitudeKalmanFilter();

  /// Start comprehensive floor detection with auto-calibration
  static Future<void> startFloorDetection({
    Duration interval = const Duration(seconds: 10),
  }) async {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Perform auto-calibration if needed
    if (PressureCalibrationService.isCalibrationNeeded()) {
      AppLogger.info(
        'Performing auto-calibration...',
        source: 'FloorDetection',
      );
      final calibrationResult =
          await PressureCalibrationService.performAutoCalibration();
      if (calibrationResult.success) {
        AppLogger.info(
          'Auto-calibration successful: ${calibrationResult.message}',
          source: 'Calibration',
        );
      } else {
        AppLogger.warning(
          'Auto-calibration failed: ${calibrationResult.message}',
          source: 'Calibration',
        );
      }
    }

    // Initial detection
    await _performDetection();

    // Set up periodic detection
    _detectionTimer = Timer.periodic(interval, (_) async {
      await _performDetection();
    });
  }

  /// Stop floor detection
  static void stopFloorDetection() {
    _isMonitoring = false;
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  /// Get stream of floor detection results
  static Stream<FloorDetectionResult> get detectionStream =>
      _resultController.stream;

  /// Perform detection with BAROMETER PRIORITY - use barometer when available, weather service only when not
  static Future<FloorDetectionResult> detectFloor() async {
    AppLogger.info(
      'Starting floor detection: barometer priority, weather service fallback',
      source: 'FloorDetection',
    );

    // PRIORITY 1: Check for hardware barometer - if available, use ONLY barometer
    try {
      final barometerAvailable = await BarometerService.isAvailable();
      if (barometerAvailable) {
        AppLogger.info(
          'Hardware barometer detected - using BAROMETER ONLY mode',
          source: 'FloorDetection',
        );

        final barometerResult = await BarometerService.detectFloor();
        AppLogger.info(
          'Hardware barometer result: Floor: ${barometerResult.floor}, Altitude: ${barometerResult.altitude.toStringAsFixed(2)}m, Confidence: ${(barometerResult.confidence * 100).toStringAsFixed(1)}%, Method: ${barometerResult.method}',
          source: 'Barometer',
        );

        if (barometerResult.error == null) {
          // Apply Kalman filtering for smoothing
          final filteredResult = _applyKalmanFilter(barometerResult);

          AppLogger.info(
            '🎯 BAROMETER ONLY - Final result: Floor: ${filteredResult.floor}, Altitude: ${filteredResult.altitude.toStringAsFixed(2)}m, Confidence: ${(filteredResult.confidence * 100).toStringAsFixed(1)}%, Method: ${filteredResult.method}',
            source: 'Final',
          );

          return filteredResult;
        } else {
          AppLogger.error(
            'Hardware barometer error: ${barometerResult.error}',
            source: 'Barometer',
          );
        }
      } else {
        AppLogger.info(
          'Hardware barometer not available - using fallback methods',
          source: 'FloorDetection',
        );
      }
    } catch (e) {
      AppLogger.error('Hardware barometer exception: $e', source: 'Barometer');
    }

    // FALLBACK: Use WEATHER SERVICE ONLY when hardware barometer is not available
    AppLogger.info(
      'Using weather service only (no barometer available)',
      source: 'FloorDetection',
    );

    // Try weather station detection if GPS location is available
    try {
      final location = await GPSAltitudeService.getCurrentLocation();
      if (location?.latitude != null && location?.longitude != null) {
        final weatherResult = await WeatherStationService.detectFloor(
          latitude: location!.latitude!,
          longitude: location.longitude!,
        );
        AppLogger.info(
          'Weather result: Floor: ${weatherResult.floor}, Altitude: ${weatherResult.altitude.toStringAsFixed(2)}m, Confidence: ${(weatherResult.confidence * 100).toStringAsFixed(1)}%, Method: ${weatherResult.method}',
          source: 'Weather',
        );
        if (weatherResult.error == null) {
          // Apply Kalman filtering for smoothing
          final filteredResult = _applyKalmanFilter(weatherResult);

          AppLogger.info(
            '🌤️ WEATHER ONLY - Final result: Floor: ${filteredResult.floor}, Altitude: ${filteredResult.altitude.toStringAsFixed(2)}m, Confidence: ${(filteredResult.confidence * 100).toStringAsFixed(1)}%, Method: ${filteredResult.method}',
            source: 'Final',
          );

          return filteredResult;
        } else {
          AppLogger.error(
            'Weather error: ${weatherResult.error}',
            source: 'Weather',
          );
        }
      } else {
        AppLogger.error(
          'GPS location not available for weather service',
          source: 'Weather',
        );
      }
    } catch (e) {
      AppLogger.error('Weather exception: $e', source: 'Weather');
    }

    // If weather service also fails, return error result
    AppLogger.error(
      'All detection methods failed - no barometer and weather service unavailable',
      source: 'FloorDetection',
    );

    return FloorDetectionResult(
      floor: 0,
      altitude: 0,
      confidence: 0.0,
      method: 'weather_station',
      error:
          'No barometer available and weather service failed. Please check your internet connection and location services.',
    );
  }

  /// Apply Kalman filtering to smooth altitude measurements
  static FloorDetectionResult _applyKalmanFilter(FloorDetectionResult result) {
    if (result.error != null) return result;

    final filterResult = _kalmanFilter.update(
      result.altitude,
      result.confidence,
    );

    // Create new result with filtered altitude
    final filteredFloor = (filterResult.filteredAltitude / 3.5).round();

    return FloorDetectionResult(
      floor: filteredFloor,
      altitude: filterResult.filteredAltitude,
      confidence: filterResult.confidence,
      method: '${result.method} (filtered)',
      error: null,
    );
  }

  /// Perform detection and emit result
  static Future<void> _performDetection() async {
    try {
      final result = await detectFloor();
      _resultController.add(result);
      AppLogger.info('Background detection completed', source: 'Background');
    } catch (e) {
      final errorResult = FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'combined',
        error: e.toString(),
      );
      _resultController.add(errorResult);
      AppLogger.error('Background detection failed: $e', source: 'Background');
    }
  }

  /// Get current floor with fallback options
  static Future<FloorDetectionResult> getCurrentFloor() async {
    return await detectFloor();
  }

  /// Dispose resources
  static void dispose() {
    stopFloorDetection();
    _kalmanFilter.reset();
    _resultController.close();
  }
}
