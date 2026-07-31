#!/usr/bin/env bash
set -euo pipefail

# Build a release APK and publish it to a channel via the dpdadmin publish CLI.
#
# Usage:
#   scripts/release.sh <channel> [options]
#
# Channels: internal (default) | beta | production
#
# Options:
#   --flavor dev|prod   Android flavor (default: dev for internal/beta, prod for production)
#   --no-build          Skip flutter build, reuse existing APK
#   --no-activate       Upload + register only; do not make it live
#   --required          Mark the release as a required (forced) update
#   --notes "text"      Release notes shown in the driver update prompt
#   --dry-run           Validate only (no R2/DB writes); implies --no-activate
#
# Examples:
#   scripts/release.sh internal --notes "Add-delivery fixes"
#   scripts/release.sh production --flavor prod --notes "Critical fix"
#   scripts/release.sh internal --no-build --dry-run
#
# Env overrides:
#   DPDADMIN_DIR   Path to the dpdadmin Next.js app
#   ENV_FILE       Path to dart-define JSON (default env/dev.json or env/prod.json)

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$APP_DIR/pubspec.yaml"

DPDADMIN_DIR="${DPDADMIN_DIR:-$APP_DIR/../dpd adminpannel/dpdadmin}"
# Prod flavor must publish through the prod admin repo (prod Supabase + dpd-private-prod R2).
# Defaulting this to the testing dir previously caused prod releases to land in the testing DB/bucket.
DPDADMIN_PROD_DIR="${DPDADMIN_PROD_DIR:-$APP_DIR/../dpd adminpannel/dpdadmin-prod}"

CHANNEL="internal"
FLAVOR=""
DO_BUILD=1
ACTIVATE="--activate"
REQUIRED=""
NOTES=""
DRY_RUN=""

# First non-flag arg is the channel.
if [[ $# -gt 0 && "$1" != --* ]]; then
  CHANNEL="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)      FLAVOR="$2"; shift 2 ;;
    --no-build)    DO_BUILD=0; shift ;;
    --no-activate) ACTIVATE=""; shift ;;
    --required)    REQUIRED="--required"; shift ;;
    --notes)       NOTES="$2"; shift 2 ;;
    --dry-run)     DRY_RUN="--dry-run"; ACTIVATE=""; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

case "$CHANNEL" in
  internal|beta|production) ;;
  *) echo "Invalid channel '$CHANNEL' (use internal | beta | production)" >&2; exit 1 ;;
esac

if [[ -z "$FLAVOR" ]]; then
  if [[ "$CHANNEL" == "production" ]]; then
    FLAVOR="prod"
  else
    FLAVOR="dev"
  fi
fi

case "$FLAVOR" in
  dev|prod) ;;
  *) echo "Invalid flavor '$FLAVOR' (use dev | prod)" >&2; exit 1 ;;
esac

if [[ "$FLAVOR" == "prod" ]]; then
  DPDADMIN_DIR="$DPDADMIN_PROD_DIR"
  ENV_FILE="${ENV_FILE:-$APP_DIR/env/prod.json}"
else
  ENV_FILE="${ENV_FILE:-$APP_DIR/env/dev.json}"
fi

# env (dev|prod) × distribution (Sideload) — App Releases APK with OTA permission.
ANDROID_FLAVOR="${FLAVOR}Sideload"
APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-${ANDROID_FLAVOR}-release.apk"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE (required for --dart-define-from-file)." >&2
  exit 1
fi

if [[ ! -d "$DPDADMIN_DIR" ]]; then
  echo "dpdadmin repo not found at: $DPDADMIN_DIR" >&2
  echo "Set DPDADMIN_DIR / DPDADMIN_PROD_DIR to the correct path." >&2
  exit 1
fi

VERSION_LINE="$(grep -E '^version:' "$PUBSPEC" | head -1 | awk '{print $2}')"
echo "==> Driver app version: $VERSION_LINE  (channel: $CHANNEL, env: $FLAVOR, android: $ANDROID_FLAVOR)"
echo "==> Admin publish dir: $DPDADMIN_DIR"
echo "==> Env file: $ENV_FILE"

if [[ "$CHANNEL" == "production" && -z "$DRY_RUN" ]]; then
  read -r -p "About to publish $VERSION_LINE to PRODUCTION (live drivers). Continue? [y/N] " ok
  [[ "$ok" == "y" || "$ok" == "Y" ]] || { echo "Aborted."; exit 1; }
fi

"$APP_DIR/scripts/check_release_keystore.sh"

if [[ "$DO_BUILD" -eq 1 ]]; then
  echo "==> Building release APK..."
  ( cd "$APP_DIR" && flutter build apk \
      --flavor "$ANDROID_FLAVOR" \
      --dart-define-from-file="$ENV_FILE" \
      --dart-define=SIDELOAD_OTA=true \
      --release )
else
  echo "==> Skipping build (--no-build); reusing existing APK"
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found at: $APK_PATH" >&2
  exit 1
fi

"$APP_DIR/scripts/verify_apk_signing.sh" "$APK_PATH"

echo "==> Publishing via dpdadmin CLI..."
cd "$DPDADMIN_DIR"
# shellcheck disable=SC2086
npm run --silent publish:apk -- \
  --apk "$APK_PATH" \
  --pubspec "$PUBSPEC" \
  --channel "$CHANNEL" \
  ${NOTES:+--release-notes "$NOTES"} \
  $REQUIRED \
  $ACTIVATE \
  $DRY_RUN
