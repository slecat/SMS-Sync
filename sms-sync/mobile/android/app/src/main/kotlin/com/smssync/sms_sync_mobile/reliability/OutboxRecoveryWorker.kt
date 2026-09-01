package com.smssync.sms_sync_mobile.reliability

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.smssync.sms_sync_mobile.BackgroundServiceStarter
import com.smssync.sms_sync_mobile.storage.OutboxDatabaseProvider

class OutboxRecoveryWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        OutboxDatabaseProvider.get(applicationContext).outboxDao().recoverExpiredLeases(System.currentTimeMillis())
        BackgroundServiceStarter.ensureRunning(applicationContext, "outbox-recovery")
        return Result.success()
    }
}
