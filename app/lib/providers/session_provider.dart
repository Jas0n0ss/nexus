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

enum SessionState { disconnected, connecting, connected, disconnecting, error }

/// Connection controller with Passwall-style auto failover.
///
/// Health loop (when [SettingsProvider.autoFailover] is on):
/// 1. Probe [probeUrl] through the local mixed port
/// 2. If probe fails but the device still has network → try next node
/// 3. Walk main → backups (other imported nodes by latency) → wrap
/// 4. Optionally restore the primary node when it recovers
class SessionProvider extends ChangeNotifier {
  final SingboxRunner singboxRunner;
  final LogsProvider logsProvider;
  SettingsProvider? settings;
  NodesProvider? _nodes;

  SessionState _state = SessionState.disconnected;
  ProxyNode? _activeNode;
  ProxyNode? _primaryNode;
  DateTime? _connectedAt;
  Timer? _statsTimer;
  Timer? _healthTimer;
  StreamSubscription<String>? _logSub;
  String? lastError;
  bool _failoverInFlight = false;
  int _failoverCursor = 0;

  double uploadMbps = 0;
  double downloadMbps = 0;
  int latencyMs = 0;
  double totalGbToday = 0;
  String? externalIp;

  final List<double> uploadHistory = List.filled(40, 0);
  final List<double> downloadHistory = List.filled(40, 0);

  SessionProvider({required this.singboxRunner, required this.logsProvider});

  SessionState get state => _state;
  ProxyNode? get activeNode => _activeNode;
  bool get isConnected => _state == SessionState.connected;
  Duration get uptime => _connectedAt != null
      ? DateTime.now().difference(_connectedAt!)
      : Duration.zero;

  void bindSettings(SettingsProvider s) {
    settings = s;
  }

  void updateNodes(NodesProvider nodes) {
    _nodes = nodes;
    if (_activeNode != null &&
        !nodes.all.any((n) => n.id == _activeNode!.id)) {
      disconnect();
    }
  }

