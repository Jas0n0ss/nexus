#!/usr/bin/env bash
# Compute the next Nexus release version.
#
# Scheme (patch always 0):
#   0.10.0 → 0.11.0 → … → 0.19.0 → 1.1.0 → 1.2.0 → … → 1.9.0 → 2.1.0 → …
#
# Usage:
#   next_version.sh                 # no prior tag → 0.10.0
#   next_version.sh v0.1.0          # → 0.10.0  (legacy below 0.10 jumps into scheme)
#   next_version.sh v0.19.0         # → 1.1.0
#   next_version.sh 1.9.0           # → 2.1.0
#
# Prints: MAJOR.MINOR.PATCH  (no leading "v")

set -euo pipefail

latest="${1:-}"
latest="${latest#v}"
latest="${latest%%+*}"   # drop +build
latest="${latest%%-*}"   # drop -prerelease

if [[ -z "$latest" ]]; then
  echo "0.10.0"
  exit 0
fi

IFS=. read -r major minor _patch <<< "$latest"
major="${major:-0}"
minor="${minor:-0}"

if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]]; then
  echo "0.10.0"
  exit 0
fi

if (( major == 0 )); then
  if (( minor < 10 )); then
    echo "0.10.0"
  elif (( minor < 19 )); then
    echo "0.$((minor + 1)).0"
  else
    echo "1.1.0"
  fi
else
  if (( minor < 9 )); then
    echo "${major}.$((minor + 1)).0"
  else
    echo "$((major + 1)).1.0"
  fi
fi
