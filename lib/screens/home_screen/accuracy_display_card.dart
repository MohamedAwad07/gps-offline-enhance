import 'package:flutter/material.dart';
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/accuracy/altitude_accuracy_service.dart';
import 'package:learning/services/calibration/pressure_calibration_service.dart';

/// Card displaying accuracy metrics and calibration status
class AccuracyDisplayCard extends StatelessWidget {
  final FloorDetectionResult? currentResult;

  const AccuracyDisplayCard({super.key, required this.currentResult});

  @override
  Widget build(BuildContext context) {
    if (currentResult == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Accuracy Metrics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'No detection results available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accuracy = AltitudeAccuracyService.calculateAccuracy(currentResult!);
    final floorAccuracy = AltitudeAccuracyService.calculateFloorAccuracy(
      currentResult!,
    );
    final recommendations = AltitudeAccuracyService.getAccuracyRecommendations(
      accuracy,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: _getAccuracyColor(accuracy.accuracyGrade),
                ),
                const SizedBox(width: 8),
                Text(
                  'Accuracy Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getAccuracyColor(
                      accuracy.accuracyGrade,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getAccuracyColor(
                        accuracy.accuracyGrade,
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    accuracy.accuracyGrade.displayName,
                    style: TextStyle(
                      color: _getAccuracyColor(accuracy.accuracyGrade),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Detection Method Indicator (PRIORITY DISPLAY)
            _buildMetricRow(
              'Detection Method',
              _getMethodDescription(currentResult!.method),
              _getMethodIcon(currentResult!.method),
              _getMethodColor(currentResult!.method),
            ),
            const SizedBox(height: 8),

            // Altitude Accuracy
            _buildMetricRow(
              'Altitude Accuracy',
              accuracy.accuracyDescription,
              Icons.height,
              Colors.blue,
            ),
            const SizedBox(height: 8),

            // Confidence Interval
            _buildMetricRow(
              'Confidence Interval',
              accuracy.confidenceIntervalDescription,
              Icons.show_chart,
              Colors.green,
            ),
            const SizedBox(height: 8),

            // Floor Confidence
            _buildMetricRow(
              'Floor Detection',
              '${floorAccuracy.floorDescription} (${floorAccuracy.probabilityDescription})',
              Icons.layers,
              Colors.orange,
            ),
            const SizedBox(height: 8),

            // Possible Floor Range
            if (floorAccuracy.possibleFloorRange.span > 1)
              _buildMetricRow(
                'Possible Range',
                floorAccuracy.possibleFloorRange.description,
                Icons.vertical_align_center,
                Colors.amber,
              ),

            const SizedBox(height: 16),

            // Calibration Status
            _buildCalibrationStatus(accuracy.calibrationStatus),

            // Recommendations
            if (recommendations.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Recommendations',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...recommendations.map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.grey)),
                      Expanded(
                        child: Text(
                          rec,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Flexible(
          flex: 2,
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationStatus(CalibrationStatus status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.isCalibrated
            ? (status.isCalibrationNeeded
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1))
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.isCalibrated
              ? (status.isCalibrationNeeded
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.green.withOpacity(0.3))
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            status.isCalibrated
                ? (status.isCalibrationNeeded
                      ? Icons.warning
                      : Icons.check_circle)
                : Icons.error,
            color: status.isCalibrated
                ? (status.isCalibrationNeeded ? Colors.orange : Colors.green)
                : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calibration Status',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: status.isCalibrated
                        ? (status.isCalibrationNeeded
                              ? Colors.orange
                              : Colors.green)
                        : Colors.red,
                  ),
                ),
                Text(
                  status.statusMessage,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          if (status.isCalibrationNeeded || !status.isCalibrated)
            TextButton(
              onPressed: () => _showCalibrationDialog(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Calibrate', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  void _showCalibrationDialog() {
    // TODO: Implement calibration dialog
    // This would show options for manual or automatic calibration
  }

  Color _getAccuracyColor(AccuracyGrade grade) {
    switch (grade) {
      case AccuracyGrade.aPlus:
      case AccuracyGrade.a:
        return Colors.green;
      case AccuracyGrade.b:
        return Colors.lightGreen;
      case AccuracyGrade.c:
        return Colors.orange;
      case AccuracyGrade.d:
        return Colors.deepOrange;
      case AccuracyGrade.f:
        return Colors.red;
    }
  }

  String _getMethodDescription(String method) {
    final methodLower = method.toLowerCase();
    if (methodLower.contains('barometer') && methodLower.contains('hardware')) {
      return '🎯 Hardware Barometer (Precise)';
    } else if (methodLower.contains('barometer')) {
      return '🌤️ Weather Barometer';
    } else if (methodLower.contains('fusion')) {
      return '🔄 Multi-Sensor Fusion';
    } else if (methodLower.contains('gps')) {
      return '📡 GPS Altitude';
    } else if (methodLower.contains('weather')) {
      return '🌐 Weather Station';
    }
    return '❓ $method';
  }

  IconData _getMethodIcon(String method) {
    final methodLower = method.toLowerCase();
    if (methodLower.contains('barometer') && methodLower.contains('hardware')) {
      return Icons.sensors;
    } else if (methodLower.contains('barometer')) {
      return Icons.cloud;
    } else if (methodLower.contains('fusion')) {
      return Icons.merge;
    } else if (methodLower.contains('gps')) {
      return Icons.satellite_alt;
    } else if (methodLower.contains('weather')) {
      return Icons.wb_sunny;
    }
    return Icons.help_outline;
  }

  Color _getMethodColor(String method) {
    final methodLower = method.toLowerCase();
    if (methodLower.contains('barometer') && methodLower.contains('hardware')) {
      return Colors.green; // Best method - Hardware barometer
    } else if (methodLower.contains('barometer')) {
      return Colors.blue;
    } else if (methodLower.contains('fusion')) {
      return Colors.purple;
    } else if (methodLower.contains('gps')) {
      return Colors.orange;
    } else if (methodLower.contains('weather')) {
      return Colors.lightBlue;
    }
    return Colors.grey;
  }
}
