# Desktop Update Route Picker Design

**Date:** 2026-04-01

## Goal

Restore desktop update route selection so users can explicitly choose between the default installer package and any Ops-provided mirror URL each time they download a new desktop release.

## Confirmed Decisions

- Route selection happens when the user clicks the desktop download button.
- The picker remains a lightweight modal instead of a persistent selector in the update panel.
- The default installer package must be selectable alongside any mirror routes.
- Mirror download failures must not auto-fallback to another route.

## Existing State

The desktop client already contains most of the route-picker plumbing:

- `main/services/update-service.js` normalizes mirror routes from `download_sources` and `download_urls`
- `preload.js`, `main/ipc.js`, and `main/app.js` already accept `downloadUpdate(selectedUrl)`
- `renderer/app.js` already opens a route picker modal when multiple routes are present
- `index.html` and `renderer/styles.css` already include the modal shell and styles

What is missing is the default installer package as a first-class selectable route. Right now, `downloadOptions` only reflects Ops mirror fields, so the route picker omits the main package URL.

## Chosen Approach

Treat the primary release download URL as the canonical “default installer package” option and include it in `latestRelease.downloadOptions` before any mirror-derived routes.

That keeps route selection fully data-driven:

- the Electron main process owns normalized update metadata
- the renderer only displays what the main process exposes
- existing download IPC continues to pass one selected URL back to the main process

## Data Model Changes

`latestRelease.downloadOptions` will be built with this order:

1. Primary installer URL from `latestRelease.downloadUrl`
2. Structured Ops routes from `download_sources`
3. Plain URL list routes from `download_urls`

Each option keeps the existing shape:

- `url`
- `label`
- `host`

Label rules:

- The primary installer URL is labeled `默认安装包`
- Ops-provided names still win for mirror routes
- If Ops does not provide a label, fallback remains host or URL

Deduplication rules:

- URLs are deduplicated after normalization
- If the default installer URL is the same as an Ops `local` route, only one option is shown
- The default option wins in that case so the user sees `默认安装包` instead of a duplicate `local`

## Desktop Flow

### Update Check

1. The renderer triggers `checkForUpdates()`
2. `DesktopUpdateService` fetches the latest release metadata
3. The service normalizes:
   - `downloadUrl`
   - `downloadOptions` including the default installer package
4. The update state is emitted to the renderer

### Download Start

1. User clicks `下载并安装`
2. Renderer reads `latestRelease.downloadOptions`
3. If exactly one route exists, download begins immediately
4. If multiple routes exist, the existing modal is shown
5. User selects one route or cancels
6. The selected route URL is sent through existing IPC to `downloadUpdate(selectedUrl)`
7. Main process downloads exactly that URL

### Download Failure

- The state becomes `error`
- The latest release metadata remains available
- The user can click download again and re-open the picker
- No silent mirror switching occurs

## UI Changes

The existing modal shell stays in place.

Small UI adjustment:

- Update the modal subtitle to mention both the default package and mirror routes, so the choice is clear to users.

No permanent new controls are needed in the update panel.

## Error Handling

- If the release has only the default installer URL, the modal is skipped
- If all mirror fields are empty but the primary URL exists, downloading still works through that single default route
- If the selected route fails, show the existing update error message and preserve release metadata for retry

## Testing Strategy

Add or update desktop tests to cover:

- primary installer URL is inserted into `downloadOptions`
- primary installer URL is labeled `默认安装包`
- duplicate primary/mirror URLs collapse to one option
- selected route download still honors the chosen mirror URL

Existing renderer layout tests should continue to verify the modal shell is present.

## Expected Outcome

After the change, desktop update downloads behave like the intended design:

- users can choose the default package or any mirror route
- the picker appears only when there is a meaningful choice
- the Electron main process remains the single source of truth for update route metadata
