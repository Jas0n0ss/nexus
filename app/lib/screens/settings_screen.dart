import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/vpn_provider.dart';
import '../widgets/nexus_surface.dart';
import '../widgets/page_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
<<<<<<< HEAD
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              // Keep content readable and centered on ultra-wide windows
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (ctx, c) {
                    final twoCol = c.maxWidth > 640;
                    if (twoCol) {
                      // Balanced masonry: left = Core(4)+DNS(2) rows,
                      // right = Route(2)+Automation(3)+Appearance(1) rows.
                      // Both columns total 6 setting rows → equal height, no gap.
                      return const IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(children: [
                                _CoreSection(),
                                SizedBox(height: 16),
                                _DnsSection(),
                              ]),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(children: [
                                _RouteSection(),
                                SizedBox(height: 16),
                                _AutoSection(),
                                SizedBox(height: 16),
                                _AppearanceSection(),
                              ]),
                            ),
                          ],
                        ),
                      );
                    }
                    return const Column(children: [
                      _CoreSection(),
                      SizedBox(height: 16),
                      _DnsSection(),
                      SizedBox(height: 16),
                      _RouteSection(),
                      SizedBox(height: 16),
                      _AutoSection(),
                      SizedBox(height: 16),
                      _AppearanceSection(),
                    ]);
                  }),
                  const SizedBox(height: 16),
                  const _AboutSection(),
                ],
              ),
            ),
=======
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: '设置',
                subtitle: '路由 · TUN · DNS · 系统代理',
              ),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (ctx, c) {
                final wide = c.maxWidth > 640;
                final left = Column(children: [
                  const _CoreBlock(),
                  const SizedBox(height: 12),
                  const _DnsBlock(),
                ]);
                final right = Column(children: [
                  const _RouteBlock(),
                  const SizedBox(height: 12),
                  const _AutoBlock(),
                  const SizedBox(height: 12),
                  const _AppearanceBlock(),
                ]);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 12),
                      Expanded(child: right),
                    ],
                  );
                }
                return Column(children: [
                  left,
                  const SizedBox(height: 12),
                  right,
                ]);
              }),
            ],
>>>>>>> 248d32e43e80f0618f3004e32a0fcccfc30514b3
          ),
        ),
      ),
    );
  }
}

<<<<<<< HEAD
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('设置', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 4),
        Text('管理核心引擎、分流规则与自动化行为',
          style: TextStyle(fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
      ],
    );
  }
}

