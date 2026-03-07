# Default SMS App Design

> Deprecated on 2026-03-07: this approach was abandoned because the device automatically reverted the default SMS app for safety reasons. Use `sms-sync/mobile/docs/plans/2026-03-07-notification-listener-design.md` instead.


Date: 2026-03-07

## Problem

Some verification SMS messages are visible in the system SMS app but do not appear in `Telephony.Sms` for this app and do not trigger the existing `SMS_RECEIVED` path. This strongly suggests ROM/default-SMS-app level filtering or privileged delivery behavior.

## Goal

Enable a minimal default SMS app mode so the app can request the SMS role and receive SMS through the default-app delivery path, without building a full messaging client.

## Scope

- Add a platform action to request the default SMS role
- Expose default-SMS-app status in settings
- Add the minimum manifest components Android expects for a default SMS handler
- Extend SMS receiver handling from `SMS_RECEIVED` to `SMS_DELIVER`
- Keep existing sync pipeline unchanged once an SMS body is obtained

## Non-Goals

- Full conversations UI
- Sending MMS
- Rich compose experience
- Message database management beyond current read/sync needs

## Approach

Use the current Flutter UI and native Kotlin bridge. Keep `MainActivity` as the launcher and add the minimum extra Android components: SMS deliver receiver, WAP push deliver receiver, SENDTO activity intent filter, and respond-via-message service. Request the default SMS role from the settings page and refresh status when returning to the app.

## Risks

- Some ROMs may still impose extra behavior even after role grant
- Minimal default-app compliance may be enough for testing but not enough for a polished messaging experience
- Existing Android unit-test task is currently blocked by unrelated Gradle/pub-cache path issues


