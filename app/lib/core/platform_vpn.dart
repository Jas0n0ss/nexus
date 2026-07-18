import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin bridge to native VPN / system-proxy helpers.
///
/// Channel: `com.nexusvpn/vpn`
/// Methods: startVpn({config}), stopVpn(), getStats(), setSystemProxy({host,port}), clearSystemProxy()
class PlatformVpn {
  static const _channel = MethodChannel('com.nexusvpn/vpn');

  static bool get supportsNativeChannel =>
      !kIsWeb && (Platform.isWindows || Platform.isAndroid || Platform.isIOS);

  /// Start native VPN / TUN path with a full sing-box JSON string.
  /// Returns true when the platform handled start; false when unsupported
  /// (caller should fall back to spawning sing-box itself).
  static Future<bool> startVpn(String configJson) async {
    if (!supportsNativeChannel) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('startVpn', {
        'config': configJson,
      });
      return ok == true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      throw Exception('平台 VPN 启动失败: ${e.message ?? e.code}');
    }
  }

  static Future<void> stopVpn() async {
    if (!supportsNativeChannel) return;
    try {
      await _channel.invokeMethod('stopVpn');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // Best-effort cleanup
    }
  }

  /// Windows / desktop: set OS HTTP(S) proxy to mixed inbound.
  static Future<bool> setSystemProxy({
    required String host,
    required int port,
  }) async {
    if (kIsWeb || !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('setSystemProxy', {
        'host': host,
        'port': port,
      });
      return ok == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> clearSystemProxy() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('clearSystemProxy');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }
}
