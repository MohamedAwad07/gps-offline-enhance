import 'dart:async';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'package:learning/models/floor_detection_result.dart';

class WiFiFloorDetection {
  static const MethodChannel _channel = MethodChannel('wifi_floor_detection');

  // Store known WiFi networks and their floor locations
  static final Map<String, WiFiFloorData> _knownNetworks = {};

  // Initialize with some default networks for testing
  static void _initializeDefaultNetworks() {
    if (_knownNetworks.isEmpty) {
      // Add some common network patterns for testing
      addKnownNetwork('Building1_Floor0', 0, -30.0, 'Building1');
      addKnownNetwork('Building1_Floor1', 1, -35.0, 'Building1');
      addKnownNetwork('Building1_Floor2', 2, -40.0, 'Building1');
      addKnownNetwork('Office_WiFi_GF', 0, -25.0, 'Office');
      addKnownNetwork('Office_WiFi_1F', 1, -30.0, 'Office');
      addKnownNetwork('Office_WiFi_2F', 2, -35.0, 'Office');
    }
  }

  /// Add a known WiFi network with its floor information
  static void addKnownNetwork(
    String ssid,
    int floor,
    double signalStrength,
    String building,
  ) {
    _knownNetworks[ssid] = WiFiFloorData(
      ssid: ssid,
      floor: floor,
      signalStrength: signalStrength,
      building: building,
    );
  }

  /// Get current WiFi networks and their signal strengths
  static Future<List<WiFiNetwork>> getCurrentWiFiNetworks() async {
    try {
      dev.log('Calling getWiFiNetworks method channel...');
      final List<dynamic> networks = await _channel.invokeMethod(
        'getWiFiNetworks',
      );
      dev.log('Method channel returned ${networks.length} networks');
      return networks
          .map(
            (network) =>
                WiFiNetwork.fromMap(Map<String, dynamic>.from(network as Map)),
          )
          .toList();
    } catch (e) {
      dev.log('WiFi method channel error: $e');

      // If WiFi scanning fails, provide some mock networks for testing
      if (e.toString().contains('WIFI_SCAN_FAILED') ||
          e.toString().contains('WIFI_DISABLED')) {
        dev.log('Providing mock WiFi networks for testing...');
        return [
          WiFiNetwork(
            ssid: 'MockNetwork_Floor0',
            bssid: '00:11:22:33:44:55',
            signalStrength: -30.0,
            frequency: 2412,
            capabilities: '[WPA2-PSK-CCMP][ESS]',
          ),
          WiFiNetwork(
            ssid: 'MockNetwork_Floor1',
            bssid: '00:11:22:33:44:56',
            signalStrength: -35.0,
            frequency: 2437,
            capabilities: '[WPA2-PSK-CCMP][ESS]',
          ),
          WiFiNetwork(
            ssid: 'MockNetwork_Floor2',
            bssid: '00:11:22:33:44:57',
            signalStrength: -40.0,
            frequency: 2462,
            capabilities: '[WPA2-PSK-CCMP][ESS]',
          ),
        ];
      }

      return [];
    }
  }

