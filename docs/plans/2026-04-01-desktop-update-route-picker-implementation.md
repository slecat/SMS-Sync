# Desktop Update Route Picker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expose the desktop app's default installer package as a selectable update route alongside Ops mirror URLs and use the existing route picker modal when multiple options exist.

**Architecture:** Keep route normalization in the Electron main process so `latestRelease.downloadOptions` is always complete before it reaches the renderer. Reuse the existing modal, IPC contract, and selected-URL download flow; only the normalized update metadata and route labels need to change.

**Tech Stack:** Electron, Node.js, renderer DOM scripting, `node:test`

---

### Task 1: Lock the update-route data model with failing tests

**Files:**
- Modify: `sms-sync/desktop/test/services/update-service.test.js`
- Modify: `sms-sync/desktop/main/services/update-service.js`

**Step 1: Write the failing test**

- Add a test asserting the primary `download_url` is included as the first `downloadOptions` entry with label `默认安装包`.
- Add a test asserting when an Ops route duplicates the primary installer URL, only one option remains.

**Step 2: Run test to verify it fails**

Run: `node --test test/services/update-service.test.js`

Expected: FAIL because `downloadOptions` currently contains only mirror-derived routes.

**Step 3: Write minimal implementation**

- Add the primary installer URL to `downloadOptions` before mirror normalization.
- Keep URL normalization and deduplication in one place.
- Ensure the default option label is `默认安装包`.

**Step 4: Run test to verify it passes**

Run: `node --test test/services/update-service.test.js`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/desktop/main/services/update-service.js sms-sync/desktop/test/services/update-service.test.js
git commit -m "feat: include default desktop installer in update routes"
```

### Task 2: Clarify the route picker copy and preserve existing behavior

**Files:**
- Modify: `sms-sync/desktop/index.html`
- Modify: `sms-sync/desktop/renderer/app.js`
- Modify: `sms-sync/desktop/test/services/update-layout.test.js`

**Step 1: Write the failing test**

- Add a layout test asserting the route picker subtitle mentions both the default installer package and mirror routes.

**Step 2: Run test to verify it fails**

Run: `node --test test/services/update-layout.test.js`

Expected: FAIL because the modal copy still only mentions mirror routes.

**Step 3: Write minimal implementation**

- Update the modal subtitle text in `index.html`.
- Keep renderer behavior unchanged except for any small defensive cleanup needed after the data-model change.

**Step 4: Run test to verify it passes**

Run: `node --test test/services/update-layout.test.js`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/desktop/index.html sms-sync/desktop/renderer/app.js sms-sync/desktop/test/services/update-layout.test.js
git commit -m "test: clarify desktop update route picker copy"
```

### Task 3: Verify the desktop update flow end to end

**Files:**
- No code changes required unless verification reveals a defect.

**Step 1: Run focused desktop update tests**

Run: `node --test test/services/update-service.test.js test/services/update-layout.test.js`

Expected: PASS

**Step 2: Run desktop npm tests for the same scope**

Run: `npm test -- test/services/update-service.test.js test/services/update-layout.test.js`

Expected: PASS

**Step 3: Manual verification**

- Check updates when only the default installer URL exists and confirm download starts directly.
- Check updates when default + mirrors exist and confirm the modal appears.
- Confirm `默认安装包` appears as the first option.
- Confirm choosing a mirror downloads exactly that mirror URL.
- Confirm cancelling the modal does not start a download.

**Step 4: Commit**

```bash
git add .
git commit -m "test: verify desktop update route picker"
```
