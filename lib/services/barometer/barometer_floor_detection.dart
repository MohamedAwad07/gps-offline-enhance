import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/barometer/barometer_calculations.dart';
import 'package:learning/services/barometer/barometer_sensor_info.dart';
import 'package:learning/utils/app_logger.dart';

/// Barometer-based floor detection
class BarometerFloorDetection {
  /// Get floor detection with confidence level (HARDWARE BAROMETER ONLY)
  static Future<FloorDetectionResult> detectFloor() async {
    try {
      // Check if hardware barometer is available first
      final barometerAvailable = await BarometerSensorInfo.isAvailable();
      if (!barometerAvailable) {
        AppLogger.error('Hardware barometer not available');
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'barometer',
          error: 'Hardware barometer sensor not available on this device',
        );
      }

      final pressure = await BarometerSensorInfo.getCurrentPressure();
      if (pressure == null) {
        AppLogger.error('Hardware barometer pressure reading failed');
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'barometer',
          error: 'Failed to get pressure reading from hardware barometer',
        );
      }

      // ALWAYS use standard sea level pressure for hardware barometer (no calibration)
      const double standardSeaLevelPressure =
          1013.25; // Standard atmospheric pressure
      BarometerCalculations.setSeaLevelPressure(standardSeaLevelPressure);

      // Use standard calculation with temperature compensation
      final altitude = BarometerCalculations.calculateAltitude(
        pressure,
        temperature: 15.0,
      );
      final floor = BarometerCalculations.calculateFloor(altitude);

      // Calculate confidence based on pressure reading quality and calibration status
      double confidence = 0.95; // High base confidence for hardware barometer

      // Adjust confidence based on pressure value (should be reasonable atmospheric pressure)
      if (pressure < 800 || pressure > 1200) {
        confidence = 0.4; // Low confidence for unrealistic pressure values
        AppLogger.warning(
          'Unusual pressure reading: ${pressure.toStringAsFixed(1)} hPa',
          source: 'Barometer',
        );
      } else if (pressure < 900 || pressure > 1100) {
        confidence = 0.7; // Medium confidence for unusual but possible values
        AppLogger.info(
          'Pressure reading within acceptable range: ${pressure.toStringAsFixed(1)} hPa',
          source: 'Barometer',
        );
      } else {
        AppLogger.info(
          'Excellent pressure reading: ${pressure.toStringAsFixed(1)} hPa',
          source: 'Barometer',
        );
      }

      // No calibration boost for hardware barometer (uses standard pressure)

      AppLogger.info(
        'Hardware barometer detection: Floor $floor, Altitude ${altitude.toStringAsFixed(2)}m, Pressure ${pressure.toStringAsFixed(1)} hPa, Confidence ${(confidence * 100).toStringAsFixed(1)}%',
        source: 'Barometer',
      );

      return FloorDetectionResult(
        floor: floor,
        altitude: altitude,
        confidence: confidence,
        method: 'barometer (hardware)',
        error: null,
      );
    } catch (e) {
      AppLogger.error(
        'Hardware barometer floor detection failed: $e',
        source: 'Barometer',
      );
      return FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'barometer',
        error: 'Hardware barometer error: ${e.toString()}',
      );
    }
  }
}
