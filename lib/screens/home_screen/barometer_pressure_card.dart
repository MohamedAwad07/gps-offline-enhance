import 'package:flutter/material.dart';
import 'package:learning/services/barometer/barometer_service.dart';

/// Card widget to display current barometric pressure
class BarometerPressureCard extends StatefulWidget {
  const BarometerPressureCard({super.key});

  @override
  State<BarometerPressureCard> createState() => _BarometerPressureCardState();
}

class _BarometerPressureCardState extends State<BarometerPressureCard> {
  double? _currentPressure;
  bool _isBarometerAvailable = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBarometerAndGetPressure();
  }

  Future<void> _checkBarometerAndGetPressure() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if barometer is available
      final isAvailable = await BarometerService.isAvailable();

      if (!isAvailable) {
        setState(() {
          _isBarometerAvailable = false;
          _isLoading = false;
        });
        return;
      }

      // Get current pressure
      final pressure = await BarometerService.getCurrentPressure();

      setState(() {
        _isBarometerAvailable = true;
        _currentPressure = pressure;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isBarometerAvailable = false;
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshPressure() async {
    await _checkBarometerAndGetPressure();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Barometric Pressure',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _refreshPressure,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh pressure reading',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!_isBarometerAvailable)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.sensors_off, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Barometer sensor not available on this device',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error reading pressure: $_error',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else if (_currentPressure != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPressure!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'hPa',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getPressureDescription(_currentPressure!),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unable to read pressure value',
                        style: TextStyle(
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
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

  String _getPressureDescription(double pressure) {
    if (pressure < 1000) {
      return 'Low pressure';
    } else if (pressure < 1013) {
      return 'Below average';
    } else if (pressure < 1020) {
      return 'Normal pressure';
    } else if (pressure < 1030) {
      return 'High pressure';
    } else {
      return 'Very high pressure';
    }
  }
}
