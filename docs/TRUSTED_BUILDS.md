# Trusted builds (no install warnings)

Nexus CI can produce **system-trusted** installers only when each platform’s
**official signing certificate** is provided as GitHub Actions Secrets.

> Self-signed certificates **cannot** silence Apple Gatekeeper or Microsoft
> SmartScreen. Those systems require paid Developer ID / Authenticode certs
> issued by Apple / a Windows CA.

## Required GitHub Secrets

Configure under **Settings → Secrets and variables → Actions**.

### Android (installable APK — already supported)

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of the `.p12` / `.jks` keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

If unset, CI falls back to the community release keystore under
`app/packaging/android/` (APKs remain installable after “unknown source”).

Generate & upload:

```bash
# From repo root
bash app/scripts/gen_android_keystore.sh   # writes local keystore + prints base64
# Then (needs repo admin):
gh secret set ANDROID_KEYSTORE_BASE64 < keystore.b64
gh secret set ANDROID_KEYSTORE_PASSWORD --body '…'
gh secret set ANDROID_KEY_ALIAS --body 'nexus'
gh secret set ANDROID_KEY_PASSWORD --body '…'
```

### macOS (Gatekeeper / no “Apple could not verify”)

| Secret | Description |
|--------|-------------|
| `MACOS_CERTIFICATE_BASE64` | Developer ID Application `.p12` (base64) |
| `MACOS_CERTIFICATE_PASSWORD` | `.p12` password |
| `MACOS_SIGNING_IDENTITY` | e.g. `Developer ID Application: … (TEAMID)` |
| `APPLE_TEAM_ID` | 10-char Team ID |
| `APPLE_API_KEY_BASE64` | App Store Connect API `.p8` (base64) |
| `APPLE_API_KEY_ID` | Key ID |
| `APPLE_API_ISSUER_ID` | Issuer UUID |

Requires a paid **Apple Developer Program** membership. See [CODE_SIGNING.md](CODE_SIGNING.md).

### Windows (SmartScreen / Authenticode)

| Secret | Description |
|--------|-------------|
| `WINDOWS_CERTIFICATE_BASE64` | Code-signing `.pfx` (base64) |
| `WINDOWS_CERTIFICATE_PASSWORD` | `.pfx` password |

Requires an OV/EV code-signing certificate from a public CA.

### iOS (device install / TestFlight)

| Secret | Description |
|--------|-------------|
| `IOS_CERTIFICATE_BASE64` | Distribution `.p12` |
| `IOS_CERTIFICATE_PASS` | Password |
| `IOS_PROVISION_BASE64` | `.mobileprovision` |

## Local-certificate fallback

When official Secrets are absent, CI now signs with local identities:

- **Android:** the repository's persistent local release keystore. It must stay
  stable so a newer APK can update an older installation.
- **Windows:** a 30-day self-signed code-signing certificate generated for each
  CI run; binaries and the installer carry an Authenticode integrity signature.
- **macOS:** a 30-day local code-signing certificate generated in a temporary
  keychain; if that fails, CI falls back to ad-hoc signing.
- **iOS:** remains unsigned; arbitrary self-signed certificates cannot create an
  installable IPA on normal devices without provisioning.

Local certificates are intentionally **not uploaded as Secrets**: they have no
public trust value. Official certificates in Secrets always take precedence.

## What CI does today

| Platform | Without secrets | With secrets |
|----------|-----------------|--------------|
| Android | Persistent local-keystore APK | Your keystore |
| macOS | Locally/ad-hoc signed DMG (Gatekeeper warn) | Sign + notarize |
| Windows | Self-signed setup/portable (Unknown publisher) | CA Authenticode sign |
| Linux | No OS trust gate | Optional GPG later |
| iOS | Unsigned IPA (sideload) | Signed IPA |

## Honest limitation

This repository **cannot invent** Apple / Microsoft certificates.  
If those Secrets are empty, CI still ships usable packages, but macOS/Windows
will show the platform’s standard unsigned-app warnings until you add them.
