package com.nexusvpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter MethodChannel `com.nexusvpn/vpn` to [NexusVpnService].
 * Copied into the flutter-created tree by CI / apply_release_config.sh.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.nexusvpn/vpn"
        private const val REQ_VPN = 1001
    }

    private var pendingConfig: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVpn" -> {
                        val config = call.argument<String>("config")
                        if (config.isNullOrEmpty()) {
                            result.error("INVALID_ARGS", "config required", null)
                            return@setMethodCallHandler
                        }
                        prepareAndStart(config, result)
                    }
                    "stopVpn" -> {
                        val intent = Intent(this, NexusVpnService::class.java).apply {
                            action = NexusVpnService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "getStats" -> {
                        result.success(
                            mapOf(
                                "uploadMbps" to 0.0,
                                "downloadMbps" to 0.0,
                                "latencyMs" to 0,
                            )
                        )
                    }
                    "setSystemProxy", "clearSystemProxy" -> {
                        // Android uses VpnService TUN — system proxy N/A
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun prepareAndStart(config: String, result: MethodChannel.Result) {
        val prepare = VpnService.prepare(this)
        if (prepare != null) {
            pendingConfig = config
            pendingResult = result
            startActivityForResult(prepare, REQ_VPN)
        } else {
            startVpnService(config)
            result.success(true)
        }
    }

    private fun startVpnService(config: String) {
        val intent = Intent(this, NexusVpnService::class.java).apply {
            action = NexusVpnService.ACTION_START
            putExtra(NexusVpnService.EXTRA_CONFIG, config)
        }
        startForegroundService(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_VPN) return
        val result = pendingResult
        val config = pendingConfig
        pendingResult = null
        pendingConfig = null
        if (resultCode == Activity.RESULT_OK && config != null) {
            startVpnService(config)
            result?.success(true)
        } else {
            result?.error("VPN_PERMISSION", "User denied VPN permission", null)
        }
    }
}
