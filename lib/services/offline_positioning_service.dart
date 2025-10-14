import 'dart:async';
import 'dart:developer';
import 'package:testgps/models/gnss_models.dart';
import 'package:testgps/services/gnss_native_service.dart';

/// Offline Positioning Service for enhanced GPS performance in offline scenarios
/// Implements cold start optimization and progressive acquisition strategies
class OfflinePositioningService {
  static final OfflinePositioningService _instance =
      OfflinePositioningService._internal();
  factory OfflinePositioningService() => _instance;
  OfflinePositioningService._internal();

  final GnssNativeService _gnssService = GnssNativeService();

  bool _isInitialized = false;
  bool _isColdStart = true;
  DateTime? _lastFixTime;
  final Map<String, dynamic> _almanacCache = {};
  final Map<String, dynamic> _ephemerisCache = {};

  // Cold start optimization parameters
  static const Duration _coldStartTimeout = Duration(minutes: 10);
  static const Duration _warmStartTimeout = Duration(minutes: 2);
  static const Duration _hotStartTimeout = Duration(seconds: 30);

  // Progressive acquisition parameters
  static const List<int> _minSatellitesForFix = [4, 6, 8];
  static const List<double> _minSnrThresholds = [15.0, 20.0, 25.0];

  /// Initialize offline positioning service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await _gnssService.initialize();
      _isInitialized = true;
      log('Offline Positioning Service initialized');
      return true;
    } catch (e) {
      log('Failed to initialize Offline Positioning Service: $e');
      return false;
    }
  }

  /// Get position with offline optimization
  Future<GnssStatus?> getPositionWithOfflineOptimization({
    Duration? timeout,
    bool forceColdStart = false,
    bool manageTracking = true, // New parameter to control tracking lifecycle
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Determine start type and timeout
    final startType = _determineStartType(forceColdStart);
    final effectiveTimeout = timeout ?? _getTimeoutForStartType(startType);

    log(
      'Starting offline positioning with $startType (timeout: ${effectiveTimeout.inMinutes}min)',
    );

    try {
      // Start GNSS tracking only if we're managing the lifecycle
      if (manageTracking) {
        final trackingStarted = await _gnssService.startTracking();
        if (!trackingStarted) {
          throw Exception('Failed to start GNSS tracking');
        }
      }

      // Wait for position fix with progressive acquisition
      final status = await _waitForPositionFix(effectiveTimeout, startType);

      if (status != null) {
        _lastFixTime = DateTime.now();
        _isColdStart = false;
        log(
          'Position fix obtained: ${status.fixType.name}, accuracy: ${status.accuracy.toStringAsFixed(1)}m',
        );
      }

      return status;
    } catch (e) {
      log('Offline positioning failed: $e');
      return null;
    } finally {
      // Only stop tracking if we started it
      if (manageTracking) {
        await _gnssService.stopTracking();
      }
    }
  }

  /// Wait for position fix with progressive acquisition
  Future<GnssStatus?> _waitForPositionFix(
    Duration timeout,
    StartType startType,
  ) async {
    final stopwatch = Stopwatch()..start();
    GnssStatus? bestStatus;
    int bestSatellitesUsed = 0;
    double bestAccuracy = double.infinity;

    // Set up status monitoring
    final statusStream = _gnssService.eventStream
        .where((event) => event is SatelliteStatusEvent)
        .map((event) => (event as SatelliteStatusEvent).status);

    await for (final status in statusStream.timeout(timeout)) {
      final elapsed = stopwatch.elapsed;

      // Check if we have a good enough fix
      if (_isGoodEnoughFix(status, startType)) {
        log('Good fix obtained after ${elapsed.inSeconds}s');
        return status;
      }

      // Track best status for fallback
      if (status.satellitesInUse > bestSatellitesUsed ||
          (status.satellitesInUse == bestSatellitesUsed &&
              status.accuracy < bestAccuracy)) {
        bestStatus = status;
        bestSatellitesUsed = status.satellitesInUse;
        bestAccuracy = status.accuracy;
      }

      // Progressive acquisition - try different thresholds
      for (int i = 0; i < _minSatellitesForFix.length; i++) {
        final minSats = _minSatellitesForFix[i];
        final minSnr = _minSnrThresholds[i];

        if (status.satellitesInUse >= minSats && status.averageSnr >= minSnr) {
          log(
            'Progressive fix achieved: ${status.satellitesInUse} sats, ${status.averageSnr.toStringAsFixed(1)} SNR',
          );
          return status;
        }
      }

      // Log progress every 30 seconds
      if (elapsed.inSeconds % 30 == 0) {
        log(
          'Positioning progress: ${status.satellitesInUse}/${status.satellitesInView} sats, '
          '${status.averageSnr.toStringAsFixed(1)} SNR, ${status.accuracy.toStringAsFixed(1)}m accuracy',
        );
      }
    }

    // Timeout reached, return best status if available
    if (bestStatus != null) {
      log('Timeout reached, returning best available status');
      return bestStatus;
    }

    return null;
  }

  /// Check if status represents a good enough fix for the start type
  bool _isGoodEnoughFix(GnssStatus status, StartType startType) {
    switch (startType) {
      case StartType.coldStart:
        return status.fixType == GnssFixType.fix3D &&
            status.satellitesInUse >= 6 &&
            status.accuracy <= 20.0;
      case StartType.warmStart:
        return status.fixType == GnssFixType.fix3D &&
            status.satellitesInUse >= 4 &&
            status.accuracy <= 10.0;
      case StartType.hotStart:
        return status.fixType == GnssFixType.fix3D &&
            status.satellitesInUse >= 4 &&
            status.accuracy <= 5.0;
    }
  }

  /// Determine start type based on last fix time
  StartType _determineStartType(bool forceColdStart) {
    if (forceColdStart) return StartType.coldStart;

    if (_lastFixTime == null) return StartType.coldStart;

    final timeSinceLastFix = DateTime.now().difference(_lastFixTime!);

    if (timeSinceLastFix > const Duration(hours: 2)) {
      return StartType.coldStart;
    } else if (timeSinceLastFix > const Duration(minutes: 30)) {
      return StartType.warmStart;
    } else {
      return StartType.hotStart;
    }
  }

  /// Get timeout based on start type
  Duration _getTimeoutForStartType(StartType startType) {
    switch (startType) {
      case StartType.coldStart:
        return _coldStartTimeout;
      case StartType.warmStart:
        return _warmStartTimeout;
      case StartType.hotStart:
        return _hotStartTimeout;
    }
  }

  /// Get positioning statistics
  PositioningStats getStats() {
    return PositioningStats(
      isColdStart: _isColdStart,
      lastFixTime: _lastFixTime,
      almanacCacheSize: _almanacCache.length,
      ephemerisCacheSize: _ephemerisCache.length,
    );
  }

  /// Clear positioning cache (useful for testing)
  void clearCache() {
    _almanacCache.clear();
    _ephemerisCache.clear();
    _lastFixTime = null;
    _isColdStart = true;
    log('Positioning cache cleared');
  }

  /// Dispose resources
  void dispose() {
    _gnssService.dispose();
    _isInitialized = false;
  }
}

