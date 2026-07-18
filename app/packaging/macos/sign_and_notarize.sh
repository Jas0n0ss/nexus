#!/usr/bin/env bash
# Sign .app with Developer ID (hardened runtime) and notarize a .dmg.
# Invoked by CI when MACOS_CERTIFICATE_BASE64 (+ Apple API key) secrets are set.
set -euo pipefail

APP_PATH="${1:?usage: sign_and_notarize.sh <App.app> <Out.dmg>}"
DMG_PATH="${2:?usage: sign_and_notarize.sh <App.app> <Out.dmg>}"
ENTITLEMENTS="${ENTITLEMENTS:-app/packaging/macos/Runner.entitlements}"

: "${MACOS_CERTIFICATE_BASE64:?}"
: "${MACOS_CERTIFICATE_PASSWORD:?}"
: "${APPLE_TEAM_ID:?}"
: "${APPLE_API_KEY_BASE64:?}"
: "${APPLE_API_KEY_ID:?}"
: "${APPLE_API_ISSUER_ID:?}"

IDENTITY="${MACOS_SIGNING_IDENTITY:-Developer ID Application}"
KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/nexus-signing.keychain-db"
KEYCHAIN_PASS="$(openssl rand -base64 32)"
API_KEY_PATH="${RUNNER_TEMP:-/tmp}/AuthKey_${APPLE_API_KEY_ID}.p8"

cleanup() {
  security delete-keychain "$KEYCHAIN_PATH" 2>/dev/null || true
  rm -f "$API_KEY_PATH"
}
trap cleanup EXIT

echo "🔐 Importing Developer ID certificate…"
security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"

echo "$MACOS_CERTIFICATE_BASE64" | base64 --decode > /tmp/macos-cert.p12
security import /tmp/macos-cert.p12 -k "$KEYCHAIN_PATH" -P "$MACOS_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productsign
rm -f /tmp/macos-cert.p12

security list-keychain -d user -s "$KEYCHAIN_PATH" $(security list-keychain -d user | tr -d '"')
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "$KEYCHAIN_PASS" "$KEYCHAIN_PATH" >/dev/null

# Resolve full identity name
SIGN_ID=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" \
  | awk -F'"' '/Developer ID Application/{print $2; exit}')
if [ -z "$SIGN_ID" ]; then
  SIGN_ID=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" \
    | awk -F'"' '/'"$IDENTITY"'/{print $2; exit}')
fi
[ -n "$SIGN_ID" ] || { echo "❌ No Developer ID Application identity in keychain"; exit 1; }
echo "✍️  Signing identity: $SIGN_ID"

echo "🔏 codesign (deep, hardened runtime)…"
# Sign nested Mach-Os first (Flutter frameworks / helpers)
find "$APP_PATH" -type f \( -name "*.dylib" -o -name "*.so" -o -name "sing-box" \) -print0 \
  | while IFS= read -r -d '' f; do
      codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$f" || true
    done
find "$APP_PATH/Contents/Frameworks" -name "*.framework" -maxdepth 2 -print0 2>/dev/null \
  | while IFS= read -r -d '' fw; do
      codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$fw" || true
    done

codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_ID" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute -vv "$APP_PATH" 2>&1 || \
  echo "⚠️  spctl assess before notarization may fail; continuing to notarize"

echo "📦 Building DMG…"
VERSION_LABEL="$(basename "$DMG_PATH" .dmg)"
rm -f "$DMG_PATH"
create-dmg \
  --volname "Nexus VPN" \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "$(basename "$APP_PATH")" 160 190 \
  --app-drop-link 380 190 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$APP_PATH" || {
    STATUS=$?
    [ $STATUS -eq 2 ] || exit $STATUS
  }

echo "🔏 codesign DMG…"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG_PATH"

echo "☁️  Notarizing with notarytool…"
echo "$APPLE_API_KEY_BASE64" | base64 --decode > "$API_KEY_PATH"
# notarytool expects key in a specific layout or --key path
xcrun notarytool submit "$DMG_PATH" \
  --key "$API_KEY_PATH" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --wait

echo "📎 Stapling ticket…"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "✅ Signed + notarized: $DMG_PATH"
