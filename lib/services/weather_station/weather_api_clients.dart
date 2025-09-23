import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:learning/services/weather_config.dart';
import 'package:learning/services/weather_station/weather_data_model.dart';

/// Weather API clients for different weather services
class WeatherApiClients {
  static const String _openWeatherMapBaseUrl =
      'https://api.openweathermap.org/data/2.5';
  static const String _weatherApiBaseUrl = 'https://api.weatherapi.com/v1';

  /// Fetch data from OpenWeatherMap API
  static Future<WeatherData?> getOpenWeatherMapData(
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
  static Future<WeatherData?> getWeatherApiData(
    double latitude,
    double longitude,
  ) async {
    if (WeatherConfig.weatherApiKey == 'YOUR_WEATHERAPI_KEY_HERE') {
      return null;
    }

    final url = Uri.parse(
      '$_weatherApiBaseUrl/current.json?key=${WeatherConfig.weatherApiKey}&q=$latitude,$longitude&aqi=no',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
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
  static Future<WeatherData?> getFreeWeatherData(
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
      final current = data['current_weather'];
      final hourly = data['hourly'];

      if (current != null && hourly != null) {
        // Get the most recent pressure reading
        final pressures = hourly['surface_pressure'] as List<dynamic>?;
        final pressure = pressures?.isNotEmpty == true
            ? (pressures?.first as num?)?.toDouble() ?? 1013.25
            : 1013.25; // Default sea level pressure

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
}
