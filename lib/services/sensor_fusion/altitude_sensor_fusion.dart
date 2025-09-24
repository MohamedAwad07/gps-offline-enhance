import 'dart:math';
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/utils/app_logger.dart';

/// Advanced sensor fusion for combining multiple altitude measurements
class AltitudeSensorFusion {
  static const Map<String, double> _methodWeights = {
    'barometer': 0.9, // Highest weight for calibrated barometer
    'barometer (weather)': 0.7, // Weather-based barometer fallback
    'weather': 0.7, // Weather station data
    'gps': 0.3, // GPS has lower accuracy for altitude
  };

  static const Map<String, double> _methodBaseConfidence = {
    'barometer': 0.9,
    'barometer (weather)': 0.7,
    'weather': 0.7,
    'gps': 0.4,
  };

  /// Fuse multiple floor detection results using weighted averaging
  static FloorDetectionResult fuseResults(List<FloorDetectionResult> results) {
    if (results.isEmpty) {
      return FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'fusion',
        error: 'No detection results to fuse',
      );
    }

    if (results.length == 1) {
      // Single result - just enhance confidence based on method
      final result = results.first;
      return FloorDetectionResult(
        floor: result.floor,
        altitude: result.altitude,
        confidence: _enhanceConfidence(result),
        method: '${result.method} (single)',
        error: result.error,
      );
    }

    // Filter out results with errors
    final validResults = results.where((r) => r.error == null).toList();

