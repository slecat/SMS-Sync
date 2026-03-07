package com.smssync.sms_sync_mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationSmsHeuristicsTest {
    @Test
    fun `extractCandidate accepts verification code notification`() {
        val actual = NotificationSmsHeuristics.extractCandidate(
            sourcePackage = "com.android.mms.service",
            selfPackage = "com.smssync.sms_sync_mobile",
            title = "鹰角网络",
            text = "【鹰角网络】验证码：830859。此验证码只用于鹰角账号登录使用。",
            bigText = null,
        )

        requireNotNull(actual)
        assertEquals("鹰角网络", actual.from)
        assertEquals("【鹰角网络】验证码：830859。此验证码只用于鹰角账号登录使用。", actual.body)
    }

    @Test
    fun `extractCandidate rejects self notification`() {
        val actual = NotificationSmsHeuristics.extractCandidate(
            sourcePackage = "com.smssync.sms_sync_mobile",
            selfPackage = "com.smssync.sms_sync_mobile",
            title = "短信同步",
            text = "正在后台同步短信",
            bigText = null,
        )

        assertNull(actual)
    }

    @Test
    fun `extractCandidate rejects unrelated notification`() {
        val actual = NotificationSmsHeuristics.extractCandidate(
            sourcePackage = "com.android.systemui",
            selfPackage = "com.smssync.sms_sync_mobile",
            title = "电量",
            text = "电量低于 20%",
            bigText = null,
        )

        assertNull(actual)
    }

    @Test
    fun `extractCandidate rejects verification text from non messaging package`() {
        val actual = NotificationSmsHeuristics.extractCandidate(
            sourcePackage = "com.evil.overlay",
            selfPackage = "com.smssync.sms_sync_mobile",
            title = "伪装通知",
            text = "验证码 123456",
            bigText = null,
        )

        assertNull(actual)
    }

    @Test
    fun `isTrustedSmsNotificationPackage accepts known messaging packages`() {
        assertTrue(
            NotificationSmsHeuristics.isTrustedSmsNotificationPackage(
                "com.android.mms.service",
            ),
        )
        assertTrue(
            NotificationSmsHeuristics.isTrustedSmsNotificationPackage(
                "com.google.android.apps.messaging",
            ),
        )
    }

    @Test
    fun `isTrustedSmsNotificationPackage rejects unknown package`() {
        assertFalse(
            NotificationSmsHeuristics.isTrustedSmsNotificationPackage(
                "com.getsurfboard",
            ),
        )
    }

    @Test
    fun `looksLikeVerificationSms requires keyword and digits`() {
        assertTrue(NotificationSmsHeuristics.looksLikeVerificationSms("验证码 123456"))
        assertFalse(NotificationSmsHeuristics.looksLikeVerificationSms("验证码已发送"))
        assertFalse(NotificationSmsHeuristics.looksLikeVerificationSms("订单号 123456"))
    }
}
