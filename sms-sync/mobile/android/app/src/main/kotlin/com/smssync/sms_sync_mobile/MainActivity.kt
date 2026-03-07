package com.smssync.sms_sync_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_sync_channel"
    private val APP_CHANNEL = "sms_sync_app"
    private val NOTIFICATION_CHANNEL_ID = "sms_sync_service_v2"
    private val TAG = "MainActivity"

    private var smsObserver: SmsObserver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "configureFlutterEngine called")

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        NativeSmsRelay.methodChannel = methodChannel
        SmsApplication.methodChannel = methodChannel

        methodChannel.setMethodCallHandler { call, result ->
            Log.d(TAG, "Received method call: ${call.method}")
            when (call.method) {
                "registerHandler" -> {
                    Log.d(TAG, "Handler registered (called from background service)")
                    result.success(null)
                }
                "readLatestSms" -> {
                    val sms = readLatestSms()
                    result.success(sms)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> result.success(isNotificationListenerEnabled())
                "openNotificationListenerSettings" -> result.success(openNotificationListenerSettings())
                "getDeviceId" -> result.success(resolveDeviceId())
                else -> result.notImplemented()
            }
        }

        createNotificationChannel()
        setupSmsObserver(methodChannel)
    }

    private fun setupSmsObserver(methodChannel: MethodChannel) {
        Log.d(TAG, "Setting up SmsObserver")

        smsObserver = SmsObserver(this) { from, body ->
            Log.d(TAG, "SmsObserver received SMS: From=$from")
            val smsData = mapOf(
                "from" to from,
                "body" to body,
                "timestamp" to System.currentTimeMillis()
            )
            methodChannel.invokeMethod("onSmsReceived", smsData)
        }

        contentResolver.registerContentObserver(
            Telephony.Sms.CONTENT_URI,
            true,
            smsObserver!!
        )

        Log.d(TAG, "SmsObserver registered successfully")
    }

    private fun readLatestSms(): Map<String, Any>? {
        return try {
            logRecentSmsSnapshot("all", null, null)

            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE
            )

            val selection = "${Telephony.Sms.TYPE} = ?"
            val selectionArgs = arrayOf(Telephony.Sms.MESSAGE_TYPE_INBOX.toString())
            val sortOrder = "${Telephony.Sms.DATE} DESC, ${Telephony.Sms._ID} DESC"

            val cursor: Cursor? = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )

            cursor?.use {
                if (it.moveToFirst()) {
                    val idIndex = it.getColumnIndex(Telephony.Sms._ID)
                    val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
                    val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
                    val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)
                    val typeIndex = it.getColumnIndex(Telephony.Sms.TYPE)

                    if (
                        idIndex >= 0 &&
                        addressIndex >= 0 &&
                        bodyIndex >= 0 &&
                        dateIndex >= 0 &&
                        typeIndex >= 0
                    ) {
                        val id = it.getLong(idIndex)
                        val from = it.getString(addressIndex) ?: "unknown_sender"
                        val body = it.getString(bodyIndex) ?: ""
                        val date = it.getLong(dateIndex)
                        val type = it.getInt(typeIndex)

                        Log.d(
                            TAG,
                            "Latest SMS - ID: $id, Type: $type, From: $from, Preview=${previewBody(body)}",
                        )

                        mapOf(
                            "id" to id,
                            "from" to from,
                            "body" to body,
                            "timestamp" to date
                        )
                    } else {
                        null
                    }
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading latest SMS: ${e.message}", e)
            null
        }
    }

    private fun logRecentSmsSnapshot(
        label: String,
        selection: String?,
        selectionArgs: Array<String>?,
    ) {
        try {
            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE,
            )
            val sortOrder = "${Telephony.Sms.DATE} DESC, ${Telephony.Sms._ID} DESC LIMIT 5"
            val cursor = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder,
            )

            cursor?.use {
                val idIndex = it.getColumnIndex(Telephony.Sms._ID)
                val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
                val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)
                val typeIndex = it.getColumnIndex(Telephony.Sms.TYPE)

                var row = 0
                while (it.moveToNext()) {
                    if (
                        idIndex < 0 ||
                        addressIndex < 0 ||
                        bodyIndex < 0 ||
                        dateIndex < 0 ||
                        typeIndex < 0
                    ) {
                        break
                    }

                    val id = it.getLong(idIndex)
                    val from = it.getString(addressIndex) ?: "unknown_sender"
                    val body = it.getString(bodyIndex) ?: ""
                    val date = it.getLong(dateIndex)
                    val type = it.getInt(typeIndex)
                    Log.d(
                        TAG,
                        "Recent SMS[$label][$row] - ID=$id, Type=$type, Date=$date, From=$from, Preview=${previewBody(body)}",
                    )
                    row += 1
                }

                if (row == 0) {
                    Log.d(TAG, "Recent SMS[$label] - no rows")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error logging recent SMS[$label]: ${e.message}", e)
        }
    }

    private fun previewBody(body: String): String {
        val normalized = body.replace('\n', ' ').trim()
        return if (normalized.length <= 40) normalized else normalized.substring(0, 40) + "..."
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return try {
            val enabled = Settings.Secure.getString(
                contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            val component = ComponentName(this, SmsNotificationListenerService::class.java)
            enabled.split(':').any { it.equals(component.flattenToString(), ignoreCase = true) }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking notification listener: ${e.message}", e)
            false
        }
    }

    private fun openNotificationListenerSettings(): Boolean {
        return try {
            startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error opening notification listener settings: ${e.message}", e)
            false
        }
    }

    private fun resolveDeviceId(): String {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                ?: Build.ID
                ?: "unknown_device"
        } catch (e: Exception) {
            Log.e(TAG, "Error getting device ID: ${e.message}", e)
            "unknown_device"
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "短信同步"
            val descriptionText = "后台同步短信通知"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        smsObserver?.let {
            contentResolver.unregisterContentObserver(it)
            Log.d(TAG, "SmsObserver unregistered")
        }
    }
}
