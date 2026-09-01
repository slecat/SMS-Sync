package com.smssync.sms_sync_mobile.reliability

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.smssync.sms_sync_mobile.NativeConfigStore
import com.smssync.sms_sync_mobile.storage.OutboxDatabaseProvider
import com.smssync.sms_sync_mobile.storage.OutboxMessage
import com.smssync.sms_sync_mobile.storage.OutboxRepository
import com.smssync.sms_sync_mobile.storage.RoomOutboxStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import android.provider.Settings
import java.util.concurrent.TimeUnit

/** Small native foreground anchor. Flutter remains responsible for socket I/O. */
class ReliableRelayService : Service() {
    companion object {
        private const val TAG = "ReliableRelayService"
    private const val CHANNEL = "sms_sync_relay"
        private const val EXTRA_REASON = "reason"
        private const val NOTIFICATION_ID = 889
    }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val client = OkHttpClient.Builder().pingInterval(20, TimeUnit.SECONDS).build()
    private var socket: WebSocket? = null
    private var repository: OutboxRepository? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(NOTIFICATION_ID, Notification.Builder(this, CHANNEL)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("短信同步")
            .setContentText("可靠中继已运行")
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build())
        scheduleRecovery()
        repository = OutboxRepository(RoomOutboxStore(OutboxDatabaseProvider.get(this).outboxDao()))
        connect()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "relay service started: reason=${intent?.getStringExtra(EXTRA_REASON)}")
        scheduleRecovery()
        connect()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        socket?.close(1000, "service stopped")
        socket = null
        scope.cancel()
        client.dispatcher.executorService.shutdown()
        super.onDestroy()
    }

    private fun connect() {
        val config = NativeConfigStore(this).read()
        val url = config.serverUrl.trim()
        if (url.isEmpty() || socket != null) return
        val deviceId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: Build.ID
        val request = runCatching { Request.Builder().url(url).build() }.getOrNull() ?: return
        socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                webSocket.send(JSONObject().apply {
                    put("type", "register"); put("protocolVersion", 2); put("deviceId", deviceId)
                    put("groupId", config.groupId); put("deviceName", config.deviceName); put("platform", "mobile")
                }.toString())
                drain(webSocket, config.groupId, deviceId)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                val payload = runCatching { JSONObject(text) }.getOrNull() ?: return
                if (payload.optString("type") == "server-ack") {
                    val messageId = payload.optString("messageId")
                    if (messageId.isNotEmpty()) scope.launch { repository?.markServerAcked(messageId) }
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { handleDisconnect() }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) { handleDisconnect() }
        })
    }

    private fun drain(webSocket: WebSocket, groupId: String, deviceId: String) {
        scope.launch {
            val repo = repository ?: return@launch
            repo.recoverExpiredLeases()
            while (socket != null) {
                val message = repo.findReady(1).firstOrNull() ?: break
                if (!repo.claim(message.messageId, System.currentTimeMillis() + 45_000L)) continue
                val sent = webSocket.send(JSONObject().apply {
                    put("type", "sms"); put("protocolVersion", 2); put("messageId", message.messageId)
                    put("groupId", groupId); put("sourceDeviceId", deviceId); put("from", message.from)
                    put("body", message.body); put("receivedAt", message.receivedAt); put("timestamp", message.receivedAt)
                }.toString())
                if (!sent) {
                    repo.markRetry(message.messageId, System.currentTimeMillis() + ReliableRelayPolicy.retryDelayMillis(message.attemptCount + 1), "socket_send_failed")
                    break
                }
                kotlinx.coroutines.delay(5_000L)
                repo.markRetry(message.messageId, System.currentTimeMillis() + ReliableRelayPolicy.retryDelayMillis(message.attemptCount + 1), "ack_timeout")
            }
        }
    }

    private fun handleDisconnect() {
        socket = null
        android.os.Handler(mainLooper).postDelayed({ connect() }, 5_000L)
    }

    private fun scheduleRecovery() {
        WorkManager.getInstance(applicationContext).enqueue(
            OneTimeWorkRequestBuilder<OutboxRecoveryWorker>()
                .setInitialDelay(30, TimeUnit.SECONDS)
                .build(),
        )
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "可靠中继", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

}
