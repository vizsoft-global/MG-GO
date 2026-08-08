#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/prod.json}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

"$(dirname "$0")/check_release_keystore.sh"

flutter build apk \
  --dart-define-from-file="$ENV_FILE" \
  --release \
  "$@"

APK="build/app/outputs/flutter-apk/app-release.apk"
echo "APK (local/MDM test only — distribute via Play Store for production): $APK"
"$(dirname "$0")/verify_apk_signing.sh" "$APK"