class _CoreSection extends StatelessWidget {
  const _CoreSection();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _SectionCard(
      icon: Icons.memory_rounded,
      accent: const Color(0xFF6366F1),
      title: '核心引擎',
      children: [
        _dropdownRow(context, '代理核心', '选择运行的代理内核',
          value: s.coreEngine.name,
          items: const ['singbox', 'xray', 'v2ray'],
          labels: const ['sing-box 1.9.x', 'Xray-core 1.8.x', 'v2ray-core 5.x'],
          onChanged: (v) => s.set((s) => s.coreEngine = CoreEngine.values.firstWhere((e) => e.name == v)),
        ),
        _divider(),
        _switchRow(context, 'TUN 模式', '全局透明代理（需管理员权限）', s.tunMode,
          (v) => s.set((s) => s.tunMode = v)),
        _divider(),
        _switchRow(context, '自动重连', '断线后自动重新连接', s.autoReconnect,
          (v) => s.set((s) => s.autoReconnect = v)),
        _divider(),
        _switchRow(context, 'Mux 多路复用', '减少 TCP 握手开销', s.mux,
          (v) => s.set((s) => s.mux = v)),
=======
Future<void> _set(
  BuildContext context,
  void Function(SettingsProvider s) fn, {
  bool reload = false,
}) async {
  context.read<SettingsProvider>().set(fn);
  if (reload && context.read<VpnProvider>().isConnected) {
    await context.read<VpnProvider>().applySettingsAndReconnect();
  }
}

class _CoreBlock extends StatelessWidget {
  const _CoreBlock();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _Section(
      title: '核心',
      children: [
        _SwitchRow('TUN 模式', '系统级透明代理', s.tunMode,
            (v) => _set(context, (x) => x.tunMode = v, reload: true)),
        _SwitchRow('系统代理', '关闭 TUN 时设置 HTTP 代理', s.systemProxy,
            (v) => _set(context, (x) => x.systemProxy = v, reload: true)),
        _SwitchRow('允许局域网', 'mixed 监听 0.0.0.0', s.allowLan,
            (v) => _set(context, (x) => x.allowLan = v, reload: true)),
        _SwitchRow('Mux', 'TCP 多路复用', s.mux,
            (v) => _set(context, (x) => x.mux = v, reload: true)),
      ],
    );
  }
}

class _DnsBlock extends StatelessWidget {
  const _DnsBlock();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _Section(
      title: 'DNS',
      children: [
        _SwitchRow('DNS 防泄漏', '境外域名走远端加密 DNS', s.dnsLeakProtection,
            (v) => _set(context, (x) => x.dnsLeakProtection = v, reload: true)),
        _DropdownRow(
          '远端 DNS',
          s.remoteDns,
          const [
            'https://1.1.1.1/dns-query',
            'https://8.8.8.8/dns-query',
            'https://dns.alidns.com/dns-query',
          ],
          const ['Cloudflare', 'Google', 'AliDNS'],
          (v) => _set(context, (x) => x.remoteDns = v ?? x.remoteDns, reload: true),
        ),
>>>>>>> 248d32e43e80f0618f3004e32a0fcccfc30514b3
      ],
    );
  }
}

<<<<<<< HEAD
class _DnsSection extends StatelessWidget {
  const _DnsSection();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _SectionCard(
      icon: Icons.dns_rounded,
      accent: const Color(0xFF06B6D4),
      title: 'DNS',
      children: [
        _switchRow(context, 'DNS 防泄漏', '强制所有 DNS 经过代理', s.dnsLeakProtection,
          (v) => s.set((s) => s.dnsLeakProtection = v)),
        _divider(),
        _dropdownRow(context, '远端 DNS', '加密 DNS 服务器',
          value: s.remoteDns,
          items: const ['https://1.1.1.1/dns-query', 'https://8.8.8.8/dns-query', 'https://dns.alidns.com/dns-query'],
          labels: const ['Cloudflare 1.1.1.1', 'Google 8.8.8.8', '阿里 DNS'],
          onChanged: (v) => s.set((s) => s.remoteDns = v ?? s.remoteDns),
        ),
      ],
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _SectionCard(
      icon: Icons.alt_route_rounded,
      accent: const Color(0xFF22C55E),
      title: '分流规则',
      children: [
        _dropdownRow(context, '路由模式', '代理流量过滤策略',
          value: s.routeMode.name,
          items: const ['rule', 'global', 'direct'],
          labels: const ['规则分流 (GeoSite)', '全局代理', '直连模式'],
          onChanged: (v) => s.set((s) => s.routeMode = RouteMode.values.firstWhere((e) => e.name == v)),
        ),
        _divider(),
        _actionRow(context, 'GeoIP 数据库', '最后更新：2025-12-01',
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在更新 GeoIP 数据库...')))),
=======
class _RouteBlock extends StatelessWidget {
  const _RouteBlock();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _Section(
      title: '分流',
      children: [
        _DropdownRow(
          '路由模式',
          s.routeMode.name,
          const ['rule', 'global', 'direct'],
          const ['规则分流', '全局代理', '直连'],
          (v) => _set(
            context,
            (x) => x.routeMode = RouteMode.values.firstWhere((e) => e.name == v),
            reload: true,
          ),
        ),
        _SwitchRow('广告拦截', 'geosite ads → block', s.blockAds,
            (v) => _set(context, (x) => x.blockAds = v, reload: true)),
        _SwitchRow('协议嗅探覆写', 'sniff_override_destination', s.sniffOverride,
            (v) => _set(context, (x) => x.sniffOverride = v, reload: true)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mixed 端口',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('本地混合入站', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              SizedBox(
                width: 88,
                child: TextFormField(
                  initialValue: '${s.mixedPort}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (v) {
                    final p = int.tryParse(v);
                    if (p != null && p > 0 && p < 65536) {
                      _set(context, (x) => x.mixedPort = p, reload: true);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
>>>>>>> 248d32e43e80f0618f3004e32a0fcccfc30514b3
      ],
    );
  }
}

<<<<<<< HEAD
class _AutoSection extends StatelessWidget {
  const _AutoSection();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _SectionCard(
      icon: Icons.auto_fix_high_rounded,
      accent: const Color(0xFFF59E0B),
      title: '自动化',
      children: [
        _switchRow(context, '自动修复配置', '导入时自动修正常见错误', s.autofix,
          (v) => s.set((s) => s.autofix = v)),
        _divider(),
        _switchRow(context, '连接后自动测试', '检测 Google / Cloudflare 可用性', s.postConnectTest,
          (v) => s.set((s) => s.postConnectTest = v)),
        _divider(),
        _switchRow(context, '核心崩溃自动重启', '检测到进程退出时自动恢复', s.crashAutoRestart,
          (v) => s.set((s) => s.crashAutoRestart = v)),
=======
class _AutoBlock extends StatelessWidget {
  const _AutoBlock();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _Section(
      title: '自动化',
      children: [
        _SwitchRow('自动重连', '断线后恢复', s.autoReconnect,
            (v) => context.read<SettingsProvider>().set((x) => x.autoReconnect = v)),
        _SwitchRow('崩溃重启', '核心退出后拉起', s.crashAutoRestart,
            (v) => context.read<SettingsProvider>().set((x) => x.crashAutoRestart = v)),
        _SwitchRow('导入自动修复', 'ALPN / SNI / alterId', s.autofix,
            (v) => context.read<SettingsProvider>().set((x) => x.autofix = v)),
        _SwitchRow('连接后探测', 'Cloudflare / Google', s.postConnectTest,
            (v) => context.read<SettingsProvider>().set((x) => x.postConnectTest = v)),
>>>>>>> 248d32e43e80f0618f3004e32a0fcccfc30514b3
      ],
    );
  }
}

<<<<<<< HEAD
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _SectionCard(
      icon: Icons.palette_rounded,
      accent: const Color(0xFFEC4899),
      title: '外观',
      children: [
        // Segmented theme picker fills the row width elegantly (no dead space)
        _ThemeSegments(
          value: s.themeMode,
          onChanged: (m) => s.set((s) => s.themeMode = m),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF22C55E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Nexus VPN',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: onSurface.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6)),
                child: Text('v1.0.0',
                  style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.6))),
              ),
            ]),
            const SizedBox(height: 3),
            Text('sing-box 1.9.3 内核 · Flutter 构建',
              style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.5))),
          ]),
        ),
        _iconChip(context, Icons.description_outlined, '文档'),
        const SizedBox(width: 8),
        _iconChip(context, Icons.code_rounded, 'GitHub'),
      ]),
=======
class _AppearanceBlock extends StatelessWidget {
  const _AppearanceBlock();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return _Section(
      title: '外观',
      children: [
        _DropdownRow(
          '主题',
          s.themeMode.name,
          const ['system', 'light', 'dark'],
          const ['跟随系统', '浅色', '深色'],
          (v) => context.read<SettingsProvider>().set(
                (x) => x.themeMode = ThemeMode.values.firstWhere((e) => e.name == v),
              ),
        ),
      ],
>>>>>>> 248d32e43e80f0618f3004e32a0fcccfc30514b3
    );
  }
}

