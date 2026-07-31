#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/prod.json}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  echo "Copy env/prod.json.example to env/prod.json and set the prod SUPABASE_ANON_KEY." >&2
  exit 1
fi

flutter run \
  --flavor prodSideload \
  --dart-define-from-file="$ENV_FILE" \
  --dart-define=SIDELOAD_OTA=true \
  ${SENTRY_DSN:+--dart-define=SENTRY_DSN="$SENTRY_DSN"} \
  "$@"
