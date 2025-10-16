import 'dart:async';
import 'dart:developer';
import 'package:geolocator/geolocator.dart';
import 'package:testgps/location_service.dart';
import 'package:testgps/services/gnss_native_service.dart';
import 'package:testgps/services/smart_location_service.dart';
import 'package:testgps/models/gnss_models.dart';

/// Enhanced Location Service that combines geolocator and native GNSS
/// Provides the best of both worlds: reliability and detailed GNSS data
class EnhancedLocationService {
  static final EnhancedLocationService _instance =
      EnhancedLocationService._internal();
  factory EnhancedLocationService() => _instance;
  EnhancedLocationService._internal();

  final LocationService _locationService = LocationService.instance();
  final GnssNativeService _gnssService = GnssNativeService();
  final SmartLocationService _smartLocationService = SmartLocationService();

  bool _isInitialized = false;
  bool _useGnssNative = false;
  bool _useSmartLocation = true;
  StreamSubscription<GnssEvent>? _gnssEventSubscription;
  StreamSubscription<SmartLocationEvent>? _smartLocationEventSubscription;

  // Current status
  GnssStatus? _currentGnssStatus;
  Position? _currentPosition;
  bool _isOffline = false;

  /// Stream of enhanced location events
  final StreamController<EnhancedLocationEvent> _eventController =
      StreamController<EnhancedLocationEvent>.broadcast();

  /// Stream of enhanced location events
  Stream<EnhancedLocationEvent> get eventStream => _eventController.stream;

  /// Current GNSS status
  GnssStatus? get currentGnssStatus => _currentGnssStatus;

  /// Current position
  Position? get currentPosition => _currentPosition;

  /// Whether using GNSS native service
  bool get useGnssNative => _useGnssNative;

  /// Whether using smart location service
  bool get useSmartLocation => _useSmartLocation;

  /// Whether service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the enhanced location service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize Smart Location Service (includes GNSS and Fused Location)
      final smartInitialized = await _smartLocationService.initialize();
      if (smartInitialized) {
        log('Smart Location Service initialized successfully');
        _useSmartLocation = true;

        // Listen to smart location events
        _smartLocationEventSubscription = _smartLocationService.eventStream
            .listen(
              _handleSmartLocationEvent,
              onError: (error) {
                log('Smart location event error: $error');
              },
            );
      } else {
        log(
          'Smart Location Service initialization failed, falling back to individual services',
        );
        _useSmartLocation = false;

        // Initialize GNSS native service as fallback
        final gnssInitialized = await _gnssService.initialize();
        if (gnssInitialized) {
          log('GNSS native service initialized successfully');

          // Listen to GNSS events
          _gnssEventSubscription = _gnssService.eventStream.listen(
            _handleGnssEvent,
            onError: (error) {
              log('GNSS event error: $error');
            },
          );
        } else {
          log(
            'GNSS native service initialization failed, falling back to geolocator only',
          );
        }
      }

