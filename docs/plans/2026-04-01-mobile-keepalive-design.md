# Mobile Keepalive Hardening Design

**Context**

The Android mobile client in `sms-sync/mobile` already uses a foreground `flutter_background_service` runtime and can queue SMS for delayed delivery. In practice, some ROMs still kill the service or silently disconnect the notification listener, which breaks background SMS sync until the app is reopened.

The user wants the mobile app to adopt the more aggressive keepalive strategy already used in `E:/File/MySoftword/billr`, prioritizing survival over battery cost.

**Goals**

- Make the background sync runtime recover quickly after process death.
- Restore the service after boot, package replacement, and vendor quick boot flows.
- Keep the notification-listener fallback alive even when Android disconnects it.
- Preserve existing Flutter-side SMS routing, queueing, and sync logic.

**Non-Goals**

- Replacing the Flutter background runtime with a fully native SMS sync pipeline.
- Removing the existing plugin watchdog implementation.
- Reducing battery cost or background wakeups.

## Current State

`sms-sync/mobile` already has:

- A foreground Flutter background service configured in `lib/background/background_runtime.dart`
- Native SMS ingestion through `SmsReceiver`
- Notification fallback through `SmsNotificationListenerService`
- Recovery of queued native SMS through `NativeSmsRelay`
- A plugin-level watchdog inside `third_party/flutter_background_service_android`

The current gaps compared with `billr` are:

- App-level boot recovery only handles `USER_UNLOCKED`
- No app-level watchdog receiver in `android/app/src/main/kotlin/...`
- No centralized native keepalive helper for coordinated restart and rebind
- No `onListenerDisconnected()` self-healing in `SmsNotificationListenerService`
- No app-level rebind path that runs even when the background service is still technically alive

## Reference From `billr`

The `billr` app uses four pieces together:

