import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/weather_config.dart';

/// Service to fetch atmospheric pressure data from meteorological stations
class WeatherStationService {
  static const String _openWeatherMapBaseUrl =
      'https://api.openweathermap.org/data/2.5';
  static const String _weatherApiBaseUrl = 'https://api.weatherapi.com/v1';

  // Cache for weather data to avoid excessive API calls
  static final Map<String, WeatherData> _weatherCache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheValidity = Duration(minutes: 30);

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
      final altitude = _calculateAltitudeFromPressure(weatherData.pressure);
      final floor = _calculateFloorFromAltitude(altitude);

      // Calculate confidence based on data quality and recency
      final confidence = _calculateWeatherConfidence(weatherData);

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
    if (_isCacheValid() && _weatherCache.containsKey(cacheKey)) {
      return _weatherCache[cacheKey];
    }

    // Try OpenWeatherMap first
    try {
      final weatherData = await _getOpenWeatherMapData(latitude, longitude);
      if (weatherData != null) {
        _updateCache(cacheKey, weatherData);
        return weatherData;
      }
    } catch (e) {
      dev.log('OpenWeatherMap failed: $e');
    }

    // Try WeatherAPI as fallback
    try {
      final weatherData = await _getWeatherApiData(latitude, longitude);
      if (weatherData != null) {
        _updateCache(cacheKey, weatherData);
        return weatherData;
      }
    } catch (e) {
      dev.log('WeatherAPI failed: $e');
    }

    // Try free weather service as last resort
    try {
      final weatherData = await _getFreeWeatherData(latitude, longitude);
      if (weatherData != null) {
        _updateCache(cacheKey, weatherData);
        return weatherData;
      }
    } catch (e) {
      dev.log('Free weather service failed: $e');
    }

