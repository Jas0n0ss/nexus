import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/nodes_provider.dart';
import '../providers/vpn_provider.dart';
import '../models/proxy_node.dart';
import '../widgets/glass_card.dart';

class NodesScreen extends StatelessWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _Header(),
              const SizedBox(height: 16),
              _SearchBar(),
              const SizedBox(height: 12),
              _GroupChips(),
              const SizedBox(height: 12),
              const Expanded(child: _NodeList()),
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
    final nodes = context.watch<NodesProvider>();
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('节点列表', style: Theme.of(context).textTheme.displayLarge),
        Text('共 ${nodes.all.length} 个节点 · ${nodes.groups.length - 1} 个分组',
          style: Theme.of(context).textTheme.bodySmall),
      ])),
      OutlinedButton.icon(
        onPressed: () => nodes.testAll(),
        icon: const Icon(Icons.bolt_rounded, size: 16),
        label: const Text('全部测速'),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, size: 16),
        label: const Text('导入'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
      ),
    ]);
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nodes = context.read<NodesProvider>();
    return TextField(
      onChanged: nodes.setSearch,
      decoration: InputDecoration(
        hintText: '搜索节点名称、地区或协议...',
        prefixIcon: Icon(Icons.search_rounded, size: 18,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
      ),
    );
  }
}

class _GroupChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: nodes.groups.map((g) {
          final active = nodes.filterGroup == g;
          final count = g == '全部' ? nodes.all.length : nodes.all.where((n) => n.group == g).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$g  $count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              selected: active,
              onSelected: (_) => nodes.setFilterGroup(g),
              backgroundColor: Colors.transparent,
              selectedColor: const Color(0xFF3B82F6),
              side: BorderSide(color: active ? const Color(0xFF3B82F6) : Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NodeList extends StatelessWidget {
  const _NodeList();

  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    final list = nodes.filtered;
    if (list.isEmpty) return const Center(child: Text('没有匹配的节点'));
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) =>
        _NodeCard(node: list[i]).animate(delay: Duration(milliseconds: i * 30))
          .fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final ProxyNode node;
  const _NodeCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    final vpn = context.watch<VpnProvider>();
    final isSelected = nodes.selected?.id == node.id;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        nodes.select(node);
        if (vpn.isConnected) vpn.connect(node);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.1)
              : cs.surface.withOpacity(0.6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6).withOpacity(0.45)
                : cs.onSurface.withOpacity(0.08),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Text(node.flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                _ProtoBadge(node.protocolLabel),
                const SizedBox(width: 8),
                Text('${node.server}:${node.port}',
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
                const SizedBox(width: 8),
                Text(node.sourceLabel,
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.3))),
              ]),
            ],
          )),
          const SizedBox(width: 12),
          // Speed
          if (node.downloadMbps != null)
            Text('↓${node.downloadMbps!.toStringAsFixed(0)}M',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
          const SizedBox(width: 12),
          // Latency
          Text(node.latencyLabel,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: node.latencyColor)),
          const SizedBox(width: 8),
          // Actions
          IconButton(
            icon: const Icon(Icons.bolt_rounded, size: 18),
            color: cs.onSurface.withOpacity(0.4),
            onPressed: () => context.read<NodesProvider>().testLatency(node.id),
            tooltip: '测速',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: cs.onSurface.withOpacity(0.4),
            onPressed: () => _confirmDelete(context, node),
            tooltip: '删除',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, ProxyNode node) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('删除节点'),
        content: Text('确定删除 ${node.name}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { ctx.read<NodesProvider>().remove(node.id); Navigator.pop(ctx); },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _ProtoBadge extends StatelessWidget {
  final String label;
  const _ProtoBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF6366F1).withOpacity(0.18),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
      color: Color(0xFFA5B4FC))),
  );
}
