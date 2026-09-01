# Device Identity Unification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace mixed device identity behavior with one canonical long-lived `deviceId` model across mobile, desktop, and server.

**Architecture:** Mobile and desktop each get a local identity service that owns persistent UUID generation and validation. The server continues to key device presence by canonical `deviceId` while separating runtime connection identity for logging and diagnostics. Deployment includes inspecting the live server over SSH before syncing changes.

**Tech Stack:** Flutter, SharedPreferences, Electron, electron-store, Node.js, ws, node:test

---

### Task 1: Document and lock the identity model

**Files:**
- Create: `docs/plans/2026-03-16-device-identity-design.md`
- Create: `docs/plans/2026-03-16-device-identity-implementation.md`

**Step 1: Save the approved design**

Write the design document with:
- canonical meaning of `deviceId`
- `connectionId` separation
- mobile, desktop, and server responsibilities
- SSH-first server deployment rule

**Step 2: Verify the plan matches repository structure**

Run: `rg -n "deviceId|randomUUID|resolveDeviceId|getDeviceId" sms-sync`

Expected: references exist in mobile, desktop, and server code paths that this plan targets.

### Task 2: Add mobile identity tests

**Files:**
- Modify: `sms-sync/mobile/lib/services/device_id_service.dart`
- Create: `sms-sync/mobile/test/services/device_id_service_test.dart`

**Step 1: Write the failing test**

Cover:
- returns stored UUID when present
- generates and persists UUID when missing
- replaces invalid placeholder values such as `unknown_device`

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/device_id_service_test.dart`

Expected: FAIL because the current implementation depends on platform IDs and does not generate canonical UUIDs locally.

**Step 3: Write minimal implementation**

Implement a local UUID-backed identity service and remove canonical fallback to platform IDs.

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/device_id_service_test.dart`

Expected: PASS

### Task 3: Add desktop identity tests

**Files:**
- Create: `sms-sync/desktop/main/services/device-identity.js`
- Create: `sms-sync/desktop/test/services/device-identity.test.js`
- Modify: `sms-sync/desktop/main/app.js`

**Step 1: Write the failing test**

Cover:
- stored UUID is reused
- missing ID creates and persists a UUID
- runtime connection ID is distinct from canonical `deviceId`

**Step 2: Run test to verify it fails**

Run: `npm test -- test/services/device-identity.test.js`

Expected: FAIL because no desktop identity service exists and canonical identity is not persisted.

**Step 3: Write minimal implementation**

Create a desktop identity service backed by `electron-store` and wire it into app startup and payload creation.

**Step 4: Run test to verify it passes**

Run: `npm test -- test/services/device-identity.test.js`

Expected: PASS

### Task 4: Add server identity tests

**Files:**
- Modify: `sms-sync/server/presence-state.js`
- Modify: `sms-sync/server/index.js`
- Modify: `sms-sync/server/test/presence-state.test.js`

**Step 1: Write the failing test**

Cover:
- registration preserves canonical `deviceId`
- connection metadata can vary without creating a second device record
- invalid `deviceId` registration is ignored

**Step 2: Run test to verify it fails**

Run: `node --test test/presence-state.test.js`

Expected: FAIL because connection identity is not explicitly modeled or validated yet.

**Step 3: Write minimal implementation**

Normalize registration handling so `deviceId` remains the canonical key and `connectionId` is stored only as per-socket/session metadata.

**Step 4: Run test to verify it passes**

Run: `node --test test/presence-state.test.js`

Expected: PASS

### Task 5: Inspect live server before applying server deployment changes

**Files:**
- Inspect only: remote host `111.228.32.128`

**Step 1: SSH into the host and inspect the live process**

Run: `ssh 111.228.32.128 "pm2 status && pm2 show sms-sync-server"`

Expected: identify the actual process name and deployment path, or confirm the matching PM2 app is absent.

**Step 2: Pull back current deployed server files**

Run a read-only archive/listing command over SSH and compare against `sms-sync/server`.

Expected: local understanding of live server state before deploying repository changes.

### Task 6: Wire identity into production paths and verify

**Files:**
- Modify: `sms-sync/mobile/lib/ui/home/home_setup_coordinator.dart`
- Modify: `sms-sync/mobile/lib/background/background_runtime.dart`
- Modify: `sms-sync/mobile/lib/services/settings_repository.dart`
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/MainActivity.kt`
- Modify: `sms-sync/desktop/main/app.js`
- Modify: `sms-sync/server/index.js`
- Modify: `README.md`
- Modify: `AGENTS.md` if command or structure rules change

**Step 1: Implement the smallest changes needed to use the new identity services everywhere**

Use canonical `deviceId` for:
- register payloads
- presence payloads
- local UI display
- message IDs where device identity is embedded

**Step 2: Run targeted verification**

Run:
- `cd sms-sync/mobile && flutter test test/services/device_id_service_test.dart`
- `cd sms-sync/desktop && npm test -- test/services/device-identity.test.js test/transport/websocket-client.test.js`
- `cd sms-sync/server && node --test test/presence-state.test.js`

Expected: PASS

**Step 3: Deploy server after SSH inspection**

Use the existing remote deployment flow based on the inspected live directory and `deploy.sh`.

**Step 4: Re-run deployment checks**

Run remotely:
- `pm2 status`
- `pm2 logs sms-sync-server --lines 50`

Expected: service online without registration or presence errors.
