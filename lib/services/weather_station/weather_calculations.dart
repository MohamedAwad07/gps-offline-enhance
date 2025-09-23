import 'dart:math';
import 'package:learning/services/weather_station/weather_data_model.dart';

/// Weather-based calculations for altitude and floor detection
class WeatherCalculations {
  /// Calculate altitude from atmospheric pressure using barometric formula
  static double calculateAltitudeFromPressure(double pressure) {
    const double seaLevelPressure = 1013.25; // hPa
    const double temperature = 15.0; // °C (standard temperature)
    const double lapseRate = 0.0065; // K/m

    // Barometric formula: h = (T0 / L) * (1 - (P / P0)^(R * L / (g * M)))
    // Simplified version for approximate altitude calculation
    const double R = 8.31447; // Universal gas constant
    const double g = 9.80665; // Gravitational acceleration
    const double M = 0.0289644; // Molar mass of dry air

    final double altitude =
        (temperature / lapseRate) *
        (1 - pow(pressure / seaLevelPressure, (R * lapseRate) / (g * M)));

    return altitude;
  }

  /// Calculate floor number from altitude
  static int calculateFloorFromAltitude(
    double altitude, {
    double floorHeight = 3.5,
  }) {
    return (altitude / floorHeight).round();
  }

  /// Calculate confidence based on weather data quality
  static double calculateWeatherConfidence(WeatherData weatherData) {
    double confidence = 0.7; // Base confidence for weather data

    // Adjust based on data recency
    final age = DateTime.now().difference(weatherData.timestamp);
    if (age.inMinutes < 15) {
      confidence += 0.2; // Very recent data
    } else if (age.inMinutes < 60) {
      confidence += 0.1; // Recent data
    } else {
      confidence -= 0.1; // Old data
    }

    // Adjust based on pressure value reasonableness
    if (weatherData.pressure >= 950 && weatherData.pressure <= 1050) {
      confidence += 0.1; // Reasonable pressure range
    } else {
      confidence -= 0.2; // Unusual pressure
    }

    // Adjust based on data source reliability
    switch (weatherData.source) {
      case 'OpenWeatherMap':
        confidence += 0.1;
        break;
      case 'WeatherAPI':
        confidence += 0.05;
        break;
      case 'Open-Meteo':
        confidence += 0.0;
        break;
    }

    return (confidence * 100).round() / 100; // Round to 2 decimal places
  }
}
