package com.smssync.sms_sync_mobile

import android.content.Context
import android.util.Log

object BackgroundServiceStarter {
    private const val TAG = "BgServiceStarter"

    fun ensureRunning(context: Context, reason: String) {
        try {
            SmsKeepAliveHelper.startMonitoringServices(context, reason)
            Log.d(TAG, "Requested keepalive start, reason=$reason")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request keepalive start, reason=$reason", e)
        }
    }
}
