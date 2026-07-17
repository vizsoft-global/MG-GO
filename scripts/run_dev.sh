#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/dev.json}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  echo "Copy env/dev.json.example to env/dev.json and set SUPABASE_ANON_KEY." >&2
  exit 1
fi

flutter run \
  --flavor dev \
  --dart-define-from-file="$ENV_FILE" \
  ${SENTRY_DSN:+--dart-define=SENTRY_DSN="$SENTRY_DSN"} \
  "$@"
