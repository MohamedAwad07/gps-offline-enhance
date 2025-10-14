import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:testgps/models/gnss_models.dart';

/// GNSS Native Service for direct access to GNSS hardware
/// Provides real-time satellite data, measurements, and positioning
class GnssNativeService {
  static final GnssNativeService _instance = GnssNativeService._internal();
  factory GnssNativeService() => _instance;
  GnssNativeService._internal();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.testgps/gnss_native',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.testgps/gnss_events',
  );

  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<GnssEvent> _eventController =
      StreamController<GnssEvent>.broadcast();

  bool _isInitialized = false;
  bool _isTracking = false;
  GnssCapabilities? _capabilities;
  GnssStatus? _currentStatus;
  final List<SatelliteInfo> _satellites = [];
  final List<GnssMeasurement> _measurements = [];

  /// Stream of GNSS events
  Stream<GnssEvent> get eventStream => _eventController.stream;

  /// Current GNSS status
  GnssStatus? get currentStatus => _currentStatus;

  /// Current satellite list
  List<SatelliteInfo> get satellites => List.unmodifiable(_satellites);

  /// Current measurements
  List<GnssMeasurement> get measurements => List.unmodifiable(_measurements);

  /// GNSS capabilities
  GnssCapabilities? get capabilities => _capabilities;

  /// Whether GNSS tracking is active
  bool get isTracking => _isTracking;

  /// Initialize the GNSS native service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Set up event channel listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) {
          log('GNSS event error: $error');
          _eventController.addError(error);
        },
      );

      // Get GNSS capabilities
      await _getCapabilities();

      _isInitialized = true;
      log('GNSS Native Service initialized successfully');
      return true;
    } catch (e) {
      log('Failed to initialize GNSS Native Service: $e');
      return false;
    }
  }

  /// Start GNSS tracking
  Future<bool> startTracking() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isTracking) return true;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'startGnssTracking',
      );
      _isTracking = result ?? false;

      if (_isTracking) {
        log('GNSS tracking started successfully');
      } else {
        log('Failed to start GNSS tracking');
      }

      return _isTracking;
    } catch (e) {
      log('Error starting GNSS tracking: $e');
      return false;
    }
  }

  /// Stop GNSS tracking
  Future<bool> stopTracking() async {
    if (!_isTracking) return true;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'stopGnssTracking',
      );
      _isTracking = false;

      log('GNSS tracking stopped');
      return result ?? true;
    } catch (e) {
      log('Error stopping GNSS tracking: $e');
      return false;
    }
  }

  /// Get GNSS capabilities
  Future<GnssCapabilities?> getCapabilities() async {
    if (_capabilities != null) return _capabilities;
    return await _getCapabilities();
  }

  /// Get current GNSS status
  Future<GnssStatus?> getCurrentStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getCurrentGnssStatus',
      );
      if (result != null) {
        _currentStatus = GnssStatus.fromJson(Map<String, dynamic>.from(result));
        return _currentStatus;
      }
    } catch (e) {
      log('Error getting current GNSS status: $e');
    }
    return null;
  }

  /// Get satellite data
  Future<List<SatelliteInfo>> getSatelliteData() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getSatelliteData',
      );
      if (result != null) {
        _satellites.clear();
        _satellites.addAll(
          result.map(
            (data) => SatelliteInfo.fromJson(Map<String, dynamic>.from(data)),
          ),
        );
        return satellites;
      }
    } catch (e) {
      log('Error getting satellite data: $e');
    }
    return [];
  }

  /// Get measurement data
  Future<List<GnssMeasurement>> getMeasurementData() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getMeasurementData',
      );
      if (result != null) {
        _measurements.clear();
        _measurements.addAll(
          result.map(
            (data) => GnssMeasurement.fromJson(Map<String, dynamic>.from(data)),
          ),
        );
        return measurements;
      }
    } catch (e) {
      log('Error getting measurement data: $e');
    }
    return [];
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _eventSubscription?.cancel();
    _eventController.close();
    _isInitialized = false;
  }

  /// Handle events from native service
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['eventType'] as String;
      final dynamic data = eventData['data'];

      switch (eventType) {
        case 'satelliteStatus':
          _handleSatelliteStatus(data);
          break;
        case 'gnssMeasurements':
          _handleGnssMeasurements(data);
          break;
        case 'locationUpdate':
          _handleLocationUpdate(data);
          break;
        case 'firstFix':
          _handleFirstFix(data);
          break;
        default:
          log('Unknown GNSS event type: $eventType');
      }
    } catch (e) {
      log('Error handling GNSS event: $e');
    }
  }

  /// Handle satellite status updates
  void _handleSatelliteStatus(dynamic data) {
    try {
      final Map<String, dynamic> statusData = Map<String, dynamic>.from(data);
      _currentStatus = GnssStatus.fromJson(statusData);

      // Update satellite list
      final List<dynamic> satellitesData =
          statusData['satellites'] as List<dynamic>;
      _satellites.clear();
      _satellites.addAll(
        satellitesData.map(
          (s) => SatelliteInfo.fromJson(Map<String, dynamic>.from(s)),
        ),
      );

      _eventController.add(GnssEvent.satelliteStatus(_currentStatus!));
    } catch (e) {
      log('Error handling satellite status: $e');
    }
  }

  /// Handle GNSS measurements
  void _handleGnssMeasurements(dynamic data) {
    try {
      final List<dynamic> measurementsData = data as List<dynamic>;
      _measurements.clear();
      _measurements.addAll(
        measurementsData.map(
          (m) => GnssMeasurement.fromJson(Map<String, dynamic>.from(m)),
        ),
      );

      _eventController.add(GnssEvent.measurements(_measurements));
    } catch (e) {
      log('Error handling GNSS measurements: $e');
    }
  }

  /// Handle location updates
  void _handleLocationUpdate(dynamic data) {
    try {
      final Map<String, dynamic> locationData = Map<String, dynamic>.from(data);
      _eventController.add(GnssEvent.locationUpdate(locationData));
    } catch (e) {
      log('Error handling location update: $e');
    }
  }

  /// Handle first fix event
  void _handleFirstFix(dynamic data) {
    try {
      final Map<String, dynamic> firstFixData = Map<String, dynamic>.from(data);
      final int ttffMillis = firstFixData['ttffMillis'] as int;
      _eventController.add(GnssEvent.firstFix(ttffMillis));
    } catch (e) {
      log('Error handling first fix: $e');
    }
  }

  /// Get GNSS capabilities from native service
  Future<GnssCapabilities?> _getCapabilities() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getGnssCapabilities',
      );
      if (result != null) {
        _capabilities = GnssCapabilities.fromJson(
          Map<String, dynamic>.from(result),
        );
        return _capabilities;
      }
    } catch (e) {
      log('Error getting GNSS capabilities: $e');
    }
    return null;
  }
}

/// GNSS Event types
abstract class GnssEvent {
  const GnssEvent();

  factory GnssEvent.satelliteStatus(GnssStatus status) = SatelliteStatusEvent;
  factory GnssEvent.measurements(List<GnssMeasurement> measurements) =
      MeasurementsEvent;
  factory GnssEvent.locationUpdate(Map<String, dynamic> location) =
      LocationUpdateEvent;
  factory GnssEvent.firstFix(int ttffMillis) = FirstFixEvent;
}

class SatelliteStatusEvent extends GnssEvent {
  final GnssStatus status;
  const SatelliteStatusEvent(this.status);
}

class MeasurementsEvent extends GnssEvent {
  final List<GnssMeasurement> measurements;
  const MeasurementsEvent(this.measurements);
}

class LocationUpdateEvent extends GnssEvent {
  final Map<String, dynamic> location;
  const LocationUpdateEvent(this.location);
}

class FirstFixEvent extends GnssEvent {
  final int ttffMillis;
  const FirstFixEvent(this.ttffMillis);
}
