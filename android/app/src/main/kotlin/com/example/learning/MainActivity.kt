package com.example.learning

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.Manifest
import androidx.core.app.ActivityCompat
import android.net.wifi.WifiManager
import android.net.wifi.ScanResult
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.WifiManager.SCAN_RESULTS_AVAILABLE_ACTION

class MainActivity: FlutterActivity() {
    private val CHANNEL_BAROMETER = "barometer_service"
    private val CHANNEL_WIFI = "wifi_floor_detection"
    private val CHANNEL_GPS = "gps_altitude_service"
    
    private var barometerChannel: MethodChannel? = null
    private var wifiChannel: MethodChannel? = null
    private var gpsChannel: MethodChannel? = null
    
    private var sensorManager: SensorManager? = null
    private var pressureSensor: Sensor? = null
    private var pressureListener: SensorEventListener? = null
    
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null
    
    private var wifiManager: WifiManager? = null
    private var wifiReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize sensor manager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        pressureSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PRESSURE)
        
        // Initialize location manager
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        
        // Initialize WiFi manager
        wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        
        // Setup method channels
        setupBarometerChannel(flutterEngine)
        setupWifiChannel(flutterEngine)
        setupGpsChannel(flutterEngine)
    }
    
    private fun setupBarometerChannel(flutterEngine: FlutterEngine) {
        barometerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_BAROMETER)
        barometerChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isBarometerAvailable" -> {
                    val available = pressureSensor != null
                    result.success(available)
                }
                "getSensorInfo" -> {
                    val sensorInfo = mapOf(
                        "barometer_available" to (pressureSensor != null),
                        "pressure_sensor_name" to (pressureSensor?.name ?: "None"),
                        "pressure_sensor_vendor" to (pressureSensor?.vendor ?: "None"),
                        "pressure_sensor_version" to (pressureSensor?.version ?: 0)
                    )
                    result.success(sensorInfo)
                }
                "getPressure" -> {
                    if (pressureSensor != null) {
                        startPressureMonitoring()
                        result.success(getLastPressure())
                    } else {
                        result.error("BAROMETER_UNAVAILABLE", "Barometer sensor not available", null)
                    }
                }
                "startPressureMonitoring" -> {
                    startPressureMonitoring()
                    result.success(null)
                }
                "stopPressureMonitoring" -> {
                    stopPressureMonitoring()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun setupWifiChannel(flutterEngine: FlutterEngine) {
        wifiChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_WIFI)
        wifiChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getWiFiNetworks" -> {
                    getWiFiNetworks(result)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun setupGpsChannel(flutterEngine: FlutterEngine) {
        gpsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_GPS)
        gpsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isGPSAvailable" -> {
                    result.success(isGPSAvailable())
                }
                "getCurrentLocation" -> {
                    getCurrentLocation(result)
                }
                "startLocationMonitoring" -> {
                    startLocationMonitoring()
                    result.success(null)
                }
                "stopLocationMonitoring" -> {
                    stopLocationMonitoring()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    // Barometer methods
    private var lastPressure: Float = 0f
    
    private fun startPressureMonitoring() {
        if (pressureSensor != null && pressureListener == null) {
            pressureListener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent?) {
                    if (event?.sensor?.type == Sensor.TYPE_PRESSURE) {
                        lastPressure = event.values[0]
                        barometerChannel?.invokeMethod("pressureUpdate", lastPressure)
                    }
                }
                
                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
            }
            sensorManager?.registerListener(pressureListener, pressureSensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }
    
    private fun stopPressureMonitoring() {
        pressureListener?.let { listener ->
            sensorManager?.unregisterListener(listener)
            pressureListener = null
        }
    }
    
    private fun getLastPressure(): Float = lastPressure
    
    // WiFi methods
    private fun getWiFiNetworks(result: MethodChannel.Result) {
        try {
            if (wifiManager?.isWifiEnabled != true) {
                result.error("WIFI_DISABLED", "WiFi is disabled", null)
                return
            }
            
            // Try to get existing scan results first (no need to start new scan)
            val scanResults = wifiManager?.scanResults ?: emptyList()
            
            // If no results, try to start a scan (but don't fail if it doesn't work)
            if (scanResults.isEmpty()) {
                try {
                    wifiManager?.startScan()
                } catch (e: Exception) {
                    // Scan might fail due to rate limiting, that's okay
                }
                // Get results again after attempting scan
                val newScanResults = wifiManager?.scanResults ?: emptyList()
                if (newScanResults.isNotEmpty()) {
                    val networks = newScanResults.map { scanResult ->
                        mapOf(
                            "ssid" to (scanResult.SSID ?: ""),
                            "bssid" to (scanResult.BSSID ?: ""),
                            "signalStrength" to scanResult.level,
                            "frequency" to scanResult.frequency,
                            "capabilities" to (scanResult.capabilities ?: "")
                        )
                    }
                    result.success(networks)
                    return
                }
            }
            
            // Use existing scan results
            val networks = scanResults.map { scanResult ->
                mapOf(
                    "ssid" to (scanResult.SSID ?: ""),
                    "bssid" to (scanResult.BSSID ?: ""),
                    "signalStrength" to scanResult.level,
                    "frequency" to scanResult.frequency,
                    "capabilities" to (scanResult.capabilities ?: "")
                )
            }
            
            result.success(networks)
        } catch (e: Exception) {
            result.error("WIFI_ERROR", "WiFi scan error: ${e.message}", null)
        }
    }
    
    // GPS methods
    private fun isGPSAvailable(): Boolean {
        return locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true ||
               locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
    }
    
    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        
        // First try to get last known location (faster)
        try {
            var lastKnownLocation = locationManager?.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            if (lastKnownLocation == null) {
                lastKnownLocation = locationManager?.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            }
            
            if (lastKnownLocation != null) {
                val locationData = mapOf(
                    "latitude" to lastKnownLocation.latitude,
                    "longitude" to lastKnownLocation.longitude,
                    "altitude" to lastKnownLocation.altitude,
                    "accuracy" to lastKnownLocation.accuracy,
                    "speed" to lastKnownLocation.speed,
                    "heading" to lastKnownLocation.bearing,
                    "timestamp" to lastKnownLocation.time
                )
                result.success(locationData)
                return
            }
        } catch (e: Exception) {
            // Continue to request fresh location
        }
        
        // If no last known location, request fresh location with timeout
        val locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                val locationData = mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "altitude" to location.altitude,
                    "accuracy" to location.accuracy,
                    "speed" to location.speed,
                    "heading" to location.bearing,
                    "timestamp" to location.time
                )
                result.success(locationData)
                locationManager?.removeUpdates(this)
            }
            
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {
                result.error("GPS_DISABLED", "GPS provider disabled", null)
                locationManager?.removeUpdates(this)
            }
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        
        try {
            // Try GPS first, then network provider
            val providers = mutableListOf<String>()
            if (locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true) {
                providers.add(LocationManager.GPS_PROVIDER)
            }
            if (locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true) {
                providers.add(LocationManager.NETWORK_PROVIDER)
            }
            
            if (providers.isEmpty()) {
                result.error("NO_PROVIDERS", "No location providers available", null)
                return
            }
            
            // Request location from all available providers
            for (provider in providers) {
                locationManager?.requestLocationUpdates(
                    provider,
                    1000L,
                    1f,
                    locationListener
                )
            }
            
            // Set a timeout to avoid hanging
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                for (provider in providers) {
                    locationManager?.removeUpdates(locationListener)
                }
                result.error("GPS_TIMEOUT", "Location request timed out", null)
            }, 10000) // 10 second timeout
            
        } catch (e: Exception) {
            result.error("GPS_ERROR", "Failed to request location: ${e.message}", null)
        }
    }
    
    private fun startLocationMonitoring() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return
        }
        
        locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                val locationData = mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "altitude" to location.altitude,
                    "accuracy" to location.accuracy,
                    "speed" to location.speed,
                    "heading" to location.bearing,
                    "timestamp" to location.time
                )
                gpsChannel?.invokeMethod("locationUpdate", locationData)
            }
            
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        
        locationManager?.requestLocationUpdates(
            LocationManager.GPS_PROVIDER,
            5000L,
            1f,
            locationListener!!
        )
    }
    
    private fun stopLocationMonitoring() {
        locationListener?.let { listener ->
            locationManager?.removeUpdates(listener)
            locationListener = null
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopPressureMonitoring()
        stopLocationMonitoring()
    }
}