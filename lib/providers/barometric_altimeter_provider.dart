import 'dart:math';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';

class BarometricAltimeterProvider with ChangeNotifier {
  double? _previousReading;
  double? _pZero;
  double _currentElevation = 0.0;
  double? _currentAltitude; // Absolute altitude above sea level
  bool _isMonitoring = false;
  String _status = 'Not started';

  // Getters
  double? get pZero => _pZero;
  double? get previousReading => _previousReading;
  double get currentElevation => _currentElevation;
  double? get currentAltitude => _currentAltitude;
  bool get isMonitoring => _isMonitoring;
  String get status => _status;

  /// Set the previous pressure reading
  void setPreviousReading(double value) {
    _previousReading = value;
    notifyListeners();
  }

  /// Reset the reference pressure (P0) to current reading
  void resetPZeroValue() {
    if (_previousReading != null) {
      _pZero = _previousReading;
      _currentElevation = 0.0;
      _status = 'Reset to current pressure';
      notifyListeners();
    }
  }

  /// Update current elevation
  void updateElevation(double elevation) {
    _currentElevation = elevation;
    notifyListeners();
  }

  /// Update current altitude above sea level
  void updateAltitude(double altitude) {
    _currentAltitude = altitude;
    notifyListeners();
  }

  /// Calculate absolute altitude from pressure using barometric formula
  /// Formula: h = (T0 / L) * (1 - (P / P0)^(R * L / (g * M)))
  /// where P is current pressure, P0 is sea level pressure (1013.25 hPa or calibrated)
  void calculateAltitudeFromPressure(
    double pressure, {
    double temperature = 15.0,
  }) {
    if (pressure <= 0) return;

    // Use calibrated or standard sea level pressure
    final double seaLevelPressure =
        _pZero ?? 1013.25; // Use calibrated or standard pressure

    // ISA barometric formula constants
    const double lapseRate = 0.0065; // K/m
    const double R = 8.31447; // Universal gas constant J/(mol·K)
    const double g = 9.80665; // Gravitational acceleration m/s²
    const double M = 0.0289644; // Molar mass of dry air kg/mol

    // Convert temperature to Kelvin (THIS WAS THE BUG!)
    final double tempKelvin = temperature + 273.15;

    // ISA barometric formula for altitude calculation
    final double altitude =
        (tempKelvin / lapseRate) *
        (1 - pow(pressure / seaLevelPressure, (R * lapseRate) / (g * M)));

    _currentAltitude = altitude;
    dev.log(
      'Pressure: $pressure hPa, Temperature: $temperature°C, Calculated altitude: $altitude m',
    );
    notifyListeners();
  }

  /// Set monitoring status
  void setMonitoringStatus(bool isMonitoring) {
    _isMonitoring = isMonitoring;
    _status = isMonitoring ? 'Monitoring pressure' : 'Stopped monitoring';
    notifyListeners();
  }

  /// Set status message
  void setStatus(String status) {
    _status = status;
    notifyListeners();
  }

  /// Initialize with default sea level pressure
  void initializeWithSeaLevelPressure() {
    _pZero = 1013.25; // Standard atmospheric pressure at sea level
    _status = 'Initialized with sea level pressure';
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _previousReading = null;
    _pZero = null;
    _currentElevation = 0.0;
    _currentAltitude = null;
    _isMonitoring = false;
    _status = 'Cleared';
    notifyListeners();
  }
}
