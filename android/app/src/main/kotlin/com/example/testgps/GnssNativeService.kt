package com.example.testgps

import android.Manifest
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.GnssMeasurementsEvent
import android.location.GnssStatus
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Binder
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native GNSS Service for direct access to GNSS hardware
 * Provides real-time satellite data, measurements, and positioning
 */
class GnssNativeService : Service() {
    
    companion object {
        private const val TAG = "GnssNativeService"
        private const val CHANNEL_NAME = "com.example.testgps/gnss_native"
        private const val EVENT_CHANNEL_NAME = "com.example.testgps/gnss_events"
        private const val MIN_UPDATE_INTERVAL_MS = 1000L // 1 second
        private const val MIN_UPDATE_DISTANCE_M = 0f
    }

    private val binder = GnssBinder()
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    
    private lateinit var locationManager: LocationManager
    private val isTracking = AtomicBoolean(false)
    private val satelliteData = ConcurrentHashMap<Int, SatelliteInfo>()
    private val measurementData = ConcurrentHashMap<Int, GnssMeasurement>()
    
    // Current GNSS status
    private var currentGnssStatus: GnssStatus? = null
    private var currentLocation: Location? = null
    private var gnssCapabilities: GnssCapabilities? = null
    
    // GNSS Status Callback
    private val gnssStatusCallback = object : GnssStatus.Callback() {
        override fun onStarted() {
            Log.d(TAG, "GNSS status callback started")
        }

        override fun onStopped() {
            Log.d(TAG, "GNSS status callback stopped")
        }

        override fun onFirstFix(ttffMillis: Int) {
            Log.d(TAG, "First GNSS fix obtained in ${ttffMillis}ms")
            sendEvent("firstFix", mapOf("ttffMillis" to ttffMillis))
        }

        override fun onSatelliteStatusChanged(status: GnssStatus) {
            Log.d(TAG, "onSatelliteStatusChanged called with ${status.satelliteCount} satellites")
            currentGnssStatus = status
            satelliteData.clear()
            
            for (i in 0 until status.satelliteCount) {
                val svid = status.getSvid(i)
                val constellation = getConstellationName(status.getConstellationType(i))
                val snr = status.getCn0DbHz(i)
                val usedInFix = status.usedInFix(i)
                val elevation = status.getElevationDegrees(i)
                val azimuth = status.getAzimuthDegrees(i)
                
                val satelliteInfo = SatelliteInfo(
                    svid = svid,
                    constellation = constellation,
                    snr = snr.toDouble(),
                    usedInFix = usedInFix,
                    elevation = elevation.toDouble(),
                    azimuth = azimuth.toDouble(),
                    hasAlmanac = status.hasAlmanacData(i),
                    hasEphemeris = status.hasEphemerisData(i),
                    carrierFrequency = getCarrierFrequency(constellation, svid)
                )
                
                satelliteData[svid] = satelliteInfo
            }
            
            Log.d(TAG, "Sending satellite status with ${satelliteData.size} satellites")
            // Send satellite data to Flutter
            sendEvent("satelliteStatus", getCurrentGnssStatusJson())
        }
    }
    
