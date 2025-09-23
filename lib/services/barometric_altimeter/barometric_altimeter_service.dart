// import 'dart:async';
// import 'dart:math';
// import 'package:learning/providers/barometric_altimeter_provider.dart';
// import 'package:learning/services/weather_barometric_altimeter_service.dart';

// class BarometricAltimeterService {
//   static BarometricAltimeterProvider? _provider;
//   static bool _isInitialized = false;
//   static Timer? _updateTimer;

//   /// Initialize the service with a provider
//   static void initialize(BarometricAltimeterProvider provider) {
//     _provider = provider;
//     _isInitialized = true;
//   }

//   /// Check if weather service is available (always true as it uses internet)
//   static Future<bool> isAvailable() async {
//     return await WeatherBarometricAltimeterService.isAvailable();
//   }

//   /// Start monitoring atmospheric pressure from weather services
//   static Future<bool> startMonitoring() async {
//     if (!_isInitialized || _provider == null) {
//       throw Exception('Service not initialized. Call initialize() first.');
//     }

//     try {
//       // Check if weather service is available
//       final available = await isAvailable();
//       if (!available) {
//         _provider!.setStatus(
//           'Weather service not available - GPS or internet required',
//         );
//         return false;
//       }

//       // Start periodic pressure updates (every 10 seconds for more responsive updates)
//       _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
//         _updatePressureFromWeather();
//       });

//       // Get initial pressure reading
//       await _updatePressureFromWeather();

//       _provider!.setMonitoringStatus(true);
//       _provider!.setStatus('Monitoring pressure from weather services');
//       return true;
//     } catch (e) {
//       _provider!.setStatus('Failed to start weather monitoring: $e');
//       return false;
//     }
//   }

//   /// Stop monitoring
//   static Future<void> stopMonitoring() async {
//     _updateTimer?.cancel();
//     _updateTimer = null;
//     if (_provider != null) {
//       _provider!.setMonitoringStatus(false);
//       _provider!.setStatus('Stopped monitoring');
//     }
//   }

//   /// Update pressure from weather service
//   static Future<void> _updatePressureFromWeather() async {
//     if (_provider == null) return;

//     try {
//       // Get pressure from weather service
//       final pressure =
//           await WeatherBarometricAltimeterService.getCurrentPressure();
//       if (pressure == null) {
//         _provider!.setStatus('Unable to get pressure from weather service');
//         return;
//       }

//       // Update provider with current reading
//       _provider!.setPreviousReading(pressure);

//       // Calculate absolute altitude from pressure
//       _provider!.calculateAltitudeFromPressure(pressure);
//       _provider!.setStatus(
//         'Weather pressure: ${pressure.toStringAsFixed(1)} hPa',
//       );
//     } catch (e) {
//       _provider!.setStatus('Weather update error: $e');
//     }
//   }

//   /// Get current pressure reading from weather service
//   static Future<double?> getCurrentPressure() async {
//     return await WeatherBarometricAltimeterService.getCurrentPressure();
//   }

//   /// Calculate floor number based on elevation
//   /// Assumes each floor is 3.5 meters high
//   static int calculateFloor(double elevation, {double floorHeight = 3.5}) {
//     return (elevation / floorHeight).round();
//   }

//   /// Get elevation change direction
//   static String getElevationDirection(
//     double currentElevation,
//     double previousElevation,
//   ) {
//     const double threshold = 0.5; // meters

//     if (currentElevation - previousElevation > threshold) {
//       return 'Ascending';
//     } else if (currentElevation - previousElevation < -threshold) {
//       return 'Descending';
//     } else {
//       return 'Equilibrium';
//     }
//   }

//   /// Dispose resources
//   static void dispose() {
//     stopMonitoring();
//     _provider = null;
//     _isInitialized = false;
//   }
// }
