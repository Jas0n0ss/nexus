import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

import '../models/proxy_node.dart';

class ParsedResult {
  final List<ProxyNode> nodes;
  final List<String> errors;
  final String? detectedSource;
  ParsedResult(
      {required this.nodes, required this.errors, this.detectedSource});

  bool get hasNodes => nodes.isNotEmpty;
}

class NodeParser {
  Future<ParsedResult> parse(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return ParsedResult(nodes: [], errors: ['输入为空'], detectedSource: null);
    }

    // Local file path (file picker writes file://...)
    if (trimmed.startsWith('file://') || _looksLikeLocalPath(trimmed)) {
      return _parseLocalFile(trimmed);
    }

    // HTTP subscription URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _fetchAndParse(trimmed);
    }

    return _parseContent(trimmed);
  }

  Future<ParsedResult> _parseLocalFile(String pathOrUri) async {
    try {
      final path = pathOrUri.startsWith('file://')
          ? Uri.parse(pathOrUri).toFilePath()
          : pathOrUri;
      final file = File(path);
      if (!await file.exists()) {
        return ParsedResult(
            nodes: [], errors: ['文件不存在: $path'], detectedSource: null);
      }
      final content = await file.readAsString();
      final result = await _parseContent(content);
      return ParsedResult(
        nodes: result.nodes,
        errors: result.errors,
        detectedSource: result.detectedSource ?? '本地文件',
      );
    } catch (e) {
      return ParsedResult(
          nodes: [], errors: ['读取文件失败: $e'], detectedSource: null);
    }
  }

  Future<ParsedResult> _parseContent(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return ParsedResult(nodes: [], errors: ['内容为空'], detectedSource: null);
    }

    // Clash / Meta YAML
    if (_looksLikeClashYaml(trimmed)) {
      final clash = _parseClashYaml(trimmed);
      if (clash.hasNodes || clash.errors.isNotEmpty) return clash;
    }

    // URI share lines (allow non-URI comments / blank lines)
    final uriLines = trimmed
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#') && l.contains('://'))
        .where((l) => !_isHttpUrl(l))
        .toList();
    if (uriLines.isNotEmpty) {
      final uriResult = _parseUriLines(uriLines);
      if (uriResult.hasNodes) return uriResult;
    }

    // Base64 subscription blob
    final decoded = _tryBase64Decode(trimmed);
    if (decoded != null && decoded != trimmed) {
      final nested = await _parseContent(decoded);
      if (nested.hasNodes) {
        return ParsedResult(
          nodes: nested.nodes,
          errors: nested.errors,
          detectedSource: nested.detectedSource ?? 'Base64 订阅',
        );
      }
    }

    // sing-box / JSON
    try {
      final json = jsonDecode(trimmed);
      if (json is Map<String, dynamic>) {
        return _parseSingboxJson(json);
      }
      if (json is List) {
        return _parseJsonNodeList(json);
      }
    } catch (_) {}

    // Last resort: Clash YAML even without obvious markers
    if (trimmed.contains('proxies:') || trimmed.contains('type:')) {
      final clash = _parseClashYaml(trimmed);
      if (clash.hasNodes) return clash;
    }

    return ParsedResult(
      nodes: [],
      errors: [
        '无法识别输入格式（支持 URI / Base64 订阅 / Clash YAML / sing-box JSON / 本地文件）'
      ],
      detectedSource: null,
    );
  }

  Future<ParsedResult> _fetchAndParse(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: const {
          'User-Agent': 'Nexus/1.0',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return ParsedResult(
            nodes: [],
            errors: ['HTTP ${resp.statusCode}'],
            detectedSource: null);
      }
      // Some panels return UTF-8 bytes as latin1; prefer bodyBytes
      String body;
      try {
        body = utf8.decode(resp.bodyBytes);
      } catch (_) {
        body = resp.body;
      }
      final source = _detectSource(url, body);
      final result = await _parseContent(body);
      return ParsedResult(
        nodes: result.nodes
            .map((n) => n.copyWith(
                  source: n.source == NodeSource.unknown
                      ? NodeSource.subscription
                      : n.source,
                ))
            .toList(),
        errors: result.errors,
        detectedSource: source ?? result.detectedSource,
      );
    } catch (e) {
      return ParsedResult(
          nodes: [], errors: ['请求失败: $e'], detectedSource: null);
    }
  }

  ParsedResult _parseUriLines(List<String> lines) {
    final nodes = <ProxyNode>[];
    final errors = <String>[];
    for (final line in lines) {
      try {
        nodes.add(_parseUri(line));
      } catch (e) {
        final preview = line.length > 48 ? '${line.substring(0, 48)}…' : line;
        errors.add('$preview → $e');
      }
    }
    return ParsedResult(nodes: nodes, errors: errors, detectedSource: 'URI 分享');
  }

  ParsedResult _parseSingboxJson(Map<String, dynamic> json) {
    final outbounds = (json['outbounds'] as List?) ?? const [];
    final nodes = <ProxyNode>[];
    final errors = <String>[];
    for (final raw in outbounds) {
      if (raw is! Map) continue;
      final ob = Map<String, dynamic>.from(raw);
      final type = ob['type'] as String? ?? '';
      if (const {
        'direct',
        'block',
        'dns',
        'selector',
        'urltest',
        'echo',
        'tor',
        'ssh'
      }.contains(type)) {
        continue;
      }
      try {
        nodes.add(_singboxOutboundToNode(ob));
      } catch (e) {
        errors.add('outbound[${ob['tag']}]: $e');
      }
    }
    return ParsedResult(
        nodes: nodes, errors: errors, detectedSource: 'sing-box 配置');
  }

  ParsedResult _parseJsonNodeList(List list) {
    final nodes = <ProxyNode>[];
    final errors = <String>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      try {
        if (m.containsKey('type') && m.containsKey('server')) {
          nodes.add(_singboxOutboundToNode(m));
        } else if (m.containsKey('protocol') || m.containsKey('id')) {
          nodes.add(ProxyNode.fromJson(m));
        }
      } catch (e) {
        errors.add('json item: $e');
      }
    }
    return ParsedResult(
        nodes: nodes, errors: errors, detectedSource: 'JSON 节点列表');
  }

  ParsedResult _parseClashYaml(String content) {
    final nodes = <ProxyNode>[];
    final errors = <String>[];
    try {
      final doc = loadYaml(content);
      if (doc is! YamlMap && doc is! Map) {
        return ParsedResult(
            nodes: [], errors: ['YAML 根节点无效'], detectedSource: 'Clash');
      }
      final root = _yamlToDart(doc) as Map;
      final proxies = root['proxies'] ?? root['Proxy'];
      if (proxies is! List) {
        return ParsedResult(
            nodes: [], errors: ['未找到 proxies 列表'], detectedSource: 'Clash');
      }
      for (final p in proxies) {
        if (p is! Map) continue;
        try {
          nodes.add(_clashProxyToNode(Map<String, dynamic>.from(
            p.map((k, v) => MapEntry(k.toString(), v)),
          )));
        } catch (e) {
          errors.add('proxy[${p['name']}]: $e');
        }
      }
      return ParsedResult(
          nodes: nodes, errors: errors, detectedSource: 'Clash / Meta');
    } catch (e) {
      return ParsedResult(
          nodes: [], errors: ['Clash YAML 解析失败: $e'], detectedSource: 'Clash');
    }
  }

  ProxyNode _clashProxyToNode(Map<String, dynamic> p) {
    final type = (p['type'] as String? ?? '').toLowerCase();
    final name = (p['name'] ?? p['tag'] ?? '未命名').toString();
    final server = (p['server'] ?? '').toString();
    final port = int.tryParse('${p['port']}') ?? 443;
    final network = (p['network'] ?? p['transport'] ?? 'tcp').toString();
    final tlsEnabled = p['tls'] == true ||
        p['tls'] == 'true' ||
        (p['tls'] is Map) ||
        ['trojan', 'hysteria2', 'tuic'].contains(type);

    Security security = Security.none;
    String? sni = p['sni']?.toString() ?? p['servername']?.toString();
    String? fingerprint =
        p['client-fingerprint']?.toString() ?? p['fingerprint']?.toString();
    String? publicKey;
    String? shortId;
    List<String>? alpn;

    final reality = p['reality-opts'] ?? p['reality'];
    if (reality is Map) {
      security = Security.reality;
      publicKey = reality['public-key']?.toString() ??
          reality['public_key']?.toString();
      shortId =
          reality['short-id']?.toString() ?? reality['short_id']?.toString();
    } else if (tlsEnabled) {
      security = Security.tls;
    }

    if (p['alpn'] is List) {
      alpn = (p['alpn'] as List).map((e) => e.toString()).toList();
    } else if (p['alpn'] is String) {
      alpn = (p['alpn'] as String).split(',');
    }

    final wsOpts = p['ws-opts'] is Map
        ? Map<String, dynamic>.from(p['ws-opts'] as Map)
        : null;
    final grpcOpts = p['grpc-opts'] is Map
        ? Map<String, dynamic>.from(p['grpc-opts'] as Map)
        : null;
    final path = wsOpts?['path']?.toString() ?? p['path']?.toString();
    String? host;
    final headers = wsOpts?['headers'];
    if (headers is Map)
      host = headers['Host']?.toString() ?? headers['host']?.toString();
    host ??= p['host']?.toString();

    Protocol protocol;
    String? uuid = p['uuid']?.toString();
    String? password = p['password']?.toString();
    String? method = p['cipher']?.toString() ?? p['method']?.toString();
    int? alterId = int.tryParse('${p['alterId'] ?? p['aid'] ?? ''}');
    String? obfs = p['obfs']?.toString();
    String? obfsPassword = p['obfs-password']?.toString();
    String? congestion = p['congestion-controller']?.toString() ??
        p['congestion_control']?.toString();
    String? privateKey;
    String? publicKeyWG;
    List<String>? allowedIPs;
    String? dns;

    switch (type) {
      case 'ss':
      case 'shadowsocks':
        protocol = Protocol.shadowsocks;
        break;
      case 'vmess':
        protocol = Protocol.vmess;
        break;
      case 'vless':
        protocol = Protocol.vless;
        break;
      case 'trojan':
        protocol = Protocol.trojan;
        security = Security.tls;
        break;
      case 'hysteria2':
      case 'hy2':
        protocol = Protocol.hysteria2;
        security = Security.tls;
        password ??= p['password']?.toString() ?? p['auth']?.toString();
        break;
      case 'tuic':
        protocol = Protocol.tuic;
        security = Security.tls;
        uuid ??= p['uuid']?.toString();
        password ??= p['password']?.toString();
        break;
      case 'wireguard':
      case 'wg':
        protocol = Protocol.wireguard;
        privateKey =
            p['private-key']?.toString() ?? p['private_key']?.toString();
        publicKeyWG =
            p['public-key']?.toString() ?? p['public_key']?.toString();
        if (p['allowed-ips'] is List) {
          allowedIPs =
              (p['allowed-ips'] as List).map((e) => e.toString()).toList();
        }
        dns = p['dns']?.toString();
        break;
      default:
        throw Exception('不支持的 Clash 协议: $type');
    }

    return ProxyNode(
      id: _uuid(),
      name: name,
      flag: _flagFromName(name),
      group: _groupFromName(name),
      protocol: protocol,
      server: server,
      port: port,
      uuid: uuid,
      password: password,
      method: method,
      alterId: alterId,
      transport: _mapTransport(network),
      path: path,
      host: host,
      serviceName: grpcOpts?['grpc-service-name']?.toString() ??
          p['service-name']?.toString(),
      security: security,
      sni: sni,
      alpn: alpn,
      fingerprint: fingerprint,
      publicKey: publicKey,
      shortId: shortId,
      obfs: obfs,
      obfsPassword: obfsPassword,
      congestion: congestion,
      privateKey: privateKey,
      publicKeyWG: publicKeyWG,
      allowedIPs: allowedIPs,
      dns: dns,
      source: NodeSource.unknown,
    );
  }

  ProxyNode _parseUri(String uri) {
    final scheme = uri.split('://').first.toLowerCase();
    switch (scheme) {
      case 'vmess':
        return _vmess(uri);
      case 'vless':
        return _vless(uri);
      case 'trojan':
        return _trojan(uri);
      case 'ss':
        return _ss(uri);
      case 'hysteria2':
      case 'hy2':
        return _hysteria2(uri);
      case 'tuic':
        return _tuic(uri);
      case 'wg':
      case 'wireguard':
        return _wireguard(uri);
      default:
        throw Exception('不支持的协议: $scheme');
    }
  }

  ProxyNode _vmess(String uri) {
    final b64 = uri.substring('vmess://'.length);
    final decoded = _tryBase64Decode(b64);
    if (decoded == null) throw Exception('VMess Base64 无效');
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    return ProxyNode(
      id: _uuid(),
      name: json['ps']?.toString() ?? json['add']?.toString() ?? '未命名',
      flag: _flagFromName(json['ps']?.toString() ?? ''),
      group: _groupFromName(json['ps']?.toString() ?? ''),
      protocol: Protocol.vmess,
      server: json['add']?.toString() ?? '',
      port: int.tryParse(json['port'].toString()) ?? 443,
      uuid: json['id']?.toString(),
      alterId: int.tryParse(json['aid']?.toString() ?? '0') ?? 0,
      transport: _mapTransport(json['net']?.toString()),
      path: json['path']?.toString(),
      host: json['host']?.toString(),
      security: json['tls']?.toString() == 'tls' ? Security.tls : Security.none,
      sni: json['sni']?.toString() ?? json['host']?.toString(),
      alpn: json['alpn'] != null ? json['alpn'].toString().split(',') : null,
      source: NodeSource.unknown,
      rawUri: uri,
    );
  }

  ProxyNode _vless(String uri) {
    final u = Uri.parse(uri.replaceFirst('vless://', 'https://'));
    final p = u.queryParameters;
    final sec = p['security'] == 'reality'
        ? Security.reality
        : p['security'] == 'tls'
            ? Security.tls
            : Security.none;
    return ProxyNode(
      id: _uuid(),
      name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: _flagFromName(u.fragment),
      group: _groupFromName(u.fragment),
      protocol: Protocol.vless,
      server: u.host,
      port: u.port > 0 ? u.port : 443,
      uuid: u.userInfo,
      transport: _mapTransport(p['type']),
      path: p['path'] ?? p['serviceName'],
      host: p['host'],
      serviceName: p['serviceName'],
      security: sec,
      sni: p['sni'],
      alpn: p['alpn']?.split(','),
      fingerprint: p['fp'],
      publicKey: p['pbk'],
      shortId: p['sid'],
      source: NodeSource.unknown,
      rawUri: uri,
    );
  }

  ProxyNode _trojan(String uri) {
    final u = Uri.parse(uri.replaceFirst('trojan://', 'https://'));
    final p = u.queryParameters;
    return ProxyNode(
      id: _uuid(),
      name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: _flagFromName(u.fragment),
      group: _groupFromName(u.fragment),
      protocol: Protocol.trojan,
      server: u.host,
      port: u.port > 0 ? u.port : 443,
      password: Uri.decodeComponent(u.userInfo),
      transport: _mapTransport(p['type']),
      path: p['path'] ?? p['serviceName'],
      serviceName: p['serviceName'],
      security: Security.tls,
      sni: p['sni'] ?? u.host,
      alpn: p['alpn']?.split(','),
      fingerprint: p['fp'],
      source: NodeSource.unknown,
      rawUri: uri,
    );
  }

  ProxyNode _ss(String uri) {
    final withoutScheme = uri.substring('ss://'.length);
    final hashIdx = withoutScheme.indexOf('#');
    final name = hashIdx >= 0
        ? Uri.decodeComponent(withoutScheme.substring(hashIdx + 1))
        : '';
    final main =
        hashIdx >= 0 ? withoutScheme.substring(0, hashIdx) : withoutScheme;
    String method, password, server;
    int port;
    if (main.contains('@')) {
      final atIdx = main.lastIndexOf('@');
      final userPart = main.substring(0, atIdx);
      String creds;
      if (userPart.contains(':')) {
        creds = userPart;
      } else {
        final decoded = _tryBase64Decode(userPart);
        if (decoded == null) throw Exception('SS 凭证 Base64 无效');
        creds = decoded;
      }
      final colonIdx = creds.indexOf(':');
      if (colonIdx < 0) throw Exception('SS 凭证格式错误');
      method = creds.substring(0, colonIdx);
      password = creds.substring(colonIdx + 1);
      final hostPort = main.substring(atIdx + 1);
      final lastColon = hostPort.lastIndexOf(':');
      if (lastColon < 0) throw Exception('SS 主机端口无效');
      server = hostPort.substring(0, lastColon);
      port = int.parse(hostPort.substring(lastColon + 1));
    } else {
      final decoded = _tryBase64Decode(main);
      if (decoded == null) throw Exception('SS Base64 无效');
      final match = RegExp(r'^(.+?):(.+)@(.+):(\d+)$').firstMatch(decoded);
      if (match == null) throw Exception('SS 解码后格式无效');
      method = match[1]!;
      password = match[2]!;
      server = match[3]!;
      port = int.parse(match[4]!);
    }
    return ProxyNode(
      id: _uuid(),
      name: name.isEmpty ? server : name,
      flag: _flagFromName(name),
      group: _groupFromName(name),
      protocol: Protocol.shadowsocks,
      server: server,
      port: port,
      method: method,
      password: password,
      transport: Transport.tcp,
      security: Security.none,
      source: NodeSource.unknown,
      rawUri: uri,
    );
  }

  ProxyNode _hysteria2(String uri) {
    final u =
        Uri.parse(uri.replaceFirst(RegExp(r'^(hysteria2|hy2)://'), 'https://'));
    final p = u.queryParameters;
    return ProxyNode(
      id: _uuid(),
      name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: _flagFromName(u.fragment),
      group: _groupFromName(u.fragment),
      protocol: Protocol.hysteria2,
      server: u.host,
      port: u.port > 0 ? u.port : 443,
      password: Uri.decodeComponent(u.userInfo),
      transport: Transport.quic,
      security: Security.tls,
      sni: p['sni'],
      obfs: p['obfs'],
      obfsPassword: p['obfs-password'],
      source: NodeSource.unknown,
      rawUri: uri,
    );
  }

  ProxyNode _tuic(String uri) {
    final u = Uri.parse(uri.replaceFirst('tuic://', 'https://'));
    final p = u.queryParameters;
    final userParts = u.userInfo.split(':');
    return ProxyNode(
      id: _uuid(),
      name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: _flagFromName(u.fragment),
      group: _groupFromName(u.fragment),
      protocol: Protocol.tuic,
      server: u.host,
      port: u.port > 0 ? u.port : 443,
      uuid: userParts.isNotEmpty ? userParts.first : null,
      password: userParts.length > 1 ? userParts.sublist(1).join(':') : null,
      transport: Transport.quic,
      security: Security.tls,
      sni: p['sni'],
      alpn: p['alpn']?.split(','),
      congestion: p['congestion_control'] ?? 'bbr',
      source: NodeSource.unknown,
      rawUri: uri,
    );
  }

  ProxyNode _wireguard(String uri) {
    final u =
        Uri.parse(uri.replaceFirst(RegExp(r'^(wg|wireguard)://'), 'https://'));
    final p = u.queryParameters;
    return ProxyNode(
      id: _uuid(),
      name: Uri.decodeComponent(u.fragment.isNotEmpty ? u.fragment : u.host),
      flag: '🌐',
      group: 'WireGuard',
      protocol: Protocol.wireguard,
      server: u.host,
      port: u.port > 0 ? u.port : 51820,
      privateKey: u.userInfo,
      publicKeyWG: p['pub'],
      allowedIPs: p['allowed']?.split(',') ?? ['0.0.0.0/0', '::/0'],
      dns: p['dns'] ?? '1.1.1.1',
      transport: Transport.none,
      security: Security.none,
      source: NodeSource.unknown,
      rawUri: uri,
    );
  }

  ProxyNode _singboxOutboundToNode(Map<String, dynamic> ob) {
    final tls = (ob['tls'] as Map?)?.cast<String, dynamic>() ?? {};
    final tp = (ob['transport'] as Map?)?.cast<String, dynamic>() ?? {};
    final isReality = tls['reality'] is Map &&
        (tls['reality']['enabled'] == true ||
            tls['reality']['public_key'] != null);
    final sec = tls['enabled'] == true
        ? (isReality ? Security.reality : Security.tls)
        : Security.none;
    final type = (ob['type'] as String? ?? 'vless').toLowerCase();
    final protocol = type == 'ss' || type == 'shadowsocks'
        ? Protocol.shadowsocks
        : Protocol.values
            .firstWhere((p) => p.name == type, orElse: () => Protocol.vless);

    return ProxyNode(
      id: _uuid(),
      name: ob['tag']?.toString() ?? '未命名',
      flag: _flagFromName(ob['tag']?.toString() ?? ''),
      group: _groupFromName(ob['tag']?.toString() ?? ''),
      protocol: protocol,
      server: ob['server']?.toString() ?? '',
      port: (ob['server_port'] as num?)?.toInt() ?? 443,
      uuid: ob['uuid']?.toString(),
      password: ob['password']?.toString(),
      method: ob['method']?.toString(),
      alterId: (ob['alter_id'] as num?)?.toInt(),
      transport: _mapTransport(tp['type']?.toString()),
      path: tp['path']?.toString() ?? tp['service_name']?.toString(),
      serviceName: tp['service_name']?.toString(),
      security: sec,
      sni: tls['server_name']?.toString(),
      alpn: (tls['alpn'] as List?)?.map((e) => e.toString()).toList(),
      fingerprint:
          tls['utls'] is Map ? tls['utls']['fingerprint']?.toString() : null,
      publicKey: tls['reality'] is Map
          ? tls['reality']['public_key']?.toString()
          : null,
      shortId:
          tls['reality'] is Map ? tls['reality']['short_id']?.toString() : null,
      obfs: ob['obfs'] is Map ? ob['obfs']['type']?.toString() : null,
      obfsPassword:
          ob['obfs'] is Map ? ob['obfs']['password']?.toString() : null,
      congestion: ob['congestion_control']?.toString(),
      source: NodeSource.sub233boySingbox,
    );
  }

  Transport _mapTransport(String? t) {
    switch (t?.toLowerCase()) {
      case 'ws':
      case 'websocket':
        return Transport.ws;
      case 'grpc':
        return Transport.grpc;
      case 'http':
      case 'h2':
      case 'httpupgrade':
        return Transport.http;
      case 'quic':
        return Transport.quic;
      case 'none':
        return Transport.none;
      default:
        return Transport.tcp;
    }
  }

  String? _detectSource(String url, String body) {
    final s = '${url.toLowerCase()} ${body.toLowerCase()}';
    if (s.contains('233boy') && s.contains('sing-box'))
      return '233boy/sing-box';
    if (s.contains('233boy') && s.contains('xray')) return '233boy/Xray';
    if (s.contains('v2ray-agent') || s.contains('mack-a'))
      return 'mack-a/v2ray-agent';
    if (s.contains('sing-box-yg') || s.contains('yonggekkk'))
      return 'yonggekkk/sing-box-yg';
    if (_looksLikeClashYaml(body)) return 'Clash / Meta';
    return '通用格式';
  }

  bool _looksLikeClashYaml(String s) {
    final head = s.length > 800 ? s.substring(0, 800) : s;
    return head.contains('proxies:') ||
        head.contains('proxy-groups:') ||
        head.contains('mixed-port:') ||
        (head.contains('port:') &&
            head.contains('type:') &&
            head.contains('name:'));
  }

  bool _looksLikeLocalPath(String s) {
    if (s.contains('\n')) return false;
    if (s.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(s)) {
      return s.endsWith('.json') ||
          s.endsWith('.yaml') ||
          s.endsWith('.yml') ||
          s.endsWith('.conf') ||
          s.endsWith('.txt');
    }
    return false;
  }

  bool _isHttpUrl(String s) =>
      s.startsWith('http://') || s.startsWith('https://');

  String? _tryBase64Decode(String input) {
    var s = input.replaceAll(RegExp(r'\s'), '');
    if (s.isEmpty) return null;
    // Strip data URI prefix
    if (s.contains(',')) {
      final idx = s.indexOf(',');
      if (s.substring(0, idx).contains('base64')) s = s.substring(idx + 1);
    }
    s = s.replaceAll('-', '+').replaceAll('_', '/');
    final pad = s.length % 4;
    if (pad > 0) s = s.padRight(s.length + (4 - pad), '=');
    try {
      final bytes = base64Decode(s);
      // Heuristic: decoded text should be mostly printable / UTF-8
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  dynamic _yamlToDart(dynamic value) {
    if (value is YamlMap) {
      return {
        for (final e in value.entries) e.key.toString(): _yamlToDart(e.value),
      };
    }
    if (value is YamlList) {
      return value.map(_yamlToDart).toList();
    }
    return value;
  }

  static int _counter = 0;
  String _uuid() =>
      'node-${DateTime.now().millisecondsSinceEpoch}-${_counter++}';

  static const _countryFlags = {
    '日本': '🇯🇵',
    'japan': '🇯🇵',
    'jp': '🇯🇵',
    'tokyo': '🇯🇵',
    'osaka': '🇯🇵',
    '美国': '🇺🇸',
    'usa': '🇺🇸',
    'us': '🇺🇸',
    'angeles': '🇺🇸',
    'york': '🇺🇸',
    '香港': '🇭🇰',
    'hk': '🇭🇰',
    'hong kong': '🇭🇰',
    '新加坡': '🇸🇬',
    'sg': '🇸🇬',
    'singapore': '🇸🇬',
    '台湾': '🇹🇼',
    'tw': '🇹🇼',
    'taiwan': '🇹🇼',
    '韩国': '🇰🇷',
    'kr': '🇰🇷',
    'korea': '🇰🇷',
    'seoul': '🇰🇷',
    '德国': '🇩🇪',
    'de': '🇩🇪',
    'germany': '🇩🇪',
    'frankfurt': '🇩🇪',
    '英国': '🇬🇧',
    'uk': '🇬🇧',
    'london': '🇬🇧',
    '法国': '🇫🇷',
    'fr': '🇫🇷',
    'paris': '🇫🇷',
    '澳大利亚': '🇦🇺',
    'au': '🇦🇺',
    'sydney': '🇦🇺',
  };
  static const _regionGroups = {
    '亚太': [
      '日本',
      '香港',
      '新加坡',
      '台湾',
      '韩国',
      '澳大利亚',
      'jp',
      'hk',
      'sg',
      'tw',
      'kr',
      'au',
      'tokyo',
      'osaka',
      'seoul',
      'singapore',
      'taiwan'
    ],
    '北美': ['美国', 'us', 'usa', 'angeles', 'york'],
    '欧洲': ['德国', '英国', '法国', 'de', 'uk', 'fr', 'frankfurt', 'london', 'paris'],
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
