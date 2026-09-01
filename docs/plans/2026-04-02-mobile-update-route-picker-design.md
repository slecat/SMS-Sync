# Mobile Update Route Picker Design

**Date:** 2026-04-02

## Goal

Restore mobile update route selection so users can explicitly choose between the default APK package and any Ops-provided mirror URL each time they download a new mobile release.

## Confirmed Decisions

- Route selection continues to happen when the user taps the mobile update download button.
- The picker remains the existing bottom sheet instead of becoming a persistent setting.
- The default APK package must be selectable alongside any mirror routes.
- Download failures must not silently switch to another mirror.

## Existing State

The mobile client already contains most of the update route flow:

- `lib/services/app_update_service.dart` normalizes release metadata and downloads the selected file
- `lib/ui/home/settings_tab.dart` already calls `_selectDownloadOption(...)` before downloading
- `lib/ui/home/update_download_route_sheet.dart` already renders the bottom sheet used for route selection

What is missing is the default APK package as a first-class selectable route. Right now `downloadOptions` only reflects Ops mirror fields, so the route picker omits the main package URL and may make the feature appear unsupported.

## Chosen Approach

Treat the primary release download URL as the canonical `默认安装包` option and prepend it to `AppRelease.downloadOptions` before any mirror-derived routes.

That keeps route selection data-driven:

- the update service remains the single source of truth for normalized release metadata
- the settings page continues to only present route choices and start the download
- the existing selected-option download flow remains unchanged

## Data Model Changes

`AppRelease.downloadOptions` will be built in this order:

1. Primary APK URL from `AppRelease.downloadUrl`
2. Structured Ops routes from `download_sources`
3. Plain URL list routes from `download_urls`

Each option keeps the existing shape:

- `url`
- `label`
- `host`

Label rules:

- The primary APK URL is labeled `默认安装包`
- Ops-provided names still win for mirror routes
- If Ops does not provide a label, fallback remains host or URL

Deduplication rules:

- URLs are deduplicated after normalization
- If the default APK URL is the same as an Ops route, only one option is shown
- The default option wins in that case so the user sees `默认安装包` instead of a duplicate route label

## Mobile Flow

### Update Check

1. The settings page triggers `checkForUpdates(...)`
2. `AppUpdateService` fetches the latest release metadata
3. The service normalizes:
   - `downloadUrl`
   - `downloadOptions` including the default APK package
4. The latest state is rendered in the update card

### Download Start

1. User taps `下载并安装`
2. `SettingsTab` reads `latestRelease.downloadOptions`
3. If exactly one route exists, download starts immediately
4. If multiple routes exist, the existing bottom sheet is shown
5. User selects one route or cancels
6. The selected option is sent back to `AppUpdateService.downloadUpdate(...)`
7. The service downloads exactly that URL

### Download Failure

- The update state becomes `error`
- The latest release metadata remains available for retry
- The user can reopen the bottom sheet and pick the same or another route manually
- No automatic mirror switching occurs

## UI Changes

The existing bottom sheet remains in place.

Small copy adjustment:

- Update the subtitle to mention both the default package and mirror addresses so the available choices are clear.

No permanent new controls are needed in the settings page.

## Error Handling

- If the release has only the default APK URL, the bottom sheet is skipped
- If all mirror fields are empty but the primary URL exists, downloading still works through that single default route
- If the selected route fails, keep the current error behavior and preserve release metadata for retry

## Testing Strategy

Add or update mobile tests to cover:

- primary APK URL is inserted into `downloadOptions`
- primary APK URL is labeled `默认安装包`
- relative primary download URLs are resolved against the API base URL
- duplicate primary/mirror URLs collapse to one option with the default label
- the route picker copy mentions both the default package and mirrors

## Expected Outcome

After the change, mobile update downloads behave like the intended design:

- users can choose the default APK package or any mirror route
- the bottom sheet appears only when there is a meaningful choice
- the update service remains the single source of truth for mobile update route metadata
