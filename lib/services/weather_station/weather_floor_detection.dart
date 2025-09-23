import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/weather_station/weather_data_model.dart';
import 'package:learning/services/weather_station/weather_calculations.dart';
import 'package:learning/services/weather_station/weather_api_clients.dart';
import 'package:learning/services/weather_station/weather_cache.dart';

/// Weather-based floor detection service
class WeatherFloorDetection {
  /// Get atmospheric pressure from the nearest meteorological station
  static Future<FloorDetectionResult> detectFloor({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Try multiple weather services for better reliability
      final WeatherData? weatherData = await _getWeatherDataWithFallback(
        latitude,
        longitude,
      );

      if (weatherData == null) {
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'weather_station',
          error: 'Unable to fetch weather data from any service',
        );
      }

      // Calculate altitude from atmospheric pressure
      final altitude = WeatherCalculations.calculateAltitudeFromPressure(
        weatherData.pressure,
      );
      final floor = WeatherCalculations.calculateFloorFromAltitude(altitude);

      // Calculate confidence based on data quality and recency
      final confidence = WeatherCalculations.calculateWeatherConfidence(
        weatherData,
      );

      return FloorDetectionResult(
        floor: floor,
        altitude: altitude,
        confidence: confidence,
        method: 'weather_station',
        error: null,
      );
    } catch (e) {
      return FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'weather_station',
        error: 'Weather service error: ${e.toString()}',
      );
    }
  }

  /// Try multiple weather services with fallback
  static Future<WeatherData?> _getWeatherDataWithFallback(
    double latitude,
    double longitude,
  ) async {
    // Check cache first
    final cacheKey =
        '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';
    final cachedData = WeatherCache.getCachedData(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    // Try OpenWeatherMap first
    try {
      final weatherData = await WeatherApiClients.getOpenWeatherMapData(
        latitude,
        longitude,
      );
      if (weatherData != null) {
        WeatherCache.updateCache(cacheKey, weatherData);
        return weatherData;
      }
    } catch (e) {
      // OpenWeatherMap failed, continue to next service
    }

    // Try WeatherAPI as fallback
    try {
      final weatherData = await WeatherApiClients.getWeatherApiData(
        latitude,
        longitude,
      );
      if (weatherData != null) {
        WeatherCache.updateCache(cacheKey, weatherData);
        return weatherData;
      }
    } catch (e) {
      // WeatherAPI failed, continue to next service
    }

    // Try free weather service as last resort
    try {
      final weatherData = await WeatherApiClients.getFreeWeatherData(
        latitude,
        longitude,
      );
      if (weatherData != null) {
        WeatherCache.updateCache(cacheKey, weatherData);
        return weatherData;
      }
    } catch (e) {
      // Free weather service failed
    }

    return null;
  }
}
