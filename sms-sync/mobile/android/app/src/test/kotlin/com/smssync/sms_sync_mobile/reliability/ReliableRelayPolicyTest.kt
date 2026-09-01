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

    @Test
    fun a_live_connection_is_woken_for_new_outbox_items() {
        assertEquals(true, ReliableRelayPolicy.shouldDrainExistingConnection(hasLiveSocket = true))
        assertEquals(false, ReliableRelayPolicy.shouldDrainExistingConnection(hasLiveSocket = false))
    }
}