    // Location Listener Callback
    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            currentLocation = location
            Log.d(TAG, "Location updated: lat=${location.latitude}, lon=${location.longitude}, accuracy=${location.accuracy}m")
            sendEvent("locationUpdate", locationToJson(location))
        }

        override fun onProviderEnabled(provider: String) {
            Log.d(TAG, "Location provider enabled: $provider")
        }

        override fun onProviderDisabled(provider: String) {
            Log.d(TAG, "Location provider disabled: $provider")
        }

        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
            Log.d(TAG, "Location provider status changed: $provider, status: $status")
        }
    }
    
    // GNSS Measurements Callback
    private val gnssMeasurementsCallback = object : GnssMeasurementsEvent.Callback() {
        override fun onGnssMeasurementsReceived(event: GnssMeasurementsEvent) {
            val measurements = event.measurements
            Log.d(TAG, "Received ${measurements.size} GNSS measurements")
            
            for (measurement in measurements) {
                val svid = measurement.svid
                val constellation = getConstellationName(measurement.constellationType)
                
                val gnssMeasurement = GnssMeasurement(
                    svid = svid,
                    constellation = constellation,
                    pseudorange = measurement.pseudorangeRateMetersPerSecond.toDouble(),
                    pseudorangeRate = measurement.pseudorangeRateMetersPerSecond.toDouble(),
                    carrierPhase = measurement.accumulatedDeltaRangeMeters.toDouble(),
                    carrierFrequency = measurement.carrierFrequencyHz.toDouble(),
                    snr = measurement.cn0DbHz.toDouble(),
                    elevation = 0.0, // Not available in GnssMeasurement
                    azimuth = 0.0, // Not available in GnssMeasurement
                    hasAlmanac = (measurement.state and 0x1) != 0, // STATE_HAS_ALMANAC_DATA
                    hasEphemeris = (measurement.state and 0x2) != 0, // STATE_HAS_EPHEMERIS_DATA
                    timestamp = java.util.Date(measurement.receivedSvTimeNanos / 1000000)
                )
                
                measurementData[svid] = gnssMeasurement
            }
            
            // Send measurement data to Flutter
            sendEvent("gnssMeasurements", getMeasurementDataJson())
            
            // Also create and send satellite status from measurements
            _sendSatelliteStatusFromMeasurements()
        }

        override fun onStatusChanged(type: Int) {
            Log.d(TAG, "GNSS measurements status changed: $type")
        }
    }

    inner class GnssBinder : Binder() {
        fun getService(): GnssNativeService = this@GnssNativeService
    }

    override fun onBind(intent: Intent): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "GnssNativeService created")
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        Log.d(TAG, "About to initialize GNSS capabilities...")
        initializeGnssCapabilities()
        Log.d(TAG, "GNSS capabilities initialization completed")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopGnssTracking()
        Log.d(TAG, "GnssNativeService destroyed")
    }

    /**
     * Initialize method channel for Flutter communication
     */
    fun initializeChannels(methodChannel: MethodChannel, eventChannel: EventChannel) {
        this.methodChannel = methodChannel
        this.eventChannel = eventChannel
        
        // Set up method channel handlers
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startGnssTracking" -> {
                    startGnssTracking()
                    result.success(true)
                }
                "stopGnssTracking" -> {
                    stopGnssTracking()
                    result.success(true)
                }
                "getGnssCapabilities" -> {
                    Log.d(TAG, "Returning GNSS capabilities: $gnssCapabilities")
                    result.success(gnssCapabilities?.toJson())
                }
                "getCurrentGnssStatus" -> {
                    result.success(getCurrentGnssStatusJson())
                }
                "getSatelliteData" -> {
                    result.success(getSatelliteDataJson())
                }
                "getMeasurementData" -> {
                    result.success(getMeasurementDataJson())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Set up event channel
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d(TAG, "Event channel listener attached")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d(TAG, "Event channel listener detached")
            }
        })
    }

    /**
     * Initialize GNSS capabilities
     */
    private fun initializeGnssCapabilities() {
        Log.d(TAG, "Starting GNSS capabilities initialization...")
        
        // Check if GPS hardware is available (not just if it's enabled)
        val hasGpsHardware = packageManager.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)
        Log.d(TAG, "GPS hardware available: $hasGpsHardware")
        
        // Check if location services are available - use multiple methods
        val hasLocationServices = try {
            val allProviders = locationManager.allProviders
            val hasProvider = allProviders.contains(LocationManager.GPS_PROVIDER)
            val isEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val getProvider = locationManager.getProvider(LocationManager.GPS_PROVIDER) != null
            
            Log.d(TAG, "Location services check: allProviders=$allProviders, hasProvider=$hasProvider, isEnabled=$isEnabled, getProvider=$getProvider")
            
            hasProvider || isEnabled || getProvider
        } catch (e: SecurityException) {
            // If we don't have permission, assume it's available if hardware is present
            Log.w(TAG, "No location permission for capabilities check, assuming available")
            hasGpsHardware
        }
        
        // Determine GNSS support - if hardware is available, assume GNSS is available
        val hasGnss = hasGpsHardware
        Log.d(TAG, "Final GNSS support determination: hasGnss=$hasGnss")
        
        gnssCapabilities = GnssCapabilities(
            hasGnss = hasGnss,
            hasGps = hasGpsHardware,
            hasGlonass = hasGpsHardware, // Most modern devices support GLONASS
            hasGalileo = hasGpsHardware, // Most modern devices support Galileo
            hasBeiDou = hasGpsHardware, // Most modern devices support BeiDou
            hasQzss = false, // QZSS is mainly for Japan
            hasIrnss = false, // IRNSS is mainly for India
            hasGnssMeasurements = hasGnss, // GNSS measurements available if GNSS is available
            hasGnssNavigationMessage = hasGnss, // Navigation messages available if GNSS is available
            maxSatellites = 64, // Typical maximum for modern GNSS receivers
            hardwareModel = android.os.Build.MODEL,
            softwareVersion = android.os.Build.VERSION.RELEASE
        )
        
        Log.d(TAG, "GNSS Capabilities initialized: hasGnss=$hasGnss, hasGpsHardware=$hasGpsHardware, hasLocationServices=$hasLocationServices")
        Log.d(TAG, "Final capabilities: $gnssCapabilities")
    }

    /**
     * Start GNSS tracking
     */
    fun startGnssTracking(): Boolean {
        if (isTracking.get()) {
            Log.w(TAG, "GNSS tracking already started")
            return true
        }

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "Fine location permission not granted")
            return false
        }

        try {
            // Register for GNSS status updates
            locationManager.registerGnssStatusCallback(gnssStatusCallback, null)
            
            // Register for GNSS measurements
            locationManager.registerGnssMeasurementsCallback(gnssMeasurementsCallback, null)
            
            // Register for location updates
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                MIN_UPDATE_INTERVAL_MS,
                MIN_UPDATE_DISTANCE_M,
                locationListener
            )
            
            isTracking.set(true)
            Log.d(TAG, "GNSS tracking started successfully")
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start GNSS tracking", e)
            return false
        }
    }

    /**
     * Stop GNSS tracking
     */
    fun stopGnssTracking() {
        if (!isTracking.get()) {
            return
        }

        try {
            locationManager.unregisterGnssStatusCallback(gnssStatusCallback)
            locationManager.unregisterGnssMeasurementsCallback(gnssMeasurementsCallback)
            locationManager.removeUpdates(locationListener)
            
            isTracking.set(false)
            satelliteData.clear()
            measurementData.clear()
            
            Log.d(TAG, "GNSS tracking stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping GNSS tracking", e)
        }
    }

    // Note: All GNSS callback methods are now implemented as callback objects above

    /**
     * Get constellation name from constellation type
     */
    private fun getConstellationName(constellationType: Int): String {
        return when (constellationType) {
            GnssStatus.CONSTELLATION_GPS -> "GPS"
            GnssStatus.CONSTELLATION_GLONASS -> "GLONASS"
            GnssStatus.CONSTELLATION_GALILEO -> "Galileo"
            GnssStatus.CONSTELLATION_BEIDOU -> "BeiDou"
            GnssStatus.CONSTELLATION_QZSS -> "QZSS"
            GnssStatus.CONSTELLATION_IRNSS -> "IRNSS"
            else -> "UNKNOWN"
        }
    }

    /**
     * Get carrier frequency for constellation and satellite
     */
    private fun getCarrierFrequency(constellation: String, svid: Int): Double {
        return when (constellation) {
            "GPS" -> 1575.42e6 // L1 frequency
            "GLONASS" -> 1602.0e6 + svid * 0.5625e6 // GLONASS frequency
            "Galileo" -> 1575.42e6 // E1 frequency
            "BeiDou" -> 1561.098e6 // B1 frequency
            "QZSS" -> 1575.42e6 // L1 frequency
            "IRNSS" -> 1176.45e6 // L5 frequency
            else -> 1575.42e6 // Default to GPS L1
        }
    }

    /**
     * Send event to Flutter
     */
    private fun sendEvent(eventType: String, data: Any?) {
        Log.d(TAG, "Sending event: $eventType with data: $data")
        if (eventSink != null) {
            eventSink!!.success(mapOf(
                "eventType" to eventType,
                "data" to data,
                "timestamp" to System.currentTimeMillis()
            ))
            Log.d(TAG, "Event sent successfully: $eventType")
        } else {
            Log.e(TAG, "Event sink is null, cannot send event: $eventType")
        }
    }

    /**
     * Create and send satellite status from measurements
     */
    private fun _sendSatelliteStatusFromMeasurements() {
        if (measurementData.isEmpty()) return
        
        // Create satellite info from measurements
        satelliteData.clear()
        for ((svid, measurement) in measurementData) {
            val satelliteInfo = SatelliteInfo(
                svid = svid,
                constellation = measurement.constellation,
                snr = measurement.snr,
                usedInFix = measurement.snr > 20.0, // Simple heuristic: SNR > 20 dB-Hz = used in fix
                elevation = measurement.elevation,
                azimuth = measurement.azimuth,
                hasAlmanac = measurement.hasAlmanac,
                hasEphemeris = measurement.hasEphemeris,
                carrierFrequency = measurement.carrierFrequency
            )
            satelliteData[svid] = satelliteInfo
        }
        
        Log.d(TAG, "Sending satellite status from measurements: ${satelliteData.size} satellites")
        sendEvent("satelliteStatus", getCurrentGnssStatusJson())
    }

    /**
     * Get current GNSS status as JSON
     */
    private fun getCurrentGnssStatusJson(): Map<String, Any> {
        val status = currentGnssStatus
        val location = currentLocation
        
        if (status == null) {
            return mapOf("error" to "No GNSS status available")
        }

        val satellites = satelliteData.values.map { it.toJson() }
        val satellitesInView = status.satelliteCount
        val satellitesInUse = satelliteData.values.count { it.usedInFix }
        val averageSnr = if (satellitesInUse > 0) {
            satelliteData.values.filter { it.usedInFix }.map { it.snr }.average()
        } else 0.0

        val fixType = when {
            satellitesInUse >= 4 -> "3D Fix"
            satellitesInUse >= 3 -> "2D Fix"
            else -> "No Fix"
        }

        return mapOf(
            "satellites" to satellites,
            "satellitesInView" to satellitesInView,
            "satellitesInUse" to satellitesInUse,
            "averageSnr" to averageSnr,
            "fixType" to fixType,
            "accuracy" to (location?.accuracy ?: 0.0),
            "altitudeAccuracy" to (location?.verticalAccuracyMeters ?: 0.0),
            "speed" to (location?.speed ?: 0.0),
            "bearing" to (location?.bearing ?: 0.0),
            "timestamp" to (location?.time ?: System.currentTimeMillis()),
            "isMocked" to (location?.isFromMockProvider ?: false),
            "latitude" to (location?.latitude ?: 0.0),
            "longitude" to (location?.longitude ?: 0.0),
            "altitude" to (location?.altitude ?: 0.0)
        )
    }

    /**
     * Get satellite data as JSON
     */
    private fun getSatelliteDataJson(): List<Map<String, Any>> {
        return satelliteData.values.map { it.toJson() }
    }

    /**
     * Get measurement data as JSON
     */
    private fun getMeasurementDataJson(): List<Map<String, Any>> {
        return measurementData.values.map { it.toJson() }
    }

    /**
     * Convert Location to JSON
     */
    private fun locationToJson(location: Location): Map<String, Any> {
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "altitude" to location.altitude,
            "accuracy" to location.accuracy,
            "speed" to location.speed,
            "bearing" to location.bearing,
            "timestamp" to location.time,
            "isMocked" to location.isFromMockProvider
        )
    }

    /**
     * Data classes for GNSS information
     */
    data class SatelliteInfo(
        val svid: Int,
        val constellation: String,
        val snr: Double,
        val usedInFix: Boolean,
        val elevation: Double,
        val azimuth: Double,
        val hasAlmanac: Boolean,
        val hasEphemeris: Boolean,
        val carrierFrequency: Double
    ) {
        fun toJson(): Map<String, Any> {
            return mapOf(
                "svid" to svid,
                "constellation" to constellation,
                "snr" to snr,
                "usedInFix" to usedInFix,
                "elevation" to elevation,
                "azimuth" to azimuth,
                "hasAlmanac" to hasAlmanac,
                "hasEphemeris" to hasEphemeris,
                "carrierFrequency" to carrierFrequency
            )
        }
    }

    data class GnssMeasurement(
        val svid: Int,
        val constellation: String,
        val pseudorange: Double,
        val pseudorangeRate: Double,
        val carrierPhase: Double,
        val carrierFrequency: Double,
        val snr: Double,
        val elevation: Double,
        val azimuth: Double,
        val hasAlmanac: Boolean,
        val hasEphemeris: Boolean,
        val timestamp: java.util.Date
    ) {
        fun toJson(): Map<String, Any> {
            return mapOf(
                "svid" to svid,
                "constellation" to constellation,
                "pseudorange" to pseudorange,
                "pseudorangeRate" to pseudorangeRate,
                "carrierPhase" to carrierPhase,
                "carrierFrequency" to carrierFrequency,
                "snr" to snr,
                "elevation" to elevation,
                "azimuth" to azimuth,
                "hasAlmanac" to hasAlmanac,
                "hasEphemeris" to hasEphemeris,
                "timestamp" to timestamp.time
            )
        }
    }

    data class GnssCapabilities(
        val hasGnss: Boolean,
        val hasGps: Boolean,
        val hasGlonass: Boolean,
        val hasGalileo: Boolean,
        val hasBeiDou: Boolean,
        val hasQzss: Boolean,
        val hasIrnss: Boolean,
        val hasGnssMeasurements: Boolean,
        val hasGnssNavigationMessage: Boolean,
        val maxSatellites: Int,
        val hardwareModel: String,
        val softwareVersion: String
    ) {
        fun toJson(): Map<String, Any> {
            return mapOf(
                "hasGnss" to hasGnss,
                "hasGps" to hasGps,
                "hasGlonass" to hasGlonass,
                "hasGalileo" to hasGalileo,
                "hasBeiDou" to hasBeiDou,
                "hasQzss" to hasQzss,
                "hasIrnss" to hasIrnss,
                "hasGnssMeasurements" to hasGnssMeasurements,
                "hasGnssNavigationMessage" to hasGnssNavigationMessage,
                "maxSatellites" to maxSatellites,
                "hardwareModel" to hardwareModel,
                "softwareVersion" to softwareVersion
            )
        }
    }
}
