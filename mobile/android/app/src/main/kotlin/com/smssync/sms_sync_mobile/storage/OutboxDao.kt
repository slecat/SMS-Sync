package com.smssync.sms_sync_mobile.storage

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface OutboxDao {
    @Query("SELECT COUNT(*) FROM outbox_messages WHERE state = :state")
    fun countByState(state: String): Int

    @Query("SELECT MAX(serverAckedAt) FROM outbox_messages WHERE state = 'SERVER_ACKED'")
    fun latestServerAckAt(): Long?

    @Query("SELECT MIN(capturedAt) FROM outbox_messages WHERE state IN ('PENDING', 'SENDING', 'RETRY_WAIT')")
    fun oldestPendingAt(): Long?

    @Query("SELECT lastErrorCode FROM outbox_messages WHERE lastErrorCode IS NOT NULL ORDER BY capturedAt DESC LIMIT 1")
    fun latestErrorCode(): String?

    @Query("DELETE FROM outbox_messages WHERE state = 'SERVER_ACKED' AND serverAckedAt IS NOT NULL AND serverAckedAt < :before")
    fun deleteAckedBefore(before: Long): Int

    @Query("SELECT * FROM outbox_messages WHERE state IN ('PENDING', 'RETRY_WAIT') AND nextAttemptAt <= :now ORDER BY capturedAt ASC LIMIT :limit")
    fun findReady(now: Long, limit: Int): List<OutboxMessageEntity>
    @Query("SELECT * FROM outbox_messages WHERE fingerprint = :fingerprint LIMIT 1")
    fun findEntityByFingerprint(fingerprint: String): OutboxMessageEntity?

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    fun insertMessage(message: OutboxMessageEntity): Long

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    fun insertFingerprint(fingerprint: IngestFingerprintEntity): Long

    @Transaction
    fun insertBundle(message: OutboxMessageEntity): Boolean {
        if (insertMessage(message) == -1L) return false
        insertFingerprint(
            IngestFingerprintEntity(
                fingerprint = message.fingerprint,
                messageId = message.messageId,
                createdAt = message.capturedAt,
            ),
        )
        return true
    }

    @Query("SELECT * FROM outbox_messages WHERE messageId = :messageId LIMIT 1")
    fun findEntity(messageId: String): OutboxMessageEntity?

    @Query(
        "UPDATE outbox_messages SET state = 'SENDING', leaseUntil = :leaseUntil, " +
            "attemptCount = attemptCount + 1 WHERE messageId = :messageId " +
            "AND state IN ('PENDING', 'RETRY_WAIT') AND leaseUntil <= :now",
    )
    fun claim(messageId: String, leaseUntil: Long, now: Long): Int

    @Query(
        "UPDATE outbox_messages SET state = 'RETRY_WAIT', leaseUntil = 0 " +
            "WHERE state = 'SENDING' AND leaseUntil <= :now",
    )
    fun recoverExpiredLeases(now: Long): Int

    @Query("UPDATE outbox_messages SET state = 'SERVER_ACKED', leaseUntil = 0, serverAckedAt = :ackedAt WHERE messageId = :messageId")
    fun markServerAcked(messageId: String, ackedAt: Long): Int

    @Query("UPDATE outbox_messages SET state = 'RETRY_WAIT', leaseUntil = 0, nextAttemptAt = :nextAttemptAt, lastErrorCode = :errorCode WHERE messageId = :messageId AND state = 'SENDING'")
    fun markRetry(messageId: String, nextAttemptAt: Long, errorCode: String?): Int
}
