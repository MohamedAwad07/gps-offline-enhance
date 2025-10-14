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
  final bool _useGnssNative = true;

  GnssStatus? _currentStatus;
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
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          'GNSS Dashboard',
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

                  // Satellite Data Section
                  _buildSatelliteDataSection(),
                  const SizedBox(height: 20),

                  // SNR Indicator
                  _buildSnrIndicator(),
                ],
              ),
            ),
          ),

          // Bottom Navigation Modules
          _buildBottomModules(),
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
          onPressed: _toggleTracking,
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
    final status = _currentStatus;
    if (status == null) {
      return Container(
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
              Icon(Icons.gps_off, size: 48, color: Color(0xFF6C757D)),
              SizedBox(height: 8),
              Text(
                'No GNSS Status',
                style: TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        // GNSS Status Card
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getFixTypeColor(status.fixType).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GNSS Status',
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
                          color: _getFixTypeColor(status.fixType),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getFixTypeIcon(status.fixType),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          status.fixType.name.toUpperCase(),
                          style: TextStyle(
                            color: _getFixTypeColor(status.fixType),
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
                color: _getAccuracyColor(status.accuracy).withOpacity(0.3),
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
                          color: _getAccuracyColor(status.accuracy),
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
                          status.accuracy.toStringAsFixed(0),
                          style: TextStyle(
                            color: _getAccuracyColor(status.accuracy),
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

  Widget _buildSatelliteDataSection() {
    final status = _currentStatus;
    if (status == null || _satellites.isEmpty) {
      return Container(
        height: 300,
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
                Icons.satellite_outlined,
                size: 48,
                color: Color(0xFF6C757D),
              ),
              SizedBox(height: 8),
              Text(
                'No Satellite Data',
                style: TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
            // Satellite Count Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'In View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${status.satellitesInView}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'In Use',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${status.satellitesInUse}',
                      style: const TextStyle(
                        color: Color(0xFF28A745),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Signal Strength Chart
            SizedBox(height: 200, child: _buildSignalStrengthChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildSnrIndicator() {
    final status = _currentStatus;
    if (status == null) {
      return const SizedBox.shrink();
    }
    final avgSnr = status.averageSnr;

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
              'AVG SNR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Gradient Bar
            Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFDC3545), // Red
                    Color(0xFFFD7E14), // Orange
                    Color(0xFFFFC107), // Yellow
                    Color(0xFF28A745), // Green
                  ],
                  stops: [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Scale Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '00',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                Text(
                  '10',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                Text(
                  '20',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                Text(
                  '30',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                Text(
                  '50',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                Text(
                  '99',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current Value Indicator
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getSnrColor(avgSnr),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  avgSnr.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomModules() {
    return Container(
      height: 100,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Color(0xFF333333), width: 1)),
      ),
      child: Row(
        children: [
          _buildBottomModule(Icons.radar, 'Skyplot', const Color(0xFF00E5FF)),
          _buildBottomModule(Icons.public, 'Map', const Color(0xFF28A745)),
          _buildBottomModule(Icons.explore, 'Compass', const Color(0xFF17A2B8)),
          _buildBottomModule(Icons.speed, 'Speed', const Color(0xFFFFC107)),
          _buildBottomModule(
            Icons.access_time,
            'Time',
            const Color(0xFF6F42C1),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomModule(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalStrengthChart() {
    final usedSatellites = _satellites.where((s) => s.usedInFix).toList();
    if (usedSatellites.isEmpty) {
      return const Center(
        child: Text(
          'No satellites used in fix',
          style: TextStyle(color: Color(0xFF6C757D), fontSize: 14),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Grid lines
            Expanded(
              child: CustomPaint(
                painter: GridPainter(),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: usedSatellites.length,
                  itemBuilder: (context, index) {
                    final satellite = usedSatellites[index];
                    final height = (satellite.snr / 50.0 * 120).clamp(
                      10.0,
                      120.0,
                    );

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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF333333),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${satellite.svid}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            satellite.snr.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 8,
                              fontFamily: 'monospace',
                              color: Color(0xFF6C757D),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFixTypeColor(GnssFixType fixType) {
    switch (fixType) {
      case GnssFixType.fix3D:
        return const Color(0xFF28A745);
      case GnssFixType.fix2D:
        return const Color(0xFFFFC107);
      case GnssFixType.noFix:
        return const Color(0xFFDC3545);
      case GnssFixType.gnssDeadReckoning:
        return const Color(0xFF17A2B8);
    }
  }

  IconData _getFixTypeIcon(GnssFixType fixType) {
    switch (fixType) {
      case GnssFixType.noFix:
        return Icons.gps_off;
      case GnssFixType.gnssDeadReckoning:
        return Icons.gps_not_fixed;
      case GnssFixType.fix2D:
        return Icons.gps_fixed;
      case GnssFixType.fix3D:
        return Icons.gps_fixed;
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy <= 5) return const Color(0xFF28A745);
    if (accuracy <= 10) return const Color(0xFFFFC107);
    if (accuracy <= 20) return const Color(0xFFFD7E14);
    return const Color(0xFFDC3545);
  }

  Color _getSignalColor(double snr) {
    if (snr >= 30) return const Color(0xFF28A745);
    if (snr >= 20) return const Color(0xFFFFC107);
    if (snr >= 10) return const Color(0xFFFD7E14);
    return const Color(0xFFDC3545);
  }

  Color _getSnrColor(double snr) {
    if (snr >= 30) return const Color(0xFF28A745);
    if (snr >= 20) return const Color(0xFFFFC107);
    if (snr >= 10) return const Color(0xFFFD7E14);
    return const Color(0xFFDC3545);
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
