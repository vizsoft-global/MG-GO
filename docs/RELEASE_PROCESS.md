# Release / OTA publishing process (Musallam driver app)

This is the authoritative checklist for shipping a new build of the Android
driver app and making it reach drivers via the in-app OTA updater. Read this
**before** publishing anything. Most past mistakes came from skipping the
environment-separation rules in section 2.

---

## 1. The big picture

The driver app checks for updates on every launch / resume / sign-in by calling:

```
GET {ADMIN_API_BASE_URL}/api/driver-app/active-release
      ?platform=android&channel=<channel>&versionCode=<n>&versionName=<x.y.z>
```

That endpoint:

1. Records what the phone reports into `drivers.current_app_*` (so you can debug
   what version/channel a phone is actually on).
2. Reads the active row from `app_releases` (via `driver_get_active_app_release`).
3. Returns a **presigned R2 URL** for the APK (`apk_object_key`) so the app can
   download it.

For an update to actually land, **all three** must be true in the **same**
environment:

- A row exists in `app_releases` for that `platform/channel` with `is_active = true`
  and a higher `version_code` than the phone.
- The APK object referenced by `apk_object_key` exists in **that environment's R2 bucket**.
- The app is pointed at the matching admin API / Supabase (via its flavor env file).
- **Fleet APK** = `*Sideload` flavor (`REQUEST_INSTALL_PACKAGES` + OTA). **Play Store** = `./scripts/build_play.sh` (`prodPlay`, `SIDELOAD_OTA=false`). Before Play review submit, turn Admin → Settings → Driver App → Sideload updates **OFF**.

A presigned URL is generated even if the object does **not** exist — so a
missing object shows up as a **404 at download time**, not at the API call.

---

## 2. Environment separation — THE critical rules

There are two completely separate stacks. They do **not** share a database and
do **not** share an R2 bucket. Never assume "shared".

| Thing                 | Dev / testing                         | Production                                  |
| --------------------- | ------------------------------------- | ------------------------------------------- |
| Flavor                | `dev`                                 | `prod`                                       |
| OTA channel           | `internal` (default)                  | `production`                                 |
| App env file          | `env/dev.json`                        | `env/prod.json`                              |
| Supabase project      | `ytfmsgckjatiserpgdbz`                | `eoksxkdssptgyqyywdju`                       |
| Admin API base URL    | `https://dpdadmin.vercel.app`         | `https://dpdadmin-prod.vercel.app`           |
| Admin repo (publish)  | `../dpd adminpannel/dpdadmin`         | `../dpd adminpannel/dpdadmin-prod`           |
| R2 bucket             | `dpd-private`                         | `dpd-private-prod`                           |
| Firebase project      | (dev)                                 | `musallam-delivery-prod`                     |

**Rule 1 — publish through the matching admin repo.**
`scripts/release.sh` selects the publish directory by flavor:

- `--flavor dev`  -> `DPDADMIN_DIR` (`dpdadmin`)
- `--flavor prod` -> `DPDADMIN_PROD_DIR` (`dpdadmin-prod`)

The prod default is now hard-wired to `dpdadmin-prod`. If you ever publish prod
through `dpdadmin`, the release lands in the **testing** DB + **testing** bucket
and drivers will never see it (this exact bug cost us a whole release cycle).

**Rule 2 — the publish CLI uses `.env.local` in that admin repo.**
`scripts/publish-app-release.mjs` reads `NEXT_PUBLIC_SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, and `R2_*` from the admin repo's `.env.local`.
That file decides which DB and which bucket get written. Confirm it before publishing:

```bash
grep -E 'NEXT_PUBLIC_SUPABASE_URL|R2_BUCKET_NAME' "../dpd adminpannel/dpdadmin-prod/.env.local"
# expect: eoksxkdssptgyqyywdju  +  dpd-private-prod
```

**Rule 3 — secrets are NOT recoverable from Vercel.**
`SUPABASE_SERVICE_ROLE_KEY`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` are
marked **Sensitive** in Vercel. `vercel env pull` brings them down **empty**.
You must get them from the Supabase / Cloudflare dashboards (or the user) and
write them into `dpdadmin-prod/.env.local` by hand. This file is gitignored.

**Rule 4 — backend changes must be migrated to prod too.**
RPCs the app depends on (e.g. `driver_get_extra_earnings`, incentive functions)
must exist in **production** Supabase, not just testing. If a feature "works on
testing but not prod", check the function/migration exists in `eoksxkdssptgyqyywdju`.

---

## 3. Versioning rules (see also AGENTS.md)

Source of truth is `pubspec.yaml`: `version: <versionName>+<versionCode>`.

- **Always bump `versionCode` by +1** for every new build. Android refuses to
  install an APK whose code is <= the installed one, and the OTA check compares
  `version_code` numerically.
- **Bump `versionName` only when the user explicitly asks.**
- The `version_code` / `version_name` you publish **must match** `pubspec.yaml`
  exactly (the publish CLI parses them from `--pubspec`).

---

## 4. Release signing (MDM + OTA) — required

Motorola MDM and enterprise deploy tools **reject debug-signed APKs**. All release
builds must use the production keystore.

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

