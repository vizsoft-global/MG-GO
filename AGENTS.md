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
4. Ship via **Google Play only** (`./scripts/build_play.sh` → Play Console AAB).
   In-app APK OTA / admin `/app-releases` upload is permanently removed.
5. The app hard-blocks when Android Developer options are enabled (release builds).
6. **Do not change** `applicationId` (`com.musallam_delivery.app`) or regenerate
   the production keystore — both are required for in-place Play/MDM upgrades.

### Quick reference for incrementing

| Scenario                                  | Before      | After       |
| ----------------------------------------- | ----------- | ----------- |
| Routine new build (no version bump asked) | `1.0.8+37`  | `1.0.8+38`  |
| User asks for "1.0.9" release             | `1.0.8+37`  | `1.0.9+38`  |
| User asks for "1.1.0" release             | `1.0.8+37`  | `1.1.0+38`  |

## Release — CRITICAL rules

Full procedure: **`docs/RELEASE_PROCESS.md`** (Play Store only — no sideload OTA).

The driver app targets **one production stack only**. There are no Android flavors
and no separate app-update channels in this app.

| Thing            | Production                          |
| ---------------- | ----------------------------------- |
| App env file     | `env/prod.json`                     |
| Supabase project | `eoksxkdssptgyqyywdju`              |
| Admin API URL    | `dpdadmin-prod.vercel.app`          |
| Admin repo       | `../dpd adminpannel/dpdadmin-prod`  |
| R2 bucket        | `dpd-private-prod`                  |
| Firebase         | `musallam-delivery-prod`            |
| `applicationId`  | `com.musallam_delivery.app`         |

1. **Standard release:** bump `versionCode`, ensure `env/prod.json` exists, run
   `./scripts/build_play.sh`, upload AAB in Play Console.
2. **Backend changes (RPCs/migrations) must be applied to prod Supabase**
   (`eoksxkdssptgyqyywdju`).
3. OTA / `app_releases` sideload publishing is removed (`scripts/release.sh` exits).
4. External testing infra may still exist; **do not wire the app to it**.

## Android release signing — CRITICAL

Full checklist: **`docs/RELEASE_PROCESS.md` section 3**. Cursor rule: `.cursor/rules/android-release-signing.mdc`.

1. **Never ship debug-signed APKs.** Release builds load `android/key.properties` and
   use the existing keystore (documented as `~/musallam-release.jks`, alias
   `musallam_delivery`). Gradle fails if `key.properties` is missing.
   `scripts/verify_apk_signing.sh` rejects `CN=Android Debug`.
2. **First-time setup:** copy `android/key.properties.example` → `android/key.properties`,
   point `storeFile` at the keystore, fill passwords. Back up the `.jks` — losing it
   blocks all future updates on installed phones.
3. **Same keystore forever.** Do not regenerate the keystore unless every driver phone
   will uninstall and reinstall (certificate change blocks in-place upgrades).
4. **MDM:** upload `build/app/outputs/flutter-apk/app-release.apk` if needed.
   If phones had older **debug-signed** builds, drivers must uninstall first.
5. **Before any build/publish I generate:** run `./scripts/check_release_keystore.sh`,
   build, then confirm `verify_apk_signing.sh` passes (cert DN = `CN=Musallam Delivery`).
