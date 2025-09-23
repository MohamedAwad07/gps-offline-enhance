import 'package:flutter/material.dart';
import 'package:learning/screens/barometric_altimeter/altimeter_display.dart';
import 'package:learning/services/weather_barometric_altimeter_service.dart';

class BarometricAltimeterScreen extends StatelessWidget {
  const BarometricAltimeterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(246, 246, 246, 1.0),
      appBar: AppBar(
        title: const Text('Barometric Altimeter'),
        backgroundColor: const Color.fromRGBO(96, 99, 240, 1.0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              WeatherBarometricAltimeterService.getCurrentService(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: const SingleChildScrollView(
        child: Center(child: Column(children: <Widget>[AltimeterDisplay()])),
      ),
    );
  }
}
