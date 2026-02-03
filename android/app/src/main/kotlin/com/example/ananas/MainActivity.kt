package com.example.ananas

import android.content.Intent
import android.net.VpnService as AndroidVpnService
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.FlutterInjector
import java.io.File
import java.io.FileOutputStream
import android.util.Log

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.ananas/vpn"
    private val EVENT_CHANNEL = "com.example.ananas/vpn_status"
    private val VPN_REQUEST_CODE = 1001
    private var pendingVpnConfig: String? = null
    private val TAG = "AnanasVPN"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val success = initializeAssets()
                    if (success) result.success(true) else result.error("INIT_FAILED", "Failed to copy assets", null)
                }
                "startVpn" -> {
                    // Ensure all assets (binary and geo files) are ready
                    initializeAssets()
                    
                    val config = call.argument<String>("config")
                    if (config != null) {
                        val intent = AndroidVpnService.prepare(this)
                        if (intent != null) {
                            pendingVpnConfig = config
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                        } else {
                            startVpnService(config)
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_CONFIG", "Config is null", null)
                    }
                }
                "stopVpn" -> {
                    val intent = Intent(this, VpnService::class.java)
                    intent.action = "STOP_VPN"
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    VpnService.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    VpnService.eventSink = null
                }
            }
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE && resultCode == RESULT_OK) {
            pendingVpnConfig?.let {
                startVpnService(it)
                pendingVpnConfig = null
            }
        }
    }

    private fun startVpnService(config: String) {
        val intent = Intent(this, VpnService::class.java)
        intent.action = "START_VPN"
        intent.putExtra("config", config)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun initializeAssets(): Boolean {
        try {
            // 1. Check for Xray binary
            val nativeDir = applicationInfo.nativeLibraryDir
            val xrayFile = File(nativeDir, "libxray.so")
            
            if (!xrayFile.exists()) {
                Log.e(TAG, "Xray binary NOT found in native library directory!")
            } else {
                Log.d(TAG, "Xray binary found: ${xrayFile.absolutePath}")
            }

            // 2. Copy geo files from assets to internal storage (filesDir)
            val loader = FlutterInjector.instance().flutterLoader()
            val assetManager = assets
            val geoFiles = listOf("geoip.dat", "geosite.dat")
            
            for (fileName in geoFiles) {
                val assetPath = loader.getLookupKeyForAsset("assets/bin/xray_android/$fileName")
                val targetFile = File(filesDir, fileName)
                
                // Copy if file doesn't exist or we want to overwrite (optional)
                assetManager.open(assetPath).use { input ->
                    FileOutputStream(targetFile).use { output ->
                        input.copyTo(output)
                    }
                }
                Log.d(TAG, "Copied $fileName to ${targetFile.absolutePath}")
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize assets", e)
            return false
        }
    }
}