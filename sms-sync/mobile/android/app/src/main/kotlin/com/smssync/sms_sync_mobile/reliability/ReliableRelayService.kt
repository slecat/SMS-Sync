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
import java.util.concurrent.TimeUnit

/** Small native foreground anchor. Flutter remains responsible for socket I/O. */
class ReliableRelayService : Service() {
    companion object {
        private const val TAG = "ReliableRelayService"
        private const val CHANNEL = "sms_sync_relay"
        private const val EXTRA_REASON = "reason"
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(889, Notification.Builder(this, CHANNEL)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("短信同步")
            .setContentText("可靠中继已运行")
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build())
        scheduleRecovery()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "relay service started: reason=${intent?.getStringExtra(EXTRA_REASON)}")
        scheduleRecovery()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

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
