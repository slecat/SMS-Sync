package com.smssync.sms_sync_mobile

import org.junit.Assert.assertEquals
import org.junit.Test

class NativeConfigStoreTest {
    @Test
    fun readsFlutterSharedPreferencesKeys() {
        val config = NativeConfigStore.parse(mapOf(
            "flutter.serverUrl" to "wss://relay.example",
            "flutter.groupId" to "home",
            "flutter.deviceName" to "Z10",
            "flutter.syncSecret" to "secret",
        ))
        assertEquals("wss://relay.example", config.serverUrl)
        assertEquals("home", config.groupId)
        assertEquals("Z10", config.deviceName)
        assertEquals("secret", config.syncSecret)
    }

    @Test
    fun normalizesBareServerAddress() {
        val config = NativeConfigStore.parse(mapOf("serverUrl" to "111.228.32.128:8004"))
        assertEquals("ws://111.228.32.128:8004", config.serverUrl)
    }
}
