package com.smssync.sms_sync_mobile.storage

interface OutboxStore {
    suspend fun findByFingerprint(fingerprint: String): OutboxMessage?
    suspend fun insertIfAbsent(message: OutboxMessage): Boolean
    suspend fun claim(messageId: String, leaseUntil: Long, now: Long): Boolean
    suspend fun recoverExpiredLeases(now: Long): Int
    suspend fun findReady(now: Long, limit: Int = 50): List<OutboxMessage>
    suspend fun markServerAcked(messageId: String, ackedAt: Long): Boolean
    suspend fun markRetry(messageId: String, nextAttemptAt: Long, errorCode: String?): Boolean
}

data class IngestResult(
    val inserted: Boolean,
    val message: OutboxMessage?,
)

class OutboxRepository(
    private val store: OutboxStore,
    private val nowMillis: () -> Long = { System.currentTimeMillis() },
) {
    suspend fun ingest(input: IncomingSms): IngestResult {
        val existing = store.findByFingerprint(input.fingerprint)
        if (existing != null) return IngestResult(inserted = false, message = existing)

        val message = OutboxMessage(
            messageId = input.messageId,
            fingerprint = input.fingerprint,
            from = input.from,
            body = input.body,
            receivedAt = input.receivedAt,
            capturedAt = input.capturedAt,
            source = input.source,
        )
        val inserted = store.insertIfAbsent(message)
        return if (inserted) {
            IngestResult(inserted = true, message = message)
        } else {
            IngestResult(inserted = false, message = store.findByFingerprint(input.fingerprint))
        }
    }

    suspend fun claim(messageId: String, leaseUntil: Long): Boolean =
        store.claim(messageId, leaseUntil, nowMillis())

    suspend fun recoverExpiredLeases(now: Long = nowMillis()): Int =
        store.recoverExpiredLeases(now)

    suspend fun findReady(limit: Int = 50): List<OutboxMessage> = store.findReady(nowMillis(), limit)
    suspend fun markServerAcked(messageId: String, ackedAt: Long = nowMillis()): Boolean = store.markServerAcked(messageId, ackedAt)
    suspend fun markRetry(messageId: String, nextAttemptAt: Long, errorCode: String?): Boolean = store.markRetry(messageId, nextAttemptAt, errorCode)
}

class RoomOutboxStore(private val dao: OutboxDao) : OutboxStore {
    override suspend fun findByFingerprint(fingerprint: String): OutboxMessage? =
        dao.findEntityByFingerprint(fingerprint)?.toDomain()

    override suspend fun insertIfAbsent(message: OutboxMessage): Boolean {
        return dao.insertBundle(message.toEntity())
    }

    override suspend fun claim(messageId: String, leaseUntil: Long, now: Long): Boolean =
        dao.claim(messageId, leaseUntil, now) > 0

    override suspend fun recoverExpiredLeases(now: Long): Int = dao.recoverExpiredLeases(now)
    override suspend fun findReady(now: Long, limit: Int): List<OutboxMessage> = dao.findReady(now, limit).map { it.toDomain() }
    override suspend fun markServerAcked(messageId: String, ackedAt: Long): Boolean = dao.markServerAcked(messageId, ackedAt) > 0
    override suspend fun markRetry(messageId: String, nextAttemptAt: Long, errorCode: String?): Boolean = dao.markRetry(messageId, nextAttemptAt, errorCode) > 0
}

private fun OutboxMessage.toEntity() = OutboxMessageEntity(
    messageId = messageId,
    fingerprint = fingerprint,
    fromAddress = from,
    body = body,
    receivedAt = receivedAt,
    capturedAt = capturedAt,
    source = source,
    state = state.name,
    attemptCount = attemptCount,
    nextAttemptAt = nextAttemptAt,
    leaseUntil = leaseUntil,
    lastErrorCode = lastErrorCode,
    serverAckedAt = serverAckedAt,
)

private fun OutboxMessageEntity.toDomain() = OutboxMessage(
    messageId = messageId,
    fingerprint = fingerprint,
    from = fromAddress,
    body = body,
    receivedAt = receivedAt,
    capturedAt = capturedAt,
    source = source,
    state = runCatching { OutboxState.valueOf(state) }.getOrDefault(OutboxState.BLOCKED),
    attemptCount = attemptCount,
    nextAttemptAt = nextAttemptAt,
    leaseUntil = leaseUntil,
    lastErrorCode = lastErrorCode,
    serverAckedAt = serverAckedAt,
)
