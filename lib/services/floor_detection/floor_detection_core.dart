import 'dart:async';
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/barometer/barometer_service.dart';
import 'package:learning/utils/app_logger.dart';

/// Core floor detection logic
class FloorDetectionCore {
  static final StreamController<FloorDetectionResult> _resultController =
      StreamController<FloorDetectionResult>.broadcast();
  static Timer? _detectionTimer;
  static bool _isMonitoring = false;

  /// Start comprehensive floor detection
  static Future<void> startFloorDetection({
    Duration interval = const Duration(seconds: 2),
  }) async {
    if (_isMonitoring) return;

    _isMonitoring = true;

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

  /// Perform single detection using all available methods
  static Future<FloorDetectionResult> detectFloor() async {
    AppLogger.info('Starting floor detection', source: 'FloorDetection');
    final results = <FloorDetectionResult>[];

    // Try barometer detection
    try {
      final barometerResult = await BarometerService.detectFloor();
      AppLogger.info(
        'Barometer result: Floor: ${barometerResult.floor}, Altitude: ${barometerResult.altitude.toStringAsFixed(2)}m, Confidence: ${(barometerResult.confidence * 100).toStringAsFixed(1)}%, Method: ${barometerResult.method}',
        source: 'Barometer',
      );
      if (barometerResult.error == null) {
        results.add(barometerResult);
      } else {
        AppLogger.error(
          'Barometer error: ${barometerResult.error}',
          source: 'Barometer',
        );
      }
    } catch (e) {
      AppLogger.error('Barometer exception: $e', source: 'Barometer');
    }

    //   // Try GPS detection
    //   try {
    //     final gpsResult = await GPSAltitudeService.detectFloor();
    //     AppLogger.info('GPS result: Floor: ${gpsResult.floor}, Altitude: ${gpsResult.altitude.toStringAsFixed(2)}m, Confidence: ${(gpsResult.confidence * 100).toStringAsFixed(1)}%, Method: ${gpsResult.method}', source: 'GPS');
    //     if (gpsResult.error == null) {
    //       results.add(gpsResult);
    //     } else {
    //       AppLogger.error('GPS error: ${gpsResult.error}', source: 'GPS');
    //     }
    //   } catch (e) {
    //     // GPS detection failed
    //     AppLogger.error('GPS exception: $e', source: 'GPS');
    //   }
    //   try {
    //     final wifiResult = await WiFiFloorDetection.detectFloor();
    //     AppLogger.info('WiFi result: Floor: ${wifiResult.floor}, Altitude: ${wifiResult.altitude.toStringAsFixed(2)}m, Confidence: ${(wifiResult.confidence * 100).toStringAsFixed(1)}%, Method: ${wifiResult.method}', source: 'WiFi');
    //     if (wifiResult.error == null) {
    //       results.add(wifiResult);
    //     } else {
    //       AppLogger.error('WiFi error: ${wifiResult.error}', source: 'WiFi');
    //     }
    //   } catch (e) {
    //     // WiFi detection failed
    //     AppLogger.error('WiFi exception: $e', source: 'WiFi');
    //   }
    //   final combinedResult = _combineResults(results);
    //   AppLogger.info('Combined result: Floor: ${combinedResult.floor}, Altitude: ${combinedResult.altitude.toStringAsFixed(2)}m, Confidence: ${(combinedResult.confidence * 100).toStringAsFixed(1)}%, Method: ${combinedResult.method}', source: 'Combined');
    //   return combinedResult;
    // }
    return results.first;
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
    _resultController.close();
  }
}
