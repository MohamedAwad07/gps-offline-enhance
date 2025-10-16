import 'dart:async';
import 'dart:developer';
import 'package:geolocator/geolocator.dart';
import 'package:testgps/services/gnss_native_service.dart';
import 'package:testgps/services/fused_location_service.dart';
import 'package:testgps/location_service.dart';
import 'package:testgps/models/gnss_models.dart';

/// Smart Location Service that switches between GNSS and Fused Location
class SmartLocationService {
  static final SmartLocationService _instance =
      SmartLocationService._internal();
  factory SmartLocationService() => _instance;
  SmartLocationService._internal();

  final GnssNativeService _gnssService = GnssNativeService();
  final FusedLocationService _fusedLocationService = FusedLocationService();
  final LocationService _locationService = LocationService.instance();

  bool _isInitialized = false;
  bool _isTracking = false;
  LocationProvider _currentProvider = LocationProvider.gnss;
  Position? _currentPosition;
  GnssStatus? _currentGnssStatus;

  // Provider switching tracking
  bool _isSwitchingProvider = false;
  String _currentMethodDescription = 'Initializing...';
  String _lastSwitchReason = '';
  DateTime? _lastProviderSwitch;

  // Position history and accuracy tracking
  final List<Position> _positionHistory = [];
  double _currentGlobalAccuracy = 0.0;
  static const int _maxHistorySize = 50; // Keep last 50 positions

  // Service phase tracking
  bool _isInGnssPhase = false;
  bool _isInFusedPhase = false;
  bool _isInStandardPhase = false;
  Timer? _gnssPhaseTimer;
  Timer? _fusedPhaseTimer;
  Timer? _standardPhaseTimer;
  Timer? _standardLocationUpdateTimer;

  // Configuration
  int _minSatellitesRequired = 9;
  double _minAccuracyThreshold = 10.0;
  Duration _gnssTimeout = const Duration(
    seconds: 30,
  );
  Duration _fusedLocationTimeout = const Duration(seconds: 30);
  Duration _standardLocationTimeout = const Duration(minutes: 1);

  // Stream controllers
  final StreamController<SmartLocationEvent> _eventController =
      StreamController<SmartLocationEvent>.broadcast();

  StreamSubscription<GnssEvent>? _gnssEventSubscription;
  StreamSubscription<FusedLocationEvent>? _fusedLocationEventSubscription;

  /// Stream of smart location events
  Stream<SmartLocationEvent> get eventStream => _eventController.stream;

  /// Current position
  Position? get currentPosition => _currentPosition;

  /// Current GNSS status
  GnssStatus? get currentGnssStatus => _currentGnssStatus;

  /// Current location provider being used
  LocationProvider get currentProvider => _currentProvider;

  /// Whether service is tracking
  bool get isTracking => _isTracking;

  /// Whether service is initialized
  bool get isInitialized => _isInitialized;

  /// Whether currently switching providers
  bool get isSwitchingProvider => _isSwitchingProvider;

  /// Current method description
  String get currentMethodDescription => _currentMethodDescription;

  /// Last switch reason
  String get lastSwitchReason => _lastSwitchReason;

  /// Last provider switch time
  DateTime? get lastProviderSwitch => _lastProviderSwitch;

  /// Position history for Fused Location
  List<Position> get positionHistory => List.unmodifiable(_positionHistory);

  /// Current global accuracy (latest position accuracy for Fused Location, GNSS status accuracy for GNSS)
  double get currentGlobalAccuracy => _currentGlobalAccuracy;

