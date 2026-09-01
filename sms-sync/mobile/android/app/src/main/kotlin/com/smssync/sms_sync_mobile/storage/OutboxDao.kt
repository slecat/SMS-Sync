package com.smssync.sms_sync_mobile.storage

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface OutboxDao {
    @Query("SELECT * FROM outbox_messages WHERE fingerprint = :fingerprint LIMIT 1")
    fun findEntityByFingerprint(fingerprint: String): OutboxMessageEntity?

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    fun insertMessage(message: OutboxMessageEntity): Long

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    fun insertFingerprint(fingerprint: IngestFingerprintEntity): Long

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
}
