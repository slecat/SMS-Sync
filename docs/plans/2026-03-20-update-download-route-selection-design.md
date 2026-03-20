# Update Download Route Selection Design

**Date:** 2026-03-20

## Goal

Optimize desktop and mobile app updates so users can manually choose one of the mirror download routes provided by Ops each time they download a newly discovered version.

## Confirmed Decisions

- Both clients continue using the Ops software download service as the update metadata source.
- Route selection happens when the user starts a download, not in advance in settings.
- Users choose manually every time a new version is downloaded.
- Only Ops-provided mirror routes are shown to users.
- `local` and any implicit default download source are not exposed as user-selectable routes.
- If Ops does not provide a human-readable route name, clients may display the host or full URL.
- Clients must not silently switch to another route if the selected route fails.

## Scope

- `sms-sync/desktop/main/services/update-service.js`
- `sms-sync/desktop/main/app.js`
- `sms-sync/desktop/main/ipc.js`
- `sms-sync/desktop/preload.js`
- `sms-sync/desktop/index.html`
- `sms-sync/desktop/renderer/app.js`
- `sms-sync/desktop/renderer/styles.css`
- `sms-sync/desktop/test/services/update-service.test.js`
- `sms-sync/mobile/lib/services/app_update_service.dart`
- `sms-sync/mobile/lib/ui/home/settings_tab.dart`
- `sms-sync/mobile/test/services/app_update_service_test.dart`
- mobile widget tests if the existing coverage pattern supports the selection dialog cleanly

## Existing Baseline

The current update flow on both clients assumes a single download target:

- desktop normalizes one `downloadUrl` and downloads it directly
- mobile normalizes one `downloadUrl` and downloads it directly

Neither client currently surfaces mirror choices from Ops, so the UI cannot distinguish multiple routes for the same release.

## API Assumptions

Clients keep using:

- `GET /api/public/softwares/:slug/releases/latest`

The latest-release payload may already expose mirror-related fields such as:

- `download_urls`
- `download_sources`

Clients should read those fields from the latest-release response and normalize them into a client-side list of selectable routes. No server change is assumed for this task.

## Data Model Changes

Both clients should expand the normalized release model from:

- `version`
- `buildNumber`
- `downloadUrl`
- `changelog`

to:

- `version`
- `buildNumber`
- `downloadUrl`
- `downloadOptions`
- `changelog`

Each `downloadOption` should include:

- `url`: the actual route URL used for download
- `label`: preferred display text from Ops when available
- `host`: a derived host name for fallback display

Normalization rules:

1. Read candidate mirror routes from `download_sources` first when that field provides structured mirror items.
2. Fall back to `download_urls` when only a plain URL list is available.
3. Ignore `local` or other non-mirror default-source entries.
4. Filter invalid, empty, or duplicate URLs.
5. If no display name exists, build the label from the URL host and keep the full URL available as secondary text.

## Desktop Design

Desktop keeps update state in the Electron main process and exposes the route list to the renderer.

Changes:

- `update-service`
  - parse mirror routes into `latestRelease.downloadOptions`
  - accept a selected route URL when starting a download
  - download exactly the route chosen by the user
- `main/app.js` and IPC wiring
  - update the `download-update` handler to receive a selected route URL
- `preload.js`
  - bridge route-aware download calls to the renderer
- renderer
  - when an update is available and the user clicks the download button:
    - show a route picker overlay
    - display one row per Ops mirror route
    - pass the selected route URL back through IPC
  - keep the existing progress and installer-launch behavior unchanged after selection

Desktop fallback behavior:

- if exactly one mirror route is available, the app may start downloading immediately without opening the picker
- if no selectable mirror routes exist, the renderer should show a clear failure message instead of attempting a default download

## Mobile Design

Flutter continues to own update discovery and download state. Route selection happens in the settings UI before download begins.

Changes:

- `app_update_service`
  - parse mirror routes into `latestRelease.downloadOptions`
  - accept the user-selected route URL in `downloadUpdate`
  - download only the selected route
- `settings_tab.dart`
  - keep the existing check-for-updates entry and main action button
  - when an update is available and the user taps the action button:
    - show a route picker dialog or bottom sheet
    - display route label plus URL
    - start the download only after the user selects one route
  - preserve the existing APK installation flow after a successful download

Mobile fallback behavior:

- if no valid mirror routes exist, show a user-facing error and keep the release metadata visible for retry after a future check
- if the selected route download fails, keep the release metadata and let the user reopen the picker on the next attempt

## UI Behavior

### Shared

- Checking for updates still happens through the existing manual and startup flows.
- Route selection is only shown when the user initiates a download for an available update.
- Route selection lists only mirror routes from Ops.
- Each route row shows:
  - a primary label
  - the full URL as secondary detail when useful

### Desktop

- Download button text stays close to the current wording.
- A lightweight modal or overlay is sufficient; no page restructure is needed.
- After selection, the existing progress bar and success/error messages remain in place.

### Mobile

- The update card stays in the settings page.
- A bottom sheet is preferred if it fits the current visual pattern; an alert dialog is acceptable if simpler.
- Progress, ready-to-install state, and install permission prompts remain unchanged after the route is chosen.

## Error Handling

- Do not auto-fallback to another route when the selected mirror fails.
- Keep the latest release metadata in memory after download failure so the user can retry.
- Treat empty or malformed route lists as a user-visible update error for the download step, not as a false "up to date" result.
- Preserve the existing network and payload validation behavior for update checks.

## Testing Strategy

Desktop:

- add unit tests for parsing `download_sources` and `download_urls`
- add unit tests for filtering `local`, invalid URLs, and duplicates
- add unit tests proving `downloadUpdate(selectedUrl)` uses the selected mirror route
- add renderer-facing tests only where existing desktop test style makes this practical

Mobile:

- add Dart tests for mirror-route normalization
- add Dart tests for invalid and duplicate route filtering
- add Dart tests proving `downloadUpdate` uses the selected route URL
- add widget or interaction tests for the route picker only if the existing Flutter test setup already supports that flow without large new scaffolding

## Non-Goals

- no server-side change to Ops download APIs
- no persistent per-device default route preference
- no automatic retry across multiple mirrors
- no exposure of `local` or implicit default source as a user-facing route choice