    if (validResults.isEmpty) {
      return FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'fusion',
        error: 'All detection methods failed',
      );
    }

    // Calculate weighted average altitude
    double totalWeightedAltitude = 0;
    double totalWeight = 0;
    double totalWeightedConfidence = 0;
    final List<String> usedMethods = [];

    for (final result in validResults) {
      final weight = _getMethodWeight(result.method) * result.confidence;
      totalWeightedAltitude += result.altitude * weight;
      totalWeightedConfidence += result.confidence * weight;
      totalWeight += weight;
      usedMethods.add(result.method);
    }

    if (totalWeight == 0) {
      return FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'fusion',
        error: 'No valid weighted results',
      );
    }

    final fusedAltitude = totalWeightedAltitude / totalWeight;
    final fusedConfidence = _calculateFusedConfidence(
      validResults,
      totalWeightedConfidence / totalWeight,
    );
    final fusedFloor = (fusedAltitude / 3.5).round(); // 3.5m per floor

    AppLogger.info('Sensor fusion: ${validResults.length} methods combined');
    AppLogger.info(
      'Fused altitude: ${fusedAltitude.toStringAsFixed(2)}m, confidence: ${(fusedConfidence * 100).toStringAsFixed(1)}%',
    );

    return FloorDetectionResult(
      floor: fusedFloor,
      altitude: fusedAltitude,
      confidence: fusedConfidence,
      method: 'fusion (${usedMethods.join(', ')})',
      error: null,
    );
  }

  /// Get weight for a detection method
  static double _getMethodWeight(String method) {
    // Find the best matching method weight
    for (final entry in _methodWeights.entries) {
      if (method.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 0.5; // Default weight for unknown methods
  }

  /// Calculate fused confidence considering multiple factors
  static double _calculateFusedConfidence(
    List<FloorDetectionResult> results,
    double baseConfidence,
  ) {
    // Start with weighted average confidence
    double fusedConfidence = baseConfidence;

    // Bonus for multiple agreeing methods
    if (results.length >= 2) {
      // Check agreement between methods
      final altitudes = results.map((r) => r.altitude).toList();
      final agreement = _calculateAgreement(altitudes);

      // Bonus for good agreement (within 5 meters)
      if (agreement <= 5.0) {
        fusedConfidence +=
            0.1 *
            (results.length - 1); // Bonus for each additional agreeing method
      } else if (agreement <= 10.0) {
        fusedConfidence +=
            0.05 * (results.length - 1); // Smaller bonus for moderate agreement
      }
    }

    // Penalty for high disagreement
    if (results.length >= 2) {
      final altitudes = results.map((r) => r.altitude).toList();
      final disagreement = _calculateAgreement(altitudes);

      if (disagreement > 20.0) {
        fusedConfidence *= 0.7; // Significant penalty for high disagreement
      } else if (disagreement > 10.0) {
        fusedConfidence *= 0.85; // Moderate penalty for disagreement
      }
    }

    // Bonus for high-confidence primary methods
    final primaryResults = results
        .where((r) => r.method.contains('barometer') && r.confidence > 0.8)
        .toList();

    if (primaryResults.isNotEmpty) {
      fusedConfidence +=
          0.05; // Small bonus for high-confidence barometer readings
    }

    // Ensure confidence stays within bounds
    return fusedConfidence.clamp(0.0, 1.0);
  }

  /// Calculate agreement (standard deviation) between altitude measurements
  static double _calculateAgreement(List<double> altitudes) {
    if (altitudes.length < 2) return 0.0;

    final mean = altitudes.reduce((a, b) => a + b) / altitudes.length;
    final variance =
        altitudes.map((alt) => pow(alt - mean, 2)).reduce((a, b) => a + b) /
        altitudes.length;

    return sqrt(variance); // Standard deviation as agreement metric
  }

  /// Enhance confidence for single method results
  static double _enhanceConfidence(FloorDetectionResult result) {
    double confidence = result.confidence;

    // Enhance based on method reliability
    final baseConfidence = _methodBaseConfidence[result.method] ?? 0.5;

    // Blend original confidence with method base confidence
    confidence = (confidence + baseConfidence) / 2;

    // Small bonus for reasonable altitude values
    if (result.altitude >= -10 && result.altitude <= 1000) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Detect and handle outliers in altitude measurements
  static List<FloorDetectionResult> filterOutliers(
    List<FloorDetectionResult> results,
  ) {
    if (results.length < 3)
      return results; // Need at least 3 for outlier detection

    final altitudes = results.map((r) => r.altitude).toList();
    final mean = altitudes.reduce((a, b) => a + b) / altitudes.length;
    final stdDev = _calculateAgreement(altitudes);

    // Remove results that are more than 2 standard deviations from mean
    final filtered = <FloorDetectionResult>[];
    for (int i = 0; i < results.length; i++) {
      final deviation = (results[i].altitude - mean).abs();
      if (deviation <= 2 * stdDev || stdDev == 0) {
        filtered.add(results[i]);
      } else {
        AppLogger.warning(
          'Filtered outlier: ${results[i].method} altitude ${results[i].altitude.toStringAsFixed(1)}m',
        );
      }
    }

    return filtered.isNotEmpty
        ? filtered
        : results; // Return original if all filtered
  }

  /// Get fusion quality metrics for debugging
  static Map<String, dynamic> getFusionMetrics(
    List<FloorDetectionResult> results,
  ) {
    if (results.isEmpty) {
      return {'error': 'No results to analyze'};
    }

    final validResults = results.where((r) => r.error == null).toList();
    final altitudes = validResults.map((r) => r.altitude).toList();

    return {
      'total_methods': results.length,
      'valid_methods': validResults.length,
      'altitude_range': altitudes.isNotEmpty
          ? '${altitudes.reduce(min).toStringAsFixed(1)} - ${altitudes.reduce(max).toStringAsFixed(1)}m'
          : 'N/A',
      'agreement_stddev': altitudes.length >= 2
          ? _calculateAgreement(altitudes).toStringAsFixed(2)
          : 'N/A',
      'methods_used': validResults.map((r) => r.method).join(', '),
      'confidence_range': validResults.isNotEmpty
          ? '${(validResults.map((r) => r.confidence).reduce(min) * 100).toStringAsFixed(1)}% - ${(validResults.map((r) => r.confidence).reduce(max) * 100).toStringAsFixed(1)}%'
          : 'N/A',
    };
  }
}
