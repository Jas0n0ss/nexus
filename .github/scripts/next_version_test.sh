#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
NV="$ROOT/next_version.sh"
chmod +x "$NV"

assert_eq() {
  local got want
  got="$("$NV" "$1")"
  want="$2"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: next_version('$1') => '$got' (want '$want')" >&2
    exit 1
  fi
  echo "OK  next_version('$1') => $got"
}

assert_eq ""        "0.10.0"
assert_eq "v0.1.0"  "0.10.0"
assert_eq "0.9.0"   "0.10.0"
assert_eq "0.10.0"  "0.11.0"
assert_eq "0.18.0"  "0.19.0"
assert_eq "0.19.0"  "1.1.0"
assert_eq "1.1.0"   "1.2.0"
assert_eq "1.8.0"   "1.9.0"
assert_eq "1.9.0"   "2.1.0"
assert_eq "2.9.0"   "3.1.0"
assert_eq "v3.5.0"  "3.6.0"

echo "✅ next_version scheme tests passed"
