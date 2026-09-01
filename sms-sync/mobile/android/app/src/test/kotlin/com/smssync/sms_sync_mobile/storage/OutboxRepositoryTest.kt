package com.smssync.sms_sync_mobile.storage

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OutboxRepositoryTest {
    private val store = FakeOutboxStore()
    private val repository = OutboxRepository(store, nowMillis = { 1_000L })

    @Test
    fun `insert is idempotent for the same fingerprint`() = runBlocking {
        val first = repository.ingest(sampleSms("fp-1"))
        val second = repository.ingest(sampleSms("fp-1"))

        assertTrue(first.inserted)
        assertFalse(second.inserted)
        assertEquals(1, store.items.size)
    }

    @Test
    fun `expired send lease returns item to retry wait`() = runBlocking {
        val item = repository.ingest(sampleSms("fp-2")).message!!
        repository.claim(item.messageId, leaseUntil = 10L)
        repository.recoverExpiredLeases(now = 11L)

        assertEquals(OutboxState.RETRY_WAIT, store.items.single().state)
    }

    @Test
    fun `server acknowledgement is terminal and retry cannot resurrect it`() = runBlocking {
        val item = repository.ingest(sampleSms("fp-3")).message!!
        repository.claim(item.messageId, leaseUntil = 10_000L)
        assertTrue(repository.markServerAcked(item.messageId, ackedAt = 2_000L))
        assertFalse(repository.markRetry(item.messageId, nextAttemptAt = 3_000L, errorCode = "late"))
        assertEquals(OutboxState.SERVER_ACKED, store.items.single().state)
    }

    private fun sampleSms(fingerprint: String) = IncomingSms(
        messageId = "message-$fingerprint",
        fingerprint = fingerprint,
        from = "95588",
        body = "验证码 482913",
        receivedAt = 900L,
        capturedAt = 1_000L,
        source = "sms_receiver",
    )
}

private class FakeOutboxStore : OutboxStore {
    val items = mutableListOf<OutboxMessage>()

    override suspend fun findByFingerprint(fingerprint: String): OutboxMessage? =
        items.firstOrNull { it.fingerprint == fingerprint }

    override suspend fun insertIfAbsent(message: OutboxMessage): Boolean {
        if (items.any { it.fingerprint == message.fingerprint }) return false
        items += message
        return true
    }

    override suspend fun claim(messageId: String, leaseUntil: Long, now: Long): Boolean {
        val item = items.firstOrNull { it.messageId == messageId } ?: return false
        if (item.state != OutboxState.PENDING && item.state != OutboxState.RETRY_WAIT) return false
        item.state = OutboxState.SENDING
        item.leaseUntil = leaseUntil
        return true
    }

    override suspend fun recoverExpiredLeases(now: Long): Int {
        items.filter { it.state == OutboxState.SENDING && it.leaseUntil <= now }
            .forEach { it.state = OutboxState.RETRY_WAIT }
        return items.count { it.state == OutboxState.RETRY_WAIT }
    }

    override suspend fun findReady(now: Long, limit: Int): List<OutboxMessage> =
        items.filter { (it.state == OutboxState.PENDING || it.state == OutboxState.RETRY_WAIT) && it.nextAttemptAt <= now }.take(limit)

    override suspend fun markServerAcked(messageId: String, ackedAt: Long): Boolean {
        val item = items.firstOrNull { it.messageId == messageId } ?: return false
        item.state = OutboxState.SERVER_ACKED
        item.serverAckedAt = ackedAt
        return true
    }

    override suspend fun markRetry(messageId: String, nextAttemptAt: Long, errorCode: String?): Boolean =
        items.firstOrNull { it.messageId == messageId && it.state == OutboxState.SENDING }?.let {
            it.state = OutboxState.RETRY_WAIT
            it.nextAttemptAt = nextAttemptAt
            it.lastErrorCode = errorCode
            true
        } ?: false
}
