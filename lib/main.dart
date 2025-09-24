import 'package:flutter/material.dart';
import 'package:learning/services/background_services.dart';
import 'package:learning/screens/home_screen/home_screen.dart';
import 'package:learning/services/floor_detection/floor_detection_service.dart';
import 'package:learning/providers/barometric_altimeter_provider.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  await Permission.location.isDenied.then((value) {
    if (value) {
      Permission.location.request();
    }
  });

  await initializeService();

  await FloorDetectionService.startFloorDetection();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BarometricAltimeterProvider()),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HomePage(),
      ),
    ),
  );
}
