import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/proxy_node.dart';
import '../providers/settings_provider.dart';
import 'config_generator.dart';
import 'core_locator.dart';
import 'platform_proxy.dart';

class CoreStats {
  final double uploadMbps;
  final double downloadMbps;
  final int latencyMs;
  CoreStats({
    required this.uploadMbps,
    required this.downloadMbps,
    required this.latencyMs,
  });
}

class SingboxRunner {
  Process? _process;
  StreamController<String>? _logStream;
  Timer? _exitWatcher;
  bool _usingNative = false;
  bool _usingSystemProxy = false;
  String? _configPath;
  int _mixedPort = 7890;

  // traffic sampling
  int _lastUp = 0;
  int _lastDown = 0;
  DateTime? _lastTrafficAt;

  Stream<String> get logs => _logStream?.stream ?? const Stream.empty();
  bool get isRunning => _process != null || _usingNative;
  String? get configPath => _configPath;
  int get mixedPort => _mixedPort;

  /// Start sing-box with settings-aware config. Throws if core cannot run.
  Future<void> start(ProxyNode node, {SettingsProvider? settings}) async {
    await stop();
    _logStream = StreamController.broadcast();
    _mixedPort = settings?.mixedPort ?? 7890;

    if (node.server.isEmpty) {
      throw Exception('节点服务器地址为空，无法连接');
    }

    final tmpDir = await getTemporaryDirectory();
    final cachePath = '${tmpDir.path}/nexus-cache.db';
    var wantTun = settings?.tunMode ?? true;
    final config = ConfigGenerator.generate(
      node,
      settings: settings,
      cachePath: cachePath,
    );
    final configJson = const JsonEncoder.withIndent('  ').convert(config);

    final configFile = File('${tmpDir.path}/nexus-singbox.json');
    await configFile.writeAsString(configJson);
    _configPath = configFile.path;
    _logStream?.add('[INFO] 配置已写入 ${_configPath}');

    // Prefer native tunnel channel (Windows WinTUN / Android VpnService)
    if (PlatformProxy.supportsNativeChannel) {
      try {
        final ok = await PlatformProxy.startTunnel(configJson);
        if (ok) {
          _usingNative = true;
          _logStream?.add('[OK] 已通过平台隧道通道启动');
          _watchNative();
          return;
        }
        _logStream?.add('[INFO] 平台通道未接管，回退到本地 sing-box 进程');
      } catch (e) {
        _logStream?.add('[WARN] 平台隧道: $e — 尝试本地进程');
      }
    }

    final binary = await CoreLocator().resolve();
    if (binary == null) {
      final msg = '未找到 sing-box 核心。请运行 app/scripts/fetch_singbox.sh '
          '下载内核，或确认安装包内含 cores/sing-box。'
          '配置已生成: ${_configPath}';
      _logStream?.add('[ERR] $msg');
      // Only allow fake simulator in explicit debug + flag
      if (kDebugMode &&
          const bool.fromEnvironment('NEXUS_ALLOW_SIMULATOR',
              defaultValue: false)) {
        _logStream?.add('[WARN] 调试模拟器模式已启用（流量不会真正代理）');
        return;
      }
      throw Exception(msg);
    }

    final startupErrors = <String>[];
    Future<int> launchCore() async {
      startupErrors.clear();
      _logStream?.add('[INFO] 启动核心: $binary');
      final process = await Process.start(
        binary,
        ['run', '-c', configFile.path],
        runInShell: false,
        workingDirectory: File(binary).parent.path,
      );
      _process = process;

      process.stdout.transform(utf8.decoder).listen((line) {
        for (final l in line.split('\n')) {
          final t = l.trim();
          if (t.isNotEmpty) _logStream?.add(t);
        }
      });
      process.stderr.transform(utf8.decoder).listen((line) {
        for (final l in line.split('\n')) {
          final t = l.trim();
          if (t.isNotEmpty) {
            startupErrors.add(t);
            _logStream?.add('[ERR] $t');
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 450));
      return process.exitCode.timeout(
        const Duration(milliseconds: 80),
        onTimeout: () => -999,
      );
    }

    var exitCode = await launchCore();
    final desktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (exitCode != -999 && wantTun && desktop) {
      _process = null;
      wantTun = false;
      _logStream?.add(
        '[WARN] TUN 启动失败，自动切换到系统代理模式（无需管理员权限）',
      );
      final fallback = ConfigGenerator.generate(
        node,
        settings: settings,
        tunMode: false,
        cachePath: cachePath,
      );
      await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(fallback),
      );
      exitCode = await launchCore();
    }

    if (exitCode != -999) {
      _process = null;
      final detail = startupErrors.isEmpty ? '无错误输出' : startupErrors.last;
      throw Exception(
        'sing-box 启动后立即退出 (code=$exitCode)：$detail',
      );
    }

    _exitWatcher = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_process == null) return;
      try {
        final code = await _process!.exitCode.timeout(
          const Duration(milliseconds: 20),
          onTimeout: () => -999,
        );
        if (code != -999) {
          _logStream?.add('[ERR] sing-box 进程已退出 (code=$code)');
          _process = null;
        }
      } catch (_) {}
    });

    // Desktop system proxy when TUN is off
    final wantSysProxy = settings?.systemProxy ?? true;
    if (!wantTun &&
        wantSysProxy &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final ok = await PlatformProxy.setSystemProxy(
        host: '127.0.0.1',
        port: _mixedPort,
      );
      _usingSystemProxy = ok;
      if (ok) {
        _logStream?.add('[OK] 系统代理 → 127.0.0.1:$_mixedPort');
      } else if (Platform.isWindows) {
        // Fallback: WinINET via netsh (best-effort)
        try {
          await Process.run('netsh', [
            'winhttp',
            'set',
            'proxy',
            'proxy-server=127.0.0.1:$_mixedPort',
          ]);
          _usingSystemProxy = true;
          _logStream?.add('[OK] netsh 系统代理已设置');
        } catch (e) {
          _logStream?.add('[WARN] 系统代理设置失败: $e（可手动指向 127.0.0.1:$_mixedPort）');
        }
      } else {
        _logStream?.add('[WARN] 未能自动设置系统代理，请手动使用 127.0.0.1:$_mixedPort');
      }
    }

    _logStream?.add(
        '[OK] 已连接 ${node.name}（mixed=$_mixedPort，TUN=${wantTun ? "开" : "关"}，路由=${settings?.routeMode.name ?? "rule"}）');
  }

  Future<void> stop() async {
    _exitWatcher?.cancel();
    _exitWatcher = null;

    if (_usingNative) {
      await PlatformProxy.stopTunnel();
      _usingNative = false;
    }

    if (_usingSystemProxy) {
      await PlatformProxy.clearSystemProxy();
      if (Platform.isWindows) {
        try {
          await Process.run('netsh', ['winhttp', 'reset', 'proxy']);
        } catch (_) {}
      }
      _usingSystemProxy = false;
    }

    final p = _process;
    _process = null;
    if (p != null) {
      p.kill();
      try {
        await p.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        p.kill(ProcessSignal.sigkill);
      }
    }

    await _logStream?.close();
    _logStream = null;
    _lastUp = 0;
    _lastDown = 0;
    _lastTrafficAt = null;
  }

  Future<CoreStats> getStats() async {
    try {
      final resp = await http
          .get(Uri.parse('http://127.0.0.1:9090/traffic'))
          .timeout(const Duration(milliseconds: 800));
      if (resp.statusCode == 200) {
        // Clash API streams NDJSON; take last complete object if possible
        final lines = resp.body.trim().split('\n').where((l) => l.isNotEmpty);
        if (lines.isNotEmpty) {
          final json = jsonDecode(lines.last) as Map<String, dynamic>;
          final up = (json['up'] as num?)?.toInt() ?? 0;
          final down = (json['down'] as num?)?.toInt() ?? 0;
          final now = DateTime.now();
          double upMbps = 0, downMbps = 0;
          if (_lastTrafficAt != null) {
            final dt = now.difference(_lastTrafficAt!).inMilliseconds / 1000.0;
            if (dt > 0) {
              upMbps = ((up - _lastUp).clamp(0, 1 << 30) * 8 / dt) / 1e6;
              downMbps = ((down - _lastDown).clamp(0, 1 << 30) * 8 / dt) / 1e6;
            }
          }
          _lastUp = up;
          _lastDown = down;
          _lastTrafficAt = now;
          return CoreStats(
            uploadMbps: upMbps,
            downloadMbps: downMbps,
            latencyMs: await _probeLatency(),
          );
        }
      }
    } catch (_) {
      // Clash API may stream forever; ignore and return zeros
    }
    return CoreStats(
        uploadMbps: 0, downloadMbps: 0, latencyMs: await _probeLatency());
  }

  Future<int> _probeLatency() async {
    try {
      final sw = Stopwatch()..start();
      final client = HttpClient();
      client.findProxy = (_) => 'PROXY 127.0.0.1:$_mixedPort';
      client.connectionTimeout = const Duration(seconds: 3);
      final req = await client
          .getUrl(Uri.parse('http://cp.cloudflare.com/generate_204'));
      final resp = await req.close().timeout(const Duration(seconds: 3));
      await resp.drain<void>();
      client.close(force: true);
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return 0;
    }
  }

  void _watchNative() {
    // Native path has no Process handle; stats still come from Clash API.
  }
}
