import 'dart:async';
import 'dart:developer';
import 'package:geolocator/geolocator.dart';
import 'package:testgps/services/gnss_native_service.dart';
import 'package:testgps/services/fused_location_service.dart';
import 'package:testgps/location_service.dart';
import 'package:testgps/models/gnss_models.dart';

/// Smart Location Service that intelligently switches between GNSS and Fused Location
/// based on satellite availability and accuracy requirements
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

  // Configuration
  int _minSatellitesRequired = 100;
  double _minAccuracyThreshold = 60.0; // meters
  Duration _gnssTimeout = const Duration(seconds: 30);
  Duration _fusedLocationTimeout = const Duration(seconds: 15);

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

  /// Helper method to safely add events to the stream
  void _addEvent(SmartLocationEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
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

  /// Get current position with intelligent provider selection
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(minutes: 2),
    bool preferGnss = false,
    int? minSatellites,
    double? minAccuracy,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Use custom thresholds if provided
    final satellitesRequired = minSatellites ?? _minSatellitesRequired;
    final accuracyThreshold = minAccuracy ?? _minAccuracyThreshold;

    if (preferGnss) {
      // Try GNSS first
      try {
        final position = await _getPositionFromGnss(
          timeout,
          satellitesRequired,
          accuracyThreshold,
        );
        if (position != null) {
          _currentProvider = LocationProvider.gnss;
          _currentPosition = position;
          _addEvent(
            SmartLocationEvent.positionUpdate(position, LocationProvider.gnss),
          );
          return position;
        }
      } catch (e) {
        log('GNSS position failed: $e');
      }

      // Fallback to Fused Location
      try {
        final position = await _getPositionFromFusedLocation(
          _fusedLocationTimeout,
        );
        _currentProvider = LocationProvider.fusedLocation;
        _currentPosition = position;
        _addEvent(
          SmartLocationEvent.positionUpdate(
            position,
            LocationProvider.fusedLocation,
          ),
        );
        _addEvent(
          SmartLocationEvent.providerSwitched(
            LocationProvider.fusedLocation,
            'GNSS failed - insufficient satellites or accuracy',
          ),
        );
        return position;
      } catch (e) {
        log('Fused Location position failed: $e');
      }
    } else {
      // Try Fused Location first
      try {
        final position = await _getPositionFromFusedLocation(timeout);
        _currentProvider = LocationProvider.fusedLocation;
        _currentPosition = position;
        _addEvent(
          SmartLocationEvent.positionUpdate(
            position,
            LocationProvider.fusedLocation,
          ),
        );
        return position;
      } catch (e) {
        log('Fused Location position failed: $e');
      }

      // Fallback to GNSS
      try {
        final position = await _getPositionFromGnss(
          _gnssTimeout,
          satellitesRequired,
          accuracyThreshold,
        );
        if (position != null) {
          _currentProvider = LocationProvider.gnss;
          _currentPosition = position;
          _addEvent(
            SmartLocationEvent.positionUpdate(position, LocationProvider.gnss),
          );
          _addEvent(
            SmartLocationEvent.providerSwitched(
              LocationProvider.gnss,
              'Fused Location failed - falling back to GNSS',
            ),
          );
          return position;
        }
      } catch (e) {
        log('GNSS position failed: $e');
      }
    }

    // Final fallback to standard location service
    try {
      final position = await _locationService.getCurrentPositionWithFallback(
        timeout: timeout,
      );
      _currentProvider = LocationProvider.standard;
      _currentPosition = position;
      _addEvent(
        SmartLocationEvent.positionUpdate(position, LocationProvider.standard),
      );
      _addEvent(
        SmartLocationEvent.providerSwitched(
          LocationProvider.standard,
          'All advanced providers failed - using standard location service',
        ),
      );
      return position;
    } catch (e) {
      log('All location providers failed: $e');
      rethrow;
    }
  }

  /// Start intelligent location tracking
  Future<bool> startTracking({
    Duration updateInterval = const Duration(seconds: 1),
    bool preferGnss = true,
    int? minSatellites,
    double? minAccuracy,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isTracking) return true;

    // Use custom thresholds if provided
    final satellitesRequired = minSatellites ?? _minSatellitesRequired;
    final accuracyThreshold = minAccuracy ?? _minAccuracyThreshold;

    _isTracking = true;

    if (preferGnss) {
      // Start with GNSS tracking
      final gnssStarted = await _gnssService.startTracking();
      if (gnssStarted) {
        _currentProvider = LocationProvider.gnss;
        _addEvent(SmartLocationEvent.trackingStarted(LocationProvider.gnss));

        // Monitor GNSS quality and switch if needed
        _monitorGnssQuality(satellitesRequired, accuracyThreshold);
        return true;
      } else {
        // Fallback to Fused Location
        final fusedStarted = await _fusedLocationService.startTracking(
          updateInterval: updateInterval,
        );
        if (fusedStarted) {
          _currentProvider = LocationProvider.fusedLocation;
          _addEvent(
            SmartLocationEvent.trackingStarted(LocationProvider.fusedLocation),
          );
          _addEvent(
            SmartLocationEvent.providerSwitched(
              LocationProvider.fusedLocation,
              'GNSS tracking failed - using Fused Location',
            ),
          );
          return true;
        }
      }
    } else {
      // Start with Fused Location
      final fusedStarted = await _fusedLocationService.startTracking(
        updateInterval: updateInterval,
      );
      if (fusedStarted) {
        _currentProvider = LocationProvider.fusedLocation;
        _addEvent(
          SmartLocationEvent.trackingStarted(LocationProvider.fusedLocation),
        );
        return true;
      } else {
        // Fallback to GNSS
        final gnssStarted = await _gnssService.startTracking();
        if (gnssStarted) {
          _currentProvider = LocationProvider.gnss;
          _addEvent(SmartLocationEvent.trackingStarted(LocationProvider.gnss));
          _addEvent(
            SmartLocationEvent.providerSwitched(
              LocationProvider.gnss,
              'Fused Location tracking failed - using GNSS',
            ),
          );
          _monitorGnssQuality(satellitesRequired, accuracyThreshold);
          return true;
        }
      }
    }

    _isTracking = false;
    return false;
  }

  /// Stop location tracking
  Future<bool> stopTracking() async {
    if (!_isTracking) return true;

    _isTracking = false;

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
  Future<Position> _getPositionFromFusedLocation(Duration timeout) async {
    return await _fusedLocationService.getCurrentPosition(timeout: timeout);
  }

  /// Monitor GNSS quality and switch providers if needed
  void _monitorGnssQuality(int minSatellites, double minAccuracy) {
    if (!_isTracking) return;

    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isTracking) {
        timer.cancel();
        return;
      }

      final status = _currentGnssStatus;
      if (status != null) {
        // Check if GNSS quality is poor
        if (status.satellitesInView < minSatellites ||
            status.accuracy > minAccuracy ||
            (status.fixType != GnssFixType.fix3D &&
                status.fixType != GnssFixType.fix2D)) {
          log('GNSS quality poor - switching to Fused Location');
          _switchToFusedLocation();
          timer.cancel();
        }
      }
    });
  }

  /// Switch to Fused Location provider
  Future<void> _switchToFusedLocation() async {
    if (_currentProvider == LocationProvider.fusedLocation) return;

    try {
      // Stop GNSS tracking
      await _gnssService.stopTracking();

      // Start Fused Location tracking
      final started = await _fusedLocationService.startTracking();
      if (started) {
        _currentProvider = LocationProvider.fusedLocation;
        _addEvent(
          SmartLocationEvent.providerSwitched(
            LocationProvider.fusedLocation,
            'GNSS quality poor - switched to Fused Location',
          ),
        );
      }
    } catch (e) {
      log('Error switching to Fused Location: $e');
    }
  }

  /// Handle GNSS events
  void _handleGnssEvent(GnssEvent event) {
    if (_eventController.isClosed) return;

    switch (event.runtimeType) {
      case SatelliteStatusEvent:
        final statusEvent = event as SatelliteStatusEvent;
        _currentGnssStatus = statusEvent.status;
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
  }) {
    if (minSatellitesRequired != null)
      _minSatellitesRequired = minSatellitesRequired;
    if (minAccuracyThreshold != null)
      _minAccuracyThreshold = minAccuracyThreshold;
    if (gnssTimeout != null) _gnssTimeout = gnssTimeout;
    if (fusedLocationTimeout != null)
      _fusedLocationTimeout = fusedLocationTimeout;
  }

  /// Dispose resources
  void dispose() {
    _isTracking = false;
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
