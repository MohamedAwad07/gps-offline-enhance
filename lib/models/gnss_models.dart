/// GNSS (Global Navigation Satellite System) data models
/// These models represent satellite information and GNSS status data
library;

class SatelliteInfo {
  final int svid; // Satellite ID (Space Vehicle ID)
  final String constellation; // GPS, GLONASS, Galileo, BeiDou, QZSS, IRNSS
  final double snr; // Signal-to-Noise Ratio (dB-Hz)
  final bool
  usedInFix; // Whether this satellite is used in position calculation
  final double elevation; // Elevation angle in degrees (0-90)
  final double azimuth; // Azimuth angle in degrees (0-360)
  final bool hasAlmanac; // Whether almanac data is available
  final bool hasEphemeris; // Whether ephemeris data is available
  final double carrierFrequency; // Carrier frequency in Hz

  const SatelliteInfo({
    required this.svid,
    required this.constellation,
    required this.snr,
    required this.usedInFix,
    required this.elevation,
    required this.azimuth,
    required this.hasAlmanac,
    required this.hasEphemeris,
    required this.carrierFrequency,
  });

  /// Get signal quality category based on SNR
  SignalQuality get signalQuality {
    if (snr >= 30) return SignalQuality.excellent;
    if (snr >= 20) return SignalQuality.good;
    if (snr >= 10) return SignalQuality.fair;
    return SignalQuality.poor;
  }

  /// Get constellation color for UI display
  String get constellationColor {
    switch (constellation.toUpperCase()) {
      case 'GPS':
        return '#4CAF50'; // Green
      case 'GLONASS':
        return '#2196F3'; // Blue
      case 'GALILEO':
        return '#FF9800'; // Orange
      case 'BEIDOU':
        return '#9C27B0'; // Purple
      case 'QZSS':
        return '#F44336'; // Red
      case 'IRNSS':
        return '#607D8B'; // Blue Grey
      default:
        return '#9E9E9E'; // Grey
    }
  }

  @override
  String toString() {
    return 'SatelliteInfo(svid: $svid, constellation: $constellation, snr: ${snr.toStringAsFixed(1)}, usedInFix: $usedInFix)';
  }

  Map<String, dynamic> toJson() {
    return {
      'svid': svid,
      'constellation': constellation,
      'snr': snr,
      'usedInFix': usedInFix,
      'elevation': elevation,
      'azimuth': azimuth,
      'hasAlmanac': hasAlmanac,
      'hasEphemeris': hasEphemeris,
      'carrierFrequency': carrierFrequency,
    };
  }

  factory SatelliteInfo.fromJson(Map<String, dynamic> json) {
    return SatelliteInfo(
      svid: json['svid'] as int,
      constellation: json['constellation'] as String,
      snr: (json['snr'] as num).toDouble(),
      usedInFix: json['usedInFix'] as bool,
      elevation: (json['elevation'] as num).toDouble(),
      azimuth: (json['azimuth'] as num).toDouble(),
      hasAlmanac: json['hasAlmanac'] as bool,
      hasEphemeris: json['hasEphemeris'] as bool,
      carrierFrequency: (json['carrierFrequency'] as num).toDouble(),
    );
  }
}

enum SignalQuality {
  excellent, // SNR >= 30 dB-Hz
  good, // SNR 20-29 dB-Hz
  fair, // SNR 10-19 dB-Hz
  poor, // SNR < 10 dB-Hz
}

class GnssStatus {
  final List<SatelliteInfo> satellites;
  final int satellitesInView;
  final int satellitesInUse;
  final double averageSnr;
  final GnssFixType fixType;
  final double accuracy; // Horizontal accuracy in meters
  final double altitudeAccuracy; // Vertical accuracy in meters
  final double speed; // Speed in m/s
  final double bearing; // Bearing in degrees
  final DateTime timestamp;
  final bool isMocked; // Whether location is mocked
  final double latitude;
  final double longitude;
  final double altitude;

