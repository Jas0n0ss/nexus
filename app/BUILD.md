# Nexus VPN — Build Guide

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter SDK | ≥ 3.16 | `flutter --version` |
| Dart SDK | ≥ 3.2 | Bundled with Flutter |
| Xcode | ≥ 15 | macOS / iOS only |
| Android Studio | ≥ Hedgehog | Android only |
| Visual Studio 2022 | ≥ 17 | Windows only (C++ workload) |
| CMake | ≥ 3.14 | Windows / Linux |

## 1. Clone & Install Dependencies

```bash
git clone https://github.com/yourorg/nexus-vpn
cd nexus-vpn/app
flutter pub get
```

## 2. Download sing-box Binaries

```bash
# macOS (arm64 + x64 universal)
mkdir -p assets/cores
curl -L https://github.com/SagerNet/sing-box/releases/download/v1.9.3/sing-box-1.9.3-darwin-amd64.tar.gz | tar xz
lipo -create -output assets/cores/sing-box \
  sing-box-1.9.3-darwin-amd64/sing-box \
  sing-box-1.9.3-darwin-arm64/sing-box

# iOS (arm64 only — cross-compiled for device)
curl -L https://github.com/SagerNet/sing-box/releases/download/v1.9.3/sing-box-1.9.3-ios.tar.gz | tar xz
cp sing-box-1.9.3-ios/sing-box ios/NexusVPNExtension/sing-box

# Android (arm64-v8a + x86_64)
for ABI in arm64-v8a x86_64 armeabi-v7a; do
  curl -L "https://github.com/SagerNet/sing-box/releases/download/v1.9.3/sing-box-1.9.3-android-${ABI}.tar.gz" | tar xz
  mkdir -p android/app/src/main/assets/cores
  cp "sing-box-1.9.3-android-${ABI}/sing-box" "android/app/src/main/assets/cores/sing-box-${ABI}"
done

# Windows
curl -L https://github.com/SagerNet/sing-box/releases/download/v1.9.3/sing-box-1.9.3-windows-amd64.zip -o sb-win.zip
unzip sb-win.zip
cp sing-box-1.9.3-windows-amd64/sing-box.exe windows/runner/
# Also download WinTUN: https://www.wintun.net/
curl -L https://www.wintun.net/builds/wintun-0.14.1.zip -o wintun.zip
unzip wintun.zip
cp wintun/bin/amd64/wintun.dll windows/runner/
```

## 3. macOS Build

```bash
# Open Xcode project and configure signing
open macos/Runner.xcworkspace

# Or build from command line (requires valid Apple Developer account):
flutter build macos --release

# Package as DMG
brew install create-dmg
create-dmg \
  --volname "Nexus VPN" \
  --background "macos/dmg-background.png" \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "Nexus VPN.app" 160 190 \
  --app-drop-link 380 190 \
  "Nexus VPN.dmg" \
  "build/macos/Build/Products/Release/Nexus VPN.app"
```

**Required Entitlements (macos/Runner/*.entitlements):**
```xml
<key>com.apple.security.network.client</key><true/>
<key>com.apple.developer.networking.networkextension</key>
<array><string>packet-tunnel-provider</string></array>
<key>com.apple.security.app-sandbox</key><true/>
```

## 4. iOS Build

```bash
# Configure signing in Xcode:
open ios/Runner.xcworkspace
# Set Team + Bundle ID, enable Network Extension capability

flutter build ios --release
# Archive and submit via Xcode Organizer or:
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner -configuration Release \
  -archivePath build/NexusVPN.xcarchive archive
```

**Required Capabilities:**
- Network Extensions → Packet Tunnel
- App Groups → group.com.yourcompany.nexusvpn

## 5. Android Build

```bash
# Debug APK
flutter build apk --debug

# Release AAB (for Play Store)
flutter build appbundle --release

# Release APK (split by ABI)
flutter build apk --release --split-per-abi
# Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

**AndroidManifest.xml additions:**
```xml
<uses-permission android:name="android.permission.BIND_VPN_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<service android:name=".NexusVpnService"
  android:permission="android.permission.BIND_VPN_SERVICE">
  <intent-filter><action android:name="android.net.VpnService"/></intent-filter>
</service>
```

## 6. Windows Build

```bash
# Build release EXE
flutter build windows --release
# Output: build/windows/x64/runner/Release/nexus_vpn.exe

# Create installer with Inno Setup:
iscc windows/installer/nexus-vpn.iss
# Output: build/NexusVPN-Setup.exe

# Or publish to winget (after release):
# Update manifests in microsoft/winget-pkgs
```

**Run as admin** is required for WinTUN driver access. The app automatically requests elevation via a manifest:
```xml
<!-- windows/runner/nexus_vpn.exe.manifest -->
<requestedExecutionLevel level="requireAdministrator"/>
```

## 7. Package Managers

### macOS — Homebrew Cask
```ruby
# Formula: nexus-vpn.rb
cask "nexus-vpn" do
  version "1.0.0"
  sha256 "..."
  url "https://github.com/yourorg/nexus-vpn/releases/download/v1.0.0/NexusVPN-1.0.0.dmg"
  name "Nexus VPN"
  desc "Cross-platform VPN client supporting VLESS/Hysteria2/TUIC"
  homepage "https://github.com/yourorg/nexus-vpn"
  app "Nexus VPN.app"
end
```

### Windows — winget
```yaml
# manifests/y/yourorg/nexusvpn/1.0.0/yourorg.nexusvpn.yaml
PackageIdentifier: yourorg.nexusvpn
PackageVersion: 1.0.0
PackageName: Nexus VPN
Installers:
  - Architecture: x64
    InstallerType: inno
    InstallerUrl: https://github.com/yourorg/nexus-vpn/releases/download/v1.0.0/NexusVPN-Setup.exe
```

### Windows — Scoop
```json
{
  "version": "1.0.0",
  "description": "Nexus VPN — cross-platform VPN client",
  "url": "https://github.com/yourorg/nexus-vpn/releases/download/v1.0.0/NexusVPN-portable.zip",
  "bin": "nexus_vpn.exe"
}
```

## 8. Run Tests

```bash
# Unit tests
flutter test

# Integration tests (requires device/emulator)
flutter test integration_test/

# Protocol parser tests
flutter test test/parsers/
```
