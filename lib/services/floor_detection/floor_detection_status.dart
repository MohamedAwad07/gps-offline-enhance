import 'package:learning/services/barometer/barometer_service.dart';
import 'package:learning/services/gps_altitude_service.dart';
import 'package:learning/services/weather_station/weather_station_service.dart';

/// Floor detection status and monitoring utilities
/// Note: When barometer is not available, only weather service is used (no sensor fusion)
class FloorDetectionStatus {
  /// Get detection method status
  static Future<Map<String, bool>> getMethodStatus() async {
    return {
      'barometer': await BarometerService.isAvailable(),
      'wifi': true, // WiFi is always available
      'gps': await GPSAltitudeService.isGPSAvailable(),
    };
  }

  /// Get detailed status information for debugging
  static Future<Map<String, dynamic>> getDetailedStatus() async {
    final status = <String, dynamic>{};

    // Barometer status
    try {
      final barometerAvailable = await BarometerService.isAvailable();
      final pressure = await BarometerService.getCurrentPressure();
      final sensorInfo = await BarometerService.getSensorInfo();
      final weatherAvailable = WeatherStationService.isAvailable();
      final cachedWeather = WeatherStationService.getCachedData();

      status['barometer'] = {
        'available': barometerAvailable,
        'pressure': pressure,
        'sensor_name': sensorInfo['pressure_sensor_name'],
        'sensor_vendor': sensorInfo['pressure_sensor_vendor'],
        'weather_fallback_available': weatherAvailable,
        'cached_weather_stations': cachedWeather.length,
        'error': barometerAvailable ? null : 'Barometer sensor not available',
      };
    } catch (e) {
      status['barometer'] = {
        'available': false,
        'pressure': null,
        'sensor_name': 'Unknown',
        'sensor_vendor': 'Unknown',
        'weather_fallback_available': false,
        'cached_weather_stations': 0,
        'error': e.toString(),
      };
    }

    // GPS status
    try {
      final gpsAvailable = await GPSAltitudeService.isGPSAvailable();
      final location = await GPSAltitudeService.getCurrentLocation();
      status['gps'] = {
        'available': gpsAvailable,
        'location': location?.toString(),
        'error': gpsAvailable ? null : 'GPS not available or disabled',
      };
    } catch (e) {
      status['gps'] = {
        'available': false,
        'location': null,
        'error': e.toString(),
      };
    }
    return status;
  }
}
