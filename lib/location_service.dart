// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:logging/logging.dart';

class LocationService {
  factory LocationService.instance() => _instance;
  LocationService._();
  static final LocationService _instance = LocationService._();

  final Location _location = Location();

  Future<bool> requestLocationService() async {
    var serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
    }
    return serviceEnabled;
  }

  Future<bool> isLoctionSerivceEnabled() async {
    try {
      return Geolocator.isLocationServiceEnabled();
    } catch (e) {
      Logger.root.warning('Error checking location service', e);
      return false;
    }
  }

  Future<LocationAccuracyStatus> getLocationAccuracy() {
    return Geolocator.getLocationAccuracy();
  }

  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  Future<Position> getCurrentPosition() async {
    try {
      return await getCurrentPositionWithFallback();
    } on TimeoutException catch (e) {
      log('Timeout getting current position: $e');
      throw Exception('Location timeout');
    } catch (e) {
      log('Error getting current position: $e');
      rethrow;
    }
  }

  Future<Position> getCurrentPositionWithFallback({
    Duration timeout = const Duration(seconds: 300), // 5 min for cold start
    bool allowLastKnown = true,
    Duration maxLastKnownAge = const Duration(
      minutes: 15,
    ), // Only use last known if within 15 minutes
  }) async {
    Position? lastKnownPosition;

    // Try to get last known position as backup (only if recent)
    if (allowLastKnown) {
      lastKnownPosition = await getLastKnownPosition();
      if (lastKnownPosition != null &&
          !isLocationRecent(lastKnownPosition, maxAge: maxLastKnownAge)) {
        log(
          'Last known position is too old (${lastKnownPosition.timestamp}), will not use as fallback',
        );
        lastKnownPosition = null;
      }
    }

    // Try GPS with multiple accuracy levels
    for (final accuracy in [
      LocationAccuracy.bestForNavigation,
      LocationAccuracy.high,
      LocationAccuracy.medium,
      LocationAccuracy.low,
    ]) {
      try {
        return await _getCurrentPositionWithAccuracy(accuracy, timeout);
      } on TimeoutException {
        continue; // Try next accuracy level
      }
    }

    // All attempts failed, use last known if available and recent
    if (lastKnownPosition != null) {
      log(
        'Using recent last known position from ${lastKnownPosition.timestamp}',
      );
      return lastKnownPosition;
    }

    throw Exception('Location timeout');
  }

  Future<Position> _getCurrentPositionWithAccuracy(
    LocationAccuracy accuracy,
    Duration timeout,
  ) async {
    /* forceLocationManager: true forces the plugin to use the old Android LocationManager API, instead of the newer FusedLocationProviderClient (FLP) from Google Play Services.
    if it true:
        - It bypasses Google’s Fused provider (which expects Play Services and AGPS data).
        - It talks directly to the GNSS chip, ensuring a pure satellite fix.
        - It continues to work on devices without Google Play Services (Huawei, custom ROMs, etc.).
        - It eliminates the “waiting for network-assisted fix” delay.

      trade off:
        - Slightly slower cold start (especially after reboot, ~30s–2 min).
        - Higher battery drain if you keep it running continuously.
        - You lose Wi-Fi/cell-based fallback, so indoor accuracy may drop.

    if it false:
        - It uses Google’s Fused provider (which expects Play Services and AGPS data).
        - It doesn’t talk directly to the GNSS chip, ensuring a pure satellite fix.
        - It doesn’t continue to work on devices without Google Play Services (Huawei, custom ROMs, etc.).
        - It has the “waiting for network-assisted fix” delay.

      trade off:
        - Slightly faster cold start (especially after reboot, ~30s–2 min).
        - Lower battery drain if you keep it running continuously.
        - You get Wi-Fi/cell-based fallback, so indoor accuracy is better.
    */

    /* 
    Its recommended to use forceLocationManager: false when internet connection is available.
    And forceLocationManager: true when internet connection is not available.

    We can according to internet connection and determine if we will use forceLocationManager: true or false.
    */

    final locationSettings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: accuracy,
            distanceFilter: 0,
            forceLocationManager:
                false, // Use Google Play Services when available
            intervalDuration: const Duration(seconds: 10),
            timeLimit: timeout,
          )
        : AppleSettings(
            accuracy: accuracy,
            activityType: ActivityType.other,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            timeLimit: timeout,
          );

    return Geolocator.getCurrentPosition(locationSettings: locationSettings);
  }

  bool isLocationRecent(
    Position position, {
    Duration maxAge = const Duration(minutes: 15),
  }) {
    final now = DateTime.now();
    final locationTime = position.timestamp;
    final age = now.difference(locationTime);
    log(
      'Location age: ${age.inMinutes} minutes (max allowed: ${maxAge.inMinutes} minutes)',
    );
    return age <= maxAge;
  }

  Future<Position?> getLastKnownPosition() async {
    return Geolocator.getLastKnownPosition();
  }
}