### Before every build / publish

```bash
./scripts/check_release_keystore.sh          # key.properties + .jks exist
./scripts/build_prod.sh                      # or release.sh (runs checks automatically)
./scripts/verify_apk_signing.sh build/app/outputs/flutter-apk/app-prod-release.apk
```

`verify_apk_signing.sh` must show `CN=Musallam Delivery`. If it shows
`CN=Android Debug`, **do not distribute**.

### MDM rollout notes

- Package id: `kw.musallam.delivery`, prod label: **Musallam Delivery**
- Phones that had **debug-signed** installs must **uninstall** before the first
  release-signed APK (certificate change blocks upgrades)

### Keystore rules

- **Same keystore for every future build** — Android rejects APKs signed with a
  different certificate over an existing install.
- **Never commit** `key.properties`, `*.jks`, or keystore passwords.

---

## 5. Standard publish procedure

### 5a. Production release (forced/required example)

```bash
cd "/Users/wb/Desktop/dpd userapp"

# 1. Bump versionCode in pubspec.yaml (e.g. 1.0.8+35 -> 1.0.8+36)

# 2. Make sure env/prod.json exists (gitignored; copy from env/prod.json.example)

# 3. Verify the prod admin .env.local points at prod (Rule 2 grep above)

# 4. Build + publish + activate as a required update
./scripts/release.sh production --flavor prod --required \
  --notes "Short driver-facing release notes"
```

`release.sh` will: build the `prod` APK with `--dart-define-from-file=env/prod.json`,
then call the prod admin's `publish:apk`, which uploads to `dpd-private-prod`,
inserts the `app_releases` row, and activates it (deactivating the previous one).

Useful flags:

- `--required`      mark as a forced update (driver cannot skip).
- `--no-build`      reuse the already-built APK at
  `build/app/outputs/flutter-apk/app-prod-release.apk`.
- `--no-activate`   upload + register but do not flip `is_active` (stage it).
- `--dry-run`       validate only, no R2/DB writes.

### 5b. Internal/testing release

```bash
./scripts/release.sh internal --notes "What changed"
# flavor defaults to dev, channel internal, publishes to dpdadmin (testing)
```

---

## 6. Manual publish (if release.sh can't be used)

From the **correct** admin repo (prod = `dpdadmin-prod`):

```bash
cd "/Users/wb/Desktop/dpd adminpannel/dpdadmin-prod"
npm run --silent publish:apk -- \
  --apk "/Users/wb/Desktop/dpd userapp/build/app/outputs/flutter-apk/app-prod-release.apk" \
  --pubspec "/Users/wb/Desktop/dpd userapp/pubspec.yaml" \
  --channel production --required --activate \
  --release-notes "..."
```

Do **not** hand-insert an `app_releases` row and skip the upload — the row will
point at an object that isn't in the bucket and downloads will 404. The CLI does
a `HeadObject` verification after upload to prevent exactly this.

---

## 7. Verify after every publish

1. **DB row is active in the right project:**

```sql
-- against eoksxkdssptgyqyywdju (prod)
SELECT channel, version_name, version_code, is_active, is_required, apk_object_key
FROM public.app_releases
WHERE platform='android' AND channel='production'
ORDER BY version_code DESC;
```

Expect exactly one `is_active = true` row at the new `version_code`.

2. **Object exists in the bucket** — the CLI already verifies via `HeadObject`;
   if you published manually, confirm the key
   `releases/android/<channel>/musallam-<code>.apk` is present in the bucket.

3. **On a phone:** fully close (swipe from recents) and reopen the app. The check
   only fires on launch / resume / sign-in.

---

## 8. Debugging "I didn't get the update"

Work top-down:

1. **What does the phone report?** Query the prod DB:

```sql
SELECT employee_id, current_app_channel, current_app_version_code, app_version_seen_at
FROM drivers WHERE archived_at IS NULL ORDER BY app_version_seen_at DESC NULLS LAST;
```

   If `current_app_*` is recent, the phone is reaching the prod admin/DB. If it's
   stale/null, the app isn't checking (wrong admin URL, not relaunched, offline).

2. **Is there an active prod release higher than the phone's code?** (section 6 query).
   If the table is empty or the active row was published to the wrong environment,
   that's the bug — re-publish through `dpdadmin-prod` (section 4a).

3. **Does the APK object exist in `dpd-private-prod`?** If the row exists but the
   download fails with 404, the object is missing from the prod bucket (it was
   likely uploaded to the testing bucket `dpd-private`). Re-run the prod publish.

4. **Channel mismatch?** The phone's `current_app_channel` must equal the channel
   the active row is on (`production` for prod builds).

---

## 9. Security

`dpdadmin-prod/.env.local` holds the prod **service-role key** and **R2 secret**.
It is gitignored — never commit it. If these secrets are ever exposed (e.g.
pasted in chat), rotate them:

- Supabase: Project Settings -> API -> roll `service_role`.
- Cloudflare: R2 -> Manage R2 API Tokens -> revoke + recreate.

After rotating, update both `dpdadmin-prod/.env.local` and the Vercel project
env vars for `dpdadmin-prod`, then redeploy.
