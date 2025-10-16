import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Fused Location Provider Service using Google Play Services
/// Provides high-accuracy location using multiple sources (GPS, WiFi, Cell towers)
/// Acts as a fallback when GNSS has insufficient satellites
class FusedLocationService {
  static final FusedLocationService _instance =
      FusedLocationService._internal();
  factory FusedLocationService() => _instance;
  FusedLocationService._internal();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.testgps/fused_location',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.testgps/fused_location_events',
  );

  StreamSubscription<dynamic>? _eventSubscription;
  StreamController<FusedLocationEvent> _eventController =
      StreamController<FusedLocationEvent>.broadcast();

  bool _isInitialized = false;
  bool _isTracking = false;
  Position? _currentPosition;
  LocationAccuracy? _currentAccuracy;

  /// Stream of fused location events
  Stream<FusedLocationEvent> get eventStream => _eventController.stream;

  /// Current position from fused location
  Position? get currentPosition => _currentPosition;

  /// Current accuracy level
  LocationAccuracy? get currentAccuracy => _currentAccuracy;

  /// Whether fused location tracking is active
  bool get isTracking => _isTracking;

  /// Whether service is initialized
  bool get isInitialized => _isInitialized;

  /// Helper method to safely add events to the stream
  void _addEvent(FusedLocationEvent event) {
    log(
      'Service: Adding event to stream: ${event.runtimeType}, controller closed: ${_eventController.isClosed}',
    );
    if (!_eventController.isClosed) {
      _eventController.add(event);
      log('Service: Event added to stream successfully');
    } else {
      log('Service: Event controller is closed, recreating stream controller');
      // Recreate the stream controller if it's closed
      _eventController = StreamController<FusedLocationEvent>.broadcast();
      _eventController.add(event);
      log('Service: Event added to new stream controller');
    }
  }

  /// Initialize the fused location service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check if Google Play Services is available
      final isAvailable = await _methodChannel.invokeMethod<bool>(
        'isGooglePlayServicesAvailable',
      );
      if (isAvailable != true) {
        log('Google Play Services not available for Fused Location Provider');
        return false;
      }

      // Set up event channel listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) {
          log('Fused location event error: $error');
          _eventController.addError(error);
        },
      );

      _isInitialized = true;
      log('Fused Location Service initialized successfully');
      return true;
    } catch (e) {
      log('Failed to initialize Fused Location Service: $e');
      return false;
    }
  }

  /// Get current position using fused location provider
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(minutes: 2),
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw Exception('Fused Location Service not available');
      }
    }

    try {
      final result = await _methodChannel
          .invokeMethod<Map<dynamic, dynamic>>('getCurrentPosition', {
            'timeout': timeout.inMilliseconds,
            'accuracy': _locationAccuracyToString(accuracy),
          });

      if (result != null) {
        final position = _mapToPosition(Map<String, dynamic>.from(result));
        _currentPosition = position;
        _currentAccuracy = accuracy;
        _addEvent(FusedLocationEvent.positionUpdate(position));
        return position;
      } else {
        throw Exception('No position received from fused location provider');
      }
    } catch (e) {
      log('Error getting current position from fused location: $e');
      rethrow;
    }
  }

  /// Start fused location tracking
  Future<bool> startTracking({
    Duration updateInterval = const Duration(seconds: 1),
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
  }) async {
    log(
      'Service: startTracking() called - updateInterval: $updateInterval, accuracy: $accuracy',
    );

    if (!_isInitialized) {
      log('Service: Not initialized, initializing first...');
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isTracking) {
      log('Service: Already tracking, returning true');
      return true;
    }

    try {
      log('Service: Calling native startLocationUpdates...');
      final result = await _methodChannel
          .invokeMethod<bool>('startLocationUpdates', {
            'updateInterval': updateInterval.inMilliseconds,
            'accuracy': _locationAccuracyToString(accuracy),
          });
      _isTracking = result ?? false;

      if (_isTracking) {
        log('Fused location tracking started successfully');
        _currentAccuracy = accuracy;
        _addEvent(FusedLocationEvent.trackingStarted());
      } else {
        log('Failed to start fused location tracking');
      }

      return _isTracking;
    } catch (e) {
      log('Error starting fused location tracking: $e');
      return false;
    }
  }

  /// Stop fused location tracking
  Future<bool> stopTracking() async {
    if (!_isTracking) return true;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'stopLocationUpdates',
      );
      _isTracking = false;

      log('Fused location tracking stopped');
      _addEvent(FusedLocationEvent.trackingStopped());
      return result ?? true;
    } catch (e) {
      log('Error stopping fused location tracking: $e');
      return false;
    }
  }

  /// Check if Google Play Services is available
  Future<bool> isGooglePlayServicesAvailable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isGooglePlayServicesAvailable',
      );
      return result ?? false;
    } catch (e) {
      log('Error checking Google Play Services availability: $e');
      return false;
    }
  }

  /// Get location settings status
  Future<LocationSettingsStatus> getLocationSettingsStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getLocationSettingsStatus',
      );
      if (result != null) {
        return LocationSettingsStatus.fromJson(
          Map<String, dynamic>.from(result),
        );
      }
    } catch (e) {
      log('Error getting location settings status: $e');
    }
    return LocationSettingsStatus(
      isLocationEnabled: false,
      isGpsEnabled: false,
      isNetworkEnabled: false,
      isPassiveEnabled: false,
    );
  }

  /// Request location settings changes
  Future<bool> requestLocationSettings({
    bool needBle = false,
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestLocationSettings',
        {'needBle': needBle, 'accuracy': _locationAccuracyToString(accuracy)},
      );
      return result ?? false;
    } catch (e) {
      log('Error requesting location settings: $e');
      return false;
    }
  }

  /// Request high accuracy location settings
  Future<bool> requestHighAccuracySettings() async {
    return await requestLocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      needBle: false,
    );
  }

  /// Handle events from native service
  void _handleEvent(dynamic event) {
    try {
      log('Raw fused location event received: $event');

      // Safely convert the event to Map<String, dynamic>
      Map<String, dynamic> eventData;
      if (event is Map) {
        eventData = Map<String, dynamic>.from(event);
      } else {
        log('Invalid event type: ${event.runtimeType}');
        return;
      }

      final String eventType = eventData['eventType'] as String;
      final dynamic data = eventData['data'];

      log('Received fused location event: $eventType with data: $data');

      switch (eventType) {
        case 'positionUpdate':
          _handlePositionUpdate(data);
          break;
        case 'locationSettingsChanged':
          _handleLocationSettingsChanged(data);
          break;
        case 'error':
          _handleError(data);
          break;
        default:
          log('Unknown fused location event type: $eventType');
      }
    } catch (e) {
      log('Error handling fused location event: $e');
    }
  }

  /// Handle position updates
  void _handlePositionUpdate(dynamic data) {
    try {
      if (data is Map) {
        final position = _mapToPosition(Map<String, dynamic>.from(data));
        _currentPosition = position;
        _addEvent(FusedLocationEvent.positionUpdate(position));
      }
    } catch (e) {
      log('Error handling position update: $e');
    }
  }

  /// Handle location settings changes
  void _handleLocationSettingsChanged(dynamic data) {
    try {
      if (data is Map) {
        final status = LocationSettingsStatus.fromJson(
          Map<String, dynamic>.from(data),
        );
        _addEvent(FusedLocationEvent.locationSettingsChanged(status));
      }
    } catch (e) {
      log('Error handling location settings change: $e');
    }
  }

  /// Handle errors
  void _handleError(dynamic data) {
    try {
      final errorMessage = data is String ? data : data.toString();
      _addEvent(FusedLocationEvent.error(errorMessage));
    } catch (e) {
      log('Error handling error event: $e');
    }
  }

  /// Convert location accuracy to string
  String _locationAccuracyToString(LocationAccuracy accuracy) {
    switch (accuracy) {
      case LocationAccuracy.lowest:
        return 'lowest';
      case LocationAccuracy.low:
        return 'low';
      case LocationAccuracy.medium:
        return 'medium';
      case LocationAccuracy.high:
        return 'high';
      case LocationAccuracy.best:
        return 'best';
      case LocationAccuracy.bestForNavigation:
        return 'bestForNavigation';
      default:
        return 'high';
    }
  }

  /// Convert map to Position object
  Position _mapToPosition(Map<String, dynamic> data) {
    return Position(
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
      accuracy: (data['accuracy'] as num).toDouble(),
      altitude: (data['altitude'] as num?)?.toDouble() ?? 0.0,
      heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
      speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
      speedAccuracy: (data['speedAccuracy'] as num?)?.toDouble() ?? 0.0,
      altitudeAccuracy: (data['altitudeAccuracy'] as num?)?.toDouble() ?? 0.0,
      headingAccuracy: (data['headingAccuracy'] as num?)?.toDouble() ?? 0.0,
      isMocked: data['isMocked'] as bool? ?? false,
    );
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _eventSubscription?.cancel();
    // Don't close the stream controller as this is a singleton service
    // and other parts of the app might still need it
    _isInitialized = false;
  }

  /// Force close the service (use with caution)
  void forceDispose() {
    stopTracking();
    _eventSubscription?.cancel();
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    _isInitialized = false;
  }
}

