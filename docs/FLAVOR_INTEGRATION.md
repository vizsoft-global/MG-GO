# Production stack integration matrix

Every driver-facing backend call routes through [`lib/core/config/env.dart`](../lib/core/config/env.dart). Build-time config comes from `env/prod.json` (`--dart-define-from-file`). At startup, `Env.validateConfiguration()` rejects non-production Supabase or Admin URLs.

## Stack (single production)

| Layer | Value |
|-------|--------|
| Supabase | `eoksxkdssptgyqyywdju` |
| Admin API | `https://dpdadmin-prod.vercel.app` |
| Firebase (native) | `musallam-delivery-prod` — Gradle file is `android/app/google-services.json` (not `src/main/`) |
| R2 (via admin) | `dpd-private-prod` |
| `applicationId` | `com.musallam_delivery.app` (do not change) |

Distribution is **Google Play only**. There are no Android product flavors, no in-app APK / sideload OTA, and no separate app-update channels in this app.

External testing infrastructure may still exist outside this repo; the **driver app no longer targets it**.

## Feature → auth → endpoint

| Feature | Auth | Transport | Config source |
|---------|------|-----------|---------------|
| **Passcode login** | Edge function (no session yet) | `Supabase.functions.invoke('driver-passcode-login')` | `Env.supabaseUrl` / anon key |
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

## Infra checklist (production)

- [ ] Edge function `driver-passcode-login` deployed on prod Supabase
- [ ] Admin `dpdadmin-prod` CORS / `DRIVER_APP_ORIGINS` configured
- [ ] R2 bucket `dpd-private-prod` matches admin env
- [ ] Firebase Admin on `dpdadmin-prod` matches `musallam-delivery-prod`
- [ ] Drivers exist on prod Supabase

## Common misconfiguration symptoms

| Symptom | Likely cause |
|---------|----------------|
| App throws at startup | `env/prod.json` points at testing Supabase or non-prod admin |
| Login works, uploads return 401/403 | Admin JWT audience mismatch (wrong admin deployment) |
| FCM never arrives | `android/app/google-services.json` is `musallam-delivery-kw` (Gradle ignores `src/main/`); Admin JWT invalid (`app/invalid-credential`) |
| App shows the block screen on launch | Android Developer options are enabled — turn them off in phone Settings |
