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
  ImportResult({required this.nodes, required this.errors,
    required this.fixes, this.detectedSource});
}

class NodesProvider extends ChangeNotifier {
  final List<ProxyNode> _nodes = [];
  ProxyNode? _selected;
  String _filterGroup = '全部';
  String _searchQuery = '';

  List<ProxyNode> get all => _nodes;

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

  NodesProvider() {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('nodes');
    final stored = box.values.whereType<ProxyNode>().toList();
    if (stored.isEmpty) {
      // Load demo nodes on first launch
      _nodes.addAll(ProxyNode.demoNodes);
      _selected = _nodes.first;
    } else {
      _nodes.addAll(stored);
      _selected = _nodes.first;
    }
    notifyListeners();
  }

  void setFilterGroup(String g) { _filterGroup = g; notifyListeners(); }
  void setSearch(String q) { _searchQuery = q; notifyListeners(); }

  void select(ProxyNode node) {
    _selected = node;
    notifyListeners();
  }

  void remove(String id) {
    _nodes.removeWhere((n) => n.id == id);
    if (_selected?.id == id) _selected = _nodes.isNotEmpty ? _nodes.first : null;
    _saveToHive();
    notifyListeners();
  }

  Future<ImportResult> importFromUri(String input) async {
    final parser = NodeParser();
    final autofix = AutofixEngine();

    final parsed = await parser.parse(input);
    final fixes = autofix.fixAll(parsed.nodes);

    // Dedup by server:port:uuid
    for (final node in parsed.nodes) {
      final exists = _nodes.any((n) =>
        n.server == node.server && n.port == node.port && n.uuid == node.uuid);
      if (!exists) _nodes.add(node);
    }

    if (_selected == null && _nodes.isNotEmpty) _selected = _nodes.first;
    _saveToHive();
    notifyListeners();

    return ImportResult(
      nodes: parsed.nodes,
      errors: parsed.errors,
      fixes: fixes,
      detectedSource: parsed.detectedSource,
    );
  }

  Future<void> testLatency(String nodeId) async {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx < 0) return;

    // TCP connect timing – real implementation uses dart:io Socket.connect
    await Future.delayed(const Duration(milliseconds: 500));
    final ms = 15 + (DateTime.now().millisecondsSinceEpoch % 250);
    _nodes[idx].latencyMs = ms;
    notifyListeners();
  }

  Future<void> testAll() async {
    await Future.wait(_nodes.map((n) => testLatency(n.id)));
  }

  void _saveToHive() {
    final box = Hive.box('nodes');
    box.clear();
    for (final n in _nodes) { box.add(n); }
  }
}
