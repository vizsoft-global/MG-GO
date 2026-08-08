#!/usr/bin/env bash
# Fail if an APK is debug-signed. Release/MDM builds must use the production keystore.
set -euo pipefail

APK="${1:?Usage: verify_apk_signing.sh <path-to.apk>}"

if [[ ! -f "$APK" ]]; then
  echo "APK not found: $APK" >&2
  exit 1
fi

APKSIGNER=""
for dir in \
  "${ANDROID_HOME:-}/build-tools"/* \
  "$HOME/Library/Android/sdk/build-tools"/*; do
  if [[ -x "$dir/apksigner" ]]; then
    APKSIGNER="$dir/apksigner"
    break
  fi
done

if [[ -z "$APKSIGNER" ]]; then
  echo "apksigner not found (install Android SDK build-tools)." >&2
  exit 1
fi

CERTS="$("$APKSIGNER" verify --print-certs "$APK" 2>&1)" || {
  echo "apksigner verify failed for $APK" >&2
  echo "$CERTS" >&2
  exit 1
}

if echo "$CERTS" | grep -q "CN=Android Debug"; then
  echo "REFUSED: $APK is signed with the Android DEBUG certificate." >&2
  echo "Release builds require android/key.properties + ~/musallam-release.jks." >&2
  echo "See docs/RELEASE_PROCESS.md section 3 and android/key.properties.example" >&2
  exit 1
fi

if ! echo "$CERTS" | grep -q "CN=Musallam Delivery"; then
  echo "REFUSED: $APK is not signed with the Musallam release certificate." >&2
  echo "$CERTS" >&2
  exit 1
fi

echo "OK: release-signed ($APK)"
