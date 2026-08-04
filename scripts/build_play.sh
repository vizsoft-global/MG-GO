#!/usr/bin/env bash
set -euo pipefail

# Play Store AAB — sideload / in-app APK OTA fully removed.

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/prod.json}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  echo "Copy env/prod.json.example to env/prod.json and set the prod SUPABASE_ANON_KEY." >&2
  exit 1
fi

"$(dirname "$0")/check_release_keystore.sh"

flutter build appbundle \
  --flavor prod \
  --dart-define-from-file="$ENV_FILE" \
  --release \
  "$@"

AAB="build/app/outputs/bundle/prodRelease/app-prod-release.aab"
echo "AAB: $AAB"
echo "Sideload OTA is disabled in code. Install packages permission is not declared."
