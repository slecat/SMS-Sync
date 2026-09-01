package com.smssync.sms_sync_mobile.reliability

import org.junit.Assert.assertEquals
import org.junit.Test

class ReliableRelayPolicyTest {
    @Test
    fun restartUsesStickyServiceAndBackoffIsCapped() {
        assertEquals(2_000L, ReliableRelayPolicy.retryDelayMillis(1))
        assertEquals(900_000L, ReliableRelayPolicy.retryDelayMillis(6))
        assertEquals(1_800_000L, ReliableRelayPolicy.retryDelayMillis(99))
        assertEquals(true, ReliableRelayPolicy.shouldRestart(startId = 3))
    }
}
