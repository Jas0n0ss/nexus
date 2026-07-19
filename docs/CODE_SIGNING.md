# 让安装包被系统信任（代码签名）

> 你在 Mac 上看到的  
> **「Apple could not verify “nexus_vpn.app” is free of malware…」**  
> 是 **Gatekeeper**：无官方 Secrets 时，Release 仅使用 CI 自动生成的
> **本地代码签名证书**，没有 Apple **Developer ID** 信任链，也没有公证
>（notarize）。这不是应用损坏，而是系统不信任本地签名发布者。

要让各平台安装包被系统默认信任，必须使用**各平台官方颁发的付费/商用证书**，并在 CI 里完成签名（以及 macOS 公证）。  
本仓库 CI 已支持：配置好 GitHub Secrets 后，打 `v*.*.*` tag 会自动产出受信任包。

---

## 现状 vs 目标

| 平台 | 现在（无 Secrets） | 目标（配置 Secrets 后） | 用户侧效果 |
|------|-------------------|-------------------------|-----------|
| **macOS** | 本地证书 / ad-hoc 签名 DMG | Developer ID 签名 + **公证** | 双击即可打开，无 Gatekeeper 警告 |
| **Windows** | 自动生成的自签 Authenticode | EV/OV 代码签名 | SmartScreen 不再「未知发布者」 |
| **Android** | 社区 release 证书（可安装） | 同上，或换成你自己的 Play 密钥 | 可安装；上架需 Play Console |
| **iOS** | 未签名 IPA（侧载） | Apple 开发者证书 + 描述文件 | TestFlight / 企业分发 / App Store |
| **Linux** | 无系统级「签名信任」门槛 | 可选 GPG 签名 deb/rpm | 一般直接运行即可 |

**无法绕过的事实：**  
没有 Apple / Microsoft 等颁发的证书，CI **不能**凭空让 Gatekeeper / SmartScreen 信任安装包。  
开源社区证书（我们已有的 Android 社区 keystore）**不能**消除 macOS/Windows 的系统警告。

---

## 没有证书时：临时打开 macOS 包

1. 打开「系统设置 → 隐私与安全性」  
2. 或对 `nexus_vpn.app` / DMG 内应用：**右键 → 打开 → 仍要打开**  
3. 终端（本机一次）：

```bash
xattr -cr /Applications/nexus_vpn.app
# 或
sudo spctl --master-disable   # 不推荐长期关闭 Gatekeeper
```

---

## 1. macOS：Developer ID + 公证（消除该警告的关键）

### 你需要准备

1. [Apple Developer Program](https://developer.apple.com/programs/)（年费）  
2. 证书：**Developer ID Application**（导出为 `.p12`）  
3. 公证账号（二选一）：  
   - **推荐**：App Store Connect API Key（`.p8` + Key ID + Issuer ID）  
   - 或：Apple ID + App 专用密码  

### GitHub Secrets

| Secret | 说明 |
|--------|------|
| `MACOS_CERTIFICATE_BASE64` | Developer ID Application 的 `.p12`，`base64 -i cert.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | p12 密码 |
| `MACOS_SIGNING_IDENTITY` | 可选，默认匹配 `Developer ID Application` |
| `APPLE_TEAM_ID` | 10 位 Team ID |
| `APPLE_API_KEY_BASE64` | AuthKey_XXX.p8 的 base64 |
| `APPLE_API_KEY_ID` | Key ID |
| `APPLE_API_ISSUER_ID` | Issuer UUID |

配置后，CI 会对 `.app` **hardened runtime** 签名 → 打 DMG → **notarytool 公证** → **staple**，用户下载后应不再出现该恶意软件提示。

### 本地导出 p12 示例

```bash
# Keychain Access → 我的证书 → Developer ID Application → 导出 .p12
base64 -i DeveloperID.p12 | pbcopy   # 粘贴到 MACOS_CERTIFICATE_BASE64
```

---

## 2. Windows：Authenticode

### 你需要准备

- OV/EV **代码签名证书**（DigiCert、Sectigo、SSL.com 等；EV 对 SmartScreen 更友好）  
- 导出 `.pfx`（含私钥）

### GitHub Secrets

| Secret | 说明 |
|--------|------|
| `WINDOWS_CERTIFICATE_BASE64` | `.pfx` 的 base64 |
| `WINDOWS_CERTIFICATE_PASSWORD` | pfx 密码 |

CI 使用 `signtool` 对 `nexus_vpn.exe`、安装包与便携版内文件签名并加时间戳。

---

## 3. Android

- **侧载安装**：已使用社区 release 证书（`app/packaging/android/`），一般可安装。  
- **被系统/厂商商店信任 / 上架 Google Play**：在 Play Console 创建应用，用你自己的上传密钥（可用 Secrets 覆盖）：

| Secret | 说明 |
|--------|------|
| `ANDROID_KEYSTORE_BASE64` | 你的 keystore |
| `ANDROID_STORE_PASS` / `ANDROID_KEY_PASS` / `ANDROID_KEY_ALIAS` | 密码与别名 |

---

## 4. iOS

需要 Apple 开发者账号 + 证书 + Provisioning Profile（Network Extension 还需对应 Capability）。

| Secret | 说明 |
|--------|------|
| `IOS_CERTIFICATE_BASE64` | 分发/开发证书 p12 |
| `IOS_CERTIFICATE_PASS` | 密码 |
| `IOS_PROVISION_BASE64` | `.mobileprovision` |
| `IOS_TEAM_ID` | Team ID（可选，写入 Xcode） |

未配置时 CI 仍产出 **未签名 IPA**（AltStore / TrollStore 等侧载）。  
正式对用户「可信任安装」通常走 **TestFlight / App Store**，而不是裸 IPA。

---

## 5. Linux

AppImage / deb / rpm 默认无 macOS/Windows 那种强制弹窗。  
若要仓库级信任，可对包做 **GPG 签名**并公布公钥（可选，当前未强制）。

---

## 配置顺序建议

1. **先解决 macOS**：申请 Apple Developer → Developer ID → 配 Secrets → 打 tag 发版 → 在干净 Mac 上验证无 Gatekeeper 警告。  
2. 再配 **Windows** 代码签名。  
3. Android / iOS 按上架渠道配置。

验证 macOS 是否已公证：

```bash
spctl -a -vv /Applications/nexus_vpn.app
# 期望：accepted / source=Notarized Developer ID

stapler validate NexusVPN-*-macos.dmg
```

---

## 费用与周期（量级）

| 项目 | 大致情况 |
|------|----------|
| Apple Developer | ~99 USD/年 |
| Windows 代码签名 OV | 约数百 USD/年；EV 更高，SmartScreen 信誉更好 |
| Android Play | 一次性注册费 |
| 出证到 CI 跑通 | 通常数天到数周（含企业验证） |

---

## 相关文件

- CI：`.github/workflows/ci.yml`（macOS 签名/公证、Windows signtool、Android/iOS secrets）  
- Android 社区证书：`app/packaging/android/`  
- macOS 公证用 entitlements：`app/packaging/macos/Runner.entitlements`
