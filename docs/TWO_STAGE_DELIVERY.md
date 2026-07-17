# Two-Stage Delivery + In/Out Lock

## Delivery flow

1. **Pickup** (`/deliveries/add`) — order ID, pickup photo, GPS, restaurant/zone proximity gate → RPC `driver_create_pickup` → status `in_transit`.
2. **Active delivery** (`/deliveries/active`) — shows in-progress order; rider chooses **Mark as Delivered** or **Cancel Order**.
3. **Finish** (`/deliveries/finish/:id`) — delivery/cancel photo + GPS (no proximity gate) → RPC `driver_complete_delivery` or `driver_cancel_delivery`.

Only one `in_transit` delivery per rider at a time.

## Cancel reasons

Stored in `deliveries.cancel_reason` as `code|optional note`:

- `customer_no_show`
- `customer_refused`
- `wrong_address`
- `restaurant_issue`
- `accident`
- `other`

Cancelled deliveries are kept for audit and excluded from incentive counts server-side.

## GPS enrichment

Every `driver_report_location` report may include:

- heading, altitude, network type, charging state, mock flag, location provider
- `active_delivery_id` (from SharedPreferences while an order is in progress)

Background isolate reads `active_delivery_id` via `DutySessionStorage`.

## In / Out (driver UI)

The app shows **In** / **Out** for duty state (backend fields remain `is_online`, `is_on_duty`).

- **In** → opens `driver_sessions`, sets `went_online_at`, writes `attendance_logs.check_in_at`, accumulates `driver_attendance.online_seconds`
- **Out** → closes session, sets `check_out_at`, stops GPS foreground service

**Work time** (`online_seconds`) is shown as **Time in** on the home weekly card and per-day on attendance.

**Network offline** (`offlineMode`, `OfflineBanner`) is separate — connectivity, not duty state.

## Daily shift gate (mandatory)

Drivers must submit a shift **for each working period**. A shift is active from its start until `shift_end_at` (supports overnight, e.g. 27th 21:00 → 28th 06:00).

| Situation | Behavior |
|-----------|----------|
| No active shift | **In** blocked → mandatory shift sheet (non-dismissible) |
| Active shift, before end | **In/Out** allowed freely (including before declared start time) |
| After `shift_end_at` | Shift expires → must submit a **new** shift before **In** again |
| Same calendar date after end | Re-submit allowed (upsert replaces the expired row) |

Backend: `_driver_find_active_shift` returns a row only while `now() < shift_end_at` (today **and** yesterday overnight rows).

App: `ensureOnDutyForAction` refreshes shift state, clears expired cache, and shows the mandatory sheet when needed.

## Shift adherence

Compare actual In/Out vs submitted shift (session 1 start, last session end for split shifts):

- Returned as `shift_adherence` on `driver_get_home_dashboard` (today) and each row of `driver_get_attendance`
- Uses active overnight shift when attendance falls on the next calendar day
- Home shows a compact card when clocked in today (late / early / on time)
- Attendance month grid shows a short label under days with shift + clock events

## GPS zone tracking

Every `driver_report_location` sets:

- `zone_status`: `in_zone` | `out_of_zone` | `unknown`
- `in_range` boolean

While **In**, the app shows:

- A **10-minute countdown banner** when out of zone (`zone_monitor_provider`)
- A **zone status chip** on home from the latest location report

Admin can audit via `driver_location_history.zone_status`.

## In lock (Android)

When `isOnlineOnDuty`:

- `DutyOverlayController` shows a **floating bubble** (app icon) when the rider backgrounds the app. Tap the bubble to return; drag to reposition. The app is **not** force-returned automatically.
- Pressing **back** while In **minimizes** the app (`moveTaskToBack`) instead of closing it.
- A full-screen GPS lock overlay appears if location services are disabled.
- Requires `SYSTEM_ALERT_WINDOW` — checked in the duty readiness sheet.

The duty readiness sheet shows a **count summary** for completed checks and lists **only missing** permissions.

## Database migrations

Apply admin migrations:

- `dpdadmin/supabase/migrations/20260701100000_two_stage_delivery_and_gps_signals.sql`
- `dpdadmin/supabase/migrations/20260705110000_driver_shift_adherence.sql`
- `dpdadmin/supabase/migrations/20260706100000_driver_active_shift_expiry.sql`

## Offline queue

SQLite tables:

- `pending_pickups` — synced first via `driver_create_pickup`
- `pending_completions` — synced after pickup; `outcome` = `delivered` | `cancelled`

Legacy `pending_deliveries` rows still sync via the deprecated two-step shim.

## Deprecated RPC

`driver_create_delivery` remains as a shim (pickup + complete in one call) for one release.

## Sideloaded Android updates

Drivers on Android receive in-app update prompts when a newer APK is marked **active** in the admin panel.

1. Admin uploads APK under **Settings → App Releases** (super admin).
2. Admin clicks **Activate** on the target version for the `production` channel.
3. On launch (and on resume), the app calls `GET /api/driver-app/active-release` with the driver session token.
4. If `version_code` is newer than the installed build, the app shows an update sheet.
5. **Optional** updates can be dismissed once per session; **required** updates (or builds below `min_supported_version_code`) block the app until installed.
6. The APK downloads to device cache, SHA256 is verified, then Android's package installer opens.

Apply admin migration `20260707110000_app_releases.sql`.

Requirements:

- Same release keystore for every build (Android rejects certificate changes). Setup: `docs/RELEASE_PROCESS.md` section 4, keystore at `~/musallam-release.jks`, config in `android/key.properties`.
- `REQUEST_INSTALL_PACKAGES` permission — user must allow "Install unknown apps" once.
- Beta/internal channels: dev flavor seeds `app_update_channel` to `internal`; prod flavor seeds `production`. Override anytime via SharedPreferences key `app_update_channel`.
