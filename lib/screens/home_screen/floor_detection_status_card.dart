import 'package:flutter/material.dart';
import 'package:learning/models/floor_detection_result.dart';

class FloorDetectionStatusCard extends StatelessWidget {
  final FloorDetectionResult? currentFloorResult;

  const FloorDetectionStatusCard({super.key, required this.currentFloorResult});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Floor Detection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (currentFloorResult != null) ...[
              Text(
                'Floor: ${currentFloorResult!.floorDescription}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Altitude: ${currentFloorResult!.altitude.toStringAsFixed(2)}m above sea level',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Confidence: ${currentFloorResult!.confidenceDescription} (${(currentFloorResult!.confidence * 100).toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 14,
                  color: currentFloorResult!.confidence >= 0.6
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Method: ${currentFloorResult!.method}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (currentFloorResult!.error != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Error: ${currentFloorResult!.error}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
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
    );
  }
}
