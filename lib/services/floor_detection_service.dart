import 'dart:async';
import 'package:learning/models/floor_detection_result.dart';
import 'barometer_service.dart';
import 'wifi_floor_detection.dart';
import 'gps_altitude_service.dart';
import 'weather_station_service.dart';
import 'package:learning/utils/app_logger.dart';

/// Main service that combines all floor detection methods
class FloorDetectionService {
  static final StreamController<FloorDetectionResult> _resultController =
      StreamController<FloorDetectionResult>.broadcast();
  static Timer? _detectionTimer;
  static bool _isMonitoring = false;

  /// Start comprehensive floor detection
  static Future<void> startFloorDetection({
    Duration interval = const Duration(seconds: 5),
  }) async {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Initial detection
    await _performDetection();

    // Set up periodic detection
    _detectionTimer = Timer.periodic(interval, (_) async {
      await _performDetection();
    });
  }

  /// Stop floor detection
  static void stopFloorDetection() {
    _isMonitoring = false;
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  /// Get stream of floor detection results
  static Stream<FloorDetectionResult> get detectionStream =>
      _resultController.stream;

  /// Perform single detection using all available methods
  static Future<FloorDetectionResult> detectFloor() async {
    AppLogger.info('Starting floor detection', source: 'FloorDetection');
    final results = <FloorDetectionResult>[];

    // Try barometer detection
    try {
      final barometerResult = await BarometerService.detectFloor();
      AppLogger.info(
        'Barometer result: Floor: ${barometerResult.floor}, Altitude: ${barometerResult.altitude.toStringAsFixed(2)}m, Confidence: ${(barometerResult.confidence * 100).toStringAsFixed(1)}%, Method: ${barometerResult.method}',
        source: 'Barometer',
      );
      if (barometerResult.error == null) {
        results.add(barometerResult);
      } else {
        AppLogger.error(
          'Barometer error: ${barometerResult.error}',
          source: 'Barometer',
        );
      }
    } catch (e) {
      AppLogger.error('Barometer exception: $e', source: 'Barometer');
    }

    //   // Try GPS detection
    //   try {
    //     final gpsResult = await GPSAltitudeService.detectFloor();
    //     AppLogger.info('GPS result: Floor: ${gpsResult.floor}, Altitude: ${gpsResult.altitude.toStringAsFixed(2)}m, Confidence: ${(gpsResult.confidence * 100).toStringAsFixed(1)}%, Method: ${gpsResult.method}', source: 'GPS');
    //     if (gpsResult.error == null) {
    //       results.add(gpsResult);
    //     } else {
    //       AppLogger.error('GPS error: ${gpsResult.error}', source: 'GPS');
    //     }
    //   } catch (e) {
    //     // GPS detection failed
    //     AppLogger.error('GPS exception: $e', source: 'GPS');
    //   }
    //   try {
    //     final wifiResult = await WiFiFloorDetection.detectFloor();
    //     AppLogger.info('WiFi result: Floor: ${wifiResult.floor}, Altitude: ${wifiResult.altitude.toStringAsFixed(2)}m, Confidence: ${(wifiResult.confidence * 100).toStringAsFixed(1)}%, Method: ${wifiResult.method}', source: 'WiFi');
    //     if (wifiResult.error == null) {
    //       results.add(wifiResult);
    //     } else {
    //       AppLogger.error('WiFi error: ${wifiResult.error}', source: 'WiFi');
    //     }
    //   } catch (e) {
    //     // WiFi detection failed
    //     AppLogger.error('WiFi exception: $e', source: 'WiFi');
    //   }
    //   final combinedResult = _combineResults(results);
    //   AppLogger.info('Combined result: Floor: ${combinedResult.floor}, Altitude: ${combinedResult.altitude.toStringAsFixed(2)}m, Confidence: ${(combinedResult.confidence * 100).toStringAsFixed(1)}%, Method: ${combinedResult.method}', source: 'Combined');
    //   return combinedResult;
    // }
    return results.first;
  }

  /// Perform detection and emit result
  static Future<void> _performDetection() async {
    try {
      final result = await detectFloor();
      _resultController.add(result);
      AppLogger.info('Background detection completed', source: 'Background');
    } catch (e) {
      final errorResult = FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'combined',
        error: e.toString(),
      );
      _resultController.add(errorResult);
      AppLogger.error('Background detection failed: $e', source: 'Background');
    }
  }

  /// Combine multiple detection results using weighted average

  // static FloorDetectionResult _combineResults(
  //   List<FloorDetectionResult> results,
  // ) {
  //   if (results.isEmpty) {
  //     return FloorDetectionResult(
  //       floor: 0,
  //       altitude: 0,
  //       confidence: 0.0,
  //       method: 'combined',
  //       error: 'No detection methods available',
  //     );
  //   }

  //   // Filter results by minimum confidence
  //   final validResults = results.where((result) {
  //     final minConf = _minConfidence[result.method] ?? 0.0;
  //     return result.confidence >= minConf;
  //   }).toList();

