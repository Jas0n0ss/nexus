import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/vpn_provider.dart';
import '../providers/nodes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shell_nav.dart';
import '../widgets/glass_card.dart';
import '../widgets/connect_button.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(),
              const SizedBox(height: 16),
              _RouteModeBar(),
              const SizedBox(height: 16),
              _ConnectionCard(),
              const SizedBox(height: 16),
              _StatsRow(),
              const SizedBox(height: 16),
              _SpeedChart(),
              const SizedBox(height: 16),
              _QuickNodes(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('仪表盘', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 2),
              Text('连接状态 · 分流模式 · 流量监控',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => context.read<ShellNav>().openImport(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('导入配置'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _RouteModeBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final vpn = context.watch<VpnProvider>();
    final modes = [
      (RouteMode.rule, '规则分流', '国内直连，其余代理'),
      (RouteMode.global, '全局代理', '全部走代理'),
      (RouteMode.direct, '直连', '全部直连'),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '代理模式（类似 Passwall）',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: modes.map((m) {
              final active = settings.routeMode == m.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      if (settings.routeMode == m.$1) return;
                      settings.set((s) => s.routeMode = m.$1);
                      if (vpn.isConnected) {
                        await vpn.applySettingsAndReconnect();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF3B82F6).withOpacity(0.15)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF3B82F6)
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.$2,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? const Color(0xFF3B82F6)
                                    : Theme.of(context).colorScheme.onSurface,
                              )),
                          const SizedBox(height: 2),
                          Text(m.$3,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final nodes = context.watch<NodesProvider>();
    final settings = context.watch<SettingsProvider>();
    final node = nodes.selected;
    final isConnected = vpn.isConnected;
    final cs = Theme.of(context).colorScheme;

    return GlassCard(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.12),
          const Color(0xFF6366F1).withOpacity(0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: const Color(0xFF6366F1).withOpacity(0.25),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: vpn.state == VpnState.error
                          ? const Color(0xFFEF4444)
                          : isConnected
                              ? const Color(0xFF22C55E)
                              : Colors.grey.shade600,
                      boxShadow: isConnected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF22C55E).withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vpn.state == VpnState.connecting
                        ? '连接中...'
                        : vpn.state == VpnState.disconnecting
                            ? '断开中...'
                            : vpn.state == VpnState.error
                                ? '连接失败'
                                : isConnected
                                    ? '已连接'
                                    : '未连接',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'TUN ${settings.tunMode ? "开" : "关"} · ${settings.routeMode.name}',
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.35)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  isConnected
                      ? (vpn.externalIp ?? '获取出口 IP...')
                      : (nodes.isEmpty ? '请先导入节点' : '–'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                if (vpn.state == VpnState.error && vpn.lastError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    vpn.lastError!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                  ),
                ],
                const SizedBox(height: 4),
                if (node != null)
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: '通过 '),
                      TextSpan(
                        text: '${node.flag} ${node.name}',
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: ' · ${node.protocolLabel}'),
                    ]),
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.55)),
                  )
                else
                  TextButton(
                    onPressed: () => context.read<ShellNav>().openImport(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: const Color(0xFF3B82F6),
                    ),
                    child: const Text('导入配置以开始使用 →'),
                  ),
                const SizedBox(height: 12),
                Text('连接时长',
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.35))),
                const SizedBox(height: 2),
                _UptimeText(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          ConnectButton(
            state: vpn.state,
            onToggle: () => vpn.toggle(nodes.selected),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }
}

class _UptimeText extends StatefulWidget {
  @override
  State<_UptimeText> createState() => _UptimeTextState();
}

class _UptimeTextState extends State<_UptimeText> {
  late final Stream<Duration> _stream;
  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(seconds: 1), (_) {
      return context.read<VpnProvider>().uptime;
    });
  }

  String _fmt(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:'
      '${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    if (!vpn.isConnected) {
      return const Text('–', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
    }
    return StreamBuilder<Duration>(
      stream: _stream,
      initialData: vpn.uptime,
      builder: (_, snap) => Text(
        _fmt(snap.data ?? Duration.zero),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final items = [
      ('上传', vpn.uploadMbps.toStringAsFixed(1), 'Mbps', const Color(0xFF22C55E)),
      ('下载', vpn.downloadMbps.toStringAsFixed(1), 'Mbps', const Color(0xFF3B82F6)),
      (
        '延迟',
        vpn.latencyMs.toString(),
        'ms',
        vpn.latencyMs == 0
            ? const Color(0xFF6B7280)
            : vpn.latencyMs < 80
                ? const Color(0xFF22C55E)
                : vpn.latencyMs < 200
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444)
      ),
      ('今日', vpn.totalGbToday.toStringAsFixed(2), 'GB', const Color(0xFF6366F1)),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _StatCard(items[i].$1, items[i].$2, items[i].$3, items[i].$4)),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _StatCard(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ]),
    );
  }
}

class _SpeedChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final cs = Theme.of(context).colorScheme;

    List<FlSpot> spots(List<double> data) =>
        data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('实时速率曲线', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            _legendDot(const Color(0xFF22C55E), '上传'),
            const SizedBox(width: 16),
            _legendDot(const Color(0xFF3B82F6), '下载'),
          ]),
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
                    color: cs.onSurface.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.35)),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  _line(spots(vpn.uploadHistory), const Color(0xFF22C55E)),
                  _line(spots(vpn.downloadHistory), const Color(0xFF3B82F6)),
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

  Widget _legendDot(Color c, String label) => Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}

class _QuickNodes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    final vpn = context.watch<VpnProvider>();

    if (nodes.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('快速切换', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '导入节点后可在此快速切换',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.read<ShellNav>().openImport(),
            child: const Text('导入'),
          ),
        ]),
      );
    }

    final top = [...nodes.all]
      ..sort((a, b) => (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999));
    final shown = top.take(5).toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('快速切换', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () => context.read<ShellNav>().openNodes(),
              child: const Text('全部节点', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final n = shown[i];
                final isActive = nodes.selected?.id == n.id;
                return GestureDetector(
                  onTap: () async {
                    nodes.select(n);
                    if (vpn.isConnected) await vpn.connect(n);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 110,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF3B82F6).withOpacity(0.15)
                          : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.05),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF3B82F6).withOpacity(0.5)
                            : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.flag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(
                          n.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
