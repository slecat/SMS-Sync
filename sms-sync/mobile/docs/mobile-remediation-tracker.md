# Mobile Remediation Tracker

Last updated: 2026-02-27
Owner: Codex + User
Scope: `sms-sync/mobile`

## Milestone A - Stabilization (current)

- [x] A0: Create implementation tracker
- [x] A1: Gate platform-only background service and UDP/network listeners for test/non-Android contexts
- [x] A2: Add lifecycle cleanup (`dispose`, cancel timers/subscriptions, close sockets)
- [x] A3: Emit and consume server connection status events consistently
- [x] A4: Unify device ID retrieval path and persist one `deviceId`
- [x] A5: Run `flutter analyze` and `flutter test`, capture remaining issues

## Milestone B - Modularization (next)

- [x] B1: Split core runtime/platform/settings abstractions out of `main.dart` (`platform/`, `services/`)
- [x] B2: Move UDP/WebSocket send paths and payload builders into dedicated services
- [x] B3: Move settings persistence into repository layer
- [x] B4: Add unit tests for deduplication and message routing

## Risk Notes

- Dependency injection is in place for Home and Background flows; remaining risk is incomplete test coverage for injected dependency overrides.
- Message dedup relies on timestamp hash and short interval; duplicates are still possible.
- Payload signature hardening is now in place, but LAN transport is still plaintext.
- Signature rollout is configuration-sensitive: devices with inconsistent `syncSecret` will reject each other.

## Verification Checklist

- [x] `flutter analyze sms-sync/mobile` has no warnings from newly introduced code
- [x] `flutter test` passes in `sms-sync/mobile`
- [x] Manual smoke check on Android: SMS receive -> local broadcast -> server relay

## Current Validation Snapshot

- `flutter analyze sms-sync/mobile`: 0 issues
- `flutter test`: pass (`message_payload_factory_test`, `message_routing_policy_test`, `message_security_service_test`, `sms_deduplicator_test`)
- Android smoke (2026-02-27, device `10CF3U0YHC00035`, group `Dulin`): passed
- Server relay proof (`test`): `sms-sync/server/.smoke/listener_message.out.log` contains `LISTENER_SUCCESS_MESSAGE_TYPE_test`
- Server relay proof (`sms`): `sms-sync/server/.smoke/listener_sms2.out.log` contains `LISTENER_SUCCESS_SMS`
- Permission hardening (2026-02-27): removed `WRITE_SMS`, `SEND_SMS`, `READ_PHONE_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`; runtime request removed `Permission.phone`
- Signature hardening (2026-02-27): mobile + server support optional HMAC-SHA256 (`_sig`, `_sig_v`), and settings UI now supports `syncSecret`
- Structural modularization (2026-02-27): `main.dart` reduced to bootstrap only; background runtime moved to `background/background_runtime.dart`, app shell moved to `app/sms_sync_app.dart`, and page state moved to `ui/home_page.dart`
- Feature UI split (2026-02-27): extracted bottom nav and 4 tabs into `ui/home/` (`home_bottom_nav_bar.dart`, `home_config_tab.dart`, `messages_tab.dart`, `devices_tab.dart`, `settings_tab.dart`); `home_page.dart` now focuses on state orchestration
- Runtime coordination split (2026-02-27): extracted UDP/background/SMS listener side effects into `ui/home/home_runtime_coordinator.dart`; `home_page.dart` keeps state transitions and user-triggered actions
- Action coordination split (2026-02-27): extracted save/test/read user actions into `ui/home/home_action_coordinator.dart`; `home_page.dart` now handles action results and UI feedback
- Setup coordination split (2026-02-27): extracted preference loading + permission request into `ui/home/home_setup_coordinator.dart`; `home_page.dart` now applies setup result only
- View-state split (2026-02-27): extracted page state transitions into `ui/home/home_view_state.dart`, and centralized feedback rendering in `ui/home/home_snack_bar.dart`
- Dependency injection split (2026-02-27): introduced `ui/home/home_dependencies.dart`; `home_page.dart`, `home_setup_coordinator.dart`, and `home_action_coordinator.dart` now use injected dependencies instead of direct global access
- Background DI split (2026-02-27): introduced `background/background_dependencies.dart`; `background_runtime.dart` now resolves runtime services through dependency container
- Service provider split (2026-02-27): `app/service_registry.dart` refactored to `AppServices` container with `configureAppServices(...)`; default Home/Background dependencies are now created from provider rather than direct global service fields
