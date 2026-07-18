# Android release packaging

CI runs `flutter create` to scaffold `android/`, then applies this overlay so
release APKs are **sideload-installable**.

## What this provides

| File | Purpose |
|------|---------|
| `keystore/nexus-release.p12` | Community release keystore (not the Android Debug cert) |
| `key.properties` | Passwords / alias for CI signing |
| `apply_release_config.sh` | Patches `AndroidManifest.xml` + `build.gradle` after scaffold |

## Why

APKs signed with `CN=Android Debug` are rejected by many OEM installers
(Xiaomi / HyperOS, Huawei, Oppo, etc.) with a generic “无法安装”.

## Play Store builds

Override the community keystore with GitHub Secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASS` / `ANDROID_KEY_PASS` / `ANDROID_KEY_ALIAS`
