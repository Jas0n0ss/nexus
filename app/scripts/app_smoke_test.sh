#!/usr/bin/env bash
# End-to-end app/core smoke test:
# 1. Parse a VLESS Reality URI through the Dart app parser
# 2. Generate desktop proxy + TUN configs
# 3. Validate both configs with the bundled sing-box version
# 4. When NEXUS_E2E_TEST_URI is set, establish a real proxy connection
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CORE="assets/cores/sing-box"
if [[ ! -x "$CORE" ]]; then
  bash scripts/fetch_singbox.sh --platform linux
fi

rm -rf build/app-smoke
flutter test --no-pub test/core_config_smoke_test.dart

"$CORE" check -c build/app-smoke/config-proxy.json
"$CORE" check -c build/app-smoke/config-tun.json
echo "✅ Parser → config generator → sing-box check"

if [[ -z "${NEXUS_E2E_TEST_URI:-}" ]]; then
  echo "::notice::NEXUS_E2E_TEST_URI is not configured; live connectivity test skipped."
  exit 0
fi

LOG="build/app-smoke/sing-box.log"
"$CORE" run -c build/app-smoke/config-proxy.json >"$LOG" 2>&1 &
CORE_PID=$!
cleanup() {
  kill "$CORE_PID" >/dev/null 2>&1 || true
  wait "$CORE_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for attempt in 1 2 3; do
  if ! kill -0 "$CORE_PID" >/dev/null 2>&1; then
    echo "❌ sing-box exited during live smoke test"
    tail -100 "$LOG"
    exit 1
  fi
  if curl --fail --silent --show-error \
      --proxy "http://127.0.0.1:17890" \
      --connect-timeout 8 --max-time 20 \
      "https://www.gstatic.com/generate_204" \
      --output /dev/null; then
    echo "✅ Live VLESS Reality connectivity passed"
    exit 0
  fi
  echo "Live probe attempt ${attempt}/3 failed; retrying..."
  sleep 3
done

echo "❌ Live VLESS Reality connectivity failed"
tail -100 "$LOG"
exit 1
