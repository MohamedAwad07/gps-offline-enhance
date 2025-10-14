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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'GNSS Test Suite',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF1A1D29),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getStatusColor(), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Status Overview
            _buildSystemStatusCard(),
            const SizedBox(height: 20),

            // Control Panel
            _buildControlPanel(),
            const SizedBox(height: 20),

            // GNSS Status Dashboard
            if (_currentStatus != null) ...[
              _buildGnssStatusDashboard(),
              const SizedBox(height: 20),
              _buildSatellitesList(),
            ] else
              _buildWaitingCard(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (!_isInitialized) return const Color(0xFF6C757D);
    if (_isTracking) return const Color(0xFF28A745);
    return const Color(0xFF17A2B8);
  }

  String _getStatusText() {
    if (!_isInitialized) return 'OFFLINE';
    if (_isTracking) return 'TRACKING';
    return 'READY';
  }

  Widget _buildSystemStatusCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1D29), Color(0xFF2D3142)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isTracking ? Icons.satellite_alt : Icons.satellite,
                    color: _getStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Status',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _status,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildStatusIndicator('Initialized', _isInitialized),
                const SizedBox(width: 20),
                _buildStatusIndicator('Tracking', _isTracking),
              ],
            ),
            if (_capabilities != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hardware Information',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Model: ${_capabilities!.hardwareModel}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Constellations: ${_capabilities!.supportedConstellations.join(', ')}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
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

  Widget _buildStatusIndicator(String label, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF28A745) : const Color(0xFF6C757D),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Control Panel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    'Start Tracking',
                    Icons.play_arrow,
                    _isInitialized && !_isTracking ? _startTracking : null,
                    const Color(0xFF28A745),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    'Stop Tracking',
                    Icons.stop,
                    _isTracking ? _stopTracking : null,
                    const Color(0xFFDC3545),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    String text,
    IconData icon,
    VoidCallback? onPressed,
    Color color,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : Colors.grey.shade300,
        foregroundColor: onPressed != null
            ? Colors.white
            : Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: onPressed != null ? 2 : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGnssStatusDashboard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getFixTypeColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFixTypeIcon(),
                    color: _getFixTypeColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'GNSS Status Dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D29),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Fix Type',
                    _currentStatus!.fixType.name.toUpperCase(),
                    _getFixTypeColor(),
                    Icons.gps_fixed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Satellites',
                    '${_currentStatus!.satellitesInUse}/${_currentStatus!.satellitesInView}',
                    const Color(0xFF17A2B8),
                    Icons.satellite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Accuracy',
                    '${_currentStatus!.accuracy.toStringAsFixed(1)}m',
                    _getAccuracyColor(),
                    Icons.center_focus_strong,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Avg SNR',
                    '${_currentStatus!.averageSnr.toStringAsFixed(1)} dB-Hz',
                    _getSnrColor(),
                    Icons.signal_cellular_alt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Position Coordinates',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF495057),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lat: ${_currentStatus!.latitude.toStringAsFixed(6)}°',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6C757D),
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'Lng: ${_currentStatus!.longitude.toStringAsFixed(6)}°',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6C757D),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSatellitesList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17A2B8).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.satellite_alt,
                    color: Color(0xFF17A2B8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Satellite Constellation (${_satellites.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D29),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _satellites.length,
                itemBuilder: (context, index) {
                  final satellite = _satellites[index];
                  return _buildSatelliteItem(satellite);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSatelliteItem(SatelliteInfo satellite) {
    final constellationColor = _getConstellationColor(satellite.constellation);
    final snrColor = _getSnrColorForSatellite(satellite.snr);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: satellite.usedInFix
            ? constellationColor.withOpacity(0.1)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: satellite.usedInFix
              ? constellationColor.withOpacity(0.3)
              : const Color(0xFFE9ECEF),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: satellite.usedInFix
                  ? constellationColor
                  : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                satellite.svid.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${satellite.constellation} ${satellite.svid}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: satellite.usedInFix
                        ? constellationColor
                        : const Color(0xFF6C757D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SNR: ${satellite.snr.toStringAsFixed(1)} dB-Hz',
                  style: TextStyle(
                    fontSize: 12,
                    color: snrColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: satellite.usedInFix
                  ? const Color(0xFF28A745).withOpacity(0.1)
                  : const Color(0xFF6C757D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              satellite.usedInFix ? 'USED' : 'IDLE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: satellite.usedInFix
                    ? const Color(0xFF28A745)
                    : const Color(0xFF6C757D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6C757D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.satellite_outlined,
                size: 48,
                color: Color(0xFF6C757D),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Waiting for GNSS Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking to see satellite information',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFixTypeColor() {
    switch (_currentStatus?.fixType) {
      case GnssFixType.noFix:
        return const Color(0xFFDC3545);
      case GnssFixType.gnssDeadReckoning:
        return const Color(0xFFFD7E14);
      case GnssFixType.fix2D:
        return const Color(0xFFFFC107);
      case GnssFixType.fix3D:
        return const Color(0xFF28A745);
      default:
        return const Color(0xFF6C757D);
    }
  }

  IconData _getFixTypeIcon() {
    switch (_currentStatus?.fixType) {
      case GnssFixType.noFix:
        return Icons.gps_off;
      case GnssFixType.gnssDeadReckoning:
        return Icons.gps_not_fixed;
      case GnssFixType.fix2D:
        return Icons.gps_fixed;
      case GnssFixType.fix3D:
        return Icons.gps_fixed;
      default:
        return Icons.gps_off;
    }
  }

  Color _getAccuracyColor() {
    final accuracy = _currentStatus?.accuracy ?? 0;
    if (accuracy <= 5) return const Color(0xFF28A745);
    if (accuracy <= 10) return const Color(0xFFFFC107);
    if (accuracy <= 20) return const Color(0xFFFD7E14);
    return const Color(0xFFDC3545);
  }

  Color _getSnrColor() {
    final snr = _currentStatus?.averageSnr ?? 0;
    if (snr >= 30) return const Color(0xFF28A745);
    if (snr >= 20) return const Color(0xFFFFC107);
    if (snr >= 10) return const Color(0xFFFD7E14);
    return const Color(0xFFDC3545);
  }

  Color _getConstellationColor(String constellation) {
    switch (constellation.toLowerCase()) {
      case 'gps':
        return const Color(0xFF007BFF);
      case 'glonass':
        return const Color(0xFF28A745);
      case 'galileo':
        return const Color(0xFF6F42C1);
      case 'beidou':
        return const Color(0xFFDC3545);
      case 'qzss':
        return const Color(0xFF17A2B8);
      case 'navic':
        return const Color(0xFFFD7E14);
      default:
        return const Color(0xFF6C757D);
    }
  }

  Color _getSnrColorForSatellite(double snr) {
    if (snr >= 30) return const Color(0xFF28A745);
    if (snr >= 20) return const Color(0xFFFFC107);
    if (snr >= 10) return const Color(0xFFFD7E14);
    return const Color(0xFFDC3545);
  }
}
