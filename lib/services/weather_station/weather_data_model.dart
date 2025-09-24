/// Weather station information
class WeatherStationInfo {
  final String? stationId;
  final String? stationName;
  final double? stationLatitude;
  final double? stationLongitude;
  final double? distanceFromUser; // in kilometers
  final String? country;
  final String? region;
  final String? city;
  final int? elevation; // in meters

  WeatherStationInfo({
    this.stationId,
    this.stationName,
    this.stationLatitude,
    this.stationLongitude,
    this.distanceFromUser,
    this.country,
    this.region,
    this.city,
    this.elevation,
  });

  @override
  String toString() {
    return 'WeatherStationInfo(id: $stationId, name: $stationName, location: ${stationLatitude?.toStringAsFixed(4)},${stationLongitude?.toStringAsFixed(4)}, distance: ${distanceFromUser?.toStringAsFixed(1)}km, city: $city, country: $country)';
  }
}

/// Weather data model
class WeatherData {
  final double pressure; // in hPa
  final double temperature; // in Celsius
  final double humidity; // in percentage
  final DateTime timestamp;
  final String source;
  final WeatherStationInfo? stationInfo;
  final double? userLatitude; // User's location
  final double? userLongitude; // User's location

  WeatherData({
    required this.pressure,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    required this.source,
    this.stationInfo,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  String toString() {
    final stationInfoStr = stationInfo != null ? ', station: $stationInfo' : '';
    return 'WeatherData(pressure: ${pressure}hPa, temp: $temperature°C, humidity: $humidity%, source: $source, time: $timestamp$stationInfoStr)';
  }

  /// Get a user-friendly description of the weather station
  String getStationDescription() {
    if (stationInfo == null) return 'Unknown station';

    final parts = <String>[];
    if (stationInfo!.stationName != null) {
      parts.add(stationInfo!.stationName!);
    }
    if (stationInfo!.city != null) {
      parts.add(stationInfo!.city!);
    }
    if (stationInfo!.country != null) {
      parts.add(stationInfo!.country!);
    }

    final location = parts.isNotEmpty ? parts.join(', ') : 'Unknown location';
    final distance = stationInfo!.distanceFromUser != null
        ? ' (${stationInfo!.distanceFromUser!.toStringAsFixed(1)}km away)'
        : '';

    return '$location$distance';
  }
}
