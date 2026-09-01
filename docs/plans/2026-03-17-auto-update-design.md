# Auto Update Design

**Date:** 2026-03-17

## Goal

Add update checking and package download flows to both clients:

- desktop slug: `sms-sync`
- mobile slug: `sms-sync-mobile`

Both clients must read latest version metadata and download targets from `ops-software-download-api.zh-CN.md`.

## Confirmed Product Decisions

- Both clients check for updates once on startup.
- Both clients expose a manual "check for updates" entry in settings.
- Startup checks are silent when no update is available.
- Both clients download update packages in-app.
- Desktop downloads the Windows package and opens it after download.
- Mobile downloads the APK and then triggers Android package installation.

## API Contract

Public endpoints only:

- `GET /api/public/softwares/:slug/releases/latest`
- `GET /api/public/download/:slug/latest`

Clients use `releases/latest` to fetch structured metadata and version fields. Clients use `download/:slug/latest` as the canonical download endpoint when the response does not already expose a stable direct download URL.

Expected response handling:

- success payloads use `{ success: true, data: ... }`
- failures use `{ success: false, error: "..." }`
- download endpoints may return file bodies or `302` redirects

## Version Model

Version comparison must use both:

- `version` as semver
- `build_number` as the tiebreaker when semver is equal

Upgrade decision:

1. compare semver
2. if semver is equal, compare `build_number`
3. upgrade only when the remote release is strictly newer

If version fields are missing or malformed, clients log the problem and treat the result as "no upgrade" rather than risking a false update.

## Desktop Architecture

Desktop work stays in the Electron main process except for rendering update state.

New responsibilities:

- `update-api-client`
  - fetch latest release metadata for slug `sms-sync`
  - normalize response fields
- `update-service`
  - read current app version from Electron
  - compare local and remote versions
  - manage startup checks and manual checks
  - download installer packages to a temp directory
  - emit progress and status snapshots
  - open the downloaded package with Electron shell

Existing wiring changes:

- `main/app.js`
  - create the update service
  - trigger a silent startup check after app ready
  - register IPC handlers for check, download, and state reads
- `main/ipc.js`
  - expose new update IPC methods
- `preload.js`
  - bridge update actions and update state events
- renderer files
  - show current app version
  - show latest version when available
  - show "checking", "available", "downloading", "ready to install", and "error"
  - add manual check and download actions

Desktop package handling:

- download to a temp directory owned by the current user
- clean partial files on failure
- keep the completed file long enough to open it
- treat `.exe`, `.msi`, and similar Windows packages as launchable installers

## Mobile Architecture

Flutter owns update discovery and download state. Android native code owns APK installation.

New responsibilities:

- `app_update_service`
  - fetch latest release metadata for slug `sms-sync-mobile`
  - compare local and remote versions
  - download the APK with progress reporting
  - expose a small state model for the settings UI
- Android installation bridge
  - accept an APK path from Flutter
  - convert it to a `content://` URI via `FileProvider`
  - launch the package installer intent
  - detect or redirect missing "install unknown apps" permission when required

Existing wiring changes:

- `lib/app/service_registry.dart`
  - register update service dependencies
- `lib/ui/home/settings_tab.dart`
  - trigger startup check once during initialization
  - add manual check button
  - render update status and download progress
  - trigger install after download completes
- `android/app/src/main/kotlin/.../MainActivity.kt`
  - add method-channel handlers for install permission and APK install
- `android/app/src/main/AndroidManifest.xml`
  - add installation permission and `FileProvider`
- Android XML resources
  - add provider path config for downloaded APK files

## UI Behavior

### Startup

- app starts normally
- a delayed silent check runs once
- no toast appears when already up to date
- when a newer release is found, settings shows:
  - latest version
  - build number if present
  - download button

### Manual Check

- settings includes a "检查更新" action
- action forces a fresh request and visible state transition
- if already latest, show a clear latest-state message
- if a newer release exists, keep the release details visible for download

### Download

- while downloading, show progress percentage when available
- disable duplicate download triggers
- keep latest release details visible after failures
- allow retry without forcing another metadata request

### Install

- desktop: open the downloaded Windows package
- mobile: invoke Android package installer for the downloaded APK
- if Android blocks installation from unknown sources, redirect to the correct settings page and preserve the downloaded file for retry

## Error Handling

Update failures must never block the core SMS sync product.

Handled error classes:

- network or timeout failure
- API returns `success: false`
- malformed response payload
- download interrupted or write failure
- installer launch failure
- Android permission gate for package installation

Failure policy:

- keep the last known release metadata when possible
- clear only the broken partial download artifact
- log details locally
- show concise user-facing status in settings

## Testing Strategy

Desktop:

- unit tests for response normalization
- unit tests for semver plus build-number comparison
- unit tests for update-state transitions
- unit tests for download target selection and installer launch behavior

Mobile:

- Dart tests for metadata parsing
- Dart tests for version comparison
- Dart tests for update-state transitions and progress updates
- Android unit tests for APK install intent creation and permission branching

Manual verification:

1. startup check finds no update
2. startup check finds an update
3. manual check after startup
4. package download failure and retry
5. successful download followed by install trigger

## Non-Goals

- no server-side proxy through `sms-sync/server`
- no background auto-download without user action
- no delta patch update system
- no iOS update flow
