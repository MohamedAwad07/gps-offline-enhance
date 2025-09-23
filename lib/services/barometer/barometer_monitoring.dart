import 'dart:async';
import 'package:flutter/services.dart';
import 'package:learning/services/barometer/barometer_calculations.dart';

/// Barometer monitoring and streaming functionality
class BarometerMonitoring {
  static const MethodChannel _channel = MethodChannel('barometer_service');
  static StreamController<double>? _pressureController;
  static StreamController<double>? _altitudeController;
  static bool _isListening = false;

  /// Start listening to pressure changes
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
          final double altitude = BarometerCalculations.calculateAltitude(
            pressure,
          );
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
}