  Future<void> connect(ProxyNode node, {bool force = false, bool asPrimary = true}) async {
    if (_state == SessionState.connecting || _state == SessionState.disconnecting) {
      return;
    }

    if (_state == SessionState.connected) {
      if (!force && _activeNode?.id == node.id) return;
      await disconnect(keepHealth: false);
    }

    _setState(SessionState.connecting);
    lastError = null;
    if (asPrimary) _primaryNode = node;

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
      _setState(SessionState.connected);
      logsProvider.add('OK', 'CONNECT', '核心已启动 · ${node.name}');
      _startStatsTimer();
      _startHealthTimer();
      await _fetchExternalIp();
      if (settings?.postConnectTest != false) {
        _runPostConnectTests();
      }
    } catch (e) {
      lastError = e.toString();
      _setState(SessionState.error);
      logsProvider.add('ERROR', 'CONNECT', '连接失败: $e');
      await singboxRunner.stop();
      _activeNode = null;
      _connectedAt = null;
      _stopHealthTimer();

      // Connect-time failover: try next candidate immediately.
      if (settings?.autoFailover == true && force == false) {
        final next = _nextFailoverCandidate(excludeId: node.id);
        if (next != null) {
          logsProvider.add('WARN', 'FAILOVER', '主节点失败，尝试 ${next.name}');
          await connect(next, force: true, asPrimary: false);
          return;
        }
      }
    }
  }

  Future<void> disconnect({bool keepHealth = false}) async {
    if (_state == SessionState.disconnected) return;
    _setState(SessionState.disconnecting);
    _statsTimer?.cancel();
    if (!keepHealth) _stopHealthTimer();
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
    _setState(SessionState.disconnected);
    logsProvider.add('INFO', 'DISCONNECT', '已断开连接');
  }

  Future<void> toggle(ProxyNode? node) async {
    if (isConnected || _state == SessionState.error) {
      await disconnect();
    } else if (node != null) {
      await connect(node);
    } else {
      logsProvider.add('ERROR', 'CONNECT', '请先导入并选择一个节点');
    }
  }

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
        await connect(node, force: true, asPrimary: false);
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

  void _startHealthTimer() {
    _stopHealthTimer();
    if (settings?.autoFailover != true) return;
    final interval = Duration(seconds: (settings?.failoverIntervalSec ?? 30).clamp(10, 300));
    _healthTimer = Timer.periodic(interval, (_) => _healthTick());
  }

  void _stopHealthTimer() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  Future<void> _healthTick() async {
    if (!isConnected || _failoverInFlight || settings?.autoFailover != true) return;
    _failoverInFlight = true;
    try {
      final probeOk = await _probeProxy();
      if (probeOk) {
        // Optionally restore primary when it recovers.
        if (settings?.restorePrimary == true &&
            _primaryNode != null &&
            _activeNode?.id != _primaryNode!.id) {
          final primaryOk = await _preflightNode(_primaryNode!);
          if (primaryOk) {
            logsProvider.add('OK', 'FAILOVER', '主节点已恢复，切回 ${_primaryNode!.name}');
            await connect(_primaryNode!, force: true, asPrimary: true);
          }
        }
        return;
      }

      // Distinguish proxy dead vs device offline (Passwall socks_auto_switch logic).
      final netOk = await _deviceHasNetwork();
      if (!netOk) {
        logsProvider.add('WARN', 'FAILOVER', '本机网络不可用，暂不切换节点');
        return;
      }

      final next = _nextFailoverCandidate(excludeId: _activeNode?.id);
      if (next == null) {
        logsProvider.add('ERROR', 'FAILOVER', '探测失败且无可用备用节点');
        return;
      }

      final ok = await _preflightNode(next);
      if (!ok) {
        logsProvider.add('WARN', 'FAILOVER', '备用节点 ${next.name} 预检失败，继续轮询');
        // Advance cursor anyway so we don't stick on a dead node.
        _failoverCursor++;
        return;
      }

      logsProvider.add('WARN', 'FAILOVER', '当前节点不可达 → 切换到 ${next.name}');
      await connect(next, force: true, asPrimary: false);
    } finally {
      _failoverInFlight = false;
    }
  }

  List<ProxyNode> _failoverPool() {
    final all = _nodes?.all ?? const <ProxyNode>[];
    if (all.isEmpty) return const [];
    final sorted = [...all]
      ..sort((a, b) => (a.latencyMs ?? 99999).compareTo(b.latencyMs ?? 99999));
    // Prefer primary first, then low-latency others.
    final primary = _primaryNode;
    final rest = sorted.where((n) => n.id != primary?.id).toList();
    return [
      if (primary != null && sorted.any((n) => n.id == primary.id)) primary,
      ...rest,
    ];
  }

  ProxyNode? _nextFailoverCandidate({String? excludeId}) {
    final pool = _failoverPool().where((n) => n.id != excludeId).toList();
    if (pool.isEmpty) return null;
    final idx = _failoverCursor % pool.length;
    _failoverCursor = idx + 1;
    return pool[idx];
  }

  Future<bool> _probeProxy() async {
    final url = settings?.probeUrl ?? 'https://www.google.com/generate_204';
    final port = singboxRunner.mixedPort;
    final timeout = Duration(seconds: (settings?.failoverTimeoutSec ?? 3).clamp(1, 15));
    final retries = (settings?.failoverRetries ?? 1).clamp(0, 5);
    for (var i = 0; i <= retries; i++) {
      try {
        final client = HttpClient();
        client.connectionTimeout = timeout;
        client.findProxy = (_) => 'PROXY 127.0.0.1:$port';
        final req = await client.getUrl(Uri.parse(url));
        final resp = await req.close().timeout(timeout + const Duration(seconds: 2));
        await resp.drain<void>();
        client.close(force: true);
        if (resp.statusCode == 200 || resp.statusCode == 204) return true;
      } catch (_) {
        // retry
      }
    }
    return false;
  }

  Future<bool> _deviceHasNetwork() async {
    try {
      final result = await InternetAddress.lookup('223.5.5.5')
          .timeout(const Duration(seconds: 2));
      if (result.isNotEmpty) return true;
    } catch (_) {}
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse('https://www.baidu.com'));
      final resp = await req.close().timeout(const Duration(seconds: 4));
      await resp.drain<void>();
      client.close(force: true);
      return resp.statusCode >= 200 && resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// Lightweight reachability: TCP connect to node server:port.
  Future<bool> _preflightNode(ProxyNode node) async {
    if (node.server.isEmpty || node.port <= 0) return false;
    try {
      final socket = await Socket.connect(
        node.server,
        node.port,
        timeout: Duration(seconds: (settings?.failoverTimeoutSec ?? 3).clamp(1, 15)),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
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

  void _setState(SessionState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _stopHealthTimer();
    _logSub?.cancel();
    singboxRunner.stop();
    super.dispose();
  }
}
