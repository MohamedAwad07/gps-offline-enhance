import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:testgps/location_service.dart';
import 'package:testgps/services/enhanced_location_service.dart';
import 'package:testgps/models/gnss_models.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';

/// GNSS Dashboard - Real-time satellite and positioning data display
/// Similar to GPS Test app with comprehensive GNSS information
class GnssDashboard extends StatefulWidget {
  const GnssDashboard({super.key});

  @override
  State<GnssDashboard> createState() => _GnssDashboardState();
}

class _GnssDashboardState extends State<GnssDashboard> {
  final EnhancedLocationService _enhancedService = EnhancedLocationService();
  late final LocationService _locationService = LocationService.instance();

  bool _isInitialized = false;
  bool _isTracking = false;
  final bool _useGnssNative = true;

  GnssStatus? _currentStatus;
  List<SatelliteInfo> _satellites = [];
  Position? _geolocatorPosition;

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
    final enhancedInitialized = await _enhancedService.initialize();
    final locationInitialized = await _locationService.requestLocationService();

    if (enhancedInitialized && locationInitialized) {
      setState(() {
        _isInitialized = true;
      });

      // Listen to events
      _eventSubscription = _enhancedService.eventStream.listen(_handleEvent);

      // Get initial geolocator position
      await _updateGeolocatorPosition();

      // Don't start tracking automatically - wait for user to press FAB
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

    // Also update geolocator position
    await _updateGeolocatorPosition();
  }

