#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/dev.json}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

"$(dirname "$0")/check_release_keystore.sh" || true

flutter build apk \
  --flavor dev \
  --dart-define-from-file="$ENV_FILE" \
  --release \
  "$@"

APK="build/app/outputs/flutter-apk/app-dev-release.apk"
echo "APK (local QA only — not for Play OTA): $APK"
