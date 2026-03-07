# Notification Listener Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a notification-listener fallback for verification-code SMS that are hidden from the SMS provider and broadcast APIs.

**Architecture:** Add a native `NotificationListenerService` that extracts title/body text from notifications, filters aggressively for verification-code SMS-like content, and forwards accepted items through the existing method-channel / UDP sync pipeline. Expose status and settings entry points in the Flutter settings page.

**Tech Stack:** Flutter, Kotlin, Android NotificationListenerService, MethodChannel.

---

### Task 1: Listener heuristics

**Files:**
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/NotificationSmsHeuristics.kt`
- Create: `sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/NotificationSmsHeuristicsTest.kt`

**Step 1: Write the failing test**

Add tests for positive verification-code content and negative self-notification/non-SMS content.

**Step 2: Run test to verify it fails**

Attempt focused Android unit test; if blocked by the known Gradle path issue, document the blocker and continue with build verification.

**Step 3: Write minimal implementation**

Implement package filtering and verification-code pattern matching.

**Step 4: Run verification**

Run: `flutter build apk --debug`
Expected: build succeeds.

### Task 2: Notification listener service

**Files:**
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsNotificationListenerService.kt`
- Modify: `sms-sync/mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/MainActivity.kt`

**Step 1: Write the failing test**

Use helper-level tests to pin notification extraction behavior.

**Step 2: Run test to verify it fails**

Attempt focused unit test; if blocked, record the blocker and proceed to build verification.

**Step 3: Write minimal implementation**

Register the notification listener service, expose listener-enabled/status methods, and forward accepted notifications into the existing SMS sync path.

**Step 4: Run verification**

Run: `flutter build apk --debug`
Expected: build succeeds.

### Task 3: Settings UI integration

**Files:**
- Modify: `sms-sync/mobile/lib/ui/home/settings_tab.dart`

**Step 1: Write the failing test**

No widget test exists; keep change minimal and verify through build plus manual flow.

**Step 2: Write minimal implementation**

Add listener status row and open-notification-listener-settings action.

**Step 3: Run verification**

Run: `flutter build apk --debug`
Expected: build succeeds.
