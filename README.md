<div align="center">

<img src="app/assets/icons/app_icon_512.png" width="128" height="128" alt="Nexus VPN Logo"/>

# Nexus VPN

**现代跨平台 VPN 客户端** · Apple 设计风格 · sing-box 内核 · Flutter 构建

[![CI](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/nexus/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/Jas0n0ss/nexus/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Jas0n0ss/nexus?style=flat-square&color=3b82f6)](https://github.com/Jas0n0ss/nexus/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.22-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![sing-box](https://img.shields.io/badge/sing--box-1.9.3-orange?style=flat-square)](https://github.com/SagerNet/sing-box)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android-lightgrey?style=flat-square)](#下载)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

[**下载**](#下载) · [**快速开始**](#快速开始) · [**协议支持**](#协议支持) · [**项目结构**](STRUCTURE.md) · [**构建**](#构建)

</div>

---

## ✨ 功能特性

### 🔌 多协议支持

| 协议 | 传输方式 | 安全层 | 解析入口 |
|------|---------|--------|---------|
| **VLESS** | TCP / WebSocket / gRPC | REALITY / TLS | `lib/core/node_parser.dart` |
| **VMess** | TCP / WebSocket / gRPC | TLS / None | 同上 |
| **Trojan** | TCP / WebSocket / gRPC | TLS | 同上 |
| **Shadowsocks** | TCP / UDP | AEAD-2022 / AES-GCM | 同上 |
| **Hysteria 2** | QUIC | TLS | 同上 |
| **TUIC v5** | QUIC | TLS | 同上 |
| **WireGuard** | UDP | 内置加密 | 同上 |

### 📥 一键导入（5 大服务端脚本）

支持从以下流行的服务端一键部署脚本直接导入节点配置（识别逻辑见 `lib/models/proxy_node.dart` 的 `NodeSource` 枚举）：

| 服务端脚本 | 导入格式 |
|-----------|---------|
| [233boy/sing-box](https://github.com/233boy/sing-box) | sing-box JSON / URI |
| [233boy/Xray](https://github.com/233boy/Xray) | Xray JSON / URI |
| [233boy/v2ray](https://github.com/233boy/v2ray) | Base64 订阅 / vmess:// |
| [mack-a/v2ray-agent](https://github.com/mack-a/v2ray-agent) | 多协议订阅 |
| [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) | sing-box JSON |

导入方式：**订阅 URL** / **URI 粘贴**（`vless://` `vmess://` `trojan://` `ss://` `hysteria2://` `tuic://` `wg://`）/ **配置文件**（file_picker）。

### 🔧 自动修复引擎（`lib/core/autofix_engine.dart`）

导入节点后自动检测并修复常见配置错误：

- VMess `encryption: auto` → `none`（sing-box 兼容）
- gRPC ALPN 强制 `h2`（避免握手失败）
- QUIC 协议（Hysteria2 / TUIC）禁用 TCP Mux
- Trojan / VLESS SNI 缺失自动补全
- REALITY `fingerprint` 缺失默认 `chrome`
- Shadowsocks 2022 密钥格式校验

### 🎨 Apple 风格 UI（`lib/screens/` + `lib/widgets/`）

- 毛玻璃卡片（`glass_card.dart`）
- 实时速率曲线（fl_chart，`dashboard_screen.dart`）
- 大圆形连接按钮 + 动画（flutter_animate，`connect_button.dart`）
- 深色 / 浅色模式跟随系统
- 桌面端左侧导航（window_manager 管理窗口），移动端底部标签栏（`main_shell.dart`）

---

## 下载

每次 push 到 `main` 都会构建全平台产物（Actions Artifacts），打 `v*.*.*` tag 自动发布 Release：

| 平台 | 文件 | 安装方式 |
|------|------|---------|
| 🍎 **macOS** | `NexusVPN-*-macos.dmg` | 拖入 Applications（Apple Silicon + Intel 通用）|
| 🪟 **Windows** | `NexusVPN-*-windows-setup.exe` | 安装包，含 WinTUN 驱动 |
| 🪟 **Windows** | `NexusVPN-*-windows-portable.zip` | 便携版，解压即用 |
| 🐧 **Linux** | `NexusVPN-*-linux-x86_64.AppImage` | `chmod +x` 后直接运行 |
| 🐧 **Linux** | `NexusVPN-*-linux-amd64.deb` | Debian/Ubuntu：`sudo dpkg -i` |
| 🐧 **Linux** | `NexusVPN-*-linux-x86_64.rpm` | Fedora/RHEL/openSUSE：`sudo rpm -i` |
| 🤖 **Android** | `NexusVPN-android-arm64-v8a.apk` | 主流设备（另有 armv7 / x86_64 / AAB）|
| 🍏 **iOS** | `NexusVPN-*-ios-unsigned.ipa` | AltStore / TrollStore / Sideloadly 侧载 |

→ [最新 Release](https://github.com/Jas0n0ss/nexus/releases/latest) · [CI 构建产物](https://github.com/Jas0n0ss/nexus/actions/workflows/ci.yml)

---

## 快速开始

### 1. 导入节点

打开 Nexus VPN → 「导入」页 → 粘贴订阅链接或单节点 URI：

```
# 订阅链接（233boy / mack-a / yonggekkk 脚本生成的均可）
https://your.domain/sub?token=xxx

# 单节点 URI
vless://uuid@host:443?encryption=none&security=reality&sni=yahoo.com&fp=chrome&pbk=xxx&type=tcp#节点名
```

### 2. 连接

「节点」页选择延迟最低的节点 → 返回仪表盘 → 点击连接按钮。自动修复引擎会在导入时处理常见配置问题。

### 3. 平台集成

| 平台 | TUN 实现 | 位置 |
|------|---------|------|
| Android | `VpnService` + sing-box 进程 | `app/android/.../VpnService.kt` |
| iOS | `NEPacketTunnelProvider` | `app/ios/NexusVPNExtension/` |
| Windows | WinTUN 虚拟网卡 | `app/windows/runner/vpn_channel.cpp` |
| macOS / Linux | sing-box 进程 + 系统代理 | `lib/core/singbox_runner.dart` |

---

## 协议支持

核心数据流（详见 [STRUCTURE.md](STRUCTURE.md)）：

```
URI/订阅 → NodeParser 解析 → AutofixEngine 修复 → ConfigGenerator 生成 sing-box JSON
        → SingboxRunner 启动内核 → 平台 TUN/代理接管流量 → Dashboard 实时图表
```

分流模式：**规则分流**（中国 IP/域名直连 + 广告屏蔽）/ **全局代理** / **直连**。

---

## 构建

### 环境要求

- Flutter 3.22（CI 使用版本，见 `.github/workflows/ci.yml` 的 `FLUTTER_VERSION`）
- 平台工具链：Xcode 15+（macOS/iOS）· VS 2022 C++（Windows）· JDK 17（Android）· GTK3 dev（Linux）

### 本地构建

```bash
git clone https://github.com/Jas0n0ss/nexus
cd nexus/app

# 生成平台脚手架（本仓库只提交自定义源码，脚手架由 flutter create 生成）
flutter create --org com.nexusvpn --project-name nexus_vpn \
  --platforms=android,ios,linux,macos,windows --no-pub .

flutter pub get

# 下载 sing-box 内核（以 macOS arm64 为例）
mkdir -p assets/cores
curl -fsSL https://github.com/SagerNet/sing-box/releases/download/v1.9.3/sing-box-1.9.3-darwin-arm64.tar.gz | tar xz
mv sing-box-1.9.3-darwin-arm64/sing-box assets/cores/ && chmod +x assets/cores/sing-box

flutter run                      # 调试运行
flutter build macos --release    # 或 windows / linux / apk / ios
```

### CI / Release

单一工作流 `.github/workflows/ci.yml` 完成全部工作：

```
version → lint + test + 4 平台并行构建 → all-builds 门禁 → (tag 时) GitHub Release
```

```bash
# 触发 Release：打 tag 即可
git tag v1.0.0 && git push origin v1.0.0
```

产物：Android APK×3 + AAB · Linux AppImage + deb + rpm · Windows 安装包 + 便携版 · macOS DMG · iOS 未签名 IPA。

### 签名（可选 Secrets）

| Secret | 用途 |
|--------|------|
| `ANDROID_KEYSTORE_BASE64` / `ANDROID_STORE_PASS` / `ANDROID_KEY_PASS` / `ANDROID_KEY_ALIAS` | Android 签名 APK |
| `IOS_CERTIFICATE_BASE64` / `IOS_CERTIFICATE_PASS` / `IOS_PROVISION_BASE64` | iOS 签名 IPA |

未配置时 CI 构建未签名包（iOS 可侧载，Android 为 debug 签名）。

---

## 贡献：添加新协议

1. `lib/models/proxy_node.dart` — `Protocol` 枚举加新值
2. `lib/core/node_parser.dart` — 添加 URI 解析方法
3. `lib/core/config_generator.dart` — 添加 sing-box outbound 生成
4. `lib/core/autofix_engine.dart` — 添加修复规则
5. `test/` — 补充解析测试

---

## 许可证

[MIT License](LICENSE)
