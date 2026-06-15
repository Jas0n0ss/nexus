import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/logs_provider.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _filter = 'ALL';
  bool _autoScroll = true;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<LogsProvider>();
    final filtered = logs.filtered(_filter);

    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('运行日志', style: Theme.of(context).textTheme.displayLarge),
                  Text('sing-box 内核实时输出', style: Theme.of(context).textTheme.bodySmall),
                ])),
                OutlinedButton.icon(
                  onPressed: logs.clear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('清空'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {/* export */},
                  icon: const Icon(Icons.save_alt_rounded, size: 16),
                  label: const Text('导出'),
                ),
              ]),
              const SizedBox(height: 16),
              // Toolbar
              Row(children: [
                _FilterChip('ALL',   _filter, () => setState(() => _filter = 'ALL')),
                const SizedBox(width: 6),
                _FilterChip('INFO',  _filter, () => setState(() => _filter = 'INFO')),
                const SizedBox(width: 6),
                _FilterChip('WARN',  _filter, () => setState(() => _filter = 'WARN')),
                const SizedBox(width: 6),
                _FilterChip('ERROR', _filter, () => setState(() => _filter = 'ERROR')),
                const Spacer(),
                Row(children: [
                  Switch(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Text('自动滚动', style: TextStyle(fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
                ]),
              ]),
              const SizedBox(height: 12),
              // Log area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: filtered.isEmpty
                    ? const Center(child: Text('暂无日志', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _LogLine(filtered[i]),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String level, current;
  final VoidCallback onTap;
  const _FilterChip(this.level, this.current, this.onTap);
  @override
  Widget build(BuildContext ctx) {
    final active = level == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Theme.of(ctx).colorScheme.onSurface.withOpacity(0.12) : Colors.transparent,
          border: Border.all(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(active ? 0.2 : 0.08)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(level, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: active ? Theme.of(ctx).colorScheme.onSurface : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4))),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final LogEntry entry;
  const _LogLine(this.entry);

  Color _levelColor(String level) {
    switch (level) {
      case 'OK':    return const Color(0xFF22C55E);
      case 'WARN':  return const Color(0xFFF59E0B);
      case 'ERROR': return const Color(0xFFEF4444);
      default:      return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(entry.timeStr,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF6B7280))),
      const SizedBox(width: 12),
      SizedBox(width: 42,
        child: Text(entry.level,
          style: TextStyle(fontFamily: 'monospace', fontSize: 11,
            fontWeight: FontWeight.w700, color: _levelColor(entry.level)))),
      const SizedBox(width: 8),
      Expanded(child: Text('[${entry.tag}] ${entry.message}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFD1D5DB)))),
    ]),
  );
}
