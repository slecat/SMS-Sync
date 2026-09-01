# Mobile Keepalive Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Harden `sms-sync/mobile` background survival by adding `billr`-style boot recovery, watchdog restart, and notification-listener self-healing.

**Architecture:** Keep the existing Flutter `BackgroundService` as the SMS sync runtime, but add an app-level native keepalive helper and watchdog in `android/app/src/main/kotlin/com/smssync/sms_sync_mobile/`. Native boot and watchdog flows will restart the service and rebind the notification listener, while existing Flutter queue and SMS transport logic stays intact.

**Tech Stack:** Flutter, Dart, Kotlin, Android `BroadcastReceiver`, `AlarmManagerCompat`, `NotificationListenerService`, `flutter_background_service`

---

### Task 1: Lock boot and watchdog policy with Android tests

**Files:**
- Create: `sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/SmsKeepAlivePolicyTest.kt`
- Modify: `sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/WatchdogSchedulePolicyTest.kt`
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsKeepAlivePolicy.kt`

**Step 1: Write the failing test**

- Add a test asserting boot-like actions include `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, and `USER_UNLOCKED`.
- Add a test asserting keepalive is disabled when the service was manually stopped.
- Add a test asserting watchdog interval uses the extreme keepalive cadence we choose for app-level probing.

**Step 2: Run test to verify it fails**

Run: `./gradlew test --tests com.smssync.sms_sync_mobile.SmsKeepAlivePolicyTest --tests com.smssync.sms_sync_mobile.WatchdogSchedulePolicyTest`

Expected: FAIL because the helper policy object does not exist yet and the schedule still reflects the old assumptions.

**Step 3: Write minimal implementation**

- Create `SmsKeepAlivePolicy.kt` with pure functions:
  - `isBootLikeAction(action: String?): Boolean`
  - `shouldRestore(autoStartOnBoot: Boolean, manuallyStopped: Boolean, backgroundHandle: Long): Boolean`
  - `watchdogDelayMillis(): Long`
- Keep this file free of Android framework dependencies so it remains easy to unit test.

**Step 4: Run test to verify it passes**

Run: `./gradlew test --tests com.smssync.sms_sync_mobile.SmsKeepAlivePolicyTest --tests com.smssync.sms_sync_mobile.WatchdogSchedulePolicyTest`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsKeepAlivePolicy.kt sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/SmsKeepAlivePolicyTest.kt sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/WatchdogSchedulePolicyTest.kt
git commit -m "test: define mobile keepalive policy"
```

### Task 2: Add native keepalive helper and watchdog receiver

**Files:**
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsKeepAliveHelper.kt`
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/WatchdogReceiver.kt`
- Modify: `sms-sync/mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/BackgroundServiceStarter.kt`

**Step 1: Write the failing test**

- Add Android unit tests asserting:
  - watchdog should cancel itself when keepalive is not allowed
  - watchdog should attempt service restoration when the background service is missing
  - watchdog should still invoke listener recovery when the service is running

**Step 2: Run test to verify it fails**

Run: `./gradlew test --tests com.smssync.sms_sync_mobile.WatchdogReceiverTest`

Expected: FAIL because the receiver and helper do not exist yet.

**Step 3: Write minimal implementation**

- Implement `SmsKeepAliveHelper` to:
  - start `id.flutter.flutter_background_service.BackgroundService`
  - attempt notification listener activation and `requestRebind(...)`
  - schedule watchdog alarms
- Implement `WatchdogReceiver` to:
  - validate keepalive gates using `Config`
  - inspect `ActivityManager.getRunningServices(...)`
  - restart via `SmsKeepAliveHelper` when needed
  - renew the next alarm every cycle
- Update `AndroidManifest.xml` to register `WatchdogReceiver` and broaden `BootReceiver` intent filters.
- Keep `BackgroundServiceStarter` as a small wrapper or delegate so existing native callers still work.

**Step 4: Run test to verify it passes**

Run: `./gradlew test --tests com.smssync.sms_sync_mobile.WatchdogReceiverTest`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsKeepAliveHelper.kt sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/WatchdogReceiver.kt sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/BackgroundServiceStarter.kt sms-sync/mobile/android/app/src/main/AndroidManifest.xml
git commit -m "feat: add native watchdog for mobile keepalive"
```

### Task 3: Upgrade boot recovery flow

