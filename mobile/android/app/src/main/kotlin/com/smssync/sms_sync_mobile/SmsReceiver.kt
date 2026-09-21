package com.smssync.sms_sync_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage
import android.util.Log
import com.smssync.sms_sync_mobile.ingest.SmsIngestor
import com.smssync.sms_sync_mobile.ingest.NativeSmsIngestion
import com.smssync.sms_sync_mobile.ingest.SmsPart
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Receives system SMS and persists it before handing it to Flutter. */
class SmsReceiver : BroadcastReceiver() {
    companion object { const val TAG = "SmsReceiver" }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return
        val pendingResult = goAsync()
        val appContext = context.applicationContext
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val parts = parseParts(intent)
                if (parts.isEmpty()) return@launch
                val results = NativeSmsIngestion.persistAndRelay(appContext, parts, "sms-receiver")
                Log.d(TAG, "SMS persisted: count=${results.size}, duplicates=${results.count { it.isDuplicate }}, parts=${parts.size}")
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to persist incoming SMS", error)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun parseParts(intent: Intent): List<SmsPart> {
        val extras = intent.extras ?: return emptyList()
        val pdus = extras.get("pdus") as? Array<*> ?: return emptyList()
        val format = extras.getString("format") ?: "3gpp"
        return pdus.mapIndexedNotNull { index, rawPdu ->
            runCatching {
                val message = SmsMessage.createFromPdu(rawPdu as ByteArray, format)
                val from = message.originatingAddress ?: return@runCatching null
                val body = message.messageBody ?: return@runCatching null
                SmsPart(from, body, message.timestampMillis, index)
            }.getOrNull()
        }
    }
}