  const GnssStatus({
    required this.satellites,
    required this.satellitesInView,
    required this.satellitesInUse,
    required this.averageSnr,
    required this.fixType,
    required this.accuracy,
    required this.altitudeAccuracy,
    required this.speed,
    required this.bearing,
    required this.timestamp,
    required this.isMocked,
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  /// Get satellites grouped by constellation
  Map<String, List<SatelliteInfo>> get satellitesByConstellation {
    final Map<String, List<SatelliteInfo>> grouped = {};
    for (final satellite in satellites) {
      grouped.putIfAbsent(satellite.constellation, () => []).add(satellite);
    }
    return grouped;
  }

  /// Get satellites used in fix
  List<SatelliteInfo> get satellitesUsedInFix {
    return satellites.where((s) => s.usedInFix).toList();
  }

  /// Get satellites with good signal quality
  List<SatelliteInfo> get satellitesWithGoodSignal {
    return satellites
        .where((s) => s.signalQuality.index >= SignalQuality.good.index)
        .toList();
  }

  /// Check if GNSS status indicates good positioning
  bool get hasGoodFix {
    return fixType == GnssFixType.fix3D &&
        satellitesInUse >= 4 &&
        averageSnr >= 20.0 &&
        accuracy <= 10.0;
  }

  /// Get constellation count
  Map<String, int> get constellationCount {
    final Map<String, int> counts = {};
    for (final satellite in satellites) {
      counts[satellite.constellation] =
          (counts[satellite.constellation] ?? 0) + 1;
    }
    return counts;
  }

  @override
  String toString() {
    return 'GnssStatus(fixType: $fixType, satellitesInUse: $satellitesInUse/$satellitesInView, accuracy: ${accuracy.toStringAsFixed(1)}m, avgSnr: ${averageSnr.toStringAsFixed(1)})';
  }

  Map<String, dynamic> toJson() {
    return {
      'satellites': satellites.map((s) => s.toJson()).toList(),
      'satellitesInView': satellitesInView,
      'satellitesInUse': satellitesInUse,
      'averageSnr': averageSnr,
      'fixType': fixType.name,
      'accuracy': accuracy,
      'altitudeAccuracy': altitudeAccuracy,
      'speed': speed,
      'bearing': bearing,
      'timestamp': timestamp.toIso8601String(),
      'isMocked': isMocked,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
    };
  }

  factory GnssStatus.fromJson(Map<String, dynamic> json) {
    // Handle timestamp - it can be either a string or a number (milliseconds)
    DateTime timestamp;
    final timestampValue = json['timestamp'];
    if (timestampValue is String) {
      timestamp = DateTime.parse(timestampValue);
    } else if (timestampValue is num) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue.toInt());
    } else {
      timestamp = DateTime.now();
    }

    // Handle fixType - it can be a string or we need to parse it
    GnssFixType fixType;
    final fixTypeValue = json['fixType'];
    if (fixTypeValue is String) {
      // Handle different fix type formats from Android
      switch (fixTypeValue.toLowerCase()) {
        case '3d fix':
        case '3d':
          fixType = GnssFixType.fix3D;
          break;
        case '2d fix':
        case '2d':
          fixType = GnssFixType.fix2D;
          break;
        case 'no fix':
        case 'nofix':
        default:
          fixType = GnssFixType.noFix;
          break;
      }
    } else {
      fixType = GnssFixType.noFix;
    }

    return GnssStatus(
      satellites: (json['satellites'] as List).map((s) {
        if (s is Map) {
          // Convert satellite data safely
          final Map<String, dynamic> satelliteMap = <String, dynamic>{};
          s.forEach((key, value) {
            if (key is String) {
              satelliteMap[key] = value;
            } else {
              satelliteMap[key.toString()] = value;
            }
          });
          return SatelliteInfo.fromJson(satelliteMap);
        } else {
          throw Exception('Invalid satellite data type: ${s.runtimeType}');
        }
      }).toList(),
      satellitesInView: json['satellitesInView'] as int,
      satellitesInUse: json['satellitesInUse'] as int,
      averageSnr: (json['averageSnr'] as num).toDouble(),
      fixType: fixType,
      accuracy: (json['accuracy'] as num).toDouble(),
      altitudeAccuracy: (json['altitudeAccuracy'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      bearing: (json['bearing'] as num).toDouble(),
      timestamp: timestamp,
      isMocked: json['isMocked'] as bool,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num).toDouble(),
    );
  }
}

enum GnssFixType {
  noFix, // No position fix
  fix2D, // 2D position fix (lat/lon only)
  fix3D, // 3D position fix (lat/lon/altitude)
  gnssDeadReckoning, // GNSS dead reckoning
}

/// GNSS measurement data for advanced positioning algorithms
class GnssMeasurement {
  final int svid;
  final String constellation;
  final double pseudorange; // Pseudorange in meters
  final double pseudorangeRate; // Pseudorange rate in m/s
  final double carrierPhase; // Carrier phase in cycles
  final double carrierFrequency; // Carrier frequency in Hz
  final double snr; // Signal-to-noise ratio in dB-Hz
  final double elevation; // Elevation angle in degrees
  final double azimuth; // Azimuth angle in degrees
  final bool hasAlmanac;
  final bool hasEphemeris;
  final DateTime timestamp;

