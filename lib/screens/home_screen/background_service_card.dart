import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class BackgroundServiceCard extends StatefulWidget {
  const BackgroundServiceCard({super.key});

  @override
  State<BackgroundServiceCard> createState() => _BackgroundServiceCardState();
}

class _BackgroundServiceCardState extends State<BackgroundServiceCard> {
  String text = "stop service";

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
              'Background Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      FlutterBackgroundService().invoke("setAsForeground");
                    },
                    child: const Text("Foreground Service"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      FlutterBackgroundService().invoke("setAsBackground");
                    },
                    child: const Text("Background Service"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final service = FlutterBackgroundService();
                final bool isRunning = await service.isRunning();
                if (isRunning) {
                  service.invoke("stopService");
                } else {
                  service.startService();
                }
                if (!isRunning) {
                  text = "Stop Service";
                } else {
                  text = "Start Service";
                }
                setState(() {});
              },
              child: Text(text),
            ),
          ],
        ),
      ),
    );
  }
}
