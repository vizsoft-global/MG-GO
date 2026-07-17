#!/usr/bin/env bash
# Pre-flight: ensure release signing config exists before building/publishing.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEY_PROPS="$APP_DIR/android/key.properties"
EXAMPLE="$APP_DIR/android/key.properties.example"

if [[ ! -f "$KEY_PROPS" ]]; then
  echo "Missing $KEY_PROPS" >&2
  echo "Copy $EXAMPLE to key.properties and set storePassword, keyPassword, storeFile." >&2
  exit 1
fi

STORE_FILE="$(grep -E '^storeFile=' "$KEY_PROPS" | cut -d= -f2- | tr -d '[:space:]')"
if [[ -z "$STORE_FILE" || ! -f "$STORE_FILE" ]]; then
  echo "Keystore not found at storeFile=$STORE_FILE (from $KEY_PROPS)" >&2
  echo "The release keystore must exist at the path in key.properties (default: ~/musallam-release.jks)." >&2
  exit 1
fi

echo "OK: release keystore configured ($STORE_FILE)"
