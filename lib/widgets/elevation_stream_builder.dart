import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:learning/services/barometric_altimeter/weather_barometric_altimeter_service.dart';
import 'package:provider/provider.dart';
import '../providers/barometric_altimeter_provider.dart';

class ElevationStreamBuilder extends StatefulWidget {
  final double pZero;

  const ElevationStreamBuilder({super.key, required this.pZero});

  @override
  State<ElevationStreamBuilder> createState() => _ElevationStreamBuilderState();
}

class _ElevationStreamBuilderState extends State<ElevationStreamBuilder> {
  Timer? _updateTimer;
  StreamController<double>? _pressureStreamController;
  double? _currentPressure;

  @override
  void initState() {
    super.initState();
    _pressureStreamController = StreamController<double>.broadcast();
    _startPeriodicUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _pressureStreamController?.close();
    super.dispose();
  }

  void _startPeriodicUpdates() {
    // Update pressure data every 10 seconds for more responsive updates
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _updatePressureData();
      }
    });

    // Initial update
    _updatePressureData();
  }

  Future<void> _updatePressureData() async {
    try {
      final pressure =
          await WeatherBarometricAltimeterService.getCurrentPressure();
      if (pressure != null && mounted) {
        final provider = Provider.of<BarometricAltimeterProvider>(
          context,
          listen: false,
        );

        provider.setPreviousReading(pressure);

        // Update current pressure and stream
        _currentPressure = pressure;
        _pressureStreamController?.add(pressure);

        // Calculate absolute altitude from pressure
        provider.calculateAltitudeFromPressure(pressure);

        // Calculate elevation if we have a reference pressure
        final pZero = provider.pZero;
        if (pZero != null) {
          final elevation = _calculateHeightDifference(pressure, pZero);
          provider.updateElevation(elevation);
        }

        setState(() {}); // Trigger rebuild
      }
    } catch (e) {
      // Handle error silently or show in status
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BarometricAltimeterProvider>(
      builder: (context, provider, child) {
        final currentPressure = provider.previousReading;

        if (currentPressure == null) {
          return const Column(
            children: <Widget>[
              Text(
                'Awaiting pressure reading from weather service...',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          );
        }

        return Column(
          children: <Widget>[
            // Real-time pressure display with stream
            _buildPressureDisplay(),
            const SizedBox(height: 20),
            // Absolute altitude display
            _buildAltitudeDisplay(provider),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildPressureDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          const Text(
            'Current Atmospheric Pressure',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<double>(
            stream: _pressureStreamController?.stream,
            initialData: _currentPressure,
            builder: (context, snapshot) {
              final pressure = snapshot.data ?? _currentPressure ?? 0.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    pressure.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'hPa',
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          StreamBuilder<double>(
            stream: _pressureStreamController?.stream,
            initialData: _currentPressure,
            builder: (context, snapshot) {
              final pressure = snapshot.data ?? _currentPressure ?? 0.0;
              return Text(
                _getPressureDescription(pressure),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getPressureDescription(double pressure) {
    if (pressure < 1000) return 'Low pressure (stormy weather)';
    if (pressure < 1013) return 'Below average pressure';
    if (pressure < 1020) return 'Normal pressure';
    if (pressure < 1030) return 'High pressure (clear weather)';
    return 'Very high pressure';
  }

  Widget _buildAltitudeDisplay(BarometricAltimeterProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Altitude Above Sea Level',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          if (provider.currentAltitude != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  provider.currentAltitude!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getAltitudeDescription(provider.currentAltitude!),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Calculating altitude...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getAltitudeDescription(double altitude) {
    if (altitude < 0) return 'Below sea level';
    if (altitude < 100) return 'Near sea level';
    if (altitude < 500) return 'Low altitude';
    if (altitude < 1000) return 'Moderate altitude';
    if (altitude < 2000) return 'High altitude';
    if (altitude < 3000) return 'Very high altitude';
    if (altitude < 5000) return 'Extreme altitude';
    return 'Ultra high altitude';
  }

  double _calculateHeightDifference(double pressure, double pZero) {
    if (pressure <= 0 || pZero <= 0) return 0.0;

    // Use the same formula as ElevaTorr: h = -8434.356429 * ln(P/P0)
    return (log(pressure / pZero)) * -8434.356429;
  }
}