  Future<void> _updateGeolocatorPosition() async {
    try {
      final position = await _locationService.getCurrentPositionWithFallback(
        timeout: const Duration(seconds: 10),
        allowLastKnown: false,
      );
      setState(() {
        _geolocatorPosition = position;
      });
    } catch (e) {
      // Keep previous position if update fails
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _enhancedService.stopTracking();
      _updateTimer?.cancel();
      _updateTimer = null;
    } else {
      await _enhancedService.startTracking(useGnssNative: _useGnssNative);
      // Start periodic updates when tracking begins
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateStatus();
      });
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
    if (status == null || !_isTracking) {
      return Row(
        children: [
          // GNSS Status Card - Not Tracking
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
                    Icon(Icons.gps_off, size: 32, color: Color(0xFF6C757D)),
                    SizedBox(height: 8),
                    Text(
                      'GNSS Status',
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
    if (status == null || _satellites.isEmpty || !_isTracking) {
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
                    ? Icons.satellite_outlined
                    : Icons.play_circle_outline,
                size: 48,
                color: const Color(0xFF6C757D),
              ),
              const SizedBox(height: 8),
              Text(
                _isTracking
                    ? 'No Satellite Data'
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
                  'Press the play button to begin GNSS tracking',
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
            const SizedBox(height: 16),

            // Geolocator Position (Standard GPS)
            _buildGeolocatorPositionSection(),
            const SizedBox(height: 16),

            // Current Position Coordinates (GNSS)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.satellite,
                        color: Color(0xFF00E5FF),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GNSS Position',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Latitude
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Latitude',
                            style: TextStyle(
                              color: Color(0xFF6C757D),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onLongPress: () => _copyToClipboard(
                              'Latitude: ${status.latitude.toStringAsFixed(8)}°',
                              'Latitude',
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: status.latitude != 0
                                    ? const Color(0xFF00E5FF).withOpacity(0.1)
                                    : const Color(0xFF6C757D).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: status.latitude != 0
                                      ? const Color(0xFF00E5FF).withOpacity(0.3)
                                      : const Color(
                                          0xFF6C757D,
                                        ).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                status.latitude != 0
                                    ? '${status.latitude.toStringAsFixed(8)}°'
                                    : '--',
                                style: TextStyle(
                                  color: status.latitude != 0
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xFF6C757D),
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Longitude
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Longitude',
                            style: TextStyle(
                              color: Color(0xFF6C757D),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onLongPress: () => _copyToClipboard(
                              'Longitude: ${status.longitude.toStringAsFixed(8)}°',
                              'Longitude',
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: status.longitude != 0
                                    ? const Color(0xFF00E5FF).withOpacity(0.1)
                                    : const Color(0xFF6C757D).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: status.longitude != 0
                                      ? const Color(0xFF00E5FF).withOpacity(0.3)
                                      : const Color(
                                          0xFF6C757D,
                                        ).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                status.longitude != 0
                                    ? '${status.longitude.toStringAsFixed(8)}°'
                                    : '--',
                                style: TextStyle(
                                  color: status.longitude != 0
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xFF6C757D),
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF28A745),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${status.accuracy.toStringAsFixed(1)}m accuracy',
                          style: const TextStyle(
                            color: Color(0xFF28A745),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${status.satellitesInUse}/${status.satellitesInView} sats',
                          style: const TextStyle(
                            color: Color(0xFF6C757D),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Position Difference Section
            _buildPositionDifferenceSection(),
            const SizedBox(height: 20),

            // Signal Strength Chart
            SizedBox(height: 240, child: _buildSignalStrengthChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildSnrIndicator() {
    final status = _currentStatus;
    if (status == null || !_isTracking) {
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
                  color: Color(0xFF6C757D),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // Gradient Bar (disabled state)
              Container(
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),

              // Scale Labels (disabled state)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '00',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    '10',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    '20',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    '30',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    '50',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    '99',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Current Value Indicator (disabled state)
              const Center(
                child: Text(
                  '--',
                  style: TextStyle(
                    color: Color(0xFF6C757D),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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

  // Widget _buildBottomModules() {
  //   return Container(
  //     height: 100,
  //     decoration: const BoxDecoration(
  //       color: Color(0xFF1A1A1A),
  //       border: Border(top: BorderSide(color: Color(0xFF333333), width: 1)),
  //     ),
  //     child: Row(
  //       children: [
  //         _buildBottomModule(Icons.radar, 'Skyplot', const Color(0xFF00E5FF)),
  //         _buildBottomModule(Icons.public, 'Map', const Color(0xFF28A745)),
  //         _buildBottomModule(Icons.explore, 'Compass', const Color(0xFF17A2B8)),
  //         _buildBottomModule(Icons.speed, 'Speed', const Color(0xFFFFC107)),
  //         _buildBottomModule(
  //           Icons.access_time,
  //           'Time',
  //           const Color(0xFF6F42C1),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildBottomModule(IconData icon, String label, Color color) {
  //   return Expanded(
  //     child: Container(
  //       margin: const EdgeInsets.all(8),
  //       decoration: BoxDecoration(
  //         color: const Color(0xFF0A0A0A),
  //         borderRadius: BorderRadius.circular(12),
  //         border: Border.all(color: color.withOpacity(0.3), width: 1),
  //       ),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(icon, color: color, size: 24),
  //           const SizedBox(height: 4),
  //           Text(
  //             label,
  //             style: TextStyle(
  //               color: color,
  //               fontSize: 10,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

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
                          // SNR measurement above the bar
                          Text(
                            satellite.snr.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Color(0xFF6C757D),
                            ),
                          ),
                          const SizedBox(height: 2),
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
                          // Satellite constellation type below the ID
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _getConstellationColor(
                                satellite.constellation,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: _getConstellationColor(
                                  satellite.constellation,
                                ).withOpacity(0.5),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              satellite.constellation,
                              style: TextStyle(
                                fontSize: 7,
                                fontFamily: 'monospace',
                                color: _getConstellationColor(
                                  satellite.constellation,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
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

  Widget _buildPositionDifferenceSection() {
    if (_geolocatorPosition == null ||
        _currentStatus?.latitude == null ||
        _currentStatus?.longitude == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF6C757D).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.compare_arrows, color: Color(0xFF6C757D), size: 32),
              SizedBox(height: 8),
              Text(
                'Position Comparison',
                style: TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Both positions needed for comparison',
                style: TextStyle(color: Color(0xFF6C757D), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final distance = _calculateDistance(
      _geolocatorPosition!.latitude,
      _geolocatorPosition!.longitude,
      _currentStatus!.latitude,
      _currentStatus!.longitude,
    );

    final accuracyDiff =
        (_geolocatorPosition!.accuracy - _currentStatus!.accuracy).abs();
    final isGnssMoreAccurate =
        _currentStatus!.accuracy < _geolocatorPosition!.accuracy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getDifferenceColor(distance).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows,
                color: Color(0xFFFFC107),
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Position Difference',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDifferenceColor(distance).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getDifferenceColor(distance),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getDifferenceLabel(distance),
                  style: TextStyle(
                    color: _getDifferenceColor(distance),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Distance
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Distance',
                      style: TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifferenceColor(distance).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getDifferenceColor(distance).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${distance.toStringAsFixed(2)}m',
                        style: TextStyle(
                          color: _getDifferenceColor(distance),
                          fontSize: 18,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Accuracy Diff',
                      style: TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isGnssMoreAccurate
                                    ? const Color(0xFF28A745)
                                    : const Color(0xFFDC3545))
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (isGnssMoreAccurate
                                      ? const Color(0xFF28A745)
                                      : const Color(0xFFDC3545))
                                  .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isGnssMoreAccurate
                                ? Icons.trending_down
                                : Icons.trending_up,
                            color: isGnssMoreAccurate
                                ? const Color(0xFF28A745)
                                : const Color(0xFFDC3545),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${accuracyDiff.toStringAsFixed(1)}m',
                            style: TextStyle(
                              color: isGnssMoreAccurate
                                  ? const Color(0xFF28A745)
                                  : const Color(0xFFDC3545),
                              fontSize: 16,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comparison Info
          Row(
            children: [
              Icon(
                isGnssMoreAccurate ? Icons.star : Icons.info_outline,
                color: isGnssMoreAccurate
                    ? const Color(0xFF28A745)
                    : const Color(0xFF6C757D),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isGnssMoreAccurate
                      ? 'GNSS is ${accuracyDiff.toStringAsFixed(1)}m more accurate'
                      : 'Geolocator is ${accuracyDiff.toStringAsFixed(1)}m more accurate',
                  style: TextStyle(
                    color: isGnssMoreAccurate
                        ? const Color(0xFF28A745)
                        : const Color(0xFF6C757D),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Haversine formula to calculate distance between two points
    const double earthRadius = 6371000; // Earth's radius in meters

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  Color _getDifferenceColor(double distance) {
    if (distance <= 1) return const Color(0xFF28A745); // Green - excellent
    if (distance <= 3) return const Color(0xFFFFC107); // Yellow - good
    if (distance <= 10) return const Color(0xFFFD7E14); // Orange - fair
    return const Color(0xFFDC3545); // Red - poor
  }

  String _getDifferenceLabel(double distance) {
    if (distance <= 1) return 'EXCELLENT';
    if (distance <= 3) return 'GOOD';
    if (distance <= 10) return 'FAIR';
    return 'POOR';
  }

  Widget _buildGeolocatorPositionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF17A2B8).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_searching,
                color: Color(0xFF17A2B8),
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Geolocator Position',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_geolocatorPosition != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Latitude
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Latitude',
                      style: TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onLongPress: () => _copyToClipboard(
                        'Geolocator Latitude: ${_geolocatorPosition!.latitude.toStringAsFixed(8)}°',
                        'Geolocator Latitude',
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17A2B8).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF17A2B8).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${_geolocatorPosition!.latitude.toStringAsFixed(8)}°',
                          style: const TextStyle(
                            color: Color(0xFF17A2B8),
                            fontSize: 16,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Longitude
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Longitude',
                      style: TextStyle(
                        color: Color(0xFF6C757D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onLongPress: () => _copyToClipboard(
                        'Geolocator Longitude: ${_geolocatorPosition!.longitude.toStringAsFixed(8)}°',
                        'Geolocator Longitude',
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17A2B8).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF17A2B8).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${_geolocatorPosition!.longitude.toStringAsFixed(8)}°',
                          style: const TextStyle(
                            color: Color(0xFF17A2B8),
                            fontSize: 16,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Geolocator Info
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF17A2B8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_geolocatorPosition!.accuracy.toStringAsFixed(1)}m accuracy',
                      style: const TextStyle(
                        color: Color(0xFF17A2B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_geolocatorPosition!.speed.toStringAsFixed(1)} m/s',
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
          ] else ...[
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.location_searching,
                    color: Color(0xFF6C757D),
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No Geolocator Position',
                    style: TextStyle(
                      color: Color(0xFF6C757D),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Standard GPS position not available',
                    style: TextStyle(color: Color(0xFF6C757D), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getConstellationColor(String constellation) {
    switch (constellation.toUpperCase()) {
      case 'GPS':
        return const Color(0xFF007BFF);
      case 'GLONASS':
        return const Color(0xFF28A745);
      case 'GALILEO':
        return const Color(0xFF6F42C1);
      case 'BEIDOU':
        return const Color(0xFFDC3545);
      case 'QZSS':
        return const Color(0xFF17A2B8);
      case 'IRNSS':
        return const Color(0xFFFD7E14);
      default:
        return const Color(0xFF6C757D);
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied to clipboard'),
            backgroundColor: const Color(0xFF28A745),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy $label'),
            backgroundColor: const Color(0xFFDC3545),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
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
