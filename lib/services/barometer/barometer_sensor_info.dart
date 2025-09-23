import 'package:flutter/services.dart';

/// Barometer sensor information and availability
class BarometerSensorInfo {
  static const MethodChannel _channel = MethodChannel('barometer_service');

  /// Check if barometer is available on this device
  static Future<bool> isAvailable() async {
    try {
      final bool available = await _channel.invokeMethod(
        'isBarometerAvailable',
      );
      return available;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed sensor information
  static Future<Map<String, dynamic>> getSensorInfo() async {
    try {
      final Map<dynamic, dynamic> info = await _channel.invokeMethod(
        'getSensorInfo',
      );
      return Map<String, dynamic>.from(info);
    } catch (e) {
      return {
        'barometer_available': false,
        'pressure_sensor_name': 'Error',
        'pressure_sensor_vendor': 'Error',
        'pressure_sensor_version': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get current atmospheric pressure
  static Future<double?> getCurrentPressure() async {
    try {
      final double pressure = await _channel.invokeMethod('getPressure');
      return pressure;
    } catch (e) {
      return null;
    }
  }
}
