import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/barometer/barometer_calculations.dart';
import 'package:learning/services/barometer/barometer_sensor_info.dart';
import 'package:learning/services/weather_station/weather_station_service.dart';
import 'package:learning/services/gps_altitude_service.dart';
import 'package:learning/utils/app_logger.dart';

/// Barometer-based floor detection
class BarometerFloorDetection {
  /// Get floor detection with confidence level
  static Future<FloorDetectionResult> detectFloor() async {
    try {
      // Check if barometer is available first
      final barometerAvailable = await BarometerSensorInfo.isAvailable();
      if (!barometerAvailable) {
        // Try weather station service as fallback
        AppLogger.error('Barometer not available');
        return await _tryWeatherStationFallback();
      }

      final pressure = await BarometerSensorInfo.getCurrentPressure();
      if (pressure == null) {
        // Try weather station service as fallback
        AppLogger.error('Barometer pressure not available');
        return await _tryWeatherStationFallback();
      }

      final altitude = BarometerCalculations.calculateAltitude(pressure);
      final floor = BarometerCalculations.calculateFloor(altitude);

      // Calculate confidence based on pressure reading quality
      double confidence = 0.9; // Base confidence for barometer

      // Adjust confidence based on pressure value (should be reasonable atmospheric pressure)
      if (pressure < 800 || pressure > 1200) {
        confidence = 0.3; // Low confidence for unrealistic pressure values
      } else if (pressure < 900 || pressure > 1100) {
        confidence = 0.6; // Medium confidence for unusual but possible values
      }

      return FloorDetectionResult(
        floor: floor,
        altitude: altitude.toDouble(),
        confidence: confidence,
        method: 'barometer',
        error: null,
      );
    } catch (e) {
      // Try weather station service as fallback
      AppLogger.error('Barometer floor detection failed: $e');
      return await _tryWeatherStationFallback();
    }
  }

  /// Try weather station service as fallback when barometer is not available
  static Future<FloorDetectionResult> _tryWeatherStationFallback() async {
    try {
      // Check if weather service is available
      if (!WeatherStationService.isAvailable()) {
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'barometer',
          error:
              'Barometer sensor not available and weather service not configured',
        );
      }

      // Get current location for weather data
      final location = await GPSAltitudeService.getCurrentLocation();
      if (location?.latitude == null || location?.longitude == null) {
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'barometer',
          error:
              'Barometer not available and GPS location not available for weather data',
        );
      }

      // Get weather data and calculate floor
      final weatherResult = await WeatherStationService.detectFloor(
        latitude: location!.latitude!,
        longitude: location.longitude!,
      );

      // Update the method to indicate it's using weather data as barometer fallback
      return FloorDetectionResult(
        floor: weatherResult.floor,
        altitude: weatherResult.altitude,
        confidence:
            weatherResult.confidence *
            0.9,
        method: 'barometer (weather)',
        error: weatherResult.error,
      );
    } catch (e) {
      return FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'barometer',
        error:
            'Barometer not available and weather fallback failed: ${e.toString()}',
      );
    }
  }
}
