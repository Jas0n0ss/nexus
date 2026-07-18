import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/nodes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shell_nav.dart';
import '../widgets/glass_card.dart';

enum _ImportMode { url, uri, file, qr }

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
            '成功导入 ${result.nodes.length} 个节点'
            '${result.detectedSource != null ? '  ·  来源：${result.detectedSource}' : ''}';
        if (result.errors.isNotEmpty) {
          _warnings = result.errors;
        }
      } else {
        _resultMsg = '解析失败：${result.errors.isNotEmpty ? result.errors.first : "未知错误"}';
        _warnings = result.errors.skip(1).toList();
      }
      _fixes = result.fixes.map((f) => f.description).toList();
      _parsed = result.nodes.map((n) => '${n.flag} ${n.name}  ·  ${n.protocolLabel}').toList();
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
    if (path != null) {
      setState(() => _ctrl.text = 'file://$path');
    }
  }

  Future<void> _refreshSubs() async {
    setState(() {
      _loading = true;
      _resultMsg = null;
    });
    final result = await context.read<NodesProvider>().refreshSubscriptions();
    setState(() {
      _loading = false;
      _resultOk = result.ok;
      _resultMsg = result.ok
          ? '订阅更新完成，解析 ${result.nodes.length} 个节点'
          : '订阅更新失败：${result.errors.isNotEmpty ? result.errors.first : ""}';
      _parsed = result.nodes.map((n) => '${n.flag} ${n.name}').toList();
      _warnings = result.errors;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodes = context.watch<NodesProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 20),
              _modeSelector(),
              const SizedBox(height: 16),
              _inputArea(context),
              if (nodes.subscriptionUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _subscriptionBar(nodes),
              ],
              const SizedBox(height: 16),
              if (_loading) _progressIndicator(),
              if (_resultMsg != null) _resultCard(),
              if (_parsed.isNotEmpty) ...[
                const SizedBox(height: 12),
                _parsedList(),
              ],
              const SizedBox(height: 24),
              _sourceInfo(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('导入配置', style: Theme.of(ctx).textTheme.displayLarge),
          Text(
            '支持订阅链接 / URI / Clash YAML / sing-box JSON / 本地文件',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      );

  Widget _modeSelector() => Row(
        children: _ImportMode.values.map((m) {
          final labels = {
            _ImportMode.url: ('订阅', Icons.link_rounded),
            _ImportMode.uri: ('URI', Icons.content_paste_rounded),
            _ImportMode.file: ('文件', Icons.folder_open_rounded),
            _ImportMode.qr: ('扫码', Icons.qr_code_scanner_rounded),
          };
          final (label, icon) = labels[m]!;
          final active = _mode == m;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _mode = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF3B82F6).withOpacity(0.12)
                        : Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF3B82F6)
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(children: [
                    Icon(icon,
                        size: 22,
                        color: active
                            ? const Color(0xFF3B82F6)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.45)),
                    const SizedBox(height: 4),
                    Text(label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? const Color(0xFF3B82F6)
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        )),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _inputArea(BuildContext ctx) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              maxLines: 5,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText: _placeholder,
                border: InputBorder.none,
                fillColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: _loading ? null : _import,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                  child: const Text('解析导入'),
                ),
                OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('粘贴'),
                ),
                if (_mode == _ImportMode.file)
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('选择文件'),
                  ),
                Text(
                  'vmess / vless / trojan / ss / hy2 / tuic / clash / sing-box',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _subscriptionBar(NodesProvider nodes) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已保存订阅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${nodes.subscriptionUrls.length} 条 · 点击更新可重新拉取',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _refreshSubs,
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: const Text('更新订阅'),
          ),
        ]),
      );

  Widget _progressIndicator() => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('正在解析配置...', style: TextStyle(fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(borderRadius: BorderRadius.circular(2)),
        ]),
      );

  Widget _resultCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (_resultOk ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withOpacity(0.08),
          border: Border.all(
            color: (_resultOk ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withOpacity(0.25),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                _resultOk ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 18,
                color: _resultOk ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_resultMsg!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (_resultOk)
                TextButton(
                  onPressed: () => context.read<ShellNav>().openNodes(),
                  child: const Text('查看节点'),
                ),
            ]),
            if (_warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._warnings.take(5).map((w) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('· $w',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                        )),
                  )),
            ],
            if (_fixes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '自动修复 ${_fixes.length} 项',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ..._fixes.take(8).map((f) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('  · $f',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFFBBF24))),
                  )),
            ],
          ],
        ),
      );

  Widget _parsedList() => GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('解析结果', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._parsed.take(20).map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p, style: const TextStyle(fontSize: 13))),
                  ]),
                )),
            if (_parsed.length > 20)
              Text('… 另有 ${_parsed.length - 20} 个节点',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  )),
          ],
        ),
      );

  Widget _sourceInfo(BuildContext ctx) => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '支持的格式',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: const [
              _SourceChip('订阅 Base64', '通用机场订阅'),
              _SourceChip('Clash YAML', 'proxies 列表'),
              _SourceChip('sing-box JSON', 'outbounds 提取'),
              _SourceChip('URI 分享', 'vmess/vless/trojan/ss/hy2/tuic'),
              _SourceChip('本地文件', 'json / yaml / conf'),
            ]),
          ],
        ),
      );

  String get _placeholder {
    switch (_mode) {
      case _ImportMode.url:
        return '粘贴订阅链接：\nhttps://example.com/sub?token=xxx';
      case _ImportMode.uri:
        return '每行一个 URI：\nvless://uuid@host:443?security=reality#name\nss://...#name';
      case _ImportMode.file:
        return '粘贴配置内容，或点击「选择文件」导入 .json / .yaml / .conf';
      case _ImportMode.qr:
        return '请使用订阅链接或 URI 方式导入（扫码将在后续版本完善）';
    }
  }
}

class _SourceChip extends StatelessWidget {
  final String name, subtitle;
  const _SourceChip(this.name, this.subtitle);
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Text(subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.45),
              )),
        ]),
      );
}
