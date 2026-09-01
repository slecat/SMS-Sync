package com.smssync.sms_sync_mobile

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.smssync.sms_sync_mobile.ingest.NativeSmsIngestion
import com.smssync.sms_sync_mobile.ingest.SmsPart
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class SmsNotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "SmsNotifListener"
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification listener connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Notification listener disconnected, requesting rebind")
        SmsKeepAliveHelper.requestNotificationListenerRebind(
            applicationContext,
            "listener-disconnected",
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) {
            return
        }

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return
        val sourcePackage = sbn.packageName ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()

        val candidate = NotificationSmsHeuristics.extractCandidate(
            sourcePackage = sourcePackage,
            selfPackage = packageName,
            title = title,
            text = text,
            bigText = bigText,
        )

        if (candidate == null) {
            if (!text.isNullOrBlank() || !bigText.isNullOrBlank()) {
                Log.d(
                    TAG,
                    "Ignored notification pkg=$sourcePackage, title=${title ?: ""}, text=${preview(text ?: bigText ?: "")}",
                )
            }
            return
        }

        val timestamp = sbn.postTime.takeIf { it > 0 }
            ?: System.currentTimeMillis()
        Log.d(
            TAG,
            "Accepted notification SMS pkg=$sourcePackage, from=${candidate.from}, body=${preview(candidate.body)}",
        )
        CoroutineScope(Dispatchers.IO).launch {
            runCatching {
                NativeSmsIngestion.persistAndRelay(
                    context = applicationContext,
                    parts = listOf(
                        SmsPart(
                            from = candidate.from,
                            body = candidate.body,
                            receivedAt = timestamp,
                            sequence = 0,
                        ),
                    ),
                    source = "notification-listener",
                )
            }.onFailure { error -> Log.e(TAG, "Failed to persist notification SMS", error) }
        }
    }

    private fun preview(value: String): String {
        val normalized = value.replace('\n', ' ').trim()
        return if (normalized.length <= 60) normalized else normalized.substring(0, 60) + "..."
    }
}
