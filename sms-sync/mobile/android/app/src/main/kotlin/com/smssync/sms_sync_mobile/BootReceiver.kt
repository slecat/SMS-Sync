package com.smssync.sms_sync_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import id.flutter.flutter_background_service.Config

class BootReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val shouldStart = action == Intent.ACTION_USER_UNLOCKED

        if (shouldStart) {
            val config = Config(context)
            val autoStart = config.isAutoStartOnBoot
            val manuallyStopped = config.isManuallyStopped
            val backgroundHandle = config.backgroundHandle

            if (!autoStart || manuallyStopped || backgroundHandle <= 0) {
                Log.d(
                    TAG,
                    "Skipped auto start: action=$action, autoStart=$autoStart, manuallyStopped=$manuallyStopped, handle=$backgroundHandle",
                )
                return
            }

            Log.d(TAG, "Auto start trigger received: $action")
            BackgroundServiceStarter.ensureRunning(context, "boot-event:$action")
        }
    }
}
