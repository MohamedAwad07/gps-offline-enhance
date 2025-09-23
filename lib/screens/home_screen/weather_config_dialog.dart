import 'package:flutter/material.dart';
import 'package:learning/services/weather_config.dart';

class WeatherConfigDialog extends StatelessWidget {
  const WeatherConfigDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Weather Service Configuration'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Current Status:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Configured: ${WeatherConfig.isConfigured ? "Yes" : "No"}',
              style: TextStyle(
                color: WeatherConfig.isConfigured ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Available Services:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...WeatherConfig.availableServices.map(
              (service) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text('• $service'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Configuration Instructions:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              WeatherConfig.configurationInstructions,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
