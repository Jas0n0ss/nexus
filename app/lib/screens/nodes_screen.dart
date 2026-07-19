import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/nodes_provider.dart';
import '../providers/session_provider.dart';
import '../providers/shell_nav.dart';
import '../models/proxy_node.dart';
import '../theme/nexus_theme.dart';
import '../widgets/nexus_surface.dart';
import '../widgets/page_header.dart';

class NodesScreen extends StatelessWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          child: Column(
            children: [
              Consumer<NodesProvider>(
                builder: (ctx, nodes, __) => PageHeader(
                  title: '节点',
                  subtitle: nodes.isEmpty
                      ? '尚未导入'
                      : '${nodes.all.length} 个节点 · ${nodes.groups.length - 1} 组',
                  actions: [
                    if (!nodes.isEmpty)
                      OutlinedButton.icon(
                        onPressed: nodes.testAll,
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text('测速'),
                      ),
                    FilledButton.icon(
                      onPressed: () => ctx.read<ShellNav>().openImport(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('添加节点'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: context.read<NodesProvider>().setSearch,
                decoration: const InputDecoration(
                  hintText: '搜索名称 / 协议 / 地区',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              const _GroupBar(),
              const SizedBox(height: 12),
              const Expanded(child: _List()),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupBar extends StatelessWidget {
  const _GroupBar();

  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    if (nodes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: nodes.groups.map((g) {
          final active = nodes.filterGroup == g;
          final count = g == '全部'
              ? nodes.all.length
              : nodes.all.where((n) => n.group == g).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$g $count'),
              selected: active,
              onSelected: (_) => nodes.setFilterGroup(g),
              selectedColor: NexusColors.accent.withOpacity(0.22),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? NexusColors.accent
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              ),
              side: BorderSide(
                color: active
                    ? NexusColors.accent.withOpacity(0.45)
                    : NexusColors.line,
              ),
              backgroundColor: active
                  ? NexusColors.surfaceLift
                  : Theme.of(context).scaffoldBackgroundColor,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List();

  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    if (nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined,
                size: 44, color: NexusColors.textFaint),
            const SizedBox(height: 12),
            Text('还没有节点', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('从订阅或配置文件导入', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<ShellNav>().openImport(),
              child: const Text('添加节点'),
            ),
          ],
        ),
      );
    }
    final list = nodes.filtered;
    if (list.isEmpty) {
      return const Center(child: Text('没有匹配的节点'));
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _NodeRow(node: list[i])
          .animate(delay: Duration(milliseconds: i * 24))
          .fadeIn(duration: 200.ms)
          .slideY(begin: 0.04, end: 0),
    );
  }
}

class _NodeRow extends StatelessWidget {
  final ProxyNode node;
  const _NodeRow({required this.node});

  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    final proxy = context.watch<SessionProvider>();
    final selected = nodes.selected?.id == node.id;
    final active = proxy.activeNode?.id == node.id && proxy.isConnected;

    return NexusSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: active
          ? NexusColors.ok.withOpacity(0.5)
          : selected
              ? NexusColors.accent.withOpacity(0.45)
              : null,
      onTap: () async {
        nodes.select(node);
        if (proxy.isConnected) await proxy.connect(node);
      },
      child: Row(
        children: [
          Text(node.flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (active)
                      const Text(
                        '使用中',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: NexusColors.ok,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${node.protocolLabel}  ·  ${node.server}:${node.port}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            node.isReachable == false ? '超时' : node.latencyLabel,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: node.isReachable == false
                  ? NexusColors.danger
                  : node.latencyColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bolt_rounded, size: 18),
            color: NexusColors.textDim,
            onPressed: () => nodes.testLatency(node.id),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: NexusColors.textDim,
            onPressed: () => _confirmDelete(context, node),
          ),
        ],
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
            onPressed: () {
              ctx.read<NodesProvider>().remove(node.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: NexusColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
