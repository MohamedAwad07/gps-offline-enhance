import 'package:learning/services/weather_config.dart';
import 'package:learning/services/weather_station/weather_api_clients.dart';
import 'package:learning/services/weather_station/weather_cache.dart';
import 'package:learning/services/weather_station/weather_floor_detection.dart';

/// Weather service testing and diagnostics
class WeatherTesting {
  /// Test weather service with current location
  static Future<Map<String, dynamic>> testWeatherService() async {
    final testResult = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'services_tested': <String>[],
      'successful_services': <String>[],
      'failed_services': <String>[],
      'final_result': null,
      'errors': <String>[],
    };

    try {
      // Test with a known location (Cairo, Egypt - based on your GPS logs)
      const double testLatitude = 30.31341586;
      const double testLongitude = 31.70383879;

      // Test OpenWeatherMap
      if (WeatherConfig.openWeatherMapApiKey !=
          'YOUR_OPENWEATHERMAP_API_KEY_HERE') {
        testResult['services_tested'].add('OpenWeatherMap');
        try {
          final data = await WeatherApiClients.getOpenWeatherMapData(
            testLatitude,
            testLongitude,
          );
          if (data != null) {
            testResult['successful_services'].add('OpenWeatherMap');
            testResult['openweathermap_data'] = data.toString();
            testResult['openweathermap_station'] =
                data.stationInfo?.toString() ?? 'No station info';
          } else {
            testResult['failed_services'].add('OpenWeatherMap');
            testResult['errors'].add('OpenWeatherMap returned null data');
          }
        } catch (e) {
          testResult['failed_services'].add('OpenWeatherMap');
          testResult['errors'].add('OpenWeatherMap error: $e');
        }
      }

      // Test WeatherAPI
      if (WeatherConfig.weatherApiKey != 'YOUR_WEATHERAPI_KEY_HERE') {
        testResult['services_tested'].add('WeatherAPI');
        try {
          final data = await WeatherApiClients.getWeatherApiData(
            testLatitude,
            testLongitude,
          );
          if (data != null) {
            testResult['successful_services'].add('WeatherAPI');
            testResult['weatherapi_data'] = data.toString();
            testResult['weatherapi_station'] =
                data.stationInfo?.toString() ?? 'No station info';
          } else {
            testResult['failed_services'].add('WeatherAPI');
            testResult['errors'].add('WeatherAPI returned null data');
          }
        } catch (e) {
          testResult['failed_services'].add('WeatherAPI');
          testResult['errors'].add('WeatherAPI error: $e');
        }
      }

      // Test free services
      testResult['services_tested'].add('Open-Meteo');
      try {
        final data = await WeatherApiClients.getFreeWeatherData(
          testLatitude,
          testLongitude,
        );
        if (data != null) {
          testResult['successful_services'].add('Open-Meteo');
          testResult['openmeteo_data'] = data.toString();
          testResult['openmeteo_station'] =
              data.stationInfo?.toString() ?? 'No station info';
        } else {
          testResult['failed_services'].add('Open-Meteo');
          testResult['errors'].add('Open-Meteo returned null data');
        }
      } catch (e) {
        testResult['failed_services'].add('Open-Meteo');
        testResult['errors'].add('Open-Meteo error: $e');
      }

      // Test the main detectFloor method
      try {
        final result = await WeatherFloorDetection.detectFloor(
          latitude: testLatitude,
          longitude: testLongitude,
        );
        testResult['final_result'] = {
          'floor': result.floor,
          'altitude': result.altitude,
          'confidence': result.confidence,
          'method': result.method,
          'error': result.error,
        };
        testResult['test_successful'] = result.error == null;
      } catch (e) {
        testResult['test_successful'] = false;
        testResult['errors'].add('Main detectFloor error: $e');
      }

      testResult['overall_success'] =
          testResult['successful_services'].isNotEmpty;
      testResult['cache_status'] = WeatherCache.getCacheStatus();
    } catch (e) {
      testResult['overall_success'] = false;
      testResult['errors'].add('Test setup error: $e');
    }

    return testResult;
  }

  /// Get detailed service status
  static Map<String, dynamic> getServiceStatus() {
    return {
      'is_configured': WeatherConfig.isConfigured,
      'available_services': WeatherConfig.availableServices,
      'openweathermap_configured':
          WeatherConfig.openWeatherMapApiKey !=
          'YOUR_OPENWEATHERMAP_API_KEY_HERE',
      'weatherapi_configured':
          WeatherConfig.weatherApiKey != 'YOUR_WEATHERAPI_KEY_HERE',
      'free_services_enabled':
          WeatherConfig.useOpenMeteo || WeatherConfig.useWttrIn,
      'cache_info': WeatherCache.getCacheStatus(),
    };
  }
}
