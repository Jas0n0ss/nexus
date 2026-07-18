import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/proxy_node.dart';
import '../core/node_parser.dart';
import '../core/autofix_engine.dart';

class ImportResult {
  final List<ProxyNode> nodes;
  final List<String> errors;
  final List<AutoFix> fixes;
  final String? detectedSource;
  ImportResult({
    required this.nodes,
    required this.errors,
    required this.fixes,
    this.detectedSource,
  });

  bool get ok => nodes.isNotEmpty;
}

class NodesProvider extends ChangeNotifier {
  final List<ProxyNode> _nodes = [];
  ProxyNode? _selected;
  String _filterGroup = '全部';
  String _searchQuery = '';
  final List<String> _subscriptionUrls = [];

  List<ProxyNode> get all => List.unmodifiable(_nodes);
  List<String> get subscriptionUrls => List.unmodifiable(_subscriptionUrls);

  List<ProxyNode> get filtered {
    return _nodes.where((n) {
      final matchGroup = _filterGroup == '全部' || n.group == _filterGroup;
      final q = _searchQuery.toLowerCase();
      final matchQ = q.isEmpty ||
          n.name.toLowerCase().contains(q) ||
          n.protocolLabel.toLowerCase().contains(q) ||
          n.group.toLowerCase().contains(q) ||
          n.server.toLowerCase().contains(q);
      return matchGroup && matchQ;
    }).toList();
  }

  Set<String> get groups => {'全部', ..._nodes.map((n) => n.group)};
  ProxyNode? get selected => _selected;
  String get filterGroup => _filterGroup;
  bool get isEmpty => _nodes.isEmpty;

  NodesProvider() {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('nodes');
    try {
      final raw = box.get('nodes_json');
      if (raw is String && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          if (item is Map) {
            _nodes.add(ProxyNode.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } else {
        // Legacy: typed ProxyNode objects (usually empty — adapter was never registered)
        for (final v in box.values) {
          if (v is ProxyNode) _nodes.add(v);
        }
      }

      final subs = box.get('subscriptions_json');
      if (subs is String && subs.isNotEmpty) {
        final list = jsonDecode(subs) as List;
        _subscriptionUrls.addAll(list.map((e) => e.toString()));
      }

      final selectedId = box.get('selected_id') as String?;
      if (selectedId != null) {
        final match = _nodes.where((n) => n.id == selectedId);
        _selected = match.isNotEmpty
            ? match.first
            : (_nodes.isNotEmpty ? _nodes.first : null);
      } else if (_nodes.isNotEmpty) {
        _selected = _nodes.first;
      }
    } catch (e) {
      debugPrint('nodes load failed: $e');
    }
    // Intentionally NO demo / preset nodes — empty until user imports.
    notifyListeners();
  }

  void setFilterGroup(String g) { _filterGroup = g; notifyListeners(); }
  void setSearch(String q) { _searchQuery = q; notifyListeners(); }

  void select(ProxyNode node) {
    _selected = node;
    _saveToHive();
    notifyListeners();
  }

  void remove(String id) {
    _nodes.removeWhere((n) => n.id == id);
    if (_selected?.id == id) _selected = _nodes.isNotEmpty ? _nodes.first : null;
    _saveToHive();
    notifyListeners();
  }

  void clearAll() {
    _nodes.clear();
    _selected = null;
    _saveToHive();
    notifyListeners();
  }

  Future<ImportResult> importFromUri(String input, {bool applyAutofix = true}) async {
    final parser = NodeParser();
    final autofix = AutofixEngine();

    final parsed = await parser.parse(input);
    var nodes = parsed.nodes;
    var fixes = <AutoFix>[];

    if (applyAutofix && nodes.isNotEmpty) {
      final fixed = autofix.fixAll(nodes);
      nodes = fixed.nodes;
      fixes = fixed.fixes;
    }

    var added = 0;
    for (final node in nodes) {
      final exists = _nodes.any((n) => n.dedupeKey == node.dedupeKey);
      if (!exists) {
        _nodes.add(node);
        added++;
      }
    }

    final trimmed = input.trim();
    if ((trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
        !_subscriptionUrls.contains(trimmed)) {
      _subscriptionUrls.add(trimmed);
    }

    if (_selected == null && _nodes.isNotEmpty) _selected = _nodes.first;
    _saveToHive();
    notifyListeners();

    final errors = List<String>.from(parsed.errors);
    if (nodes.isEmpty && errors.isEmpty) {
      errors.add('未解析到任何节点');
    } else if (added == 0 && nodes.isNotEmpty) {
      errors.add('节点已存在，未重复导入');
    }

    return ImportResult(
      nodes: nodes,
      errors: errors,
      fixes: fixes,
      detectedSource: parsed.detectedSource,
    );
  }

  Future<ImportResult> refreshSubscriptions() async {
    if (_subscriptionUrls.isEmpty) {
      return ImportResult(nodes: [], errors: ['没有已保存的订阅链接'], fixes: []);
    }
    final allNodes = <ProxyNode>[];
    final errors = <String>[];
    final fixes = <AutoFix>[];
    String? source;
    for (final url in List<String>.from(_subscriptionUrls)) {
      final r = await importFromUri(url);
      allNodes.addAll(r.nodes);
      errors.addAll(r.errors.map((e) => '$url → $e'));
      fixes.addAll(r.fixes);
      source ??= r.detectedSource;
    }
    return ImportResult(
      nodes: allNodes,
      errors: errors,
      fixes: fixes,
      detectedSource: source,
    );
  }

  Future<void> testLatency(String nodeId) async {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx < 0) return;

    final node = _nodes[idx];
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        node.server,
        node.port,
        timeout: const Duration(seconds: 5),
      );
      sw.stop();
      await socket.close();
      _nodes[idx].latencyMs = sw.elapsedMilliseconds;
      _nodes[idx].isReachable = true;
    } catch (_) {
      sw.stop();
      _nodes[idx].latencyMs = null;
      _nodes[idx].isReachable = false;
    }
    notifyListeners();
  }

  Future<void> testAll() async {
    // Limit concurrency to avoid flooding
    const batch = 8;
    for (var i = 0; i < _nodes.length; i += batch) {
      final slice = _nodes.skip(i).take(batch);
      await Future.wait(slice.map((n) => testLatency(n.id)));
    }
  }

  void _saveToHive() {
    final box = Hive.box('nodes');
    box.put('nodes_json', jsonEncode(_nodes.map((n) => n.toJson()).toList()));
    box.put('subscriptions_json', jsonEncode(_subscriptionUrls));
    if (_selected != null) {
      box.put('selected_id', _selected!.id);
    } else {
      box.delete('selected_id');
    }
  }
}
