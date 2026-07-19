<!-- README-I18N:START -->
[English](./README.md) | **简体中文**
<!-- README-I18N:END -->

<div align="center">

<img src="app/assets/icons/app_icon_512.png" width="128" height="128" alt="Nexus"/>

# Nexus

**一套客户端，五端可用 · 多节点故障转移 · sing-box 内核**

面向自建与订阅场景的跨平台代理客户端：导入、自动纠错、连接，  
并具备 Passwall 风格的自动故障转移，尽量保持会话可用。

[![CI](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/nexus/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/Jas0n0ss/nexus/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Jas0n0ss/nexus?style=flat-square&color=ff9900)](https://github.com/Jas0n0ss/nexus/releases/latest)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android-24292f?style=flat-square)](#下载)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![sing-box](https://img.shields.io/badge/core-sing--box%201.9.x-orange?style=flat-square)](https://github.com/SagerNet/sing-box)

[下载](#下载) · [快速上手](#快速上手) · [高可用](#高可用) · [构建](app/BUILD.md)

</div>

---

## 功能

- **协议** — VLESS / VMess / Trojan / Shadowsocks / Hysteria2 / TUIC / WireGuard  
- **导入** — 订阅链接、分享 URI、Clash YAML、sing-box JSON、本地文件  
- **自动修复** — 导入时纠正 ALPN / SNI / encryption / REALITY 等常见问题  
- **分流** — 规则 / 全局 / 直连（可选广告屏蔽）  
- **故障转移** — 探测当前节点 → 切换备用 → 主节点恢复后切回  
- **平台** — macOS · Windows · Linux · iOS · Android  

高可用逻辑参考 [OpenWrt Passwall](https://github.com/Openwrt-Passwall/openwrt-passwall)
的 `socks_auto_switch`（探测 URL、备用节点、恢复主节点、区分本机断网）。

---

## 高可用

开启 **自动故障转移**（默认开启）后：

1. 约每 30 秒通过本地 mixed 端口探测 `generate_204`  
2. 探测失败且本机仍有网络 → 切换到下一节点  
3. 候选 = 主节点 + 其它已导入节点（按延迟排序）  
4. 可选 **恢复主节点**：主节点恢复后自动切回  

设置 →「自动化 · 高可用」。

---

## 下载

| 平台 | 包类型 |
|------|--------|
| macOS | `.dmg` |
| Windows | 安装包 / 便携 ZIP |
| Linux | AppImage / `.deb` / `.rpm` |
| Android | 通用 APK（推荐） |
| iOS | 未签名 IPA（侧载） |

**发布页：** https://github.com/Jas0n0ss/nexus/releases/latest  

推送到 `main` 会自动升版本并发布（仅保留最新 **2** 个 Release）。  
PR 上的 CI 只产出构建产物。

**可信安装包**（无 Gatekeeper / SmartScreen 警告）需要把各平台官方证书配进
GitHub Secrets，见 [docs/TRUSTED_BUILDS.md](docs/TRUSTED_BUILDS.md) 与
[docs/CODE_SIGNING.md](docs/CODE_SIGNING.md)。  
Android 可用脚本生成 keystore；macOS / Windows 必须使用付费的 Apple / CA 证书，无法凭空消除系统警告。

---

## 快速上手

```bash
bash app/scripts/fetch_singbox.sh
cd app && flutter pub get && flutter run
```

1. 导入订阅或 URI  
2. 测延迟并选择节点  
3. 连接 — 后台健康检查会自动故障转移  

---

## 开发

| 文档 | 内容 |
|------|------|
| [app/BUILD.md](app/BUILD.md) | 构建与内核 |
| [docs/TRUSTED_BUILDS.md](docs/TRUSTED_BUILDS.md) | 可信包所需 Secrets |
| [docs/CODE_SIGNING.md](docs/CODE_SIGNING.md) | 签名与公证 |
| [STRUCTURE.md](STRUCTURE.md) | 目录结构 |
| [nexus-preview.html](nexus-preview.html) | 界面静态预览 |

---

## 许可证

[MIT](LICENSE)
