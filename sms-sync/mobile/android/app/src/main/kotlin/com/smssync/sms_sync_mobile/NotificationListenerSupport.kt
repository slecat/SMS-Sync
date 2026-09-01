package com.smssync.sms_sync_mobile

import android.os.Build

object NotificationListenerSupport {
    fun isComponentEnabled(enabledListeners: String?, componentName: String): Boolean {
        if (enabledListeners.isNullOrBlank()) {
            return false
        }

        return enabledListeners
            .split(':')
            .any { it.equals(componentName, ignoreCase = true) }
    }

    fun shouldRequestRebind(
        sdkInt: Int = Build.VERSION.SDK_INT,
        enabledListeners: String?,
        componentName: String,
    ): Boolean {
        return sdkInt >= Build.VERSION_CODES.N &&
            isComponentEnabled(enabledListeners, componentName)
    }
}
