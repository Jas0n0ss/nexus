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

  // Passwall-like extras
  bool systemProxy = true;       // set OS proxy when TUN off (desktop)
  bool allowLan = false;         // listen 0.0.0.0 for LAN devices
  bool blockAds = true;          // geosite ads → block
  bool sniffOverride = true;     // sniff_override_destination
  bool preferIpv4 = true;
  int mixedPort = 7890;
  String? lastSubscriptionUrl;

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
    systemProxy        = p.getBool('systemProxy') ?? true;
    allowLan           = p.getBool('allowLan') ?? false;
    blockAds           = p.getBool('blockAds') ?? true;
    sniffOverride      = p.getBool('sniffOverride') ?? true;
    preferIpv4         = p.getBool('preferIpv4') ?? true;
    mixedPort          = p.getInt('mixedPort') ?? 7890;
    lastSubscriptionUrl = p.getString('lastSub');
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
    await p.setBool('systemProxy', systemProxy);
    await p.setBool('allowLan', allowLan);
    await p.setBool('blockAds', blockAds);
    await p.setBool('sniffOverride', sniffOverride);
    await p.setBool('preferIpv4', preferIpv4);
    await p.setInt('mixedPort', mixedPort);
    if (lastSubscriptionUrl != null) {
      await p.setString('lastSub', lastSubscriptionUrl!);
    }
  }

  void set(void Function(SettingsProvider s) fn) {
    fn(this);
    save();
    notifyListeners();
  }
}
