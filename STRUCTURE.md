# Nexus VPN — 完整文件目录结构

> 每个文件均附有功能说明，帮助新贡献者快速定位代码。

```
nexus-vpn/
│
├── README.md                          # English project overview (canonical)
├── README.zh-CN.md                    # 简体中文版 README
├── LICENSE                            # MIT
├── STRUCTURE.md                       # 本文件：注解版目录结构
│
├── nexus-vpn-preview.html             # 🎨 可交互 Web UI 预览（无需后端，直接浏览器打开）
│                                      #    Apple 深色毛玻璃风格，Chart.js 实时曲线，12 个 Mock 节点
│
├── architecture.svg                   # 🗺️ 跨平台架构图（SVG）
│                                      #    五层结构：UI → 业务逻辑 → 代理核心 → 平台集成 → 网络
│
├── .github/
│   └── workflows/
│       ├── release.yml                # 🚀 Release CI（git tag 触发）
│       │                              #    Jobs: prepare → build-macos → build-windows →
│       │                              #           build-linux → build-android → build-ios →
│       │                              #           release → update-pkg-managers
│       │                              #    产物：DMG / EXE安装包 / AppImage / .deb /
│       │                              #           split-ABI APK + AAB / unsigned IPA
│       │
│       ├── build-check.yml            # ✅ PR 验证 CI（push develop / PR to main|develop 触发）
│       │                              #    Jobs: lint → test → check-{android,linux,windows,macos}
│       │                              #           → all-checks（branch protection gate）
│       │                              #    使用 stub 二进制文件，无需真实 sing-box
│       │
│       └── ci.yml                     # 🧪 协议 / 解析器单元测试 CI
│                                      #    10 Jobs：lint / parser-test / uri-validation /
│                                      #    sing-box-check / latency-sim / autofix-scenarios /
│                                      #    script-source-compat / multi-platform / playwright /
│                                      #    security-scan
│
├── src/                               # TypeScript 工具库（可在 Node.js / Electron 中复用）
│   ├── parsers/
│   │   └── node_parser.ts             # 通用 URI / 订阅解析器
│   │                                  #   parseUri()        — 解析 7 种 URI scheme
│   │                                  #   parseSubscription() — URL拉取 / Base64 / JSON全配置
│   │                                  #   parseSingboxConfig() — sing-box outbounds 提取
│   │                                  #   detectSource()    — 脚本来源识别（5 种）
│   │                                  #   fixVmessEncryption / fixAlpnMismatch /
│   │                                  #   fixMuxConflict / fixTrojanSni /
│   │                                  #   fixReality / fixSsMethod — 自动修复函数
│   │
│   └── core/
│       ├── singbox_generator.ts       # sing-box 1.9.x 配置生成器
│       │                              #   generateSingboxConfig(opts) — 完整 JSON 生成
│       │                              #   nodeToOutbound(node) — ProxyNode → outbound 对象
│       │                              #   TUN inbound 172.19.0.1/30 / mixed 7890 /
│       │                              #   GeoSite+GeoIP 规则 / Clash API 9090
│       │
│       └── health_monitor.ts          # 运行时健康监控
│                                      #   HealthMonitor class — 可配置检测间隔和阈值
│                                      #   检测项：核心崩溃 / CPU > 80% / 内存 > 512MB /
│                                      #           DNS 泄漏 / 延迟 > 2s
│                                      #   超过 maxRestarts 后切换 fallbackCore
│
└── app/                               # Flutter 应用（dart → macOS / Windows / Linux / iOS / Android）
    │
    ├── pubspec.yaml                   # Flutter 依赖声明
    │                                  #   provider / fl_chart / flutter_animate / dio /
    │                                  #   hive_flutter / file_picker / mobile_scanner /
    │                                  #   process_run / window_manager / system_tray /
    │                                  #   flutter_secure_storage
    │
    ├── BUILD.md                       # 详细构建指南（各平台 sing-box 下载命令 / 签名配置）
    │
    ├── lib/
    │   ├── main.dart                  # 应用入口
    │   │                              #   MultiProvider 挂载（Settings/Logs/Nodes/VPN）
    │   │                              #   桌面：window_manager（900×600 最小 / 1100×720 默认）
    │   │                              #   移动：竖屏锁定
    │   │
    │   ├── app.dart                   # NexusApp — 主题 + 路由
    │   │                              #   _buildTheme()：Inter 字体 / 深色 #0F0F13 /
    │   │                              #   主色 #3B82F6 / 圆角卡片 + 微妙边框
    │   │
    │   ├── models/
    │   │   └── proxy_node.dart        # ProxyNode HiveObject — 所有字段（7 种协议）
    │   │                              #   枚举：Protocol / Transport / Security / NodeSource
    │   │                              #   计算属性：protocolLabel / latencyColor / latencyLabel
    │   │                              #   ProxyNode.demoNodes — 8 个预设节点（Tokyo VLESS+REALITY
    │   │                              #   Singapore Hysteria2 LA VMess HK Trojan…）
    │   │
    │   ├── providers/                 # 状态管理（Provider + ChangeNotifier 模式）
    │   │   ├── vpn_provider.dart      # VpnProvider — 连接状态机
    │   │   │                          #   VpnState: disconnected/connecting/connected/
    │   │   │                          #             disconnecting/error
    │   │   │                          #   connect(node): 启动 singboxRunner / 起 stats 定时器 /
    │   │   │                          #                  拉取外部 IP / Google+Cloudflare 测试
    │   │   │                          #   uploadHistory / downloadHistory：40 点滚动缓冲（曲线图）
    │   │   │
    │   │   ├── nodes_provider.dart    # NodesProvider — 节点管理
    │   │   │                          #   importFromUri(input)：NodeParser + AutofixEngine
    │   │   │                          #                         → 去重 → Hive 持久化
    │   │   │                          #   testLatency / testAll：TCP 连接时延测试
    │   │   │                          #   首次启动 Hive 为空时加载 demoNodes
    │   │   │
    │   │   ├── settings_provider.dart # SettingsProvider — 用户偏好（SharedPreferences）
    │   │   │                          #   主题 / 语言 / 核心引擎 / 分流模式 / 开机启动 / 托盘
    │   │   │
    │   │   └── logs_provider.dart     # LogsProvider — 运行日志列表（最多 2000 条）
    │   │
    │   ├── screens/
    │   │   ├── main_shell.dart        # 根布局外壳
    │   │   │                          #   _DesktopLayout：220px 侧边栏 + 内容区（> 720px）
    │   │   │                          #   _MobileLayout：IndexedStack + NavigationBar 底部标签
    │   │   │
    │   │   ├── dashboard_screen.dart  # 仪表盘页
    │   │   │                          #   _ConnectionCard：动态状态点 / IP 显示 / 节点协议标签 /
    │   │   │                          #                    在线计时 / ConnectButton
    │   │   │                          #   _SpeedChart：LineChart（上传绿 + 下载蓝）
    │   │   │                          #   _QuickNodes：延迟最低的前 5 节点横向滚动
    │   │   │
    │   │   ├── nodes_screen.dart      # 节点列表页
    │   │   │                          #   分组显示（按 NodeSource）/ 延迟排序 / 删除 / 复制 URI
    │   │   │
    │   │   ├── import_screen.dart     # 导入配置页
    │   │   │                          #   4 种导入模式按钮：URL / URI / 文件 / 二维码
    │   │   │                          #   进度指示器 / 自动修复标签展示 / 解析节点列表
    │   │   │
    │   │   ├── logs_screen.dart       # 运行日志页
    │   │   │                          #   实时滚动日志 / 日志级别彩色标识 / 复制 / 清空
    │   │   │
    │   │   └── settings_screen.dart   # 设置页
    │   │                              #   核心引擎切换 / 分流模式 / TUN 开关 /
    │   │                              #   开机启动 / 系统代理 / 主题 / 语言
    │   │
    │   ├── widgets/
    │   │   ├── glass_card.dart        # GlassCard — 毛玻璃卡片基础组件
    │   │   ├── connect_button.dart    # ConnectButton — 大圆形连接按钮（带动画）
    │   │   ├── protocol_badge.dart    # ProtocolBadge — 协议彩色标签
    │   │   ├── latency_dot.dart       # LatencyDot — 延迟状态圆点
    │   │   └── node_card.dart         # NodeCard — 节点列表条目
    │   │
    │   └── core/                      # Dart 核心逻辑
    │       ├── node_parser.dart        # URI / 订阅解析（Dart 实现）
    │       │                           #   7 种 URI scheme 解析
    │       │                           #   _flagFromName() — 国家关键词 → 旗帜 emoji
    │       │                           #   _groupFromName() — 国家关键词 → 地区分组
    │       │                           #   _detectSource() — 脚本来源识别
    │       │
    │       ├── autofix_engine.dart     # 自动修复引擎
    │       │                           #   AutofixEngine.fixAll(nodes) — 6 种修复
    │       │                           #   _fixGrpcAlpn / _fixMuxOnQuic / _fixTrojanSni /
    │       │                           #   _fixRealityFingerprint / _fixSs2022Key /
    │       │                           #   _fixVmessZeroAlterId
    │       │                           #   返回 AutoFix 记录（字段名 / 旧值 / 新值）
    │       │
    │       ├── config_generator.dart   # sing-box 配置生成器（Dart 实现）
    │       │                           #   ConfigGenerator.generate(node) → Map<String,dynamic>
    │       │                           #   _dns() / _inbounds() / _outbound() /
    │       │                           #   _transport() / _route()
    │       │                           #   WireGuard 特殊处理（peers 数组）
    │       │
    │       └── singbox_runner.dart     # sing-box 进程管理
    │                                   #   start(node)：写临时配置 → 查找二进制 → 启动进程
    │                                   #   二进制搜索路径：/usr/local/bin / /opt/homebrew/bin /
    │                                   #                   /usr/bin / 应用支持目录 / Windows PATH
    │                                   #   Simulator 模式：找不到二进制时启动 _fakeTicker
    │                                   #   (生成随机上传/下载数据，CI 可用)
    │
    ├── ios/
    │   ├── Runner/                     # 主 App Target
    │   │   ├── AppDelegate.swift
    │   │   └── Assets.xcassets/
    │   └── NexusVPNExtension/          # Network Extension Target（iOS / macOS 共用）
    │       ├── PacketTunnelProvider.swift  # NEPacketTunnelProvider 子类
    │       │                               #   startTunnel()：写配置到 AppGroup 容器 /
    │       │                               #                  setTunnelNetworkSettings() /
    │       │                               #                  启动 sing-box 进程
    │       │                               #   buildNetworkSettings()：IPv4 172.19.0.1/30 /
    │       │                               #                           IPv6 fdfe:dcba:9876::1/126 /
    │       │                               #                           DNS 172.19.0.1 / MTU 9000
    │       │                               #   崩溃检测：监控 stdout "panic"/"fatal"，
    │       │                               #             2s 延迟后自动重启
    │       └── Info.plist
    │
    ├── android/
    │   └── app/src/main/
    │       ├── AndroidManifest.xml     # VPN 权限 / 前台服务 / 文件提供者
    │       ├── kotlin/com/nexusvpn/
    │       │   ├── MainActivity.kt     # Flutter 主 Activity
    │       │   └── VpnService.kt       # NexusVpnService : VpnService
    │       │                           #   ACTION_START / ACTION_STOP intent 处理
    │       │                           #   buildTun()：VpnService.Builder 172.19.0.1/30 /
    │       │                           #               DNS 172.19.0.1 / MTU 9000 / 全局路由
    │       │                           #   extractBinary()：首次运行将 sing-box-{ABI}
    │       │                           #                    从 assets 复制到 filesDir
    │       │                           #   崩溃检测 coroutine：2s 后自动重启
    │       │                           #   前台通知（NotificationChannel）
    │       └── assets/
    │           └── cores/              # 构建时下载（CI 自动填充）
    │               ├── sing-box-arm64-v8a
    │               ├── sing-box-armeabi-v7a
    │               └── sing-box-x86_64
    │
    ├── windows/
    │   ├── runner/
    │   │   ├── main.cpp               # Windows 入口
    │   │   ├── flutter_window.cpp     # Flutter 窗口 + MethodChannel 注册
    │   │   ├── vpn_channel.cpp        # Platform Channel "com.nexusvpn/vpn"
    │   │   │                          #   startVpn：写配置 → 加载 wintun.dll →
    │   │   │                          #              CreateProcess sing-box.exe →
    │   │   │                          #              SetSystemProxy(127.0.0.1, 7890)
    │   │   │                          #   stopVpn：TerminateProcess + ClearSystemProxy
    │   │   │                          #   getStats：读取 Clash API 流量统计
    │   │   │                          #   SetSystemProxy / ClearSystemProxy：
    │   │   │                          #     HKCU Internet Settings + InternetSetOptionA 刷新
    │   │   ├── sing-box.exe           # 构建时下载（gitignore）
    │   │   └── wintun.dll             # 构建时下载（gitignore）
    │   └── installer/
    │       └── nexus-vpn.iss          # Inno Setup 6 安装包脚本
    │                                  #   打包：Flutter Release + sing-box.exe + wintun.dll
    │                                  #   功能：WinTUN 驱动静默安装 / PATH 注册 /
    │                                  #         桌面快捷方式 / 开机启动选项
    │                                  #   最低系统：Windows 10 1809+ 64-bit
    │                                  #   语言：英文 + 简体中文
    │
    ├── macos/
    │   ├── Runner/
    │   │   ├── AppDelegate.swift
    │   │   └── Assets.xcassets/
    │   └── NexusVPNExtension/         # macOS Network Extension（与 iOS 共用 Swift 代码）
    │       └── PacketTunnelProvider.swift  # 同 iOS（通过 #if os(macOS) 做平台差异）
    │
    ├── linux/
    │   └── CMakeLists.txt             # Linux 构建配置
    │
    └── assets/
        ├── cores/                     # 桌面平台 sing-box 二进制（构建时下载，gitignore）
        │   └── sing-box               # macOS universal binary（lipo arm64 + amd64）
        ├── icons/
        │   ├── app_icon_512.png       # 主图标（512×512）
        │   ├── app_icon.ico           # Windows 图标
        │   └── app_icon.icns          # macOS 图标
        └── fonts/
            └── Inter/                 # Inter 字体族（UI 使用）
```

