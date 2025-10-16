package com.example.testgps

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1001
    }

    private var gnssNativeService: GnssNativeService? = null
    private var fusedLocationService: FusedLocationService? = null
    private var serviceBound = false
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            Log.d(TAG, "Service connected")
            val binder = service as GnssNativeService.GnssBinder
            gnssNativeService = binder.getService()
            serviceBound = true
            
            // Initialize channels after service is bound
            gnssNativeService?.initializeChannels(methodChannel, eventChannel)
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d(TAG, "Service disconnected")
            gnssNativeService = null
            serviceBound = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check and request permissions
        checkPermissions()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.testgps/gnss_native"
        )
        
        // Set up event channel
        eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.testgps/gnss_events"
        )
        
        // Initialize Fused Location Service
        fusedLocationService = FusedLocationService()
        fusedLocationService?.attachToEngine(flutterEngine, this)
        
        // Start and bind to the service
        startAndBindService()
    }

    private fun startAndBindService() {
        val serviceIntent = Intent(this, GnssNativeService::class.java)
        startService(serviceIntent)
        bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    private fun checkPermissions() {
        val permissions = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        
        val permissionsToRequest = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        
        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                LOCATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            LOCATION_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    Toast.makeText(this, "Location permissions granted", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(this, "Location permissions denied", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        
        if (serviceBound) {
            gnssNativeService?.stopGnssTracking()
            unbindService(serviceConnection)
            serviceBound = false
        }
        
        fusedLocationService?.detachFromEngine()
        fusedLocationService = null
        
        stopService(Intent(this, GnssNativeService::class.java))
    }
}