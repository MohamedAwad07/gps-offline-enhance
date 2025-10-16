package com.example.testgps

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import androidx.core.app.ActivityCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.*
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.util.concurrent.TimeUnit

class FusedLocationService : MethodCallHandler, EventChannel.StreamHandler {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    
    private var context: Context? = null
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null
    private var locationRequest: LocationRequest? = null
    
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    fun attachToEngine(flutterEngine: FlutterEngine, context: Context) {
        this.context = context
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.testgps/fused_location")
        methodChannel?.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.testgps/fused_location_events")
        eventChannel?.setStreamHandler(this)
        
        // Initialize FusedLocationProviderClient
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
    }
    
    fun detachFromEngine() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        context = null
        fusedLocationClient = null
        coroutineScope.cancel()
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isGooglePlayServicesAvailable" -> {
                result.success(isGooglePlayServicesAvailable())
            }
            "getCurrentPosition" -> {
                getCurrentPosition(call, result)
            }
            "startLocationUpdates" -> {
                startLocationUpdates(call, result)
            }
            "stopLocationUpdates" -> {
                stopLocationUpdates(result)
            }
            "getLocationSettingsStatus" -> {
                getLocationSettingsStatus(result)
            }
            "requestLocationSettings" -> {
                requestLocationSettings(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun isGooglePlayServicesAvailable(): Boolean {
        val context = this.context ?: return false
        val googleApiAvailability = GoogleApiAvailability.getInstance()
        val resultCode = googleApiAvailability.isGooglePlayServicesAvailable(context)
        return resultCode == ConnectionResult.SUCCESS
    }
    
    private fun getCurrentPosition(call: MethodCall, result: Result) {
        val context = this.context ?: return result.error("NO_CONTEXT", "Context not available", null)
        val fusedLocationClient = this.fusedLocationClient ?: return result.error("NO_CLIENT", "FusedLocationClient not available", null)
        
        if (!hasLocationPermission()) {
            return result.error("NO_PERMISSION", "Location permission not granted", null)
        }
        
        val timeout = (call.argument<Int>("timeout") ?: 120000).toLong() // 2 minutes default
        val accuracyString = call.argument<String>("accuracy") ?: "high"
        
        val locationRequest = createLocationRequest(accuracyString)
        
        fusedLocationClient.getCurrentLocation(
            locationRequest.priority,
            null
        ).addOnSuccessListener { location ->
            if (location != null) {
                val locationMap = locationToMap(location)
                result.success(locationMap)
            } else {
                result.error("NO_LOCATION", "Unable to get current location", null)
            }
        }.addOnFailureListener { exception ->
            result.error("LOCATION_ERROR", "Error getting location: ${exception.message}", null)
        }
    }
    
    private fun startLocationUpdates(call: MethodCall, result: Result) {
        val context = this.context ?: return result.error("NO_CONTEXT", "Context not available", null)
        val fusedLocationClient = this.fusedLocationClient ?: return result.error("NO_CLIENT", "FusedLocationClient not available", null)
        
        if (!hasLocationPermission()) {
            return result.error("NO_PERMISSION", "Location permission not granted", null)
        }
        
        val updateInterval = (call.argument<Int>("updateInterval") ?: 1000).toLong()
        val accuracyString = call.argument<String>("accuracy") ?: "high"
        
        locationRequest = createLocationRequest(accuracyString).apply {
            interval = updateInterval
            fastestInterval = updateInterval / 2
        }
        
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    val locationMap = locationToMap(location)
                    val eventData = mapOf(
                        "eventType" to "positionUpdate",
                        "data" to locationMap
                    )
                    eventSink?.success(eventData)
                }
            }
        }
        
        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest!!,
                locationCallback!!,
                Looper.getMainLooper()
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("UPDATE_ERROR", "Error starting location updates: ${e.message}", null)
        }
    }
    
    private fun stopLocationUpdates(result: Result) {
        val fusedLocationClient = this.fusedLocationClient ?: return result.error("NO_CLIENT", "FusedLocationClient not available", null)
        
        locationCallback?.let { callback ->
            fusedLocationClient.removeLocationUpdates(callback)
            locationCallback = null
        }
        
        locationRequest = null
        result.success(true)
    }
    
    private fun getLocationSettingsStatus(result: Result) {
        val context = this.context ?: return result.error("NO_CONTEXT", "Context not available", null)
        
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
        val isGpsEnabled = locationManager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER)
        val isNetworkEnabled = locationManager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER)
        val isPassiveEnabled = locationManager.isProviderEnabled(android.location.LocationManager.PASSIVE_PROVIDER)
        
        val statusMap = mapOf(
            "isLocationEnabled" to (isGpsEnabled || isNetworkEnabled || isPassiveEnabled),
            "isGpsEnabled" to isGpsEnabled,
            "isNetworkEnabled" to isNetworkEnabled,
            "isPassiveEnabled" to isPassiveEnabled
        )
        
        result.success(statusMap)
    }
    
    private fun requestLocationSettings(call: MethodCall, result: Result) {
        val context = this.context ?: return result.error("NO_CONTEXT", "Context not available", null)
        val needBle = call.argument<Boolean>("needBle") ?: false
        val accuracyString = call.argument<String>("accuracy") ?: "high"
        
        val locationRequest = createLocationRequest(accuracyString)
        val builder = LocationSettingsRequest.Builder()
            .addLocationRequest(locationRequest)
            .setAlwaysShow(true) // Always show location settings dialog
            .setNeedBle(needBle)
        
        val settingsClient = LocationServices.getSettingsClient(context)
        val locationSettingsRequest = builder.build()
        
        settingsClient.checkLocationSettings(locationSettingsRequest)
            .addOnSuccessListener {
                result.success(true)
            }
            .addOnFailureListener { exception ->
                result.error("SETTINGS_ERROR", "Location settings error: ${exception.message}", null)
            }
    }
    
    private fun createLocationRequest(accuracyString: String): LocationRequest {
        val priority = when (accuracyString.lowercase()) {
            "lowest" -> LocationRequest.PRIORITY_LOW_POWER
            "low" -> LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY
            "medium" -> LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY
            "high" -> LocationRequest.PRIORITY_HIGH_ACCURACY
            "best" -> LocationRequest.PRIORITY_HIGH_ACCURACY
            "bestfornavigation" -> LocationRequest.PRIORITY_HIGH_ACCURACY
            else -> LocationRequest.PRIORITY_HIGH_ACCURACY
        }
        
        val builder = LocationRequest.Builder(priority, 1000)
            .setWaitForAccurateLocation(true) // Wait for accurate location!
            .setMinUpdateIntervalMillis(500)
            .setMaxUpdateDelayMillis(2000)
        
        // Add accuracy-specific configurations
        when (accuracyString.lowercase()) {
            "bestfornavigation" -> {
                builder.setMinUpdateIntervalMillis(100) // Faster updates for navigation
                builder.setMaxUpdateDelayMillis(1000)
            }
            "best" -> {
                builder.setMinUpdateIntervalMillis(200)
                builder.setMaxUpdateDelayMillis(1500)
            }
            "high" -> {
                builder.setMinUpdateIntervalMillis(500)
                builder.setMaxUpdateDelayMillis(2000)
            }
        }
        
        return builder.build()
    }
    
    private fun hasLocationPermission(): Boolean {
        val context = this.context ?: return false
        return ActivityCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ActivityCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun locationToMap(location: Location): Map<String, Any> {
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "timestamp" to location.time,
            "accuracy" to location.accuracy,
            "altitude" to (location.altitude ?: 0.0),
            "heading" to (location.bearing ?: 0.0),
            "speed" to (location.speed ?: 0.0),
            "speedAccuracy" to (location.speedAccuracyMetersPerSecond ?: 0.0),
            "altitudeAccuracy" to (location.verticalAccuracyMeters ?: 0.0),
            "headingAccuracy" to (location.bearingAccuracyDegrees ?: 0.0),
            "isMocked" to location.isFromMockProvider
        )
    }
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
