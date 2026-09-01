# Mobile Heartbeat Replacement Design

**Context**

The Android mobile runtime currently keeps a foreground service alive with multiple periodic timers and a plugin watchdog alarm. This preserves background sync but costs too much battery for a device that stays mounted in the background for long periods.

**Goals**

- Preserve the core behavior: background SMS must still sync out within a few seconds.
- Keep the mobile device logically online while its background service is running.
- Preserve LAN discovery without high-frequency presence refreshes.
- Remove periodic heartbeat, reconnect probing, and watchdog wakeups from the normal runtime path.

**Non-Goals**

- Real-time liveness derived from heartbeat timestamps.
- Server-initiated workflows that depend on a permanently refreshed connection.
- Exact-alarm self-healing loops.

## Root Cause

Battery cost comes from repeated wakeups across multiple layers:

- `background_runtime.dart` runs periodic timers for queue flushing, LAN presence, WebSocket presence, reconnect probing, and device cleanup.
- `flutter_background_service_android` schedules a watchdog alarm about every 15 seconds to verify service liveness.
- Presence is TTL-based, so the app keeps sending refresh traffic just to remain visible as online.

The service is not merely resident; it is continuously active.

## Chosen Approach

Keep the background service, but convert it from a timer-driven runtime into an idle event-driven runtime.

### Service Lifecycle

- Service start means the mobile device is online.
- Service stop or process death means the mobile device is offline.
- Presence is updated on lifecycle events, not on recurring heartbeats.

### SMS Delivery

- Incoming SMS still enters through `SmsReceiver` and `SmsNotificationListenerService`.
- If the Flutter/UI method channel is unavailable, native code queues the SMS and starts the background service if needed.
- The background runtime flushes queued SMS immediately on startup and on explicit events.
- If the server connection is alive, SMS is sent through that connection.
- If the connection is down, the runtime performs a single reconnect attempt for the event that needs delivery.
- Failed items remain queued for the next meaningful event:
  - next SMS
  - service restart
  - app foreground open
  - manual reconnect after settings save

### Presence Model

- Presence payloads gain explicit lifecycle status:
  - `online`
  - `offline`
- On service startup:
  - broadcast LAN `device-presence online`
  - register or reconnect once to the server if configured
- On service stop:
  - best-effort LAN/server `device-presence offline`
- No periodic presence refresh remains.

### Online Device Semantics

Consumers must stop treating mobile presence as TTL-renewed.

- A mobile device marked `online` remains online until:
  - an explicit `offline` event arrives, or
  - local state is reset manually or during app restart
- Existing TTL cleanup can still apply to legacy freshness-based sources if needed, but not to lifecycle-based mobile presence.

## Design Changes

### Android / Native

- Remove watchdog scheduling from `BackgroundServiceStarter`.
- Keep boot restore behavior, but only start the service once on valid boot/unlock events.
- Continue to enqueue pending SMS when the Flutter channel is absent.

### Flutter Background Runtime

- Remove periodic timers for:
  - reconnect probing
  - WebSocket presence refresh
  - LAN presence refresh
  - pending SMS polling
  - device cleanup persistence loop
- Keep:
  - startup connection attempt
  - explicit reconnect event handling
  - immediate flush of queued SMS
  - runtime event bridge to UI
- Add explicit one-shot hooks:
  - publish online presence
  - publish offline presence
  - flush pending native SMS

### UI / Presence State

- Store explicit lifecycle status for remote devices.
- Do not evict mobile devices solely because a timestamp aged out.
- Keep cleanup behavior only for sources that still rely on freshness timestamps.

## Error Handling

- A missing or invalid `serverUrl` means LAN-only delivery.
- A failed reconnect during SMS handling does not start a background timer; the SMS stays queued.
- Offline presence is best-effort only. If the OS kills the service, stale online state may persist until the next lifecycle event corrects it.

## Testing Strategy

- Add unit tests for presence payload status fields.
- Add unit tests for view-state cleanup so lifecycle-based devices are not removed by TTL cleanup.
- Add runtime/service tests for event-triggered flush and absence of periodic reconnect behavior where feasible.
- Add Android unit coverage for the no-watchdog starter path if practical.

## Expected Outcome

The mobile app remains mounted in the background, but idle most of the time. SMS-triggered work still completes within seconds, while the runtime stops burning battery on constant heartbeats, reconnect probes, and alarm-based watchdog checks.
