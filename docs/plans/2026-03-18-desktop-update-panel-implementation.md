# Desktop Update Panel Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix desktop update checks to use the software download service and move the update controls into a standalone sidebar group.

**Architecture:** Desktop keeps using the existing `DesktopUpdateService` and renderer event flow. A tiny config module owns the default update API base URL and slug so app wiring is testable, while the HTML/CSS renderer only relocates the update controls into an independent sidebar section.

**Tech Stack:** Electron, Node.js test runner, HTML, CSS, vanilla JavaScript

---

### Task 1: Lock desktop update wiring in tests

**Files:**
- Create: `sms-sync/desktop/main/services/update-config.js`
- Create: `sms-sync/desktop/test/services/update-config.test.js`

**Step 1: Write the failing test**

Assert:
- `UPDATE_API_BASE_URL === 'http://111.228.32.128:8002'`
- `DESKTOP_UPDATE_SLUG === 'sms-sync-desktop'`

**Step 2: Run test to verify it fails**

Run: `node --test test/services/update-config.test.js`
Expected: FAIL because the config module does not exist yet.

**Step 3: Write minimal implementation**

Export the two constants from `main/services/update-config.js`.

**Step 4: Run test to verify it passes**

Run: `node --test test/services/update-config.test.js`
Expected: PASS

### Task 2: Lock the standalone update section in tests

**Files:**
- Create: `sms-sync/desktop/test/services/update-layout.test.js`
- Modify: `sms-sync/desktop/index.html`

**Step 1: Write the failing test**

Assert:
- a dedicated `updates-section` exists
- a `data-section="updates"` header exists
- `updatesContent` exists
- the legacy `update-card` markup no longer exists
- the updates section appears after the devices section

**Step 2: Run test to verify it fails**

Run: `node --test test/services/update-layout.test.js`
Expected: FAIL because the update UI is still embedded in settings.

**Step 3: Write minimal implementation**

Move the update DOM into a dedicated sidebar section and keep the existing control ids.

**Step 4: Run test to verify it passes**

Run: `node --test test/services/update-layout.test.js`
Expected: PASS

### Task 3: Wire the desktop app to the shared update config

**Files:**
- Modify: `sms-sync/desktop/main/app.js`
- Test: `sms-sync/desktop/test/services/update-service.test.js`

**Step 1: Reuse the existing update service tests**

Keep the existing update service behavior tests unchanged.

**Step 2: Implement the wiring change**

Replace the hard-coded update URL in `main/app.js` with the shared config constant.

**Step 3: Run desktop verification**

Run: `node --test test/services/update-service.test.js test/services/update-config.test.js test/services/update-layout.test.js`
Expected: PASS

### Task 4: Adjust sidebar styling for the new update group

**Files:**
- Modify: `sms-sync/desktop/renderer/styles.css`

**Step 1: Keep styles scoped**

Update CSS selectors so the standalone update section renders cleanly without the old card wrapper.

**Step 2: Run full desktop verification**

Run: `npm test -- test/services/update-service.test.js test/services/update-config.test.js test/services/update-layout.test.js`
Expected: PASS