**Files:**
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/BootReceiver.kt`
- Test: `sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/SmsKeepAlivePolicyTest.kt`

**Step 1: Write the failing test**

- Add a focused test for the boot-action decision path if it is not already covered by the policy tests.
- Add assertions for `USER_UNLOCKED` support alongside traditional boot actions.

**Step 2: Run test to verify it fails**

Run: `./gradlew test --tests com.smssync.sms_sync_mobile.SmsKeepAlivePolicyTest`

Expected: FAIL if the action set or restore gate is incomplete.

**Step 3: Write minimal implementation**

- Change `BootReceiver` to use `SmsKeepAlivePolicy.isBootLikeAction(...)`.
- Delegate service startup to `SmsKeepAliveHelper.startMonitoringServices(...)`.
- Keep existing config guards so user-initiated stop still wins.

**Step 4: Run test to verify it passes**

Run: `./gradlew test --tests com.smssync.sms_sync_mobile.SmsKeepAlivePolicyTest`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/BootReceiver.kt sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/SmsKeepAlivePolicyTest.kt
git commit -m "feat: broaden mobile boot recovery actions"
```

### Task 4: Add notification-listener self-healing

**Files:**
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsNotificationListenerService.kt`
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/MainActivity.kt`

**Step 1: Write the failing test**

- Add an Android unit test, if practical, around a small extracted helper that determines whether rebind should be attempted.
- If framework-heavy testing is not practical, add a pure helper for enabled-listener detection and test that instead.

**Step 2: Run test to verify it fails**

Run the targeted Android unit test command for the new helper.

Expected: FAIL because the helper or rebind path does not exist yet.

**Step 3: Write minimal implementation**

- Add `onListenerConnected()` logging for observability.
- Add `onListenerDisconnected()` and call `requestRebind(ComponentName(...))` on Android N and above.
- Reuse or extract enabled-listener detection logic so both `MainActivity` and `SmsKeepAliveHelper` can use the same component check.

**Step 4: Run test to verify it passes**

Run the targeted Android unit test command again.

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsNotificationListenerService.kt sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/MainActivity.kt
git commit -m "feat: self-heal sms notification listener"
```

### Task 5: Preserve native SMS recovery paths under kill-and-restart

**Files:**
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/NativeSmsRelay.kt`
- Modify: `sms-sync/mobile/lib/background/background_runtime.dart`
- Modify: `sms-sync/mobile/test/services/settings_repository_test.dart`

**Step 1: Write the failing test**

- Add or extend Flutter tests for pending native SMS recovery to ensure a native-triggered restart still leads to queue flush.
- Add assertions that a startup-triggered flush path remains intact after the keepalive changes.

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/settings_repository_test.dart`

Expected: FAIL if queue-triggered recovery behavior changes unintentionally.

**Step 3: Write minimal implementation**

- Keep `NativeSmsRelay` delegating into the new keepalive helper path when Flutter is unavailable.
- Ensure `background_runtime.dart` still flushes pending native SMS on startup and on explicit reconnect.
- Avoid adding new periodic Dart timers; native keepalive should handle survival.

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/settings_repository_test.dart`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/NativeSmsRelay.kt sms-sync/mobile/lib/background/background_runtime.dart sms-sync/mobile/test/services/settings_repository_test.dart
git commit -m "test: keep pending sms recovery compatible with hard keepalive"
```

### Task 6: Verify the mobile client end to end

**Files:**
- No code changes required unless verification exposes a defect.

**Step 1: Run targeted Flutter tests**

Run: `flutter test test/services/settings_repository_test.dart test/services/message_payload_factory_test.dart`

Expected: PASS

**Step 2: Run Android unit tests**

Run: `./gradlew test`

Expected: PASS

**Step 3: Run mobile static analysis**

Run: `flutter analyze`

Expected: PASS or only pre-existing warnings unrelated to keepalive changes

**Step 4: Manual verification**

- Start the mobile app and send it to background; confirm the service notification remains visible.
- Kill the app process and confirm it is restored quickly.
- Reboot the device or emulator and confirm auto-start recovery.
- Toggle notification-listener permission and confirm the listener resumes.
- Receive a real SMS and verify it still syncs within seconds.

**Step 5: Commit**

```bash
git add .
git commit -m "test: verify mobile keepalive hardening"
```
