package com.smssync.sms_sync_mobile.storage

import androidx.room.Database
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.RoomDatabase

enum class OutboxState {
    PENDING,
    SENDING,
    RETRY_WAIT,
    SERVER_ACKED,
    BLOCKED,
}

data class IncomingSms(
    val messageId: String,
    val fingerprint: String,
    val from: String,
    val body: String,
    val receivedAt: Long,
    val capturedAt: Long,
    val source: String,
)

data class OutboxMessage(
    val messageId: String,
    val fingerprint: String,
    val from: String,
    val body: String,
    val receivedAt: Long,
    val capturedAt: Long,
    val source: String,
    var state: OutboxState = OutboxState.PENDING,
    var attemptCount: Int = 0,
    var nextAttemptAt: Long = 0L,
    var leaseUntil: Long = 0L,
    var lastErrorCode: String? = null,
    var serverAckedAt: Long? = null,
)

@Entity(
    tableName = "outbox_messages",
    indices = [
        Index(value = ["fingerprint"], unique = true),
        Index(value = ["state", "nextAttemptAt"]),
    ],
)
data class OutboxMessageEntity(
    @PrimaryKey val messageId: String,
    val fingerprint: String,
    val fromAddress: String,
    val body: String,
    val receivedAt: Long,
    val capturedAt: Long,
    val source: String,
    val state: String,
    val attemptCount: Int,
    val nextAttemptAt: Long,
    val leaseUntil: Long,
    val lastErrorCode: String?,
    val serverAckedAt: Long?,
)

@Entity(
    tableName = "ingest_fingerprints",
    indices = [Index(value = ["fingerprint"], unique = true)],
)
data class IngestFingerprintEntity(
    @PrimaryKey val fingerprint: String,
    val messageId: String,
    val createdAt: Long,
)

@Database(
    entities = [OutboxMessageEntity::class, IngestFingerprintEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class OutboxDatabase : RoomDatabase() {
    abstract fun outboxDao(): OutboxDao
}
