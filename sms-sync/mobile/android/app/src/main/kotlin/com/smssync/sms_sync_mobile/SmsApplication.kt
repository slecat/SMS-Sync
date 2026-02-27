package com.smssync.sms_sync_mobile

import android.app.Application
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class SmsApplication : Application() {
    companion object {
        const val CHANNEL = "sms_sync_channel"
        const val TAG = "SmsApplication"
        var methodChannel: MethodChannel? = null
        var instance: SmsApplication? = null
            private set
        
        private var flutterEngine: FlutterEngine? = null
        
        fun getContext(): Context? {
            return instance?.applicationContext
        }
        
        fun sendSmsToBackground(from: String, body: String, timestamp: Long) {
            Log.d(TAG, "sendSmsToBackground called: From=$from")
            
            if (methodChannel != null) {
                try {
                    val smsData = mapOf(
                        "from" to from,
                        "body" to body,
                        "timestamp" to timestamp
                    )
                    methodChannel?.invokeMethod("onSmsReceived", smsData)
                    Log.d(TAG, "SMS sent to Flutter via method channel")
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending SMS to Flutter: ${e.message}", e)
                }
            } else {
                Log.w(TAG, "Method channel not available")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "SmsApplication onCreate")
    }
}
