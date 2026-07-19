import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/proxy_node.dart';
import '../core/singbox_runner.dart';
import 'logs_provider.dart';
import 'nodes_provider.dart';
import 'settings_provider.dart';

enum VpnState { disconnected, connecting, connected, disconnecting, error }

class VpnProvider extends ChangeNotifier {
  final SingboxRunner singboxRunner;
  final LogsProvider logsProvider;
  SettingsProvider? settings;

  VpnState _state = VpnState.disconnected;
  ProxyNode? _activeNode;
  DateTime? _connectedAt;
  Timer? _statsTimer;
  StreamSubscription<String>? _logSub;
  String? lastError;

  double uploadMbps = 0;
  double downloadMbps = 0;
  int latencyMs = 0;
  double totalGbToday = 0;
  String? externalIp;

  final List<double> uploadHistory = List.filled(40, 0);
  final List<double> downloadHistory = List.filled(40, 0);

  VpnProvider({required this.singboxRunner, required this.logsProvider});

  VpnState get state => _state;
  ProxyNode? get activeNode => _activeNode;
  bool get isConnected => _state == VpnState.connected;
  Duration get uptime => _connectedAt != null
      ? DateTime.now().difference(_connectedAt!)
      : Duration.zero;

  void bindSettings(SettingsProvider s) {
    settings = s;
  }

  void updateNodes(NodesProvider nodes) {
    if (_activeNode != null &&
        !nodes.all.any((n) => n.id == _activeNode!.id)) {
      disconnect();
    }
  }

  Future<void> connect(ProxyNode node, {bool force = false}) async {
    if (_state == VpnState.connecting || _state == VpnState.disconnecting) {
      return;
    }

    // Switch node while connected → reconnect (force=true for crash restart)
    if (_state == VpnState.connected) {
      if (!force && _activeNode?.id == node.id) return;
      await disconnect();
    }

    _setState(VpnState.connecting);
    lastError = null;
    logsProvider.add(
      'INFO',
      'CONNECT',
      '正在连接 ${node.name} (${node.protocolLabel}) · 路由=${settings?.routeMode.name ?? "rule"} · TUN=${settings?.tunMode == true ? "开" : "关"}',
    );

    try {
      _logSub?.cancel();
      _logSub = singboxRunner.logs.listen((line) {
        final level = line.contains('[ERR]') ? 'ERROR' : 'INFO';
        logsProvider.add(level, 'CORE', line);
      });

      await singboxRunner.start(node, settings: settings);
      _activeNode = node;
      _connectedAt = DateTime.now();
      _setState(VpnState.connected);
      logsProvider.add('OK', 'CONNECT', '核心已启动 · ${node.name}');
      _startStatsTimer();
      await _fetchExternalIp();
      if (settings?.postConnectTest != false) {
        _runPostConnectTests();
      }
    } catch (e) {
      lastError = e.toString();
      _setState(VpnState.error);
      logsProvider.add('ERROR', 'CONNECT', '连接失败: $e');
      await singboxRunner.stop();
      _activeNode = null;
      _connectedAt = null;
    }
  }

  Future<void> disconnect() async {
    if (_state == VpnState.disconnected) return;
    _setState(VpnState.disconnecting);
    _statsTimer?.cancel();
    logsProvider.add('INFO', 'DISCONNECT', '正在断开连接...');
    await singboxRunner.stop();
    await _logSub?.cancel();
    _logSub = null;
    _activeNode = null;
    _connectedAt = null;
    externalIp = null;
    uploadMbps = 0;
    downloadMbps = 0;
    latencyMs = 0;
    for (int i = 0; i < uploadHistory.length; i++) {
      uploadHistory[i] = 0;
      downloadHistory[i] = 0;
    }
    _setState(VpnState.disconnected);
    logsProvider.add('INFO', 'DISCONNECT', '已断开连接');
  }

  Future<void> toggle(ProxyNode? node) async {
    if (isConnected || _state == VpnState.error) {
      await disconnect();
    } else if (node != null) {
      await connect(node);
    } else {
      logsProvider.add('ERROR', 'CONNECT', '请先导入并选择一个节点');
    }
  }

  /// Hot-apply route mode / TUN / DNS changes by reconnecting.
  Future<void> applySettingsAndReconnect() async {
    final node = _activeNode;
    if (node == null || !isConnected) return;
    logsProvider.add('INFO', 'SETTINGS', '设置已变更，正在重载核心...');
    await disconnect();
    await connect(node);
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (!isConnected) return;
      if (!singboxRunner.isRunning &&
          (settings?.crashAutoRestart == true || settings?.autoReconnect == true) &&
          _activeNode != null) {
        logsProvider.add('WARN', 'CORE', '核心退出，尝试自动重连...');
        final node = _activeNode!;
        await connect(node, force: true);
        return;
      }

      final stats = await singboxRunner.getStats();
      uploadMbps = stats.uploadMbps;
      downloadMbps = stats.downloadMbps;
      latencyMs = stats.latencyMs;
      totalGbToday += (uploadMbps + downloadMbps) * 0.8 / 8192;

      uploadHistory.removeAt(0);
      uploadHistory.add(uploadMbps);
      downloadHistory.removeAt(0);
      downloadHistory.add(downloadMbps);

      notifyListeners();
    });
  }

  Future<void> _fetchExternalIp() async {
    try {
      final port = singboxRunner.mixedPort;
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      client.findProxy = (_) => 'PROXY 127.0.0.1:$port';
      final req = await client.getUrl(Uri.parse('https://api.ipify.org?format=json'));
      final resp = await req.close().timeout(const Duration(seconds: 6));
      final body = await resp.transform(utf8.decoder).join();
      client.close(force: true);
      final json = jsonDecode(body) as Map<String, dynamic>;
      externalIp = json['ip']?.toString();
      notifyListeners();
      if (externalIp != null) {
        logsProvider.add('OK', 'IP', '出口 IP: $externalIp');
      }
    } catch (e) {
      // Fallback without forcing proxy (TUN path)
      try {
        final resp = await http
            .get(Uri.parse('https://api.ipify.org'))
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200 && resp.body.isNotEmpty) {
          externalIp = resp.body.trim();
          notifyListeners();
        }
      } catch (_) {
        logsProvider.add('WARN', 'IP', '出口 IP 获取失败: $e');
      }
    }
  }

  void _runPostConnectTests() {
    Future.delayed(const Duration(seconds: 1), () async {
      if (!isConnected) return;
      logsProvider.add('INFO', 'TEST', '连通性检测中...');
      final port = singboxRunner.mixedPort;
      await _probeViaProxy('http://cp.cloudflare.com/generate_204', port, 'Cloudflare');
      await _probeViaProxy('https://www.gstatic.com/generate_204', port, 'Google');
    });
  }

  Future<void> _probeViaProxy(String url, int port, String label) async {
    try {
      final sw = Stopwatch()..start();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      client.findProxy = (_) => 'PROXY 127.0.0.1:$port';
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close().timeout(const Duration(seconds: 6));
      await resp.drain<void>();
      client.close(force: true);
      sw.stop();
      logsProvider.add('OK', 'TEST', '$label → ${resp.statusCode} (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      logsProvider.add('ERROR', 'TEST', '$label 不可达: $e');
    }
  }

  void _setState(VpnState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _logSub?.cancel();
    singboxRunner.stop();
    super.dispose();
  }
}
