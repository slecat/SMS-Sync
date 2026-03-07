package com.smssync.sms_sync_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive called with action: ${intent.action}")

        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") {
            Log.d(TAG, "Ignoring unsupported SMS action: ${intent.action}")
            return
        }

        Log.d(TAG, "Incoming SMS action accepted: ${intent.action}")

        val bundle = intent.extras
        if (bundle == null) {
            Log.d(TAG, "Bundle is null")
            return
        }

        val pdus = bundle.get("pdus") as? Array<*>
        val format = bundle.getString("format") ?: "3gpp"

        Log.d(TAG, "Number of PDUs: ${pdus?.size}")
        Log.d(TAG, "Format: $format")

        pdus?.forEachIndexed { index, pdu ->
            try {
                Log.d(TAG, "Processing PDU $index")
                val message = SmsMessage.createFromPdu(pdu as ByteArray, format)
                val from = message?.originatingAddress
                val body = message?.messageBody

                Log.d(TAG, "From: $from")
                Log.d(TAG, "Body: $body")

                if (from != null && body != null) {
                    NativeSmsRelay.deliver(
                        context = context,
                        from = from,
                        body = body,
                        timestamp = message.timestampMillis,
                        source = "sms-receiver",
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing SMS PDU $index: ${e.message}", e)
            }
        }
    }
}
