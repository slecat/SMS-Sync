# Auto Update Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add startup update checks plus manual update controls to desktop and mobile, downloading packages from the ops software download API and launching installation flows on each platform.

**Architecture:** Desktop uses a main-process update service that fetches release metadata, compares `version + build_number`, downloads the Windows package, and opens it. Mobile uses a Flutter update service for metadata and APK download, while Android native code handles package installation through a `FileProvider`-backed install intent.

**Tech Stack:** Electron, Node.js built-in fetch/fs/path, Flutter, Dart `HttpClient`, SharedPreferences, Android MethodChannel, Kotlin, JUnit

---

### Task 1: Lock the update API contract in tests and docs

**Files:**
- Create: `docs/plans/2026-03-17-auto-update-design.md`
- Create: `docs/plans/2026-03-17-auto-update-implementation.md`

**Step 1: Save the approved design and plan**

Write both documents with:
- startup auto-check behavior
- manual check entry in settings
- slug mapping: `sms-sync` and `sms-sync-mobile`
- version comparison rules based on `version + build_number`

**Step 2: Verify the repository paths in the plan**

Run: `rg --files sms-sync/desktop/main sms-sync/desktop/renderer sms-sync/mobile/lib sms-sync/mobile/android/app/src/main sms-sync/mobile/android/app/src/test sms-sync/mobile/test`

Expected: all file families referenced by the plan exist in the current repository.

### Task 2: Add desktop update service tests first

**Files:**
- Create: `sms-sync/desktop/main/services/update-service.js`
- Create: `sms-sync/desktop/test/services/update-service.test.js`

**Step 1: Write the failing test**

Cover:
- parses `success/data` release payloads
- treats malformed payloads as unavailable updates
- compares semver first and `build_number` second
- prefers explicit download URLs when present and otherwise falls back to `/api/public/download/sms-sync/latest`
- reports `idle -> checking -> available` and `idle -> checking -> current` transitions

**Step 2: Run test to verify it fails**

Run: `node --test test/services/update-service.test.js`

Expected: FAIL because the desktop update service does not exist yet.

**Step 3: Write minimal implementation**

Implement:
- release normalization
- local-versus-remote comparison
- state snapshot storage
- metadata check method without UI wiring

**Step 4: Run test to verify it passes**

Run: `node --test test/services/update-service.test.js`

Expected: PASS

### Task 3: Wire desktop download and renderer update controls

**Files:**
- Modify: `sms-sync/desktop/main/app.js`
- Modify: `sms-sync/desktop/main/ipc.js`
- Modify: `sms-sync/desktop/preload.js`
- Modify: `sms-sync/desktop/index.html`
- Modify: `sms-sync/desktop/renderer/app.js`
- Modify: `sms-sync/desktop/renderer/styles.css`
- Modify: `sms-sync/desktop/package.json`
- Test: `sms-sync/desktop/test/services/update-service.test.js`

**Step 1: Extend the failing desktop test for download behavior**

Add coverage for:
- download progress snapshots
- partial file cleanup on failure
- opening the downloaded installer through Electron shell
- rejecting concurrent downloads while one is active

**Step 2: Run the targeted desktop test**

Run: `node --test test/services/update-service.test.js`

Expected: FAIL because download and installer launch are not implemented.

**Step 3: Implement the main-process update wiring**

Add:
- startup silent check after `app.whenReady()`
- IPC methods for `get-update-state`, `check-for-updates`, `download-update`
- event push from main process to renderer for state changes
- temp-directory download logic using Node streams
- installer launch using Electron `shell.openPath`

**Step 4: Implement the renderer update card**

Render:
- current version
- latest version/build
- status text
- manual check button
- download/install button
- progress text

**Step 5: Run desktop verification**

Run:
- `npm test -- test/services/update-service.test.js`
- `npm run lint`

Expected: PASS

### Task 4: Add mobile update service tests first

**Files:**
- Create: `sms-sync/mobile/lib/services/app_update_service.dart`
- Create: `sms-sync/mobile/test/services/app_update_service_test.dart`
- Modify: `sms-sync/mobile/pubspec.yaml`

**Step 1: Write the failing Dart test**

