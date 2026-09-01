package com.smssync.sms_sync_mobile

import android.content.Intent

object SmsKeepAlivePolicy {
    private const val QUICKBOOT_POWERON = "android.intent.action.QUICKBOOT_POWERON"
    private const val WATCHDOG_DELAY_MS = 15_000L

    fun isBootLikeAction(action: String?): Boolean {
        return action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == QUICKBOOT_POWERON ||
            action == Intent.ACTION_USER_UNLOCKED
    }

    fun shouldRestore(
        autoStartOnBoot: Boolean,
        manuallyStopped: Boolean,
        backgroundHandle: Long,
    ): Boolean {
        return autoStartOnBoot && !manuallyStopped && backgroundHandle > 0
    }

    fun shouldMaintainWatchdog(
        manuallyStopped: Boolean,
        backgroundHandle: Long,
    ): Boolean {
        return !manuallyStopped && backgroundHandle > 0
    }

    fun watchdogDelayMillis(): Long = WATCHDOG_DELAY_MS
}
