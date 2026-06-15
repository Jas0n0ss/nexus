<div align="center">

<img src="app/assets/icons/app_icon_512.png" width="128" height="128" alt="Nexus VPN Logo"/>

# Nexus VPN

**现代跨平台 VPN 客户端** · Apple 设计风格 · sing-box / Xray / v2ray 三核心

[![Release](https://img.shields.io/github/v/release/yourorg/nexus-vpn?style=flat-square&color=3b82f6)](https://github.com/yourorg/nexus-vpn/releases)
[![Build](https://img.shields.io/github/actions/workflow/status/yourorg/nexus-vpn/release.yml?style=flat-square&label=CI)](https://github.com/yourorg/nexus-vpn/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.22-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![sing-box](https://img.shields.io/badge/sing--box-1.9.3-orange?style=flat-square)](https://github.com/SagerNet/sing-box)
[![License](https://img.shields.io/github/license/yourorg/nexus-vpn?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android-lightgrey?style=flat-square)](#下载)

[**下载**](#下载) · [**快速开始**](#快速开始) · [**协议支持**](#协议支持) · [**构建**](#构建) · [**贡献**](#贡献)

</div>

---

## ✨ 功能特性

### 🔌 多协议支持
| 协议 | 传输方式 | 安全层 |
|------|---------|--------|
| **VLESS** | TCP / WebSocket / gRPC | REALITY / TLS |
| **VMess** | TCP / WebSocket / gRPC | TLS / None |
| **Trojan** | TCP / WebSocket / gRPC | TLS |
| **Shadowsocks** | TCP / UDP | AEAD-2022 / ChaCha20 / AES-GCM |
| **Hysteria 2** | QUIC | TLS |
| **TUIC v5** | QUIC | TLS |
| **WireGuard** | UDP | 内置 |

### 📥 一键导入（5 大脚本来源）
| 脚本 | 格式 | 特点 |
|------|------|------|
| [233boy/sing-box](https://github.com/233boy/sing-box) | JSON 全配置 | VLESS REALITY / Hysteria2 |
| [233boy/Xray](https://github.com/233boy/Xray) | JSON 全配置 | 多协议 / XTLS |
| [233boy/v2ray](https://github.com/233boy/v2ray) | Base64 订阅 | VMess WS / gRPC |
| [mack-a/v2ray-agent](https://github.com/mack-a/v2ray-agent) | 多用户订阅 | 全协议覆盖 |
| [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) | sing-box JSON | 一键脚本 |

支持导入方式：
- 🔗 **订阅 URL** — 自动拉取并解析
- 📋 **URI 粘贴** — `vmess://` `vless://` `trojan://` `ss://` `hysteria2://` `tuic://` `wg://`
- 📄 **配置文件** — `.json` `.yaml` `.conf` 直接上传
- 📷 **二维码扫描** — iOS / Android 摄像头扫描

### 🔧 自动修复引擎
导入节点后自动检测并修复：
- ✅ VMess `encryption` 字段 `auto` → `none`（sing-box 要求）
- ✅ gRPC ALPN `h2,http/1.1` → `h2`（避免握手失败）
- ✅ QUIC 协议（Hysteria2 / TUIC）禁用 TCP Mux
- ✅ Trojan SNI 缺失自动补全
- ✅ REALITY `fingerprint` 缺失默认设为 `chrome`
- ✅ Shadowsocks 2022 密钥格式校验

### 🛡️ 运行时健康监控
- 内核崩溃自动重启（超过阈值切换备用核心）
- CPU / 内存异常检测
- DNS 泄漏实时检测 + 自动修复
- 连接后自动测试 Google / Cloudflare 可用性

### 🎨 Apple 风格 UI
- 毛玻璃卡片（Glassmorphism）
- 实时速率曲线（fl_chart）
- 深色 / 浅色模式跟随系统
- 桌面端：左侧导航栏；移动端：底部标签栏

---

## 下载

| 平台 | 最新版本 | 说明 |
|------|---------|------|
| 🍎 **macOS** | [.dmg ↓](https://github.com/yourorg/nexus-vpn/releases/latest) | Apple Silicon + Intel 通用 |
| 🪟 **Windows** | [.exe ↓](https://github.com/yourorg/nexus-vpn/releases/latest) | x64 安装包，含 WinTUN |
| 🐧 **Linux** | [.AppImage ↓](https://github.com/yourorg/nexus-vpn/releases/latest) · [.deb ↓](https://github.com/yourorg/nexus-vpn/releases/latest) | x64 |
| 🤖 **Android** | [.apk ↓](https://github.com/yourorg/nexus-vpn/releases/latest) | arm64-v8a 推荐 |
| 🍏 **iOS** | [unsigned .ipa ↓](https://github.com/yourorg/nexus-vpn/releases/latest) | AltStore / TrollStore 安装 |

### 包管理器安装

```bash
# macOS — Homebrew
brew install --cask nexus-vpn

# Windows — winget
winget install yourorg.nexusvpn

# Windows — Scoop
scoop bucket add nexusvpn https://github.com/yourorg/scoop-nexusvpn
scoop install nexus-vpn
```

---

## 快速开始

### 1. 导入节点

打开 Nexus VPN → 点击「导入配置」→ 粘贴订阅链接或 URI：

```
# 订阅链接示例（233boy/sing-box 格式）
https://your.domain/sub?token=your_token

# 单节点 URI 示例
vless://uuid@host:443?encryption=none&security=reality&sni=yahoo.com&fp=chrome&pbk=xxx&type=tcp#节点名

vmess://eyJ2IjoiMiIsInBzIjoiVG9reW8tMDEiLCJhZGQiOiIxMDMuMjE4LjY0LjEyIiwicG9ydCI6IjQ0MyIsImlkIjoiYWJjMTIzNDUtMTIzNC0xMjM0LTEyMzQtYWJjMTIzNDU2Nzg5IiwiYWlkIjoiMCIsIm5ldCI6IndzIiwidHlwZSI6Im5vbmUiLCJob3N0IjoiIiwicGF0aCI6Ii93cyIsInRscyI6InRscyJ9
```

### 2. 选择节点并连接

在「节点列表」选择延迟最低的节点 → 返回仪表盘 → 点击大按钮连接。

### 3. 验证连接

连接成功后，应用自动检测：
- 外部 IP 是否变更
- google.com / 1.1.1.1 是否可达
- DNS 有无泄漏

---

## 协议支持

### 核心引擎切换

在「设置 → 核心引擎」可在三个内核间切换（热切换，不断开连接）：

| 内核 | 版本 | 推荐场景 |
|------|------|---------|
| **sing-box** ⭐ | 1.9.x | 推荐，支持全部协议，性能最优 |
| **Xray-core** | 1.8.x | XTLS-Vision 用户 |
| **v2ray-core** | 5.x | 向后兼容旧配置 |

### 分流规则

| 模式 | 说明 |
|------|------|
| **规则分流**（默认）| 中国 IP / 域名直连，其余代理；广告屏蔽 |
| **全局代理** | 所有流量经过代理 |
| **直连模式** | 临时关闭代理 |

---

## 平台集成

| 平台 | TUN 模式 | 系统代理 | 需要权限 |
|------|---------|---------|---------|
| macOS | Network Extension | ✅ | 系统扩展批准 |
| iOS | NEPacketTunnelProvider | — | VPN 配置权限 |
| Windows | WinTUN 虚拟网卡 | ✅ | 管理员 |
| Android | VpnService | — | VPN 权限 |
| Linux | TUN 设备 | ✅ | root / CAP_NET_ADMIN |

---

## 构建

### 环境要求

- Flutter ≥ 3.16（`flutter --version`）
- Dart ≥ 3.2
- macOS 构建：Xcode ≥ 15
- Windows 构建：Visual Studio 2022（含 C++ 工作负载）
- Android 构建：Android Studio + JDK 17
- iOS 构建：Xcode + Apple Developer 账号

### 本地构建

```bash
# 克隆仓库
git clone https://github.com/yourorg/nexus-vpn
cd nexus-vpn/app

# 安装 Flutter 依赖
flutter pub get

# 下载 sing-box 二进制（见 BUILD.md 获取各平台命令）
# macOS 快速下载：
mkdir -p assets/cores
curl -fsSL https://github.com/SagerNet/sing-box/releases/download/v1.9.3/sing-box-1.9.3-darwin-arm64.tar.gz | tar xz
mv sing-box-1.9.3-darwin-arm64/sing-box assets/cores/sing-box && chmod +x assets/cores/sing-box

# 运行（Simulator 模式，无需真实后端）
flutter run

# 构建 Release
flutter build macos --release   # macOS
flutter build windows --release # Windows
flutter build linux --release   # Linux
flutter build apk --release --split-per-abi  # Android
flutter build ios --release --no-codesign    # iOS
```

### CI 触发 Release

```bash
# 打 tag 即可触发 GitHub Actions 自动构建并发布
git tag v1.0.0
git push origin v1.0.0
```

CI 将自动：
1. 并行在 macOS / Windows / Ubuntu / macOS(iOS) 上构建
2. 下载对应平台的 sing-box 二进制打包进去
3. 创建 GitHub Release 并上传全部安装包

---

## 项目结构

```
nexus-vpn/
├── .github/
│   └── workflows/
│       ├── release.yml        # 多平台 Release CI（tag 触发）
│       ├── build-check.yml    # PR 构建验证
│       └── ci.yml             # 协议 / 解析器 / 自动修复单测
├── app/                       # Flutter 应用主目录
│   ├── lib/
│   │   ├── main.dart          # 入口
│   │   ├── app.dart           # 主题 / 路由
│   │   ├── models/            # 数据模型（ProxyNode 等）
│   │   ├── providers/         # 状态管理（VPN / Nodes / Settings / Logs）
│   │   ├── screens/           # 5 个页面（仪表盘 / 节点 / 导入 / 日志 / 设置）
│   │   ├── widgets/           # 共享组件（GlassCard / ConnectButton）
│   │   └── core/              # 核心逻辑（NodeParser / SingboxRunner / AutofixEngine / ConfigGenerator）
│   ├── ios/
│   │   └── NexusVPNExtension/ # NEPacketTunnelProvider（iOS / macOS Network Extension）
│   ├── android/
│   │   └── app/src/main/kotlin/com/nexusvpn/
│   │       └── VpnService.kt  # Android VpnService + TUN
│   ├── windows/
│   │   ├── runner/
│   │   │   └── vpn_channel.cpp # WinTUN + 系统代理 Platform Channel
│   │   └── installer/
│   │       └── nexus-vpn.iss  # Inno Setup 安装包脚本
│   ├── assets/
│   │   ├── cores/             # sing-box 二进制（构建时下载）
│   │   ├── icons/             # 应用图标
│   │   └── fonts/             # Inter 字体
│   ├── pubspec.yaml           # Flutter 依赖声明
│   └── BUILD.md               # 详细构建指南
├── src/                       # TypeScript 工具库（Node.js / Electron 可复用）
│   ├── parsers/
│   │   └── node_parser.ts     # URI / 订阅 / sing-box JSON 解析器
│   └── core/
│       ├── singbox_generator.ts # sing-box 配置生成器
│       └── health_monitor.ts    # 运行时健康监控
├── architecture.svg           # 跨平台架构图
├── nexus-vpn-preview.html     # 可交互 Web UI 预览
└── README.md                  # 本文档
```

完整注解版目录见 [STRUCTURE.md](STRUCTURE.md)。

---

## 配置示例

### sing-box 生成配置（VLESS + REALITY）

```json
{
  "outbounds": [{
    "type": "vless",
    "tag": "proxy",
    "server": "your.server.com",
    "server_port": 443,
    "uuid": "your-uuid",
    "flow": "xtls-rprx-vision",
    "tls": {
      "enabled": true,
      "server_name": "yahoo.com",
      "utls": { "enabled": true, "fingerprint": "chrome" },
      "reality": {
        "enabled": true,
        "public_key": "your-public-key",
        "short_id": "your-short-id"
      }
    }
  }]
}
```

---

## Secrets 配置（GitHub CI）

在仓库 Settings → Secrets and variables → Actions 中配置：

| Secret | 用途 | 必需 |
|--------|------|------|
| `ANDROID_KEYSTORE_BASE64` | Android 签名证书（Base64）| 发布签名版 APK |
| `ANDROID_STORE_PASS` | Keystore 密码 | 同上 |
| `ANDROID_KEY_PASS` | Key 密码 | 同上 |
| `ANDROID_KEY_ALIAS` | Key 别名 | 同上 |
| `IOS_CERTIFICATE_BASE64` | iOS .p12 证书（Base64）| 签名 IPA |
| `IOS_CERTIFICATE_PASS` | 证书密码 | 同上 |
| `IOS_PROVISION_BASE64` | Provisioning Profile | 同上 |
| `TAP_REPO_TOKEN` | Homebrew Tap 仓库 PAT | 自动更新 Homebrew |
| `WINGET_REPO_TOKEN` | winget 仓库 PAT | 自动提交 winget manifest |

> 未配置签名 Secrets 时，CI 仍会构建并上传未签名包，可用 AltStore / sideloadly 安装 iOS 包。

---

## 贡献

欢迎 PR 和 Issue！

```bash
# Fork → Clone → 创建分支
git checkout -b feat/my-feature

# 开发 → 提交
git commit -m "feat: add XXX support"

# 推送 → 创建 PR 到 develop 分支
git push origin feat/my-feature
```

### 添加新协议支持

1. 在 `lib/models/proxy_node.dart` 的 `Protocol` 枚举添加新协议
2. 在 `lib/core/node_parser.dart` 添加 URI 解析方法
3. 在 `lib/core/config_generator.dart` 添加 sing-box outbound 生成逻辑
4. 在 `lib/core/autofix_engine.dart` 添加相关修复规则
5. 添加测试：`test/parsers/xxx_parser_test.dart`

---

## 许可证

[MIT License](LICENSE) · Copyright © 2025 Nexus VPN Team

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给个 Star！**

[报告问题](https://github.com/yourorg/nexus-vpn/issues) · [功能请求](https://github.com/yourorg/nexus-vpn/issues) · [讨论](https://github.com/yourorg/nexus-vpn/discussions)

</div>
