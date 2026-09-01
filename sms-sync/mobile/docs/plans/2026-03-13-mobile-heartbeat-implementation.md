# Mobile Heartbeat Replacement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace timer-driven background heartbeats with lifecycle and event-driven SMS sync while preserving fast background SMS delivery.

**Architecture:** Keep the Android background service alive, but make it mostly idle. Presence becomes lifecycle-based (`online` on service start, `offline` on service stop), queued SMS is flushed on startup and explicit events, and reconnect attempts happen only when a real event needs delivery.

**Tech Stack:** Flutter, Dart, Android Kotlin, `flutter_background_service`, `shared_preferences`, WebSocket, UDP broadcast.

---

### Task 1: Lock the new presence semantics with tests

**Files:**
- Modify: `sms-sync/mobile/test/services/message_payload_factory_test.dart`
- Create: `sms-sync/mobile/test/ui/home/home_view_state_test.dart`
- Modify: `sms-sync/mobile/lib/services/message_payload_factory.dart`
- Modify: `sms-sync/mobile/lib/ui/home/home_view_state.dart`

**Step 1: Write the failing test**

- Add a test asserting `devicePresence(...)` includes a `status` field and defaults to `online`.
- Add a test asserting an explicit `offline` status is preserved.
- Add a test asserting TTL cleanup does not remove lifecycle-based online devices.
- Add a test asserting explicit offline events remove the device immediately.

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/message_payload_factory_test.dart test/ui/home/home_view_state_test.dart`

Expected: FAIL because `devicePresence` has no status support and `HomeViewState` cannot distinguish lifecycle presence.

**Step 3: Write minimal implementation**

- Extend `devicePresence` payload creation with a `status` field.
- Teach `HomeViewState` to retain lifecycle-based devices across stale cleanup and to drop devices on explicit `offline`.

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/message_payload_factory_test.dart test/ui/home/home_view_state_test.dart`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/lib/services/message_payload_factory.dart sms-sync/mobile/lib/ui/home/home_view_state.dart sms-sync/mobile/test/services/message_payload_factory_test.dart sms-sync/mobile/test/ui/home/home_view_state_test.dart
git commit -m "test: define lifecycle-based mobile presence semantics"
```

### Task 2: Remove watchdog and timer-driven background work

**Files:**
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/BackgroundServiceStarter.kt`
- Modify: `sms-sync/mobile/lib/background/background_runtime.dart`
- Modify: `sms-sync/mobile/lib/ui/home/home_runtime_coordinator.dart`

**Step 1: Write the failing test**

- Add a focused Dart regression test for any extracted helper that decides whether reconnect or queue flush should run.
- If the Android unit harness can cover the starter cheaply, add a small test to prove watchdog scheduling is gone; otherwise verify by code review and runtime behavior.

**Step 2: Run test to verify it fails**

Run the targeted Flutter test command for the new helper or coordinator test.

Expected: FAIL because the current runtime still schedules periodic work.

**Step 3: Write minimal implementation**

- Remove `WatchdogReceiver.enqueue(...)` from the app starter.
- Remove recurring timers for reconnect, presence refresh, pending queue polling, and cleanup persistence.
- Publish `online` presence once at startup.
- Flush queued native SMS at startup and on explicit reconnect/manual events.
- Preserve direct SMS-triggered reconnect behavior without periodic probing.

**Step 4: Run test to verify it passes**

Run the targeted Flutter tests plus any existing impacted tests.

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/BackgroundServiceStarter.kt sms-sync/mobile/lib/background/background_runtime.dart sms-sync/mobile/lib/ui/home/home_runtime_coordinator.dart
git commit -m "refactor: replace mobile heartbeat timers with event-driven runtime"
```

### Task 3: Align event triggers and manual reconnect flows

**Files:**
- Modify: `sms-sync/mobile/lib/ui/home/home_action_coordinator.dart`
- Modify: `sms-sync/mobile/lib/background/background_runtime.dart`
- Modify: `sms-sync/mobile/lib/services/settings_repository.dart`
- Modify: `sms-sync/mobile/test/services/settings_repository_test.dart`

**Step 1: Write the failing test**

- Add tests for new explicit runtime events or queue-flush persistence behavior.
- Add a repository test if presence or queue state handling changes.

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/settings_repository_test.dart`

Expected: FAIL if the new event semantics are not implemented yet.

**Step 3: Write minimal implementation**

- After saving preferences, trigger a one-shot reconnect and queue-flush path instead of relying on periodic pollers.
- Keep queue persistence minimal and event-triggered.

**Step 4: Run test to verify it passes**

Run the targeted repository/runtime tests.

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/lib/ui/home/home_action_coordinator.dart sms-sync/mobile/lib/background/background_runtime.dart sms-sync/mobile/lib/services/settings_repository.dart sms-sync/mobile/test/services/settings_repository_test.dart
git commit -m "feat: trigger one-shot mobile sync on meaningful events"
```

### Task 4: Verify the runtime end-to-end

**Files:**
- No code changes required unless verification reveals a defect.

**Step 1: Run targeted Flutter tests**

Run: `flutter test test/services/message_payload_factory_test.dart test/services/settings_repository_test.dart test/ui/home/home_view_state_test.dart`

Expected: PASS

**Step 2: Run the full mobile test suite**

Run: `flutter test`

Expected: PASS

**Step 3: Run Android unit tests if available**

Run: `./gradlew test` from `sms-sync/mobile/android`

Expected: PASS

**Step 4: Manual verification**

- Start the service and confirm only one online presence publish occurs.
- Leave the app in background and confirm logs no longer show 3s/5s/12s heartbeat activity.
- Send a real SMS and verify sync completes within seconds.
- Disable network, send SMS, confirm it remains queued.
- Reopen app or restart service, confirm queued SMS is retried.

**Step 5: Commit**

```bash
git add .
git commit -m "test: verify event-driven mobile sync runtime"
```
