import 'dart:developer' as dev;

import 'package:learning/screens/home_screen/home_screen.dart';

/// Simple logger that captures logs for the live log viewer
class AppLogger {
  static void log(String level, String message, {String source = 'App'}) {
    // Log to console
    dev.log('[$level] $source: $message');

    // Add to live log viewer
    LogInterceptor.log(level, message, source: source);
  }

  static void info(String message, {String source = 'App'}) {
    log('INFO', message, source: source);
  }

  static void error(String message, {String source = 'App'}) {
    log('ERROR', message, source: source);
  }

  static void warning(String message, {String source = 'App'}) {
    log('WARNING', message, source: source);
  }

  static void debug(String message, {String source = 'App'}) {
    log('DEBUG', message, source: source);
  }
}