1. `BootReceiver` handles `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, and vendor quick boot.
2. `PaymentAutoStartHelper` centralizes foreground-service startup and notification-listener recovery.
3. `WatchdogReceiver` uses `AlarmManagerCompat.setExactAndAllowWhileIdle` or `setAndAllowWhileIdle` for recurring probes.
4. `PaymentNotificationService.onListenerDisconnected()` calls `requestRebind(...)`.

That combination makes the system resilient to both process death and listener detachment.

## Chosen Approach

Adopt a hybrid hard-keepalive model for `sms-sync/mobile`:

- Keep the existing Flutter `BackgroundService` as the actual sync runtime.
- Add an app-level native keepalive orchestration layer modeled after `billr`.
- Use an app-level watchdog receiver to periodically verify the Flutter service and rebind the notification listener.
- Expand boot/package-replacement triggers so recovery happens earlier and more consistently.
- Let native SMS ingestion continue queueing work whenever Flutter is unavailable.

This preserves the current architecture while making keepalive behavior far more aggressive.

## Architecture

### 1. Boot And Upgrade Recovery

Extend `android/app/src/main/AndroidManifest.xml` and `BootReceiver.kt` so app-level auto-start reacts to:

- `android.intent.action.BOOT_COMPLETED`
- `android.intent.action.MY_PACKAGE_REPLACED`
- `android.intent.action.QUICKBOOT_POWERON`
- `android.intent.action.USER_UNLOCKED`

The boot receiver will keep respecting the plugin config gates:

- `Config.isAutoStartOnBoot`
- `Config.isManuallyStopped`
- `Config.backgroundHandle > 0`

If the runtime should be restored, the receiver will delegate to a new native helper instead of starting the service directly.

### 2. Native Keepalive Helper

Add a new Kotlin helper, `SmsKeepAliveHelper`, that centralizes keepalive behavior:

- Start the Flutter `BackgroundService`
- Rebind `SmsNotificationListenerService` when permission is granted
- Start the listener service process if possible
- Schedule or cancel the app-level watchdog
- Log the precise restart reason for diagnosis

This mirrors `billr`'s `PaymentAutoStartHelper` and prevents restart logic from being duplicated across receivers and services.

### 3. App-Level Watchdog Receiver

Add a native `WatchdogReceiver` under `android/app/src/main/kotlin/com/smssync/sms_sync_mobile/`.

Responsibilities:

- Probe whether `id.flutter.flutter_background_service.BackgroundService` is currently running
- If not running, restore it through `SmsKeepAliveHelper`
- If running, still call the listener recovery path so the notification fallback does not silently die
- Reschedule itself every cycle while keepalive is enabled
- Remove its alarm when keepalive is disabled or the service was manually stopped

This watchdog becomes the main app-controlled recovery loop. The plugin watchdog remains as a secondary safety net.

### 4. Notification Listener Self-Healing

Enhance `SmsNotificationListenerService` with:

- `onListenerConnected()` logging
- `onListenerDisconnected()` recovery using `requestRebind(ComponentName(...))`

Additionally, `SmsKeepAliveHelper.ensureNotificationListenerActive(...)` will call `requestRebind(...)` whenever the permission is enabled, including in watchdog-alive cycles.

This addresses the failure mode where the background service still exists but the listener fallback no longer receives notifications.

### 5. Existing SMS Flow Preservation

No major functional change is needed for:

- `SmsReceiver`
- `NativeSmsRelay`
- Flutter-side queue flushing in `background_runtime.dart`

They already support the important case:

- native SMS arrives
- Flutter channel is missing
- message is queued
- keepalive path starts or restores the background runtime
- queue flushes on startup or reconnect

The keepalive hardening only makes this path happen more reliably.

## Data Flow

### Boot / Package Replaced / Unlock

1. `BootReceiver` receives a restore-capable action.
2. It checks the plugin config gates.
3. If restoration is allowed, it calls `SmsKeepAliveHelper.startMonitoringServices(...)`.
4. The helper starts the Flutter background service, tries listener recovery, and schedules the watchdog.

### Normal Background Operation

1. Flutter background service stays in foreground mode.
2. SMS continues entering through `SmsReceiver`.
3. Notification-derived SMS fallback continues entering through `SmsNotificationListenerService`.
4. Both use `NativeSmsRelay.deliver(...)`.
5. If Flutter is not reachable, SMS is queued and the keepalive helper path is triggered.

### Watchdog Cycle

1. `WatchdogReceiver` alarm fires.
2. It validates whether keepalive is still allowed.
3. It checks whether the Flutter background service is running.
4. If not, it restarts the service.
5. If yes, it still attempts listener self-healing.
6. It schedules the next probe.

### Listener Disconnect

1. Android disconnects `SmsNotificationListenerService`.
2. `onListenerDisconnected()` runs.
3. The service calls `requestRebind(...)`.
4. Future watchdog cycles continue reinforcing rebind attempts.

## Manifest Changes

`android/app/src/main/AndroidManifest.xml` will need:

- App-level `WatchdogReceiver` declaration
- Additional boot-related intent actions on `BootReceiver`
- Existing service declarations kept intact

The foreground service remains `id.flutter.flutter_background_service.BackgroundService`, so no new app-specific foreground service is introduced in this design.

## Error Handling

- If notification-listener permission is disabled, keepalive logs and skips rebind instead of crashing.
- If foreground-service startup throws, the helper logs the error and the next watchdog cycle retries.
- If the user manually stops the service, the watchdog must stand down and cancel itself.
- If a vendor ROM delays alarms, the plugin watchdog still exists as a secondary fallback.

## Testing Strategy

### Android Unit Tests

Add or update tests for:

- Boot action filtering and keepalive gating
- Watchdog scheduling policy
- Watchdog restart behavior when service is absent
- Watchdog no-op plus listener rebind when service is present
- Listener disconnect rebind behavior where practical

### Flutter Regression Coverage

Re-run existing mobile tests covering:

- Native pending SMS queue persistence
- Background runtime flush behavior
- Settings-triggered reconnect paths

### Manual Verification

- Start app, send it to background, confirm foreground notification remains
- Kill the process, confirm watchdog restores it quickly
- Reboot device, confirm auto-start recovers service
- Upgrade/reinstall package, confirm service restores on package replacement path
- Toggle notification-listener permission off/on and verify the fallback resumes
- Receive a real SMS while backgrounded and confirm sync still happens within seconds

## Trade-Offs

This design intentionally favors reliability over battery life:

- More `AlarmManager` wakeups
- More background activity
- Stronger persistence signals to the OS
- Higher user-visible “always running” behavior

That matches the requested “extreme keepalive” mode and the `billr` reference implementation.

## Expected Outcome

After implementation, `sms-sync/mobile` should behave much closer to `billr`:

- the Flutter sync runtime is recovered after kill, reboot, and app replacement
- the notification-listener fallback heals itself when detached
- queued SMS survives runtime death and is retried after recovery
- background SMS sync becomes noticeably harder for the OS or OEM ROM to break silently
