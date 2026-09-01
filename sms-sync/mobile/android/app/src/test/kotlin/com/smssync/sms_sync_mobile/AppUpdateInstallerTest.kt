package com.smssync.sms_sync_mobile

import android.content.Intent
import android.provider.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppUpdateInstallerTest {
    @Test
    fun `buildInstallIntentSpec configures package installer launch`() {
        val spec = AppUpdateInstaller.buildInstallIntentSpec(
            "content://com.smssync.sms_sync_mobile.fileprovider/update.apk",
        )

        assertEquals(Intent.ACTION_VIEW, spec.action)
        assertEquals("application/vnd.android.package-archive", spec.mimeType)
        assertEquals(
            "content://com.smssync.sms_sync_mobile.fileprovider/update.apk",
            spec.dataUriString,
        )
        assertTrue(spec.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
        assertTrue(spec.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }

    @Test
    fun `requiresInstallPermission only blocks on Android O and above without permission`() {
        assertFalse(
            AppUpdateInstaller.requiresInstallPermission(
                sdkInt = 25,
                canRequestPackageInstalls = false,
            ),
        )
        assertFalse(
            AppUpdateInstaller.requiresInstallPermission(
                sdkInt = 30,
                canRequestPackageInstalls = true,
            ),
        )
        assertTrue(
            AppUpdateInstaller.requiresInstallPermission(
                sdkInt = 30,
                canRequestPackageInstalls = false,
            ),
        )
    }

    @Test
    fun `buildManageUnknownAppSourcesIntentSpec opens per app settings`() {
        val spec = AppUpdateInstaller.buildManageUnknownAppSourcesIntentSpec(
            packageName = "com.smssync.sms_sync_mobile",
        )

        assertEquals(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, spec.action)
        assertEquals("package:com.smssync.sms_sync_mobile", spec.dataUriString)
        assertTrue(spec.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
    }
}
