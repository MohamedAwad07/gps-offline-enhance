import 'package:flutter/material.dart';
import 'package:testgps/services/gnss_native_service.dart';
import 'package:testgps/models/gnss_models.dart';
import 'dart:async';

/// Simple GNSS Test Screen to verify native service functionality
class GnssSimpleTest extends StatefulWidget {
  const GnssSimpleTest({super.key});

  @override
  State<GnssSimpleTest> createState() => _GnssSimpleTestState();
}

class _GnssSimpleTestState extends State<GnssSimpleTest> {
  final GnssNativeService _gnssService = GnssNativeService();

  bool _isInitialized = false;
  bool _isTracking = false;
  String _status = 'Not initialized';
  GnssCapabilities? _capabilities;
  GnssStatus? _currentStatus;
  List<SatelliteInfo> _satellites = [];

  StreamSubscription<GnssEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _gnssService.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    setState(() {
      _status = 'Initializing...';
    });

    try {
      print('Initializing GNSS service...');
      final initialized = await _gnssService.initialize();
      print('GNSS service initialized: $initialized');

      if (initialized) {
        setState(() {
          _isInitialized = true;
          _status = 'Initialized successfully';
        });

        // Get capabilities
        print('Getting GNSS capabilities...');
        _capabilities = await _gnssService.getCapabilities();
        print('Capabilities: ${_capabilities?.hardwareModel}');

        // Listen to events
        print('Setting up event listener...');
        _eventSubscription = _gnssService.eventStream.listen(
          _handleEvent,
          onError: (error) {
            print('Event stream error: $error');
          },
        );

        setState(() {});
      } else {
        setState(() {
          _status = 'Failed to initialize';
        });
      }
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  void _handleEvent(GnssEvent event) {
    print('Received GNSS event: ${event.runtimeType}');
    setState(() {
      switch (event.runtimeType) {
        case SatelliteStatusEvent:
          final statusEvent = event as SatelliteStatusEvent;
          _currentStatus = statusEvent.status;
          _satellites = statusEvent.status.satellites;
          print(
            'Updated status: ${_currentStatus?.fixType}, satellites: ${_satellites.length}',
          );
          break;
        case MeasurementsEvent:
          final measurementsEvent = event as MeasurementsEvent;
          print(
            'Received ${measurementsEvent.measurements.length} measurements',
          );
          break;
        case LocationUpdateEvent:
          final locationEvent = event as LocationUpdateEvent;
          print('Location update: ${locationEvent.location}');
          break;
        case FirstFixEvent:
          final firstFixEvent = event as FirstFixEvent;
          _status = 'First fix obtained in ${firstFixEvent.ttffMillis}ms';
          print('First fix: ${firstFixEvent.ttffMillis}ms');
          break;
      }
    });
  }

  Future<void> _startTracking() async {
    if (!_isInitialized) return;

    setState(() {
      _status = 'Starting tracking...';
    });

    try {
      print('Starting GNSS tracking...');
      final started = await _gnssService.startTracking();
      print('GNSS tracking started: $started');
      setState(() {
        _isTracking = started;
        _status = started ? 'Tracking started' : 'Failed to start tracking';
      });
    } catch (e) {
      print('Error starting tracking: $e');
      setState(() {
        _status = 'Error starting tracking: $e';
      });
    }
  }

  Future<void> _stopTracking() async {
    try {
      await _gnssService.stopTracking();
      setState(() {
        _isTracking = false;
        _status = 'Tracking stopped';
      });
    } catch (e) {
      setState(() {
        _status = 'Error stopping tracking: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GNSS Simple Test'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Initialized: $_isInitialized'),
                    Text('Tracking: $_isTracking'),
                    if (_capabilities != null) ...[
                      const SizedBox(height: 8),
                      Text('Hardware: ${_capabilities!.hardwareModel}'),
                      Text(
                        'Supported: ${_capabilities!.supportedConstellations.join(', ')}',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isInitialized && !_isTracking
                      ? _startTracking
                      : null,
                  child: const Text('Start Tracking'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isTracking ? _stopTracking : null,
                  child: const Text('Stop Tracking'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // GNSS Status
            if (_currentStatus != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GNSS Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Fix Type: ${_currentStatus!.fixType.name}'),
                      Text(
                        'Satellites: ${_currentStatus!.satellitesInUse}/${_currentStatus!.satellitesInView}',
                      ),
                      Text(
                        'Accuracy: ${_currentStatus!.accuracy.toStringAsFixed(1)}m',
                      ),
                      Text(
                        'Avg SNR: ${_currentStatus!.averageSnr.toStringAsFixed(1)} dB-Hz',
                      ),
                      Text(
                        'Position: ${_currentStatus!.latitude.toStringAsFixed(6)}, ${_currentStatus!.longitude.toStringAsFixed(6)}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Satellites List
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Satellites (${_satellites.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _satellites.length,
                            itemBuilder: (context, index) {
                              final satellite = _satellites[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: satellite.usedInFix
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Text(
                                    satellite.svid.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${satellite.constellation} ${satellite.svid}',
                                ),
                                subtitle: Text(
                                  'SNR: ${satellite.snr.toStringAsFixed(1)} dB-Hz',
                                ),
                                trailing: Text(
                                  satellite.usedInFix ? 'Used' : 'Not used',
                                  style: TextStyle(
                                    color: satellite.usedInFix
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
