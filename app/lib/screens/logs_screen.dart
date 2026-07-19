import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/logs_provider.dart';
import '../theme/nexus_theme.dart';
import '../widgets/nexus_surface.dart';
import '../widgets/page_header.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _filter = 'ALL';
  bool _autoScroll = true;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: '日志',
                subtitle: '核心实时输出',
                actions: [
                  OutlinedButton(
                    onPressed: logs.clear,
                    child: const Text('清空'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final f in const ['ALL', 'INFO', 'WARN', 'ERROR']) ...[
                    _Chip(
                      label: f,
                      active: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  Text('自动滚动', style: Theme.of(context).textTheme.bodySmall),
                  Switch(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: NexusSurface(
                  padding: const EdgeInsets.all(14),
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('暂无日志',
                              style: Theme.of(context).textTheme.bodySmall),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _Line(filtered[i]),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? NexusColors.accent.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? NexusColors.accent.withOpacity(0.4) : NexusColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? NexusColors.accent : NexusColors.textDim,
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final LogEntry entry;
  const _Line(this.entry);

  Color _color(String level) {
    switch (level) {
      case 'OK':
        return NexusColors.ok;
      case 'WARN':
        return NexusColors.warn;
      case 'ERROR':
        return NexusColors.danger;
      default:
        return NexusColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.45,
            color: NexusColors.textDim,
          ),
          children: [
            TextSpan(text: '${entry.timeStr}  '),
            TextSpan(
              text: entry.level.padRight(5),
              style: TextStyle(
                color: _color(entry.level),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: ' [${entry.tag}] ${entry.message}'),
          ],
        ),
      ),
    );
  }
}