  /// Helper method to safely add events to the stream
  void _addEvent(SmartLocationEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Add position to history and update global accuracy
  void _addPositionToHistory(Position position) {
    _positionHistory.add(position);

    // Keep only the last N positions
    if (_positionHistory.length > _maxHistorySize) {
      _positionHistory.removeAt(0);
    }

    // Update global accuracy with latest position accuracy
    _currentGlobalAccuracy = position.accuracy;

    log(
      'Position added to history: ${position.accuracy.toStringAsFixed(1)}m accuracy',
    );
  }

  /// Clear position history
  void _clearPositionHistory() {
    _positionHistory.clear();
    _currentGlobalAccuracy = 0.0;
    log('Position history cleared');
  }

  /// Evaluate GNSS phase after 30 seconds
  Future<void> _evaluateGnssPhase(int satellitesRequired) async {
    if (!_isInGnssPhase) return;

    _isInGnssPhase = false;
    final currentStatus = _currentGnssStatus;
    final satellitesInUse = currentStatus?.satellitesInUse ?? 0;

    log(
      '📊 GNSS Phase Evaluation: $satellitesInUse satellites in use (required: $satellitesRequired)',
    );

    if (satellitesInUse >= satellitesRequired) {
      // GNSS is good enough - complete service
      log(
        '✅ GNSS SUFFICIENT: $satellitesInUse satellites >= $satellitesRequired - completing service',
      );
      await _completeServiceWithFinalAccuracy(
        'GNSS Phase - $satellitesInUse satellites',
      );
    } else {
      // GNSS insufficient - switch to Fused Location
      log(
        '❌ GNSS INSUFFICIENT: $satellitesInUse satellites < $satellitesRequired - switching to Fused Location',
      );
      await _startFusedLocationPhase();
    }
  }

  /// Start Fused Location phase for 30 seconds
  Future<bool> _startFusedLocationPhase() async {
    try {
      log('PHASE 2: Starting Fused Location for 30 seconds...');
      _updateMethodDescription(
        'Fused Location Phase (30s)',
        'GNSS insufficient - using Fused Location...',
      );

      // Stop GNSS tracking
      await _gnssService.stopTracking();

      // Start Fused Location tracking
      final fusedStarted = await _fusedLocationService.startTracking(
        accuracy: LocationAccuracy.bestForNavigation,
      );

      if (fusedStarted) {
        _isInFusedPhase = true;
        _switchToProvider(
          LocationProvider.fusedLocation,
          'GNSS insufficient - switched to Fused Location for 30 seconds',
        );

        // Start 30-second Fused Location phase timer
        _fusedPhaseTimer = Timer(const Duration(seconds: 30), () {
          _completeFusedLocationPhase();
        });

        return true;
      } else {
        // Fused Location failed - go to Standard GPS
        log('❌ Fused Location failed to start, switching to Standard GPS...');
        return await _startStandardLocationPhase();
      }
    } catch (e) {
      log('Error starting Fused Location phase: $e');
      return await _startStandardLocationPhase();
    }
  }

  /// Complete Fused Location phase after 30 seconds
  Future<void> _completeFusedLocationPhase() async {
    if (!_isInFusedPhase) return;

    _isInFusedPhase = false;
    log('🏁 Fused Location phase completed after 30 seconds');
    await _completeServiceWithFinalAccuracy(
      'Fused Location Phase - 30 seconds',
    );
  }

  /// Start Standard Location phase for 1 minute (fallback)
  Future<bool> _startStandardLocationPhase() async {
    try {
      log('PHASE 3: Starting Standard GPS for 1 minute (fallback)...');
      _updateMethodDescription(
        'Standard GPS Phase (1m)',
        'Fused Location failed - using Standard GPS...',
      );

      // Stop Fused Location tracking
      await _fusedLocationService.stopTracking();

      _isInStandardPhase = true;
      _switchToProvider(
        LocationProvider.standard,
        'Fused Location failed - using Standard GPS for 1 minute',
      );

      // Start periodic position updates using LocationService
      _startStandardLocationUpdates();

      // Start 1-minute Standard GPS phase timer
      _standardPhaseTimer = Timer(const Duration(minutes: 1), () {
        _completeStandardLocationPhase();
      });

      return true;
    } catch (e) {
      log('Error starting Standard Location phase: $e');
      await _completeServiceWithFinalAccuracy('Standard GPS Phase - Error');
      return false;
    }
  }

  /// Start periodic position updates for Standard Location phase
  void _startStandardLocationUpdates() {
    _standardLocationUpdateTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) {
      if (!_isInStandardPhase || !_isTracking) {
        timer.cancel();
        return;
      }

      _locationService
          .getCurrentPositionWithFallback(timeout: const Duration(seconds: 5))
          .then((position) {
            if (_isInStandardPhase && _isTracking) {
              _currentPosition = position;
              _currentGlobalAccuracy = position.accuracy;
              _addEvent(
                SmartLocationEvent.positionUpdate(
                  position,
                  LocationProvider.standard,
                ),
              );
            }
          })
          .catchError((e) {
            log('Error getting standard location: $e');
          });
    });
  }

  /// Complete Standard Location phase after 1 minute
  Future<void> _completeStandardLocationPhase() async {
    if (!_isInStandardPhase) return;

    _isInStandardPhase = false;
    log('🏁 Standard GPS phase completed after 1 minute');
    await _completeServiceWithFinalAccuracy('Standard GPS Phase - 1 minute');
  }

  /// Complete service with final accuracy
  Future<void> _completeServiceWithFinalAccuracy(String phase) async {
    try {
      // Get the final accuracy from the latest position
      final finalAccuracy = _currentGlobalAccuracy;

      log(
        '🏁 Service completed in $phase - Final accuracy: ${finalAccuracy.toStringAsFixed(1)}m',
      );

      // Reset all phase flags first
      _isInGnssPhase = false;
      _isInFusedPhase = false;
      _isInStandardPhase = false;

      // Cancel all phase timers
      _gnssPhaseTimer?.cancel();
      _gnssPhaseTimer = null;
      _fusedPhaseTimer?.cancel();
      _fusedPhaseTimer = null;
      _standardPhaseTimer?.cancel();
      _standardPhaseTimer = null;
      _standardLocationUpdateTimer?.cancel();
      _standardLocationUpdateTimer = null;

      // Stop all tracking services
      await _gnssService.stopTracking();
      await _fusedLocationService.stopTracking();

      // Set tracking to false
      _isTracking = false;

      // Clear position history
      _clearPositionHistory();

      // Emit completion event
      _addEvent(SmartLocationEvent.serviceCompleted(finalAccuracy));

      log('✅ Service fully stopped and completed');
    } catch (e) {
      log('Error completing service: $e');
    }
  }

  /// Update method description
  void _updateMethodDescription(String method, String status) {
    _currentMethodDescription = '$method - $status';
    log('Method: $_currentMethodDescription');
  }

  /// Switch to a new provider
  void _switchToProvider(LocationProvider newProvider, String reason) {
    if (_currentProvider != newProvider) {
      _isSwitchingProvider = true;
      _lastSwitchReason = reason;
      _lastProviderSwitch = DateTime.now();
      _currentProvider = newProvider;

      log('🔄 Provider switched to: $newProvider - Reason: $reason');

      // Clear position history when switching away from Fused Location
      if (_currentProvider != LocationProvider.fusedLocation) {
        _clearPositionHistory();
      }

      _addEvent(SmartLocationEvent.providerSwitched(newProvider, reason));

      // Reset switching flag after a short delay
      Timer(const Duration(milliseconds: 500), () {
        _isSwitchingProvider = false;
      });
    }
  }

  /// Initialize the smart location service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize GNSS service
      final gnssInitialized = await _gnssService.initialize();
      if (gnssInitialized) {
        log('GNSS service initialized successfully');
        _gnssEventSubscription = _gnssService.eventStream.listen(
          _handleGnssEvent,
        );
      } else {
        log('GNSS service initialization failed');
      }

      // Initialize Fused Location service
      final fusedInitialized = await _fusedLocationService.initialize();
      if (fusedInitialized) {
        log('Fused Location service initialized successfully');
        _fusedLocationEventSubscription = _fusedLocationService.eventStream
            .listen(_handleFusedLocationEvent);
      } else {
        log('Fused Location service initialization failed');
      }

      _isInitialized = true;
      log('Smart Location Service initialized');
      return true;
    } catch (e) {
      log('Failed to initialize Smart Location Service: $e');
      return false;
    }
  }

  /// Get current position with intelligent 3-tier fallback strategy:
  /// 1. GNSS (15s timeout, 9+ satellites required)
  /// 2. Fused Location (best for navigation)
  /// 3. Standard LocationService
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(minutes: 2),
    int? minSatellites,
    double? minAccuracy,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Use custom thresholds if provided
    final satellitesRequired = minSatellites ?? _minSatellitesRequired;
    final accuracyThreshold = minAccuracy ?? _minAccuracyThreshold;

    log('Starting 3-tier location fallback strategy...');

    // TIER 1: Try GNSS with best settings (15s timeout, 9+ satellites)
    log('TIER 1: Attempting GNSS with $satellitesRequired+ satellites...');
    _updateMethodDescription(
      'GNSS ($satellitesRequired+ satellites)',
      'Attempting GNSS fix...',
    );

    try {
      final position = await _getPositionFromGnss(
        _gnssTimeout,
        satellitesRequired,
        accuracyThreshold,
      );
      if (position != null) {
        _switchToProvider(
          LocationProvider.gnss,
          'GNSS successful - $satellitesRequired+ satellites available',
        );
        _currentPosition = position;
        _addEvent(
          SmartLocationEvent.positionUpdate(position, LocationProvider.gnss),
        );
        log(
          '✅ GNSS SUCCESS: Got position with ${_currentGnssStatus?.satellitesInUse ?? 0} satellites',
        );
        return position;
      }
    } catch (e) {
      log('❌ GNSS FAILED: $e');
    }

    // TIER 2: Fallback to Fused Location with best for navigation
    log(
      'TIER 2: GNSS failed, switching to Fused Location (best for navigation)...',
    );
    _updateMethodDescription(
      'Fused Location (Best for Navigation)',
      'GNSS failed - using Fused Location...',
    );

    try {
      final position = await _getPositionFromFusedLocation(
        _fusedLocationTimeout,
        accuracy: LocationAccuracy.bestForNavigation,
      );
      _switchToProvider(
        LocationProvider.fusedLocation,
        'GNSS failed - insufficient satellites (<$satellitesRequired)',
      );
      _currentPosition = position;
      _addEvent(
        SmartLocationEvent.positionUpdate(
          position,
          LocationProvider.fusedLocation,
        ),
      );
      log(
        '✅ FUSED LOCATION SUCCESS: Got position with ${position.accuracy.toStringAsFixed(1)}m accuracy',
      );
      return position;
    } catch (e) {
      log('❌ FUSED LOCATION FAILED: $e');
    }

    // TIER 3: Final fallback to standard LocationService
    log('TIER 3: Fused Location failed, using standard LocationService...');
    _updateMethodDescription(
      'Standard Location Service',
      'Fused Location failed - using standard service...',
    );

    try {
      final position = await _locationService.getCurrentPositionWithFallback(
        timeout: _standardLocationTimeout,
      );
      _switchToProvider(
        LocationProvider.standard,
        'Fused Location failed - using standard location service',
      );
      _currentPosition = position;
      _addEvent(
        SmartLocationEvent.positionUpdate(position, LocationProvider.standard),
      );
      log(
        '✅ STANDARD LOCATION SUCCESS: Got position with ${position.accuracy.toStringAsFixed(1)}m accuracy',
      );
      return position;
    } catch (e) {
      log('❌ ALL LOCATION PROVIDERS FAILED: $e');
      _updateMethodDescription(
        'All Methods Failed',
        'All location providers failed',
      );
      throw Exception('All location providers failed');
    }
  }

  /// Start intelligent location tracking with structured phase approach
  Future<bool> startTracking({
    Duration updateInterval = const Duration(seconds: 1),
    int? minSatellites,
    double? minAccuracy,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isTracking) return true;

    // Use custom thresholds if provided
    final satellitesRequired = minSatellites ?? _minSatellitesRequired;

    _isTracking = true;
    _clearPositionHistory(); // Clear history when starting tracking
    log('🚀 Starting structured location tracking...');

    // PHASE 1: Start with GNSS for 30 seconds
    log('PHASE 1: Starting GNSS tracking for 30 seconds...');
    _updateMethodDescription(
      'GNSS Phase (30s)',
      'Testing GNSS with $satellitesRequired+ satellites...',
    );

    final gnssStarted = await _gnssService.startTracking();
    if (gnssStarted) {
      _isInGnssPhase = true;
      _switchToProvider(
        LocationProvider.gnss,
        'GNSS phase started - testing for 30 seconds',
      );
      _addEvent(SmartLocationEvent.trackingStarted(LocationProvider.gnss));

      // Start 30-second GNSS phase timer
      _gnssPhaseTimer = Timer(const Duration(seconds: 30), () {
        _evaluateGnssPhase(satellitesRequired);
      });

      return true;
    }

    // If GNSS fails to start, go directly to Fused Location
    log('❌ GNSS failed to start, going directly to Fused Location...');
    return await _startFusedLocationPhase();
  }

  /// Stop location tracking
  Future<bool> stopTracking() async {
    if (!_isTracking) return true;

    _isTracking = false;
    _clearPositionHistory(); // Clear history when stopping tracking

    // Cancel all phase timers
    _gnssPhaseTimer?.cancel();
    _gnssPhaseTimer = null;
    _fusedPhaseTimer?.cancel();
    _fusedPhaseTimer = null;
    _standardPhaseTimer?.cancel();
    _standardPhaseTimer = null;
    _standardLocationUpdateTimer?.cancel();
    _standardLocationUpdateTimer = null;

    // Reset all phase flags
    _isInGnssPhase = false;
    _isInFusedPhase = false;
    _isInStandardPhase = false;

    // Stop all tracking
    await _gnssService.stopTracking();
    await _fusedLocationService.stopTracking();

    _addEvent(SmartLocationEvent.trackingStopped());
    return true;
  }

  /// Get position from GNSS with quality checks
  Future<Position?> _getPositionFromGnss(
    Duration timeout,
    int minSatellites,
    double minAccuracy,
  ) async {
    try {
      // Start GNSS tracking temporarily
      final started = await _gnssService.startTracking();
      if (!started) return null;

      // Wait for first fix with timeout
      final completer = Completer<Position?>();
      late StreamSubscription subscription;

      subscription = _gnssService.eventStream.listen((event) {
        if (event is SatelliteStatusEvent) {
          final status = event.status;
          _currentGnssStatus = status;

          // Check if we have enough satellites and good accuracy
          if (status.satellitesInView >= minSatellites &&
              status.accuracy <= minAccuracy &&
              (status.fixType == GnssFixType.fix3D ||
                  status.fixType == GnssFixType.fix2D)) {
            final position = Position(
              latitude: status.latitude,
              longitude: status.longitude,
              timestamp: status.timestamp,
              accuracy: status.accuracy,
              altitude: status.altitude,
              heading: status.bearing,
              speed: status.speed,
              speedAccuracy: status.altitudeAccuracy,
              altitudeAccuracy: status.altitudeAccuracy,
              headingAccuracy: 0.0,
              isMocked: status.isMocked,
            );

            subscription.cancel();
            completer.complete(position);
          }
        }
      });

      // Timeout handling
      Timer(timeout, () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(null);
        }
      });

      return await completer.future;
    } catch (e) {
      log('Error getting position from GNSS: $e');
      return null;
    }
  }

  /// Get position from Fused Location
  Future<Position> _getPositionFromFusedLocation(
    Duration timeout, {
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
  }) async {
    return await _fusedLocationService.getCurrentPosition(
      timeout: timeout,
      accuracy: accuracy,
    );
  }

  /// Handle GNSS events
  void _handleGnssEvent(GnssEvent event) {
    if (_eventController.isClosed) return;

    switch (event.runtimeType) {
      case SatelliteStatusEvent:
        final statusEvent = event as SatelliteStatusEvent;
        _currentGnssStatus = statusEvent.status;

        // Update global accuracy for GNSS
        if (_currentProvider == LocationProvider.gnss) {
          _currentGlobalAccuracy = statusEvent.status.accuracy;
        }

        if (!_eventController.isClosed) {
          _addEvent(SmartLocationEvent.gnssStatusUpdate(statusEvent.status));
        }
        break;
      case LocationUpdateEvent:
        final locationEvent = event as LocationUpdateEvent;
        if (!_eventController.isClosed) {
          _addEvent(
            SmartLocationEvent.gnssLocationUpdate(locationEvent.location),
          );
        }
        break;
    }
  }

  /// Handle Fused Location events
  void _handleFusedLocationEvent(FusedLocationEvent event) {
    if (_eventController.isClosed) return;

    switch (event.runtimeType) {
      case PositionUpdateEvent:
        final positionEvent = event as PositionUpdateEvent;
        _currentPosition = positionEvent.position;

        // Add position to history for Fused Location
        if (_currentProvider == LocationProvider.fusedLocation) {
          _addPositionToHistory(positionEvent.position);
        }

        if (!_eventController.isClosed) {
          _addEvent(
            SmartLocationEvent.positionUpdate(
              positionEvent.position,
              LocationProvider.fusedLocation,
            ),
          );
        }
        break;
    }
  }

  /// Configure service parameters
  void configure({
    int? minSatellitesRequired,
    double? minAccuracyThreshold,
    Duration? gnssTimeout,
    Duration? fusedLocationTimeout,
    Duration? standardLocationTimeout,
  }) {
    if (minSatellitesRequired != null)
      _minSatellitesRequired = minSatellitesRequired;
    if (minAccuracyThreshold != null)
      _minAccuracyThreshold = minAccuracyThreshold;
    if (gnssTimeout != null) _gnssTimeout = gnssTimeout;
    if (fusedLocationTimeout != null)
      _fusedLocationTimeout = fusedLocationTimeout;
    if (standardLocationTimeout != null)
      _standardLocationTimeout = standardLocationTimeout;
  }

  /// Dispose resources
  void dispose() {
    _isTracking = false;
    _clearPositionHistory(); // Clear history when disposing

    // Cancel all phase timers
    _gnssPhaseTimer?.cancel();
    _fusedPhaseTimer?.cancel();
    _standardPhaseTimer?.cancel();
    _standardLocationUpdateTimer?.cancel();

    _gnssEventSubscription?.cancel();
    _fusedLocationEventSubscription?.cancel();
    _gnssService.dispose();
    _fusedLocationService.dispose();
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    _isInitialized = false;
  }
}

