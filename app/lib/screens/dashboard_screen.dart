import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/vpn_provider.dart';
import '../providers/nodes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shell_nav.dart';
import '../theme/nexus_theme.dart';
import '../widgets/connect_button.dart';
import '../widgets/nexus_surface.dart';
import '../widgets/page_header.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
              PageHeader(
                title: 'NEXUS',
                subtitle: '代理连接 · 分流 · 流量',
                actions: [
                  FilledButton.icon(
                    onPressed: () => context.read<ShellNav>().openImport(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加节点'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _HeroConnect()
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: 0.04, end: 0),
              const SizedBox(height: 20),
              const _RouteModes()
                  .animate(delay: 80.ms)
                  .fadeIn(duration: 280.ms),
              const SizedBox(height: 20),
              const _StatsRow(),
              const SizedBox(height: 20),
              const _SpeedChart(),
              const SizedBox(height: 20),
              const _QuickNodes(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroConnect extends StatelessWidget {
  const _HeroConnect();

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final nodes = context.watch<NodesProvider>();
    final settings = context.watch<SettingsProvider>();
    final node = nodes.selected;
    final connected = vpn.isConnected;

    return NexusSurface(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          NexusColors.accent.withOpacity(0.14),
          NexusColors.surface.withOpacity(0.9),
          NexusColors.accentDeep.withOpacity(0.10),
        ],
      ),
      borderColor: NexusColors.accent.withOpacity(0.28),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONNECTION', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: vpn.state == VpnState.error
                            ? NexusColors.danger
                            : connected
                                ? NexusColors.ok
                                : NexusColors.textFaint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      vpn.state == VpnState.connecting
                          ? '连接中'
                          : vpn.state == VpnState.disconnecting
                              ? '断开中'
                              : vpn.state == VpnState.error
                                  ? '失败'
                                  : connected
                                      ? '已连接'
                                      : '未连接',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  connected
                      ? (vpn.externalIp ?? '获取出口…')
                      : (nodes.isEmpty ? '先导入节点' : '准备就绪'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 34),
                ),
                const SizedBox(height: 8),
                Text(
                  node == null
                      ? '无选中节点'
                      : '${node.flag} ${node.name}  ·  ${node.protocolLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'TUN ${settings.tunMode ? "开" : "关"}  ·  ${settings.routeMode.name}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (vpn.state == VpnState.error && vpn.lastError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    vpn.lastError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NexusColors.danger, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          ConnectButton(
            state: vpn.state,
            onToggle: () => vpn.toggle(nodes.selected),
          ),
        ],
      ),
    );
  }
}

class _RouteModes extends StatelessWidget {
  const _RouteModes();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final vpn = context.watch<VpnProvider>();
    final modes = [
      (RouteMode.rule, '规则', '国内直连'),
      (RouteMode.global, '全局', '全部代理'),
      (RouteMode.direct, '直连', '不走代理'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('代理模式', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final m in modes)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: NexusSurface(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    borderColor: settings.routeMode == m.$1
                        ? NexusColors.accent.withOpacity(0.55)
                        : null,
                    onTap: () async {
                      if (settings.routeMode == m.$1) return;
                      settings.set((s) => s.routeMode = m.$1);
                      if (vpn.isConnected) await vpn.applySettingsAndReconnect();
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.$2,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: settings.routeMode == m.$1
                                ? NexusColors.accent
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(m.$3, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final items = [
      ('上传', '${vpn.uploadMbps.toStringAsFixed(1)}', 'Mbps'),
      ('下载', '${vpn.downloadMbps.toStringAsFixed(1)}', 'Mbps'),
      ('延迟', '${vpn.latencyMs}', 'ms'),
      ('今日', vpn.totalGbToday.toStringAsFixed(2), 'GB'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: NexusSurface(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                children: [
                  Text(items[i].$1, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Text(
                    items[i].$2,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: NexusColors.accent,
                    ),
                  ),
                  Text(items[i].$3, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SpeedChart extends StatelessWidget {
  const _SpeedChart();

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    List<FlSpot> spots(List<double> data) =>
        data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return NexusSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('速率', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              _dot(NexusColors.ok, '上传'),
              const SizedBox(width: 14),
              _dot(NexusColors.accent, '下载'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: NexusColors.line,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  _line(spots(vpn.uploadHistory), NexusColors.ok),
                  _line(spots(vpn.downloadHistory), NexusColors.accent),
                ],
              ),
              duration: const Duration(milliseconds: 150),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2,
        isCurved: true,
        curveSmoothness: 0.35,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: color.withOpacity(0.08)),
      );

  Widget _dot(Color c, String label) => Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _QuickNodes extends StatelessWidget {
  const _QuickNodes();

  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    final vpn = context.watch<VpnProvider>();

    if (nodes.isEmpty) {
      return NexusSurface(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('快速切换', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('导入节点后在此切换', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => context.read<ShellNav>().openImport(),
              child: const Text('添加节点'),
            ),
          ],
        ),
      );
    }

    final top = [...nodes.all]
      ..sort((a, b) => (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999));
    final shown = top.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('快速切换', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => context.read<ShellNav>().openNodes(),
              child: const Text('全部'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final n = shown[i];
              final active = nodes.selected?.id == n.id;
              return NexusSurface(
                padding: const EdgeInsets.all(12),
                borderColor:
                    active ? NexusColors.accent.withOpacity(0.5) : null,
                onTap: () async {
                  nodes.select(n);
                  if (vpn.isConnected) await vpn.connect(n);
                },
                child: SizedBox(
                  width: 108,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(
                        n.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.latencyLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: n.latencyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
