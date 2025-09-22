/// Configuration for weather services
class WeatherConfig {
  // OpenWeatherMap API Configuration
  // Get your free API key from: https://openweathermap.org/api
  static const String openWeatherMapApiKey = '8cfeb45e82748a3030ebb3c98eacc5bf';

  // WeatherAPI Configuration
  // Get your free API key from: https://www.weatherapi.com/
  static const String weatherApiKey = '14dc55347e004532979155339252109';

  // Alternative free weather services (no API key required)
  static const bool useOpenMeteo = true; // Free service, no API key needed
  static const bool useWttrIn = true; // Free service, no API key needed

  /// Check if any weather service is configured
  static bool get isConfigured {
    return openWeatherMapApiKey != 'YOUR_OPENWEATHERMAP_API_KEY_HERE' ||
        weatherApiKey != 'YOUR_WEATHERAPI_KEY_HERE' ||
        useOpenMeteo ||
        useWttrIn;
  }

  /// Get list of available services
  static List<String> get availableServices {
    final services = <String>[];

    if (openWeatherMapApiKey != 'YOUR_OPENWEATHERMAP_API_KEY_HERE') {
      services.add('OpenWeatherMap');
    }

    if (weatherApiKey != 'YOUR_WEATHERAPI_KEY_HERE') {
      services.add('WeatherAPI');
    }

    if (useOpenMeteo) {
      services.add('Open-Meteo (Free)');
    }

    if (useWttrIn) {
      services.add('wttr.in (Free)');
    }

    return services;
  }

  /// Get configuration instructions
  static String get configurationInstructions => '''
Weather Service Configuration Instructions:

1. OpenWeatherMap (Recommended):
   - Visit: https://openweathermap.org/api
   - Sign up for a free account
   - Get your API key
   - Replace 'YOUR_OPENWEATHERMAP_API_KEY_HERE' in weather_config.dart

2. WeatherAPI (Alternative):
   - Visit: https://www.weatherapi.com/
   - Sign up for a free account  
   - Get your API key
   - Replace 'YOUR_WEATHERAPI_KEY_HERE' in weather_config.dart

3. Free Services (No API key needed):
   - Open-Meteo: Already enabled
   - wttr.in: Already enabled

Note: Free services have rate limits but work without API keys.
For production use, consider getting API keys for better reliability.
''';
}
