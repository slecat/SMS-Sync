package com.smssync.sms_sync_mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

object AppUpdateInstaller {
    private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    private const val INSTALLER_FLAGS =
        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK

    fun buildInstallIntent(contentUri: Uri): Intent {
        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(contentUri, APK_MIME_TYPE)
        intent.addFlags(INSTALLER_FLAGS)
        return intent
    }

    fun buildInstallIntentSpec(contentUriString: String): IntentSpec {
        return IntentSpec(
            action = Intent.ACTION_VIEW,
            dataUriString = contentUriString,
            mimeType = APK_MIME_TYPE,
            flags = INSTALLER_FLAGS,
        )
    }

    fun requiresInstallPermission(
        sdkInt: Int = Build.VERSION.SDK_INT,
        canRequestPackageInstalls: Boolean,
    ): Boolean {
        return sdkInt >= Build.VERSION_CODES.O && !canRequestPackageInstalls
    }

    fun buildManageUnknownAppSourcesIntent(packageName: String): Intent {
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
        intent.data = Uri.parse(buildManageUnknownAppSourcesUriString(packageName))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return intent
    }

    fun buildManageUnknownAppSourcesUriString(packageName: String): String {
        return "package:$packageName"
    }

    fun buildManageUnknownAppSourcesIntentSpec(packageName: String): IntentSpec {
        return IntentSpec(
            action = Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            dataUriString = buildManageUnknownAppSourcesUriString(packageName),
            mimeType = null,
            flags = Intent.FLAG_ACTIVITY_NEW_TASK,
        )
    }

    fun resolveContentUri(
        context: Context,
        filePath: String,
        authority: String = "${context.packageName}.fileprovider",
    ): Uri {
        return FileProvider.getUriForFile(context, authority, File(filePath))
    }
}

data class IntentSpec(
    val action: String,
    val dataUriString: String?,
    val mimeType: String?,
    val flags: Int,
)
