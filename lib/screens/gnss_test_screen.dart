import 'package:flutter/material.dart';
import 'package:testgps/services/enhanced_location_service.dart';
import 'package:testgps/services/offline_positioning_service.dart';
import 'package:testgps/models/gnss_models.dart';
import 'dart:async';

/// GNSS Test Screen for validating native implementation
/// Comprehensive testing of offline positioning and GNSS capabilities
class GnssTestScreen extends StatefulWidget {
  const GnssTestScreen({super.key});

  @override
  State<GnssTestScreen> createState() => _GnssTestScreenState();
}

class _GnssTestScreenState extends State<GnssTestScreen> {
  final EnhancedLocationService _enhancedService = EnhancedLocationService();
  final OfflinePositioningService _offlineService = OfflinePositioningService();

  bool _isInitialized = false;
  bool _isTesting = false;
  String _testStatus = 'Ready to test';

  // Test results
  final List<TestResult> _testResults = [];
  GnssCapabilities? _capabilities;
  PositioningStats? _positioningStats;

  // Current status
  GnssStatus? _currentStatus;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _enhancedService.dispose();
    _offlineService.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _testStatus = 'Initializing services...';
    });

    try {
      final enhancedInitialized = await _enhancedService.initialize();
      final offlineInitialized = await _offlineService.initialize();

      if (enhancedInitialized && offlineInitialized) {
        _capabilities = await _enhancedService.getGnssCapabilities();
        _positioningStats = _offlineService.getStats();

        setState(() {
          _isInitialized = true;
          _testStatus = 'Services initialized successfully';
        });
      } else {
        setState(() {
          _testStatus = 'Failed to initialize services';
        });
      }
    } catch (e) {
      setState(() {
        _testStatus = 'Initialization error: $e';
      });
    }
  }

  Future<void> _runBasicGnssTest() async {
    if (!_isInitialized) return;

    setState(() {
      _isTesting = true;
      _testStatus = 'Running basic GNSS test...';
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Test GNSS native service
      final status = await _enhancedService.getCurrentGnssStatus();

      stopwatch.stop();

      setState(() {
        _currentStatus = status;
        _testStatus = 'Basic GNSS test completed';
        _isTesting = false;
      });

      _addTestResult(
        TestResult(
          name: 'Basic GNSS Test',
          success: status != null,
          duration: stopwatch.elapsed,
          details: status != null
              ? 'Fix: ${status.fixType.name}, Satellites: ${status.satellitesInUse}/${status.satellitesInView}, Accuracy: ${status.accuracy.toStringAsFixed(1)}m'
              : 'No GNSS status available',
        ),
      );
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _testStatus = 'Basic GNSS test failed: $e';
        _isTesting = false;
      });

      _addTestResult(
        TestResult(
          name: 'Basic GNSS Test',
          success: false,
          duration: stopwatch.elapsed,
          details: 'Error: $e',
        ),
      );
    }
  }

  Future<void> _runOfflinePositioningTest() async {
    if (!_isInitialized) return;

    setState(() {
      _isTesting = true;
      _testStatus = 'Running offline positioning test...';
    });

    final stopwatch = Stopwatch()..start();

    try {
      // Ensure GNSS tracking is started for the test
      final trackingStarted = await _enhancedService.startTracking();
      if (!trackingStarted) {
        throw Exception('Failed to start GNSS tracking for offline test');
      }

      // Test offline positioning with cold start
      // Don't manage tracking lifecycle since we started it above
      final status = await _offlineService.getPositionWithOfflineOptimization(
        forceColdStart: true,
        timeout: const Duration(minutes: 5),
        manageTracking: false, // Don't manage tracking lifecycle
      );

      stopwatch.stop();

      setState(() {
        _currentStatus = status;
        _testStatus = 'Offline positioning test completed';
        _isTesting = false;
      });

      _addTestResult(
        TestResult(
          name: 'Offline Positioning Test',
          success: status != null,
          duration: stopwatch.elapsed,
          details: status != null
              ? 'Fix: ${status.fixType.name}, Accuracy: ${status.accuracy.toStringAsFixed(1)}m, TTFF: ${stopwatch.elapsed.inSeconds}s'
              : 'No position fix obtained',
        ),
      );
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _testStatus = 'Offline positioning test failed: $e';
        _isTesting = false;
      });

      _addTestResult(
        TestResult(
          name: 'Offline Positioning Test',
          success: false,
          duration: stopwatch.elapsed,
          details: 'Error: $e',
        ),
      );
    }
  }

  Future<void> _runCapabilitiesTest() async {
    if (!_isInitialized) return;

    setState(() {
      _isTesting = true;
      _testStatus = 'Testing GNSS capabilities...';
    });

    final stopwatch = Stopwatch()..start();

    try {
      final capabilities = await _enhancedService.getGnssCapabilities();
      stopwatch.stop();

      setState(() {
        _testStatus = 'Capabilities test completed';
        _isTesting = false;
      });

      _addTestResult(
        TestResult(
          name: 'GNSS Capabilities Test',
          success: capabilities != null,
          duration: stopwatch.elapsed,
          details: capabilities != null
              ? 'Constellations: ${capabilities.supportedConstellations.join(', ')}, Max Satellites: ${capabilities.maxSatellites}'
              : 'No capabilities available',
        ),
      );
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _testStatus = 'Capabilities test failed: $e';
        _isTesting = false;
      });

      _addTestResult(
        TestResult(
          name: 'GNSS Capabilities Test',
          success: false,
          duration: stopwatch.elapsed,
          details: 'Error: $e',
        ),
      );
    }
  }

  Future<void> _runComprehensiveTest() async {
    if (!_isInitialized) return;

    setState(() {
      _isTesting = true;
      _testStatus = 'Running comprehensive test suite...';
    });

    // Clear previous results
    setState(() {
      _testResults.clear();
    });

    // Run all tests sequentially
    await _runCapabilitiesTest();
    await Future.delayed(const Duration(seconds: 2));

    await _runBasicGnssTest();
    await Future.delayed(const Duration(seconds: 2));

    await _runOfflinePositioningTest();

    setState(() {
      _isTesting = false;
      _testStatus = 'Comprehensive test suite completed';
    });
  }

  void _addTestResult(TestResult result) {
    setState(() {
      _testResults.insert(0, result);
    });
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 GNSS Test Suite'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildCapabilitiesCard(),
            const SizedBox(height: 16),
            _buildPositioningStatsCard(),
            const SizedBox(height: 16),
            _buildTestButtons(),
            const SizedBox(height: 16),
            _buildCurrentStatusCard(),
            const SizedBox(height: 16),
            _buildTestResultsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _isTesting ? Colors.orange[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              _isTesting ? Icons.pending : Icons.check_circle,
              size: 48,
              color: _isTesting ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              _testStatus,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_isInitialized) ...[
              const SizedBox(height: 8),
              const Text(
                '✅ Services Initialized',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
    if (_capabilities == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No capabilities data available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔧 GNSS Capabilities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Hardware Model', _capabilities!.hardwareModel),
            _buildInfoRow('Software Version', _capabilities!.softwareVersion),
            _buildInfoRow(
              'Max Satellites',
              _capabilities!.maxSatellites.toString(),
            ),
            _buildInfoRow(
              'GNSS Support',
              _capabilities!.hasGnss ? 'Yes' : 'No',
            ),
            _buildInfoRow(
              'Measurements',
              _capabilities!.hasGnssMeasurements ? 'Yes' : 'No',
            ),
            const SizedBox(height: 8),
            const Text(
              'Supported Constellations:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: _capabilities!.supportedConstellations.map((
                constellation,
              ) {
                return Chip(
                  label: Text(constellation),
                  backgroundColor: Colors.blue[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositioningStatsCard() {
    if (_positioningStats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No positioning stats available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Positioning Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Cold Start',
              _positioningStats!.isColdStart ? 'Yes' : 'No',
            ),
            _buildInfoRow(
              'Last Fix',
              _positioningStats!.lastFixTime?.toString() ?? 'Never',
            ),
            _buildInfoRow(
              'Time Since Last Fix',
              _positioningStats!.timeSinceLastFix?.toString() ?? 'N/A',
            ),
            _buildInfoRow(
              'Estimated Start Type',
              _positioningStats!.estimatedStartType.name,
            ),
            _buildInfoRow(
              'Almanac Cache',
              '${_positioningStats!.almanacCacheSize} entries',
            ),
            _buildInfoRow(
              'Ephemeris Cache',
              '${_positioningStats!.ephemerisCacheSize} entries',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isTesting ? null : _runComprehensiveTest,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Run Comprehensive Test'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _runBasicGnssTest,
                icon: const Icon(Icons.satellite),
                label: const Text('Basic GNSS'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _runOfflinePositioningTest,
                icon: const Icon(Icons.offline_bolt),
                label: const Text('Offline Test'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _runCapabilitiesTest,
                icon: const Icon(Icons.info),
                label: const Text('Capabilities'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _testResults.isEmpty ? null : _clearResults,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Results'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentStatusCard() {
    if (_currentStatus == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No current GNSS status',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📍 Current GNSS Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Fix Type', _currentStatus!.fixType.name),
            _buildInfoRow(
              'Accuracy',
              '${_currentStatus!.accuracy.toStringAsFixed(1)} m',
            ),
            _buildInfoRow(
              'Satellites',
              '${_currentStatus!.satellitesInUse}/${_currentStatus!.satellitesInView}',
            ),
            _buildInfoRow(
              'Average SNR',
              '${_currentStatus!.averageSnr.toStringAsFixed(1)} dB-Hz',
            ),
            _buildInfoRow(
              'Latitude',
              _currentStatus!.latitude.toStringAsFixed(6),
            ),
            _buildInfoRow(
              'Longitude',
              _currentStatus!.longitude.toStringAsFixed(6),
            ),
            _buildInfoRow(
              'Altitude',
              '${_currentStatus!.altitude.toStringAsFixed(1)} m',
            ),
            _buildInfoRow(
              'Speed',
              '${_currentStatus!.speed.toStringAsFixed(1)} m/s',
            ),
            _buildInfoRow(
              'Bearing',
              '${_currentStatus!.bearing.toStringAsFixed(1)}°',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsList() {
    if (_testResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Test Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._testResults.map((result) => _buildTestResultItem(result)),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultItem(TestResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.success ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${result.duration.inSeconds}s',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          if (result.details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              result.details,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class TestResult {
  final String name;
  final bool success;
  final Duration duration;
  final String details;

  TestResult({
    required this.name,
    required this.success,
    required this.duration,
    required this.details,
  });
}
