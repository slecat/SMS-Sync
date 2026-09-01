package com.smssync.sms_sync_mobile.ingest

import com.smssync.sms_sync_mobile.storage.IncomingSms
import com.smssync.sms_sync_mobile.storage.OutboxMessage
import com.smssync.sms_sync_mobile.storage.OutboxRepository
import com.smssync.sms_sync_mobile.storage.OutboxState
import com.smssync.sms_sync_mobile.storage.OutboxStore
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SmsIngestorTest {
    private val store = FakeStore()
    private val repository = OutboxRepository(store, nowMillis = { 2_000L })
    private val ingestor = SmsIngestor(repository, nowMillis = { 2_000L })

    @Test
    fun `multipart parts become one outbox message`() = runBlocking {
        val result = ingestor.ingestParts(
            parts = listOf(
                SmsPart("95588", "验证码 482", 1_000L, sequence = 1),
                SmsPart("95588", "913，请勿泄露", 1_000L, sequence = 2),
            ),
            source = "sms_receiver",
        )

        assertEquals(1, result.size)
        assertEquals("验证码 482913，请勿泄露", result.single().body)
    }

    @Test
    fun `notification candidate matching a recent sms is ignored`() = runBlocking {
        ingestor.ingestParts(
            listOf(SmsPart("95588", "验证码 482913", 1_000L, sequence = 1)),
            source = "sms_receiver",
        )
        val result = ingestor.ingestParts(
            listOf(SmsPart("95588", "验证码 482913", 1_005L, sequence = 1)),
            source = "notification_listener",
        )

        assertTrue(result.single().isDuplicate)
        assertEquals(1, store.items.size)
    }
}

private class FakeStore : OutboxStore {
    val items = mutableListOf<OutboxMessage>()

    override suspend fun findByFingerprint(fingerprint: String): OutboxMessage? =
        items.firstOrNull { it.fingerprint == fingerprint }

    override suspend fun insertIfAbsent(message: OutboxMessage): Boolean {
        if (items.any { it.fingerprint == message.fingerprint }) return false
        items += message
        return true
    }

    override suspend fun claim(messageId: String, leaseUntil: Long, now: Long) = false

    override suspend fun recoverExpiredLeases(now: Long) = 0

    override suspend fun findReady(now: Long, limit: Int): List<OutboxMessage> = emptyList()

    override suspend fun markServerAcked(messageId: String, ackedAt: Long): Boolean = false

    override suspend fun markRetry(messageId: String, nextAttemptAt: Long, errorCode: String?): Boolean = false
}
