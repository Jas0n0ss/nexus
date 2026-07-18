import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/vpn_provider.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('设置', style: Theme.of(context).textTheme.displayLarge),
              Text(
                '路由 / TUN / DNS / 系统代理 — 变更后已连接时将自动重载',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (ctx, c) {
                if (c.maxWidth > 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(children: [
                          _CoreSection(),
                          const SizedBox(height: 16),
                          _DnsSection(),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(children: [
                          _RouteSection(),
                          const SizedBox(height: 16),
                          _PasswallSection(),
                          const SizedBox(height: 16),
                          _AutoSection(),
                        ]),
                      ),
                    ],
                  );
                }
                return Column(children: [
                  _CoreSection(),
                  const SizedBox(height: 16),
                  _DnsSection(),
                  const SizedBox(height: 16),
                  _RouteSection(),
                  const SizedBox(height: 16),
                  _PasswallSection(),
                  const SizedBox(height: 16),
                  _AutoSection(),
                ]);
              }),
              const SizedBox(height: 16),
              _AppearanceSection(),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _setAndMaybeReload(
  BuildContext context,
  void Function(SettingsProvider s) fn, {
  bool reload = false,
}) async {
  final s = context.read<SettingsProvider>();
  s.set(fn);
  if (reload && context.read<VpnProvider>().isConnected) {
    await context.read<VpnProvider>().applySettingsAndReconnect();
  }
}

class _CoreSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(context, '核心引擎'),
        _dropdownRow(
          context,
          '代理核心',
          '当前仅 sing-box 已接通运行时',
          value: s.coreEngine.name,
          items: const ['singbox'],
          labels: const ['sing-box 1.9.x'],
          onChanged: (v) => _setAndMaybeReload(
            context,
            (s) => s.coreEngine = CoreEngine.values.firstWhere((e) => e.name == v),
          ),
        ),
        _divider(),
        _switchRow(
          context,
          'TUN 模式',
          '系统级透明代理（需管理员 / VPN 权限）',
          s.tunMode,
          (v) => _setAndMaybeReload(context, (s) => s.tunMode = v, reload: true),
        ),
        _divider(),
        _switchRow(
          context,
          '系统代理',
          '关闭 TUN 时自动设置 HTTP/HTTPS 代理到 mixed 端口',
          s.systemProxy,
          (v) => _setAndMaybeReload(context, (s) => s.systemProxy = v, reload: true),
        ),
        _divider(),
        _switchRow(
          context,
          '允许局域网',
          'mixed 入站监听 0.0.0.0，供其他设备使用',
          s.allowLan,
          (v) => _setAndMaybeReload(context, (s) => s.allowLan = v, reload: true),
        ),
        _divider(),
        _switchRow(
          context,
          'Mux 多路复用',
          '减少 TCP 握手（QUIC 协议自动跳过）',
          s.mux,
          (v) => _setAndMaybeReload(context, (s) => s.mux = v, reload: true),
        ),
      ]),
    );
  }
}

class _DnsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(context, 'DNS'),
        _switchRow(
          context,
          'DNS 防泄漏',
          '境外域名走远端加密 DNS',
          s.dnsLeakProtection,
          (v) => _setAndMaybeReload(context, (s) => s.dnsLeakProtection = v, reload: true),
        ),
        _divider(),
        _dropdownRow(
          context,
          '远端 DNS',
          '加密 DNS 服务器',
          value: s.remoteDns,
          items: const [
            'https://1.1.1.1/dns-query',
            'https://8.8.8.8/dns-query',
            'https://dns.alidns.com/dns-query',
          ],
          labels: const ['Cloudflare 1.1.1.1', 'Google 8.8.8.8', '阿里 DNS'],
          onChanged: (v) => _setAndMaybeReload(
            context,
            (s) => s.remoteDns = v ?? s.remoteDns,
            reload: true,
          ),
        ),
      ]),
    );
  }
}

class _RouteSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(context, '分流规则'),
        _dropdownRow(
          context,
          '路由模式',
          '规则 / 全局 / 直连',
          value: s.routeMode.name,
          items: const ['rule', 'global', 'direct'],
          labels: const ['规则分流 (GeoSite)', '全局代理', '直连模式'],
          onChanged: (v) => _setAndMaybeReload(
            context,
            (s) => s.routeMode = RouteMode.values.firstWhere((e) => e.name == v),
            reload: true,
          ),
        ),
        _divider(),
        _switchRow(
          context,
          '广告拦截',
          'geosite-category-ads-all → block',
          s.blockAds,
          (v) => _setAndMaybeReload(context, (s) => s.blockAds = v, reload: true),
        ),
        _divider(),
        _switchRow(
          context,
          '协议嗅探覆写',
          'sniff_override_destination',
          s.sniffOverride,
          (v) => _setAndMaybeReload(context, (s) => s.sniffOverride = v, reload: true),
        ),
      ]),
    );
  }
}

class _PasswallSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(context, '进阶（Passwall 风格）'),
        _switchRow(
          context,
          '自动重连',
          '断线或核心退出后自动恢复',
          s.autoReconnect,
          (v) => context.read<SettingsProvider>().set((s) => s.autoReconnect = v),
        ),
        _divider(),
        _switchRow(
          context,
          '核心崩溃自动重启',
          '检测到进程退出时重新拉起',
          s.crashAutoRestart,
          (v) => context.read<SettingsProvider>().set((s) => s.crashAutoRestart = v),
        ),
        _divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mixed 端口', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '本地 HTTP/SOCKS 混合入站',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ]),
            ),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: '${s.mixedPort}',
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final port = int.tryParse(v);
                  if (port != null && port > 0 && port < 65536) {
                    _setAndMaybeReload(context, (s) => s.mixedPort = port, reload: true);
                  }
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _AutoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(context, '自动化'),
        _switchRow(
          context,
          '自动修复配置',
          '导入时修正常见错误（ALPN / SNI / alterId…）',
          s.autofix,
          (v) => context.read<SettingsProvider>().set((s) => s.autofix = v),
        ),
        _divider(),
        _switchRow(
          context,
          '连接后自动测试',
          '经代理探测 Cloudflare / Google',
          s.postConnectTest,
          (v) => context.read<SettingsProvider>().set((s) => s.postConnectTest = v),
        ),
      ]),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(context, '外观'),
        _dropdownRow(
          context,
          '主题',
          '深色 / 浅色 / 跟随系统',
          value: s.themeMode.name,
          items: const ['system', 'light', 'dark'],
          labels: const ['跟随系统', '浅色模式', '深色模式'],
          onChanged: (v) => context.read<SettingsProvider>().set(
                (s) => s.themeMode = ThemeMode.values.firstWhere((e) => e.name == v),
              ),
        ),
      ]),
    );
  }
}

Widget _sectionTitle(BuildContext ctx, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4),
        ),
      ),
    );

Widget _divider() => Divider(height: 1, color: Colors.white.withOpacity(0.06));

Widget _switchRow(
  BuildContext ctx,
  String name,
  String desc,
  bool value,
  ValueChanged<bool> onChanged,
) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ]),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF22C55E)),
      ]),
    );

Widget _dropdownRow(
  BuildContext ctx,
  String name,
  String desc, {
  required String value,
  required List<String> items,
  required List<String> labels,
  required ValueChanged<String?> onChanged,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ]),
        ),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface),
          items: items
              .asMap()
              .entries
              .map((e) => DropdownMenuItem(value: e.value, child: Text(labels[e.key])))
              .toList(),
          onChanged: onChanged,
        ),
      ]),
    );
