# Desktop Update Installer Filename Design

**Date:** 2026-03-20

**Problem**

Windows desktop auto-update downloads can be saved as `.bin` when the download URL does not end with the installer extension. When that happens, `shell.openPath()` opens the Windows "choose an app" dialog instead of launching the installer.

**Root Cause**

The desktop update service currently derives the target filename only from `latestRelease.downloadUrl`. When the server exposes a stable endpoint such as `/api/public/download/<slug>/latest`, the URL path has no extension, so the service falls back to `.bin`.

**Chosen Approach**

Use layered filename resolution in the desktop client:

1. Parse `Content-Disposition` from the download response and use its filename when present.
2. Otherwise inspect the final response URL for a filename or extension.
3. Otherwise keep the existing fallback naming behavior.

**Why This Approach**

- Fixes the current production bug without requiring server changes or deployment.
- Preserves compatibility with future installer formats such as `.msi`.
- Keeps the change isolated to `sms-sync/desktop`.

**Expected Result**

After an update finishes downloading on Windows, the file is saved with the real installer name or extension, and the installer opens directly instead of prompting the user to choose an application for a `.bin` file.

**Testing**

- Add a regression test covering a download endpoint without an extension but with `Content-Disposition: attachment; filename="SmsSyncSetup.exe"`.
- Keep existing `.exe` URL coverage passing.
- Run the desktop test suite, and at minimum the update-service tests, after implementation.
