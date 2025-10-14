import 'package:flutter/material.dart';
import 'package:testgps/diff_scenario_offline_screen.dart';
import 'package:testgps/screens/gnss_dashboard.dart';
import 'package:testgps/screens/gnss_test_screen.dart';
import 'package:testgps/screens/gnss_simple_test.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Location Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const LocationTestUI(),
    const GnssSimpleTest(),
    const GnssTestScreen(),
  ];

  final List<String> _titles = [
    'Location Service Test',
    'GNSS Simple Test',
    'GNSS Test Suite',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Location Test',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.satellite),
            label: 'GNSS Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science),
            label: 'Test Suite',
          ),
        ],
      ),
    );
  }
}
