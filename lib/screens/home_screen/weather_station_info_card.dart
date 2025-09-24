import 'package:flutter/material.dart';
import 'package:learning/services/weather_station/weather_station_service.dart';
import 'package:learning/services/weather_station/weather_data_model.dart';
import 'package:learning/services/gps_altitude_service.dart';

/// Card widget to display current weather station information
class WeatherStationInfoCard extends StatefulWidget {
  const WeatherStationInfoCard({super.key});

  @override
  State<WeatherStationInfoCard> createState() => _WeatherStationInfoCardState();
}

class _WeatherStationInfoCardState extends State<WeatherStationInfoCard> {
  WeatherStationInfo? _currentStationInfo;
  String? _weatherSource;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeatherStationInfo();
  }

  Future<void> _loadWeatherStationInfo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current location
      final location = await GPSAltitudeService.getCurrentLocation();

      if (location?.latitude == null || location?.longitude == null) {
        setState(() {
          _error = 'Location not available';
          _isLoading = false;
        });
        return;
      }

      // Test weather service to get station info
      final testResult = await WeatherStationService.testWeatherService();

      // Extract station info from the first successful service
      WeatherStationInfo? stationInfo;
      String? source;

      if (testResult['openweathermap_station'] != null) {
        // Parse station info from OpenWeatherMap
        final stationStr = testResult['openweathermap_station'] as String;
        if (stationStr != 'No station info') {
          stationInfo = _parseStationInfo(stationStr);
          source = 'OpenWeatherMap';
        }
      } else if (testResult['weatherapi_station'] != null) {
        // Parse station info from WeatherAPI
        final stationStr = testResult['weatherapi_station'] as String;
        if (stationStr != 'No station info') {
          stationInfo = _parseStationInfo(stationStr);
          source = 'WeatherAPI';
        }
      } else if (testResult['openmeteo_station'] != null) {
        // Parse station info from Open-Meteo
        final stationStr = testResult['openmeteo_station'] as String;
        if (stationStr != 'No station info') {
          stationInfo = _parseStationInfo(stationStr);
          source = 'Open-Meteo';
        }
      }

      setState(() {
        _currentStationInfo = stationInfo;
        _weatherSource = source;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load weather station info: $e';
        _isLoading = false;
      });
    }
  }

  WeatherStationInfo? _parseStationInfo(String stationStr) {
    // This is a simple parser for the station info string
    // In a real implementation, you might want to store the actual WeatherStationInfo object
    try {
      // Extract basic info from the string format
      final parts = stationStr.split(', ');
      String? name;
      String? city;
      String? country;
      double? distance;

      for (final part in parts) {
        if (part.startsWith('name: ')) {
          name = part.substring(6);
        } else if (part.startsWith('city: ')) {
          city = part.substring(6);
        } else if (part.startsWith('country: ')) {
          country = part.substring(9);
        } else if (part.startsWith('distance: ')) {
          final distanceStr = part.substring(10).replaceAll('km', '');
          distance = double.tryParse(distanceStr);
        }
      }

      return WeatherStationInfo(
        stationName: name,
        city: city,
        country: country,
        distanceFromUser: distance,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Weather Station Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _loadWeatherStationInfo,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh weather station info',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_currentStationInfo != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_weatherSource != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.cloud_queue,
                            color: Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Source: $_weatherSource',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_currentStationInfo!.stationName != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Station: ${_currentStationInfo!.stationName}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_currentStationInfo!.city != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.location_city,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'City: ${_currentStationInfo!.city}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_currentStationInfo!.country != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.flag,
                            color: Colors.purple,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Country: ${_currentStationInfo!.country}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (_currentStationInfo!.distanceFromUser != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.straighten,
                            color: Colors.teal,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentStationInfo!.distanceFromUser! == 0.0
                                  ? 'Distance: Data from your location area'
                                  : 'Distance: ${_currentStationInfo!.distanceFromUser!.toStringAsFixed(1)}km away',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (!_isLoading) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No weather station information available. Tap refresh to load.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
