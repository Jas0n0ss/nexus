import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/proxy_node.dart';
import 'config_generator.dart';

class CoreStats {
  final double uploadMbps;
  final double downloadMbps;
  final int latencyMs;
  CoreStats({required this.uploadMbps, required this.downloadMbps, required this.latencyMs});
}

class SingboxRunner {
  Process? _process;
  StreamController<String>? _logStream;
  Timer? _fakeTicker; // Used when binary not available (simulator mode)
  double _fakeUp = 0, _fakeDown = 0;

  Stream<String> get logs => _logStream?.stream ?? const Stream.empty();

  /// Start the sing-box core process with config generated from [node].
  Future<void> start(ProxyNode node) async {
    await stop();
    _logStream = StreamController.broadcast();

    // Generate sing-box config
    final config = ConfigGenerator.generate(node);
    final configJson = jsonEncode(config);

    // Write config to temp file
    final tmpDir = await getTemporaryDirectory();
    final configFile = File('${tmpDir.path}/nexus-singbox.json');
    await configFile.writeAsString(configJson);

    // Try to find sing-box binary
    final binary = await _findBinary();

    if (binary != null) {
      // Real mode: spawn the process
      _process = await Process.start(binary, ['run', '-c', configFile.path],
        runInShell: false);

      _process!.stdout.transform(utf8.decoder).listen((line) {
        _logStream?.add(line.trim());
      });
      _process!.stderr.transform(utf8.decoder).listen((line) {
        _logStream?.add('[ERR] ${line.trim()}');
      });
    } else {
      // Simulator mode: pretend to be connected (for UI demo / CI)
      _logStream?.add('[INFO] sing-box binary not found — running in simulator mode');
      _logStream?.add('[INFO] Config written to ${configFile.path}');
      _logStream?.add('[OK] Simulator: connected to ${node.name}');
      _startSimulator();
    }
  }

  Future<void> stop() async {
    _fakeTicker?.cancel();
    _process?.kill();
    _process = null;
    await _logStream?.close();
    _logStream = null;
  }

  Future<CoreStats> getStats() async {
    if (_process != null) {
      // In production: query Clash API /traffic endpoint
      // GET http://127.0.0.1:9090/traffic
      return CoreStats(
        uploadMbps: _fakeUp,
        downloadMbps: _fakeDown,
        latencyMs: 40 + (DateTime.now().millisecondsSinceEpoch % 60),
      );
    }
    return CoreStats(uploadMbps: _fakeUp, downloadMbps: _fakeDown,
      latencyMs: 40 + (DateTime.now().millisecondsSinceEpoch % 60));
  }

  void _startSimulator() {
    _fakeTicker = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _fakeUp   = 0.5 + (DateTime.now().millisecondsSinceEpoch % 100) / 20.0;
      _fakeDown = 2.0 + (DateTime.now().millisecondsSinceEpoch % 500) / 25.0;
    });
  }

  Future<String?> _findBinary() async {
    // Search standard locations for sing-box binary
    final candidates = [
      // macOS
      '/usr/local/bin/sing-box',
      '/opt/homebrew/bin/sing-box',
      // Linux
      '/usr/bin/sing-box',
      // bundled in app
      '${(await getApplicationSupportDirectory()).path}/cores/sing-box',
      // Windows
      r'C:\Program Files\sing-box\sing-box.exe',
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    return null;
  }
}