/// Fused Location Event types
abstract class FusedLocationEvent {
  const FusedLocationEvent();

  factory FusedLocationEvent.trackingStarted() = TrackingStartedEvent;
  factory FusedLocationEvent.trackingStopped() = TrackingStoppedEvent;
  factory FusedLocationEvent.positionUpdate(Position position) =
      PositionUpdateEvent;
  factory FusedLocationEvent.locationSettingsChanged(
    LocationSettingsStatus status,
  ) = LocationSettingsChangedEvent;
  factory FusedLocationEvent.error(String error) = ErrorEvent;
}

class TrackingStartedEvent extends FusedLocationEvent {
  const TrackingStartedEvent();
}

class TrackingStoppedEvent extends FusedLocationEvent {
  const TrackingStoppedEvent();
}

class PositionUpdateEvent extends FusedLocationEvent {
  final Position position;
  const PositionUpdateEvent(this.position);
}

class LocationSettingsChangedEvent extends FusedLocationEvent {
  final LocationSettingsStatus status;
  const LocationSettingsChangedEvent(this.status);
}

class ErrorEvent extends FusedLocationEvent {
  final String error;
  const ErrorEvent(this.error);
}

/// Location Settings Status
class LocationSettingsStatus {
  final bool isLocationEnabled;
  final bool isGpsEnabled;
  final bool isNetworkEnabled;
  final bool isPassiveEnabled;

  const LocationSettingsStatus({
    required this.isLocationEnabled,
    required this.isGpsEnabled,
    required this.isNetworkEnabled,
    required this.isPassiveEnabled,
  });

  factory LocationSettingsStatus.fromJson(Map<String, dynamic> json) {
    return LocationSettingsStatus(
      isLocationEnabled: json['isLocationEnabled'] as bool? ?? false,
      isGpsEnabled: json['isGpsEnabled'] as bool? ?? false,
      isNetworkEnabled: json['isNetworkEnabled'] as bool? ?? false,
      isPassiveEnabled: json['isPassiveEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLocationEnabled': isLocationEnabled,
      'isGpsEnabled': isGpsEnabled,
      'isNetworkEnabled': isNetworkEnabled,
      'isPassiveEnabled': isPassiveEnabled,
    };
  }

  @override
  String toString() {
    return 'LocationSettingsStatus(isLocationEnabled: $isLocationEnabled, isGpsEnabled: $isGpsEnabled, isNetworkEnabled: $isNetworkEnabled, isPassiveEnabled: $isPassiveEnabled)';
  }
}
