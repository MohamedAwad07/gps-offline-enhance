import 'package:learning/services/barometer/barometer_sensor_info.dart';
import 'package:learning/services/weather_station/weather_api_clients.dart';
import 'package:learning/services/gps_altitude_service.dart';
import 'package:learning/utils/app_logger.dart';

/// Service to validate barometer sensor accuracy
class BarometerValidationService {
  /// Validate barometer reading against weather station data
  static Future<BarometerValidationResult> validateReading() async {
    try {
      // Get hardware barometer reading
      final barometerPressure = await BarometerSensorInfo.getCurrentPressure();
      if (barometerPressure == null) {
        return BarometerValidationResult(
          isValid: false,
          message: 'Hardware barometer not available',
          barometerPressure: null,
          weatherPressure: null,
          difference: null,
        );
      }

      // Get current location
      final location = await GPSAltitudeService.getCurrentLocation();
      if (location?.latitude == null || location?.longitude == null) {
        return BarometerValidationResult(
          isValid: false,
          message: 'GPS location not available for weather comparison',
          barometerPressure: barometerPressure,
          weatherPressure: null,
          difference: null,
        );
      }

      // Get weather station pressure
      final weatherData = await WeatherApiClients.getWeatherApiData(
        location!.latitude!,
        location.longitude!,
      );

      if (weatherData == null) {
        return BarometerValidationResult(
          isValid: false,
          message: 'Weather data not available for comparison',
          barometerPressure: barometerPressure,
          weatherPressure: null,
          difference: null,
        );
      }

      // Calculate difference
      final difference = (barometerPressure - weatherData.pressure).abs();

      // Determine validation status
      bool isValid;
      String message;

      if (difference <= 2.0) {
        isValid = true;
        message = 'Excellent accuracy (±${difference.toStringAsFixed(1)} hPa)';
      } else if (difference <= 5.0) {
        isValid = true;
        message = 'Good accuracy (±${difference.toStringAsFixed(1)} hPa)';
      } else if (difference <= 10.0) {
        isValid = false;
        message =
            'Poor accuracy (±${difference.toStringAsFixed(1)} hPa) - Check calibration';
      } else {
        isValid = false;
        message =
            'Very poor accuracy (±${difference.toStringAsFixed(1)} hPa) - Sensor may be faulty';
      }

      AppLogger.info(
        'Barometer validation: Hardware=${barometerPressure.toStringAsFixed(1)} hPa, Weather=${weatherData.pressure.toStringAsFixed(1)} hPa, Diff=±${difference.toStringAsFixed(1)} hPa',
        source: 'Validation',
      );

      return BarometerValidationResult(
        isValid: isValid,
        message: message,
        barometerPressure: barometerPressure,
        weatherPressure: weatherData.pressure,
        difference: difference,
        weatherSource: weatherData.source,
      );
    } catch (e) {
      AppLogger.error('Barometer validation failed: $e', source: 'Validation');
      return BarometerValidationResult(
        isValid: false,
        message: 'Validation error: ${e.toString()}',
        barometerPressure: null,
        weatherPressure: null,
        difference: null,
      );
    }
  }

  /// Get validation recommendations
  static List<String> getValidationRecommendations(
    BarometerValidationResult result,
  ) {
    final recommendations = <String>[];

    if (!result.isValid) {
      recommendations.add('📍 Move to an open area away from buildings');
      recommendations.add(
        '🌡️ Ensure stable temperature (avoid direct sunlight)',
      );
      recommendations.add('💨 Avoid windy or turbulent areas');
      recommendations.add('🔄 Try recalibrating the sensor');
    }

    if (result.difference != null) {
      if (result.difference! > 5.0) {
        recommendations.add('⚠️ Large difference detected - check for:');
        recommendations.add(
          '  • Altitude differences between you and weather station',
        );
        recommendations.add('  • Local weather variations');
        recommendations.add('  • Sensor calibration issues');
      }
    }

    recommendations.add(
      '🌐 Compare with multiple weather stations if possible',
    );
    recommendations.add('📊 Take multiple readings over time');
    recommendations.add('🏢 Consider local altitude differences');

    return recommendations;
  }

  /// Continuous validation monitoring
  static Stream<BarometerValidationResult> startValidationMonitoring({
    Duration interval = const Duration(minutes: 5),
  }) async* {
    while (true) {
      yield await validateReading();
      await Future.delayed(interval);
    }
  }
}

/// Result of barometer validation
class BarometerValidationResult {
  final bool isValid;
  final String message;
  final double? barometerPressure;
  final double? weatherPressure;
  final double? difference;
  final String? weatherSource;

  BarometerValidationResult({
    required this.isValid,
    required this.message,
    required this.barometerPressure,
    required this.weatherPressure,
    required this.difference,
    this.weatherSource,
  });

  String get accuracyGrade {
    if (difference == null) return 'N/A';

    if (difference! <= 1.0) return 'A+';
    if (difference! <= 2.0) return 'A';
    if (difference! <= 3.0) return 'B';
    if (difference! <= 5.0) return 'C';
    if (difference! <= 10.0) return 'D';
    return 'F';
  }

  @override
  String toString() {
    return 'BarometerValidation(valid: $isValid, message: $message, diff: ${difference?.toStringAsFixed(1)} hPa)';
  }
}
