#!/usr/bin/env bash
# Download sing-box binaries for local Flutter development / packaging.
# Usage (from repo root or app/):
#   bash app/scripts/fetch_singbox.sh
#   bash app/scripts/fetch_singbox.sh --platform macos|linux|windows|android|all
set -euo pipefail

VERSION="${SING_BOX_VERSION:-1.9.3}"
PLATFORM="${1:-}"
if [[ "${PLATFORM}" == "--platform" ]]; then
  PLATFORM="${2:-all}"
fi
PLATFORM="${PLATFORM:-all}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)" # app/
cd "$ROOT"

mkdir -p assets/cores

fetch_macos() {
  echo "↓ sing-box ${VERSION} darwin (universal)"
  curl -fsSL \
    "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-darwin-arm64.tar.gz" \
    | tar xz
  curl -fsSL \
    "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-darwin-amd64.tar.gz" \
    | tar xz
  if command -v lipo >/dev/null 2>&1; then
    lipo -create \
      "sing-box-${VERSION}-darwin-arm64/sing-box" \
      "sing-box-${VERSION}-darwin-amd64/sing-box" \
      -output assets/cores/sing-box
  else
    # Non-macOS host: keep arm64 binary for asset extract tests
    cp "sing-box-${VERSION}-darwin-arm64/sing-box" assets/cores/sing-box
  fi
  chmod +x assets/cores/sing-box
  rm -rf "sing-box-${VERSION}-darwin-arm64" "sing-box-${VERSION}-darwin-amd64"
  echo "✅ assets/cores/sing-box"
}

fetch_linux() {
  echo "↓ sing-box ${VERSION} linux-amd64"
  curl -fsSL \
    "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-amd64.tar.gz" \
    | tar xz
  mv "sing-box-${VERSION}-linux-amd64/sing-box" assets/cores/sing-box
  chmod +x assets/cores/sing-box
  rm -rf "sing-box-${VERSION}-linux-amd64"
  echo "✅ assets/cores/sing-box"
}

fetch_windows() {
  echo "↓ sing-box ${VERSION} windows-amd64"
  mkdir -p windows/runner
  curl -fsSL \
    "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-windows-amd64.zip" \
    -o /tmp/sb-win.zip
  unzip -qo /tmp/sb-win.zip -d /tmp/sb-win
  cp "/tmp/sb-win/sing-box-${VERSION}-windows-amd64/sing-box.exe" windows/runner/sing-box.exe
  cp windows/runner/sing-box.exe assets/cores/sing-box.exe
  rm -rf /tmp/sb-win /tmp/sb-win.zip
  echo "✅ windows/runner/sing-box.exe + assets/cores/sing-box.exe"
}

fetch_android() {
  echo "↓ sing-box ${VERSION} android ABIs"
  mkdir -p android/app/src/main/assets/cores
  # Map Android ABI → sing-box release arch
  declare -A MAP=([arm64-v8a]=arm64 [armeabi-v7a]=armv7 [x86_64]=amd64)
  for ABI in arm64-v8a armeabi-v7a x86_64; do
    SB_ARCH="${MAP[$ABI]}"
    curl -fsSL \
      "https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-android-${SB_ARCH}.tar.gz" \
      | tar xz
    mv "sing-box-${VERSION}-android-${SB_ARCH}/sing-box" \
       "android/app/src/main/assets/cores/sing-box-${ABI}"
    rm -rf "sing-box-${VERSION}-android-${SB_ARCH}"
  done
  echo "✅ android/.../assets/cores/sing-box-*"
}

case "$PLATFORM" in
  macos|darwin) fetch_macos ;;
  linux) fetch_linux ;;
  windows|win) fetch_windows ;;
  android) fetch_android ;;
  all)
    case "$(uname -s)" in
      Darwin) fetch_macos; fetch_android ;;
      Linux) fetch_linux; fetch_android ;;
      MINGW*|MSYS*|CYGWIN*) fetch_windows ;;
      *) fetch_linux ;;
    esac
    ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    echo "Usage: $0 [--platform macos|linux|windows|android|all]" >&2
    exit 1
    ;;
esac

echo "Done. Connect will extract assets/cores into Application Support if needed."
