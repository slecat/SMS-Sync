package com.smssync.sms_sync_mobile

data class NotificationSmsCandidate(
    val from: String,
    val body: String,
)

object NotificationSmsHeuristics {
    private val trustedSmsNotificationPackages = setOf(
        "com.android.mms",
        "com.android.mms.service",
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
        "com.miui.mms",
        "com.miui.smsextra",
        "com.huawei.message",
        "com.coloros.mms",
        "com.oplus.mms",
        "com.oneplus.mms",
    )
    private val codeDigitsRegex = Regex("\\b\\d{4,8}\\b")
    private val verificationKeywordRegex = Regex(
        "验证码|校验码|动态码|驗證碼|verification code|verify code|otp|one-time password",
        RegexOption.IGNORE_CASE,
    )

    fun extractCandidate(
        sourcePackage: String,
        selfPackage: String,
        title: String?,
        text: String?,
        bigText: String?,
    ): NotificationSmsCandidate? {
        if (sourcePackage == selfPackage) {
            return null
        }

        if (!isTrustedSmsNotificationPackage(sourcePackage)) {
            return null
        }

        val resolvedBody = listOf(bigText, text)
            .mapNotNull { it?.trim()?.takeIf(String::isNotEmpty) }
            .firstOrNull()
            ?: return null

        if (!looksLikeVerificationSms(resolvedBody)) {
            return null
        }

        val resolvedFrom = title?.trim().takeUnless { it.isNullOrEmpty() } ?: sourcePackage
        return NotificationSmsCandidate(from = resolvedFrom, body = resolvedBody)
    }

    fun isTrustedSmsNotificationPackage(sourcePackage: String): Boolean {
        return trustedSmsNotificationPackages.contains(sourcePackage)
    }

    fun looksLikeVerificationSms(body: String): Boolean {
        if (!verificationKeywordRegex.containsMatchIn(body)) {
            return false
        }
        return codeDigitsRegex.containsMatchIn(body)
    }
}
