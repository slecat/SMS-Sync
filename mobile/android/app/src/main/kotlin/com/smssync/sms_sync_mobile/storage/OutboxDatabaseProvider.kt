package com.smssync.sms_sync_mobile.storage

import android.content.Context
import androidx.room.Room

object OutboxDatabaseProvider {
    @Volatile
    private var instance: OutboxDatabase? = null

    fun get(context: Context): OutboxDatabase =
        instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(
                context.applicationContext,
                OutboxDatabase::class.java,
                "sms-sync-outbox.db",
            ).build().also { instance = it }
        }
}
