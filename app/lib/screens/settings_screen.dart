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
          ),
        ),
      ),
    );
  }
}

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
      ],
    );
  }
}

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
      ],
    );
  }
}

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
      ],
    );
  }
}

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
    );
  }
}

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
      ),
    );
  }
}

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
}
