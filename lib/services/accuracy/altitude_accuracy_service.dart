import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/calibration/pressure_calibration_service.dart';

/// Service for calculating and displaying altitude measurement accuracy
class AltitudeAccuracyService {
  /// Calculate accuracy metrics for altitude measurement
  static AccuracyMetrics calculateAccuracy(FloorDetectionResult result) {
    final baseAccuracy = _getMethodBaseAccuracy(result.method);
    final confidenceMultiplier = _getConfidenceMultiplier(result.confidence);
    final calibrationMultiplier = _getCalibrationMultiplier();

    // Calculate estimated accuracy (standard deviation in meters)
    final estimatedAccuracy =
        baseAccuracy * confidenceMultiplier * calibrationMultiplier;

    // Calculate accuracy grade
    final grade = _calculateAccuracyGrade(estimatedAccuracy);

    // Calculate confidence interval (±2σ for ~95% confidence)
    final confidenceInterval = estimatedAccuracy * 2;

    return AccuracyMetrics(
      estimatedAccuracyMeters: estimatedAccuracy,
      confidenceInterval95: confidenceInterval,
      accuracyGrade: grade,
      method: result.method,
      confidence: result.confidence,
      calibrationStatus: PressureCalibrationService.getCalibrationStatus(),
    );
  }

  /// Get base accuracy for different measurement methods
  static double _getMethodBaseAccuracy(String method) {
    final methodLower = method.toLowerCase();

    if (methodLower.contains('barometer')) {
      if (methodLower.contains('weather')) {
        return 8.0; // Weather-based barometer: ±8m
      }
      return 3.0; // Direct barometer: ±3m (when calibrated)
    } else if (methodLower.contains('weather')) {
      return 10.0; // Weather station: ±10m
    } else if (methodLower.contains('gps')) {
      return 15.0; // GPS altitude: ±15m
    } else if (methodLower.contains('fusion')) {
      return 5.0; // Sensor fusion: ±5m (typically better than individual methods)
    }

    return 20.0; // Unknown method: ±20m
  }

  /// Get confidence multiplier (higher confidence = better accuracy)
  static double _getConfidenceMultiplier(double confidence) {
    // confidence 0.9+ -> multiplier 0.8 (20% better accuracy)
    // confidence 0.7+ -> multiplier 1.0 (baseline accuracy)
    // confidence 0.5+ -> multiplier 1.3 (30% worse accuracy)
    // confidence 0.3+ -> multiplier 1.8 (80% worse accuracy)
    // confidence <0.3 -> multiplier 2.5 (150% worse accuracy)

    if (confidence >= 0.9) return 0.8;
    if (confidence >= 0.7) return 1.0;
    if (confidence >= 0.5) return 1.3;
    if (confidence >= 0.3) return 1.8;
    return 2.5;
  }

  /// Get calibration multiplier (calibrated = better accuracy)
  static double _getCalibrationMultiplier() {
    final calibrationStatus = PressureCalibrationService.getCalibrationStatus();

    if (!calibrationStatus.isCalibrated) {
      return 2.0; // Uncalibrated: 100% worse accuracy
    }

    if (calibrationStatus.isCalibrationNeeded) {
      return 1.5; // Old calibration: 50% worse accuracy
    }

    return 1.0; // Recent calibration: baseline accuracy
  }

  /// Calculate accuracy grade (A+ to F)
  static AccuracyGrade _calculateAccuracyGrade(double accuracyMeters) {
    if (accuracyMeters <= 2.0) return AccuracyGrade.aPlus;
    if (accuracyMeters <= 5.0) return AccuracyGrade.a;
    if (accuracyMeters <= 8.0) return AccuracyGrade.b;
    if (accuracyMeters <= 12.0) return AccuracyGrade.c;
    if (accuracyMeters <= 20.0) return AccuracyGrade.d;
    return AccuracyGrade.f;
  }

  /// Get recommendations for improving accuracy
  static List<String> getAccuracyRecommendations(AccuracyMetrics metrics) {
    final recommendations = <String>[];

    // Calibration recommendations
    if (!metrics.calibrationStatus.isCalibrated) {
      recommendations.add('📍 Calibrate using GPS location and weather data');
    } else if (metrics.calibrationStatus.isCalibrationNeeded) {
      recommendations.add('🔄 Recalibrate - current calibration is outdated');
    }

    // Method-specific recommendations
    if (metrics.method.toLowerCase().contains('gps')) {
      recommendations.add('📡 Use barometer if available for better accuracy');
      recommendations.add('🏢 GPS altitude is less accurate indoors');
    }

    if (metrics.method.toLowerCase().contains('weather')) {
      recommendations.add('🌐 Weather data depends on internet connection');
      recommendations.add(
        '📍 Accuracy varies with distance to weather station',
      );
    }

    // Confidence recommendations
    if (metrics.confidence < 0.5) {
      recommendations.add('⚠️ Low confidence - consider multiple readings');
      recommendations.add('📶 Check sensor availability and permissions');
    }

    // General recommendations
    if (metrics.estimatedAccuracyMeters > 10) {
      recommendations.add('🔧 Consider sensor fusion for better accuracy');
      recommendations.add('📊 Take multiple readings and average them');
    }

    return recommendations;
  }

