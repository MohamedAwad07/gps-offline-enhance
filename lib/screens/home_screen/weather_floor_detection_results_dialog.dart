import 'package:flutter/material.dart';
import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/weather_station/weather_station_service.dart';
import 'package:learning/services/gps_altitude_service.dart';

class WeatherFloorDetectionResultsDialog extends StatelessWidget {
  final FloorDetectionResult result;
  final LocationData location;
  final VoidCallback onRefresh;
  final VoidCallback onClearCache;
  final VoidCallback? onUseResult;

  const WeatherFloorDetectionResultsDialog({
    super.key,
    required this.result,
    required this.location,
    required this.onRefresh,
    required this.onClearCache,
    this.onUseResult,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.error == null;
    final confidencePercent = (result.confidence * 100).toStringAsFixed(1);

    return AlertDialog(
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text('Latitude: ${location.latitude?.toStringAsFixed(6)}'),
                  Text('Longitude: ${location.longitude?.toStringAsFixed(6)}'),
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
                      const Icon(Icons.height, size: 16, color: Colors.orange),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
            onRefresh();
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
            onClearCache();
          },
          icon: const Icon(Icons.clear_all, size: 16),
          label: const Text('Clear Cache'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
        if (isSuccess && onUseResult != null)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onUseResult!();
            },
            child: const Text('Use Result'),
          ),
      ],
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
