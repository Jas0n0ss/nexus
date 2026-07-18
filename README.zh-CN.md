<!-- README-I18N:START -->
[English](./README.md) | **简体中文**
<!-- README-I18N:END -->

<div align="center">

<img src="app/assets/icons/app_icon_512.png" width="112" height="112" alt="Nexus VPN"/>

# Nexus VPN

**一套客户端，覆盖五端 · 内核基于 sing-box**

面向自建节点与多协议订阅的跨平台代理客户端：导入配置、自动纠错、一键连接，  
桌面与移动端共享同一套产品逻辑。

[![CI](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/nexus/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/Jas0n0ss/nexus/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Jas0n0ss/nexus?style=flat-square&color=0d9488)](https://github.com/Jas0n0ss/nexus/releases/latest)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android-24292f?style=flat-square)](#下载)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![sing-box](https://img.shields.io/badge/core-sing--box%201.9.x-orange?style=flat-square)](https://github.com/SagerNet/sing-box)

[下载](#下载) · [快速上手](#快速上手) · [功能](#功能) · [构建](app/BUILD.md) · [架构](STRUCTURE.md)

</div>

---

## 为什么选择 Nexus

用脚本部署节点并不难；难的是 **在手机和电脑上用同一套可靠客户端**：协议多、订阅格式杂、配置差一个字段就连不上。

Nexus 针对这些问题：

| | |
|---|---|
| **统一导入** | 订阅链接、分享 URI、本地配置文件 |
| **导入即修复** | 自动纠正常见不兼容项，减少手工改 JSON |
| **真正跨平台** | macOS · Windows · Linux · iOS · Android，同一产品模型 |
| **sing-box 内核** | 现代协议、分流，以及 TUN / 系统代理路径 |

适合自建节点用户、多协议订阅用户，以及希望桌面与手机体验一致的人。

---

## 功能

### 协议支持

| 协议 | 传输 | 安全 |
|------|------|------|
| **VLESS** | TCP / WebSocket / gRPC | REALITY / TLS |
| **VMess** | TCP / WebSocket / gRPC | TLS / none |
| **Trojan** | TCP / WebSocket / gRPC | TLS |
| **Shadowsocks** | TCP / UDP | AEAD-2022 / AES-GCM |
| **Hysteria 2** | QUIC | TLS |
| **TUIC v5** | QUIC | TLS |
| **WireGuard** | UDP | 内置加密 |

### 导入来源

| 服务端脚本 | 常见格式 |
|-----------|---------|
| [233boy/sing-box](https://github.com/233boy/sing-box) | sing-box JSON / URI |
| [233boy/Xray](https://github.com/233boy/Xray) | Xray JSON / URI |
| [233boy/v2ray](https://github.com/233boy/v2ray) | Base64 订阅 / `vmess://` |
| [mack-a/v2ray-agent](https://github.com/mack-a/v2ray-agent) | 多协议订阅 |
| [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) | sing-box JSON |

另支持 Clash YAML、Base64 URI 列表，以及 `file://` 本地路径。

### 自动修复（示例）

- VMess `encryption: auto` → 适配 sing-box 的取值  
- gRPC ALPN 对齐，降低握手失败  
- Hysteria2 / TUIC 与 TCP Mux 冲突时自动调整  
- Trojan / VLESS 缺失 SNI 时尽量补全  
- REALITY 缺少 fingerprint 时给出合理默认  
- Shadowsocks 2022 密钥格式校验  

### 客户端体验

- **Graphite Tide** 界面：石墨底色、海青强调色，Syne + IBM Plex Sans  
- 桌面侧栏 / 移动端底部导航  
- 实时上下行、延迟探测、连接仪表盘  
- 路由模式：**规则分流** · **全局代理** · **直连**（可选广告屏蔽）

---

## 工作方式

```
导入 URL / URI / 文件  →  自动修复  →  选节点并测速  →  连接  →  仪表盘
```

| 平台 | 流量接管 |
|------|---------|
| Android | `VpnService` + sing-box |
| iOS | Network Extension（Packet Tunnel） |
| Windows | WinTUN + sing-box |
| macOS / Linux | sing-box 进程（关闭 TUN 时可走系统代理） |

界面静态预览：[`nexus-vpn-preview.html`](nexus-vpn-preview.html)  
模块划分：[STRUCTURE.md](STRUCTURE.md)

---

## 下载

| 平台 | 包类型 | 说明 |
|------|--------|------|
| macOS | `.dmg` | Apple Silicon + Intel |
| Windows | 安装包 `.exe` / 便携 ZIP | 安装包含 WinTUN |
| Linux | AppImage / `.deb` / `.rpm` | 常见发行版 |
| Android | 通用 APK（推荐）/ 分 ABI / Play AAB | 请安装 `.apk`，不要装 `.aab` |
| iOS | 未签名 IPA | 需侧载（AltStore / TrollStore 等） |

**正式版：** [GitHub Releases](https://github.com/Jas0n0ss/nexus/releases/latest)  
每次成功推送到 `main` 会自动发版（CI **只保留最新 2 个** Release）。  
PR 上的 CI 只产出 Artifacts，**不会**发布 — 需合并进 `main`。

> **macOS「Apple could not verify…」**  
> 未配置 Developer ID + 公证时，Gatekeeper 会拦截。  
> 临时处理：右键应用 → 打开。完整说明见 [docs/CODE_SIGNING.md](docs/CODE_SIGNING.md)。

---

## 快速上手

1. **导入** — 粘贴订阅链接或单节点 URI  
2. **选择** — 在「节点」中测延迟，选可达节点  
3. **连接** — 回到仪表盘，点击连接  

```text
# 订阅
https://your.domain/sub?token=xxx

# 单节点
vless://uuid@host:443?encryption=none&security=reality&sni=www.example.com&fp=chrome&pbk=xxx&type=tcp#节点名
```

**本地开发需准备 sing-box 内核：**

```bash
bash app/scripts/fetch_singbox.sh
cd app && flutter pub get && flutter run
```

详见：[app/BUILD.md](app/BUILD.md)

---

## 开发

| 文档 | 内容 |
|------|------|
| [app/BUILD.md](app/BUILD.md) | Flutter 脚手架、内核下载、各平台打包 |
| [docs/CODE_SIGNING.md](docs/CODE_SIGNING.md) | Developer ID / Authenticode / Play / iOS 信任签名 |
| [STRUCTURE.md](STRUCTURE.md) | 仓库结构与模块职责 |

### 发版流程

| 事件 | 结果 |
|------|------|
| 推送 / 合并到 **`main`** | 全平台构建 → 自动升版本 → GitHub Release |
| Pull Request | Lint、测试、产物 Artifacts（**不**发 Release） |
| 标签 `v*.*.*` | 重建并发布（若该 Release 已存在则跳过） |

版本规则（patch 固定为 `.0`）：`0.10 → 0.11 → … → 0.19 → 1.1 → …`  
保留策略：仅保留最新 **两个** Release，更旧的 tag / 发布会被清理。

---

## 许可证

本项目采用 [MIT License](LICENSE) 开源。
