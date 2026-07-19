import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin bridge to native TUN / system-proxy helpers.
///
/// Channel: `com.nexus/proxy`
/// Methods: startTunnel({config}), stopTunnel(), getStats(),
///          setSystemProxy({host,port}), clearSystemProxy()
///
/// Native side still accepts legacy method names `startVpn` / `stopVpn`
/// for compatibility with older platform builds.
class PlatformProxy {
  static const _channel = MethodChannel('com.nexus/proxy');
  // Legacy channel kept during transition so older platform shells still work.
  static const _legacyChannel = MethodChannel('com.nexusvpn/vpn');

  static bool get supportsNativeChannel =>
      !kIsWeb && (Platform.isWindows || Platform.isAndroid || Platform.isIOS);

  static Future<bool> startTunnel(String configJson) async {
    if (!supportsNativeChannel) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('startTunnel', {
        'config': configJson,
      });
      if (ok == true) return true;
    } on MissingPluginException {
      // fall through to legacy
    } on PlatformException catch (e) {
      throw Exception('平台隧道启动失败: ${e.message ?? e.code}');
    }
    try {
      final ok = await _legacyChannel.invokeMethod<bool>('startVpn', {
        'config': configJson,
      });
      return ok == true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      throw Exception('平台隧道启动失败: ${e.message ?? e.code}');
    }
  }

  static Future<void> stopTunnel() async {
    if (!supportsNativeChannel) return;
    try {
      await _channel.invokeMethod('stopTunnel');
      return;
    } on MissingPluginException {
      // legacy
    } on PlatformException {
      // ignore
    }
    try {
      await _legacyChannel.invokeMethod('stopVpn');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // Best-effort cleanup
    }
  }

  static Future<bool> setSystemProxy({
    required String host,
    required int port,
  }) async {
    if (kIsWeb) return false;
    for (final ch in [_channel, _legacyChannel]) {
      try {
        final ok = await ch.invokeMethod<bool>('setSystemProxy', {
          'host': host,
          'port': port,
        });
        if (ok == true) return true;
      } on MissingPluginException {
        continue;
      } on PlatformException {
        continue;
      }
    }
    if (Platform.isMacOS) return _setMacSystemProxy(host, port);
    if (Platform.isLinux) return _setLinuxSystemProxy(host, port);
    return false;
  }

  static Future<void> clearSystemProxy() async {
    if (kIsWeb) return;
    for (final ch in [_channel, _legacyChannel]) {
      try {
        await ch.invokeMethod('clearSystemProxy');
        return;
      } on MissingPluginException {
        continue;
      } on PlatformException {
        continue;
      }
    }
    if (Platform.isMacOS) {
      await _clearMacSystemProxy();
    } else if (Platform.isLinux) {
      await _clearLinuxSystemProxy();
    }
  }

  static Future<List<String>> _macNetworkServices() async {
    try {
      final result =
          await Process.run('networksetup', ['-listallnetworkservices']);
      if (result.exitCode != 0) return const [];
      return result.stdout
          .toString()
          .split('\n')
          .map((line) => line.trim())
          .where(
            (line) =>
                line.isNotEmpty &&
                !line.startsWith('An asterisk') &&
                !line.startsWith('*'),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> _setMacSystemProxy(String host, int port) async {
    final services = await _macNetworkServices();
    var changed = false;
    for (final service in services) {
      final commands = [
        ['-setwebproxy', service, host, '$port'],
        ['-setsecurewebproxy', service, host, '$port'],
        ['-setsocksfirewallproxy', service, host, '$port'],
      ];
      for (final args in commands) {
        final result = await Process.run('networksetup', args);
        changed = changed || result.exitCode == 0;
      }
    }
    return changed;
  }

  static Future<void> _clearMacSystemProxy() async {
    final services = await _macNetworkServices();
    for (final service in services) {
      for (final kind in [
        '-setwebproxystate',
        '-setsecurewebproxystate',
        '-setsocksfirewallproxystate',
      ]) {
        await Process.run('networksetup', [kind, service, 'off']);
      }
    }
  }

  static Future<bool> _setLinuxSystemProxy(String host, int port) async {
    try {
      final commands = [
        ['set', 'org.gnome.system.proxy.http', 'host', host],
        ['set', 'org.gnome.system.proxy.http', 'port', '$port'],
        ['set', 'org.gnome.system.proxy.https', 'host', host],
        ['set', 'org.gnome.system.proxy.https', 'port', '$port'],
        ['set', 'org.gnome.system.proxy.socks', 'host', host],
        ['set', 'org.gnome.system.proxy.socks', 'port', '$port'],
        ['set', 'org.gnome.system.proxy', 'mode', 'manual'],
      ];
      for (final args in commands) {
        final result = await Process.run('gsettings', args);
        if (result.exitCode != 0) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _clearLinuxSystemProxy() async {
    try {
      await Process.run(
        'gsettings',
        ['set', 'org.gnome.system.proxy', 'mode', 'none'],
      );
    } catch (_) {
      // Best-effort cleanup for non-GNOME desktops.
    }
  }
}
