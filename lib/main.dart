import 'package:flutter/material.dart';
import 'package:learning/services/background_services.dart';
import 'package:learning/services/home_screen.dart';
import 'package:learning/services/floor_detection_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request necessary permissions
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  // Request location permissions for GPS altitude detection
  await Permission.location.isDenied.then((value) {
    if (value) {
      Permission.location.request();
    }
  });

  await initializeService();

  // Start floor detection service
  await FloorDetectionService.startFloorDetection();

  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: HomePage()),
  );
}
