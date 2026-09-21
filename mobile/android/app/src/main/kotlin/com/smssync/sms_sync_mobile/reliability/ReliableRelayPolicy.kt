package com.smssync.sms_sync_mobile.reliability

object ReliableRelayPolicy {
    private val retrySchedule = longArrayOf(2_000, 5_000, 15_000, 60_000, 300_000, 900_000)
    fun retryDelayMillis(attempt: Int): Long = retrySchedule.getOrElse((attempt - 1).coerceAtLeast(0)) { 1_800_000L }
    fun shouldRestart(startId: Int): Boolean = startId != 0
    fun shouldDrainExistingConnection(hasLiveSocket: Boolean): Boolean = hasLiveSocket
}
