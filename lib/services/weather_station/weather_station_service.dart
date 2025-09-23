import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/weather_config.dart';
import 'package:learning/services/weather_station/weather_floor_detection.dart';
import 'package:learning/services/weather_station/weather_cache.dart';
import 'package:learning/services/weather_station/weather_testing.dart';

/// Service to fetch atmospheric pressure data from meteorological stations
class WeatherStationService {
  /// Get atmospheric pressure from the nearest meteorological station
  static Future<FloorDetectionResult> detectFloor({
    required double latitude,
    required double longitude,
  }) async {
    return WeatherFloorDetection.detectFloor(
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Clear weather data cache
  static void clearCache() {
    WeatherCache.clearCache();
  }

  /// Get cached weather data for debugging
  static Map<String, dynamic> getCachedData() =>
      WeatherCache.getCachedDataMap();

  /// Check if weather service is available (has valid API keys or free service)
  static bool isAvailable() {
    return WeatherConfig.isConfigured;
  }

  /// Test weather service with current location
  static Future<Map<String, dynamic>> testWeatherService() async {
    return WeatherTesting.testWeatherService();
  }

  /// Get detailed service status
  static Map<String, dynamic> getServiceStatus() {
    return WeatherTesting.getServiceStatus();
  }
}
