package com.smssync.sms_sync_mobile

import android.content.ContentUris
import android.content.Context
import android.database.ContentObserver
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log

class SmsObserver(
    private val context: Context,
    private val onSmsReceived: (String, String, Long) -> Unit
) : ContentObserver(Handler(Looper.getMainLooper())) {

    companion object {
        const val TAG = "SmsObserver"
        private var lastProcessedSignature: String? = null
    }

    override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)
        Log.d(TAG, "SMS database changed: $uri")

        Handler(Looper.getMainLooper()).postDelayed({
            checkSms(uri)
        }, 500)
    }

    private fun checkSms(changedUri: Uri?) {
        try {
            val changedSmsId = SmsObserverSelector.parseChangedSmsId(changedUri?.toString())
            val changedRecord = changedSmsId?.let { querySmsById(it) }
            val latestInboxRecord = queryLatestInboxSms()
            val selectedRecord = SmsObserverSelector.chooseRecord(
                changedSmsId = changedSmsId,
                changedRecord = changedRecord,
                latestInboxRecord = latestInboxRecord,
                inboxType = Telephony.Sms.MESSAGE_TYPE_INBOX,
            )

            if (selectedRecord == null) {
                Log.d(TAG, "No SMS record available to process")
                return
            }

            processSmsRecord(selectedRecord, changedSmsId)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking SMS: ${e.message}", e)
        }
    }

    private fun processSmsRecord(record: ObservedSmsRecord, changedSmsId: Long?) {
        val signature = "${record.id}|${record.date}|${record.from}|${record.body.hashCode()}"
        val isNewInbox = record.type == Telephony.Sms.MESSAGE_TYPE_INBOX
        val isNewSignature = signature != lastProcessedSignature

        Log.d(
            TAG,
            "SMS: ID=${record.id}, Date=${record.date}, Type=${record.type}, From=${record.from}, ChangedId=$changedSmsId",
        )
        Log.d(TAG, "Check - isNewInbox=$isNewInbox, isNewSignature=$isNewSignature")

        if (isNewInbox && isNewSignature) {
            lastProcessedSignature = signature
            Log.d(TAG, "Processing new SMS: From=${record.from}")
            onSmsReceived(record.from, record.body, record.date)
        } else {
            Log.d(TAG, "Skipping duplicate or old SMS")
        }
    }

    private fun querySmsById(smsId: Long): ObservedSmsRecord? {
        val smsUri = ContentUris.withAppendedId(Telephony.Sms.CONTENT_URI, smsId)
        return context.contentResolver.query(
            smsUri,
            projection,
            null,
            null,
            null,
        )?.use { cursor ->
            cursor.toObservedSmsRecord()
        }
    }

    private fun queryLatestInboxSms(): ObservedSmsRecord? {
        val selection = "${Telephony.Sms.TYPE} = ?"
        val selectionArgs = arrayOf(Telephony.Sms.MESSAGE_TYPE_INBOX.toString())
        val sortOrder = "${Telephony.Sms.DATE} DESC, ${Telephony.Sms._ID} DESC"

        return context.contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder,
        )?.use { cursor ->
            cursor.toObservedSmsRecord()
        }
    }

    private fun Cursor.toObservedSmsRecord(): ObservedSmsRecord? {
        if (!moveToFirst()) {
            return null
        }

        val idIndex = getColumnIndex(Telephony.Sms._ID)
        val addressIndex = getColumnIndex(Telephony.Sms.ADDRESS)
        val bodyIndex = getColumnIndex(Telephony.Sms.BODY)
        val typeIndex = getColumnIndex(Telephony.Sms.TYPE)
        val dateIndex = getColumnIndex(Telephony.Sms.DATE)

        if (
            idIndex < 0 ||
            addressIndex < 0 ||
            bodyIndex < 0 ||
            typeIndex < 0 ||
            dateIndex < 0
        ) {
            return null
        }

        return ObservedSmsRecord(
            id = getLong(idIndex),
            from = getString(addressIndex) ?: "unknown_sender",
            body = getString(bodyIndex) ?: "",
            type = getInt(typeIndex),
            date = getLong(dateIndex),
        )
    }

    private val projection = arrayOf(
        Telephony.Sms._ID,
        Telephony.Sms.ADDRESS,
        Telephony.Sms.BODY,
        Telephony.Sms.TYPE,
        Telephony.Sms.DATE,
    )
}
