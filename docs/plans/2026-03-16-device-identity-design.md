# Device Identity Unification Design

**Date:** 2026-03-16

## Goal

Unify all device identity handling so `deviceId` always means one thing across mobile, desktop, and server: a client-generated long-lived device identity that only changes when the user explicitly resets it.

## Confirmed Constraints

- `deviceId` represents long-lived identity.
- The identity changes only when the user explicitly resets it.
- Existing compatibility hacks must not override the new model.
- Server work must inspect the currently deployed code over SSH before modifying or deploying server changes.

## Canonical Model

### `deviceId`

- Meaning: long-lived device identity
- Scope: installation-level identity for the client
- Format: UUID v4 string
- Creation: generated locally on first startup when no stored identity exists
- Persistence:
  - mobile: `SharedPreferences`
  - desktop: `electron-store`
- Reset: explicit user action only

### `connectionId`

- Meaning: short-lived connection/session identity
- Scope: one runtime connection
- Format: runtime-generated UUID
- Persistence: none
- Usage: server logging, socket/session correlation

### `deviceName`

- Meaning: user-facing display name only
- Never used as identity or join key

### `platform`

- Meaning: device type marker
- Allowed values: `mobile`, `desktop`

## Protocol Rules

These message types must treat `deviceId` as the canonical long-lived identity:

- `register`
- `device-presence`
- `sms`
- `test`

Protocol payloads may include `connectionId` for diagnostics, but business logic must never use it as the device primary key.

## Client Rules

### Mobile

- Stop resolving canonical `deviceId` from `ANDROID_ID`, `Build.ID`, or `device_info_plus`.
- Introduce a single identity service that:
  - loads stored `deviceId`
  - validates it
  - generates and persists a UUID if missing
  - exposes reset support
- Remove platform-channel `getDeviceId` as the source of canonical identity.
- Stop using placeholder identities such as `unknown_device`.

### Desktop

- Stop using process-start `crypto.randomUUID()` as the canonical `deviceId`.
- Persist one canonical `deviceId` in `electron-store`.
- Create runtime `connectionId` separately.

## Server Rules

- `deviceId` is the device primary key.
- WebSocket objects remain transport details, not device identities.
- The server tracks:
  - `devicesById: Map<deviceId, DeviceSession>`
  - one or more sockets per device
- `connectionId` is optional protocol metadata and may be recorded for logs or diagnostics.

## Migration Rules

- No legacy hardware ID remains canonical after this change.
- If a stored identity is absent or invalid, create a new UUID and persist it.
- Invalid placeholders such as `unknown_device` are treated as missing.
- Legacy fields may be read only for one-time cleanup if required, but the resulting canonical identity must always be a UUID created or already stored by the client.

## Deployment Rule For Server

Before server code changes are deployed:

1. SSH into the deployed host using the existing host alias or host entry.
2. Inspect the live deployment directory and PM2 process details.
3. Pull back the current deployed `server` code snapshot to compare against the repository if the deployment is not a git checkout.
4. Apply the repository changes as the canonical source.
5. Deploy using the existing `sms-sync/server/deploy.sh` flow or the matching remote equivalent.

## Non-Goals

- No cross-platform account-based identity.
- No server-issued canonical device identity.
- No attempt to preserve old hardware-derived IDs as the new standard.
