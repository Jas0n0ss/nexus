#!/usr/bin/env bash
# Generate an Android upload/release keystore and print base64 for GitHub Secrets.
set -euo pipefail
OUT_DIR="${1:-.secrets}"
ALIAS="${ANDROID_KEY_ALIAS:-nexus}"
PASS="${ANDROID_KEYSTORE_PASSWORD:-$(openssl rand -base64 18)}"
mkdir -p "$OUT_DIR"
STORE="$OUT_DIR/nexus-release.p12"
rm -f "$STORE" "$OUT_DIR/keystore.b64"

keytool -genkeypair -v \
  -storetype PKCS12 \
  -keystore "$STORE" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=Nexus, OU=Mobile, O=Nexus, L=Internet, ST=NA, C=US"

base64 -w0 "$STORE" > "$OUT_DIR/keystore.b64"
cat > "$OUT_DIR/github-secrets.env" <<EOF
# gh secret set ANDROID_KEYSTORE_BASE64 < $OUT_DIR/keystore.b64
ANDROID_KEYSTORE_PASSWORD=$PASS
ANDROID_KEY_ALIAS=$ALIAS
ANDROID_KEY_PASSWORD=$PASS
EOF

echo "✅ Wrote $STORE"
echo "✅ Base64: $OUT_DIR/keystore.b64"
echo "✅ Values: $OUT_DIR/github-secrets.env"
echo
echo "Upload (requires repo admin token):"
echo "  gh secret set ANDROID_KEYSTORE_BASE64 < $OUT_DIR/keystore.b64"
echo "  gh secret set ANDROID_KEYSTORE_PASSWORD --body '$PASS'"
echo "  gh secret set ANDROID_KEY_ALIAS --body '$ALIAS'"
echo "  gh secret set ANDROID_KEY_PASSWORD --body '$PASS'"
