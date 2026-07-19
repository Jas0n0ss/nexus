#!/usr/bin/env bash
# Apply the Nexus name and routing icon to fresh Flutter macOS/iOS scaffolds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/assets/icons/app_icon_1024.png"

resize_icon_set() {
  local dir=$1
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' icon; do
    local width height
    width=$(sips -g pixelWidth "$icon" | awk '/pixelWidth/{print $2}')
    height=$(sips -g pixelHeight "$icon" | awk '/pixelHeight/{print $2}')
    [[ -n "$width" && -n "$height" ]] || continue
    sips -z "$height" "$width" "$SOURCE" --out "$icon" >/dev/null
  done < <(find "$dir" -type f -name '*.png' -print0)
}

resize_icon_set "$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
resize_icon_set "$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"

if [[ -f "$ROOT/macos/Runner/Configs/AppInfo.xcconfig" ]]; then
  sed -i '' 's/^PRODUCT_NAME = .*/PRODUCT_NAME = Nexus/' \
    "$ROOT/macos/Runner/Configs/AppInfo.xcconfig"
fi

if [[ -f "$ROOT/ios/Runner/Info.plist" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Nexus" \
    "$ROOT/ios/Runner/Info.plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Nexus" \
      "$ROOT/ios/Runner/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName Nexus" \
    "$ROOT/ios/Runner/Info.plist" 2>/dev/null || true
fi

echo "✅ Applied Nexus branding to Apple platform scaffolds"
