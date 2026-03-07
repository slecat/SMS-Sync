package com.smssync.sms_sync_mobile

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class SmsNotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "SmsNotifListener"
        private var lastSignature: String? = null
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
        val signature = "$sourcePackage|${candidate.from}|${candidate.body.hashCode()}"
        if (signature == lastSignature) {
            Log.d(TAG, "Skipped duplicate notification candidate from $sourcePackage")
            return
        }
        lastSignature = signature

        Log.d(
            TAG,
            "Accepted notification SMS pkg=$sourcePackage, from=${candidate.from}, body=${preview(candidate.body)}",
        )
        NativeSmsRelay.deliver(
            context = applicationContext,
            from = candidate.from,
            body = candidate.body,
            timestamp = timestamp,
            source = "notification-listener",
        )
    }

    private fun preview(value: String): String {
        val normalized = value.replace('\n', ' ').trim()
        return if (normalized.length <= 60) normalized else normalized.substring(0, 60) + "..."
    }
}
