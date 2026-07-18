<div align="center">

<img src="app/assets/icons/app_icon_512.png" width="128" height="128" alt="Nexus VPN Logo"/>

# Nexus

**一套界面，五端可用的现代 VPN 客户端**

基于 [sing-box](https://github.com/SagerNet/sing-box) 内核与 Flutter 构建，把常见代理协议、订阅导入和系统级流量接管收进同一款应用——桌面与移动端共享一致的体验。

[![CI](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/nexus/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/Jas0n0ss/nexus/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Jas0n0ss/nexus?style=flat-square&color=3b82f6)](https://github.com/Jas0n0ss/nexus/releases)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android-lightgrey?style=flat-square)](#下载)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

[**下载**](#下载) · [**快速上手**](#快速上手) · [**功能一览**](#功能一览) · [**项目结构**](STRUCTURE.md)

</div>

---

## 为什么是 Nexus

用脚本部署节点不难，难的是客户端：协议多、订阅格式乱、配置容易踩坑，桌面和手机还要各找一套工具。

Nexus 面向这个问题：

- **一处导入** — 订阅链接、单节点 URI、配置文件，都能直接进应用
- **自动纠错** — 导入时修复常见不兼容项，减少“连不上再手工改 JSON”
- **真正跨平台** — macOS / Windows / Linux / iOS / Android 同一套产品逻辑
- **内核统一** — 底层由 sing-box 承载，协议与分流能力跟上主流生态

适合自建节点用户、多协议订阅用户，以及希望桌面端与手机端体验一致的人。

---

## 功能一览

### 多协议

| 协议 | 传输 | 安全 |
|------|------|------|
| **VLESS** | TCP / WebSocket / gRPC | REALITY / TLS |
| **VMess** | TCP / WebSocket / gRPC | TLS / None |
| **Trojan** | TCP / WebSocket / gRPC | TLS |
| **Shadowsocks** | TCP / UDP | AEAD-2022 / AES-GCM |
| **Hysteria 2** | QUIC | TLS |
| **TUIC v5** | QUIC | TLS |
| **WireGuard** | UDP | 内置加密 |

### 一键导入

支持从常见服务端部署脚本产出的订阅与配置直接导入：

| 服务端脚本 | 常见格式 |
|-----------|---------|
| [233boy/sing-box](https://github.com/233boy/sing-box) | sing-box JSON / URI |
| [233boy/Xray](https://github.com/233boy/Xray) | Xray JSON / URI |
| [233boy/v2ray](https://github.com/233boy/v2ray) | Base64 订阅 / `vmess://` |
| [mack-a/v2ray-agent](https://github.com/mack-a/v2ray-agent) | 多协议订阅 |
| [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) | sing-box JSON |

导入方式：

- **订阅 URL**
- **URI 粘贴**（`vless://` `vmess://` `trojan://` `ss://` `hysteria2://` `tuic://` `wg://`）
- **本地配置文件**

### 自动修复

导入后会尽量自动处理常见配置问题，例如：

- VMess `encryption: auto` → 兼容 sing-box 的取值
- gRPC ALPN 对齐，降低握手失败
- Hysteria2 / TUIC 与 TCP Mux 冲突时自动调整
- Trojan / VLESS 缺失 SNI 时补全
- REALITY 缺少 fingerprint 时给出合理默认
- Shadowsocks 2022 密钥格式校验

### 界面与体验

Apple 风格的轻量界面：毛玻璃卡片、大号连接按钮、实时上下行曲线、深色 / 浅色跟随系统。桌面端左侧导航，移动端底部标签栏——同一产品，适配不同形态。

### 分流

连接后可按场景切换：

- **规则分流** — 国内流量直连，并配合广告屏蔽规则
- **全局代理**
- **直连**

---

## 它如何工作

对用户来说，路径很短：

```
导入订阅 / URI → 自动修复 → 选节点测延迟 → 一键连接 → 仪表盘看状态与速率
```

对系统来说，各平台用合适的方式接管流量：

| 平台 | 流量接管 |
|------|---------|
| Android | `VpnService` + sing-box |
| iOS | Network Extension（Packet Tunnel） |
| Windows | WinTUN 虚拟网卡 |
| macOS / Linux | sing-box 内核 + 系统代理 |

更细的模块划分见 [STRUCTURE.md](STRUCTURE.md)；浏览器里可直接打开 [`nexus-vpn-preview.html`](nexus-vpn-preview.html) 预览界面风格。

---

## 下载

| 平台 | 包类型 | 说明 |
|------|--------|------|
| macOS | `.dmg` | 拖入 Applications（Apple Silicon + Intel） |
| Windows | 安装包 / 便携 ZIP | 安装包含 WinTUN |
| Linux | AppImage / `.deb` / `.rpm` | 常见发行版可直接用 |
| Android | 通用 APK（推荐）/ 分 ABI APK / Play AAB | 手机请装 `.apk`，不要下 `.aab` |
| iOS | 未签名 IPA | 需侧载（AltStore / TrollStore 等） |

正式版本见 [Releases](https://github.com/Jas0n0ss/nexus/releases/latest)。  
每次推送到 `main` 也会产出全平台构建，可在 [Actions](https://github.com/Jas0n0ss/nexus/actions/workflows/ci.yml) 对应运行的 Artifacts 中下载。

---

## 快速上手

1. **导入** — 打开「导入」，粘贴订阅链接或单节点 URI  
2. **选择** — 在「节点」里测延迟，选延迟最低的节点  
3. **连接** — 回到仪表盘，点连接按钮  

示例：

```
# 订阅
https://your.domain/sub?token=xxx

# 单节点
vless://uuid@host:443?encryption=none&security=reality&sni=yahoo.com&fp=chrome&pbk=xxx&type=tcp#节点名
```

---

## 开发者

本地构建、平台脚手架、sing-box 内核准备与签名配置，见 [app/BUILD.md](app/BUILD.md)。  
代码目录与职责说明见 [STRUCTURE.md](STRUCTURE.md)。

推送 `v*.*.*` 标签会触发 CI 并创建 GitHub Release。

---

## 许可证

[MIT License](LICENSE)
