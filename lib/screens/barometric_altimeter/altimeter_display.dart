import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning/services/weather_barometric_altimeter_service.dart';
import 'package:provider/provider.dart';
import 'package:learning/providers/barometric_altimeter_provider.dart';
import 'package:learning/widgets/elevation_stream_builder.dart';

class AltimeterDisplay extends StatefulWidget {
  const AltimeterDisplay({super.key});

  @override
  State<AltimeterDisplay> createState() => _AltimeterDisplayState();
}

class _AltimeterDisplayState extends State<AltimeterDisplay> {
  bool _hasPlatformException = false;
  bool _hasOtherError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeBarometer();
  }

  @override
  void dispose() {
    WeatherBarometricAltimeterService.stopMonitoring();
    super.dispose();
  }

  Future<void> _initializeBarometer() async {
    try {
      // Initialize the service with the provider
      final provider = Provider.of<BarometricAltimeterProvider>(
        context,
        listen: false,
      );
      WeatherBarometricAltimeterService.initialize(provider);

      // Check if weather service is available
      final available = await WeatherBarometricAltimeterService.isAvailable();
      if (!available) {
        setState(() {
          _hasOtherError = true;
          _errorMessage =
              'Weather service not available - GPS or internet required';
        });
        return;
      }

      // Initialize with sea level pressure
      provider.initializeWithSeaLevelPressure();

      // Start monitoring
      final success = await WeatherBarometricAltimeterService.startMonitoring();
      if (!success) {
        setState(() {
          _hasOtherError = true;
          _errorMessage = 'Failed to start weather monitoring';
        });
        return;
      }
    } on PlatformException catch (e) {
      setState(() {
        _hasPlatformException = true;
        _errorMessage = 'Platform error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _hasOtherError = true;
        _errorMessage = 'Unexpected error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPlatformException) {
      return _buildErrorDisplay('Platform Exception!', _errorMessage);
    } else if (_hasOtherError) {
      return _buildErrorDisplay('Error!', _errorMessage);
    } else {
      return Consumer<BarometricAltimeterProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 20),
                _buildElevatorImage(),
                const SizedBox(height: 20),
                if (provider.pZero != null)
                  ElevationStreamBuilder(pZero: provider.pZero!)
                else
                  const Text(
                    'Initializing weather service...',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                const SizedBox(height: 20),
                _buildControlButtons(provider),
                const SizedBox(height: 20),
                _buildStatusInfo(provider),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildErrorDisplay(String title, String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _hasPlatformException = false;
              _hasOtherError = false;
              _errorMessage = '';
            });
            _initializeBarometer();
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildElevatorImage() {
    return Container(
      height: 150,
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: const Color.fromRGBO(96, 99, 240, 0.1),
          child: const Icon(
            Icons.elevator,
            size: 80,
            color: Color.fromRGBO(96, 99, 240, 1.0),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons(BarometricAltimeterProvider provider) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            provider.resetPZeroValue();
            _performHapticFeedback();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reset to current pressure'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(96, 99, 240, 1.0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(35),
            ),
          ),
          child: const Text(
            'Reset',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: provider.isMonitoring
                  ? () async {
                      await WeatherBarometricAltimeterService.stopMonitoring();
                    }
                  : () async {
                      await WeatherBarometricAltimeterService.startMonitoring();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.isMonitoring
                    ? Colors.red
                    : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                provider.isMonitoring ? 'Stop' : 'Start',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                provider.initializeWithSeaLevelPressure();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Initialized with sea level pressure'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text('Sea Level', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Manual refresh button
        ElevatedButton.icon(
          onPressed: () async {
            // Trigger immediate pressure update
            final pressure =
                await WeatherBarometricAltimeterService.getCurrentPressure();
            if (pressure != null) {
              provider.setPreviousReading(pressure);
              provider.calculateAltitudeFromPressure(pressure);
              final pZero = provider.pZero;
              if (pZero != null) {
                final elevation = (log(pressure / pZero)) * -8434.356429;
                provider.updateElevation(elevation);
              }
              final service =
                  WeatherBarometricAltimeterService.getCurrentService();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Pressure updated: ${pressure.toStringAsFixed(1)} hPa via $service',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
              // Force UI update to show new service
              setState(() {});
            }
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh Pressure'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(BarometricAltimeterProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Status: ${provider.status}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Data Source: ${WeatherBarometricAltimeterService.getCurrentService()}',
            style: const TextStyle(fontSize: 14, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          if (provider.pZero != null)
            Text(
              'Reference Pressure: ${provider.pZero!.toStringAsFixed(1)} hPa',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          if (provider.previousReading != null)
            Text(
              'Current Pressure: ${provider.previousReading!.toStringAsFixed(1)} hPa',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          if (provider.currentAltitude != null) ...[
            const SizedBox(height: 8),
            Text(
              'Calculated Altitude: ${provider.currentAltitude!.toStringAsFixed(1)}m above sea level',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _performHapticFeedback() {
    HapticFeedback.mediumImpact();
    Timer(const Duration(milliseconds: 200), () {
      HapticFeedback.mediumImpact();
      Timer(const Duration(milliseconds: 500), () {
        HapticFeedback.mediumImpact();
        Timer(const Duration(milliseconds: 200), () {
          HapticFeedback.mediumImpact();
        });
      });
    });
  }
}