  /// Detect floor based on WiFi signal strength patterns
  static Future<FloorDetectionResult> detectFloor() async {
    try {
      // Initialize default networks if none exist
      _initializeDefaultNetworks();

      dev.log('Getting WiFi networks...');
      final networks = await getCurrentWiFiNetworks();
      dev.log('Found ${networks.length} WiFi networks');
      if (networks.isEmpty) {
        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'wifi',
          error: 'No WiFi networks found - check WiFi is enabled',
        );
      }

      // Find known networks in current scan
      final knownNetworksFound = <WiFiFloorData>[];
      for (final network in networks) {
        if (_knownNetworks.containsKey(network.ssid)) {
          final knownData = _knownNetworks[network.ssid]!;
          knownNetworksFound.add(
            WiFiFloorData(
              ssid: network.ssid,
              floor: knownData.floor,
              signalStrength: network.signalStrength,
              building: knownData.building,
            ),
          );
        }
      }

      if (knownNetworksFound.isEmpty) {
        // If no known networks found, try to match partial names
        final partialMatches = <WiFiFloorData>[];
        for (final network in networks) {
          for (final knownEntry in _knownNetworks.entries) {
            if (network.ssid.toLowerCase().contains(
                  knownEntry.key.toLowerCase().split('_')[0],
                ) ||
                knownEntry.key.toLowerCase().contains(
                  network.ssid.toLowerCase().split('_')[0],
                )) {
              partialMatches.add(
                WiFiFloorData(
                  ssid: network.ssid,
                  floor: knownEntry.value.floor,
                  signalStrength: network.signalStrength,
                  building: knownEntry.value.building,
                ),
              );
              break; // Only add one match per network
            }
          }
        }

        if (partialMatches.isNotEmpty) {
          final floor = _calculateFloorFromWiFi(partialMatches);
          final confidence =
              _calculateConfidence(partialMatches) *
              0.7; // Lower confidence for partial matches

          return FloorDetectionResult(
            floor: floor,
            altitude: floor * 3.5,
            confidence: confidence,
            method: 'wifi',
            error: null,
          );
        }

        return FloorDetectionResult(
          floor: 0,
          altitude: 0,
          confidence: 0.0,
          method: 'wifi',
          error:
              'No known WiFi networks found. Available networks: ${networks.map((n) => n.ssid).join(', ')}',
        );
      }

      // Calculate floor based on signal strength patterns
      final floor = _calculateFloorFromWiFi(knownNetworksFound);
      final confidence = _calculateConfidence(knownNetworksFound);

      return FloorDetectionResult(
        floor: floor,
        altitude: floor * 3.5, // Assume 3.5m per floor
        confidence: confidence,
        method: 'wifi',
        error: null,
      );
    } catch (e) {
      return FloorDetectionResult(
        floor: 0,
        altitude: 0,
        confidence: 0.0,
        method: 'wifi',
        error: 'WiFi error: ${e.toString()}',
      );
    }
  }

  /// Calculate floor based on WiFi signal strength patterns
  static int _calculateFloorFromWiFi(List<WiFiFloorData> knownNetworks) {
    // Sort by signal strength (strongest first)
    knownNetworks.sort((a, b) => b.signalStrength.compareTo(a.signalStrength));

    // Weighted average based on signal strength
    double weightedSum = 0;
    double totalWeight = 0;

    for (final network in knownNetworks) {
      // Convert signal strength to weight (stronger signal = higher weight)
      final weight = _signalStrengthToWeight(network.signalStrength);
      weightedSum += network.floor * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return 0;

    return (weightedSum / totalWeight).round();
  }

  /// Convert signal strength to weight for calculation
  static num _signalStrengthToWeight(double signalStrength) {
    // Convert dBm to linear scale and apply exponential weighting
    // Stronger signals get exponentially higher weights
    final linearStrength = pow(10, signalStrength / 10);
    return linearStrength;
  }

  /// Calculate confidence based on signal strength consistency
  static double _calculateConfidence(List<WiFiFloorData> knownNetworks) {
    if (knownNetworks.length < 2) return 0.5;

    // Calculate variance in floor predictions
    final floors = knownNetworks.map((n) => n.floor.toDouble()).toList();
    final mean = floors.reduce((a, b) => a + b) / floors.length;
    final variance =
        floors.map((f) => pow(f - mean, 2)).reduce((a, b) => a + b) /
        floors.length;

    // Lower variance = higher confidence
    final confidence = max(0.0, 1.0 - (variance / 10.0));
    return min(1.0, confidence);
  }

  /// Learn floor patterns from user input
  static void learnFloorPattern(
    String ssid,
    int floor,
    double signalStrength,
    String building,
  ) {
    addKnownNetwork(ssid, floor, signalStrength, building);
  }

  /// Get all known networks
  static Map<String, WiFiFloorData> getKnownNetworks() =>
      Map.from(_knownNetworks);

  /// Clear learned data
  static void clearLearnedData() {
    _knownNetworks.clear();
  }
}

class WiFiNetwork {
  final String ssid;
  final String bssid;
  final double signalStrength; // in dBm
  final int frequency;
  final String capabilities;

  WiFiNetwork({
    required this.ssid,
    required this.bssid,
    required this.signalStrength,
    required this.frequency,
    required this.capabilities,
  });

  factory WiFiNetwork.fromMap(Map<String, dynamic> map) {
    return WiFiNetwork(
      ssid: map['ssid'] ?? '',
      bssid: map['bssid'] ?? '',
      signalStrength: (map['signalStrength'] ?? 0).toDouble(),
      frequency: map['frequency'] ?? 0,
      capabilities: map['capabilities'] ?? '',
    );
  }
}

class WiFiFloorData {
  final String ssid;
  final int floor;
  final double signalStrength;
  final String building;

  WiFiFloorData({
    required this.ssid,
    required this.floor,
    required this.signalStrength,
    required this.building,
  });
}
