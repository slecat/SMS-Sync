package com.smssync.sms_sync_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

class SmsReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "SmsReceiver"
        var methodChannel: io.flutter.plugin.common.MethodChannel? = null
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_GROUP_ID = "groupId"
        private const val KEY_DEVICE_NAME = "deviceName"
        private const val KEY_SYNC_SECRET = "syncSecret"
        private const val KEY_GROUP_ID_FLUTTER = "flutter.groupId"
        private const val KEY_DEVICE_NAME_FLUTTER = "flutter.deviceName"
        private const val KEY_SYNC_SECRET_FLUTTER = "flutter.syncSecret"
        private const val DEFAULT_GROUP_ID = "default"
        private const val DEFAULT_DEVICE_NAME = "手机端"
        private const val SIGNATURE_VERSION = 1
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive called with action: ${intent.action}")
        
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            Log.d(TAG, "SMS received!")
            
            val bundle = intent.extras
            if (bundle != null) {
                val pdus = bundle.get("pdus") as? Array<*>
                val format = bundle.getString("format") ?: "3gpp"
                
                Log.d(TAG, "Number of PDUs: ${pdus?.size}")
                Log.d(TAG, "Format: $format")

                pdus?.forEachIndexed { index, pdu ->
                    try {
                        Log.d(TAG, "Processing PDU $index")
                        val message = createSmsMessage(pdu as ByteArray, format)
                        
                        if (message != null) {
                            val from = message.originatingAddress
                            val body = message.messageBody
                            
                            Log.d(TAG, "From: $from")
                            Log.d(TAG, "Body: $body")
                            
                            if (from != null && body != null) {
                                val timestamp = message.timestampMillis
                                
                                val smsData = mapOf(
                                    "from" to from,
                                    "body" to body,
                                    "timestamp" to timestamp
                                )
                                
                                if (methodChannel != null) {
                                    methodChannel?.invokeMethod("onSmsReceived", smsData)
                                    Log.d(TAG, "Sent SMS to Flutter via method channel")
                                } else {
                                    Log.d(TAG, "Method channel not available, trying direct broadcast")
                                    sendSmsViaBroadcast(context, from, body, timestamp)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error parsing SMS PDU $index: ${e.message}", e)
                    }
                }
            } else {
                Log.d(TAG, "Bundle is null")
            }
        }
    }
    
    private fun sendSmsViaBroadcast(context: Context, from: String, body: String, timestamp: Long) {
        try {
            Log.d(TAG, "Sending SMS via UDP broadcast")
            
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val groupId = loadStringPref(
                prefs = prefs,
                flutterKey = KEY_GROUP_ID_FLUTTER,
                legacyKey = KEY_GROUP_ID,
                defaultValue = DEFAULT_GROUP_ID,
            )
            val syncSecret = loadStringPref(
                prefs = prefs,
                flutterKey = KEY_SYNC_SECRET_FLUTTER,
                legacyKey = KEY_SYNC_SECRET,
                defaultValue = "",
            )
            
            val deviceId = getDeviceId(context)
            val messageId = "${deviceId}_$timestamp"
            val payload = linkedMapOf<String, Any>(
                "type" to "sms",
                "messageId" to messageId,
                "from" to from,
                "body" to body,
                "timestamp" to timestamp,
                "groupId" to groupId,
            )
            val signedPayload = signPayload(payload, syncSecret)
            val smsJson = JSONObject(signedPayload)
            
            Thread {
                try {
                    val socket = DatagramSocket()
                    socket.setBroadcast(true)
                    val buffer = smsJson.toString().toByteArray(Charsets.UTF_8)
                    val packet = DatagramPacket(
                        buffer, 
                        buffer.size, 
                        InetAddress.getByName("255.255.255.255"), 
                        8888
                    )
                    socket.send(packet)
                    socket.close()
                    Log.d(TAG, "UDP broadcast sent successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending UDP broadcast: ${e.message}", e)
                }
            }.start()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in sendSmsViaBroadcast: ${e.message}", e)
        }
    }

    private fun loadStringPref(
        prefs: android.content.SharedPreferences,
        flutterKey: String,
        legacyKey: String,
        defaultValue: String,
    ): String {
        val flutterValue = prefs.getString(flutterKey, null)
        if (!flutterValue.isNullOrBlank()) {
            return flutterValue
        }
        val legacyValue = prefs.getString(legacyKey, null)
        if (!legacyValue.isNullOrBlank()) {
            return legacyValue
        }
        return defaultValue
    }

    private fun signPayload(
        payload: LinkedHashMap<String, Any>,
        secret: String,
    ): LinkedHashMap<String, Any> {
        val normalizedSecret = secret.trim()
        if (normalizedSecret.isEmpty()) {
            return payload
        }

        val canonical = canonicalJson(payload)
        val signature = hmacSha256(canonical, normalizedSecret)
        val signed = LinkedHashMap(payload)
        signed["_sig_v"] = SIGNATURE_VERSION
        signed["_sig"] = signature
        return signed
    }

    private fun canonicalJson(map: Map<String, Any>): String {
        val sorted = java.util.TreeMap(map)
        val parts = sorted.entries.map { entry ->
            val key = JSONObject.quote(entry.key)
            val value = toCanonicalJsonValue(entry.value)
            "$key:$value"
        }
        return "{${parts.joinToString(",")}}"
    }

    private fun toCanonicalJsonValue(value: Any?): String {
        return when (value) {
            null -> "null"
            is String -> JSONObject.quote(value)
            is Number, is Boolean -> value.toString()
            is Map<*, *> -> {
                val nested = linkedMapOf<String, Any>()
                value.forEach { (k, v) ->
                    if (k is String && v != null) {
                        nested[k] = v
                    }
                }
                canonicalJson(nested)
            }
            is List<*> -> value.joinToString(prefix = "[", postfix = "]") {
                toCanonicalJsonValue(it)
            }
            else -> JSONObject.quote(value.toString())
        }
    }

    private fun hmacSha256(payload: String, secret: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        val digest = mac.doFinal(payload.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
    
    private fun getDeviceId(context: Context): String {
        return try {
            val androidId = android.provider.Settings.Secure.getString(
                context.contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            )
            androidId ?: "unknown_device"
        } catch (e: Exception) {
            Log.e(TAG, "Error getting device ID: ${e.message}", e)
            "unknown_device"
        }
    }
    
    private fun createSmsMessage(pdu: ByteArray, format: String): android.telephony.SmsMessage? {
        return try {
            Log.d(TAG, "Creating SMS message with format: $format")
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                try {
                    val method = android.telephony.SmsMessage::class.java.getMethod(
                        "createFromPdu",
                        ByteArray::class.java,
                        String::class.java
                    )
                    val result = method.invoke(null, pdu, format) as? android.telephony.SmsMessage
                    Log.d(TAG, "createFromPdu with format succeeded")
                    result
                } catch (e: NoSuchMethodException) {
                    Log.d(TAG, "createFromPdu with format not found, trying deprecated method")
                    @Suppress("DEPRECATION")
                    val result = android.telephony.SmsMessage.createFromPdu(pdu)
                    Log.d(TAG, "Deprecated createFromPdu succeeded")
                    result
                }
            } else {
                @Suppress("DEPRECATION")
                val result = android.telephony.SmsMessage.createFromPdu(pdu)
                Log.d(TAG, "Deprecated createFromPdu succeeded")
                result
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error creating SMS message: ${e.message}", e)
            null
        }
    }
}
