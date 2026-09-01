package com.smssync.sms_sync_mobile

import android.content.Context

data class NativeRelayConfig(
    val serverUrl: String,
    val groupId: String,
    val deviceName: String,
    val syncSecret: String,
)

class NativeConfigStore(private val context: Context) {
    fun read(): NativeRelayConfig {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return parse(prefs.all)
    }

    companion object {
        private const val PREFS = "FlutterSharedPreferences"
        fun parse(values: Map<String, Any?>): NativeRelayConfig {
            fun value(name: String, fallback: String): String =
                values["flutter.$name"]?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                    ?: values[name]?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                    ?: fallback
            return NativeRelayConfig(
                serverUrl = value("serverUrl", ""),
                groupId = value("groupId", "default"),
                deviceName = value("deviceName", "手机端"),
                syncSecret = value("syncSecret", ""),
            )
        }
    }
}
