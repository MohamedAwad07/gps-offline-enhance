import 'package:flutter/material.dart';
import 'package:learning/screens/barometric_altimeter/altimeter_display.dart';

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
      ),
      body: const SingleChildScrollView(
        child: Center(child: Column(children: <Widget>[AltimeterDisplay()])),
      ),
    );
  }
}
