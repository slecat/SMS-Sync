package com.smssync.sms_sync_mobile

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationListenerSupportTest {
    private val componentName =
        "com.smssync.sms_sync_mobile/com.smssync.sms_sync_mobile.SmsNotificationListenerService"

    @Test
    fun `isComponentEnabled matches exact component in enabled list`() {
        assertTrue(
            NotificationListenerSupport.isComponentEnabled(
                enabledListeners = componentName,
                componentName = componentName,
            ),
        )
    }

    @Test
    fun `isComponentEnabled matches component inside multi value setting`() {
        assertTrue(
            NotificationListenerSupport.isComponentEnabled(
                enabledListeners = "pkg.one/.Listener:$componentName:pkg.two/.Listener",
                componentName = componentName,
            ),
        )
    }

    @Test
    fun `isComponentEnabled ignores case and rejects missing component`() {
        assertTrue(
            NotificationListenerSupport.isComponentEnabled(
                enabledListeners = componentName.uppercase(),
                componentName = componentName,
            ),
        )
        assertFalse(
            NotificationListenerSupport.isComponentEnabled(
                enabledListeners = "pkg.one/.Listener:pkg.two/.Listener",
                componentName = componentName,
            ),
        )
    }

    @Test
    fun `shouldRequestRebind requires android n and enabled listener`() {
        assertFalse(
            NotificationListenerSupport.shouldRequestRebind(
                sdkInt = 23,
                enabledListeners = componentName,
                componentName = componentName,
            ),
        )
        assertFalse(
            NotificationListenerSupport.shouldRequestRebind(
                sdkInt = 24,
                enabledListeners = null,
                componentName = componentName,
            ),
        )
        assertTrue(
            NotificationListenerSupport.shouldRequestRebind(
                sdkInt = 24,
                enabledListeners = componentName,
                componentName = componentName,
            ),
        )
    }
}
