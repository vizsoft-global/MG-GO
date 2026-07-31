# Musallam Delivery Partner (DPD Driver App)

Flutter companion app for the DPD admin panel. Drivers sign in with **driver code + 6-digit passcode** (issued in the admin panel).

## Prerequisites

- Flutter 3.11+
- Android device or emulator (Android-only app)
- **Testing** Supabase `ytfmsgckjatiserpgdbz` + admin `dpdadmin.vercel.app`
- **Production** Supabase `eoksxkdssptgyqyywdju` + admin `dpdadmin-prod.vercel.app`
- Edge Function `driver-passcode-login` deployed on **both** Supabase projects (see below)

## Configuration

Android builds use **two dimensions**: `env` (`dev` / `prod` backends) × `distribution` (`sideload` / `play`). Scripts default to `*Sideload` (in-app APK OTA + `REQUEST_INSTALL_PACKAGES`). Play Store AAB uses `prodPlay` via `scripts/build_play.sh` (no install-packages permission; `SIDELOAD_OTA=false`). Same application id — only one install at a time.

| Flavor | Launcher label | Supabase | Admin API | OTA default channel |
|--------|----------------|----------|-----------|---------------------|
| **dev** | Musallam Dev | `ytfmsgckjatiserpgdbz` | `dpdadmin.vercel.app` | `internal` |
| **prod** | Musallam Delivery | `eoksxkdssptgyqyywdju` | `dpdadmin-prod.vercel.app` | `production` |

### First-time setup

```bash
cp env/dev.json.example env/dev.json
# Edit env/dev.json — set SUPABASE_ANON_KEY from testing Supabase dashboard

cp env/prod.json.example env/prod.json
# Edit env/prod.json — set prod SUPABASE_ANON_KEY (never commit prod.json)
```

### Run (Android)

```bash
./scripts/run_dev.sh          # dev flavor → testing stack
./scripts/run_prod.sh         # prod flavor → production stack
```

Or manually:

```bash
flutter run --flavor devSideload --dart-define-from-file=env/dev.json --dart-define=SIDELOAD_OTA=true
flutter run --flavor prodSideload --dart-define-from-file=env/prod.json --dart-define=SIDELOAD_OTA=true
# Play Store AAB (no sideload OTA):
./scripts/build_play.sh
```

### Build release APK

Requires `android/key.properties` + `~/musallam-release.jks` (see `android/key.properties.example` and [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md) section 4).

```bash
./scripts/build_dev.sh        # app-dev-release.apk
./scripts/build_prod.sh       # app-prod-release.apk (MDM + prod OTA)
```

Build scripts verify the APK is **not** debug-signed before finishing.

### Publish to admin OTA

```bash
./scripts/release.sh internal --notes "QA build"              # dev flavor → testing admin
./scripts/release.sh production --flavor prod --notes "..."   # prod flavor → prod admin
```

See `env/*.json.example` for all dart-define keys. Real `env/dev.json` and `env/prod.json` are gitignored.

Full auth/endpoint matrix: [docs/FLAVOR_INTEGRATION.md](docs/FLAVOR_INTEGRATION.md).

### Verification (both flavors)

| Check | dev | prod |
|-------|-----|------|
| Login | Test driver on testing Supabase | Prod driver on prod Supabase |
| Launcher label | Musallam Dev | Musallam Delivery |
| OTA channel default | `internal` | `production` |
| Upload proof | Testing admin → R2 `dpd-private` | Prod admin → `dpd-private-prod` |
| Dev banner | Orange DEV strip + Supabase host | Hidden |

Copy the anon key from admin `.env.local` (`NEXT_PUBLIC_SUPABASE_ANON_KEY`) for the matching environment.

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

Apply admin migrations through `20260707110000_app_releases.sql` in the admin repo.

```bash
flutter run \
  --dart-define=ADMIN_API_BASE_URL=https://dpdadmin.vercel.app
```

Ensure Vercel `DRIVER_APP_ORIGINS` includes your Flutter web origin for uploads.

Deploy the edge function from the admin repo:

```bash
cd "../dpd adminpannel/dpdadmin"
supabase functions deploy driver-passcode-login --project-ref ytfmsgckjatiserpgdbz
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

- Admin panel: `../dpd adminpannel/dpdadmin`
- Handoff doc: `../dpd adminpannel/dpdadmin/docs/DRIVER_APP_HANDOFF.md`
