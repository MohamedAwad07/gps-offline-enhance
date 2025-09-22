import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/weather_station_service.dart';
import 'package:learning/services/gps_altitude_service.dart';

class BarometerService {
  static const MethodChannel _channel = MethodChannel('barometer_service');
  static StreamController<double>? _pressureController;
  static StreamController<double>? _altitudeController;
  static bool _isListening = false;

  // Sea level pressure (can be calibrated)
  static double _seaLevelPressure = 1013.25; // hPa

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

  /// Calculate altitude from pressure using barometric formula
  static double calculateAltitude(double pressure) {
    // Barometric formula: h = 44330 * (1 - (P/P0)^0.1903)
    // where P is current pressure, P0 is sea level pressure
    return 44330.0 * (1.0 - pow(pressure / _seaLevelPressure, 0.1903));
  }

  /// Calculate floor number based on altitude
  /// Assumes each floor is 3.5 meters high
  static int calculateFloor(double altitude, {double floorHeight = 3.5}) {
    return (altitude / floorHeight).round();
  }

  /// Start listening to pressure  changes
  static Stream<double> startPressureMonitoring() {
    if (_isListening) {
      return _pressureController!.stream;
    }

    _pressureController = StreamController<double>.broadcast();
    _isListening = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pressureUpdate':
          final double pressure = call.arguments;
          _pressureController!.add(pressure);
          break;
      }
    });

    _channel.invokeMethod('startPressureMonitoring');
    return _pressureController!.stream;
  }

  /// Start listening to altitude changes
  static Stream<double> startAltitudeMonitoring() {
    if (_isListening) {
      return _altitudeController!.stream;
    }

    _altitudeController = StreamController<double>.broadcast();
    _isListening = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pressureUpdate':
          final double pressure = call.arguments;
          final double altitude = calculateAltitude(pressure);
          _altitudeController!.add(altitude);
          break;
      }
    });

    _channel.invokeMethod('startPressureMonitoring');
    return _altitudeController!.stream;
  }

  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    if (!_isListening) return;

    await _channel.invokeMethod('stopPressureMonitoring');
    _pressureController?.close();
    _altitudeController?.close();
    _isListening = false;
  }

  /// Calibrate sea level pressure
  static void calibrateSeaLevelPressure(
    double knownAltitude,
    double currentPressure,
  ) {
    // Reverse calculate sea level pressure from known altitude and current pressure
    _seaLevelPressure =
        currentPressure / pow(1 - (knownAltitude / 44330), 1 / 0.1903);
  }

  /// Get floor detection with confidence level
  static Future<FloorDetectionResult> detectFloor() async {
    try {
      // Check if barometer is available first
      final barometerAvailable = await isAvailable();
      if (!barometerAvailable) {
        // Try weather station service as fallback
        return await _tryWeatherStationFallback();
      }

      final pressure = await getCurrentPressure();
      if (pressure == null) {
        // Try weather station service as fallback
        return await _tryWeatherStationFallback();
      }

      final altitude = calculateAltitude(pressure);
      final floor = calculateFloor(altitude);

      // Calculate confidence based on pressure reading quality
      double confidence = 0.8; // Base confidence for barometer

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
            0.9, // Slightly lower confidence for weather data
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
