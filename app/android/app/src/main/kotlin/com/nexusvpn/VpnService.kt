// Nexus — Android VpnService Implementation
// Manages the TUN interface, routes traffic through sing-box process.
// Manifest permissions required:
//   android.permission.BIND_VPN_SERVICE
//   android.permission.FOREGROUND_SERVICE
//   android.permission.INTERNET

package com.nexusvpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream

class NexusTunnelService : VpnService() {

    companion object {
        private const val TAG = "Nexus"
        private const val CHANNEL_ID = "nexus_channel"
        private const val NOTIFICATION_ID = 1
        const val ACTION_START = "com.nexusvpn.START"
        const val ACTION_STOP  = "com.nexusvpn.STOP"
        const val EXTRA_CONFIG = "singbox_config"
    }

    private var tunFd: ParcelFileDescriptor? = null
    private var singboxProcess: Process? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                startVpn(config)
                START_STICKY
            }
            ACTION_STOP -> {
                stopVpn()
                START_NOT_STICKY
            }
            else -> START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        stopVpn()
        scope.cancel()
        super.onDestroy()
    }

    // ── Tunnel Start ─────────────────────────────────────────────────────────────

    private fun startVpn(configJson: String) {
        Log.i(TAG, "Starting Nexus")
        showNotification("Nexus 正在连接...", "初始化中")

        scope.launch {
            try {
                // 1. Write sing-box config
                val configFile = writeConfig(configJson)

                // 2. Build TUN interface
                tunFd = buildTun()
                Log.i(TAG, "TUN interface created, fd=${tunFd?.fd}")

                // 3. Start sing-box process
                startSingbox(configFile, tunFd!!.fd)

                withContext(Dispatchers.Main) {
                    showNotification("Nexus 已连接", "通过 sing-box 代理")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Tunnel start failed: ${e.message}")
                stopVpn()
            }
        }
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping Nexus")
        singboxProcess?.destroy()
        singboxProcess = null
        tunFd?.close()
        tunFd = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ── TUN Interface ─────────────────────────────────────────────────────────

    private fun buildTun(): ParcelFileDescriptor {
        val builder = Builder()
            .setSession("Nexus")
            .addAddress("172.19.0.1", 30)
            .addAddress("fdfe:dcba:9876::1", 126)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .addDnsServer("172.19.0.1")   // Route DNS through TUN (leak prevention)
            .setMtu(9000)
            .setBlocking(true)

        // Optional: bypass apps (split tunnel)
        val bypassApps = listOf<String>() // fill from settings
        for (pkg in bypassApps) {
            runCatching { builder.addDisallowedApplication(pkg) }
        }

        return builder.establish() ?: throw IllegalStateException("Failed to establish TUN")
    }

    // ── sing-box Process ──────────────────────────────────────────────────────

    private fun writeConfig(json: String): File {
        val file = File(filesDir, "sing-box-config.json")
        FileOutputStream(file).use { it.write(json.toByteArray()) }
        return file
    }

    private fun startSingbox(configFile: File, tunFd: Int) {
        // Unpack sing-box binary from assets on first run
        val binary = extractBinary()

        val cmd = arrayOf(binary.absolutePath, "run", "-c", configFile.absolutePath)
        singboxProcess = ProcessBuilder(*cmd)
            .redirectErrorStream(true)
            .start()

        // Monitor logs
        scope.launch {
            singboxProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
                Log.d(TAG, "[sing-box] $line")
                if (line.contains("panic") || line.contains("fatal error")) {
                    Log.e(TAG, "sing-box crash — restarting in 2s")
                    // forEachLine's lambda is not a suspend context — use
                    // Thread.sleep (we're on a Dispatchers.IO worker thread).
                    Thread.sleep(2000)
                    startSingbox(configFile, tunFd)
                }
            }
        }

        // NOTE: Process.pid() requires API 33+ — don't rely on it here.
        Log.i(TAG, "sing-box started")
    }

    private fun extractBinary(): File {
        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
        val assetName = "sing-box-$abi"
        val outFile = File(filesDir, "sing-box")
        if (!outFile.exists()) {
            assets.open("cores/$assetName").use { input ->
                FileOutputStream(outFile).use { output -> input.copyTo(output) }
            }
            outFile.setExecutable(true)
        }
        return outFile
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun showNotification(title: String, text: String) {
        createChannel()
        // Use a system icon — the app's R class lives in the Flutter-generated
        // package (com.nexusvpn.nexus); launcher icon is applied during packaging.
        val icon = android.R.drawable.ic_lock_idle_lock
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(icon)
                .setContentTitle(title)
                .setContentText(text)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(icon)
                .setContentTitle(title)
                .setContentText(text)
                .setOngoing(true)
                .build()
        }
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                mgr.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Nexus", NotificationManager.IMPORTANCE_LOW)
                )
            }
        }
    }
}
