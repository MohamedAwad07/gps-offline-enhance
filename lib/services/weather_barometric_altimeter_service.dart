import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:learning/providers/barometric_altimeter_provider.dart';
import 'package:learning/services/gps_altitude_service.dart';
import 'package:learning/services/weather_config.dart';

class WeatherBarometricAltimeterService {
  static BarometricAltimeterProvider? _provider;
  static bool _isInitialized = false;
  static Timer? _updateTimer;

  /// Initialize the service with a provider
  static void initialize(BarometricAltimeterProvider provider) {
    _provider = provider;
    _isInitialized = true;
  }

  /// Check if weather service is available (always true as it uses internet)
  static Future<bool> isAvailable() async {
    try {
      // Check if GPS is available for location
      final gpsAvailable = await GPSAltitudeService.isGPSAvailable();
      if (!gpsAvailable) {
        return false;
      }

      // Try to get a test pressure reading
      final location = await GPSAltitudeService.getCurrentLocation();
      if (location?.latitude == null || location?.longitude == null) {
        return false;
      }

      // Test weather service availability by trying to get pressure
      final pressure = await _getPressureFromOpenWeatherMap(
        location!.latitude!,
        location.longitude!,
      );
      return pressure != null;
    } catch (e) {
      return false;
    }
  }

  /// Start monitoring atmospheric pressure from weather services
  static Future<bool> startMonitoring() async {
    if (!_isInitialized || _provider == null) {
      throw Exception('Service not initialized. Call initialize() first.');
    }

    try {
      // Check if weather service is available
      final available = await isAvailable();
      if (!available) {
        _provider!.setStatus(
          'Weather service not available - GPS or internet required',
        );
        return false;
      }

      // This service now only provides pressure data
      // The actual monitoring is handled by BarometricAltimeterService

      _provider!.setMonitoringStatus(true);
      _provider!.setStatus('Monitoring pressure from weather services');
      return true;
    } catch (e) {
      _provider!.setStatus('Failed to start weather monitoring: $e');
      return false;
    }
  }

  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    _updateTimer?.cancel();
    _updateTimer = null;
    if (_provider != null) {
      _provider!.setMonitoringStatus(false);
      _provider!.setStatus('Stopped monitoring');
    }
  }

  /// Get current pressure reading from weather service
  static Future<double?> getCurrentPressure() async {
    try {
      final available = await isAvailable();
      if (!available) return null;

      // Get current location
      final location = await GPSAltitudeService.getCurrentLocation();
      if (location?.latitude == null || location?.longitude == null) {
        return null;
      }

      // Try to get pressure from OpenWeatherMap
      final pressure = await _getPressureFromOpenWeatherMap(
        location!.latitude!,
        location.longitude!,
      );

      if (pressure != null) {
        _currentService = 'OpenWeatherMap';
        return pressure;
      }

      // Fallback to Open-Meteo if OpenWeatherMap fails
      final fallbackPressure = await _getPressureFromOpenMeteo(
        location.latitude!,
        location.longitude!,
      );

      if (fallbackPressure != null) {
        _currentService = 'Open-Meteo';
        return fallbackPressure;
      }

      // Final fallback to standard sea level pressure
      _currentService = 'Default (1013.25 hPa)';
      return 1013.25;
    } catch (e) {
      _currentService = 'Default (1013.25 hPa)';
      return 1013.25; // Fallback to standard sea level pressure
    }
  }

  static String _currentService = 'Unknown';

  /// Get the current weather service being used
  static String getCurrentService() {
    return _currentService;
  }

  /// Get pressure from OpenWeatherMap API
  static Future<double?> _getPressureFromOpenWeatherMap(
    double latitude,
    double longitude,
  ) async {
    try {
      if (WeatherConfig.openWeatherMapApiKey ==
          'YOUR_OPENWEATHERMAP_API_KEY_HERE') {
        return null; // API key not configured
      }

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=${WeatherConfig.openWeatherMapApiKey}&units=metric',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final main = data['main'];

        if (main != null && main['pressure'] != null) {
          return (main['pressure'] as num).toDouble(); // Pressure in hPa
        }
      }
    } catch (e) {
      // Ignore errors and return null
    }
    return null;
  }

  /// Get pressure from Open-Meteo API (fallback, free, no API key required)
  static Future<double?> _getPressureFromOpenMeteo(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&hourly=surface_pressure',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hourly = data['hourly'];

        if (hourly != null) {
          final pressures = hourly['surface_pressure'] as List<dynamic>?;
          if (pressures?.isNotEmpty == true) {
            return (pressures!.first as num).toDouble();
          }
        }
      }
    } catch (e) {
      // Ignore errors and return null
    }
    return null;
  }

  /// Dispose resources
  static void dispose() {
    stopMonitoring();
    _provider = null;
    _isInitialized = false;
  }
}
