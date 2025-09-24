import 'dart:math';

/// Kalman filter for smoothing altitude measurements
class AltitudeKalmanFilter {
  // State variables
  double _altitude = 0.0; // Current altitude estimate
  double _velocity = 0.0; // Current velocity estimate (m/s)
  double _P11 = 1000.0; // Position variance
  double _P12 = 0.0; // Position-velocity covariance
  double _P21 = 0.0; // Velocity-position covariance
  double _P22 = 1000.0; // Velocity variance

  // Process noise (how much we expect altitude/velocity to change)
  final double _processNoiseAltitude = 0.1; // m²/s²
  final double _processNoiseVelocity = 0.01; // (m/s)²/s²

  // Measurement noise (sensor accuracy)
  double _measurementNoise = 1.0; // m² (adjusted based on sensor confidence)

  DateTime? _lastUpdateTime;
  bool _isInitialized = false;

  /// Initialize the filter with first measurement
  void initialize(double initialAltitude, double confidence) {
    _altitude = initialAltitude;
    _velocity = 0.0;

    // Set initial uncertainty based on confidence
    final initialVariance = _confidenceToVariance(confidence);
    _P11 = initialVariance;
    _P12 = 0.0;
    _P21 = 0.0;
    _P22 = 1.0; // Initial velocity uncertainty

    _lastUpdateTime = DateTime.now();
    _isInitialized = true;
  }

  /// Update filter with new altitude measurement
  AltitudeFilterResult update(double measuredAltitude, double confidence) {
    final currentTime = DateTime.now();

    if (!_isInitialized) {
      initialize(measuredAltitude, confidence);
      return AltitudeFilterResult(
        filteredAltitude: _altitude,
        velocity: _velocity,
        confidence: confidence,
        innovation: 0.0,
      );
    }

    // Calculate time delta
    final deltaTime =
        currentTime.difference(_lastUpdateTime!).inMilliseconds / 1000.0;
    if (deltaTime <= 0 || deltaTime > 60) {
      // Reset if too much time has passed or invalid delta
      initialize(measuredAltitude, confidence);
      return AltitudeFilterResult(
        filteredAltitude: _altitude,
        velocity: _velocity,
        confidence: confidence,
        innovation: 0.0,
      );
    }

    // Prediction step
    _predict(deltaTime);

    // Update measurement noise based on confidence
    _measurementNoise = _confidenceToVariance(confidence);

    // Update step
    final innovation = _update(measuredAltitude);

    _lastUpdateTime = currentTime;

    return AltitudeFilterResult(
      filteredAltitude: _altitude,
      velocity: _velocity,
      confidence: _varianceToConfidence(_P11),
      innovation: innovation,
    );
  }

  /// Prediction step of Kalman filter
  void _predict(double deltaTime) {
    // State transition: altitude = altitude + velocity * dt
    final newAltitude = _altitude + _velocity * deltaTime;
    final newVelocity = _velocity; // Assume constant velocity

    // Update covariance matrix with process noise
    final dt2 = deltaTime * deltaTime;
    final dt3 = dt2 * deltaTime;
    final dt4 = dt3 * deltaTime;

    // Process noise matrix Q
    final q11 = _processNoiseAltitude * dt4 / 4; // Position process noise
    final q12 =
        _processNoiseAltitude * dt3 / 2; // Position-velocity process noise
    final q21 = q12; // Velocity-position process noise
    final q22 =
        _processNoiseAltitude * dt2 +
        _processNoiseVelocity; // Velocity process noise

    // State transition matrix F
    // F = [1, dt]
    //     [0, 1 ]

    // Predict covariance: P = F*P*F' + Q
    final newP11 = _P11 + 2 * _P12 * deltaTime + _P22 * dt2 + q11;
    final newP12 = _P12 + _P22 * deltaTime + q12;
    final newP21 = _P21 + _P22 * deltaTime + q21;
    final newP22 = _P22 + q22;

    // Update state
    _altitude = newAltitude;
    _velocity = newVelocity;
    _P11 = newP11;
    _P12 = newP12;
    _P21 = newP21;
    _P22 = newP22;
  }

