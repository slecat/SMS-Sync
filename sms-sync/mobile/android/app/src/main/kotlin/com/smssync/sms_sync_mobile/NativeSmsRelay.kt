package com.smssync.sms_sync_mobile

import android.content.Context
import org.json.JSONArray
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

object NativeSmsRelay {
    private const val TAG = "NativeSmsRelay"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_GROUP_ID = "groupId"
    private const val KEY_SYNC_SECRET = "syncSecret"
    private const val KEY_GROUP_ID_FLUTTER = "flutter.groupId"
    private const val KEY_SYNC_SECRET_FLUTTER = "flutter.syncSecret"
    private const val KEY_PENDING_NATIVE_SMS_QUEUE_FLUTTER = "flutter.pendingNativeSmsQueue"
    private const val DEFAULT_GROUP_ID = "default"
    private const val SIGNATURE_VERSION = 1
    private const val DUPLICATE_WINDOW_MS = 15_000L

    private data class PendingSms(
        val from: String,
        val body: String,
        val timestamp: Long,
        val source: String,
    )

    private data class RecentDispatch(
        val signature: String,
        val timestamp: Long,
    )

    var methodChannel: MethodChannel? = null
    private val recentDispatches = ArrayDeque<RecentDispatch>()
    private val dispatchLock = Any()

    fun deliver(context: Context, from: String, body: String, timestamp: Long, source: String) {
        if (shouldSkipDuplicate(from, body, timestamp)) {
            Log.d(TAG, "Skipped duplicate SMS from $source")
            return
        }

        val smsData = mapOf(
            "from" to from,
            "body" to body,
            "timestamp" to timestamp,
        )

        if (methodChannel != null) {
            methodChannel?.invokeMethod("onSmsReceived", smsData)
            Log.d(TAG, "Delivered SMS from $source to Flutter via method channel")
            return
        }

        Log.d(TAG, "Method channel unavailable for $source, queueing for background runtime")
        BackgroundServiceStarter.ensureRunning(context, "$source-no-channel")
        enqueuePendingSms(
            context = context,
            sms = PendingSms(from = from, body = body, timestamp = timestamp, source = source),
        )
    }

    private fun shouldSkipDuplicate(from: String, body: String, timestamp: Long): Boolean {
        val normalizedFrom = from.trim().lowercase()
        val normalizedBody = body.trim().replace("\r\n", "\n")
        val signature = "$normalizedFrom|${normalizedBody.hashCode()}"

        synchronized(dispatchLock) {
            while (recentDispatches.isNotEmpty() && timestamp - recentDispatches.first().timestamp > DUPLICATE_WINDOW_MS) {
                recentDispatches.removeFirst()
            }

            val duplicate = recentDispatches.any { dispatch ->
                dispatch.signature == signature && kotlin.math.abs(timestamp - dispatch.timestamp) <= DUPLICATE_WINDOW_MS
            }
            if (duplicate) {
                return true
            }

            recentDispatches.addLast(RecentDispatch(signature = signature, timestamp = timestamp))
            return false
        }
    }

    private fun enqueuePendingSms(context: Context, sms: PendingSms) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawQueue = prefs.getString(KEY_PENDING_NATIVE_SMS_QUEUE_FLUTTER, null)
            val queue = if (rawQueue.isNullOrBlank()) JSONArray() else JSONArray(rawQueue)
            val payload = JSONObject()
                .put("from", sms.from)
                .put("body", sms.body)
                .put("timestamp", sms.timestamp)
                .put("source", sms.source)

            queue.put(payload)
            prefs.edit().putString(KEY_PENDING_NATIVE_SMS_QUEUE_FLUTTER, queue.toString()).apply()
            Log.d(TAG, "Queued pending SMS from ${sms.source} for background delivery")
        } catch (e: Exception) {
            Log.e(TAG, "Error queueing pending SMS: ${e.message}", e)
        }
    }

    private fun sendSmsViaBroadcast(context: Context, from: String, body: String, timestamp: Long) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val groupId = loadStringPref(
                prefs = prefs,
                flutterKey = KEY_GROUP_ID_FLUTTER,
                legacyKey = KEY_GROUP_ID,
                defaultValue = DEFAULT_GROUP_ID,
            )
            val syncSecret = loadStringPref(
                prefs = prefs,
                flutterKey = KEY_SYNC_SECRET_FLUTTER,
                legacyKey = KEY_SYNC_SECRET,
                defaultValue = "",
            )

            val deviceId = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ANDROID_ID,
            ) ?: android.os.Build.ID ?: "unknown_device"
            val messageId = "${deviceId}_$timestamp"
            val payload = linkedMapOf<String, Any>(
                "type" to "sms",
                "messageId" to messageId,
                "from" to from,
                "body" to body,
                "timestamp" to timestamp,
                "groupId" to groupId,
            )
            val signedPayload = signPayload(payload, syncSecret)
            val smsJson = JSONObject(signedPayload)

            Thread {
                try {
                    val socket = DatagramSocket()
                    socket.setBroadcast(true)
                    val data = smsJson.toString().toByteArray(Charsets.UTF_8)
                    val address = InetAddress.getByName("255.255.255.255")
                    val packet = DatagramPacket(data, data.size, address, 8888)
                    socket.send(packet)
                    socket.close()
                    Log.d(TAG, "UDP broadcast sent successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending UDP broadcast: ${e.message}", e)
                }
            }.start()
        } catch (e: Exception) {
            Log.e(TAG, "Error preparing UDP broadcast: ${e.message}", e)
        }
    }

    private fun loadStringPref(
        prefs: android.content.SharedPreferences,
        flutterKey: String,
        legacyKey: String,
        defaultValue: String,
    ): String {
        return prefs.getString(flutterKey, null)
            ?: prefs.getString(legacyKey, defaultValue)
            ?: defaultValue
    }

    private fun signPayload(
        payload: LinkedHashMap<String, Any>,
        secret: String,
    ): LinkedHashMap<String, Any> {
        val normalizedSecret = secret.trim()
        if (normalizedSecret.isEmpty()) {
            return payload
        }

        val canonical = JSONObject(payload.toSortedMap(compareBy<String> { it })).toString()
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(normalizedSecret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        val digest = mac.doFinal(canonical.toByteArray(Charsets.UTF_8))
        val signed = LinkedHashMap(payload)
        signed["_sig_v"] = SIGNATURE_VERSION
        signed["_sig"] = digest.joinToString("") { "%02x".format(it) }
        return signed
    }
}
