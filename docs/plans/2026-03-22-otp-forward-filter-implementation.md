# OTP Forward Filter Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an opt-in "forward verification-code messages only" setting on mobile and desktop, with mobile filtering send paths and desktop filtering display/alerts.

**Architecture:** Persist one local boolean setting per client, keep the wire protocol unchanged, and centralize OTP detection into shared utilities on each platform. Mobile applies the filter before UDP/WebSocket sends, while desktop applies the filter before message list updates and strong alerts.

**Tech Stack:** Flutter, SharedPreferences, Electron, electron-store, Node.js test runner, Flutter test

---

### Task 1: Document the approved design

**Files:**
- Create: `docs/plans/2026-03-22-otp-forward-filter-design.md`
- Create: `docs/plans/2026-03-22-otp-forward-filter-implementation.md`

**Step 1: Verify docs are missing**

Run: `Get-ChildItem docs/plans/2026-03-22-otp-forward-filter-*`
Expected: no files found

**Step 2: Write the approved design and implementation plan**

Include:
- behavior summary
- file-level implementation points
- test plan

**Step 3: Verify docs exist**

Run: `Get-ChildItem docs/plans/2026-03-22-otp-forward-filter-*`
Expected: both markdown files listed

### Task 2: Add a failing mobile OTP detection test

**Files:**
- Create: `sms-sync/mobile/test/services/verification_code_detector_test.dart`
- Create: `sms-sync/mobile/lib/services/verification_code_detector.dart`

**Step 1: Write the failing test**

Cover:
- detects `验证码 123456`
- rejects a plain logistics/order message with digits only
- rejects empty text

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/verification_code_detector_test.dart`
Expected: FAIL because detector file or function does not exist yet

**Step 3: Write minimal implementation**

Add a reusable detector with:
- keyword regex
- 4-8 digit regex
- `isVerificationCodeMessage(String body)`

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/verification_code_detector_test.dart`
Expected: PASS

### Task 3: Add a failing mobile settings repository test

**Files:**
- Modify: `sms-sync/mobile/test/services/settings_repository_test.dart`
- Modify: `sms-sync/mobile/lib/services/settings_repository.dart`

**Step 1: Write the failing test**

Cover:
- default `forwardVerificationCodeOnly` is `false`
- saved `true` value is returned by `loadSettings()`

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/settings_repository_test.dart`
Expected: FAIL because the new field is missing

**Step 3: Write minimal implementation**

Add:
- new preferences key
- `SyncSettings.forwardVerificationCodeOnly`
- updated `loadSettings()` and `saveSettings()`

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/settings_repository_test.dart`
Expected: PASS

### Task 4: Add a failing mobile manual-send filter test

**Files:**
- Create: `sms-sync/mobile/test/ui/home/home_action_coordinator_test.dart`
- Modify: `sms-sync/mobile/lib/ui/home/home_action_coordinator.dart`

**Step 1: Write the failing test**

Cover:
- when filter is enabled and latest SMS is not OTP, `readLatestSms()` returns a filtered status and sends nothing
- when filter is enabled and latest SMS is OTP, `readLatestSms()` sends

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui/home/home_action_coordinator_test.dart`
Expected: FAIL because filtered behavior/status does not exist

**Step 3: Write minimal implementation**

Add:
- detector dependency usage
- new `ReadLatestSmsStatus.filtered`
- filtered branch before transport send

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui/home/home_action_coordinator_test.dart`
Expected: PASS

### Task 5: Apply mobile background and UI wiring

**Files:**
- Modify: `sms-sync/mobile/lib/background/background_runtime.dart`
- Modify: `sms-sync/mobile/lib/ui/home/settings_tab.dart`
- Modify: `sms-sync/mobile/lib/ui/home_page.dart`

**Step 1: Write or extend tests first where practical**

Prefer extending coordinator/repository coverage rather than adding brittle widget tests.

**Step 2: Implement minimal wiring**

Add:
- background send-path filtering
- settings toggle load/save
- snackbar for manual filtered case
- background service refresh after toggle

**Step 3: Run focused mobile tests**

Run: `flutter test test/services/verification_code_detector_test.dart test/services/settings_repository_test.dart test/ui/home/home_action_coordinator_test.dart`
Expected: PASS

### Task 6: Add a failing desktop OTP utility test

**Files:**
- Modify: `sms-sync/desktop/test/services/message-utils.test.js`
- Modify: `sms-sync/desktop/main/services/message-utils.js`

**Step 1: Write the failing test**

Cover:
- `isVerificationCodeMessage()` accepts typical OTP text
- rejects plain numeric content without OTP keywords
- `extractVerificationCode()` returns `null` for non-OTP numeric text

**Step 2: Run test to verify it fails**

Run: `npm test -- test/services/message-utils.test.js`
Expected: FAIL because helper/functionality is missing

**Step 3: Write minimal implementation**

Add:
- strict OTP detector
- tighter extraction logic based on OTP detection

**Step 4: Run test to verify it passes**

Run: `npm test -- test/services/message-utils.test.js`
Expected: PASS

### Task 7: Add desktop settings and filtering wiring

**Files:**
- Modify: `sms-sync/desktop/main/app.js`
- Modify: `sms-sync/desktop/index.html`
- Modify: `sms-sync/desktop/renderer/app.js`

**Step 1: Add or extend tests first where practical**

Reuse existing service-level tests for detection; keep UI changes small and deterministic.

**Step 2: Implement minimal wiring**

Add:
- persisted desktop setting
- renderer toggle load/save
- filter branch in `handleSmsMessage(...)`

**Step 3: Run focused desktop tests**

Run: `npm test -- test/services/message-utils.test.js`
Expected: PASS

### Task 8: Run final verification

**Files:**
- Modify: `sms-sync/mobile/...`
- Modify: `sms-sync/desktop/...`

**Step 1: Run mobile focused verification**

Run: `flutter test test/services/verification_code_detector_test.dart test/services/settings_repository_test.dart test/ui/home/home_action_coordinator_test.dart`
Expected: PASS

**Step 2: Run desktop focused verification**

Run: `npm test -- test/services/message-utils.test.js`
Expected: PASS

**Step 3: Review diff for scope**

Run: `git diff -- docs/plans sms-sync/mobile sms-sync/desktop`
Expected: only docs plus mobile/desktop files relevant to OTP filtering
