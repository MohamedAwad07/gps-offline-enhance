<!-- 470f1beb-0505-423a-9b68-b2778883cc12 faae5361-52de-469d-9804-52cee1dc6c1f -->
# Improve GPS Offline Location Acquisition

## Problem Summary

GPS location acquisition fails or takes 10+ minutes in offline mode due to GPS cold start issues. Google Maps works immediately because it uses cached AGPS data and fallback strategies. Current implementation uses 60-second timeout which is insufficient for GPS cold start (requires 5-15 minutes).

## Root Causes

1. **GPS Cold Start**: Without mobile data, GPS needs 5-15 minutes to download satellite almanac/ephemeris data
2. **No Last Known Position Fallback**: App doesn't use cached location when fresh GPS fails
3. **Insufficient Timeout**: 60 seconds is too short for cold start scenarios
4. **Android-Only Settings**: No iOS optimization
5. **No Progressive Acquisition**: App waits for perfect fix instead of progressive improvement

## Solution Strategy

Implement progressive GPS acquisition with multiple fallback layers:

1. Try last known position first (instant)
2. Attempt fresh GPS with extended timeout (up to 5 minutes)
3. Fall back to last known if fresh GPS fails
4. Add platform-specific optimizations (Android + iOS)

## Implementation Plan

### 1. Enhanced Location Service (`location_service.dart`)

#### Add Progressive GPS Acquisition Method

Create `getCurrentPositionWithFallback()` method that:

- First attempts to get last known position (may be null or very old)
- Tries fresh GPS with extended timeout (300 seconds for cold start)
- Uses multiple accuracy levels progressively (best → high → medium)
- Returns last known position if fresh GPS fails after timeout
- Includes both Android and iOS specific settings
```dart
Future<Position> getCurrentPositionWithFallback({
  Duration timeout = const Duration(seconds: 300), // 5 min for cold start
  bool allowLastKnown = true,
}) async {
  Position? lastKnownPosition;
  
  // Try to get last known position as backup
  if (allowLastKnown) {
    lastKnownPosition = await getLastKnownPosition();
  }
  
  // Try progressive GPS acquisition with multiple accuracy levels
  for (final accuracy in [LocationAccuracy.best, LocationAccuracy.high, LocationAccuracy.medium]) {
    try {
      return await _getCurrentPositionWithAccuracy(accuracy, timeout);
    } on TimeoutException {
      continue; // Try next accuracy level
    }
  }
  
  // All attempts failed, use last known if available
  if (lastKnownPosition != null) {
    return lastKnownPosition;
  }
  
  throw const LogicException(type: LogicExceptionType.locationTimeout);
}
```


#### Add Platform-Specific Settings Helper

```dart
Future<Position> _getCurrentPositionWithAccuracy(
  LocationAccuracy accuracy,
  Duration timeout,
) async {
  final locationSettings = defaultTargetPlatform == TargetPlatform.android
      ? AndroidSettings(
          accuracy: accuracy,
          distanceFilter: 0,
          forceLocationManager: false, // Use Google Play Services when available
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
  
  return await Geolocator.getCurrentPosition(locationSettings: locationSettings);
}
```

#### Update Existing `getCurrentPosition()` 

Keep existing method for backward compatibility but use the new fallback method internally:

```dart
Future<Position> getCurrentPosition() async {
  try {
    return await getCurrentPositionWithFallback();
  } on TimeoutException catch (e) {
    log('Timeout getting current position: $e');
    throw const LogicException(type: LogicExceptionType.locationTimeout);
  } catch (e) {
    log('Error getting current position: $e');
    rethrow;
  }
}
```

#### Add Location Age Validation Helper

```dart
bool isLocationRecent(Position position, {Duration maxAge = const Duration(hours: 1)}) {
  final now = DateTime.now();
  final locationTime = position.timestamp ?? now;
  return now.difference(locationTime) <= maxAge;
}
```

### 2. Update Attendance Provider (`attend_provider.dart`)

Update line 58 to handle potential stale location:

```dart
final location = await LocationService.instance().getCurrentPosition();

// Validate location freshness
if (!LocationService.instance().isLocationRecent(location)) {
  log('Warning: Using potentially stale location from ${location.timestamp}');
}
```

### 3. Update Checkout Provider (`checkout_provider.dart`)

Similarly update line 41:

```dart
final location = await LocationService.instance().getCurrentPosition();

if (!LocationService.instance().isLocationRecent(location)) {
  log('Warning: Using potentially stale location from ${location.timestamp}');
}
```

### 4. Update Tracking Service (`tracking_service.dart`)

Update line 123 to use the enhanced method:

```dart
LocationService.instance().getCurrentPosition().then(
  (value) {
    // Log if location is stale
    if (!LocationService.instance().isLocationRecent(value)) {
      log('Tracking: Using stale location from ${value.timestamp}');
    }
    return Coordinates(
      longitude: value.longitude,
      latitude: value.latitude,
      height: value.altitude,
      mocked: value.isMocked,
    );
  },
)
```

### 5. Add Platform Import

Add to `location_service.dart`:

```dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
```

## Key Files to Modify

- `dwamee/lib/core/services/location/location_service.dart` - Main location service enhancements
- `dwamee/lib/features/attendance/presentation/calendar_screen/providers/attend_provider.dart` - Update attendance flow
- `dwamee/lib/features/attendance/presentation/shift_screen/providers/checkout_provider.dart` - Update checkout flow  
- `dwamee/lib/features/tracking/data/tracking_service.dart` - Update tracking flow

## Benefits

1. **Instant Response**: Returns last known position immediately when available
2. **Progressive Fallback**: Multiple accuracy levels ensure best chance of GPS fix
3. **Extended Timeout**: 5 minutes allows GPS cold start to complete
4. **Cross-Platform**: Works on both Android and iOS
5. **Graceful Degradation**: Uses stale location rather than failing completely
6. **Google Play Services**: Uses optimized location APIs when available (Android)

## Testing Recommendations

- Test in airplane mode to simulate pure GPS cold start
- Test after device reboot (clears GPS cache)
- Test in areas with weak GPS signal
- Verify behavior with mobile data off but WiFi on
- Monitor location freshness in logs

### To-dos

- [ ] Add getCurrentPositionWithFallback() method with progressive GPS acquisition and fallback logic
- [ ] Add _getCurrentPositionWithAccuracy() helper with Android and iOS specific location settings
- [ ] Add isLocationRecent() method to validate location timestamp freshness
- [ ] Update existing getCurrentPosition() to use new fallback method
- [ ] Add Flutter foundation import for platform detection
- [ ] Update attend_provider.dart to log stale location warnings
- [ ] Update checkout_provider.dart to log stale location warnings
- [ ] Update tracking_service.dart to log stale location warnings