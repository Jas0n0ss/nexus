import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/proxy_node.dart';

class ParsedResult {
  final List<ProxyNode> nodes;
  final List<String> errors;
  final String? detectedSource;
  ParsedResult({required this.nodes, required this.errors, this.detectedSource});
}

class NodeParser {
  Future<ParsedResult> parse(String input) async {
    final trimmed = input.trim();

    // HTTP subscription URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _fetchAndParse(trimmed);
    }

    // Multi-line URIs
    final lines = trimmed.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.every((l) => l.contains('://'))) {
      return _parseUriLines(lines);
    }

    // Base64 blob
    try {
      final decoded = utf8.decode(base64Decode(trimmed.replaceAll('\n', '')));
      return parse(decoded);
    } catch (_) {}

    // Try as JSON (sing-box full config)
    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      return _parseSingboxJson(json);
    } catch (_) {}

    return ParsedResult(nodes: [], errors: ['无法识别输入格式'], detectedSource: null);
  }

  Future<ParsedResult> _fetchAndParse(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        return ParsedResult(nodes: [], errors: ['HTTP ${resp.statusCode}'], detectedSource: null);
      }
      final source = _detectSource(url, resp.body);
      final result = await parse(resp.body);
      return ParsedResult(nodes: result.nodes, errors: result.errors, detectedSource: source);
    } catch (e) {
      return ParsedResult(nodes: [], errors: ['请求失败: $e'], detectedSource: null);
    }
  }

  ParsedResult _parseUriLines(List<String> lines) {
    final nodes = <ProxyNode>[];
    final errors = <String>[];
    for (final line in lines) {
      try { nodes.add(_parseUri(line)); }
      catch (e) { errors.add('$line → $e'); }
    }
    return ParsedResult(nodes: nodes, errors: errors, detectedSource: 'URI 分享');
  }

  ParsedResult _parseSingboxJson(Map<String, dynamic> json) {
    final outbounds = (json['outbounds'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final nodes = <ProxyNode>[];
    final errors = <String>[];
    for (final ob in outbounds) {
      final type = ob['type'] as String? ?? '';
      if (['direct','block','dns','selector','urltest'].contains(type)) continue;
      try { nodes.add(_singboxOutboundToNode(ob)); }
      catch (e) { errors.add('outbound[${ob['tag']}]: $e'); }
    }
    return ParsedResult(nodes: nodes, errors: errors, detectedSource: 'sing-box 配置');
  }

  ProxyNode _parseUri(String uri) {
    final scheme = uri.split('://').first.toLowerCase();
    switch (scheme) {
      case 'vmess':     return _vmess(uri);
      case 'vless':     return _vless(uri);
      case 'trojan':    return _trojan(uri);
      case 'ss':        return _ss(uri);
      case 'hysteria2':
      case 'hy2':       return _hysteria2(uri);
      case 'tuic':      return _tuic(uri);
      case 'wg':
      case 'wireguard': return _wireguard(uri);
      default: throw Exception('不支持的协议: $scheme');
    }
  }

  ProxyNode _vmess(String uri) {
    final b64 = uri.substring('vmess://'.length);
    final json = jsonDecode(utf8.decode(base64Decode(b64))) as Map<String, dynamic>;
    return ProxyNode(
      id: _uuid(),
      name: json['ps'] ?? json['add'] ?? '未命名',
      flag: _flagFromName(json['ps'] ?? ''),
      group: _groupFromName(json['ps'] ?? ''),
      protocol: Protocol.vmess,
      server: json['add'] ?? '',
      port: int.tryParse(json['port'].toString()) ?? 443,
      uuid: json['id'],
      alterId: int.tryParse(json['aid'].toString()) ?? 0,
      transport: _mapTransport(json['net']),
      path: json['path'],
      host: json['host'],
      security: json['tls'] == 'tls' ? Security.tls : Security.none,
      sni: json['sni'] ?? json['host'],
      alpn: json['alpn'] != null ? (json['alpn'] as String).split(',') : null,
      source: NodeSource.unknown,
      rawUri: uri,
    );
  }

  ProxyNode _vless(String uri) {
    final u = Uri.parse(uri.replaceFirst('vless://', 'https://'));
    final p = u.queryParameters;
    final sec = p['security'] == 'reality' ? Security.reality
      : p['security'] == 'tls' ? Security.tls : Security.none;
    return ProxyNode(
      id: _uuid(), name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: _flagFromName(u.fragment), group: _groupFromName(u.fragment),
      protocol: Protocol.vless, server: u.host, port: u.port,
      uuid: u.userInfo,
      transport: _mapTransport(p['type']),
      path: p['path'] ?? p['serviceName'],
      host: p['host'],
      serviceName: p['serviceName'],
      security: sec,
      sni: p['sni'], alpn: p['alpn']?.split(','),
      fingerprint: p['fp'],
      publicKey: p['pbk'], shortId: p['sid'],
      source: NodeSource.unknown, rawUri: uri,
    );
  }

  ProxyNode _trojan(String uri) {
    final u = Uri.parse(uri.replaceFirst('trojan://', 'https://'));
    final p = u.queryParameters;
    return ProxyNode(
      id: _uuid(), name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: _flagFromName(u.fragment), group: _groupFromName(u.fragment),
      protocol: Protocol.trojan, server: u.host, port: u.port > 0 ? u.port : 443,
      password: u.userInfo,
      transport: _mapTransport(p['type']),
      path: p['path'] ?? p['serviceName'], serviceName: p['serviceName'],
      security: Security.tls, sni: p['sni'] ?? u.host,
      alpn: p['alpn']?.split(','), fingerprint: p['fp'],
      source: NodeSource.unknown, rawUri: uri,
    );
  }

  ProxyNode _ss(String uri) {
    final withoutScheme = uri.substring('ss://'.length);
    final hashIdx = withoutScheme.indexOf('#');
    final name = hashIdx >= 0 ? Uri.decodeComponent(withoutScheme.substring(hashIdx + 1)) : '';
    final main = hashIdx >= 0 ? withoutScheme.substring(0, hashIdx) : withoutScheme;
    String method, password, server; int port;
    if (main.contains('@')) {
      final atIdx = main.lastIndexOf('@');
      final creds = utf8.decode(base64Decode(main.substring(0, atIdx)));
      final colonIdx = creds.indexOf(':');
      method = creds.substring(0, colonIdx); password = creds.substring(colonIdx + 1);
      final hostPort = main.substring(atIdx + 1).split(':');
      server = hostPort[0]; port = int.parse(hostPort[1]);
    } else {
      final decoded = utf8.decode(base64Decode(main));
      final match = RegExp(r'^(.+?):(.+)@(.+):(\d+)$').firstMatch(decoded)!;
      method = match[1]!; password = match[2]!; server = match[3]!; port = int.parse(match[4]!);
    }
    return ProxyNode(
      id: _uuid(), name: name.isEmpty ? server : name,
      flag: _flagFromName(name), group: _groupFromName(name),
      protocol: Protocol.shadowsocks, server: server, port: port,
      method: method, password: password,
      transport: Transport.tcp, security: Security.none,
      source: NodeSource.unknown, rawUri: uri,
    );
  }

  ProxyNode _hysteria2(String uri) {
    final u = Uri.parse(uri.replaceFirst(RegExp(r'^(hysteria2|hy2)://'), 'https://'));
    final p = u.queryParameters;
    return ProxyNode(
      id: _uuid(), name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: _flagFromName(u.fragment), group: _groupFromName(u.fragment),
      protocol: Protocol.hysteria2, server: u.host, port: u.port > 0 ? u.port : 443,
      password: u.userInfo, transport: Transport.quic, security: Security.tls,
      sni: p['sni'], obfs: p['obfs'], obfsPassword: p['obfs-password'],
      source: NodeSource.unknown, rawUri: uri,
    );
  }

  ProxyNode _tuic(String uri) {
    final u = Uri.parse(uri.replaceFirst('tuic://', 'https://'));
    final p = u.queryParameters;
    return ProxyNode(
      id: _uuid(), name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: _flagFromName(u.fragment), group: _groupFromName(u.fragment),
      protocol: Protocol.tuic, server: u.host, port: u.port,
      uuid: u.userInfo, password: u.password,
      transport: Transport.quic, security: Security.tls,
      sni: p['sni'], alpn: p['alpn']?.split(','),
      congestion: p['congestion_control'] ?? 'bbr',
      source: NodeSource.unknown, rawUri: uri,
    );
  }

  ProxyNode _wireguard(String uri) {
    final u = Uri.parse(uri.replaceFirst(RegExp(r'^(wg|wireguard)://'), 'https://'));
    final p = u.queryParameters;
    return ProxyNode(
      id: _uuid(), name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: '🌐', group: 'WireGuard',
      protocol: Protocol.wireguard, server: u.host, port: u.port > 0 ? u.port : 51820,
      privateKey: u.userInfo, publicKeyWG: p['pub'],
      allowedIPs: p['allowed']?.split(',') ?? ['0.0.0.0/0', '::/0'],
      dns: p['dns'] ?? '1.1.1.1',
      transport: Transport.none, security: Security.none,
      source: NodeSource.unknown, rawUri: uri,
    );
  }

  ProxyNode _singboxOutboundToNode(Map<String, dynamic> ob) {
    final tls = (ob['tls'] as Map?)?.cast<String, dynamic>() ?? {};
    final tp  = (ob['transport'] as Map?)?.cast<String, dynamic>() ?? {};
    final isReality = tls['reality']?['enabled'] == true;
    final sec = tls['enabled'] == true ? (isReality ? Security.reality : Security.tls) : Security.none;
    return ProxyNode(
      id: _uuid(), name: ob['tag'] ?? '未命名',
      flag: _flagFromName(ob['tag'] ?? ''), group: _groupFromName(ob['tag'] ?? ''),
      protocol: Protocol.values.firstWhere((p) => p.name == ob['type'], orElse: () => Protocol.vless),
      server: ob['server'] ?? '', port: ob['server_port'] ?? 443,
      uuid: ob['uuid'], password: ob['password'],
      method: ob['method'], alterId: ob['alter_id'],
      transport: _mapTransport(tp['type']),
      path: tp['path'] ?? tp['service_name'], serviceName: tp['service_name'],
      security: sec, sni: tls['server_name'],
      alpn: (tls['alpn'] as List?)?.cast<String>(),
      fingerprint: tls['utls']?['fingerprint'],
      publicKey: tls['reality']?['public_key'], shortId: tls['reality']?['short_id'],
      obfs: (ob['obfs'] as Map?)?['type'],
      obfsPassword: (ob['obfs'] as Map?)?['password'],
      congestion: ob['congestion_control'],
      source: NodeSource.sub233boySingbox,
    );
  }

  Transport _mapTransport(String? t) {
    switch (t?.toLowerCase()) {
      case 'ws':
      case 'websocket': return Transport.ws;
      case 'grpc':      return Transport.grpc;
      case 'http':      return Transport.http;
      case 'quic':      return Transport.quic;
      default:          return Transport.tcp;
    }
  }

  String _detectSource(String url, String body) {
    final s = '${url.toLowerCase()} ${body.toLowerCase()}';
    if (s.contains('233boy') && s.contains('sing-box')) return '233boy/sing-box';
    if (s.contains('233boy') && s.contains('xray'))     return '233boy/Xray';
    if (s.contains('v2ray-agent') || s.contains('mack-a')) return 'mack-a/v2ray-agent';
    if (s.contains('sing-box-yg') || s.contains('yonggekkk')) return 'yonggekkk/sing-box-yg';
    return '通用格式';
  }

  static int _counter = 0;
  String _uuid() => 'node-${DateTime.now().millisecondsSinceEpoch}-${_counter++}';

  // Simple heuristics to extract flag emoji and group name from node name
  static const _countryFlags = {
    '日本': '🇯🇵', 'japan': '🇯🇵', 'jp': '🇯🇵', 'tokyo': '🇯🇵', 'osaka': '🇯🇵',
    '美国': '🇺🇸', 'usa': '🇺🇸', 'us': '🇺🇸', 'angeles': '🇺🇸', 'york': '🇺🇸',
    '香港': '🇭🇰', 'hk': '🇭🇰', 'hong kong': '🇭🇰',
    '新加坡': '🇸🇬', 'sg': '🇸🇬', 'singapore': '🇸🇬',
    '台湾': '🇹🇼', 'tw': '🇹🇼', 'taiwan': '🇹🇼',
    '韩国': '🇰🇷', 'kr': '🇰🇷', 'korea': '🇰🇷', 'seoul': '🇰🇷',
    '德国': '🇩🇪', 'de': '🇩🇪', 'germany': '🇩🇪', 'frankfurt': '🇩🇪',
    '英国': '🇬🇧', 'uk': '🇬🇧', 'london': '🇬🇧',
    '法国': '🇫🇷', 'fr': '🇫🇷', 'paris': '🇫🇷',
    '澳大利亚': '🇦🇺', 'au': '🇦🇺', 'sydney': '🇦🇺',
  };
  static const _regionGroups = {
    '亚太': ['日本','香港','新加坡','台湾','韩国','澳大利亚','jp','hk','sg','tw','kr','au','tokyo','osaka','seoul','singapore','taiwan'],
    '北美': ['美国','us','usa','angeles','york'],
    '欧洲': ['德国','英国','法国','de','uk','fr','frankfurt','london','paris'],
  };

  String _flagFromName(String name) {
    final lower = name.toLowerCase();
    for (final e in _countryFlags.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return '🌐';
  }

  String _groupFromName(String name) {
    final lower = name.toLowerCase();
    for (final e in _regionGroups.entries) {
      if (e.value.any((k) => lower.contains(k))) return e.key;
    }
    return '其他';
  }
}
