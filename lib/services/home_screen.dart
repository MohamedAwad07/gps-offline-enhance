import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:learning/services/floor_detection_service.dart';
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/weather_config.dart';
import 'package:learning/services/weather_station_service.dart';
import 'package:learning/services/gps_altitude_service.dart';

/// Log entry for live log viewing
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String source;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.source,
  });

  @override
  String toString() {
    return '${timestamp.toIso8601String().substring(11, 23)} [$level] $source: $message';
  }
}

/// Custom log interceptor to capture logs
class LogInterceptor {
  static void log(String level, String message, {String source = 'App'}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      source: source,
    );

    _HomePageState._logs.add(entry);
    _HomePageState._logController.add(entry);

    // Keep only last 1000 logs to prevent memory issues
    if (_HomePageState._logs.length > 1000) {
      _HomePageState._logs.removeAt(0);
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Log collection for live viewing
  static final List<LogEntry> _logs = [];
  static final StreamController<LogEntry> _logController =
      StreamController<LogEntry>.broadcast();
  FloorDetectionResult? _currentFloorResult;
  Map<String, bool> _methodStatus = {};

  Future<void> requestLocationPermissions() async {
    await Permission.location.request();
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    await Permission.ignoreBatteryOptimizations.request();
  }

  @override
  void initState() {
    super.initState();

    Future.delayed(
      const Duration(seconds: 3),
      () => requestLocationPermissions(),
    );
    Future.delayed(
      const Duration(seconds: 6),
      () => requestIgnoreBatteryOptimizations(),
    );

    // Listen to floor detection updates
    FloorDetectionService.detectionStream.listen((result) {
      setState(() {
        _currentFloorResult = result;
      });
    });

    // Get method status
    _updateMethodStatus();
  }

  Future<void> _updateMethodStatus() async {
    final status = await FloorDetectionService.getMethodStatus();
    setState(() {
      _methodStatus = status;
    });
  }

  String text = "stop service";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Detection App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Floor Detection Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Floor Detection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_currentFloorResult != null) ...[
                      Text(
                        'Floor: ${_currentFloorResult!.floorDescription}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Altitude: ${_currentFloorResult!.altitude.toStringAsFixed(2)}m above sea level',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confidence: ${_currentFloorResult!.confidenceDescription} (${(_currentFloorResult!.confidence * 100).toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: _currentFloorResult!.confidence >= 0.6
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Method: ${_currentFloorResult!.method}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (_currentFloorResult!.error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Error: ${_currentFloorResult!.error}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ] else ...[
                      const Text(
                        'Detecting floor...',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Detection Methods Status
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detection Methods Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._methodStatus.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              entry.value ? Icons.check_circle : Icons.cancel,
                              color: entry.value ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.key.toUpperCase()}: ${entry.value ? "Available" : "Not Available"}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Control Buttons
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Refresh Detection
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _updateMethodStatus();
                        final result =
                            await FloorDetectionService.detectFloor();
                        dev.log('Refresh Detection: $result');
                        setState(() {
                          _currentFloorResult = result;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Detection'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Weather Configuration
                    ElevatedButton.icon(
                      onPressed: () {
                        _showWeatherConfigDialog();
                      },
                      icon: const Icon(Icons.cloud),
                      label: const Text('Weather Config'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Test Weather Service
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _testWeatherService();
                      },
                      icon: const Icon(Icons.science),
                      label: const Text('Test Weather Service'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Test Weather Floor Detection Only
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _testWeatherFloorDetection();
                      },
                      icon: const Icon(Icons.location_on),
                      label: const Text('Test Weather Floor Detection'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Background Service Controls
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Background Service',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              FlutterBackgroundService().invoke(
                                "setAsForeground",
                              );
                            },
                            child: const Text("Foreground Service"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              FlutterBackgroundService().invoke(
                                "setAsBackground",
                              );
                            },
                            child: const Text("Background Service"),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    ElevatedButton(
                      onPressed: () async {
                        final service = FlutterBackgroundService();
                        final bool isRunning = await service.isRunning();
                        if (isRunning) {
                          service.invoke("stopService");
                        } else {
                          service.startService();
                        }
                        if (!isRunning) {
                          text = "Stop Service";
                        } else {
                          text = "Start Service";
                        }
                        setState(() {});
                      },
                      child: Text(text),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeatherConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weather Service Configuration'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Current Status:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Configured: ${WeatherConfig.isConfigured ? "Yes" : "No"}',
                style: TextStyle(
                  color: WeatherConfig.isConfigured ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Available Services:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...WeatherConfig.availableServices.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• $service'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Configuration Instructions:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                WeatherConfig.configurationInstructions,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _testWeatherService() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SizedBox(
        height: 300,
        width: 34,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      // Run the weather service test
      final testResult = await WeatherStationService.testWeatherService();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show test results
      _showWeatherTestResults(testResult);
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weather test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWeatherTestResults(Map<String, dynamic> testResult) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          testResult['overall_success'] == true
              ? '✅ Weather Test Passed'
              : '❌ Weather Test Failed',
          style: TextStyle(
            color: testResult['overall_success'] == true
                ? Colors.green
                : Colors.red,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTestSection('Overall Status', [
                'Test Successful: ${testResult['test_successful']}',
                'Overall Success: ${testResult['overall_success']}',
                'Timestamp: ${testResult['timestamp']}',
              ]),

              const SizedBox(height: 16),

              _buildTestSection(
                'Services Tested',
                testResult['services_tested'],
              ),

              const SizedBox(height: 16),

              _buildTestSection(
                'Successful Services',
                testResult['successful_services'].isNotEmpty
                    ? testResult['successful_services']
                    : ['None'],
              ),

              const SizedBox(height: 16),

              if (testResult['failed_services'].isNotEmpty) ...[
                _buildTestSection(
                  'Failed Services',
                  testResult['failed_services'],
                ),
                const SizedBox(height: 16),
              ],

              if (testResult['final_result'] != null) ...[
                _buildTestSection('Final Result', [
                  'Floor: ${testResult['final_result']['floor']}',
                  'Altitude: ${testResult['final_result']['altitude']?.toStringAsFixed(2)}m',
                  'Confidence: ${(testResult['final_result']['confidence'] * 100).toStringAsFixed(1)}%',
                  'Method: ${testResult['final_result']['method']}',
                  if (testResult['final_result']['error'] != null)
                    'Error: ${testResult['final_result']['error']}',
                ]),
                const SizedBox(height: 16),
              ],

              _buildTestSection('Cache Status', [
                'Cached Locations: ${testResult['cache_status']['cached_locations']}',
                'Cache Valid: ${testResult['cache_status']['cache_valid']}',
                'Last Update: ${testResult['cache_status']['last_update'] ?? 'Never'}',
              ]),

              if (testResult['errors'].isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildTestSection('Errors', testResult['errors']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _testWeatherService();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              WeatherStationService.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Weather cache cleared!'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear Cache'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection(String title, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text('• $item', style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Future<void> _testWeatherFloorDetection() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SizedBox(
        height: 300,
        width: 34,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      // Get current location first
      final location = await GPSAltitudeService.getCurrentLocation();

      if (location?.latitude == null || location?.longitude == null) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ GPS location not available. Please enable location services.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Test weather floor detection with current location
      final result = await WeatherStationService.detectFloor(
        latitude: location!.latitude!,
        longitude: location.longitude!,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show results
      _showWeatherFloorDetectionResults(result, location);
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Weather floor detection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWeatherFloorDetectionResults(
    FloorDetectionResult result,
    LocationData location,
  ) {
    final isSuccess = result.error == null;
    final confidencePercent = (result.confidence * 100).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isSuccess
              ? '🌤️ Weather Floor Detection'
              : '❌ Weather Detection Failed',
          style: TextStyle(
            color: isSuccess ? Colors.green : Colors.red,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Location Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📍 Location Used:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Latitude: ${location.latitude?.toStringAsFixed(6)}'),
                    Text(
                      'Longitude: ${location.longitude?.toStringAsFixed(6)}',
                    ),
                    Text('Altitude: ${location.altitude?.toStringAsFixed(2)}m'),
                    Text('Accuracy: ${location.accuracy?.toStringAsFixed(1)}m'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Detection Results
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSuccess
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Detection Results:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSuccess
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Floor
                    Row(
                      children: [
                        const Icon(Icons.stairs, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Floor: ${_getFloorDisplayName(result.floor)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Altitude
                    Row(
                      children: [
                        const Icon(
                          Icons.height,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Altitude: ${result.altitude.toStringAsFixed(2)}m',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Confidence
                    Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          size: 16,
                          color: _getConfidenceColor(result.confidence),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Confidence: ${_getConfidenceLevel(result.confidence)} ($confidencePercent%)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _getConfidenceColor(result.confidence),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Method
                    Row(
                      children: [
                        const Icon(Icons.cloud, size: 16, color: Colors.purple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Method: ${result.method}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (result.error != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: ${result.error}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Additional Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ℹ️ Additional Information:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• This test uses weather data to estimate floor and altitude',
                    ),
                    Text(
                      '• Results are based on atmospheric pressure differences',
                    ),
                    Text(
                      '• Weather data is cached for 30 minutes to reduce API calls',
                    ),
                    Text(
                      '• Free weather services (Open-Meteo) are used by default',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _testWeatherFloorDetection();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              WeatherStationService.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Weather cache cleared!'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear Cache'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          if (isSuccess)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // You could add functionality to save this result or use it
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ Weather floor detection completed successfully!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Use Result'),
            ),
        ],
      ),
    );
  }

  String _getFloorDisplayName(int floor) {
    if (floor == 0) return 'Ground Floor';
    if (floor > 0) return 'Floor $floor';
    return 'Basement Level ${-floor}';
  }

  String _getConfidenceLevel(double confidence) {
    if (confidence >= 0.8) return 'Very High';
    if (confidence >= 0.6) return 'High';
    if (confidence >= 0.4) return 'Medium';
    if (confidence >= 0.2) return 'Low';
    return 'Very Low';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.lightGreen;
    if (confidence >= 0.4) return Colors.orange;
    if (confidence >= 0.2) return Colors.deepOrange;
    return Colors.red;
  }
}
