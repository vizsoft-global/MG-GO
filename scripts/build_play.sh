#!/usr/bin/env bash
set -euo pipefail

# Play Store AAB — no REQUEST_INSTALL_PACKAGES, OTA compiled off (SIDELOAD_OTA=false).
# Before upload: turn Admin → Settings → Driver App → Sideload updates OFF.

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/prod.json}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  echo "Copy env/prod.json.example to env/prod.json and set the prod SUPABASE_ANON_KEY." >&2
  exit 1
fi

"$(dirname "$0")/check_release_keystore.sh"

flutter build appbundle \
  --flavor prodPlay \
  --dart-define-from-file="$ENV_FILE" \
  --dart-define=SIDELOAD_OTA=false \
  --release \
  "$@"

AAB="build/app/outputs/bundle/prodPlayRelease/app-prodPlay-release.aab"
echo "AAB: $AAB"
echo "Verify merged manifest has NO android.permission.REQUEST_INSTALL_PACKAGES before Play upload."
