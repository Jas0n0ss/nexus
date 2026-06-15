import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CoreEngine { singbox, xray, v2ray }
enum RouteMode  { rule, global, direct }

class SettingsProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  CoreEngine coreEngine = CoreEngine.singbox;
  RouteMode routeMode = RouteMode.rule;
  bool tunMode = true;
  bool dnsLeakProtection = true;
  bool mux = false;
  bool autoReconnect = true;
  bool autofix = true;
  bool postConnectTest = true;
  bool crashAutoRestart = true;
  String remoteDns = 'https://1.1.1.1/dns-query';

  SettingsProvider() { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    themeMode      = ThemeMode.values[p.getInt('themeMode') ?? 1];
    coreEngine     = CoreEngine.values[p.getInt('core') ?? 0];
    routeMode      = RouteMode.values[p.getInt('route') ?? 0];
    tunMode            = p.getBool('tun') ?? true;
    dnsLeakProtection  = p.getBool('dnsLeak') ?? true;
    mux                = p.getBool('mux') ?? false;
    autoReconnect      = p.getBool('autoReconnect') ?? true;
    autofix            = p.getBool('autofix') ?? true;
    postConnectTest    = p.getBool('postTest') ?? true;
    crashAutoRestart   = p.getBool('crashRestart') ?? true;
    remoteDns          = p.getString('dns') ?? 'https://1.1.1.1/dns-query';
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('themeMode', themeMode.index);
    await p.setInt('core', coreEngine.index);
    await p.setInt('route', routeMode.index);
    await p.setBool('tun', tunMode);
    await p.setBool('dnsLeak', dnsLeakProtection);
    await p.setBool('mux', mux);
    await p.setBool('autoReconnect', autoReconnect);
    await p.setBool('autofix', autofix);
    await p.setBool('postTest', postConnectTest);
    await p.setBool('crashRestart', crashAutoRestart);
    await p.setString('dns', remoteDns);
  }

  void set(void Function(SettingsProvider s) fn) {
    fn(this);
    save();
    notifyListeners();
  }
}
