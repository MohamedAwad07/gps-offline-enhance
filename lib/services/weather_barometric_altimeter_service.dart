import 'dart:async';
import 'dart:convert';
import 'dart:math';
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

  /// Get current pressure reading from weather service with offline fallbacks
  static Future<double?> getCurrentPressure() async {
    try {
      // Get current location first
      final location = await GPSAltitudeService.getCurrentLocation();
      if (location?.latitude == null || location?.longitude == null) {
        // No GPS available - try cached pressure
        final cachedPressure = getCachedPressure();
        if (cachedPressure != null) {
          _currentService = 'Cached Pressure (Offline)';
          return cachedPressure;
        }
        _currentService = 'Default (1013.25 hPa)';
        return 1013.25;
      }

      // Try online services first
      final available = await isAvailable();
      if (available) {
        // Try to get pressure from OpenWeatherMap
        final pressure = await _getPressureFromOpenWeatherMap(
          location!.latitude!,
          location.longitude!,
        );

        if (pressure != null) {
          _cachePressure(pressure); // Cache for offline use
          _currentService = 'OpenWeatherMap';
          return pressure;
        }

        // Fallback to Open-Meteo if OpenWeatherMap fails
        final fallbackPressure = await _getPressureFromOpenMeteo(
          location.latitude!,
          location.longitude!,
        );

        if (fallbackPressure != null) {
          _cachePressure(fallbackPressure); // Cache for offline use
          _currentService = 'Open-Meteo';
          return fallbackPressure;
        }
      }

      // OFFLINE FALLBACKS

      // 1. Try cached pressure first
      final cachedPressure = getCachedPressure();
      if (cachedPressure != null) {
        _currentService = 'Cached Pressure (Offline)';
        return cachedPressure;
      }

      // 2. Calculate pressure from GPS altitude
      if (location?.altitude != null) {
        final gpsPressure = calculateSeaLevelPressureFromGPS(
          location!.altitude!,
        );
        _currentService = 'GPS-Based (Offline)';
        return gpsPressure;
      }

      // 3. Use standard atmospheric model
      final standardPressure = getStandardAtmosphericPressure(0); // Sea level
      _currentService = 'Standard Atmosphere (Offline)';
      return standardPressure;
    } catch (e) {
      // Final fallback to standard sea level pressure
      _currentService = 'Default (1013.25 hPa)';
      return 1013.25;
    }
  }

  static String _currentService = 'Unknown';

  // Pressure caching for offline use
  static double? _cachedPressure;
  static DateTime? _cacheTime;
  static const Duration _cacheValidity = Duration(hours: 6);

  /// Get the current weather service being used
  static String getCurrentService() {
    return _currentService;
  }

  /// Get cached pressure for offline use
  static double? getCachedPressure() {
    if (_cachedPressure == null || _cacheTime == null) return null;

    final age = DateTime.now().difference(_cacheTime!);
    if (age > _cacheValidity) return null;

    // Apply time-based decay (pressure changes slowly over time)
    final decayFactor = 1.0 - (age.inMinutes / _cacheValidity.inMinutes) * 0.1;
    return _cachedPressure! * decayFactor;
  }

  /// Cache pressure for offline use
  static void _cachePressure(double pressure) {
    _cachedPressure = pressure;
    _cacheTime = DateTime.now();
  }

  /// Calculate sea-level pressure from GPS altitude using standard atmospheric model
  static double calculateSeaLevelPressureFromGPS(
    double gpsAltitude, {
    double temperature = 15.0,
  }) {
    const double standardSeaLevelPressure = 1013.25; // hPa
    const double g = 9.80665; // m/s²
    const double M = 0.0289644; // kg/mol
    const double R = 8.31432; // J/(mol·K)

    final double tempKelvin = temperature + 273.15;

    // Barometric formula: P = P0 * exp(-g*M*h/(R*T))
    // Solving for P0: P0 = P * exp(g*M*h/(R*T))
    final double estimatedPressure =
        standardSeaLevelPressure * exp(-g * M * gpsAltitude / (R * tempKelvin));

    return estimatedPressure;
  }

  /// Get standard atmospheric pressure at given altitude
  static double getStandardAtmosphericPressure(double altitude) {
    // ISA model: P = 1013.25 * (1 - 0.0065 * h/288.15)^5.255
    return 1013.25 * pow(1 - 0.0065 * altitude / 288.15, 5.255);
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
