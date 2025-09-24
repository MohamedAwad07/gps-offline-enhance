import 'package:flutter/material.dart';
import 'package:learning/screens/barometric_altimeter/barometric_altimeter_screen.dart';

class ControlButtonsCard extends StatelessWidget {
  final VoidCallback onRefreshDetection;
  final VoidCallback onTestWeatherFloorDetection;

  const ControlButtonsCard({
    super.key,
    required this.onRefreshDetection,
    required this.onTestWeatherFloorDetection,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Refresh Detection
            ElevatedButton.icon(
              onPressed: onRefreshDetection,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Detection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            // Test Weather Floor Detection Only
            ElevatedButton.icon(
              onPressed: onTestWeatherFloorDetection,
              icon: const Icon(Icons.location_on),
              label: const Text('Test Weather Floor Detection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Barometric Altimeter
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BarometricAltimeterScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.height),
              label: const Text('Barometric Altimeter'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: const Color.fromRGBO(96, 99, 240, 1.0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
