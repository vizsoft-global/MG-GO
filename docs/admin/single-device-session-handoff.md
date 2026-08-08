# Single-device session — admin panel handoff

This document describes the backend and app changes for **one active device per driver**. Use it to build the admin panel **Devices** section on the driver detail page.

## Product behavior

- Each driver may be signed in on **one Android device** at a time.
- Login on a second device shows a dialog:
  - **Continue on other device** → stay on login screen; first device unchanged.
  - **Sign in here** → first device is kicked on its next heartbeat; offline queue on the old device gets a **5-minute flush grace** to upload pending pickups/completions before local sign-out.
- Admin can **Force sign-out** a stuck session from the panel.

## Database schema

### `drivers` (new columns)

| Column | Type | Notes |
|--------|------|-------|
| `active_device_id` | `text` | Stable device key (ANDROID_ID or install UUID) |
| `active_device_session_id` | `uuid` | FK → `driver_device_sessions.id` |

### `driver_device_sessions` (new table)

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` PK | Session row id |
| `driver_id` | `uuid` FK | → `drivers.id` |
| `device_id` | `text` | Stable device identifier |
| `device_model` | `text` | e.g. `SM-A546B` |
| `device_manufacturer` | `text` | e.g. `samsung` |
| `os_version` | `text` | Android release string |
| `android_sdk_int` | `integer` | API level |
| `app_version_name` | `text` | e.g. `1.0.8` |
| `app_version_code` | `integer` | e.g. `22` |
| `first_seen_at` | `timestamptz` | First login on this device |
| `last_seen_at` | `timestamptz` | Updated by heartbeat + login |
| `revoked_at` | `timestamptz` | When session ended |
| `revoked_reason` | `text` | `override` \| `manual_signout` \| `admin_forced` \| `flushed` |
| `flush_deadline_at` | `timestamptz` | Override grace deadline (5 min) |
| `flushed_at` | `timestamptz` | Old device finished offline flush |

**Indexes**

- `UNIQUE (driver_id, device_id)`
- `(driver_id, last_seen_at DESC)`

**RLS**

- Drivers: `SELECT` own rows (`driver_id = auth.uid()`).
- Admin panel users: `SELECT` / `UPDATE` via `is_admin_panel_user()`.

## RPCs (admin)

### `admin_driver_device_overview(p_driver_id uuid, p_history_limit int default 20)`

Returns:

```json
{
  "driver_id": "uuid",
  "active_device_id": "abc123...",
  "active_device": {
    "session_id": "uuid",
    "device_id": "...",
    "device_model": "SM-A546B",
    "device_manufacturer": "samsung",
    "os_version": "14",
    "android_sdk_int": 34,
    "app_version_name": "1.0.8",
    "app_version_code": 22,
    "first_seen_at": "...",
    "last_seen_at": "...",
    "revoked_at": null,
    "revoked_reason": null,
    "flush_deadline_at": null,
    "flushed_at": null,
    "is_active": true
  },
  "history": [ /* same shape, up to p_history_limit rows */ ]
}
```

**Suggested UI:** Driver detail → **Devices** tab/section

- Highlight row where `is_active = true`.
- Columns: device label (`manufacturer` + `model`), OS, app version, first/last seen, status badge.
- Status badges:
  - **Active** — `is_active && !revoked_at`
  - **Override pending flush** — `revoked_reason = 'override' && !flushed_at`
  - **Signed out** — `revoked_reason IN ('manual_signout','flushed')`
  - **Admin forced** — `revoked_reason = 'admin_forced'`

### `admin_force_sign_out_driver(p_driver_id uuid)`

Clears `drivers.active_device_id` and marks the current session `revoked_reason = 'admin_forced'`. The driver app signs out on the next heartbeat.

**Suggested UI:** Red **Force sign-out** button with confirm dialog.

## Edge function: `driver-passcode-login`

**New request body fields**

| Field | Required | Description |
|-------|----------|-------------|
| `device_id` | Yes | From app (`ANDROID_ID` or install UUID) |
| `device_meta` | No | `{ model, manufacturer, os_version, android_sdk_int, app_version_name, app_version_code }` |
| `force_override` | No | `true` to kick the other device |

**New response: HTTP 409**

```json
{
  "error": "device_conflict",
  "active_device": {
    "device_id": "...",
    "device_model": "SM-A546B",
    "device_manufacturer": "samsung",
    "last_seen_at": "2026-05-27T12:00:00Z"
  }
}
```

On success, the function also writes `device_id` into `auth.users.user_metadata.device_id` (used by the app after token refresh).

## Driver RPCs (app-side, for reference)

| RPC | Purpose |
|-----|---------|
| `driver_heartbeat(p_device_id)` | Every ~2 min + resume; returns `{ kicked, flush_grace_active, flush_deadline_at }` |
| `driver_finalize_reconciliation(p_device_id)` | Old device marks flush complete after draining offline queue |
| `driver_release_device_session(p_device_id)` | Called on manual sign-out |
| `driver_create_pickup(..., p_device_id)` | Device guard on pickup |
| `driver_complete_delivery(..., p_device_id)` | Device guard on complete |
| `driver_cancel_delivery(..., p_device_id)` | Device guard on cancel |

## Migration file

`dpdadmin/supabase/migrations/20260715100000_device_session_enforcement.sql`

Apply to production Supabase (`eoksxkdssptgyqyywdju`) before shipping the new APK.

Deploy edge function:

```bash
cd "../dpd adminpannel/dpdadmin-prod"
supabase functions deploy driver-passcode-login --project-ref eoksxkdssptgyqyywdju
```

## Admin panel implementation checklist

- [ ] Call `admin_driver_device_overview(driverId)` on driver detail load.
- [ ] Render **Devices** section with active highlight + history table.
- [ ] Add **Force sign-out** button → `admin_force_sign_out_driver(driverId)`.
- [ ] Optional: audit log entry when `revoked_reason = 'override'` (driver self-switched device).
- [ ] Optional: filter drivers with multiple devices in last 7 days.

## Test plan (QA)

1. **Conflict — continue:** Sign in on phone A. On phone B, same credentials → conflict dialog → **Continue on other device** → B stays on login; A still works.
2. **Conflict — override:** Same setup → **Sign in here** → B enters app; A gets toast and returns to login on next resume/heartbeat.
3. **Offline flush:** A offline → queue pickup → B overrides → A online → pickup appears in admin → A signs out.
4. **Admin force sign-out:** Force sign-out in panel → driver app signs out on next heartbeat.
5. **Same phone reinstall:** Same ANDROID_ID → no conflict prompt on re-login.

## Known trade-offs

- Override grace is **5 minutes**. After that, queued RPCs from the old device fail with `device_revoked`.
- We do **not** revoke Supabase refresh tokens globally (that would also invalidate the new device). Server-side `p_device_id` checks are authoritative.
- iOS is out of scope (Android-only driver app).
- Instant push kick is not implemented; heartbeat + token metadata mismatch handles detection (typically within 2 minutes).

## App version alignment

Ship the new build through Google Play (`./scripts/build_play.sh`). Drivers must be on the build that sends `device_id` on login for enforcement to apply.

## Server verification

See [server-verification-checklist.md](./server-verification-checklist.md) for RPC scoping, new security event types, and idempotency assumptions the client now depends on.
