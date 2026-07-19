<!-- README-I18N:START -->
**English** | [简体中文](./README.zh-CN.md)
<!-- README-I18N:END -->

<div align="center">

<img src="app/assets/icons/app_icon_512.png" width="112" height="112" alt="Nexus VPN"/>

# Nexus VPN

**One client. Five platforms. Powered by sing-box.**

A cross-platform proxy client for self-hosted and subscription-based setups —
import nodes, fix common config issues, and connect with a consistent desktop
and mobile experience.

[![CI](https://img.shields.io/github/actions/workflow/status/Jas0n0ss/nexus/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/Jas0n0ss/nexus/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Jas0n0ss/nexus?style=flat-square&color=0d9488)](https://github.com/Jas0n0ss/nexus/releases/latest)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android-24292f?style=flat-square)](#downloads)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![sing-box](https://img.shields.io/badge/core-sing--box%201.9.x-orange?style=flat-square)](https://github.com/SagerNet/sing-box)

[Download](#downloads) · [Quick start](#quick-start) · [Features](#features) · [Build](app/BUILD.md) · [Architecture](STRUCTURE.md)

</div>

---

## Why Nexus

Deploying a node with a script is easy. Running a **reliable client** across
phones and desktops is not — protocols differ, subscription formats conflict,
and small config mistakes break connectivity.

Nexus focuses on that gap:

| | |
|---|---|
| **Unified import** | Subscription URL, share URI, or local config file |
| **Autofix on import** | Corrects common incompatibilities before you connect |
| **True cross-platform** | macOS · Windows · Linux · iOS · Android, same product model |
| **sing-box core** | Modern protocols, routing, and TUN / system-proxy paths |

Built for people who run their own infrastructure, use multi-protocol
subscriptions, or want one client that behaves the same everywhere.

---

## Features

### Protocols

| Protocol | Transport | Security |
|----------|-----------|----------|
| **VLESS** | TCP / WebSocket / gRPC | REALITY / TLS |
| **VMess** | TCP / WebSocket / gRPC | TLS / none |
| **Trojan** | TCP / WebSocket / gRPC | TLS |
| **Shadowsocks** | TCP / UDP | AEAD-2022 / AES-GCM |
| **Hysteria 2** | QUIC | TLS |
| **TUIC v5** | QUIC | TLS |
| **WireGuard** | UDP | Built-in |

### Import sources

| Server toolkit | Typical format |
|----------------|----------------|
| [233boy/sing-box](https://github.com/233boy/sing-box) | sing-box JSON / URI |
| [233boy/Xray](https://github.com/233boy/Xray) | Xray JSON / URI |
| [233boy/v2ray](https://github.com/233boy/v2ray) | Base64 subscription / `vmess://` |
| [mack-a/v2ray-agent](https://github.com/mack-a/v2ray-agent) | Multi-protocol subscription |
| [yonggekkk/sing-box-yg](https://github.com/yonggekkk/sing-box-yg) | sing-box JSON |

Also supported: Clash YAML, Base64 URI lists, and `file://` local paths.

### Autofix (examples)

- VMess `encryption: auto` → sing-box-compatible value  
- gRPC ALPN alignment to reduce handshake failures  
- Hysteria2 / TUIC vs TCP mux conflict handling  
- Missing Trojan / VLESS SNI filled when possible  
- REALITY fingerprint defaults  
- Shadowsocks 2022 key format checks  

### Client experience

- **Graphite Tide** UI — graphite surfaces, teal accent, Syne + IBM Plex Sans  
- Desktop sidebar / mobile tab shell  
- Live up/down throughput, latency probes, connection dashboard  
- Route modes: **rule** · **global** · **direct** (with optional ads block)

---

## How it works

```
Import URL / URI / file  →  Autofix  →  Pick node & test  →  Connect  →  Dashboard
```

| Platform | Traffic path |
|----------|--------------|
| Android | `VpnService` + sing-box |
| iOS | Network Extension (Packet Tunnel) |
| Windows | WinTUN + sing-box |
| macOS / Linux | sing-box process (+ system proxy when TUN is off) |

UI preview (static): [`nexus-vpn-preview.html`](nexus-vpn-preview.html)  
Module map: [STRUCTURE.md](STRUCTURE.md)

---

## Downloads

| Platform | Package | Notes |
|----------|---------|--------|
| macOS | `.dmg` | Apple Silicon + Intel |
| Windows | Setup `.exe` / portable ZIP | Installer includes WinTUN |
| Linux | AppImage / `.deb` / `.rpm` | Common distros |
| Android | Universal APK (recommended) / per-ABI / Play AAB | Install `.apk`, not `.aab` |
| iOS | Unsigned IPA | Sideload (AltStore / TrollStore / …) |

**Stable builds:** [GitHub Releases](https://github.com/Jas0n0ss/nexus/releases/latest)  
Every successful push to `main` publishes a versioned Release (CI keeps the **latest 2**).  
PR builds produce artifacts only — merge to `main` to ship.

> **macOS Gatekeeper (“Apple could not verify…”)**  
> Unsigned DMGs are blocked until Developer ID + notarization secrets are configured.  
> Workaround: right-click → Open. Full guide: [docs/CODE_SIGNING.md](docs/CODE_SIGNING.md).

---

## Quick start

1. **Import** — paste a subscription URL or node URI  
2. **Select** — open Nodes, run latency test, pick a reachable server  
3. **Connect** — return to the dashboard and tap Connect  

```text
# Subscription
https://your.domain/sub?token=xxx

# Single node
vless://uuid@host:443?encryption=none&security=reality&sni=www.example.com&fp=chrome&pbk=xxx&type=tcp#name
```

**Local development requires the sing-box binary:**

```bash
bash app/scripts/fetch_singbox.sh
cd app && flutter pub get && flutter run
```

Details: [app/BUILD.md](app/BUILD.md)

---

## Development

| Doc | Topic |
|-----|--------|
| [app/BUILD.md](app/BUILD.md) | Flutter scaffold, cores, platform packages |
| [docs/CODE_SIGNING.md](docs/CODE_SIGNING.md) | Developer ID / Authenticode / Play / iOS trust |
| [STRUCTURE.md](STRUCTURE.md) | Repository layout & module responsibilities |

### Release pipeline

| Event | Result |
|-------|--------|
| Push / merge → **`main`** | Full matrix build → auto version bump → GitHub Release |
| Pull request | Lint, test, packages as CI artifacts (**no** Release) |
| Tag `v*.*.*` | Rebuild + Release (skipped if that Release already exists) |

Version scheme (patch always `.0`): `0.10 → 0.11 → … → 0.19 → 1.1 → …`  
Retention: only the **two newest** Releases are kept; older tags/releases are pruned.

---

## License

Released under the [MIT License](LICENSE).
