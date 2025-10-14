import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'location_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Location Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LocationTestUI(),
    );
  }
}

// Test UI for the new LocationService
class LocationTestUI extends StatefulWidget {
  const LocationTestUI({super.key});

  @override
  _LocationTestUIState createState() => _LocationTestUIState();
}

class _LocationTestUIState extends State<LocationTestUI> {
  final LocationService _locationService = LocationService.instance();

  String _status = "Ready to test";
  Position? _currentPosition;
  Position? _lastKnownPosition;
  bool _isTesting = false;
  bool _useLastKnownFallback = true;
  Duration _maxLastKnownAge = Duration(minutes: 15);
  Duration _timeout = Duration(minutes: 5);

  final List<TestResult> _testResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📍 Location Service Test',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            SizedBox(height: 16),
            _buildSettingsCard(),
            SizedBox(height: 16),
            _buildTestButtons(),
            SizedBox(height: 16),
            _buildCurrentLocationCard(),
            SizedBox(height: 16),
            _buildLastKnownLocationCard(),
            SizedBox(height: 16),
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
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              _isTesting ? Icons.pending : Icons.check_circle,
              size: 48,
              color: _isTesting ? Colors.orange : Colors.green,
            ),
            SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚙️ Test Settings:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            SwitchListTile(
              title: Text('Use Last Known Fallback'),
              subtitle: Text('Use cached location if GPS is slow'),
              value: _useLastKnownFallback,
              onChanged: _isTesting
                  ? null
                  : (value) {
                      setState(() {
                        _useLastKnownFallback = value;
                      });
                    },
            ),
            ListTile(
              title: Text(
                'Max Last Known Age: ${_maxLastKnownAge.inMinutes} minutes',
              ),
              subtitle: Slider(
                value: _maxLastKnownAge.inMinutes.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                onChanged: _isTesting
                    ? null
                    : (value) {
                        setState(() {
                          _maxLastKnownAge = Duration(minutes: value.toInt());
                        });
                      },
              ),
            ),
            ListTile(
              title: Text('Timeout: ${_timeout.inMinutes} minutes'),
              subtitle: Slider(
                value: _timeout.inMinutes.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: _isTesting
                    ? null
                    : (value) {
                        setState(() {
                          _timeout = Duration(minutes: value.toInt());
                        });
                      },
              ),
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
          onPressed: _isTesting ? null : _testCurrentPosition,
          icon: Icon(Icons.my_location),
          label: Text('Test Current Position'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(16),
            backgroundColor: Colors.blue,
          ),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _isTesting ? null : _testLastKnownPosition,
          icon: Icon(Icons.history),
          label: Text('Test Last Known Position'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(16),
            backgroundColor: Colors.orange,
          ),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _isTesting ? null : _testWithFallback,
          icon: Icon(Icons.gps_fixed),
          label: Text('Test with Fallback Strategy'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(16),
            backgroundColor: Colors.green,
          ),
        ),
        SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _testResults.isEmpty ? null : _clearResults,
          icon: Icon(Icons.clear_all),
          label: Text('Clear Results'),
        ),
      ],
    );
  }

  Widget _buildCurrentLocationCard() {
    if (_currentPosition == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No current position data',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 Current Position:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              'Latitude',
              _currentPosition!.latitude.toStringAsFixed(6),
            ),
            _buildInfoRow(
              'Longitude',
              _currentPosition!.longitude.toStringAsFixed(6),
            ),
            _buildInfoRow(
              'Accuracy',
              '${_currentPosition!.accuracy.toInt()} meters',
            ),
            _buildInfoRow('Time', _formatTime(_currentPosition!.timestamp)),
            _buildInfoRow('Age', _getLocationAge(_currentPosition!)),
          ],
        ),
      ),
    );
  }

  Widget _buildLastKnownLocationCard() {
    if (_lastKnownPosition == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No last known position data',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🕒 Last Known Position:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildInfoRow(
              'Latitude',
              _lastKnownPosition!.latitude.toStringAsFixed(6),
            ),
            _buildInfoRow(
              'Longitude',
              _lastKnownPosition!.longitude.toStringAsFixed(6),
            ),
            _buildInfoRow(
              'Accuracy',
              '${_lastKnownPosition!.accuracy.toInt()} meters',
            ),
            _buildInfoRow('Time', _formatTime(_lastKnownPosition!.timestamp)),
            _buildInfoRow('Age', _getLocationAge(_lastKnownPosition!)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildTestResultsList() {
    if (_testResults.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Test Results:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ..._testResults.map((result) => _buildTestResultItem(result)),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultItem(TestResult result) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
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
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.testName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${result.duration.inSeconds}s',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          if (result.message.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              result.message,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  // Test current position
  Future<void> _testCurrentPosition() async {
    setState(() {
      _isTesting = true;
      _status = 'Getting current position...';
    });

    Stopwatch stopwatch = Stopwatch()..start();

    try {
      Position position = await _locationService.getCurrentPosition();
      stopwatch.stop();

      setState(() {
        _currentPosition = position;
        _status = 'Success! ✅';
        _isTesting = false;
        _testResults.insert(
          0,
          TestResult(
            testName: 'Current Position',
            success: true,
            duration: stopwatch.elapsed,
            message: 'Accuracy: ${position.accuracy.toInt()}m',
          ),
        );
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _status = 'Failed ❌';
        _isTesting = false;
        _testResults.insert(
          0,
          TestResult(
            testName: 'Current Position',
            success: false,
            duration: stopwatch.elapsed,
            message: e.toString(),
          ),
        );
      });
    }
  }

  // Test last known position
  Future<void> _testLastKnownPosition() async {
    setState(() {
      _isTesting = true;
      _status = 'Getting last known position...';
    });

    Stopwatch stopwatch = Stopwatch()..start();

    try {
      Position? position = await _locationService.getLastKnownPosition();
      stopwatch.stop();

      setState(() {
        _lastKnownPosition = position;
        _status = position != null ? 'Success! ✅' : 'No last known position';
        _isTesting = false;
        _testResults.insert(
          0,
          TestResult(
            testName: 'Last Known Position',
            success: position != null,
            duration: stopwatch.elapsed,
            message: position != null
                ? 'Age: ${_getLocationAge(position)}'
                : 'No cached location',
          ),
        );
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _status = 'Failed ❌';
        _isTesting = false;
        _testResults.insert(
          0,
          TestResult(
            testName: 'Last Known Position',
            success: false,
            duration: stopwatch.elapsed,
            message: e.toString(),
          ),
        );
      });
    }
  }

  // Test with fallback strategy
  Future<void> _testWithFallback() async {
    setState(() {
      _isTesting = true;
      _status = 'Testing with fallback strategy...';
    });

    Stopwatch stopwatch = Stopwatch()..start();

    try {
      Position position = await _locationService.getCurrentPositionWithFallback(
        timeout: _timeout,
        allowLastKnown: _useLastKnownFallback,
        maxLastKnownAge: _maxLastKnownAge,
      );
      stopwatch.stop();

      setState(() {
        _currentPosition = position;
        _status = 'Success! ✅';
        _isTesting = false;
        _testResults.insert(
          0,
          TestResult(
            testName: 'Fallback Strategy',
            success: true,
            duration: stopwatch.elapsed,
            message:
                'Accuracy: ${position.accuracy.toInt()}m, Age: ${_getLocationAge(position)}',
          ),
        );
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _status = 'Failed ❌';
        _isTesting = false;
        _testResults.insert(
          0,
          TestResult(
            testName: 'Fallback Strategy',
            success: false,
            duration: stopwatch.elapsed,
            message: e.toString(),
          ),
        );
      });
    }
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  String _getLocationAge(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    if (age.inMinutes < 1) {
      return '${age.inSeconds}s ago';
    } else if (age.inHours < 1) {
      return '${age.inMinutes}m ago';
    } else {
      return '${age.inHours}h ${age.inMinutes % 60}m ago';
    }
  }
}

// Class to store test results
class TestResult {
  final String testName;
  final bool success;
  final Duration duration;
  final String message;

  TestResult({
    required this.testName,
    required this.success,
    required this.duration,
    required this.message,
  });
}
