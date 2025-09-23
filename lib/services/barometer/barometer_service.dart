import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/barometer/barometer_calculations.dart';
import 'package:learning/services/barometer/barometer_monitoring.dart';
import 'package:learning/services/barometer/barometer_sensor_info.dart';
import 'package:learning/services/barometer/barometer_floor_detection.dart';

/// Main barometer service that combines all barometer functionality
class BarometerService {
  /// Check if barometer is available on this device
  static Future<bool> isAvailable() async {
    return BarometerSensorInfo.isAvailable();
  }

  /// Get detailed sensor information
  static Future<Map<String, dynamic>> getSensorInfo() async {
    return BarometerSensorInfo.getSensorInfo();
  }

  /// Get current atmospheric pressure
  static Future<double?> getCurrentPressure() async {
    return BarometerSensorInfo.getCurrentPressure();
  }

  /// Calculate altitude from pressure using barometric formula
  static double calculateAltitude(double pressure) {
    return BarometerCalculations.calculateAltitude(pressure);
  }

  /// Calculate floor number based on altitude
  /// Assumes each floor is 3.5 meters high
  static int calculateFloor(double altitude, {double floorHeight = 3.5}) {
    return BarometerCalculations.calculateFloor(
      altitude,
      floorHeight: floorHeight,
    );
  }

  /// Start listening to pressure changes
  static Stream<double> startPressureMonitoring() {
    return BarometerMonitoring.startPressureMonitoring();
  }

  /// Start listening to altitude changes
  static Stream<double> startAltitudeMonitoring() {
    return BarometerMonitoring.startAltitudeMonitoring();
  }

  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    return BarometerMonitoring.stopMonitoring();
  }

  /// Calibrate sea level pressure
  static void calibrateSeaLevelPressure(
    double knownAltitude,
    double currentPressure,
  ) {
    BarometerCalculations.calibrateSeaLevelPressure(
      knownAltitude,
      currentPressure,
    );
  }

  /// Get floor detection with confidence level
  static Future<FloorDetectionResult> detectFloor() async {
    return BarometerFloorDetection.detectFloor();
  }
}