<<<<<<< HEAD
// ── Reusable section card with icon header ──────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
        ]),
        const SizedBox(height: 6),
        ...children,
      ]),
    );
  }
}

// ── Segmented theme control ─────────────────────────────────────────────────────

class _ThemeSegments extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSegments({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    const labels = ['跟随系统', '浅色', '深色'];
    const icons = [Icons.brightness_auto_rounded, Icons.light_mode_rounded, Icons.dark_mode_rounded];
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: List.generate(modes.length, (i) {
          final selected = value == modes[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(modes[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEC4899).withOpacity(0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: selected ? const Color(0xFFEC4899).withOpacity(0.5) : Colors.transparent,
                  ),
                ),
                child: Column(children: [
                  Icon(icons[i], size: 16,
                    color: selected ? const Color(0xFFEC4899) : onSurface.withOpacity(0.5)),
                  const SizedBox(height: 4),
                  Text(labels[i], style: TextStyle(fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? onSurface : onSurface.withOpacity(0.55))),
                ]),
              ),
            ),
          );
        })),
      ),
    );
  }
}

// ── Row helpers ─────────────────────────────────────────────────────────────────

Widget _divider() => Divider(height: 1, color: Colors.white.withOpacity(0.06));

Widget _switchRow(BuildContext ctx, String name, String desc, bool value, ValueChanged<bool> onChanged) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF22C55E)),
    ]),
  );

Widget _dropdownRow(BuildContext ctx, String name, String desc,
    {required String value, required List<String> items, required List<String> labels,
     required ValueChanged<String?> onChanged}) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface),
          items: items.asMap().entries.map((e) =>
            DropdownMenuItem(value: e.value, child: Text(labels[e.key]))).toList(),
          onChanged: onChanged,
        ),
=======
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return NexusSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          ...children,
        ],
>>>>>>> 248d32e43e80f0618f3004e32a0fcccfc30514b3
      ),
    );
  }
}

<<<<<<< HEAD
Widget _actionRow(BuildContext ctx, String name, String desc, VoidCallback onTap) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
      ])),
      OutlinedButton(onPressed: onTap, child: const Text('更新', style: TextStyle(fontSize: 12))),
    ]),
  );

Widget _iconChip(BuildContext ctx, IconData icon, String label) {
  final onSurface = Theme.of(ctx).colorScheme.onSurface;
  return OutlinedButton.icon(
    onPressed: () {},
    icon: Icon(icon, size: 15),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: onSurface.withOpacity(0.75),
      side: BorderSide(color: onSurface.withOpacity(0.15)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
=======
class _SwitchRow extends StatelessWidget {
  final String name, desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(this.name, this.desc, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String name;
  final String value;
  final List<String> items;
  final List<String> labels;
  final ValueChanged<String?> onChanged;
  const _DropdownRow(this.name, this.value, this.items, this.labels, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            items: [
              for (var i = 0; i < items.length; i++)
                DropdownMenuItem(value: items[i], child: Text(labels[i])),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
>>>>>>> 248d32e43e80f0618f3004e32a0fcccfc30514b3
}
