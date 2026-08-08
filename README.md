# Musallam Delivery Partner (DPD Driver App)

Flutter companion app for the DPD admin panel. Drivers sign in with **driver code + 6-digit passcode** (issued in the admin panel).

## Prerequisites

- Flutter 3.11+
- Android device or emulator (Android-only app)
- **Production** Supabase `eoksxkdssptgyqyywdju` + admin `dpdadmin-prod.vercel.app`
- Edge Function `driver-passcode-login` deployed on production Supabase
- Firebase project `musallam-delivery-prod`

## Configuration

Single production app — **no Android product flavors**, no separate update channels,
no in-app APK / sideload OTA. Distribution is **Google Play only**. The app
**refuses to run** when Android Developer options are enabled.

| | Value |
|--|--------|
| Launcher label | Musallam Delivery |
| `applicationId` | `com.musallam_delivery.app` |
| Supabase | `eoksxkdssptgyqyywdju` |
| Admin API | `https://dpdadmin-prod.vercel.app` |
| Firebase | `musallam-delivery-prod` |
| Env file | `env/prod.json` (dart-define source of truth) |

### First-time setup

```bash
cp env/prod.json.example env/prod.json
# Edit env/prod.json — set prod SUPABASE_ANON_KEY (never commit prod.json)

cp android/key.properties.example android/key.properties
# Point storeFile at the existing production keystore; fill passwords
```

### Run (Android)

```bash
./scripts/run_prod.sh
# or:
flutter run --dart-define-from-file=env/prod.json
```

### Build

Requires `android/key.properties` + existing production keystore (see
[docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) section 3).

```bash
./scripts/build_play.sh       # Play Store AAB → bundle/release/app-release.aab
./scripts/build_prod.sh       # signed APK for local/MDM only
```

### Updates (Google Play only)

In-app OTA / admin "App Releases" APK push is **removed**. Ship updates with
`./scripts/build_play.sh` and the Play Console.

Full auth/endpoint matrix: [docs/FLAVOR_INTEGRATION.md](docs/FLAVOR_INTEGRATION.md).

### Verification

| Check | Expected |
|-------|----------|
| Login | Prod driver on prod Supabase |
| Launcher label | Musallam Delivery |
| Stack | prod Supabase + `dpdadmin-prod` + prod Firebase |
| Distribution | Google Play only |

Copy the anon key from `dpdadmin-prod` `.env.local` (`NEXT_PUBLIC_SUPABASE_ANON_KEY`).

## Passcode login

See [docs/PASSCODE_LOGIN.md](docs/PASSCODE_LOGIN.md).

## Two-stage delivery

See [docs/TWO_STAGE_DELIVERY.md](docs/TWO_STAGE_DELIVERY.md).

Drivers now log deliveries in two steps:

1. **Pickup** at the restaurant (order ID, photo, GPS, proximity gate) → `driver_create_pickup`
2. **Finish** at the customer as **Delivered** or **Cancelled** (photo, GPS, optional cancel reason) → `driver_complete_delivery` / `driver_cancel_delivery`

Apply migration `20260701100000_two_stage_delivery_and_gps_signals.sql` in the admin repo.

## Add delivery (legacy note)

Drivers start from **Home** or the **Deliveries** tab (**Pickup Order** when idle, **Mark as Delivered** when an order is in progress).

- Mandatory **Order ID** at pickup
- Proof photos at pickup and finish → Cloudflare R2 via admin API
- GPS captured at pickup and finish
- **Pickup proximity gate:** enabled only when within `driver_app_delivery_proximity_meters` of the assigned zone or restaurant
- **On-duty lock (Android):** overlay keeps the app foregrounded and blocks duty when GPS is off
- **Developer options:** app hard-blocks when Developer options are ON (Play policy / anti-sideload)

Deploy the edge function from the **prod** admin repo:

```bash
cd "../dpd adminpannel/dpdadmin-prod"
supabase functions deploy driver-passcode-login --project-ref eoksxkdssptgyqyywdju
```

## Project structure

- `lib/features/splash` — 3s launch splash (`driver_app_splash_url` or bundled asset)
- `lib/features/maintenance` — Full-screen gate when driver maintenance mode is on
- `lib/core/branding` — Reads public `app_settings` (logo, title, hints, maintenance)
- `lib/features/auth` — Driver code + passcode login
- `lib/features/home` — Dashboard UI
- `lib/features/shell` — Bottom navigation (5 tabs)

## Driver app settings (admin)

Configured in the admin panel under **Settings → Driver App** (and login hint under **Settings → Branding**). The app reads row `app_settings.id = 1` at startup:

| Column | Use in app |
|--------|------------|
| `driver_app_title` | App title |
| `driver_app_logo_url` | Login & profile logo |
| `driver_app_splash_url` | Launch splash (fallback: `assets/images/splash.png`) |
| `driver_app_maintenance_mode` | Blocks app when true |
| `driver_app_maintenance_message` | Maintenance screen copy |
| `driver_app_login_hint` | Login helper text |
| `driver_app_delivery_proximity_meters` | Max meters outside zone boundary / from assigned restaurant to allow Add Delivery (`0` = disabled) |
| `app_subtitle` | Login / profile subtitle |

See handoff doc §9: `../dpd adminpannel/dpdadmin/docs/DRIVER_APP_HANDOFF.md`.

## Database

- Login: RPC `driver_app_lookup_by_passcode` + Edge Function `driver-passcode-login`
- Profile: `profiles` (`role = rider`), `drivers` (`driver_code`, `app_passcode`)
- Staff accounts (`role = staff`) cannot use this app
- Security audit events: apply `docs/20260525_driver_security_events.sql` in the
  admin Supabase project (table `driver_security_events` + RPC
  `driver_log_security_event`)

## Security hardening (driver app)

- Android secure-screen flag blocks screenshots/screen recordings while signed in
- Capture attempts are logged to `driver_security_events` (where supported)
- Developer mode checks are logged and surfaced with warning dialogs
- Mock GPS blocks sensitive actions (delivery location resolve + duty location push)
- Security events queue offline and sync automatically when connectivity returns

## Related

- Admin panel (prod): `../dpd adminpannel/dpdadmin-prod`
- Handoff doc: `../dpd adminpannel/dpdadmin/docs/DRIVER_APP_HANDOFF.md`
