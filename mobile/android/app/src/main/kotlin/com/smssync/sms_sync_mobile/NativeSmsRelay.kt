package com.smssync.sms_sync_mobile

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel

object NativeSmsRelay {
    private const val TAG = "NativeSmsRelay"
    private const val DUPLICATE_WINDOW_MS = 15_000L

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

        Log.d(TAG, "Method channel unavailable for $source, native relay will deliver from Room")
        BackgroundServiceStarter.ensureRunning(context, "$source-no-channel")
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

}
