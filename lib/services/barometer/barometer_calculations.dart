import 'dart:math';

/// Barometric calculations and formulas
class BarometerCalculations {
  // Sea level pressure (can be calibrated)
  static double _seaLevelPressure = 1013.25; // hPa

  /// Calculate altitude from pressure using ISA barometric formula
  static double calculateAltitude(
    double pressure, {
    double temperature = 15.0,
  }) {
    // International Standard Atmosphere (ISA) barometric formula
    // h = (T0 / L) * (1 - (P / P0)^((R * L) / (g * M)))
    const double lapseRate = 0.0065; // K/m
    const double R = 8.31447; // Universal gas constant J/(mol·K)
    const double g = 9.80665; // Gravitational acceleration m/s²
    const double M = 0.0289644; // Molar mass of dry air kg/mol

    final double tempKelvin = temperature + 273.15;

    final double altitude =
        (tempKelvin / lapseRate) *
        (1 - pow(pressure / _seaLevelPressure, (R * lapseRate) / (g * M)));

    return altitude;
  }

  /// Calculate floor number based on altitude
  /// Assumes each floor is 3.5 meters high
  static int calculateFloor(double altitude, {double floorHeight = 3.5}) {
    return (altitude / floorHeight).round();
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

  /// Get current sea level pressure
  static double getSeaLevelPressure() => _seaLevelPressure;

  /// Set sea level pressure
  static void setSeaLevelPressure(double pressure) {
    _seaLevelPressure = pressure;
  }
}