  /// Update step of Kalman filter
  double _update(double measuredAltitude) {
    // Innovation (measurement residual)
    final innovation = measuredAltitude - _altitude;

    // Innovation covariance
    final S = _P11 + _measurementNoise;

    // Kalman gain
    final K1 = _P11 / S; // Gain for altitude
    final K2 = _P21 / S; // Gain for velocity

    // Update state estimate
    _altitude = _altitude + K1 * innovation;
    _velocity = _velocity + K2 * innovation;

    // Update covariance matrix
    final newP11 = (1 - K1) * _P11;
    final newP12 = (1 - K1) * _P12;
    final newP21 = _P21 - K2 * _P11;
    final newP22 = _P22 - K2 * _P12;

    _P11 = newP11;
    _P12 = newP12;
    _P21 = newP21;
    _P22 = newP22;

    return innovation;
  }

  /// Convert confidence (0-1) to measurement variance
  double _confidenceToVariance(double confidence) {
    // Higher confidence = lower variance
    // confidence 1.0 -> variance 0.1 m²
    // confidence 0.5 -> variance 4.0 m²
    // confidence 0.1 -> variance 100 m²
    return 0.1 / (confidence * confidence + 0.01);
  }

  /// Convert variance to confidence (0-1)
  double _varianceToConfidence(double variance) {
    // Lower variance = higher confidence
    return 1.0 / (1.0 + variance);
  }

  /// Get current filter state
  AltitudeFilterState getState() {
    return AltitudeFilterState(
      altitude: _altitude,
      velocity: _velocity,
      altitudeVariance: _P11,
      velocityVariance: _P22,
      isInitialized: _isInitialized,
      lastUpdateTime: _lastUpdateTime,
    );
  }

  /// Reset the filter
  void reset() {
    _altitude = 0.0;
    _velocity = 0.0;
    _P11 = 1000.0;
    _P12 = 0.0;
    _P21 = 0.0;
    _P22 = 1000.0;
    _lastUpdateTime = null;
    _isInitialized = false;
  }

  /// Check if measurement is likely an outlier
  bool isOutlier(double measuredAltitude, {double threshold = 3.0}) {
    if (!_isInitialized) return false;

    final innovation = (measuredAltitude - _altitude).abs();
    final innovationStdDev = sqrt(_P11 + _measurementNoise);

    return innovation > threshold * innovationStdDev;
  }
}

/// Result of Kalman filter update
class AltitudeFilterResult {
  final double filteredAltitude;
  final double velocity;
  final double confidence;
  final double innovation; // How much the measurement differed from prediction

  AltitudeFilterResult({
    required this.filteredAltitude,
    required this.velocity,
    required this.confidence,
    required this.innovation,
  });

  @override
  String toString() {
    return 'FilterResult(alt: ${filteredAltitude.toStringAsFixed(2)}m, vel: ${velocity.toStringAsFixed(3)}m/s, conf: ${(confidence * 100).toStringAsFixed(1)}%, innov: ${innovation.toStringAsFixed(2)}m)';
  }
}

/// Current state of the Kalman filter
class AltitudeFilterState {
  final double altitude;
  final double velocity;
  final double altitudeVariance;
  final double velocityVariance;
  final bool isInitialized;
  final DateTime? lastUpdateTime;

  AltitudeFilterState({
    required this.altitude,
    required this.velocity,
    required this.altitudeVariance,
    required this.velocityVariance,
    required this.isInitialized,
    required this.lastUpdateTime,
  });

  double get altitudeStdDev => sqrt(altitudeVariance);
  double get velocityStdDev => sqrt(velocityVariance);

  @override
  String toString() {
    return 'FilterState(alt: ${altitude.toStringAsFixed(2)}±${altitudeStdDev.toStringAsFixed(2)}m, vel: ${velocity.toStringAsFixed(3)}±${velocityStdDev.toStringAsFixed(3)}m/s)';
  }
}
