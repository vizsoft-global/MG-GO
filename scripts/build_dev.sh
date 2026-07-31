#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/dev.json}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  echo "Copy env/dev.json.example to env/dev.json and set SUPABASE_ANON_KEY." >&2
  exit 1
fi

"$(dirname "$0")/check_release_keystore.sh"

flutter build apk \
  --flavor devSideload \
  --dart-define-from-file="$ENV_FILE" \
  --dart-define=SIDELOAD_OTA=true \
  --release \
  "$@"

APK="build/app/outputs/flutter-apk/app-devSideload-release.apk"
"$(dirname "$0")/verify_apk_signing.sh" "$APK"
echo "APK: $APK"
