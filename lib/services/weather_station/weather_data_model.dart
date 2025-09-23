/// Weather data model
class WeatherData {
  final double pressure; // in hPa
  final double temperature; // in Celsius
  final double humidity; // in percentage
  final DateTime timestamp;
  final String source;

  WeatherData({
    required this.pressure,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    required this.source,
  });

  @override
  String toString() {
    return 'WeatherData(pressure: ${pressure}hPa, temp: $temperature°C, humidity: $humidity%, source: $source, time: $timestamp)';
  }
}
