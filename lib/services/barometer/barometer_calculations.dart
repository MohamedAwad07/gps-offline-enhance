import 'dart:math';

/// Barometric calculations and formulas
class BarometerCalculations {
  // Sea level pressure (can be calibrated)
  static double _seaLevelPressure = 1013.25; // hPa

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
