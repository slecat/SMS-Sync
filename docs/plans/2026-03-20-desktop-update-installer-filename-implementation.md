# Desktop Update Installer Filename Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure the Windows desktop auto-update flow saves the downloaded installer with a valid executable filename instead of falling back to `.bin` when the download endpoint lacks an extension.

**Architecture:** Keep the fix inside the desktop update service. Resolve the download filename from the HTTP response first, then from the resolved URL, and only then from the existing fallback naming logic so the install handoff remains unchanged.

**Tech Stack:** Electron main process, Node.js fetch/Response handling, Node test runner.

---

### Task 1: Add a regression test for extensionless latest-download endpoints

**Files:**
- Modify: `sms-sync/desktop/test/services/update-service.test.js`

**Step 1: Write the failing test**

Add a test that:
- checks for updates from a release payload whose `download_url` is `/api/public/download/sms-sync-desktop/latest`
- returns a download response with `Content-Disposition: attachment; filename="SmsSyncSetup.exe"`
- verifies the saved file path ends with `SmsSyncSetup.exe`

**Step 2: Run test to verify it fails**

Run: `npm test -- test/services/update-service.test.js`

Expected: the new test fails because the service currently saves the file with a `.bin` fallback.

### Task 2: Resolve installer filenames from download responses

**Files:**
- Modify: `sms-sync/desktop/main/services/update-service.js`
- Test: `sms-sync/desktop/test/services/update-service.test.js`

**Step 1: Write minimal implementation**

Update the download flow to:
- extract a filename from `Content-Disposition`
- otherwise look at `response.url`
- otherwise keep the current slug/version/build fallback

**Step 2: Run targeted tests**

Run: `npm test -- test/services/update-service.test.js`

Expected: all update-service tests pass, including the new regression test.

### Task 3: Verify desktop project checks

**Files:**
- None

**Step 1: Run desktop tests**

Run: `npm test`

Expected: all desktop tests pass.

**Step 2: Run desktop lint**

Run: `npm run lint`

Expected: no lint errors.
