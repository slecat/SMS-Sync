package com.smssync.sms_sync_mobile.ingest

import android.content.Context
import com.smssync.sms_sync_mobile.NativeSmsRelay
import com.smssync.sms_sync_mobile.storage.OutboxDatabaseProvider
import com.smssync.sms_sync_mobile.storage.OutboxRepository
import com.smssync.sms_sync_mobile.storage.RoomOutboxStore

object NativeSmsIngestion {
    suspend fun persistAndRelay(
        context: Context,
        parts: List<SmsPart>,
        source: String,
    ): List<IngestedSms> {
        if (parts.isEmpty()) return emptyList()
        val dao = OutboxDatabaseProvider.get(context).outboxDao()
        val results = SmsIngestor(OutboxRepository(RoomOutboxStore(dao)))
            .ingestParts(parts, source)
        results.forEach { result ->
            result.message?.let { message ->
                NativeSmsRelay.deliver(
                    context = context,
                    from = message.from,
                    body = message.body,
                    timestamp = message.receivedAt,
                    source = source,
                )
            }
        }
        return results
    }
}
