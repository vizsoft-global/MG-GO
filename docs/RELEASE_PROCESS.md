# Release process (Musallam driver app)

Distribution is **Google Play only**, on a **single release channel** (`production`).
In-app APK / sideload OTA, `REQUEST_INSTALL_PACKAGES`, the admin **App Releases**
uploader, and the beta / internal channels were all removed for Play Store policy.

The app also **refuses to run while Android Developer options are enabled**.

---

## 1. Environment separation — THE critical rules

There are two completely separate stacks. They do **not** share a database and
do **not** share an R2 bucket. Never assume "shared".

| Thing                 | Dev / testing                         | Production                                  |
| --------------------- | ------------------------------------- | ------------------------------------------- |
| Flavor                | `dev`                                 | `prod`                                      |
| App env file          | `env/dev.json`                        | `env/prod.json`                             |
| Supabase project      | `ytfmsgckjatiserpgdbz`                | `eoksxkdssptgyqyywdju`                      |
| Admin API base URL    | `https://dpdadmin.vercel.app`         | `https://dpdadmin-prod.vercel.app`          |
| R2 bucket             | `dpd-private`                         | `dpd-private-prod`                          |
| Firebase project      | (dev)                                 | `musallam-delivery-prod`                    |

**Backend changes must be migrated to prod too.** RPCs the app depends on must
exist in **production** Supabase, not just testing. If a feature "works on
testing but not prod", check the function/migration exists in `eoksxkdssptgyqyywdju`.

---

## 2. Versioning rules (see also AGENTS.md)

Source of truth is `pubspec.yaml`: `version: <versionName>+<versionCode>`.

- **Always bump `versionCode` by +1** for every new build. Play rejects an AAB
  whose code is <= one already uploaded.
- **Bump `versionName` only when the user explicitly asks.**

---

## 3. Release signing — required

All release builds must use the production keystore. Play upload signing depends
on it, and Android rejects certificate changes over an existing install.

### One-time setup

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

### Keystore rules

- **Same keystore for every future build.**
- **Never commit** `key.properties`, `*.jks`, or keystore passwords.

---

## 4. Publish to Google Play

```bash
cd "/Users/wb/Desktop/MG-GO userapp"

# 1. Bump versionCode in pubspec.yaml (e.g. 1.0.8+37 -> 1.0.8+38)
# 2. Make sure env/prod.json exists (gitignored; copy from env/prod.json.example)

./scripts/build_play.sh
# -> build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

Upload the AAB in the Play Console (internal testing → closed → production track
as appropriate). Drivers install and update **only** from Google Play.

For local QA builds only:

```bash
./scripts/build_dev.sh    # dev flavor APK, testing stack
./scripts/build_prod.sh   # prod flavor APK, internal testing only
```

---

## 5. Version adoption (admin)

The app still reports its installed build so admin can see adoption:

```
GET {ADMIN_API_BASE_URL}/api/driver-app/active-release
      ?platform=android&versionCode=<n>&versionName=<x.y.z>
```

That endpoint records `drivers.current_app_*` (always channel `production`) and
**always returns `null`** — it never serves an APK.

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
