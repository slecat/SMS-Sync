package com.smssync.sms_sync_mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SmsObserverSelectorTest {
    @Test
    fun `parseChangedSmsId extracts id from row uri`() {
        val actual = SmsObserverSelector.parseChangedSmsId(
            "content://sms/1298?bubble_update_flag=false",
        )

        assertEquals(1298L, actual)
    }

    @Test
    fun `parseChangedSmsId returns null for collection uri`() {
        val actual = SmsObserverSelector.parseChangedSmsId("content://sms")

        assertNull(actual)
    }

    @Test
    fun `chooseRecord prefers changed inbox record over latest inbox`() {
        val changed = ObservedSmsRecord(
            id = 1272L,
            from = "HYJK",
            body = "¡¾Ó¥½ÇÍøÂç¡¿ÑéÖ¤Âë£º830859",
            type = 1,
            date = 1000L,
        )
        val latest = ObservedSmsRecord(
            id = 1298L,
            from = "10682498330560051",
            body = "another message",
            type = 1,
            date = 2000L,
        )

        val actual = SmsObserverSelector.chooseRecord(
            changedSmsId = 1272L,
            changedRecord = changed,
            latestInboxRecord = latest,
            inboxType = 1,
        )

        assertEquals(changed, actual)
    }

    @Test
    fun `chooseRecord falls back to latest inbox when changed record missing`() {
        val latest = ObservedSmsRecord(
            id = 1298L,
            from = "10682498330560051",
            body = "another message",
            type = 1,
            date = 2000L,
        )

        val actual = SmsObserverSelector.chooseRecord(
            changedSmsId = 1272L,
            changedRecord = null,
            latestInboxRecord = latest,
            inboxType = 1,
        )

        assertEquals(latest, actual)
    }

    @Test
    fun `chooseRecord falls back when changed record is not inbox`() {
        val changed = ObservedSmsRecord(
            id = 1272L,
            from = "service",
            body = "draft",
            type = 2,
            date = 1000L,
        )
        val latest = ObservedSmsRecord(
            id = 1298L,
            from = "10682498330560051",
            body = "another message",
            type = 1,
            date = 2000L,
        )

        val actual = SmsObserverSelector.chooseRecord(
            changedSmsId = 1272L,
            changedRecord = changed,
            latestInboxRecord = latest,
            inboxType = 1,
        )

        assertEquals(latest, actual)
    }
}
