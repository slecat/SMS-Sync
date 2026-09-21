package com.smssync.sms_sync_mobile

import id.flutter.flutter_background_service.WatchdogSchedulePolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WatchdogSchedulePolicyTest {
    @Test
    fun `nextCheckIntervalMillis uses low frequency watchdog`() {
        assertEquals(60_000, WatchdogSchedulePolicy.nextCheckIntervalMillis())
    }

    @Test
    fun `shouldSchedule returns true when service can be restored`() {
        assertTrue(
            WatchdogSchedulePolicy.shouldSchedule(
                false,
                1L,
            ),
        )
    }

    @Test
    fun `shouldSchedule returns false when service was manually stopped`() {
        assertFalse(
            WatchdogSchedulePolicy.shouldSchedule(
                true,
                1L,
            ),
        )
    }

    @Test
    fun `shouldSchedule returns false when background handle is missing`() {
        assertFalse(
            WatchdogSchedulePolicy.shouldSchedule(
                false,
                0L,
            ),
        )
    }
}
