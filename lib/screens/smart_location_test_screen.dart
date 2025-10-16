import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:testgps/services/smart_location_service.dart';
import 'package:testgps/services/fused_location_service.dart' as fused;
import 'package:testgps/models/gnss_models.dart';

class SmartLocationTestScreen extends StatefulWidget {
  const SmartLocationTestScreen({super.key});

  @override
  State<SmartLocationTestScreen> createState() =>
      _SmartLocationTestScreenState();
}

class _SmartLocationTestScreenState extends State<SmartLocationTestScreen> {
  final SmartLocationService _smartLocationService = SmartLocationService();

  bool _isInitialized = false;
  bool _isTracking = false;
  Position? _currentPosition;
  GnssStatus? _currentGnssStatus;
  LocationProvider _currentProvider = LocationProvider.gnss;
  String _statusMessage = 'Not initialized';
  final List<String> _eventLog = [];
  bool _testFusedLocationOnly = false;
  double? _bestAccuracy;
  DateTime? _bestAccuracyTime;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      final initialized = await _smartLocationService.initialize();
      if (initialized) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Smart Location Service initialized';
        });
        _addToLog('Smart Location Service initialized successfully');

        // Listen to events
        _smartLocationService.eventStream.listen(_handleEvent);
      } else {
        setState(() {
          _statusMessage = 'Failed to initialize Smart Location Service';
        });
        _addToLog('Failed to initialize Smart Location Service');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing: $e';
      });
      _addToLog('Error initializing: $e');
    }
  }

  void _handleEvent(SmartLocationEvent event) {
    switch (event.runtimeType) {
      case TrackingStartedEvent:
        final startEvent = event as TrackingStartedEvent;
        setState(() {
          _isTracking = true;
          _currentProvider = startEvent.provider;
          _statusMessage = 'Tracking started with ${startEvent.provider.name}';
        });
        _addToLog('Tracking started with ${startEvent.provider.name}');
        break;
      case TrackingStoppedEvent:
        setState(() {
          _isTracking = false;
          _statusMessage = 'Tracking stopped';
        });
        _addToLog('Tracking stopped');
        break;
      case PositionUpdateEvent:
        final positionEvent = event as PositionUpdateEvent;
        setState(() {
          _currentPosition = positionEvent.position;
          _currentProvider = positionEvent.provider;

          // Track best accuracy
          if (_bestAccuracy == null ||
              positionEvent.position.accuracy < _bestAccuracy!) {
            _bestAccuracy = positionEvent.position.accuracy;
            _bestAccuracyTime = positionEvent.position.timestamp;
          }
        });
        _addToLog(
          'Position: ${positionEvent.position.latitude.toStringAsFixed(6)}, ${positionEvent.position.longitude.toStringAsFixed(6)} | Acc: ${positionEvent.position.accuracy.toStringAsFixed(1)}m | Speed: ${positionEvent.position.speed.toStringAsFixed(2)} m/s | ${positionEvent.provider.name}',
        );
        break;
      case ProviderSwitchedEvent:
        final switchEvent = event as ProviderSwitchedEvent;
        setState(() {
          _currentProvider = switchEvent.newProvider;
          _statusMessage =
              'Switched to ${switchEvent.newProvider.name}: ${switchEvent.reason}';
        });
        _addToLog(
          'Provider switched to ${switchEvent.newProvider.name}: ${switchEvent.reason}',
        );
        break;
      case GnssStatusUpdateEvent:
        final statusEvent = event as GnssStatusUpdateEvent;
        setState(() {
          _currentGnssStatus = statusEvent.status;
        });
        _addToLog(
          'GNSS Status: ${statusEvent.status.satellitesInView} satellites, accuracy: ${statusEvent.status.accuracy.toStringAsFixed(1)}m',
        );
        break;
    }
  }

  void _addToLog(String message) {
    setState(() {
      _eventLog.insert(
        0,
        '${DateTime.now().toString().substring(11, 19)}: $message',
      );
      if (_eventLog.length > 20) {
        _eventLog.removeLast();
      }
    });
  }

  Future<void> _getCurrentPosition() async {
    if (!_isInitialized) return;

    try {
      setState(() {
        _statusMessage = 'Getting position...';
      });
      _addToLog('Requesting current position...');

      final position = await _smartLocationService.getCurrentPosition(
        timeout: const Duration(minutes: 2),
        preferGnss: !_testFusedLocationOnly,
        minSatellites: 9,
        minAccuracy: 10.0,
      );

      setState(() {
        _currentPosition = position;
        _statusMessage = 'Position obtained successfully';
      });
      _addToLog(
        'Position obtained: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error getting position: $e';
      });
      _addToLog('Error getting position: $e');
    }
  }

  Future<void> _startTracking() async {
    if (!_isInitialized || _isTracking) return;

    try {
      final started = await _smartLocationService.startTracking(
        updateInterval: const Duration(seconds: 2),
        preferGnss: !_testFusedLocationOnly,
        minSatellites: 9,
        minAccuracy: 10.0,
      );

      if (started) {
        _addToLog('Tracking started successfully');
      } else {
        setState(() {
          _statusMessage = 'Failed to start tracking';
        });
        _addToLog('Failed to start tracking');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting tracking: $e';
      });
      _addToLog('Error starting tracking: $e');
    }
  }

  Future<void> _stopTracking() async {
    if (!_isTracking) return;

    try {
      final stopped = await _smartLocationService.stopTracking();
      if (stopped) {
        _addToLog('Tracking stopped successfully');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error stopping tracking: $e';
      });
      _addToLog('Error stopping tracking: $e');
    }
  }

  Future<void> _testFusedLocationDirectly() async {
    if (!_isInitialized) return;

    try {
      setState(() {
        _statusMessage = 'Testing Fused Location directly...';
      });
      _addToLog('Testing Google Fused Location Provider directly...');

      // Import the FusedLocationService directly
      final fusedLocationService = fused.FusedLocationService();

      // Initialize if needed
      if (!fusedLocationService.isInitialized) {
        final initialized = await fusedLocationService.initialize();
        if (!initialized) {
          setState(() {
            _statusMessage = 'Failed to initialize Fused Location Service';
          });
          _addToLog('Failed to initialize Fused Location Service');
          return;
        }
      }

      // Test Google Play Services availability
      final isAvailable = await fusedLocationService
          .isGooglePlayServicesAvailable();
      _addToLog('Google Play Services available: $isAvailable');

      if (!isAvailable) {
        setState(() {
          _statusMessage = 'Google Play Services not available';
        });
        _addToLog('Google Play Services not available');
        return;
      }

      // Test location settings
      final settingsStatus = await fusedLocationService
          .getLocationSettingsStatus();
      _addToLog(
        'Location settings - GPS: ${settingsStatus.isGpsEnabled}, Network: ${settingsStatus.isNetworkEnabled}',
      );

      // Get current position
      final position = await fusedLocationService.getCurrentPosition(
        timeout: const Duration(minutes: 1),
        accuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _currentProvider = LocationProvider.fusedLocation;
        _statusMessage = 'Fused Location test successful';
      });
      _addToLog(
        'Fused Location position: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      );
      _addToLog('Accuracy: ${position.accuracy.toStringAsFixed(1)}m');
    } catch (e) {
      setState(() {
        _statusMessage = 'Fused Location test failed: $e';
      });
      _addToLog('Fused Location test error: $e');
    }
  }

  @override
  void dispose() {
    _smartLocationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'Smart Location Test',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isTracking
                  ? const Color(0xFF00E5FF).withOpacity(0.2)
                  : const Color(0xFF6C757D).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isTracking
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFF6C757D),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isTracking
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF6C757D),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isTracking ? 'TRACKING' : 'STANDBY',
                  style: TextStyle(
                    color: _isTracking
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF6C757D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Top Status Cards
                  _buildTopStatusCards(),
                  const SizedBox(height: 20),
                  // Position Data Section
                  _buildPositionDataSection(),
                  const SizedBox(height: 20),
                  // Control Section
                  _buildControlSection(),
                  const SizedBox(height: 20),

                  // Event Log
                  _buildEventLogSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isTracking ? Colors.red : Colors.green).withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _isTracking ? _stopTracking : _startTracking,
          backgroundColor: _isTracking
              ? const Color(0xFFDC3545)
              : const Color(0xFF28A745),
          child: Icon(
            _isTracking ? Icons.stop : Icons.play_arrow,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTopStatusCards() {
    if (!_isTracking || _currentPosition == null) {
      return Row(
        children: [
          // Provider Status Card - Not Tracking
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF333333), width: 1),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 32,
                      color: Color(0xFF6C757D),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Provider Status',
                      style: TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Not Tracking',
                      style: TextStyle(color: Color(0xFF6C757D), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Accuracy Card - Not Tracking
          Expanded(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF333333), width: 1),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.center_focus_strong,
                      size: 32,
                      color: Color(0xFF6C757D),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Accuracy (± m)',
                      style: TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '--',
                      style: TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Provider Status Card
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getProviderColor(_currentProvider).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Provider Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getProviderColor(_currentProvider),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getProviderIcon(_currentProvider),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentProvider.name.toUpperCase(),
                          style: TextStyle(
                            color: _getProviderColor(_currentProvider),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Accuracy Card
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getAccuracyColor(
                  _currentPosition!.accuracy,
                ).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Accuracy (± m)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getAccuracyColor(_currentPosition!.accuracy),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.center_focus_strong,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentPosition!.accuracy.toStringAsFixed(0),
                          style: TextStyle(
                            color: _getAccuracyColor(
                              _currentPosition!.accuracy,
                            ),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionDataSection() {
    if (_currentPosition == null) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF333333), width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isTracking
                    ? Icons.location_searching
                    : Icons.play_circle_outline,
                size: 48,
                color: const Color(0xFF6C757D),
              ),
              const SizedBox(height: 8),
              Text(
                _isTracking
                    ? 'No Position Data'
                    : 'Start Tracking to View Data',
                style: const TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!_isTracking) ...[
                const SizedBox(height: 4),
                const Text(
                  'Press the play button to begin location tracking',
                  style: TextStyle(color: Color(0xFF6C757D), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Position Header
            Row(
              children: [
                Icon(
                  _getProviderIcon(_currentProvider),
                  color: _getProviderColor(_currentProvider),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_currentProvider.name.toUpperCase()} Position',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_bestAccuracy != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28A745).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF28A745),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Best: ${_bestAccuracy!.toStringAsFixed(1)}m',
                      style: const TextStyle(
                        color: Color(0xFF28A745),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Coordinates
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333), width: 1),
              ),
              child: Column(
                children: [
                  // Latitude
                  Row(
                    children: [
                      const Icon(
                        Icons.north,
                        color: Color(0xFF00E5FF),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Latitude',
                        style: TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentPosition!.latitude.toStringAsFixed(8)}°',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 16,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Longitude
                  Row(
                    children: [
                      const Icon(
                        Icons.east,
                        color: Color(0xFF00E5FF),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Longitude',
                        style: TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentPosition!.longitude.toStringAsFixed(8)}°',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 16,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Movement Data
            Row(
              children: [
                Expanded(
                  child: _buildDataCard(
                    'Speed',
                    '${_currentPosition!.speed.toStringAsFixed(2)} m/s',
                    Icons.speed,
                    const Color(0xFF28A745),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataCard(
                    'Heading',
                    '${_currentPosition!.heading.toStringAsFixed(1)}°',
                    Icons.navigation,
                    const Color(0xFF17A2B8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataCard(
                    'Altitude',
                    '${_currentPosition!.altitude.toStringAsFixed(1)}m',
                    Icons.height,
                    const Color(0xFFFFC107),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Accuracy Data
            Row(
              children: [
                Expanded(
                  child: _buildDataCard(
                    'Speed Acc',
                    '${_currentPosition!.speedAccuracy.toStringAsFixed(2)} m/s',
                    Icons.trending_up,
                    const Color(0xFF6F42C1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataCard(
                    'Alt Acc',
                    '${_currentPosition!.altitudeAccuracy.toStringAsFixed(1)}m',
                    Icons.height,
                    const Color(0xFFFD7E14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataCard(
                    'Head Acc',
                    '${_currentPosition!.headingAccuracy.toStringAsFixed(1)}°',
                    Icons.compass_calibration,
                    const Color(0xFFDC3545),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status Info
            Row(
              children: [
                Icon(
                  _currentPosition!.isMocked
                      ? Icons.warning
                      : Icons.check_circle,
                  color: _currentPosition!.isMocked
                      ? const Color(0xFFDC3545)
                      : const Color(0xFF28A745),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentPosition!.isMocked
                      ? 'Mock Location'
                      : 'Real Location',
                  style: TextStyle(
                    color: _currentPosition!.isMocked
                        ? const Color(0xFFDC3545)
                        : const Color(0xFF28A745),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated: ${_currentPosition!.timestamp.toString().substring(11, 19)}',
                  style: const TextStyle(
                    color: Color(0xFF6C757D),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6C757D),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Control Panel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Fused Location Only Toggle
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF00E5FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Test Fused Location Only',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _testFusedLocationOnly,
                  onChanged: (value) {
                    setState(() {
                      _testFusedLocationOnly = value;
                    });
                    _addToLog(
                      'Fused Location Only mode: ${value ? 'ON' : 'OFF'}',
                    );
                  },
                  activeColor: const Color(0xFF00E5FF),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized && !_isTracking
                        ? _getCurrentPosition
                        : null,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Get Position'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF17A2B8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_testFusedLocationOnly)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isInitialized && !_isTracking
                          ? _testFusedLocationDirectly
                          : null,
                      icon: const Icon(Icons.gps_fixed, size: 18),
                      label: const Text('Test Fused'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventLogSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Log',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _eventLog.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF333333),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      _eventLog[index],
                      style: const TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProviderColor(LocationProvider provider) {
    switch (provider) {
      case LocationProvider.gnss:
        return const Color(0xFF28A745);
      case LocationProvider.fusedLocation:
        return const Color(0xFF00E5FF);
      case LocationProvider.standard:
        return const Color(0xFF17A2B8);
    }
  }

  IconData _getProviderIcon(LocationProvider provider) {
    switch (provider) {
      case LocationProvider.gnss:
        return Icons.satellite;
      case LocationProvider.fusedLocation:
        return Icons.gps_fixed;
      case LocationProvider.standard:
        return Icons.location_searching;
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy <= 5) return const Color(0xFF28A745);
    if (accuracy <= 10) return const Color(0xFFFFC107);
    if (accuracy <= 20) return const Color(0xFFFD7E14);
    return const Color(0xFFDC3545);
  }
}