Cover:
- parses `success/data` release payloads
- compares local and remote `version + build_number`
- returns `upToDate`, `available`, and `error` states
- derives the fallback download URL `/api/public/download/sms-sync-mobile/latest`
- streams download progress updates

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/app_update_service_test.dart`

Expected: FAIL because the Flutter update service does not exist yet.

**Step 3: Write minimal implementation**

Implement:
- release model normalization
- version comparison helpers
- HTTP metadata fetch
- APK download with progress callback

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/app_update_service_test.dart`

Expected: PASS

### Task 5: Add Android installer bridge tests and implementation

**Files:**
- Create: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/AppUpdateInstaller.kt`
- Create: `sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/AppUpdateInstallerTest.kt`
- Modify: `sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/MainActivity.kt`
- Modify: `sms-sync/mobile/android/app/src/main/AndroidManifest.xml`
- Create: `sms-sync/mobile/android/app/src/main/res/xml/update_file_paths.xml`

**Step 1: Write the failing Kotlin test**

Cover:
- builds a content URI install intent for an APK path
- includes read-permission and new-task flags
- reports when package-install permission is required on supported Android versions

**Step 2: Run test to verify it fails**

Run: `.\gradlew.bat testDebugUnitTest --tests "com.smssync.sms_sync_mobile.AppUpdateInstallerTest"`

Expected: FAIL because the installer helper and provider config do not exist.

**Step 3: Write minimal implementation**

Implement:
- `FileProvider` URI conversion
- install intent factory
- unknown-source permission check/open-settings helper
- method-channel handlers in `MainActivity`
- manifest provider and install permission entries

**Step 4: Run the Android unit test**

Run: `.\gradlew.bat testDebugUnitTest --tests "com.smssync.sms_sync_mobile.AppUpdateInstallerTest"`

Expected: PASS

### Task 6: Wire mobile settings UI and startup check

**Files:**
- Modify: `sms-sync/mobile/lib/app/service_registry.dart`
- Modify: `sms-sync/mobile/lib/ui/home/settings_tab.dart`
- Modify: `sms-sync/mobile/lib/services/settings_repository.dart`
- Modify: `sms-sync/mobile/lib/platform/channels.dart`
- Test: `sms-sync/mobile/test/services/app_update_service_test.dart`
- Test: `sms-sync/mobile/test/services/settings_repository_test.dart`

**Step 1: Add a failing UI/state test if practical, otherwise extend service tests**

Cover:
- startup check runs once from the settings surface
- manual check reuses the same service
- download status persists in widget state without blocking permission controls
- install retry remains available after permission-gated failure

**Step 2: Run targeted Flutter tests**

Run:
- `flutter test test/services/app_update_service_test.dart`
- `flutter test test/services/settings_repository_test.dart`

Expected: FAIL until UI wiring and any persisted update fields are implemented.

**Step 3: Implement mobile UI wiring**

Add:
- update section in the settings tab
- silent startup check
- manual check button
- download progress UI
- install trigger and retry messaging

**Step 4: Run mobile verification**

Run:
- `flutter test test/services/app_update_service_test.dart`
- `flutter test test/services/settings_repository_test.dart`
- `flutter analyze`

Expected: PASS

### Task 7: Run end-to-end verification for both clients

**Files:**
- Modify: `sms-sync/desktop/main/app.js`
- Modify: `sms-sync/mobile/lib/ui/home/settings_tab.dart`

**Step 1: Verify desktop**

Run:
- `cd sms-sync/desktop && npm test -- test/services/update-service.test.js`
- `cd sms-sync/desktop && npm run lint`

Expected: PASS

**Step 2: Verify mobile Flutter code**

Run:
- `cd sms-sync/mobile && flutter test test/services/app_update_service_test.dart`
- `cd sms-sync/mobile && flutter test test/services/settings_repository_test.dart`
- `cd sms-sync/mobile && flutter analyze`

Expected: PASS

**Step 3: Verify Android native installer helper**

Run: `cd sms-sync/mobile/android && .\gradlew.bat testDebugUnitTest --tests "com.smssync.sms_sync_mobile.AppUpdateInstallerTest"`

Expected: PASS

**Step 4: Manual verification checklist**

Check:
- desktop startup silently detects a newer release
- desktop manual check reports current when already updated
- desktop download opens the installer package
- mobile startup silently detects a newer release
- mobile manual check can download an APK
- mobile installation either starts or cleanly redirects to unknown-app settings