  /// Calculate floor detection accuracy (how likely the floor number is correct)
  static FloorAccuracy calculateFloorAccuracy(
    FloorDetectionResult result, {
    double floorHeight = 3.5,
  }) {
    final altitudeAccuracy = calculateAccuracy(result);

    // Calculate how many floors the accuracy spans
    final floorUncertainty =
        altitudeAccuracy.estimatedAccuracyMeters / floorHeight;

    // Probability that we're on the correct floor
    double correctFloorProbability;
    if (floorUncertainty <= 0.3) {
      correctFloorProbability = 0.95; // Very high confidence
    } else if (floorUncertainty <= 0.5) {
      correctFloorProbability = 0.85; // High confidence
    } else if (floorUncertainty <= 0.8) {
      correctFloorProbability = 0.70; // Medium confidence
    } else if (floorUncertainty <= 1.2) {
      correctFloorProbability = 0.50; // Low confidence
    } else {
      correctFloorProbability = 0.30; // Very low confidence
    }

    // Calculate possible floor range
    final floorError = (altitudeAccuracy.confidenceInterval95 / floorHeight)
        .ceil();
    final minFloor = result.floor - floorError;
    final maxFloor = result.floor + floorError;

    return FloorAccuracy(
      mostLikelyFloor: result.floor,
      correctFloorProbability: correctFloorProbability,
      possibleFloorRange: FloorRange(minFloor, maxFloor),
      floorUncertainty: floorUncertainty,
      altitudeAccuracy: altitudeAccuracy,
    );
  }
}

/// Accuracy metrics for altitude measurement
class AccuracyMetrics {
  final double estimatedAccuracyMeters; // Standard deviation in meters
  final double confidenceInterval95; // ±meters for 95% confidence
  final AccuracyGrade accuracyGrade; // Letter grade A+ to F
  final String method; // Detection method used
  final double confidence; // Original confidence value
  final CalibrationStatus calibrationStatus; // Calibration status

  AccuracyMetrics({
    required this.estimatedAccuracyMeters,
    required this.confidenceInterval95,
    required this.accuracyGrade,
    required this.method,
    required this.confidence,
    required this.calibrationStatus,
  });

  String get accuracyDescription {
    return '±${estimatedAccuracyMeters.toStringAsFixed(1)}m (${accuracyGrade.displayName})';
  }

  String get confidenceIntervalDescription {
    return '±${confidenceInterval95.toStringAsFixed(1)}m (95% confidence)';
  }

  @override
  String toString() {
    return 'AccuracyMetrics($accuracyDescription, method: $method, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Floor detection accuracy information
class FloorAccuracy {
  final int mostLikelyFloor;
  final double correctFloorProbability;
  final FloorRange possibleFloorRange;
  final double floorUncertainty;
  final AccuracyMetrics altitudeAccuracy;

  FloorAccuracy({
    required this.mostLikelyFloor,
    required this.correctFloorProbability,
    required this.possibleFloorRange,
    required this.floorUncertainty,
    required this.altitudeAccuracy,
  });

  String get floorDescription {
    if (mostLikelyFloor == 0) return 'Ground Floor';
    if (mostLikelyFloor < 0) return 'Basement Level ${mostLikelyFloor.abs()}';
    return 'Floor $mostLikelyFloor';
  }

  String get probabilityDescription {
    final percentage = (correctFloorProbability * 100).toStringAsFixed(0);
    return '$percentage% confident';
  }

  @override
  String toString() {
    return 'FloorAccuracy($floorDescription, $probabilityDescription, range: ${possibleFloorRange.description})';
  }
}

/// Range of possible floors
class FloorRange {
  final int minFloor;
  final int maxFloor;

  FloorRange(this.minFloor, this.maxFloor);

  String get description {
    if (minFloor == maxFloor) return 'Floor $minFloor';
    return 'Floors $minFloor to $maxFloor';
  }

  int get span => maxFloor - minFloor + 1;
}

/// Accuracy grade enumeration
enum AccuracyGrade {
  aPlus('A+', '🟢 Excellent'),
  a('A', '🟢 Very Good'),
  b('B', '🟡 Good'),
  c('C', '🟡 Fair'),
  d('D', '🟠 Poor'),
  f('F', '🔴 Very Poor');

  const AccuracyGrade(this.grade, this.displayName);
  final String grade;
  final String displayName;
}
