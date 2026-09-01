# Mobile Update Route Picker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expose the mobile app's default APK package as a selectable update route alongside Ops mirror URLs and reuse the existing bottom sheet when multiple routes exist.

**Architecture:** Keep route normalization inside `AppUpdateService` so `AppRelease.downloadOptions` is complete before it reaches the settings UI. Reuse the existing bottom sheet, update card, and selected-option download flow; only the normalized update metadata and user-facing copy need to change.

**Tech Stack:** Flutter, Dart, `flutter_test`

---

### Task 1: Lock the mobile update-route data model with failing tests

**Files:**
- Modify: `sms-sync/mobile/test/services/app_update_service_test.dart`
- Modify: `sms-sync/mobile/lib/services/app_update_service.dart`

**Step 1: Write the failing test**

- Update the mirror normalization test to expect the primary download URL as the first option with label `默认安装包`.
- Add a test asserting when an Ops route duplicates the primary APK URL, only one option remains and keeps the default label.

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/app_update_service_test.dart`

Expected: FAIL because `downloadOptions` currently contains only mirror-derived routes.

**Step 3: Write minimal implementation**

- Normalize the primary download URL once in `_normalizeRelease(...)`.
- Prepend that normalized URL to `_normalizeDownloadOptions(...)` as `默认安装包`.
- Keep URL normalization and deduplication in one place.

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/app_update_service_test.dart`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/lib/services/app_update_service.dart sms-sync/mobile/test/services/app_update_service_test.dart
git commit -m "feat: include default mobile installer in update routes"
```

### Task 2: Clarify the route picker copy with a focused UI test

**Files:**
- Modify: `sms-sync/mobile/lib/ui/home/update_download_route_sheet.dart`
- Modify: `sms-sync/mobile/test/ui/home/update_download_route_sheet_test.dart`

**Step 1: Write the failing test**

- Update the bottom-sheet widget test to assert the copy mentions both `默认安装包` and `镜像`.

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui/home/update_download_route_sheet_test.dart`

Expected: FAIL because the subtitle currently only mentions Ops mirror routes.

**Step 3: Write minimal implementation**

- Update the bottom-sheet subtitle text to mention the default package and mirrors.
- Keep the sheet layout and selection behavior unchanged.

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui/home/update_download_route_sheet_test.dart`

Expected: PASS

**Step 5: Commit**

```bash
git add sms-sync/mobile/lib/ui/home/update_download_route_sheet.dart sms-sync/mobile/test/ui/home/update_download_route_sheet_test.dart
git commit -m "test: clarify mobile update route picker copy"
```

### Task 3: Verify the mobile update flow

**Files:**
- No code changes required unless verification reveals a defect.

**Step 1: Run focused mobile tests**

Run: `flutter test test/services/app_update_service_test.dart test/ui/home/update_download_route_sheet_test.dart`

Expected: PASS

**Step 2: Run mobile analyze**

Run: `flutter analyze`

Expected: PASS

**Step 3: Manual verification**

- Check updates when only the default APK URL exists and confirm download starts directly.
- Check updates when default + mirrors exist and confirm the bottom sheet appears.
- Confirm `默认安装包` appears as the first option.
- Confirm choosing a mirror downloads exactly that mirror URL.
- Confirm dismissing the sheet does not start a download.

**Step 4: Commit**

```bash
git add .
git commit -m "test: verify mobile update route picker"
```
