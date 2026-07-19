#!/usr/bin/env bash
# Locally sign a macOS app when no Developer ID secrets are available.
# This adds code integrity but does NOT make Gatekeeper trust the app.
set -euo pipefail

APP_PATH="${1:?usage: sign_local.sh /path/to/Nexus.app}"
TMP_DIR="$(mktemp -d)"
KEYCHAIN="$TMP_DIR/nexus-local.keychain-db"
KEYCHAIN_PASS="$(openssl rand -hex 18)"
CERT_PASS="$(openssl rand -hex 18)"
IDENTITY="Nexus Local Build"

cleanup() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$TMP_DIR/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = extensions
prompt = no
[dn]
CN = ${IDENTITY}
O = Nexus
OU = Local CI
[extensions]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -new -newkey rsa:2048 -nodes -x509 -days 30 \
  -keyout "$TMP_DIR/key.pem" \
  -out "$TMP_DIR/cert.pem" \
  -config "$TMP_DIR/cert.conf"
openssl pkcs12 -export \
  -inkey "$TMP_DIR/key.pem" \
  -in "$TMP_DIR/cert.pem" \
  -name "$IDENTITY" \
  -passout "pass:$CERT_PASS" \
  -out "$TMP_DIR/local.p12"

security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
security import "$TMP_DIR/local.p12" \
  -k "$KEYCHAIN" -P "$CERT_PASS" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: \
  -s -k "$KEYCHAIN_PASS" "$KEYCHAIN" >/dev/null

# Sign nested executable code first, then the outer app.
while IFS= read -r -d '' item; do
  codesign --force --options runtime --timestamp=none \
    --keychain "$KEYCHAIN" --sign "$IDENTITY" "$item"
done < <(
  find "$APP_PATH" -type f \
    \( -name "*.dylib" -o -name "*.so" -o -name "sing-box" \) -print0
)

find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" -print0 2>/dev/null |
  while IFS= read -r -d '' framework; do
    codesign --force --options runtime --timestamp=none \
      --keychain "$KEYCHAIN" --sign "$IDENTITY" "$framework"
  done

codesign --deep --force --options runtime --timestamp=none \
  --keychain "$KEYCHAIN" --sign "$IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "✅ Locally signed $APP_PATH with '${IDENTITY}'"
echo "⚠️  Local certificate is not Apple-trusted; Gatekeeper warnings remain."
