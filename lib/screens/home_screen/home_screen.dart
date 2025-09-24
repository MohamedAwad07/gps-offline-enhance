import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:learning/services/floor_detection/floor_detection_service.dart';
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/weather_station/weather_station_service.dart';
import 'package:learning/services/gps_altitude_service.dart';
import 'package:learning/screens/home_screen/floor_detection_status_card.dart';
import 'package:learning/screens/home_screen/detection_methods_status_card.dart';
import 'package:learning/screens/home_screen/control_buttons_card.dart';
import 'package:learning/screens/home_screen/background_service_card.dart';
import 'package:learning/screens/home_screen/barometer_pressure_card.dart';
import 'package:learning/screens/home_screen/weather_test_results_dialog.dart';
import 'package:learning/screens/home_screen/weather_floor_detection_results_dialog.dart';

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

  @override
  void dispose() {
    _logController.close();
    super.dispose();
  }

  Future<void> _updateMethodStatus() async {
    final status = await FloorDetectionService.getMethodStatus();
    setState(() {
      _methodStatus = status;
    });
  }

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
            FloorDetectionStatusCard(currentFloorResult: _currentFloorResult),
            const SizedBox(height: 16),
            // Barometric Pressure Card
            const BarometerPressureCard(),
            const SizedBox(height: 16),
            // Detection Methods Status
            DetectionMethodsStatusCard(methodStatus: _methodStatus),
            const SizedBox(height: 16),
            // Control Buttons
            ControlButtonsCard(
              onRefreshDetection: _onRefreshDetection,
              onTestWeatherFloorDetection: _testWeatherFloorDetection,
            ),
            const SizedBox(height: 16),
            // Background Service Controls
            const BackgroundServiceCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefreshDetection() async {
    await _updateMethodStatus();
    final result = await FloorDetectionService.detectFloor();
    setState(() {
      _currentFloorResult = result;
    });
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
      final testResult = await WeatherStationService.testWeatherService();

      Navigator.of(context).pop();

      _showWeatherTestResults(testResult);
    } catch (e) {
      Navigator.of(context).pop();

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
      builder: (context) => WeatherTestResultsDialog(
        testResult: testResult,
        onRefresh: _testWeatherService,
        onClearCache: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Weather cache cleared!'),
              backgroundColor: Colors.orange,
            ),
          );
        },
      ),
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
      final location = await GPSAltitudeService.getCurrentLocation();

      if (location?.latitude == null || location?.longitude == null) {
        Navigator.of(context).pop();
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

      final result = await WeatherStationService.detectFloor(
        latitude: location!.latitude!,
        longitude: location.longitude!,
      );

      Navigator.of(context).pop();

      _showWeatherFloorDetectionResults(result, location);
    } catch (e) {
      Navigator.of(context).pop();

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
    showDialog(
      context: context,
      builder: (context) => WeatherFloorDetectionResultsDialog(
        result: result,
        location: location,
        onRefresh: _testWeatherFloorDetection,
        onClearCache: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Weather cache cleared!'),
              backgroundColor: Colors.orange,
            ),
          );
        },
        onUseResult: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Weather floor detection completed successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}
