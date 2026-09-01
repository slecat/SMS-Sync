# Desktop Update Panel Design

**Date:** 2026-03-18

## Goal

Fix desktop update checks so they talk to the software download service, and move the desktop update controls into their own sidebar group instead of nesting them inside settings.

## Confirmed Decisions

- Desktop update metadata must come from the software download service at `http://111.228.32.128:8002`.
- The desktop software slug is `sms-sync-desktop`.
- The update UI must not live inside the settings group.
- The update UI must not live inside the online devices group.
- The update UI must remain in the left sidebar as its own independent group.
- The update group must be rendered after the online devices group, as the last sidebar group.

## Scope

- `sms-sync/desktop/main/app.js`
- `sms-sync/desktop/main/services/*`
- `sms-sync/desktop/index.html`
- `sms-sync/desktop/renderer/app.js`
- `sms-sync/desktop/renderer/styles.css`
- desktop tests only

## Approach

1. Extract desktop update defaults into a small config module so the default base URL can be tested directly.
2. Update the Electron app wiring to consume that config module instead of a hard-coded host.
3. Replace the current in-settings update card with a standalone sidebar section that keeps the same update actions and renderer state flow.
4. Add regression tests for both the config value and the independent update section markup.

## Error Handling

- Desktop update checks should continue to surface service errors in the existing update state message.
- This task only fixes the wrong endpoint wiring and the grouping/location of the UI.

## Verification

- `node --test test/services/update-service.test.js test/services/update-config.test.js test/services/update-layout.test.js`
- `npm test -- test/services/update-service.test.js test/services/update-config.test.js test/services/update-layout.test.js`
