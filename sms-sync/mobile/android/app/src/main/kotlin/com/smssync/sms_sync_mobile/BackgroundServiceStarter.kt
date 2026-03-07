package com.smssync.sms_sync_mobile

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import id.flutter.flutter_background_service.WatchdogReceiver

object BackgroundServiceStarter {
    private const val TAG = "BgServiceStarter"

    fun ensureRunning(context: Context, reason: String) {
        val appContext = context.applicationContext
        val serviceIntent = Intent().setClassName(
            appContext,
            "id.flutter.flutter_background_service.BackgroundService"
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(appContext, serviceIntent)
            } else {
                appContext.startService(serviceIntent)
            }
            // Keep watchdog checks alive even when OEM kills the process silently.
            WatchdogReceiver.enqueue(appContext)
            Log.d(TAG, "Requested background service start, reason=$reason")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request background service start, reason=$reason", e)
        }
    }
}
