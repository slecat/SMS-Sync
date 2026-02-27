package com.smssync.sms_sync_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_sync_channel"
    private val APP_CHANNEL = "sms_sync_app"
    private val NOTIFICATION_CHANNEL_ID = "sms_sync_channel"
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
        SmsReceiver.methodChannel = methodChannel
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
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultSmsApp" -> {
                    result.success(isDefaultSmsApp())
                }
                "getDeviceId" -> {
                    result.success(resolveDeviceId())
                }
                else -> {
                    result.notImplemented()
                }
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
            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE
            )
            
            val sortOrder = "${Telephony.Sms._ID} DESC LIMIT 1"
            
            val cursor: Cursor? = contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )
            
            cursor?.use {
                if (it.moveToFirst()) {
                    val idIndex = it.getColumnIndex(Telephony.Sms._ID)
                    val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
                    val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
                    val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)
                    
                    if (idIndex >= 0 && addressIndex >= 0 && bodyIndex >= 0 && dateIndex >= 0) {
                        val id = it.getLong(idIndex)
                        val from = it.getString(addressIndex)
                        val body = it.getString(bodyIndex)
                        val date = it.getLong(dateIndex)
                        
                        Log.d(TAG, "Latest SMS - ID: $id, From: $from")
                        
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

    private fun isDefaultSmsApp(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
                roleManager.isRoleHeld(RoleManager.ROLE_SMS)
            } else {
                val defaultSmsPackage = Telephony.Sms.getDefaultSmsPackage(this)
                defaultSmsPackage == packageName
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking default SMS app: ${e.message}", e)
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
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
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
