import 'dart:async';
import 'dart:math';
import 'package:learning/services/gps_altitude_service.dart';
import 'package:learning/services/barometric_altimeter/weather_barometric_altimeter_service.dart';
import 'package:learning/services/barometer/barometer_calculations.dart';
import 'package:learning/utils/app_logger.dart';

/// Service for dynamic sea level pressure calibration
class PressureCalibrationService {
  static DateTime? _lastCalibrationTime;
  static double? _calibratedSeaLevelPressure;
  static const Duration _calibrationInterval = Duration(hours: 1);

  /// Perform automatic calibration using weather data and GPS
  static Future<CalibrationResult> performAutoCalibration() async {
    try {
      // Get current location
      final location = await GPSAltitudeService.getCurrentLocation();
      if (location?.latitude == null || location?.longitude == null) {
        return CalibrationResult(
          success: false,
          message: 'GPS location not available for calibration',
          seaLevelPressure: null,
        );
      }

      // Get current weather pressure at location
      final weatherPressure =
          await WeatherBarometricAltimeterService.getCurrentPressure();
      if (weatherPressure == null) {
        return CalibrationResult(
          success: false,
          message: 'Weather pressure data not available',
          seaLevelPressure: null,
        );
      }

      // If GPS altitude is available, use it for calibration
      if (location!.altitude != null && location.altitude! > -100) {
        // Calculate sea level pressure from GPS altitude and weather pressure
        final calibratedPressure = _calculateSeaLevelPressureFromAltitude(
          location.altitude!,
          weatherPressure,
        );

        // Apply calibration to both systems
        BarometerCalculations.setSeaLevelPressure(calibratedPressure);
        _calibratedSeaLevelPressure = calibratedPressure;
        _lastCalibrationTime = DateTime.now();

        AppLogger.info(
          'Auto-calibration successful: ${calibratedPressure.toStringAsFixed(2)} hPa',
        );

        return CalibrationResult(
          success: true,
          message:
              'Calibrated using GPS altitude (${location.altitude!.toStringAsFixed(1)}m) and weather data',
          seaLevelPressure: calibratedPressure,
        );
      } else {
        // Use weather station pressure directly as sea level reference
        BarometerCalculations.setSeaLevelPressure(weatherPressure);
        _calibratedSeaLevelPressure = weatherPressure;
        _lastCalibrationTime = DateTime.now();

        AppLogger.info(
          'Calibrated using weather station pressure: ${weatherPressure.toStringAsFixed(2)} hPa',
        );

        return CalibrationResult(
          success: true,
          message: 'Calibrated using weather station pressure',
          seaLevelPressure: weatherPressure,
        );
      }
    } catch (e) {
      AppLogger.error('Auto-calibration failed: $e');
      return CalibrationResult(
        success: false,
        message: 'Calibration failed: ${e.toString()}',
        seaLevelPressure: null,
      );
    }
  }

  /// Manual calibration at known altitude
  static CalibrationResult performManualCalibration(
    double knownAltitude,
    double currentPressure,
  ) {
    try {
      // Calculate sea level pressure from known altitude and current pressure
      final seaLevelPressure = _calculateSeaLevelPressureFromAltitude(
        knownAltitude,
        currentPressure,
      );

      // Apply calibration to both systems
      BarometerCalculations.setSeaLevelPressure(seaLevelPressure);
      _calibratedSeaLevelPressure = seaLevelPressure;
      _lastCalibrationTime = DateTime.now();

      AppLogger.info(
        'Manual calibration successful: ${seaLevelPressure.toStringAsFixed(2)} hPa',
      );

      return CalibrationResult(
        success: true,
        message:
            'Manually calibrated at ${knownAltitude.toStringAsFixed(1)}m altitude',
        seaLevelPressure: seaLevelPressure,
      );
    } catch (e) {
      AppLogger.error('Manual calibration failed: $e');
      return CalibrationResult(
        success: false,
        message: 'Manual calibration failed: ${e.toString()}',
        seaLevelPressure: null,
      );
    }
  }

  /// Check if calibration is needed
  static bool isCalibrationNeeded() {
    if (_lastCalibrationTime == null) return true;

    final timeSinceCalibration = DateTime.now().difference(
      _lastCalibrationTime!,
    );
    return timeSinceCalibration > _calibrationInterval;
  }

  /// Get calibration status
  static CalibrationStatus getCalibrationStatus() {
    return CalibrationStatus(
      isCalibrated: _calibratedSeaLevelPressure != null,
      lastCalibrationTime: _lastCalibrationTime,
      calibratedSeaLevelPressure: _calibratedSeaLevelPressure,
      isCalibrationNeeded: isCalibrationNeeded(),
    );
  }

  /// Reset calibration to default values
  static void resetCalibration() {
    BarometerCalculations.setSeaLevelPressure(1013.25);
    _calibratedSeaLevelPressure = null;
    _lastCalibrationTime = null;
    AppLogger.info(
      'Calibration reset to default (1013.25 hPa) - both systems synchronized',
    );
  }

  /// Calculate sea level pressure from altitude and current pressure
  static double _calculateSeaLevelPressureFromAltitude(
    double altitude,
    double currentPressure, {
    double temperature = 15.0,
  }) {
    // Use ISA formula to calculate sea level pressure
    const double lapseRate = 0.0065; // K/m
    const double R = 8.31447; // Universal gas constant J/(mol·K)
    const double g = 9.80665; // Gravitational acceleration m/s²
    const double M = 0.0289644; // Molar mass of dry air kg/mol

    final double tempKelvin = temperature + 273.15;

    // Reverse ISA formula: P0 = P / (1 - (L * h) / T)^((g * M) / (R * L))
    const double exponent = (g * M) / (R * lapseRate);
    final double base = 1 - (lapseRate * altitude) / tempKelvin;

    if (base <= 0) {
      // Altitude too high for ISA model, use approximation
      return currentPressure * (1 + altitude / 8400); // Simple approximation
    }

    final double seaLevelPressure = currentPressure / pow(base, exponent);

    return seaLevelPressure;
  }
}

/// Result of a calibration attempt
class CalibrationResult {
  final bool success;
  final String message;
  final double? seaLevelPressure;

  CalibrationResult({
    required this.success,
    required this.message,
    required this.seaLevelPressure,
  });

  @override
  String toString() {
    return 'CalibrationResult(success: $success, message: $message, pressure: $seaLevelPressure)';
  }
}

/// Current calibration status
class CalibrationStatus {
  final bool isCalibrated;
  final DateTime? lastCalibrationTime;
  final double? calibratedSeaLevelPressure;
  final bool isCalibrationNeeded;

  CalibrationStatus({
    required this.isCalibrated,
    required this.lastCalibrationTime,
    required this.calibratedSeaLevelPressure,
    required this.isCalibrationNeeded,
  });

  String get statusMessage {
    if (!isCalibrated) {
      return 'Not calibrated - using standard pressure (1013.25 hPa)';
    }

    final pressure = calibratedSeaLevelPressure!.toStringAsFixed(2);
    final time = lastCalibrationTime!;
    final age = DateTime.now().difference(time);

    if (age.inMinutes < 60) {
      return 'Calibrated ${age.inMinutes}m ago ($pressure hPa)';
    } else if (age.inHours < 24) {
      return 'Calibrated ${age.inHours}h ago ($pressure hPa)';
    } else {
      return 'Calibrated ${age.inDays}d ago ($pressure hPa)';
    }
  }

  @override
  String toString() {
    return 'CalibrationStatus(calibrated: $isCalibrated, needsCalibration: $isCalibrationNeeded, pressure: $calibratedSeaLevelPressure)';
  }
}