/// Location Provider types
enum LocationProvider { gnss, fusedLocation, standard }

/// Smart Location Event types
abstract class SmartLocationEvent {
  const SmartLocationEvent();

  factory SmartLocationEvent.trackingStarted(LocationProvider provider) =
      TrackingStartedEvent;
  factory SmartLocationEvent.trackingStopped() = TrackingStoppedEvent;
  factory SmartLocationEvent.positionUpdate(
    Position position,
    LocationProvider provider,
  ) = PositionUpdateEvent;
  factory SmartLocationEvent.providerSwitched(
    LocationProvider newProvider,
    String reason,
  ) = ProviderSwitchedEvent;
  factory SmartLocationEvent.gnssStatusUpdate(GnssStatus status) =
      GnssStatusUpdateEvent;
  factory SmartLocationEvent.gnssLocationUpdate(Map<String, dynamic> location) =
      GnssLocationUpdateEvent;
  factory SmartLocationEvent.serviceCompleted(double finalAccuracy) =
      ServiceCompletedEvent;
}

class TrackingStartedEvent extends SmartLocationEvent {
  final LocationProvider provider;
  const TrackingStartedEvent(this.provider);
}

class TrackingStoppedEvent extends SmartLocationEvent {
  const TrackingStoppedEvent();
}

class PositionUpdateEvent extends SmartLocationEvent {
  final Position position;
  final LocationProvider provider;
  const PositionUpdateEvent(this.position, this.provider);
}

class ProviderSwitchedEvent extends SmartLocationEvent {
  final LocationProvider newProvider;
  final String reason;
  const ProviderSwitchedEvent(this.newProvider, this.reason);
}

class GnssStatusUpdateEvent extends SmartLocationEvent {
  final GnssStatus status;
  const GnssStatusUpdateEvent(this.status);
}

class GnssLocationUpdateEvent extends SmartLocationEvent {
  final Map<String, dynamic> location;
  const GnssLocationUpdateEvent(this.location);
}

class ServiceCompletedEvent extends SmartLocationEvent {
  final double finalAccuracy;
  const ServiceCompletedEvent(this.finalAccuracy);
}
