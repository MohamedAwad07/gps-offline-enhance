import 'package:learning/services/weather_station/weather_data_model.dart';

class FloorDetectionResult {
  final int floor;
  final double altitude;
  final double confidence; // 0.0 to 1.0
  final String method;
  final String? error;
  final WeatherStationInfo?
  weatherStationInfo; // Additional weather station info
  final String? weatherSource; // Which weather service was used

  FloorDetectionResult({
    required this.floor,
    required this.altitude,
    required this.confidence,
    required this.method,
    this.error,
    this.weatherStationInfo,
    this.weatherSource,
  });

  /// Get floor description
  String get floorDescription {
    if (floor == 0) return 'Ground Floor';
    if (floor < 0) return 'Basement Level ${floor.abs()}';
    return 'Floor $floor';
  }

  /// Get confidence description
  String get confidenceDescription {
    if (confidence >= 0.8) return 'Very High';
    if (confidence >= 0.6) return 'High';
    if (confidence >= 0.4) return 'Medium';
    if (confidence >= 0.2) return 'Low';
    return 'Very Low';
  }

  @override
  String toString() {
    return 'Floor: $floorDescription, Altitude: ${altitude.toStringAsFixed(2)}m, Confidence: $confidenceDescription (${(confidence * 100).toStringAsFixed(1)}%), Method: $method';
  }
}
