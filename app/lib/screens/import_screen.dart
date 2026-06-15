import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/nodes_provider.dart';
import '../widgets/glass_card.dart';

enum _ImportMode { url, uri, file, qr }

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  _ImportMode _mode = _ImportMode.url;
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _resultMsg;
  bool _resultOk = true;
  List<String> _fixes = [];
  List<String> _parsed = [];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _import() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    setState(() { _loading = true; _resultMsg = null; _fixes = []; _parsed = []; });

    final nodes = context.read<NodesProvider>();
    final result = await nodes.importFromUri(input);

    setState(() {
      _loading = false;
      _resultOk = result.errors.isEmpty;
      _resultMsg = result.errors.isEmpty
          ? '成功解析 ${result.nodes.length} 个节点'
              + (result.detectedSource != null ? '  ·  来源：${result.detectedSource}' : '')
          : '解析失败：${result.errors.first}';
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
      allowedExtensions: ['json','yaml','yml','conf'],
      type: FileType.custom,
    );
    if (result?.files.single.path != null) {
      setState(() => _ctrl.text = 'file://${result!.files.single.path}');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 16),
              if (_loading) _progressIndicator(),
              if (_resultMsg != null) _resultCard(),
              if (_parsed.isNotEmpty) ...[const SizedBox(height: 12), _parsedList()],
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
      Text('支持 sing-box / Xray / v2ray 脚本一键导入', style: Theme.of(ctx).textTheme.bodySmall),
    ],
  );

  Widget _modeSelector() => Row(
    children: _ImportMode.values.map((m) {
      final labels = {
        _ImportMode.url:  ('🔗', '订阅链接'),
        _ImportMode.uri:  ('📋', 'URI 粘贴'),
        _ImportMode.file: ('📄', '配置文件'),
        _ImportMode.qr:   ('📷', '二维码'),
      };
      final (icon, label) = labels[m]!;
      final active = _mode == m;
      return Expanded(child: Padding(
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
                color: active ? const Color(0xFF3B82F6) : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: active ? const Color(0xFF3B82F6) : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              )),
            ]),
          ),
        ),
      ));
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
        Row(children: [
          FilledButton(
            onPressed: _import,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('解析导入'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _paste,
            icon: const Icon(Icons.content_paste_rounded, size: 16),
            label: const Text('粘贴'),
          ),
          if (_mode == _ImportMode.file) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: const Text('选择文件'),
            ),
          ],
          const Spacer(),
          Text('vmess:// vless:// trojan:// ss:// hysteria2:// tuic://',
            style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
        ]),
      ],
    ),
  );

  Widget _progressIndicator() => GlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      Row(children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        const Text('正在解析，自动识别脚本来源...', style: TextStyle(fontSize: 13)),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(borderRadius: BorderRadius.circular(2)),
    ]),
  );

  Widget _resultCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: (_resultOk ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withOpacity(0.08),
      border: Border.all(color: (_resultOk ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withOpacity(0.25)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(_resultOk ? '✅' : '❌', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(_resultMsg!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ]),
        if (_fixes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(children: [
              const Text('🔧', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text('自动修复了 ${_fixes.length} 项配置问题',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFBBF24))),
            ]),
          ),
          const SizedBox(height: 6),
          ..._fixes.map((f) => Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('  · $f', style: const TextStyle(fontSize: 11, color: Color(0xFFFBBF24))),
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
        ..._parsed.map((p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            const Text('✓', style: TextStyle(color: Color(0xFF22C55E), fontSize: 14)),
            const SizedBox(width: 10),
            Text(p, style: const TextStyle(fontSize: 13)),
          ]),
        )),
      ],
    ),
  );

  Widget _sourceInfo(BuildContext ctx) => GlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('支持的脚本来源',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: const [
          _SourceChip('233boy/sing-box', 'VLESS REALITY · Hysteria2'),
          _SourceChip('233boy/Xray', 'VMess · VLESS · Trojan'),
          _SourceChip('233boy/v2ray', 'VMess WS · gRPC'),
          _SourceChip('mack-a/v2ray-agent', '全协议 · 多用户'),
          _SourceChip('yonggekkk/sing-box-yg', 'sing-box 一键'),
          _SourceChip('通用格式', 'Base64 · JSON · YAML'),
        ]),
      ],
    ),
  );

  String get _placeholder {
    switch (_mode) {
      case _ImportMode.url:
        return '粘贴订阅链接：\nhttps://your.domain/sub?token=xxx  (233boy/sing-box)\nhttps://your.domain/singbox  (yonggekkk)';
      case _ImportMode.uri:
        return '每行一个 URI：\nvmess://ew0KICAidiI6ICIyIiw...\nvless://uuid@host:443?encryption=none&security=reality#name\ntrojan://password@host:443#name';
      case _ImportMode.file:
        return '粘贴配置内容或点击"选择文件"上传 .json / .yaml / .conf';
      case _ImportMode.qr:
        return '移动端：点击下方扫码按钮\n桌面端：请使用订阅链接或 URI 方式导入';
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
      Text(subtitle, style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.45))),
    ]),
  );
}
