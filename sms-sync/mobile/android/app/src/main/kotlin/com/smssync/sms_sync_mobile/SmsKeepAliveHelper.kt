package com.smssync.sms_sync_mobile

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.util.Log
import androidx.core.content.ContextCompat
import id.flutter.flutter_background_service.Config
import com.smssync.sms_sync_mobile.reliability.ReliableRelayService

object SmsKeepAliveHelper {
    private const val TAG = "SmsKeepAlive"
    private const val EXTRA_START_REASON = "sms_sync_start_reason"
    private const val BACKGROUND_SERVICE_CLASS =
        "id.flutter.flutter_background_service.BackgroundService"

    fun startMonitoringServices(context: Context, reason: String) {
        val appContext = context.applicationContext
        val config = Config(appContext)
        if (!SmsKeepAlivePolicy.shouldMaintainWatchdog(
                manuallyStopped = config.isManuallyStopped,
                backgroundHandle = config.backgroundHandle,
            )
        ) {
            Log.d(
                TAG,
                "Keepalive skipped: reason=$reason, manuallyStopped=${config.isManuallyStopped}, handle=${config.backgroundHandle}",
            )
            WatchdogReceiver.remove(appContext)
            return
        }

        requestBackgroundServiceStart(appContext, reason, config)
        requestReliableRelayStart(appContext, reason)
        ensureNotificationListenerActive(appContext, reason)
        WatchdogReceiver.enqueue(appContext)
    }

    private fun requestReliableRelayStart(context: Context, reason: String) {
        val intent = Intent(context, ReliableRelayService::class.java).putExtra("reason", reason)
        try {
            ContextCompat.startForegroundService(context, intent)
        } catch (error: Exception) {
            Log.e(TAG, "Failed to start native relay, reason=$reason", error)
        }
    }

    fun ensureNotificationListenerActive(context: Context, reason: String) {
        val appContext = context.applicationContext
        try {
            appContext.startService(Intent(appContext, SmsNotificationListenerService::class.java))
        } catch (e: Exception) {
            Log.w(TAG, "Listener start request failed, reason=$reason", e)
        }

        requestNotificationListenerRebind(appContext, reason)
    }

    fun requestNotificationListenerRebind(context: Context, reason: String) {
        val appContext = context.applicationContext
        val enabledListeners = try {
            Settings.Secure.getString(
                appContext.contentResolver,
                "enabled_notification_listeners",
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read notification listener settings, reason=$reason", e)
            null
        }

        val component = ComponentName(appContext, SmsNotificationListenerService::class.java)
        if (!NotificationListenerSupport.shouldRequestRebind(
                sdkInt = Build.VERSION.SDK_INT,
                enabledListeners = enabledListeners,
                componentName = component.flattenToString(),
            )
        ) {
            Log.d(TAG, "Notification listener rebind skipped, reason=$reason")
            return
        }

        try {
            NotificationListenerService.requestRebind(component)
            Log.d(TAG, "Notification listener rebind requested, reason=$reason")
        } catch (e: Exception) {
            Log.e(TAG, "Notification listener rebind failed, reason=$reason", e)
        }
    }

    fun shouldMaintainWatchdog(context: Context): Boolean {
        val config = Config(context.applicationContext)
        return SmsKeepAlivePolicy.shouldMaintainWatchdog(
            manuallyStopped = config.isManuallyStopped,
            backgroundHandle = config.backgroundHandle,
        )
    }

    private fun requestBackgroundServiceStart(
        context: Context,
        reason: String,
        config: Config,
    ) {
        val serviceIntent = Intent().setClassName(context, BACKGROUND_SERVICE_CLASS)
            .putExtra(EXTRA_START_REASON, reason)

        try {
            if (config.isForeground) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Requested background service start, reason=$reason")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request background service start, reason=$reason", e)
        }
    }
}