  //   if (validResults.isEmpty) {
  //     // If no valid results, return the best available
  //     final bestResult = results.reduce(
  //       (a, b) => a.confidence > b.confidence ? a : b,
  //     );
  //     return FloorDetectionResult(
  //       floor: bestResult.floor,
  //       altitude: bestResult.altitude,
  //       confidence: bestResult.confidence * 0.5, // Reduce confidence
  //       method: 'combined',
  //       error: 'Low confidence detection',
  //     );
  //   }
  //   // Calculate weighted average
  //   double weightedFloorSum = 0;
  //   double weightedAltitudeSum = 0;
  //   double totalWeight = 0;
  //   double maxConfidence = 0;
  //   String primaryMethod = '';

  //   for (final result in validResults) {
  //     final weight = _methodWeights[result.method] ?? 0.1;
  //     final adjustedWeight = weight * result.confidence;

  //     weightedFloorSum += result.floor * adjustedWeight;
  //     weightedAltitudeSum += result.altitude * adjustedWeight;
  //     totalWeight += adjustedWeight;

  //     if (result.confidence > maxConfidence) {
  //       maxConfidence = result.confidence;
  //       primaryMethod = result.method;
  //     }
  //   }

  //   if (totalWeight == 0) {
  //     return FloorDetectionResult(
  //       floor: 0,
  //       altitude: 0,
  //       confidence: 0.0,
  //       method: 'combined',
  //       error: 'No valid detections',
  //     );
  //   }

  //   final finalFloor = (weightedFloorSum / totalWeight).round();
  //   final finalAltitude = weightedAltitudeSum / totalWeight;
  //   final finalConfidence = min(
  //     1.0,
  //     maxConfidence * 0.8,
  //   ); // Slightly reduce confidence for combined result

  //   return FloorDetectionResult(
  //     floor: finalFloor,
  //     altitude: finalAltitude,
  //     confidence: finalConfidence,
  //     method: 'combined ($primaryMethod)',
  //     error: null,
  //   );
  // }

  /// Get current floor with fallback options
  static Future<FloorDetectionResult> getCurrentFloor() async {
    return await detectFloor();
  }

  /// Get detection method status
  static Future<Map<String, bool>> getMethodStatus() async {
    return {
      'barometer': await BarometerService.isAvailable(),
      'wifi': true, // WiFi is always available
      'gps': await GPSAltitudeService.isGPSAvailable(),
    };
  }

  /// Get detailed status information for debugging
  static Future<Map<String, dynamic>> getDetailedStatus() async {
    final status = <String, dynamic>{};

    // Barometer status
    try {
      final barometerAvailable = await BarometerService.isAvailable();
      final pressure = await BarometerService.getCurrentPressure();
      final sensorInfo = await BarometerService.getSensorInfo();
      final weatherAvailable = WeatherStationService.isAvailable();
      final cachedWeather = WeatherStationService.getCachedData();

      status['barometer'] = {
        'available': barometerAvailable,
        'pressure': pressure,
        'sensor_name': sensorInfo['pressure_sensor_name'],
        'sensor_vendor': sensorInfo['pressure_sensor_vendor'],
        'weather_fallback_available': weatherAvailable,
        'cached_weather_stations': cachedWeather.length,
        'error': barometerAvailable ? null : 'Barometer sensor not available',
      };
    } catch (e) {
      status['barometer'] = {
        'available': false,
        'pressure': null,
        'sensor_name': 'Unknown',
        'sensor_vendor': 'Unknown',
        'weather_fallback_available': false,
        'cached_weather_stations': 0,
        'error': e.toString(),
      };
    }

    // GPS status
    try {
      final gpsAvailable = await GPSAltitudeService.isGPSAvailable();
      final location = await GPSAltitudeService.getCurrentLocation();
      status['gps'] = {
        'available': gpsAvailable,
        'location': location?.toString(),
        'error': gpsAvailable ? null : 'GPS not available or disabled',
      };
    } catch (e) {
      status['gps'] = {
        'available': false,
        'location': null,
        'error': e.toString(),
      };
    }

    // WiFi status
    try {
      final networks = await WiFiFloorDetection.getCurrentWiFiNetworks();
      final knownNetworks = WiFiFloorDetection.getKnownNetworks();
      status['wifi'] = {
        'available': true,
        'networks_found': networks.length,
        'known_networks': knownNetworks.length,
        'network_names': networks.map((n) => n.ssid).toList(),
        'error': networks.isEmpty ? 'No WiFi networks found' : null,
      };
    } catch (e) {
      status['wifi'] = {
        'available': false,
        'networks_found': 0,
        'known_networks': 0,
        'network_names': [],
        'error': e.toString(),
      };
    }

    return status;
  }

  /// Dispose resources
  static void dispose() {
    stopFloorDetection();
    _resultController.close();
  }
}
