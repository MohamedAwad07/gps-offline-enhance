import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:testgps/services/fused_location_service.dart';

class FusedLocationTestScreen extends StatefulWidget {
  const FusedLocationTestScreen({super.key});

  @override
  State<FusedLocationTestScreen> createState() =>
      _FusedLocationTestScreenState();
}

class _FusedLocationTestScreenState extends State<FusedLocationTestScreen> {
  final FusedLocationService _fusedLocationService = FusedLocationService();
  StreamSubscription<FusedLocationEvent>? _eventSubscription;

  // State variables
  bool _isInitialized = false;
  bool _isTracking = false;
  bool _isGooglePlayServicesAvailable = false;
  Position? _currentPosition;
  LocationSettingsStatus? _locationSettingsStatus;
  LocationAccuracy _selectedAccuracy = LocationAccuracy.bestForNavigation;
  Duration _updateInterval = const Duration(seconds: 1);

  // Real-time location updates list
  final List<LocationUpdateInfo> _locationUpdates = [];
  final ScrollController _scrollController = ScrollController();

  // Error handling
  String? _lastError;
  int _errorCount = 0;
  int _updateCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if tracking state has changed due to other services
    _checkTrackingState();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    // Don't dispose the singleton service as other parts of the app might need it
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      setState(() {
        _lastError = null;
      });

      // Check Google Play Services availability
      final isAvailable = await _fusedLocationService
          .isGooglePlayServicesAvailable();
      setState(() {
        _isGooglePlayServicesAvailable = isAvailable;
      });

      if (!isAvailable) {
        setState(() {
          _lastError = 'Google Play Services not available';
        });
        return;
      }

      // Initialize the service
      final initialized = await _fusedLocationService.initialize();
      setState(() {
        _isInitialized = initialized;
      });

