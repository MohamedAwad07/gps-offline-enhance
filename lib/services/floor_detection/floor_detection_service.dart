import 'package:learning/models/floor_detection_result.dart';
import 'package:learning/services/floor_detection/floor_detection_core.dart';
import 'package:learning/services/floor_detection/floor_detection_status.dart';

/// Main service that combines all floor detection methods
class FloorDetectionService {
  /// Start comprehensive floor detection
  static Future<void> startFloorDetection({
    Duration interval = const Duration(seconds: 2),
  }) async {
    return FloorDetectionCore.startFloorDetection(interval: interval);
  }

  /// Stop floor detection
  static void stopFloorDetection() {
    FloorDetectionCore.stopFloorDetection();
  }

  /// Get stream of floor detection results
  static Stream<FloorDetectionResult> get detectionStream =>
      FloorDetectionCore.detectionStream;

  /// Perform single detection using all available methods
  static Future<FloorDetectionResult> detectFloor() async {
    return FloorDetectionCore.detectFloor();
  }

  /// Get current floor with fallback options
  static Future<FloorDetectionResult> getCurrentFloor() async {
    return FloorDetectionCore.getCurrentFloor();
  }

  /// Get detection method status
  static Future<Map<String, bool>> getMethodStatus() async {
    return FloorDetectionStatus.getMethodStatus();
  }

  /// Get detailed status information for debugging
  static Future<Map<String, dynamic>> getDetailedStatus() async {
    return FloorDetectionStatus.getDetailedStatus();
  }

  /// Dispose resources
  static void dispose() {
    FloorDetectionCore.dispose();
  }
}
