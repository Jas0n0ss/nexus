import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
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
              const SizedBox(height: 24),
              // Two-column on desktop
              LayoutBuilder(builder: (ctx, c) {
                if (c.maxWidth > 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: [_CoreSection(), const SizedBox(height: 16), _DnsSection()])),
                      const SizedBox(width: 16),
                      Expanded(child: Column(children: [_RouteSection(), const SizedBox(height: 16), _AutoSection()])),
                    ],
                  );
                }
                return Column(children: [_CoreSection(), const SizedBox(height: 16), _DnsSection(),
                  const SizedBox(height: 16), _RouteSection(), const SizedBox(height: 16), _AutoSection()]);
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

class _CoreSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(context, '核心引擎'),
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
        _switchRow(context, 'DNS 防泄漏', '强制所有 DNS 经过代理', s.dnsLeakProtection,
          (v) => s.set((s) => s.dnsLeakProtection = v)),
        _divider(),
        _dropdownRow(context, '远端 DNS', '加密 DNS 服务器',
          value: s.remoteDns,
          items: const ['https://1.1.1.1/dns-query', 'https://8.8.8.8/dns-query', 'https://dns.alidns.com/dns-query'],
          labels: const ['Cloudflare 1.1.1.1', 'Google 8.8.8.8', '阿里 DNS'],
          onChanged: (v) => s.set((s) => s.remoteDns = v ?? s.remoteDns),
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
        _switchRow(context, '自动修复配置', '导入时自动修正常见错误', s.autofix,
          (v) => s.set((s) => s.autofix = v)),
        _divider(),
        _switchRow(context, '连接后自动测试', '检测 Google / Cloudflare 可用性', s.postConnectTest,
          (v) => s.set((s) => s.postConnectTest = v)),
        _divider(),
        _switchRow(context, '核心崩溃自动重启', '检测到进程退出时自动恢复', s.crashAutoRestart,
          (v) => s.set((s) => s.crashAutoRestart = v)),
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
        _dropdownRow(context, '主题', '深色 / 浅色 / 跟随系统',
          value: s.themeMode.name,
          items: const ['system', 'light', 'dark'],
          labels: const ['跟随系统', '浅色模式', '深色模式'],
          onChanged: (v) => s.set((s) => s.themeMode = ThemeMode.values.firstWhere((e) => e.name == v)),
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _sectionTitle(BuildContext ctx, String t) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
    letterSpacing: 0.6, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4))),
);

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
      DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface),
        items: items.asMap().entries.map((e) =>
          DropdownMenuItem(value: e.value, child: Text(labels[e.key]))).toList(),
        onChanged: onChanged,
      ),
    ]),
  );

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