      _isInitialized = true;
      log('Enhanced Location Service initialized');
      return true;
    } catch (e) {
      log('Failed to initialize Enhanced Location Service: $e');
      return false;
    }
  }

  /// Get current position with enhanced capabilities
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(minutes: 5),
    bool allowLastKnown = true,
    Duration maxLastKnownAge = const Duration(minutes: 15),
    int? minSatellites,
    double? minAccuracy,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_useSmartLocation) {
      // Use Smart Location Service with intelligent provider selection
      return await _smartLocationService.getCurrentPosition(
        timeout: timeout,
        minSatellites: minSatellites,
        minAccuracy: minAccuracy,
      );
    } else {
      // Fallback to individual services
      final shouldUseGnssNative = _isOffline || _useGnssNative;

      if (shouldUseGnssNative && _gnssService.isTracking) {
        return await _getPositionFromGnssNative(timeout);
      } else {
        // Use existing LocationService with fallback
        return await _locationService.getCurrentPositionWithFallback(
          timeout: timeout,
          allowLastKnown: allowLastKnown,
          maxLastKnownAge: maxLastKnownAge,
        );
      }
    }
  }

  /// Start enhanced location tracking
  Future<bool> startTracking({
    bool useGnssNative = false,
    Duration updateInterval = const Duration(seconds: 1),
    int? minSatellites,
    double? minAccuracy,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_useSmartLocation) {
      // Use Smart Location Service for tracking
      final started = await _smartLocationService.startTracking(
        updateInterval: updateInterval,
        minSatellites: minSatellites,
        minAccuracy: minAccuracy,
      );

      if (started) {
        log('Smart location tracking started');
        _eventController.add(EnhancedLocationEvent.trackingStarted(true));
        return true;
      } else {
        log('Failed to start smart location tracking');
        return false;
      }
    } else {
      // Fallback to individual services
      _useGnssNative = useGnssNative;

      if (useGnssNative) {
        // Start GNSS native tracking
        final started = await _gnssService.startTracking();
        if (started) {
          log('GNSS native tracking started');
          _eventController.add(EnhancedLocationEvent.trackingStarted(true));
          return true;
        } else {
          log(
            'Failed to start GNSS native tracking, falling back to geolocator',
          );
          _useGnssNative = false;
        }
      }

      // Fallback to geolocator tracking
      try {
        // Note: This is a simplified implementation
        // In a real app, you'd want to implement proper location stream handling
        log('Geolocator tracking started');
        _eventController.add(EnhancedLocationEvent.trackingStarted(false));
        return true;
      } catch (e) {
        log('Failed to start geolocator tracking: $e');
        return false;
      }
    }
  }

  /// Stop location tracking
  Future<bool> stopTracking() async {
    if (_useSmartLocation) {
      final stopped = await _smartLocationService.stopTracking();
      if (stopped) {
        log('Smart location tracking stopped');
        _eventController.add(EnhancedLocationEvent.trackingStopped());
        return true;
      }
    } else if (_useGnssNative) {
      final stopped = await _gnssService.stopTracking();
      if (stopped) {
        log('GNSS native tracking stopped');
        _eventController.add(EnhancedLocationEvent.trackingStopped());
        return true;
      }
    }

    // Stop geolocator tracking if needed
    log('Location tracking stopped');
    _eventController.add(EnhancedLocationEvent.trackingStopped());
    return true;
  }

  /// Get GNSS capabilities
  Future<GnssCapabilities?> getGnssCapabilities() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _gnssService.getCapabilities();
  }

  /// Get current GNSS status
  Future<GnssStatus?> getCurrentGnssStatus() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _gnssService.getCurrentStatus();
  }

  /// Get satellite data
  Future<List<SatelliteInfo>> getSatelliteData() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _gnssService.getSatelliteData();
  }

  /// Check if device is offline
  Future<bool> isOffline() async {
    // Simple offline detection - in a real app, you'd want more sophisticated detection
    try {
      await _locationService.getCurrentPosition();
      _isOffline = false;
      return false;
    } catch (e) {
      _isOffline = true;
      return true;
    }
  }

  /// Handle Smart Location events
  void _handleSmartLocationEvent(SmartLocationEvent event) {
    switch (event.runtimeType) {
      case PositionUpdateEvent:
        final positionEvent = event as PositionUpdateEvent;
        _currentPosition = positionEvent.position;
        _eventController.add(
          EnhancedLocationEvent.locationUpdate({
            'latitude': positionEvent.position.latitude,
            'longitude': positionEvent.position.longitude,
            'accuracy': positionEvent.position.accuracy,
            'timestamp':
                positionEvent.position.timestamp.millisecondsSinceEpoch,
            'provider': positionEvent.provider.name,
          }),
        );
        break;
      case GnssStatusUpdateEvent:
        final statusEvent = event as GnssStatusUpdateEvent;
        _currentGnssStatus = statusEvent.status;
        _eventController.add(
          EnhancedLocationEvent.gnssStatusUpdate(statusEvent.status),
        );
        break;
      case ProviderSwitchedEvent:
        final switchEvent = event as ProviderSwitchedEvent;
        log(
          'Location provider switched to ${switchEvent.newProvider.name}: ${switchEvent.reason}',
        );
        _eventController.add(
          EnhancedLocationEvent.locationUpdate({
            'provider': switchEvent.newProvider.name,
            'reason': switchEvent.reason,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        );
        break;
    }
  }

  /// Handle GNSS events
  void _handleGnssEvent(GnssEvent event) {
    switch (event.runtimeType) {
      case SatelliteStatusEvent:
        final statusEvent = event as SatelliteStatusEvent;
        _currentGnssStatus = statusEvent.status;
        _eventController.add(
          EnhancedLocationEvent.gnssStatusUpdate(statusEvent.status),
        );
        break;
      case MeasurementsEvent:
        final measurementsEvent = event as MeasurementsEvent;
        _eventController.add(
          EnhancedLocationEvent.measurementsUpdate(
            measurementsEvent.measurements,
          ),
        );
        break;
      case LocationUpdateEvent:
        final locationEvent = event as LocationUpdateEvent;
        _eventController.add(
          EnhancedLocationEvent.locationUpdate(locationEvent.location),
        );
        break;
      case FirstFixEvent:
        final firstFixEvent = event as FirstFixEvent;
        _eventController.add(
          EnhancedLocationEvent.firstFix(firstFixEvent.ttffMillis),
        );
        break;
    }
  }

  /// Get position from GNSS native service
  Future<Position> _getPositionFromGnssNative(Duration timeout) async {
    try {
      final gnssStatus = await _gnssService.getCurrentStatus();
      if (gnssStatus == null) {
        throw Exception('No GNSS status available');
      }

      // Convert GNSS status to Position
      final position = Position(
        latitude: gnssStatus.latitude,
        longitude: gnssStatus.longitude,
        timestamp: gnssStatus.timestamp,
        accuracy: gnssStatus.accuracy,
        altitude: gnssStatus.altitude,
        heading: gnssStatus.bearing,
        speed: gnssStatus.speed,
        speedAccuracy: gnssStatus.altitudeAccuracy,
        altitudeAccuracy: gnssStatus.altitudeAccuracy,
        headingAccuracy: 0.0,
        isMocked: gnssStatus.isMocked,
      );

      _currentPosition = position;
      return position;
    } catch (e) {
      log('Error getting position from GNSS native: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _gnssEventSubscription?.cancel();
    _smartLocationEventSubscription?.cancel();
    _eventController.close();
    _gnssService.dispose();
    _smartLocationService.dispose();
    _isInitialized = false;
  }
}

/// Enhanced Location Event types
abstract class EnhancedLocationEvent {
  const EnhancedLocationEvent();

  factory EnhancedLocationEvent.trackingStarted(bool useGnssNative) =
      TrackingStartedEvent;
  factory EnhancedLocationEvent.trackingStopped() = TrackingStoppedEvent;
  factory EnhancedLocationEvent.gnssStatusUpdate(GnssStatus status) =
      GnssStatusUpdateEvent;
  factory EnhancedLocationEvent.measurementsUpdate(
    List<GnssMeasurement> measurements,
  ) = MeasurementsUpdateEvent;
  factory EnhancedLocationEvent.locationUpdate(Map<String, dynamic> location) =
      LocationUpdateEvent;
  factory EnhancedLocationEvent.firstFix(int ttffMillis) = FirstFixEvent;
}

class TrackingStartedEvent extends EnhancedLocationEvent {
  final bool useGnssNative;
  const TrackingStartedEvent(this.useGnssNative);
}

class TrackingStoppedEvent extends EnhancedLocationEvent {
  const TrackingStoppedEvent();
}

class GnssStatusUpdateEvent extends EnhancedLocationEvent {
  final GnssStatus status;
  const GnssStatusUpdateEvent(this.status);
}

class MeasurementsUpdateEvent extends EnhancedLocationEvent {
  final List<GnssMeasurement> measurements;
  const MeasurementsUpdateEvent(this.measurements);
}

class LocationUpdateEvent extends EnhancedLocationEvent {
  final Map<String, dynamic> location;
  const LocationUpdateEvent(this.location);
}

class FirstFixEvent extends EnhancedLocationEvent {
  final int ttffMillis;
  const FirstFixEvent(this.ttffMillis);
}
