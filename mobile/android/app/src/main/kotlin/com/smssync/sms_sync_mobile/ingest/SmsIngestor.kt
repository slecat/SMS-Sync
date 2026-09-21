package com.smssync.sms_sync_mobile.ingest

import com.smssync.sms_sync_mobile.storage.IncomingSms
import com.smssync.sms_sync_mobile.storage.OutboxMessage
import com.smssync.sms_sync_mobile.storage.OutboxRepository
import java.util.UUID

data class SmsPart(
    val from: String,
    val body: String,
    val receivedAt: Long,
    val sequence: Int,
)

data class IngestedSms(
    val messageId: String,
    val body: String,
    val isDuplicate: Boolean,
    val message: OutboxMessage?,
)

class SmsIngestor(
    private val repository: OutboxRepository,
    private val nowMillis: () -> Long = { System.currentTimeMillis() },
) {
    suspend fun ingestParts(parts: List<SmsPart>, source: String): List<IngestedSms> {
        if (parts.isEmpty()) return emptyList()

        return parts.groupBy { part ->
            val normalizedFrom = part.from.trim().lowercase()
            "$normalizedFrom:${part.receivedAt / FINGERPRINT_TIME_BUCKET_MS}"
        }.values.map { group ->
            val ordered = group.sortedBy { it.sequence }
            val from = ordered.first().from.trim()
            val body = ordered.joinToString(separator = "") { normalizeBody(it.body) }
            val receivedAt = ordered.minOf { it.receivedAt }
            val fingerprint = fingerprint(from, body, receivedAt)
            val result = repository.ingest(
                IncomingSms(
                    messageId = UUID.randomUUID().toString(),
                    fingerprint = fingerprint,
                    from = from,
                    body = body,
                    receivedAt = receivedAt,
                    capturedAt = nowMillis(),
                    source = source,
                ),
            )
            IngestedSms(
                messageId = result.message?.messageId ?: "",
                body = result.message?.body ?: body,
                isDuplicate = !result.inserted,
                message = result.message,
            )
        }
    }

    private fun fingerprint(from: String, body: String, receivedAt: Long): String {
        val normalizedFrom = from.trim().lowercase()
        val normalizedBody = normalizeBody(body)
        return "$normalizedFrom|$normalizedBody|${receivedAt / FINGERPRINT_TIME_BUCKET_MS}"
    }

    private fun normalizeBody(body: String): String =
        body.replace("\r\n", "\n").replace('\r', '\n').trim()

    private companion object {
        const val FINGERPRINT_TIME_BUCKET_MS = 30_000L
    }
}
