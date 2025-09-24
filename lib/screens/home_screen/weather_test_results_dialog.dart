import 'package:flutter/material.dart';
import 'package:learning/services/weather_station/weather_station_service.dart';

class WeatherTestResultsDialog extends StatelessWidget {
  final Map<String, dynamic> testResult;
  final VoidCallback onRefresh;
  final VoidCallback onClearCache;

  const WeatherTestResultsDialog({
    super.key,
    required this.testResult,
    required this.onRefresh,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            _buildTestSection('Services Tested', testResult['services_tested']),
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
            // Weather Station Information
            if (testResult['openweathermap_station'] != null ||
                testResult['weatherapi_station'] != null ||
                testResult['openmeteo_station'] != null) ...[
              _buildTestSection('Weather Station Information', [
                if (testResult['openweathermap_station'] != null)
                  'OpenWeatherMap: ${testResult['openweathermap_station']}',
                if (testResult['weatherapi_station'] != null)
                  'WeatherAPI: ${testResult['weatherapi_station']}',
                if (testResult['openmeteo_station'] != null)
                  'Open-Meteo: ${testResult['openmeteo_station']}',
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
      ],
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
}
