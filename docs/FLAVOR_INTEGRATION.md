# Flavor integration matrix

Every driver-facing backend call routes through [`lib/core/config/env.dart`](../lib/core/config/env.dart). At startup, `Env.validateConfiguration()` rejects cross-wired builds (e.g. prod flavor + testing Supabase, or dev flavor + prod admin).

## Stack pairing (must match)

| Flavor | Supabase | Admin API | Firebase (native) | OTA default |
|--------|----------|-----------|---------------------|-------------|
| **dev** | `ytfmsgckjatiserpgdbz` | `dpdadmin.vercel.app` | `musallam-delivery-kw` | `internal` |
| **prod** | `eoksxkdssptgyqyywdju` | `dpdadmin-prod.vercel.app` | `musallam-delivery-prod` | `production` |

Admin JWT validation uses the Supabase project configured on that admin deployment. A dev app token sent to prod admin (or vice versa) returns **401/403** on upload and notification APIs.

## Feature → auth → endpoint

| Feature | Auth | Transport | Config source |
|---------|------|-----------|---------------|
| **Passcode login** | Edge function (no session yet) | `Supabase.functions.invoke('driver-passcode-login')` | Supabase URL from flavor (same project as anon key) |
| **Session / RPCs** | Supabase JWT | PostgREST / RPC on initialized client | Supabase URL + anon key |
| **GPS tracking (foreground)** | Supabase JWT | RPC `driver_report_location` | Supabase client |
| **GPS tracking (background)** | Stored access token | HTTP POST `{SUPABASE_URL}/rest/v1/rpc/driver_report_location` + `apikey: anon` | `Env.supabaseUrl`, `Env.supabaseAnonKey` |
| **Duty on/off (background)** | Stored access token | HTTP POST `driver_set_duty_state` | Same as GPS |
| **Order proof upload** | Bearer Supabase JWT | Admin `POST /api/driver-uploads/presign` → R2 PUT → `confirm` (proxy fallback) | `Env.adminApiBaseUrl` |
| **Avatar upload / read** | Bearer Supabase JWT | Admin `/api/driver-uploads/*` | `Env.adminApiBaseUrl` |
| **Notification inbox** | Supabase JWT | RPC `driver_list_notifications` (fallback: admin GET `/api/driver-app/notifications`) | Supabase + admin |
| **Notification images** | Bearer Supabase JWT | Admin GET `/api/driver-app/notification-media?campaignId=&role=` | `Env.adminApiBaseUrl` |
| **Notification telemetry** | Supabase JWT | RPC `record_notification_client_event` (fallback: admin POST `/api/notifications/events`) | Supabase + admin |
| **FCM token** | Supabase JWT | Upsert `driver_push_tokens` | Supabase client |
| **OTA update check** | Bearer Supabase JWT | Admin GET `/api/driver-app/active-release?channel=` | `Env.adminApiBaseUrl` + `app_update_channel` pref |

## Infra checklist (outside the app)

Verify on **both** Supabase projects and admin deployments:

- [ ] Edge function `driver-passcode-login` deployed
- [ ] Admin `DRIVER_APP_ORIGINS` / CORS allows the app (mobile uses Bearer, not browser origin — uploads still need admin CORS for direct R2 PUT when used)
- [ ] R2 bucket matches admin env (`dpd-private` vs `dpd-private-prod`)
- [ ] Firebase Admin service account on each admin matches that stack's FCM project
- [ ] Prod drivers exist only on prod Supabase; test drivers only on testing Supabase

## Common misconfiguration symptoms

| Symptom | Likely cause |
|---------|----------------|
| Login works, uploads return 401/403 | Admin URL from wrong flavor (JWT from testing Supabase sent to prod admin) |
| Login fails with valid credentials | Wrong Supabase project (driver/passcode on other env) |
| GPS stops in background after kill | Expected if token expired; foreground service uses stored token from same Supabase |
| FCM never arrives | Wrong `google-services.json` flavor or token registered on wrong Supabase project |
| OTA checks wrong channel | `app_update_channel` pref overridden; dev flavor defaults to `internal` on first launch |
| OTA missing on sideload build | Built `*Play` by mistake, or Admin Sideload updates OFF, or `SIDELOAD_OTA=false` |
| Play review sees REQUEST_INSTALL_PACKAGES | Uploaded `*Sideload` AAB/APK — use `./scripts/build_play.sh` (`prodPlay`) instead |
| Notification banner blank | Campaign has no media, driver not in `notification_dispatch_items`, or admin/media auth failure |