  const GnssMeasurement({
    required this.svid,
    required this.constellation,
    required this.pseudorange,
    required this.pseudorangeRate,
    required this.carrierPhase,
    required this.carrierFrequency,
    required this.snr,
    required this.elevation,
    required this.azimuth,
    required this.hasAlmanac,
    required this.hasEphemeris,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'svid': svid,
      'constellation': constellation,
      'pseudorange': pseudorange,
      'pseudorangeRate': pseudorangeRate,
      'carrierPhase': carrierPhase,
      'carrierFrequency': carrierFrequency,
      'snr': snr,
      'elevation': elevation,
      'azimuth': azimuth,
      'hasAlmanac': hasAlmanac,
      'hasEphemeris': hasEphemeris,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GnssMeasurement.fromJson(Map<String, dynamic> json) {
    // Handle timestamp - it can be either a string or a number (milliseconds)
    DateTime timestamp;
    final timestampValue = json['timestamp'];
    if (timestampValue is String) {
      timestamp = DateTime.parse(timestampValue);
    } else if (timestampValue is num) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue.toInt());
    } else {
      timestamp = DateTime.now();
    }

    return GnssMeasurement(
      svid: json['svid'] as int,
      constellation: json['constellation'] as String,
      pseudorange: (json['pseudorange'] as num).toDouble(),
      pseudorangeRate: (json['pseudorangeRate'] as num).toDouble(),
      carrierPhase: (json['carrierPhase'] as num).toDouble(),
      carrierFrequency: (json['carrierFrequency'] as num).toDouble(),
      snr: (json['snr'] as num).toDouble(),
      elevation: (json['elevation'] as num).toDouble(),
      azimuth: (json['azimuth'] as num).toDouble(),
      hasAlmanac: json['hasAlmanac'] as bool,
      hasEphemeris: json['hasEphemeris'] as bool,
      timestamp: timestamp,
    );
  }
}

/// GNSS capabilities and hardware information
class GnssCapabilities {
  final bool hasGnss;
  final bool hasGps;
  final bool hasGlonass;
  final bool hasGalileo;
  final bool hasBeiDou;
  final bool hasQzss;
  final bool hasIrnss;
  final bool hasGnssMeasurements;
  final bool hasGnssNavigationMessage;
  final int maxSatellites;
  final String hardwareModel;
  final String softwareVersion;

  const GnssCapabilities({
    required this.hasGnss,
    required this.hasGps,
    required this.hasGlonass,
    required this.hasGalileo,
    required this.hasBeiDou,
    required this.hasQzss,
    required this.hasIrnss,
    required this.hasGnssMeasurements,
    required this.hasGnssNavigationMessage,
    required this.maxSatellites,
    required this.hardwareModel,
    required this.softwareVersion,
  });

  /// Get list of supported constellations
  List<String> get supportedConstellations {
    final List<String> constellations = [];
    if (hasGps) constellations.add('GPS');
    if (hasGlonass) constellations.add('GLONASS');
    if (hasGalileo) constellations.add('Galileo');
    if (hasBeiDou) constellations.add('BeiDou');
    if (hasQzss) constellations.add('QZSS');
    if (hasIrnss) constellations.add('IRNSS');
    return constellations;
  }

  Map<String, dynamic> toJson() {
    return {
      'hasGnss': hasGnss,
      'hasGps': hasGps,
      'hasGlonass': hasGlonass,
      'hasGalileo': hasGalileo,
      'hasBeiDou': hasBeiDou,
      'hasQzss': hasQzss,
      'hasIrnss': hasIrnss,
      'hasGnssMeasurements': hasGnssMeasurements,
      'hasGnssNavigationMessage': hasGnssNavigationMessage,
      'maxSatellites': maxSatellites,
      'hardwareModel': hardwareModel,
      'softwareVersion': softwareVersion,
    };
  }

  factory GnssCapabilities.fromJson(Map<String, dynamic> json) {
    return GnssCapabilities(
      hasGnss: json['hasGnss'] as bool,
      hasGps: json['hasGps'] as bool,
      hasGlonass: json['hasGlonass'] as bool,
      hasGalileo: json['hasGalileo'] as bool,
      hasBeiDou: json['hasBeiDou'] as bool,
      hasQzss: json['hasQzss'] as bool,
      hasIrnss: json['hasIrnss'] as bool,
      hasGnssMeasurements: json['hasGnssMeasurements'] as bool,
      hasGnssNavigationMessage: json['hasGnssNavigationMessage'] as bool,
      maxSatellites: json['maxSatellites'] as int,
      hardwareModel: json['hardwareModel'] as String,
      softwareVersion: json['softwareVersion'] as String,
    );
  }
}