/// Start type enumeration
enum StartType {
  coldStart, // No recent fix, needs full almanac/ephemeris download
  warmStart, // Recent fix, some data cached
  hotStart, // Very recent fix, most data cached
}

/// Positioning statistics
class PositioningStats {
  final bool isColdStart;
  final DateTime? lastFixTime;
  final int almanacCacheSize;
  final int ephemerisCacheSize;

  const PositioningStats({
    required this.isColdStart,
    required this.lastFixTime,
    required this.almanacCacheSize,
    required this.ephemerisCacheSize,
  });

  /// Get time since last fix
  Duration? get timeSinceLastFix {
    if (lastFixTime == null) return null;
    return DateTime.now().difference(lastFixTime!);
  }

  /// Get start type based on last fix time
  StartType get estimatedStartType {
    if (lastFixTime == null) return StartType.coldStart;

    final timeSince = timeSinceLastFix!;

    if (timeSince > const Duration(hours: 2)) {
      return StartType.coldStart;
    } else if (timeSince > const Duration(minutes: 30)) {
      return StartType.warmStart;
    } else {
      return StartType.hotStart;
    }
  }

  @override
  String toString() {
    return 'PositioningStats(isColdStart: $isColdStart, '
        'lastFix: $lastFixTime, '
        'almanacCache: $almanacCacheSize, '
        'ephemerisCache: $ephemerisCacheSize)';
  }
}
