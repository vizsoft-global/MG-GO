# Agent context — `dpd_userapp`

## App version (Musallam driver app — Android only)

The canonical source of truth is `pubspec.yaml`:

```yaml
version: 1.0.8+37
```

Mapping (Android):

| Field           | Value    | Notes                                                       |
| --------------- | -------- | ----------------------------------------------------------- |
| `versionName`   | `1.0.8`  | Marketing string. Sent as `versionName` query param.        |
| `versionCode`   | `37`     | Integer build number. Sent as `versionCode` query param.    |

### Rules for any new build the user asks me to generate

1. **Always bump `versionCode` by +1** for every new build I generate (`9 → 10 → 11 → ...`).
   Never reuse a `versionCode` — Android refuses to install an APK whose code is
   the same as or lower than what's already installed.
2. **Bump `versionName` only when the user explicitly asks** (e.g. "make this 1.0.9").
   Otherwise keep the same `versionName` and only bump the build number.
3. Update **both** values in `pubspec.yaml` (`version: <name>+<code>`).
4. After bumping, remind the user that when they upload the resulting APK in the
   admin panel (`/app-releases`), they must enter the **same** `version_code` and
   `version_name` — otherwise the adoption tracker won't match the build and
   driver phones will keep prompting (or fail to detect) the update.
5. The Flutter app calls `GET /api/driver-app/active-release` with the params
   `platform=android&channel=<channel>&versionCode=<n>&versionName=<x.y.z>` on
   every launch / resume / sign-in. That call powers the **Adoption** tab in
   admin, so `versionCode` in `pubspec.yaml` must match what's uploaded.

### Quick reference for incrementing

| Scenario                                  | Before      | After       |
| ----------------------------------------- | ----------- | ----------- |
| Routine new build (no version bump asked) | `1.0.8+37`  | `1.0.8+38`  |
| User asks for "1.0.9" release             | `1.0.8+37`  | `1.0.9+38`  |
| User asks for "1.1.0" release             | `1.0.8+37`  | `1.1.0+38`  |

## Release / OTA publishing — CRITICAL rules

Full procedure + debugging guide: **`docs/RELEASE_PROCESS.md`** (read it before publishing).

Dev/testing and production are **separate stacks** — separate Supabase DBs **and**
separate R2 buckets. Never assume they share anything.

| Thing            | Dev/testing                   | Production                          |
| ---------------- | ----------------------------- | ----------------------------------- |
| Flavor / channel | `dev` / `internal`            | `prod` / `production`               |
| App env file     | `env/dev.json`                | `env/prod.json`                     |
| Supabase project | `ytfmsgckjatiserpgdbz`        | `eoksxkdssptgyqyywdju`              |
| Admin API URL    | `dpdadmin.vercel.app`         | `dpdadmin-prod.vercel.app`          |
| Admin repo       | `../dpd adminpannel/dpdadmin` | `../dpd adminpannel/dpdadmin-prod`  |
| R2 bucket        | `dpd-private`                 | `dpd-private-prod`                  |

1. **Publish prod through `dpdadmin-prod`, never `dpdadmin`.** `scripts/release.sh`
   picks the dir by flavor (`prod` → `DPDADMIN_PROD_DIR` = `dpdadmin-prod`).
   Publishing prod through the testing repo lands the release in the testing DB +
   testing bucket and **drivers never get it** (this has already burned us once).
2. **Standard prod release:**
   `./scripts/release.sh production --flavor prod --required --notes "..."`
   (bump `versionCode` first; ensure `env/prod.json` exists).
3. **Never hand-insert an `app_releases` row without uploading the APK** to that
   environment's bucket — the presigned URL will 404 at download time. Use the
   publish CLI; it verifies the upload with `HeadObject`.
4. The publish CLI reads `.env.local` in the admin repo. The three secrets
   (`SUPABASE_SERVICE_ROLE_KEY`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`) are
   **Sensitive in Vercel and come back empty from `vercel env pull`** — they must
   be filled by hand from the Supabase/Cloudflare dashboards (or the user).
5. **Backend changes (RPCs/migrations) must be applied to prod Supabase too**, not
   just testing — otherwise a feature "works on testing but not prod".
6. **Verify after publish** (against `eoksxkdssptgyqyywdju`): exactly one
   `is_active = true` row at the new `version_code` on `channel='production'`.
7. **Debugging "didn't get the update":** check `drivers.current_app_channel` /
   `current_app_version_code` to see what the phone reports, confirm an active prod
   release exists with a higher code, and confirm the APK object is in
   `dpd-private-prod`. The update check only fires on launch/resume/sign-in.

## Android release signing — CRITICAL (MDM + OTA)

Full checklist: **`docs/RELEASE_PROCESS.md` section 4**. Cursor rule: `.cursor/rules/android-release-signing.mdc`.

1. **Never ship debug-signed APKs.** Release builds load `android/key.properties` and
   use `~/musallam-release.jks` (alias `musallam_delivery`). Gradle fails if
   `key.properties` is missing. `scripts/verify_apk_signing.sh` rejects
   `CN=Android Debug` before publish.
2. **First-time setup:** copy `android/key.properties.example` → `android/key.properties`,
   point `storeFile` at the keystore, fill passwords. Back up the `.jks` — losing it
   blocks all future updates on installed phones.
3. **Same keystore forever.** Do not regenerate the keystore unless every driver phone
   will uninstall and reinstall (certificate change blocks in-place upgrades).
4. **MDM (Motorola etc.):** upload the prod APK from
   `build/app/outputs/flutter-apk/app-prod-release.apk`. If phones had older
   **debug-signed** builds, drivers must uninstall first.
5. **Before any build/publish I generate:** run `./scripts/check_release_keystore.sh`,
   build, then confirm `verify_apk_signing.sh` passes (cert DN = `CN=Musallam Delivery`).
