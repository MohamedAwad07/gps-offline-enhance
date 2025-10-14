import 'package:flutter/material.dart';
import 'package:testgps/services/enhanced_location_service.dart';
import 'package:testgps/models/gnss_models.dart';
import 'dart:async';

/// GNSS Dashboard - Real-time satellite and positioning data display
/// Similar to GPS Test app with comprehensive GNSS information
class GnssDashboard extends StatefulWidget {
  const GnssDashboard({super.key});

  @override
  State<GnssDashboard> createState() => _GnssDashboardState();
}

class _GnssDashboardState extends State<GnssDashboard> {
  final EnhancedLocationService _enhancedService = EnhancedLocationService();

  bool _isInitialized = false;
  bool _isTracking = false;
  bool _useGnssNative = true;

  GnssStatus? _currentStatus;
  GnssCapabilities? _capabilities;
  List<SatelliteInfo> _satellites = [];

  StreamSubscription<EnhancedLocationEvent>? _eventSubscription;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _updateTimer?.cancel();
    _enhancedService.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    final initialized = await _enhancedService.initialize();
    if (initialized) {
      setState(() {
        _isInitialized = true;
      });

      // Get capabilities
      _capabilities = await _enhancedService.getGnssCapabilities();

      // Listen to events
      _eventSubscription = _enhancedService.eventStream.listen(_handleEvent);

      // Start periodic updates
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateStatus();
      });
    }
  }

  void _handleEvent(EnhancedLocationEvent event) {
    switch (event.runtimeType) {
      case GnssStatusUpdateEvent:
        final statusEvent = event as GnssStatusUpdateEvent;
        setState(() {
          _currentStatus = statusEvent.status;
          _satellites = statusEvent.status.satellites;
        });
        break;
      case MeasurementsUpdateEvent:
        // Handle measurements if needed in the future
        break;
      case TrackingStartedEvent:
        setState(() {
          _isTracking = true;
        });
        break;
      case TrackingStoppedEvent:
        setState(() {
          _isTracking = false;
        });
        break;
    }
  }

  Future<void> _updateStatus() async {
    if (!_isInitialized) return;

    final status = await _enhancedService.getCurrentGnssStatus();
    if (status != null) {
      setState(() {
        _currentStatus = status;
        _satellites = status.satellites;
      });
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _enhancedService.stopTracking();
    } else {
      await _enhancedService.startTracking(useGnssNative: _useGnssNative);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛰️ GNSS Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Switch(
            value: _useGnssNative,
            onChanged: _isTracking
                ? null
                : (value) {
                    setState(() {
                      _useGnssNative = value;
                    });
                  },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Native GNSS', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildSatelliteInfoCard(),
            const SizedBox(height: 16),
            _buildSatelliteVisualization(),
            const SizedBox(height: 16),
            _buildConstellationInfo(),
            const SizedBox(height: 16),
            _buildCapabilitiesCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleTracking,
        backgroundColor: _isTracking ? Colors.red : Colors.green,
        child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _currentStatus;
    if (status == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.gps_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'No GNSS Status',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: _getFixTypeColor(status.fixType).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem(
                  'GNSS Status',
                  status.fixType.name,
                  _getFixTypeColor(status.fixType),
                ),
                _buildStatusItem(
                  'Accuracy',
                  '${status.accuracy.toStringAsFixed(1)} m',
                  Colors.cyan,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem(
                  'In View',
                  '${status.satellitesInView}',
                  Colors.blue,
                ),
                _buildStatusItem(
                  'In Use',
                  '${status.satellitesInUse}',
                  Colors.green,
                ),
                _buildStatusItem(
                  'Avg SNR',
                  status.averageSnr.toStringAsFixed(1),
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSatelliteInfoCard() {
    if (_satellites.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No satellite data available',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📡 Satellite Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._satellites
                .take(10)
                .map((satellite) => _buildSatelliteItem(satellite)),
            if (_satellites.length > 10)
              Text(
                '... and ${_satellites.length - 10} more satellites',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSatelliteItem(SatelliteInfo satellite) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getSignalColor(satellite.snr),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${satellite.constellation} ${satellite.svid}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const Spacer(),
          Text(
            '${satellite.snr.toStringAsFixed(1)} dB-Hz',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          Icon(
            satellite.usedInFix
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 16,
            color: satellite.usedInFix ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildSatelliteVisualization() {
    if (_satellites.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Signal Strength Visualization',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: _buildSignalStrengthChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalStrengthChart() {
    final usedSatellites = _satellites.where((s) => s.usedInFix).toList();
    if (usedSatellites.isEmpty) {
      return const Center(child: Text('No satellites used in fix'));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: usedSatellites.length,
      itemBuilder: (context, index) {
        final satellite = usedSatellites[index];
        final height = (satellite.snr / 50.0 * 150).clamp(10.0, 150.0);

        return Container(
          width: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: height,
                width: 30,
                decoration: BoxDecoration(
                  color: _getSignalColor(satellite.snr),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${satellite.svid}',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
              Text(
                satellite.snr.toStringAsFixed(0),
                style: const TextStyle(fontSize: 8, fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConstellationInfo() {
    if (_currentStatus == null) {
      return const SizedBox.shrink();
    }

    final constellationCount = _currentStatus!.constellationCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🌍 Constellation Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: constellationCount.entries.map((entry) {
                return _buildConstellationChip(entry.key, entry.value);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConstellationChip(String constellation, int count) {
    return Chip(
      label: Text('$constellation: $count'),
      backgroundColor: _getConstellationColor(constellation).withOpacity(0.2),
      side: BorderSide(color: _getConstellationColor(constellation)),
    );
  }

  Widget _buildCapabilitiesCard() {
    if (_capabilities == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔧 GNSS Capabilities',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildCapabilityRow('Hardware Model', _capabilities!.hardwareModel),
            _buildCapabilityRow(
              'Software Version',
              _capabilities!.softwareVersion,
            ),
            _buildCapabilityRow(
              'Max Satellites',
              _capabilities!.maxSatellites.toString(),
            ),
            const SizedBox(height: 8),
            Text(
              'Supported Constellations:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _capabilities!.supportedConstellations.map((
                constellation,
              ) {
                return Chip(
                  label: Text(constellation),
                  backgroundColor: _getConstellationColor(
                    constellation,
                  ).withOpacity(0.2),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Color _getFixTypeColor(GnssFixType fixType) {
    switch (fixType) {
      case GnssFixType.fix3D:
        return Colors.green;
      case GnssFixType.fix2D:
        return Colors.orange;
      case GnssFixType.noFix:
        return Colors.red;
    }
  }

  Color _getSignalColor(double snr) {
    if (snr >= 30) return Colors.green;
    if (snr >= 20) return Colors.yellow;
    if (snr >= 10) return Colors.orange;
    return Colors.red;
  }

  Color _getConstellationColor(String constellation) {
    switch (constellation.toUpperCase()) {
      case 'GPS':
        return Colors.green;
      case 'GLONASS':
        return Colors.blue;
      case 'GALILEO':
        return Colors.orange;
      case 'BEIDOU':
        return Colors.purple;
      case 'QZSS':
        return Colors.red;
      case 'IRNSS':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }
}