    return null;
  }

  /// Fetch data from OpenWeatherMap API
  static Future<WeatherData?> _getOpenWeatherMapData(
    double latitude,
    double longitude,
  ) async {
    if (WeatherConfig.openWeatherMapApiKey ==
        'YOUR_OPENWEATHERMAP_API_KEY_HERE') {
      dev.log('OpenWeatherMap API key not configured');
      return null;
    }

    final url = Uri.parse(
      '$_openWeatherMapBaseUrl/weather?lat=$latitude&lon=$longitude&appid=${WeatherConfig.openWeatherMapApiKey}&units=metric',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      dev.log('OpenWeatherMap data +++++++++++++++++++++++++++++++++++++++++ : $data');
      return WeatherData(
        pressure: (data['main']['pressure'] as num).toDouble(), // hPa
        temperature: (data['main']['temp'] as num).toDouble(),
        humidity: (data['main']['humidity'] as num).toDouble(),
        timestamp: DateTime.now(),
        source: 'OpenWeatherMap',
      );
    }

    return null;
  }

  /// Fetch data from WeatherAPI
  static Future<WeatherData?> _getWeatherApiData(
    double latitude,
    double longitude,
  ) async {
    if (WeatherConfig.weatherApiKey == 'YOUR_WEATHERAPI_KEY_HERE') {
      dev.log('WeatherAPI key not configured');
      return null;
    }

    final url = Uri.parse(
      '$_weatherApiBaseUrl/current.json?key=${WeatherConfig.weatherApiKey}&q=$latitude,$longitude&aqi=no',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      dev.log('WeatherAPI data +++++++++++++++++++++++++++++++++++++++++ : $data');
      return WeatherData(
        pressure: (data['current']['pressure_mb'] as num).toDouble(), // hPa
        temperature: (data['current']['temp_c'] as num).toDouble(),
        humidity: (data['current']['humidity'] as num).toDouble(),
        timestamp: DateTime.now(),
        source: 'WeatherAPI',
      );
    }

    return null;
  }

  /// Fetch data from free weather service (no API key required)
  static Future<WeatherData?> _getFreeWeatherData(
    double latitude,
    double longitude,
  ) async {
    // Using a free weather service that doesn't require API key
    // This is a simplified example - in practice, you might use a different service
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&hourly=surface_pressure',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      dev.log('Open-Meteo data +++++++++++++++++++++++++++++++++++++++++ : $data');
      final current = data['current_weather'];
      final hourly = data['hourly'];

      if (current != null && hourly != null) {
        // Get the most recent pressure reading
        final pressures = hourly['surface_pressure'] as List<dynamic>?;
        final pressure = pressures?.isNotEmpty == true
            ? (pressures?.first as num?)?.toDouble() ?? 1013.25
            : 1013.25; // Default sea level pressure

        dev.log('Open-Meteo data +++++++++++++++++++++++++++++++++++++++++ : $pressure');

        return WeatherData(
          pressure: pressure,
          temperature: (current['temperature'] as num).toDouble(),
          humidity: 50.0, // Not available in this API
          timestamp: DateTime.now(),
          source: 'Open-Meteo',
        );
      }
    }

    return null;
  }

  /// Calculate altitude from atmospheric pressure using barometric formula
  static double _calculateAltitudeFromPressure(double pressure) {
    const double seaLevelPressure = 1013.25; // hPa
    const double temperature = 15.0; // °C (standard temperature)
    const double lapseRate = 0.0065; // K/m

    // Barometric formula: h = (T0 / L) * (1 - (P / P0)^(R * L / (g * M)))
    // Simplified version for approximate altitude calculation
    const double R = 8.31447; // Universal gas constant
    const double g = 9.80665; // Gravitational acceleration
    const double M = 0.0289644; // Molar mass of dry air

    final double altitude =
        (temperature / lapseRate) *
        (1 - pow(pressure / seaLevelPressure, (R * lapseRate) / (g * M)));

    return altitude;
  }

  /// Calculate floor number from altitude
  static int _calculateFloorFromAltitude(
    double altitude, {
    double floorHeight = 3.5,
  }) {
    return (altitude / floorHeight).round();
  }

  /// Calculate confidence based on weather data quality
  static double _calculateWeatherConfidence(WeatherData weatherData) {
    double confidence = 0.7; // Base confidence for weather data

    // Adjust based on data recency
    final age = DateTime.now().difference(weatherData.timestamp);
    if (age.inMinutes < 15) {
      confidence += 0.2; // Very recent data
    } else if (age.inMinutes < 60) {
      confidence += 0.1; // Recent data
    } else {
      confidence -= 0.1; // Old data
    }

    // Adjust based on pressure value reasonableness
    if (weatherData.pressure >= 950 && weatherData.pressure <= 1050) {
      confidence += 0.1; // Reasonable pressure range
    } else {
      confidence -= 0.2; // Unusual pressure
    }

    // Adjust based on data source reliability
    switch (weatherData.source) {
      case 'OpenWeatherMap':
        confidence += 0.1;
        break;
      case 'WeatherAPI':
        confidence += 0.05;
        break;
      case 'Open-Meteo':
        confidence += 0.0;
        break;
    }

    return (confidence * 100).round() / 100; // Round to 2 decimal places
  }

  /// Check if cached data is still valid
  static bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidity;
  }

  /// Update weather data cache
  static void _updateCache(String key, WeatherData data) {
    _weatherCache[key] = data;
    _lastCacheUpdate = DateTime.now();

    // Limit cache size
    if (_weatherCache.length > 10) {
      final oldestKey = _weatherCache.keys.first;
      _weatherCache.remove(oldestKey);
    }
  }

  /// Clear weather data cache
  static void clearCache() {
    _weatherCache.clear();
    _lastCacheUpdate = null;
  }

  /// Get cached weather data for debugging
  static Map<String, WeatherData> getCachedData() => Map.from(_weatherCache);

  /// Check if weather service is available (has valid API keys or free service)
  static bool isAvailable() {
    return WeatherConfig.isConfigured;
  }

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

      dev.log(
        'Testing weather service with location: $testLatitude, $testLongitude',
      );

      // Test OpenWeatherMap
      if (WeatherConfig.openWeatherMapApiKey !=
          'YOUR_OPENWEATHERMAP_API_KEY_HERE') {
        testResult['services_tested'].add('OpenWeatherMap');
        try {
          final data = await _getOpenWeatherMapData(
            testLatitude,
            testLongitude,
          );
          if (data != null) {
            testResult['successful_services'].add('OpenWeatherMap');
            testResult['openweathermap_data'] = data.toString();
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
          final data = await _getWeatherApiData(testLatitude, testLongitude);
          if (data != null) {
            testResult['successful_services'].add('WeatherAPI');
            testResult['weatherapi_data'] = data.toString();
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
        final data = await _getFreeWeatherData(testLatitude, testLongitude);
        if (data != null) {
          testResult['successful_services'].add('Open-Meteo');
          testResult['openmeteo_data'] = data.toString();
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
        final result = await detectFloor(
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
      testResult['cache_status'] = {
        'cached_locations': _weatherCache.length,
        'last_update': _lastCacheUpdate?.toIso8601String(),
        'cache_valid': _isCacheValid(),
      };
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
      'cache_info': {
        'cached_locations': _weatherCache.length,
        'last_update': _lastCacheUpdate?.toIso8601String(),
        'cache_valid': _isCacheValid(),
      },
    };
  }
}

/// Weather data model
class WeatherData {
  final double pressure; // in hPa
  final double temperature; // in Celsius
  final double humidity; // in percentage
  final DateTime timestamp;
  final String source;

  WeatherData({
    required this.pressure,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    required this.source,
  });

  @override
  String toString() {
    return 'WeatherData(pressure: ${pressure}hPa, temp: $temperature°C, humidity: $humidity%, source: $source, time: $timestamp)';
  }
}
