import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Locates (and if needed extracts) the bundled sing-box binary.
///
/// Search order:
/// 1. Sidecar next to the app executable / `cores/`
/// 2. Platform-specific install paths (Homebrew, deb layout, …)
/// 3. Flutter asset tree inside the app bundle (macOS Frameworks path)
/// 4. Extract `assets/cores/sing-box` from the asset bundle into
///    Application Support (works for `flutter run` and sandboxed macOS)
class CoreLocator {
  CoreLocator({
    this.assetLoader,
    this.exists,
    this.writeExecutable,
  });

  /// Override for tests. Defaults to [rootBundle.load].
  final Future<ByteData> Function(String key)? assetLoader;

  /// Override for tests. Defaults to [File.exists].
  final Future<bool> Function(String path)? exists;

  /// Override for tests. Defaults to write bytes + chmod +x.
  final Future<void> Function(String path, List<int> bytes)? writeExecutable;

  static String get exeName => Platform.isWindows ? 'sing-box.exe' : 'sing-box';

  static String get assetKey => 'assets/cores/$exeName';

  /// Pure path candidates — unit-testable without touching disk.
  static List<String> candidatePaths({
    required String exeName,
    required String exeDir,
    required String supportDir,
    required bool isMacOS,
    required bool isLinux,
    required bool isWindows,
    required bool isAndroid,
  }) {
    final sep = isWindows ? r'\' : '/';
    String join(String a, String b) {
      if (a.endsWith(r'\') || a.endsWith('/')) return '$a$b';
      return '$a$sep$b';
    }

    final paths = <String>[
      join(exeDir, exeName),
      join(exeDir, 'cores$sep$exeName'),
      join(supportDir, 'cores$sep$exeName'),
      join(exeDir,
          'data${sep}flutter_assets${sep}assets${sep}cores$sep$exeName'),
    ];

    if (isMacOS) {
      // Flutter macOS: executable is Contents/MacOS/<name>
      final contents = Directory(exeDir).parent.path; // …/Contents
      paths.addAll([
        join(contents, 'Resources/cores/$exeName'),
        join(
          contents,
          'Frameworks/App.framework/Resources/flutter_assets/assets/cores/$exeName',
        ),
        '/usr/local/bin/sing-box',
        '/opt/homebrew/bin/sing-box',
      ]);
    }

    if (isLinux) {
      paths.addAll([
        '/usr/bin/sing-box',
        '/usr/lib/nexus/data/flutter_assets/assets/cores/sing-box',
      ]);
    }

    if (isWindows) {
      paths.add(r'C:\Program Files\sing-box\sing-box.exe');
    }

    if (isAndroid) {
      // Native VpnService extracts to filesDir/sing-box (no cores/ subdir).
      paths.addAll([
        join(supportDir, 'sing-box'),
        join(supportDir, 'cores/sing-box'),
        '/data/data/com.nexusvpn.nexus/files/sing-box',
        '/data/data/com.nexusvpn.nexus/files/cores/sing-box',
      ]);
    }

    return paths;
  }

  Future<bool> _exists(String path) async {
    if (exists != null) return exists!(path);
    return File(path).exists();
  }

  Future<void> _writeExecutable(String path, List<int> bytes) async {
    if (writeExecutable != null) {
      await writeExecutable!(path, bytes);
      return;
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['+x', path]);
      } catch (_) {
        // Best-effort; some environments lack chmod.
      }
    }
  }

  Future<ByteData?> _loadAsset(String key) async {
    try {
      if (assetLoader != null) return await assetLoader!(key);
      return await rootBundle.load(key);
    } catch (e) {
      debugPrint('CoreLocator: asset $key missing: $e');
      return null;
    }
  }

  /// Returns an absolute path to a runnable sing-box binary, or null.
  Future<String?> resolve() async {
    final name = exeName;
    final support = (await getApplicationSupportDirectory()).path;
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    final candidates = candidatePaths(
      exeName: name,
      exeDir: exeDir,
      supportDir: support,
      isMacOS: Platform.isMacOS,
      isLinux: Platform.isLinux,
      isWindows: Platform.isWindows,
      isAndroid: Platform.isAndroid,
    );

    for (final path in candidates) {
      if (await _exists(path)) {
        await _ensureExecutableBit(path);
        return path;
      }
    }

    // Extract from Flutter assets into Application Support (persistent).
    final dest = '$support/cores/$name';
    final extracted = await extractAssetTo(dest);
    if (extracted != null) return extracted;

    return null;
  }

  /// Extract [assetKey] to [destPath]. Returns path on success.
  Future<String?> extractAssetTo(String destPath) async {
    final data = await _loadAsset(assetKey);
    if (data == null) return null;
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (bytes.isEmpty) return null;

    // Skip rewrite if same size already present (cheap cache).
    final existing = File(destPath);
    if (await existing.exists()) {
      final len = await existing.length();
      if (len == bytes.length) {
        await _ensureExecutableBit(destPath);
        return destPath;
      }
    }

    await _writeExecutable(destPath, bytes);
    if (await _exists(destPath)) return destPath;
    return null;
  }

  Future<void> _ensureExecutableBit(String path) async {
    if (Platform.isWindows) return;
    try {
      final result = await Process.run('chmod', ['+x', path]);
      if (result.exitCode != 0) {
        debugPrint('CoreLocator: chmod failed for $path: ${result.stderr}');
      }
    } catch (_) {}
  }
}