      if (initialized) {
        // Get initial location settings status
        await _getLocationSettingsStatus();

        // Set up event stream listener
        log('UI: Setting up event stream listener');
        _eventSubscription?.cancel(); // Cancel any existing subscription
        _eventSubscription = _fusedLocationService.eventStream.listen(
          _handleFusedLocationEvent,
          onError: (error) {
            log('Fused location stream error: $error');
            setState(() {
              _lastError = error.toString();
              _errorCount++;
            });
          },
        );
        log('UI: Event stream listener set up successfully');

        // Check current tracking state
        _checkTrackingState();
      } else {
        setState(() {
          _lastError = 'Failed to initialize Fused Location Service';
        });
      }
    } catch (e) {
      log('Error initializing fused location service: $e');
      setState(() {
        _lastError = e.toString();
        _errorCount++;
      });
    }
  }

  void _checkTrackingState() {
    if (_isInitialized) {
      final serviceTrackingState = _fusedLocationService.isTracking;
      if (serviceTrackingState != _isTracking) {
        log(
          'UI: Tracking state mismatch detected - Service: $serviceTrackingState, UI: $_isTracking',
        );
        setState(() {
          _isTracking = serviceTrackingState;
        });

        if (serviceTrackingState) {
          _addLocationUpdate('Tracking Started by Another Service', null);
        } else {
          _addLocationUpdate('Tracking Stopped by Another Service', null);
        }
      }
    }
  }

  void _handleFusedLocationEvent(FusedLocationEvent event) {
    log('UI: Handling fused location event: ${event.runtimeType}');
    setState(() {
      switch (event.runtimeType) {
        case TrackingStartedEvent:
          log('UI: Tracking started event received');
          _isTracking = true;
          _addLocationUpdate('Tracking Started', null);
          break;
        case TrackingStoppedEvent:
          log('UI: Tracking stopped event received');
          _isTracking = false;
          _addLocationUpdate('Tracking Stopped', null);
          break;
        case PositionUpdateEvent:
          final positionEvent = event as PositionUpdateEvent;
          log(
            'UI: Position update event received - Lat: ${positionEvent.position.latitude}, Lng: ${positionEvent.position.longitude}, Accuracy: ${positionEvent.position.accuracy}',
          );
          _currentPosition = positionEvent.position;
          _addLocationUpdate('Position Update', positionEvent.position);
          _updateCount++;
          break;
        case LocationSettingsChangedEvent:
          final settingsEvent = event as LocationSettingsChangedEvent;
          log('UI: Location settings changed event received');
          _locationSettingsStatus = settingsEvent.status;
          _addLocationUpdate('Settings Changed', null);
          break;
        case ErrorEvent:
          final errorEvent = event as ErrorEvent;
          log('UI: Error event received: ${errorEvent.error}');
          _lastError = errorEvent.error;
          _errorCount++;
          _addLocationUpdate('Error: ${errorEvent.error}', null);
          break;
      }
    });
  }

  void _addLocationUpdate(String eventType, Position? position) {
    log(
      'UI: Adding location update - Type: $eventType, Position: ${position != null ? '${position.latitude}, ${position.longitude}' : 'null'}',
    );
    final update = LocationUpdateInfo(
      timestamp: DateTime.now(),
      eventType: eventType,
      position: position,
    );

    setState(() {
      _locationUpdates.insert(0, update); // Add to beginning for newest first
      log('UI: Location updates list now has ${_locationUpdates.length} items');

      // Keep only last 100 updates to prevent memory issues
      if (_locationUpdates.length > 100) {
        _locationUpdates.removeLast();
      }
    });

    // Auto-scroll to top to show latest update
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      setState(() {
        _lastError = null;
      });

      final position = await _fusedLocationService.getCurrentPosition(
        timeout: const Duration(minutes: 2),
        accuracy: _selectedAccuracy,
      );

      setState(() {
        _currentPosition = position;
      });

      _addLocationUpdate('Manual Position Request', position);
    } catch (e) {
      log('Error getting current position: $e');
      setState(() {
        _lastError = e.toString();
        _errorCount++;
      });
    }
  }

  Future<void> _startTracking() async {
    log('UI: _startTracking() called by user');
    try {
      setState(() {
        _lastError = null;
      });

      log('UI: Calling fusedLocationService.startTracking()...');
      final started = await _fusedLocationService.startTracking(
        updateInterval: _updateInterval,
        accuracy: _selectedAccuracy,
      );

      if (!started) {
        log('UI: Failed to start tracking');
        setState(() {
          _lastError = 'Failed to start tracking';
        });
      } else {
        log('UI: Tracking started successfully');
      }
    } catch (e) {
      log('Error starting tracking: $e');
      setState(() {
        _lastError = e.toString();
        _errorCount++;
      });
    }
  }

  Future<void> _stopTracking() async {
    log('UI: _stopTracking() called by user');
    try {
      await _fusedLocationService.stopTracking();
      log('UI: Tracking stopped successfully');
    } catch (e) {
      log('Error stopping tracking: $e');
      setState(() {
        _lastError = e.toString();
        _errorCount++;
      });
    }
  }

  Future<void> _forceStopTracking() async {
    log('UI: _forceStopTracking() called by user');
    try {
      await _fusedLocationService.stopTracking();
      setState(() {
        _isTracking = false;
      });
      _addLocationUpdate('Force Stop Tracking', null);
      log('UI: Force stop tracking completed');
    } catch (e) {
      log('Error force stopping tracking: $e');
      setState(() {
        _lastError = e.toString();
        _errorCount++;
      });
    }
  }

  Future<void> _getLocationSettingsStatus() async {
    try {
      final status = await _fusedLocationService.getLocationSettingsStatus();
      setState(() {
        _locationSettingsStatus = status;
      });
    } catch (e) {
      log('Error getting location settings status: $e');
    }
  }

  Future<void> _requestLocationSettings() async {
    try {
      final result = await _fusedLocationService.requestLocationSettings(
        accuracy: _selectedAccuracy,
      );

      if (result) {
        await _getLocationSettingsStatus();
        _addLocationUpdate('Location Settings Requested', null);
      } else {
        setState(() {
          _lastError = 'Failed to request location settings';
        });
      }
    } catch (e) {
      log('Error requesting location settings: $e');
      setState(() {
        _lastError = e.toString();
        _errorCount++;
      });
    }
  }

  Future<void> _requestHighAccuracySettings() async {
    try {
      final result = await _fusedLocationService.requestHighAccuracySettings();

      if (result) {
        await _getLocationSettingsStatus();
        _addLocationUpdate('High Accuracy Settings Requested', null);
      } else {
        setState(() {
          _lastError = 'Failed to request high accuracy settings';
        });
      }
    } catch (e) {
      log('Error requesting high accuracy settings: $e');
      setState(() {
        _lastError = e.toString();
        _errorCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServiceStatusCard(),
            const SizedBox(height: 16),
            _buildLocationSettingsCard(),
            const SizedBox(height: 16),
            _buildCurrentPositionCard(),
            const SizedBox(height: 16),
            _buildControlPanelCard(),
            const SizedBox(height: 16),
            _buildLocationUpdatesCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeService,
        tooltip: 'Reinitialize Service',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Initialized', _isInitialized),
            _buildStatusRow(
              'Google Play Services',
              _isGooglePlayServicesAvailable,
            ),
            _buildStatusRow('Tracking Active', _isTracking),
            if (_isTracking)
              _buildStatusRow('Tracking Source', 'Fused Location Test Screen'),
            _buildStatusRow('Updates Received', '$_updateCount'),
            _buildStatusRow('Errors', '$_errorCount'),
            if (_lastError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isTracking &&
                _locationUpdates.any(
                  (update) => update.eventType.contains('Another Service'),
                )) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.orange.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tracking was started by another service. Use "Force Stop" to regain control.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Location Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.high_quality),
                      onPressed: _requestHighAccuracySettings,
                      tooltip: 'Request High Accuracy Settings',
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: _requestLocationSettings,
                      tooltip: 'Request Location Settings',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_locationSettingsStatus != null) ...[
              _buildStatusRow(
                'Location Enabled',
                _locationSettingsStatus!.isLocationEnabled,
              ),
              _buildStatusRow(
                'GPS Enabled',
                _locationSettingsStatus!.isGpsEnabled,
              ),
              _buildStatusRow(
                'Network Enabled',
                _locationSettingsStatus!.isNetworkEnabled,
              ),
              _buildStatusRow(
                'Passive Enabled',
                _locationSettingsStatus!.isPassiveEnabled,
              ),
            ] else
              const Text('Settings status not available'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPositionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Position',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _getCurrentPosition,
                  tooltip: 'Get Current Position',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentPosition != null) ...[
              _buildPositionDetail(
                'Latitude',
                '${_currentPosition!.latitude.toStringAsFixed(8)}°',
              ),
              _buildPositionDetail(
                'Longitude',
                '${_currentPosition!.longitude.toStringAsFixed(8)}°',
              ),
              _buildPositionDetail(
                'Accuracy',
                '${_currentPosition!.accuracy.toStringAsFixed(2)} m',
              ),
              _buildPositionDetail(
                'Altitude',
                '${_currentPosition!.altitude.toStringAsFixed(2)} m',
              ),
              _buildPositionDetail(
                'Altitude Accuracy',
                '${_currentPosition!.altitudeAccuracy.toStringAsFixed(2)} m',
              ),
              _buildPositionDetail(
                'Heading',
                '${_currentPosition!.heading.toStringAsFixed(2)}°',
              ),
              _buildPositionDetail(
                'Heading Accuracy',
                '${_currentPosition!.headingAccuracy.toStringAsFixed(2)}°',
              ),
              _buildPositionDetail(
                'Speed',
                '${_currentPosition!.speed.toStringAsFixed(2)} m/s',
              ),
              _buildPositionDetail(
                'Speed Accuracy',
                '${_currentPosition!.speedAccuracy.toStringAsFixed(2)} m/s',
              ),
              _buildPositionDetail(
                'Timestamp',
                _currentPosition!.timestamp.toString(),
              ),
              _buildPositionDetail(
                'Is Mocked',
                _currentPosition!.isMocked.toString(),
              ),
            ] else
              const Text('No position available'),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanelCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control Panel',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Accuracy Selection
            Text(
              'Location Accuracy:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<LocationAccuracy>(
              value: _selectedAccuracy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: LocationAccuracy.values.map((accuracy) {
                return DropdownMenuItem(
                  value: accuracy,
                  child: Text(_accuracyToString(accuracy)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedAccuracy = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Update Interval Selection
            Text(
              'Update Interval:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Duration>(
              value: _updateInterval,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: Duration(seconds: 1),
                  child: Text('1 second'),
                ),
                DropdownMenuItem(
                  value: Duration(seconds: 2),
                  child: Text('2 seconds'),
                ),
                DropdownMenuItem(
                  value: Duration(seconds: 5),
                  child: Text('5 seconds'),
                ),
                DropdownMenuItem(
                  value: Duration(seconds: 10),
                  child: Text('10 seconds'),
                ),
                DropdownMenuItem(
                  value: Duration(seconds: 30),
                  child: Text('30 seconds'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _updateInterval = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized && !_isTracking
                        ? _startTracking
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? _stopTracking : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Force Stop Button (in case tracking is started by another service)
            if (_isTracking)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _forceStopTracking,
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Force Stop All Tracking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Accuracy Tips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: Colors.blue.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Accuracy Tips',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Go outdoors for best GPS accuracy\n'
                    '• Ensure GPS is enabled in device settings\n'
                    '• Use "Best for Navigation" for highest accuracy\n'
                    '• Wait a few seconds for initial fix\n'
                    '• Avoid buildings and tall structures',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationUpdatesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Real-time Updates (${_locationUpdates.length})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bug_report),
                      onPressed: () {
                        // Test UI update
                        _addLocationUpdate('Test Update', _currentPosition);
                      },
                      tooltip: 'Test UI Update',
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _locationUpdates.clear();
                          _updateCount = 0;
                          _errorCount = 0;
                        });
                      },
                      tooltip: 'Clear Updates',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: _locationUpdates.isEmpty
                  ? const Center(
                      child: Text(
                        'No updates yet. Start tracking to see real-time location updates.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _locationUpdates.length,
                      itemBuilder: (context, index) {
                        final update = _locationUpdates[index];
                        return _buildLocationUpdateItem(update);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationUpdateItem(LocationUpdateInfo update) {
    final isError = update.eventType.startsWith('Error');
    final isPositionUpdate = update.position != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.shade50
            : isPositionUpdate
            ? Colors.blue.shade50
            : Colors.grey.shade50,
        border: Border.all(
          color: isError
              ? Colors.red.shade200
              : isPositionUpdate
              ? Colors.blue.shade200
              : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError
                    ? Icons.error
                    : isPositionUpdate
                    ? Icons.location_on
                    : Icons.info,
                size: 16,
                color: isError
                    ? Colors.red.shade600
                    : isPositionUpdate
                    ? Colors.blue.shade600
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  update.eventType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isError
                        ? Colors.red.shade700
                        : isPositionUpdate
                        ? Colors.blue.shade700
                        : Colors.grey.shade700,
                  ),
                ),
              ),
              Text(
                '${update.timestamp.hour.toString().padLeft(2, '0')}:'
                '${update.timestamp.minute.toString().padLeft(2, '0')}:'
                '${update.timestamp.second.toString().padLeft(2, '0')}.'
                '${update.timestamp.millisecond.toString().padLeft(3, '0')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          if (update.position != null) ...[
            const SizedBox(height: 8),
            _buildCompactPositionDetails(update.position!),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactPositionDetails(Position position) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lat: ${position.latitude.toStringAsFixed(6)}°',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                'Lng: ${position.longitude.toStringAsFixed(6)}°',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Accuracy: ${position.accuracy.toStringAsFixed(1)}m',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                'Speed: ${position.speed.toStringAsFixed(1)}m/s',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        if (position.altitude != 0) ...[
          const SizedBox(height: 4),
          Text(
            'Altitude: ${position.altitude.toStringAsFixed(1)}m',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusRow(String label, dynamic value) {
    final bool isBool = value is bool;
    final Color color = isBool
        ? (value ? Colors.green : Colors.red)
        : Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              if (isBool) ...[
                Icon(
                  value ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                value.toString(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _accuracyToString(LocationAccuracy accuracy) {
    switch (accuracy) {
      case LocationAccuracy.lowest:
        return 'Lowest';
      case LocationAccuracy.low:
        return 'Low';
      case LocationAccuracy.medium:
        return 'Medium';
      case LocationAccuracy.high:
        return 'High';
      case LocationAccuracy.best:
        return 'Best';
      case LocationAccuracy.bestForNavigation:
        return 'Best for Navigation';
      default:
        return 'High';
    }
  }
}

class LocationUpdateInfo {
  final DateTime timestamp;
  final String eventType;
  final Position? position;

  LocationUpdateInfo({
    required this.timestamp,
    required this.eventType,
    this.position,
  });
}
