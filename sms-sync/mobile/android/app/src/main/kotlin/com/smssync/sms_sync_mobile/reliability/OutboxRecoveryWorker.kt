package com.smssync.sms_sync_mobile.reliability

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.smssync.sms_sync_mobile.BackgroundServiceStarter
import com.smssync.sms_sync_mobile.storage.OutboxDatabaseProvider

class OutboxRecoveryWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val now = System.currentTimeMillis()
        val dao = OutboxDatabaseProvider.get(applicationContext).outboxDao()
        dao.recoverExpiredLeases(now)
        // Keep the durable queue bounded without ever deleting an unacknowledged
        // message. Seven days is long enough for a disconnected desktop to
        // catch up while preventing an unattended device from growing forever.
        dao.deleteAckedBefore(now - 7L * 24 * 60 * 60 * 1000)
        BackgroundServiceStarter.ensureRunning(applicationContext, "outbox-recovery")
        return Result.success()
    }
}
