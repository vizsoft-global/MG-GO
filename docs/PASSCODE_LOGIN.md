# Driver passcode login

## Flow

1. Driver enters **4–8 digit employee ID** and **6-digit passcode** (OTP-style boxes for passcode, shown as `XXX–XXX`) from admin.
2. App calls Edge Function `driver-passcode-login` (deployed from admin repo).
3. Function validates via RPC `driver_app_lookup_by_passcode`, mints a Supabase session, returns tokens.
4. App calls `setSession` and navigates to Home.

Admin issues passcodes when a driver becomes **active** (`/drivers/[id]` → Passcode card).

## Deploy Edge Function

From **prod** admin (`dpdadmin-prod`):

```bash
cd "../dpd adminpannel/dpdadmin-prod"
supabase functions deploy driver-passcode-login --project-ref eoksxkdssptgyqyywdju
```

Requires `SUPABASE_SERVICE_ROLE_KEY` in the Supabase project (automatic on hosted).

## Run the app

```bash
./scripts/run_prod.sh
# or:
flutter run --dart-define-from-file=env/prod.json
```

Uses `SUPABASE_URL` / `SUPABASE_ANON_KEY` from `env/prod.json` (dart-define) with
production defaults in `lib/core/config/env.dart`.

## Errors

| Message | Cause |
|---------|--------|
| Invalid employee ID or passcode | Wrong ID/PIN or driver not found |
| Account not active | Driver `status` is not `active` (no passcode yet) |

See [DRIVER_APP_HANDOFF.md](../../dpd%20adminpannel/dpdadmin/docs/DRIVER_APP_HANDOFF.md) section 2a.

## Branding & maintenance

Driver-facing logo, splash, title, and maintenance mode come from `app_settings` (admin **Settings → Driver App**). Login hint and subtitle are under **Settings → Branding**. Details: handoff doc **§9**.

## Add delivery + R2 proof

- Submit: RPC `driver_create_delivery` (mandatory order ID, GPS + optional `order_proof_url` object key)
- Photo upload: admin `/api/driver-uploads/*` (handoff **§14**); set `ADMIN_API_BASE_URL` when running the app