---

## 核心数据流

```
用户粘贴 URI / 订阅 URL
         │
         ▼
  NodeParser.parseUri()
  NodeParser.parseSubscription()
         │ ProxyNode 列表
         ▼
  AutofixEngine.fixAll()          ← 6 种自动修复
         │ 修复后的 ProxyNode 列表
         ▼
  NodesProvider（Hive 持久化）
         │ 用户选择节点
         ▼
  ConfigGenerator.generate()      ← sing-box 1.9.x JSON
         │ 配置文件路径
         ▼
  SingboxRunner.start()           ← 启动 sing-box 进程
  │    │                             或进入 Simulator 模式
  │    └─ 平台 VPN 集成
  │         ├── iOS/macOS：NEPacketTunnelProvider.startTunnel()
  │         ├── Android：NexusVpnService.buildTun()
  │         └── Windows：vpn_channel.cpp → WinTUN + 系统代理
  │
  └── VpnProvider stats 定时器（800ms）
           │ 上传/下载速率
           ▼
      fl_chart LineChart 实时更新
```

---

## 关键依赖版本

| 依赖 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.22+ | 跨平台框架 |
| sing-box | 1.9.3 | 代理核心（推荐）|
| Xray-core | 1.8.x | 备用核心 |
| v2ray-core | 5.x | 备用核心 |
| provider | ^6.1.2 | 状态管理 |
| hive_flutter | ^1.1.0 | 本地持久化 |
| fl_chart | ^0.68.0 | 速率曲线图 |
| flutter_animate | ^4.5.0 | 动画 |
| dio | ^5.5.0 | HTTP 客户端 |
| mobile_scanner | ^5.1.0 | 二维码扫描 |
| window_manager | ^0.3.9 | 桌面窗口管理 |
| system_tray | ^2.0.3 | 系统托盘 |
