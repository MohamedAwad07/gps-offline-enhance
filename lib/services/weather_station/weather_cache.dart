import 'package:learning/services/weather_station/weather_data_model.dart';

/// Weather data caching functionality
class WeatherCache {
  // Cache for weather data to avoid excessive API calls
  static final Map<String, WeatherData> _weatherCache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheValidity = Duration(seconds: 5);

  /// Check if cached data is still valid
  static bool isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidity;
  }

  /// Update weather data cache
  static void updateCache(String key, WeatherData data) {
    _weatherCache[key] = data;
    _lastCacheUpdate = DateTime.now();

    // Limit cache size
    if (_weatherCache.length > 10) {
      final oldestKey = _weatherCache.keys.first;
      _weatherCache.remove(oldestKey);
    }
  }

  /// Get cached weather data
  static WeatherData? getCachedData(String key) {
    if (isCacheValid() && _weatherCache.containsKey(key)) {
      return _weatherCache[key];
    }
    return null;
  }

  /// Clear weather data cache
  static void clearCache() {
    _weatherCache.clear();
    _lastCacheUpdate = null;
  }

  /// Get cached weather data for debugging
  static Map<String, WeatherData> getCachedDataMap() => Map.from(_weatherCache);

  /// Get cache status information
  static Map<String, dynamic> getCacheStatus() {
    return {
      'cached_locations': _weatherCache.length,
      'last_update': _lastCacheUpdate?.toIso8601String(),
      'cache_valid': isCacheValid(),
    };
  }
}
