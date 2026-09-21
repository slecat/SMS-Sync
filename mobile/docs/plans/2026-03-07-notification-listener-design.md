# Notification Listener Design

Date: 2026-03-07

## Problem

Some verification messages never appear in `Telephony.Sms` and never trigger the standard SMS broadcast path, but they are still visible to the user through the system messaging app notification surface.

## Goal

Add an optional notification-listener fallback so the app can extract verification-code SMS content from notification text when Android/ROM hides the original SMS from third-party apps.

## Scope

- Add a `NotificationListenerService`
- Expose notification-listener status and settings entry in Flutter settings UI
- Filter out this app's own notifications
- Extract sender/body candidates from notification extras
- Only forward notifications that look like verification-code SMS content
- Reuse the existing sync pipeline once a body is extracted

## Non-Goals

- General-purpose notification mirroring
- Accessibility-based scraping
- Full OCR or overlay parsing
- Persisting every notification event

## Approach

Implement a native Android notification-listener service that reads `Notification.EXTRA_TITLE`, `Notification.EXTRA_TEXT`, and `Notification.EXTRA_BIG_TEXT`. Build a conservative filter: ignore this app package, require notification-listener permission, and only forward content that strongly resembles a verification-code SMS. Use the same method-channel and UDP fallback pattern already used by `SmsReceiver`.

## Risks

- ROM-customized notification layouts may omit full message body
- Some SMS apps may redact content on lockscreen or for privacy mode
- Heuristic matching can miss edge cases or forward false positives if too broad
