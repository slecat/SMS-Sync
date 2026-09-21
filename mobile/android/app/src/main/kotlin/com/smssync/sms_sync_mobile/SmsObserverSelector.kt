package com.smssync.sms_sync_mobile

data class ObservedSmsRecord(
    val id: Long,
    val from: String,
    val body: String,
    val type: Int,
    val date: Long,
)

object SmsObserverSelector {
    fun parseChangedSmsId(uriString: String?): Long? {
        if (uriString.isNullOrBlank()) {
            return null
        }

        val normalized = uriString.substringBefore('?')
        val marker = "/sms/"
        val markerIndex = normalized.lastIndexOf(marker)
        if (markerIndex < 0) {
            return null
        }

        val idPart = normalized.substring(markerIndex + marker.length)
        return idPart.toLongOrNull()
    }

    fun chooseRecord(
        changedSmsId: Long?,
        changedRecord: ObservedSmsRecord?,
        latestInboxRecord: ObservedSmsRecord?,
        inboxType: Int,
    ): ObservedSmsRecord? {
        if (
            changedSmsId != null &&
            changedRecord != null &&
            changedRecord.id == changedSmsId &&
            changedRecord.type == inboxType
        ) {
            return changedRecord
        }

        return latestInboxRecord
    }
}
