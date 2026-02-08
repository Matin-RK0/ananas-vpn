package com.example.ananas

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService as AndroidVpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import android.system.Os
import android.system.OsConstants
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import com.v2ray.ang.service.TProxyService
import java.io.BufferedReader
import java.io.File
import java.io.FileDescriptor
import java.io.InterruptedIOException
import java.io.IOException
import java.util.Timer
import java.util.TimerTask

class VpnService : AndroidVpnService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null
        @Volatile private var isRunning = false
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "vpn_channel"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var process: Process? = null
    private var tun2socksStarted: Boolean = false
    private var statusTimer: Timer? = null
    private var startTime: Long = 0
    private var tunFdInt: Int = -1
    private var lastRxBytes: Long = 0
    private var lastTxBytes: Long = 0
    private var zeroCountDown = 0
    private var zeroCountUp = 0
    private var hevLogThread: Thread? = null
    @Volatile private var hevLogRunning: Boolean = false

    private val tunAddress = "172.19.0.1"
    private val tunPrefix = 30
    private val tunNetmask = "255.255.255.252"
    private val socksPort = 10808
    private val httpPort = 10809
    private val dns1 = "1.1.1.1"
    private val dns2 = "8.8.8.8"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "STOP_VPN" -> stopVpn()
            "START_VPN" -> {
                val config = intent.getStringExtra("config")
                if (config != null && !isRunning) {
                    showNotification("Ananas VPN", "Connecting...")
                    Thread { startVpn(config) }.start()
                }
            }
        }
        return START_NOT_STICKY
    }

    private fun showNotification(title: String, content: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startVpn(config: String) {
        synchronized(this) {
            if (isRunning) return
            isRunning = true
        }

        try {
            val nativeDir = applicationInfo.nativeLibraryDir
            val xrayBinary = File(nativeDir, "libxray.so")
            
            // Ensure xray is executable
            if (!xrayBinary.exists()) {
                Log.e("AnanasVPN", "Xray binary not found!")
                stopVpn()
                return
            }

            val updatedConfig = prepareBridgeConfig(config)
            val configFile = File(filesDir, "config.json")
            configFile.writeText(updatedConfig)

            startXrayProcess(xrayBinary, configFile)

            // Wait for Xray to start and open ports
            var retry = 0
            var portOpened = false
            while (retry < 10) { // Increased retries
                if (isPortOpen("127.0.0.1", socksPort)) {
                    portOpened = true
                    break
                }
                Thread.sleep(500)
                retry++
            }

            if (!portOpened) {
                Log.e("AnanasVPN", "Xray ports failed to open after 5 seconds. Check Xray logs.")
                // We don't stop here, but it's a major warning. 
                // Xray might have crashed due to config error.
            }

            if (!establishVpn()) {
                Log.e("AnanasVPN", "Failed to establish VPN interface")
                stopVpn()
                return
            }

            if (!startTun2Socks()) {
                Log.e("AnanasVPN", "tun2socks failed.")
                stopVpn()
                return
            }

            startTime = System.currentTimeMillis()
            lastRxBytes = android.net.TrafficStats.getTotalRxBytes()
            lastTxBytes = android.net.TrafficStats.getTotalTxBytes()
            startStatusUpdates()
            showNotification("Ananas VPN", "Connected")
        } catch (e: Exception) {
            Log.e("AnanasVPN", "Error starting VPN", e)
            stopVpn()
        }
    }

    private fun isPortOpen(host: String, port: Int): Boolean {
        return try {
            java.net.Socket(host, port).use { true }
        } catch (e: Exception) {
            false
        }
    }

    private fun prepareBridgeConfig(config: String): String {
        return try {
            val json = org.json.JSONObject(config)

            // 1. Setup Logging
            val log = json.optJSONObject("log") ?: org.json.JSONObject()
            log.put("loglevel", "warning")
            json.put("log", log)

            // 2. Setup Inbounds (Exactly like v2rayNG)
            val inbounds = org.json.JSONArray()
            
            // SOCKS inbound for tun2socks
            val socksInbound = org.json.JSONObject()
            socksInbound.put("tag", "socks-in")
            socksInbound.put("protocol", "socks")
            socksInbound.put("listen", "127.0.0.1")
            socksInbound.put("port", socksPort)
            socksInbound.put("settings", org.json.JSONObject().put("udp", true).put("auth", "noauth"))
            socksInbound.put("sniffing", org.json.JSONObject()
                .put("enabled", true)
                .put("destOverride", org.json.JSONArray().put("http").put("tls").put("quic").put("fakedns"))
                .put("routeOnly", true)
            )
            inbounds.put(socksInbound)

            // HTTP inbound
            val httpInbound = org.json.JSONObject()
            httpInbound.put("tag", "http-in")
            httpInbound.put("protocol", "http")
            httpInbound.put("listen", "127.0.0.1")
            httpInbound.put("port", httpPort)
            inbounds.put(httpInbound)

            json.put("inbounds", inbounds)

            // 3. Setup Outbounds
            val outbounds = json.optJSONArray("outbounds") ?: org.json.JSONArray()
            
            // Ensure dns-out exists
            var hasDnsOut = false
            for (i in 0 until outbounds.length()) {
                if (outbounds.getJSONObject(i).optString("tag") == "dns-out") {
                    hasDnsOut = true
                    break
                }
            }
            if (!hasDnsOut) {
                outbounds.put(org.json.JSONObject().put("protocol", "dns").put("tag", "dns-out"))
            }

            // Ensure direct exists
            var hasDirect = false
            for (i in 0 until outbounds.length()) {
                if (outbounds.getJSONObject(i).optString("tag") == "direct") {
                    hasDirect = true
                    break
                }
            }
            if (!hasDirect) {
                outbounds.put(org.json.JSONObject().put("protocol", "freedom").put("tag", "direct").put("settings", org.json.JSONObject()))
            }
            json.put("outbounds", outbounds)

            // 4. Setup DNS (Robust Config)
            val dns = org.json.JSONObject()
            dns.put("queryStrategy", "UseIP")
            
            val dnsServers = org.json.JSONArray()
            dnsServers.put("fakedns")
            
            // Primary DNS (Proxied)
            dnsServers.put("1.1.1.1")
            
            // Backup/Direct DNS for resolving proxy domain
            val directDns = org.json.JSONObject()
            directDns.put("address", "8.8.8.8")
            directDns.put("port", 53)
            directDns.put("tag", "dns-direct")
            dnsServers.put(directDns)
            
            dns.put("servers", dnsServers)
            json.put("dns", dns)

            // 5. Setup FakeDNS
            val fakedns = org.json.JSONArray()
            fakedns.put(org.json.JSONObject().put("ipPool", "198.18.0.0/16").put("poolSize", 65535))
            json.put("fakedns", fakedns)

            // 6. Setup Routing Rules
            val routing = json.optJSONObject("routing") ?: org.json.JSONObject()
            routing.put("domainStrategy", "IPIfNonMatch")
            
            val rules = org.json.JSONArray()
            
            // 1. DNS Rule: Hijack DNS queries from TUN
            val dnsRule = org.json.JSONObject()
            dnsRule.put("type", "field")
            dnsRule.put("inboundTag", org.json.JSONArray().put("socks-in"))
            dnsRule.put("port", 53)
            dnsRule.put("outboundTag", "dns-out")
            rules.put(dnsRule)

            // 2. Direct Rule: System/Xray internal DNS queries should go DIRECT
            val directDnsRule = org.json.JSONObject()
            directDnsRule.put("type", "field")
            directDnsRule.put("outboundTag", "direct")
            directDnsRule.put("ip", org.json.JSONArray().put("8.8.8.8").put("1.1.1.1"))
            directDnsRule.put("port", 53)
            rules.put(directDnsRule)

            // 3. Bypass Private IPs
            val privateRule = org.json.JSONObject()
            privateRule.put("type", "field")
            privateRule.put("outboundTag", "direct")
            privateRule.put("ip", org.json.JSONArray().put("geoip:private"))
            rules.put(privateRule)

            // 4. Proxy everything else
            val proxyRule = org.json.JSONObject()
            proxyRule.put("type", "field")
            proxyRule.put("outboundTag", "proxy")
            proxyRule.put("port", "0-65535")
            rules.put(proxyRule)

            routing.put("rules", rules)
            json.put("routing", routing)

            json.toString()
        } catch (e: Exception) {
            Log.e("AnanasVPN", "Config Prep Error: ${e.message}")
            config
        }
    }

    private fun startXrayProcess(binary: File, configFile: File) {
        try {
            val pb = ProcessBuilder(binary.absolutePath, "run", "-c", configFile.absolutePath)
            pb.directory(filesDir)
            val env = pb.environment()
            env["XRAY_LOCATION_ASSET"] = filesDir.absolutePath
            env["V2RAY_ASSET_PATH"] = filesDir.absolutePath
            pb.redirectErrorStream(true)
            process = pb.start()

            Thread {
                var reader: BufferedReader? = null
                try {
                    reader = process?.inputStream?.bufferedReader()
                    while (isRunning) {
                        val line = reader?.readLine() ?: break
                        Log.d("AnanasXrayLog", line)
                    }
                } catch (e: InterruptedIOException) {
                    Log.d("AnanasVPN", "Xray process reader interrupted.")
                } catch (e: IOException) {
                    Log.e("AnanasVPN", "IOException while reading Xray process output: ${e.message}")
                } finally {
                    reader?.close()
                }
            }.start()
        } catch (e: Exception) {
            Log.e("AnanasVPN", "Xray Start Failed: ${e.message}")
        }
    }

    private fun establishVpn(): Boolean {
        return try {
            val builder = Builder()
            builder.setSession("AnanasVPN")
            builder.setMtu(1500) // standard MTU
            builder.addAddress(tunAddress, tunPrefix)
            
            // DNS handling
            builder.addDnsServer(dns1)
            builder.addDnsServer(dns2)
            
            // Routing all traffic through VPN
            builder.addRoute("0.0.0.0", 0)
            
            // Exclude our own app to prevent loops
            builder.addDisallowedApplication(packageName)

            // IPv6 support (optional but good for modern networks)
            try {
                builder.addAddress("fdfe:dcba:9876::1", 126)
                builder.addRoute("::", 0)
            } catch (e: Exception) {
                Log.w("AnanasVPN", "IPv6 not supported on this device/network")
            }

            // v2rayNG often uses this to improve compatibility
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            vpnInterface = builder.establish()
            if (vpnInterface != null) {
                Log.d("AnanasVPN", "VPN Interface established: $tunAddress")
                true
            } else {
                Log.e("AnanasVPN", "Failed to establish VPN interface (null)")
                false
            }
        } catch (e: Exception) {
            Log.e("AnanasVPN", "Establish Error: ${e.message}")
            false
        }
    }

    private fun isTun2SocksAvailable(): Boolean {
        val nativeDir = applicationInfo.nativeLibraryDir
        val hevTun = File(nativeDir, "libhev-socks5-tunnel.so")
        return hevTun.exists()
    }

    private fun startTun2Socks(): Boolean {
        val fd = vpnInterface?.fileDescriptor ?: return false
        val fdInt = getFdInt(fd)
        if (fdInt <= 0) {
            Log.e("AnanasVPN", "Invalid tun fd")
            return false
        }

        try {
            Os.fcntlInt(fd, OsConstants.F_SETFD, 0)
        } catch (e: Exception) {
            Log.w("AnanasVPN", "Failed to clear CLOEXEC on tun fd: ${e.message}")
        }

        val logFile = File(filesDir, "hev-tun.log")
        val config = buildHevTunConfig(logFile)
        val configFile = File(filesDir, "hev-tun.conf")
        return try {
            if (logFile.exists()) logFile.delete()
            configFile.writeText(config)
            TProxyService.TProxyStartService(configFile.absolutePath, fdInt)
            tun2socksStarted = true
            startHevLogTail(logFile)
            true
        } catch (e: Exception) {
            Log.e("AnanasVPN", "Failed to start hev-socks5-tunnel: ${e.message}")
            false
        }
    }

    private fun buildHevTunConfig(logFile: File): String {
        return """
tunnel:
  mtu: 1500
  ipv4: $tunAddress
  netmask: $tunNetmask

socks5:
  address: 127.0.0.1
  port: $socksPort
  udp: 'udp'

misc:
  log-level: warning
  log-file: ${logFile.absolutePath}
""".trimIndent()
    }

    private fun startHevLogTail(logFile: File) {
        if (hevLogRunning) return
        hevLogRunning = true
        hevLogThread = Thread {
            var raf: java.io.RandomAccessFile? = null
            var lastPos = 0L
            try {
                while (hevLogRunning) {
                    if (!logFile.exists()) {
                        Thread.sleep(200)
                        continue
                    }
                    if (raf == null) {
                        raf = java.io.RandomAccessFile(logFile, "r")
                        lastPos = 0L
                    }
                    raf?.seek(lastPos)
                    var line = raf?.readLine()
                    while (line != null) {
                        Log.d("AnanasHevTun", line)
                        lastPos = raf?.filePointer ?: lastPos
                        line = raf?.readLine()
                    }
                    Thread.sleep(200)
                }
            } catch (e: Exception) {
                Log.w("AnanasHevTun", "Log tail stopped: ${e.message}")
            } finally {
                try {
                    raf?.close()
                } catch (_: Exception) {
                }
            }
        }
        hevLogThread?.isDaemon = true
        hevLogThread?.start()
    }

    private fun getFdInt(fd: FileDescriptor): Int {
        return try {
            val field = FileDescriptor::class.java.getDeclaredField("descriptor")
            field.isAccessible = true
            field.getInt(fd)
        } catch (e: Exception) {
            try {
                val field = FileDescriptor::class.java.getDeclaredField("fd")
                field.isAccessible = true
                field.getInt(fd)
            } catch (e2: Exception) {
                -1
            }
        }
    }

    private fun stopVpn() {
        synchronized(this) {
            if (!isRunning) return
            isRunning = false
        }

        try {
            statusTimer?.cancel()
            statusTimer = null

            if (tun2socksStarted) {
                try {
                    TProxyService.TProxyStopService()
                } catch (_: Exception) {
                }
                tun2socksStarted = false
            }

            hevLogRunning = false
            hevLogThread?.interrupt()
            hevLogThread = null

            process?.destroy()
            process = null

            vpnInterface?.close()
            vpnInterface = null

            updateStatus("DISCONNECTED", 0, 0)
        } catch (e: Throwable) {
            Log.e("AnanasVPN", "Error during stopVpn", e)
        } finally {
            stopForeground(true)
            stopSelf()
        }
    }

    private fun startStatusUpdates() {
        statusTimer = Timer()
        statusTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (!isRunning) return
                
                val currentRx = android.net.TrafficStats.getTotalRxBytes()
                val currentTx = android.net.TrafficStats.getTotalTxBytes()
                
                var downSpeed = if (lastRxBytes > 0) (currentRx - lastRxBytes).toInt() else 0
                var upSpeed = if (lastTxBytes > 0) (currentTx - lastTxBytes).toInt() else 0
                
                // Smoothing/Debouncing zeroes: 
                // Some Android versions don't update TrafficStats every second.
                // If we get a 0, we check if it persists.
                if (downSpeed == 0 && lastRxBytes > 0) {
                    zeroCountDown++
                    if (zeroCountDown < 2) { // Skip first zero
                        return // Don't update yet, wait for next tick
                    }
                } else {
                    zeroCountDown = 0
                }

                if (upSpeed == 0 && lastTxBytes > 0) {
                    zeroCountUp++
                    if (zeroCountUp < 2) {
                        return 
                    }
                } else {
                    zeroCountUp = 0
                }
                
                lastRxBytes = currentRx
                lastTxBytes = currentTx

                val durationMs = System.currentTimeMillis() - startTime
                val durationStr = String.format(
                    "%02d:%02d:%02d",
                    durationMs / 3600000,
                    (durationMs % 3600000) / 60000,
                    (durationMs % 60000) / 1000
                )
                updateStatus("CONNECTED", upSpeed, downSpeed, durationStr)
            }
        }, 0, 1000)
    }

    private fun updateStatus(state: String, up: Int, down: Int, duration: String = "00:00:00") {
        val status = mapOf(
            "state" to state,
            "uploadSpeed" to up,
            "downloadSpeed" to down,
            "duration" to duration
        )
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                eventSink?.success(status)
            } catch (e: Exception) {
                Log.e("AnanasVPN", "Failed to send status update", e)
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "VPN Service Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
    }

    override fun onRevoke() {
        super.onRevoke()
        stopVpn()
    }
}
