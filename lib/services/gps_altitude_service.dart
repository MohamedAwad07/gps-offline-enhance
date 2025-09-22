import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'package:learning/models/floor_detection_result.dart';

class GPSAltitudeService {
  static const MethodChannel _channel = MethodChannel('gps_altitude_service');
  static StreamController<LocationData>? _locationController;
  static bool _isListening = false;

  /// Check if GPS is available and enabled
  static Future<bool> isGPSAvailable() async {
    try {
      dev.log('Calling isGPSAvailable method channel...');
      final bool available = await _channel.invokeMethod('isGPSAvailable');
      dev.log('GPS available result: $available');
      return available;
    } catch (e) {
      dev.log('GPS availability check error: $e');
      return false;
    }
  }

  /// Get current location including altitude
  static Future<LocationData?> getCurrentLocation() async {
    try {
      dev.log('Calling getCurrentLocation method channel...');
      final Map<dynamic, dynamic> location = await _channel.invokeMethod(
        'getCurrentLocation',
      );
      dev.log('GPS location method channel returned: $location');
      return LocationData.fromMap(Map<String, dynamic>.from(location));
    } catch (e) {
      dev.log('GPS location method channel error: $e');
      return null;
    }
  }

  /// Start listening to location changes
  static Stream<LocationData> startLocationMonitoring() {
    if (_isListening) {
      return _locationController!.stream;
    }

    _locationController = StreamController<LocationData>.broadcast();
    _isListening = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'locationUpdate':
          final Map<String, dynamic> locationData = call.arguments;
          final location = LocationData.fromMap(locationData);
          _locationController!.add(location);
          break;
      }
    });

    _channel.invokeMethod('startLocationMonitoring');
    return _locationController!.stream;
  }

  /// Stop location monitoring
  static Future<void> stopLocationMonitoring() async {
    if (!_isListening) return;

    await _channel.invokeMethod('stopLocationMonitoring');
    _locationController?.close();
    _isListening = false;
  }

  /// Calculate floor number based on GPS altitude
  static int calculateFloorFromAltitude(
    double altitude, {
    double floorHeight = 3.5,
  }) {
    return (altitude / floorHeight).round();
  }

  /// Detect floor using GPS altitude
  static Future<FloorDetectionResult> detectFloor() async {
    try {
      // Check if GPS is available first
      final isAvailable = await isGPSAvailable();
      if (!isAvailable) {
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'gps',
          error: 'GPS not available or disabled',
        );
      }

      final location = await getCurrentLocation();
      if (location == null) {
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'gps',
          error: 'Failed to get GPS location',
        );
      }

      if (location.altitude == null) {
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'gps',
          error: 'GPS altitude not available in location data',
        );
      }

      final altitude = location.altitude!;
      final floor = calculateFloorFromAltitude(altitude);

      // GPS altitude accuracy is lower indoors, so confidence is moderate
      final confidence = _calculateGPSConfidence(location.accuracy);

      return FloorDetectionResult(
        floor: floor,
        altitude: altitude,
        confidence: confidence,
        method: 'gps',
        error: null,
      );
    } catch (e) {
      return FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'gps',
        error: 'GPS error: ${e.toString()}',
      );
    }
  }

  /// Calculate confidence based on GPS accuracy
  static double _calculateGPSConfidence(double? accuracy) {
    if (accuracy == null) return 0.3;

    // GPS accuracy is typically 3-5 meters outdoors, 10-20 meters indoors
    // Better accuracy = higher confidence
    if (accuracy <= 5) return 0.8;
    if (accuracy <= 10) return 0.6;
    if (accuracy <= 20) return 0.4;
    return 0.2;
  }

  /// Get altitude with sea level reference
  static Future<double?> getAltitudeAboveSeaLevel() async {
    try {
      final location = await getCurrentLocation();
      return location?.altitude;
    } catch (e) {
      return null;
    }
  }

  /// Check if location is indoors (low accuracy, no GPS fix)
  static bool isIndoors(LocationData location) {
    return location.accuracy == null || location.accuracy! > 15;
  }
}

class LocationData {
  final double? latitude;
  final double? longitude;
  final double? altitude; // meters above sea level
  final double? accuracy; // meters
  final double? speed;
  final double? heading;
  final DateTime timestamp;

  LocationData({
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.timestamp,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      altitude: map['altitude']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      speed: map['speed']?.toDouble(),
      heading: map['heading']?.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, alt: $altitude, acc: $accuracy)';
  }
}
