package com.smssync.sms_sync_mobile

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.AlarmManagerCompat

class WatchdogReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "WatchdogReceiver"
        private const val ACTION_RESPAWN = "com.smssync.sms_sync_mobile.WATCHDOG_RESPAWN"
        private const val REQUEST_CODE = 10086
        private const val BACKGROUND_SERVICE_CLASS =
            "id.flutter.flutter_background_service.BackgroundService"

        fun enqueue(context: Context, delayMs: Long = SmsKeepAlivePolicy.watchdogDelayMillis()) {
            val appContext = context.applicationContext
            if (!SmsKeepAliveHelper.shouldMaintainWatchdog(appContext)) {
                remove(appContext)
                return
            }

            val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAtMillis = System.currentTimeMillis() + delayMs
            val pendingIntent = createPendingIntent(
                appContext,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val canUseExactAlarm =
                Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU || !canUseExactAlarm) {
                AlarmManagerCompat.setAndAllowWhileIdle(
                    alarmManager,
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else {
                AlarmManagerCompat.setExactAndAllowWhileIdle(
                    alarmManager,
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }
            Log.d(TAG, "enqueue: delayMs=$delayMs, triggerAt=$triggerAtMillis")
        }

        fun remove(context: Context) {
            val appContext = context.applicationContext
            val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent = createPendingIntentOrNull(
                appContext,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(TAG, "remove: cancelled keepalive watchdog")
            }
        }

        private fun createPendingIntent(context: Context, flags: Int): PendingIntent {
            val intent = Intent(context, WatchdogReceiver::class.java).apply {
                action = ACTION_RESPAWN
            }
            return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
        }

        private fun createPendingIntentOrNull(context: Context, flags: Int): PendingIntent? {
            val intent = Intent(context, WatchdogReceiver::class.java).apply {
                action = ACTION_RESPAWN
            }
            return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_RESPAWN) {
            return
        }

        val appContext = context.applicationContext
        if (!SmsKeepAliveHelper.shouldMaintainWatchdog(appContext)) {
            Log.d(TAG, "Watchdog disabled by config, removing alarm")
            remove(appContext)
            return
        }

        val running = isBackgroundServiceRunning(appContext)
        Log.d(TAG, "onReceive: serviceRunning=$running")

        if (!running) {
            Log.w(TAG, "Background service missing, restarting")
            SmsKeepAliveHelper.startMonitoringServices(appContext, "watchdog")
            return
        }

        SmsKeepAliveHelper.ensureNotificationListenerActive(appContext, "watchdog_alive")
        enqueue(appContext)
    }

    private fun isBackgroundServiceRunning(context: Context): Boolean {
        return try {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            @Suppress("DEPRECATION")
            manager.getRunningServices(Int.MAX_VALUE).any {
                it.service.className == BACKGROUND_SERVICE_CLASS
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to inspect running services", e)
            false
        }
    }
}
