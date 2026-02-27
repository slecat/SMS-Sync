package com.smssync.sms_sync_mobile

import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.content.Context
import android.util.Log

class SmsObserver(
    private val context: Context,
    private val onSmsReceived: (String, String) -> Unit
) : ContentObserver(Handler(Looper.getMainLooper())) {

    companion object {
        const val TAG = "SmsObserver"
        private var lastSmsId = -1L
        private var lastProcessTime = 0L
        private const val MIN_INTERVAL = 2000L
    }

    override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)
        Log.d(TAG, "SMS database changed: $uri")
        
        Handler(Looper.getMainLooper()).postDelayed({
            checkSms()
        }, 500)
    }

    private fun checkSms() {
        try {
            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.TYPE,
                Telephony.Sms.DATE
            )
            
            val sortOrder = "${Telephony.Sms._ID} DESC LIMIT 1"
            
            val cursor = context.contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )
            
            cursor?.use {
                if (it.moveToFirst()) {
                    val idIndex = it.getColumnIndex(Telephony.Sms._ID)
                    val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
                    val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
                    val typeIndex = it.getColumnIndex(Telephony.Sms.TYPE)
                    
                    if (idIndex >= 0 && addressIndex >= 0 && bodyIndex >= 0 && typeIndex >= 0) {
                        val smsId = it.getLong(idIndex)
                        val from = it.getString(addressIndex)
                        val body = it.getString(bodyIndex)
                        val type = it.getInt(typeIndex)
                        val currentTime = System.currentTimeMillis()
                        
                        Log.d(TAG, "SMS: ID=$smsId, Type=$type, From=$from")
                        
                        val isNewInbox = type == Telephony.Sms.MESSAGE_TYPE_INBOX
                        val isNewId = smsId != lastSmsId
                        val isRecentTime = (currentTime - lastProcessTime) > MIN_INTERVAL
                        
                        Log.d(TAG, "Check - isNewInbox=$isNewInbox, isNewId=$isNewId, isRecentTime=$isRecentTime")
                        
                        if (isNewInbox && isNewId && isRecentTime) {
                            lastSmsId = smsId
                            lastProcessTime = currentTime
                            Log.d(TAG, "Processing new SMS: From=$from")
                            onSmsReceived(from, body)
                        } else {
                            Log.d(TAG, "Skipping duplicate or old SMS")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking SMS: ${e.message}", e)
        }
    }
}
