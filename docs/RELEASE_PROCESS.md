# Release process (Musallam driver app)

Distribution is **Google Play only**. In-app APK / sideload OTA, `REQUEST_INSTALL_PACKAGES`,
admin **App Releases** APK push, Android product flavors, and separate app-update
channels were removed. The app targets a **single production stack**.

The app also **refuses to run while Android Developer options are enabled**.

---

## 1. Production stack — THE critical rules

The driver app uses one live stack only:

| Thing | Production |
| ----- | ---------- |
| App env file | `env/prod.json` (build-time source of truth via dart-define) |
| Supabase project | `eoksxkdssptgyqyywdju` |
| Admin API base URL | `https://dpdadmin-prod.vercel.app` |
| Admin repo | `../dpd adminpannel/dpdadmin-prod` |
| R2 bucket | `dpd-private-prod` |
| Firebase project | `musallam-delivery-prod` |
| `applicationId` | `com.musallam_delivery.app` (**do not change**) |

External testing projects may still exist; this app **must not** point at them.
`Env.validateConfiguration()` fails fast if Supabase/Admin are not production.

**Backend RPCs/migrations the app depends on must exist on production Supabase.**

---

## 2. Versioning rules (see also AGENTS.md)

Source of truth is `pubspec.yaml`: `version: <versionName>+<versionCode>`.

- **Always bump `versionCode` by +1** for every new build. Play rejects an AAB
  whose code is <= one already uploaded.
- **Bump `versionName` only when the user explicitly asks.**

Same `applicationId` + same signing cert + increasing `versionCode` keeps
existing Play/MDM installs upgradeable in place.

---

## 3. Release signing — required (unchanged)

All release builds must use the **existing** production keystore. Do not
regenerate or replace it — certificate changes block in-place upgrades.

### One-time setup (local machine; secrets stay out of git)

| Item | Location |
|------|----------|
| Keystore file | `~/musallam-release.jks` (keep outside repo; back up in 2+ places) |
| Key alias | `musallam_delivery` |
| Credentials | `android/key.properties` (gitignored) |
| Template | `android/key.properties.example` |

```bash
cp android/key.properties.example android/key.properties
# Edit storePassword, keyPassword, storeFile (absolute path to .jks)
```

`android/app/build.gradle.kts` loads `key.properties` for `buildTypes.release`.
If the file is missing, **release builds fail** (no silent fallback to debug signing).

Gates:

```bash
./scripts/check_release_keystore.sh
./scripts/verify_apk_signing.sh build/app/outputs/flutter-apk/app-release.apk
```

### Keystore rules

- **Same keystore for every future build.**
- **Never commit** `key.properties`, `*.jks`, or keystore passwords.

---

## 4. Publish to Google Play

```bash
# 1. Bump versionCode in pubspec.yaml (e.g. 1.0.8+37 -> 1.0.8+38)
# 2. Make sure env/prod.json exists (gitignored; copy from env/prod.json.example)

./scripts/build_play.sh
# -> build/app/outputs/bundle/release/app-release.aab
```

Upload the AAB in the Play Console. Drivers install and update **only** from Google Play.

For local/MDM APK only (still production stack + production signing):

```bash
./scripts/build_prod.sh
# -> build/app/outputs/flutter-apk/app-release.apk
```

---

## 5. Version adoption (admin)

The app reports its installed build so admin can see adoption:

```
GET {ADMIN_API_BASE_URL}/api/driver-app/active-release
      ?platform=android&versionCode=<n>&versionName=<x.y.z>
```

That endpoint records `drivers.current_app_*` and **always returns `null`** —
it never serves an APK (OTA removed).

```sql
SELECT employee_id, current_app_version_code, app_version_seen_at
FROM drivers WHERE archived_at IS NULL
ORDER BY app_version_seen_at DESC NULLS LAST;
```

---

## 6. Security

`dpdadmin-prod/.env.local` holds the prod **service-role key** and **R2 secret**.
It is gitignored — never commit it. If these secrets are ever exposed (e.g.
pasted in chat), rotate them:

- Supabase: Project Settings -> API -> roll `service_role`.
- Cloudflare: R2 -> Manage R2 API Tokens -> revoke + recreate.

After rotating, update both `dpdadmin-prod/.env.local` and the Vercel project
env vars for `dpdadmin-prod`, then redeploy.
