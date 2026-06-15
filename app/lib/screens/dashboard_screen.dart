import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/vpn_provider.dart';
import '../providers/nodes_provider.dart';
import '../models/proxy_node.dart';
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
              const SizedBox(height: 20),
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
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('仪表盘', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 2),
            Text('实时连接状态与流量监控',
              style: Theme.of(context).textTheme.bodySmall),
          ],
        )),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加节点'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final nodes = context.watch<NodesProvider>();
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
                // Status
                Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 9, height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? const Color(0xFF22C55E) : Colors.grey.shade600,
                      boxShadow: isConnected ? [
                        BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.5), blurRadius: 8),
                      ] : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vpn.state == VpnState.connecting ? '连接中...'
                      : vpn.state == VpnState.disconnecting ? '断开中...'
                      : isConnected ? '已连接' : '未连接',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                // IP
                Text(
                  isConnected ? (vpn.externalIp ?? '获取中...') : '–',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                // Node + protocol
                if (node != null) Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '通过 '),
                    TextSpan(
                      text: '${node.flag} ${node.name}',
                      style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' · ${node.protocolLabel}'),
                  ]),
                  style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.55)),
                ),
                const SizedBox(height: 12),
                // Uptime
                Text('连接时长', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.35))),
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
  @override State<_UptimeText> createState() => _UptimeTextState();
}
class _UptimeTextState extends State<_UptimeText> {
  late final Stream<Duration> _stream;
  @override void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(seconds: 1), (_) {
      return context.read<VpnProvider>().uptime;
    });
  }
  String _fmt(Duration d) =>
    '${d.inHours.toString().padLeft(2,'0')}:'
    '${(d.inMinutes % 60).toString().padLeft(2,'0')}:'
    '${(d.inSeconds % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    if (!vpn.isConnected) return const Text('–', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
    return StreamBuilder<Duration>(
      stream: _stream,
      initialData: vpn.uptime,
      builder: (_, snap) => Text(_fmt(snap.data ?? Duration.zero),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    return Row(children: [
      _StatCard('↑ 上传', vpn.uploadMbps.toStringAsFixed(1), 'MB/s', const Color(0xFF22C55E)),
      const SizedBox(width: 12),
      _StatCard('↓ 下载', vpn.downloadMbps.toStringAsFixed(1), 'MB/s', const Color(0xFF3B82F6)),
      const SizedBox(width: 12),
      _StatCard('📶 延迟', vpn.latencyMs.toString(), 'ms',
        vpn.latencyMs < 80 ? const Color(0xFF22C55E)
          : vpn.latencyMs < 200 ? const Color(0xFFF59E0B)
          : const Color(0xFFEF4444)),
      const SizedBox(width: 12),
      _StatCard('📦 今日', vpn.totalGbToday.toStringAsFixed(2), 'GB', const Color(0xFF6366F1)),
    ].map((w) => Expanded(child: w)).toList().cast<Widget>().expand((e) => [e]).toList()
    // clean up: just wrap the 4 cards
    );
  }
}

// Simple helper to build the row cleanly
class _StatsRowFix extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final items = [
      ('↑ 上传', vpn.uploadMbps.toStringAsFixed(1), 'MB/s', const Color(0xFF22C55E)),
      ('↓ 下载', vpn.downloadMbps.toStringAsFixed(1), 'MB/s', const Color(0xFF3B82F6)),
      ('📶 延迟', vpn.latencyMs.toString(), 'ms', const Color(0xFF22C55E)),
      ('📦 今日', vpn.totalGbToday.toStringAsFixed(2), 'GB', const Color(0xFF6366F1)),
    ];
    return Row(
      children: items.map((t) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _StatCard(t.$1, t.$2, t.$3, t.$4),
        ),
      )).toList(),
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
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(unit, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
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
                    color: cs.onSurface.withOpacity(0.05), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 36,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(
                      fontSize: 9, color: cs.onSurface.withOpacity(0.35))),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(
      show: true,
      color: color.withOpacity(0.08),
    ),
  );

  Widget _legendDot(Color c, String label) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12)),
  ]);
}

class _QuickNodes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    final vpn = context.watch<VpnProvider>();
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
            TextButton(onPressed: () {}, child: const Text('全部节点', style: TextStyle(fontSize: 12))),
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
                  onTap: () {
                    nodes.select(n);
                    if (vpn.isConnected) vpn.connect(n);
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
                        color: isActive ? const Color(0xFF3B82F6).withOpacity(0.5) : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.flag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(n.name.split(' ').last, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(n.latencyLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: n.latencyColor)),
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
