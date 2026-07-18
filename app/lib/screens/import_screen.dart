import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/nodes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shell_nav.dart';
import '../theme/nexus_theme.dart';
import '../widgets/nexus_surface.dart';
import '../widgets/page_header.dart';

enum _ImportMode { url, uri, file }

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  _ImportMode _mode = _ImportMode.url;
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _resultMsg;
  bool _resultOk = true;
  List<String> _fixes = [];
  List<String> _parsed = [];
  List<String> _warnings = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _loading = true;
      _resultMsg = null;
      _fixes = [];
      _parsed = [];
      _warnings = [];
    });

    final settings = context.read<SettingsProvider>();
    final nodes = context.read<NodesProvider>();
    final result = await nodes.importFromUri(input, applyAutofix: settings.autofix);

    if (input.startsWith('http://') || input.startsWith('https://')) {
      settings.set((s) => s.lastSubscriptionUrl = input);
    }

    setState(() {
      _loading = false;
      _resultOk = result.ok;
      if (result.ok) {
        _resultMsg =
            '导入 ${result.nodes.length} 个节点${result.detectedSource != null ? ' · ${result.detectedSource}' : ''}';
        _warnings = result.errors;
      } else {
        _resultMsg =
            result.errors.isNotEmpty ? result.errors.first : '解析失败';
        _warnings = result.errors.skip(1).toList();
      }
      _fixes = result.fixes.map((f) => f.description).toList();
      _parsed =
          result.nodes.map((n) => '${n.flag} ${n.name} · ${n.protocolLabel}').toList();
    });
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) setState(() => _ctrl.text = d!.text!);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: const ['json', 'yaml', 'yml', 'conf', 'txt'],
      type: FileType.custom,
    );
    final path = result?.files.single.path;
    if (path != null) setState(() => _ctrl.text = 'file://$path');
  }

  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: '导入',
                subtitle: '订阅 · URI · Clash / sing-box 文件',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (final m in _ImportMode.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ModeTab(
                          label: switch (m) {
                            _ImportMode.url => '订阅',
                            _ImportMode.uri => 'URI',
                            _ImportMode.file => '文件',
                          },
                          active: _mode == m,
                          onTap: () => setState(() => _mode = m),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              NexusSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _ctrl,
                      maxLines: 6,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 12,
                        fontFamilyFallback: ['monospace'],
                      ),
                      decoration: InputDecoration(
                        hintText: switch (_mode) {
                          _ImportMode.url => 'https://example.com/sub',
                          _ImportMode.uri => '每行一个 vless:// / ss:// / …',
                          _ImportMode.file => '粘贴内容或选择文件',
                        },
                        border: InputBorder.none,
                        filled: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _loading ? null : _import,
                          child: const Text('解析导入'),
                        ),
                        OutlinedButton(
                          onPressed: _paste,
                          child: const Text('粘贴'),
                        ),
                        if (_mode == _ImportMode.file)
                          OutlinedButton(
                            onPressed: _pickFile,
                            child: const Text('选择文件'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (nodes.subscriptionUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                NexusSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '已保存 ${nodes.subscriptionUrls.length} 条订阅',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                setState(() => _loading = true);
                                final r = await nodes.refreshSubscriptions();
                                setState(() {
                                  _loading = false;
                                  _resultOk = r.ok;
                                  _resultMsg = r.ok
                                      ? '订阅更新：${r.nodes.length} 节点'
                                      : '更新失败';
                                });
                              },
                        child: const Text('更新'),
                      ),
                    ],
                  ),
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(color: NexusColors.accent),
              ],
              if (_resultMsg != null) ...[
                const SizedBox(height: 16),
                NexusSurface(
                  borderColor: (_resultOk ? NexusColors.ok : NexusColors.danger)
                      .withOpacity(0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _resultOk ? Icons.check_circle_outline : Icons.error_outline,
                            size: 18,
                            color: _resultOk ? NexusColors.ok : NexusColors.danger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _resultMsg!,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_resultOk)
                            TextButton(
                              onPressed: () => context.read<ShellNav>().openNodes(),
                              child: const Text('查看'),
                            ),
                        ],
                      ),
                      if (_warnings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ..._warnings.take(4).map(
                              (w) => Text('· $w',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ),
                      ],
                      if (_fixes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '自动修复 ${_fixes.length} 项',
                          style: const TextStyle(
                            color: NexusColors.warn,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_parsed.isNotEmpty) ...[
                const SizedBox(height: 12),
                NexusSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('结果', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 8),
                      ..._parsed.take(16).map(
                            (p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(p, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? NexusColors.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? NexusColors.accent.withOpacity(0.45) : NexusColors.line,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active
                  ? NexusColors.accent
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ),
      ),
    );
  }
}
