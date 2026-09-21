# Default SMS App Implementation Plan

> Deprecated on 2026-03-07: this implementation path was superseded by the notification-listener fallback. Use `sms-sync/mobile/docs/plans/2026-03-07-notification-listener-implementation.md` instead.


> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a minimal default SMS app mode so the app can request the SMS role and receive SMS via the default delivery path.

**Architecture:** Keep the existing Flutter/Kotlin bridge and sync pipeline. Add minimum Android default-SMS-app manifest components, expose request/status methods via `MainActivity`, and update the settings UI to guide the user through granting the role.

**Tech Stack:** Flutter, Kotlin, Android manifest intent filters, Telephony/RoleManager APIs.

---

### Task 1: Default-SMS platform bridge

**Files:**
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/MainActivity.kt`
- Modify: `sms-sync/mobile/lib/ui/home/settings_tab.dart`

**Step 1: Write the failing test**

Add a small pure helper test for supported SMS broadcast actions so the new delivery path is pinned down.

**Step 2: Run test to verify it fails**

Run the Android unit test task if available; if blocked by the known Gradle path issue, document the blocker and continue with build verification.

**Step 3: Write minimal implementation**

Add `requestDefaultSmsApp` to the platform channel and expose current default-SMS-app status in the settings page.

**Step 4: Run verification**

Run: `flutter build apk --debug`
Expected: build succeeds.

### Task 2: Default-SMS manifest components

**Files:**
- Modify: `sms-sync/mobile/android/app/src/main/AndroidManifest.xml`
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/RespondViaMessageService.kt`
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/MmsReceiver.kt`

**Step 1: Write the failing test**

Pin the new SMS delivery action handling in a helper-level test.

**Step 2: Run test to verify it fails**

Attempt the focused unit test; if blocked, record the blocker and proceed to build verification.

**Step 3: Write minimal implementation**

Add the minimum activity/receiver/service declarations needed for default SMS app qualification.

**Step 4: Run verification**

Run: `flutter build apk --debug`
Expected: build succeeds.

### Task 3: Receiver delivery-path support

**Files:**
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsReceiver.kt`
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsBroadcastActionHelper.kt`
- Create: `sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/SmsBroadcastActionHelperTest.kt`

**Step 1: Write the failing test**

Add tests proving `SMS_DELIVER` and `SMS_RECEIVED` are both accepted.

**Step 2: Run test to verify it fails**

Attempt the focused unit test; if blocked, record the blocker and proceed to build verification.

**Step 3: Write minimal implementation**

Update the receiver to accept both actions and keep the downstream sync logic unchanged.

**Step 4: Run verification**

Run: `flutter build apk --debug`
Expected: build succeeds.


