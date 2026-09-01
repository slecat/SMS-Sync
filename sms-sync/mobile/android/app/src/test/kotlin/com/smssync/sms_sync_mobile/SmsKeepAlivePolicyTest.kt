package com.smssync.sms_sync_mobile

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SmsKeepAlivePolicyTest {
    @Test
    fun `isBootLikeAction accepts boot restore actions`() {
        assertTrue(SmsKeepAlivePolicy.isBootLikeAction("android.intent.action.BOOT_COMPLETED"))
        assertTrue(SmsKeepAlivePolicy.isBootLikeAction("android.intent.action.MY_PACKAGE_REPLACED"))
        assertTrue(SmsKeepAlivePolicy.isBootLikeAction("android.intent.action.QUICKBOOT_POWERON"))
        assertTrue(SmsKeepAlivePolicy.isBootLikeAction("android.intent.action.USER_UNLOCKED"))
    }

    @Test
    fun `isBootLikeAction rejects unrelated action`() {
        assertFalse(SmsKeepAlivePolicy.isBootLikeAction("android.intent.action.TIME_SET"))
        assertFalse(SmsKeepAlivePolicy.isBootLikeAction(null))
    }

    @Test
    fun `shouldRestore respects plugin config gates`() {
        assertTrue(
            SmsKeepAlivePolicy.shouldRestore(
                autoStartOnBoot = true,
                manuallyStopped = false,
                backgroundHandle = 1L,
            ),
        )
        assertFalse(
            SmsKeepAlivePolicy.shouldRestore(
                autoStartOnBoot = false,
                manuallyStopped = false,
                backgroundHandle = 1L,
            ),
        )
        assertFalse(
            SmsKeepAlivePolicy.shouldRestore(
                autoStartOnBoot = true,
                manuallyStopped = true,
                backgroundHandle = 1L,
            ),
        )
        assertFalse(
            SmsKeepAlivePolicy.shouldRestore(
                autoStartOnBoot = true,
                manuallyStopped = false,
                backgroundHandle = 0L,
            ),
        )
    }

    @Test
    fun `watchdog uses extreme keepalive cadence`() {
        assertTrue(SmsKeepAlivePolicy.watchdogDelayMillis() <= 15_000L)
    }

    @Test
    fun `shouldMaintainWatchdog only depends on manual stop and background handle`() {
        assertTrue(
            SmsKeepAlivePolicy.shouldMaintainWatchdog(
                manuallyStopped = false,
                backgroundHandle = 1L,
            ),
        )
        assertFalse(
            SmsKeepAlivePolicy.shouldMaintainWatchdog(
                manuallyStopped = true,
                backgroundHandle = 1L,
            ),
        )
        assertFalse(
            SmsKeepAlivePolicy.shouldMaintainWatchdog(
                manuallyStopped = false,
                backgroundHandle = 0L,
            ),
        )
    }
}
