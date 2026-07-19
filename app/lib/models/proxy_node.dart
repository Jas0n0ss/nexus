// ignore_for_file: invalid_annotation_target
import 'dart:ui' show Color;

import 'package:hive/hive.dart';

enum Protocol { vless, vmess, trojan, shadowsocks, hysteria2, tuic, wireguard }
enum Transport { tcp, ws, grpc, http, quic, none }
enum Security  { tls, reality, none }
enum NodeSource { sub233boySingbox, sub233boyXray, sub233boyV2ray, mackA, yonggekkk, manual, subscription, unknown }

@HiveType(typeId: 0)
class ProxyNode extends HiveObject {
  @HiveField(0)  final String id;
  @HiveField(1)  final String name;
  @HiveField(2)  final String flag;
  @HiveField(3)  final String group;
  @HiveField(4)  final Protocol protocol;
  @HiveField(5)  final String server;
  @HiveField(6)  final int port;

  // Auth
  @HiveField(7)  final String? uuid;
  @HiveField(8)  final String? password;
  @HiveField(9)  final String? method;        // SS encryption
  @HiveField(10) final int? alterId;          // VMess

  // Transport
  @HiveField(11) final Transport transport;
  @HiveField(12) final String? path;
  @HiveField(13) final String? host;
  @HiveField(14) final String? serviceName;

  // TLS / REALITY
  @HiveField(15) final Security security;
  @HiveField(16) final String? sni;
  @HiveField(17) final List<String>? alpn;
  @HiveField(18) final String? fingerprint;
  @HiveField(19) final String? publicKey;
  @HiveField(20) final String? shortId;

  // Hysteria2 / TUIC
  @HiveField(21) final String? obfs;
  @HiveField(22) final String? obfsPassword;
  @HiveField(23) final String? congestion;

  // WireGuard
  @HiveField(24) final String? privateKey;
  @HiveField(25) final String? publicKeyWG;
  @HiveField(26) final List<String>? allowedIPs;
  @HiveField(27) final String? dns;

  // Meta
  @HiveField(28) final NodeSource source;
  @HiveField(29) final String? rawUri;
  @HiveField(30) final DateTime addedAt;

  // Runtime (not persisted via Hive, updated in memory)
  int? latencyMs;
  double? downloadMbps;
  double? uploadMbps;
  bool? isReachable;

  ProxyNode({
    required this.id,
    required this.name,
    required this.flag,
    required this.group,
    required this.protocol,
    required this.server,
    required this.port,
    this.uuid,
    this.password,
    this.method,
    this.alterId,
    required this.transport,
    this.path,
    this.host,
    this.serviceName,
    required this.security,
    this.sni,
    this.alpn,
    this.fingerprint,
    this.publicKey,
    this.shortId,
    this.obfs,
    this.obfsPassword,
    this.congestion,
    this.privateKey,
    this.publicKeyWG,
    this.allowedIPs,
    this.dns,
    this.source = NodeSource.unknown,
    this.rawUri,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  String get protocolLabel {
    switch (protocol) {
      case Protocol.vless:
        return security == Security.reality ? 'VLESS+REALITY' : 'VLESS+${transport.name.toUpperCase()}';
      case Protocol.vmess:
        return 'VMess+${transport.name.toUpperCase()}';
      case Protocol.trojan:
        return transport == Transport.grpc ? 'Trojan+gRPC' : 'Trojan+TLS';
      case Protocol.shadowsocks:
        return 'Shadowsocks';
      case Protocol.hysteria2:
        return 'Hysteria2';
      case Protocol.tuic:
        return 'TUIC v5';
      case Protocol.wireguard:
        return 'WireGuard';
    }
  }

  Color get latencyColor {
    if (latencyMs == null) return const Color(0xFF6B7280);
    if (latencyMs! < 80)  return const Color(0xFF22C55E);
    if (latencyMs! < 200) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get latencyLabel => latencyMs != null ? '${latencyMs}ms' : '–';

  String get sourceLabel {
    switch (source) {
      case NodeSource.sub233boySingbox: return '233boy/sing-box';
      case NodeSource.sub233boyXray:   return '233boy/Xray';
      case NodeSource.sub233boyV2ray:  return '233boy/v2ray';
      case NodeSource.mackA:           return 'mack-a';
      case NodeSource.yonggekkk:       return 'yonggekkk';
      case NodeSource.manual:          return '手动配置';
      case NodeSource.subscription:    return '订阅';
      case NodeSource.unknown:         return '未知';
    }
  }

  String get dedupeKey => '$server:$port:${uuid ?? password ?? privateKey ?? name}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'flag': flag,
    'group': group,
    'protocol': protocol.name,
    'server': server,
    'port': port,
    'uuid': uuid,
    'password': password,
    'method': method,
    'alterId': alterId,
    'transport': transport.name,
    'path': path,
    'host': host,
    'serviceName': serviceName,
    'security': security.name,
    'sni': sni,
    'alpn': alpn,
    'fingerprint': fingerprint,
    'publicKey': publicKey,
    'shortId': shortId,
    'obfs': obfs,
    'obfsPassword': obfsPassword,
    'congestion': congestion,
    'privateKey': privateKey,
    'publicKeyWG': publicKeyWG,
    'allowedIPs': allowedIPs,
    'dns': dns,
    'source': source.name,
    'rawUri': rawUri,
    'addedAt': addedAt.toIso8601String(),
  };

  factory ProxyNode.fromJson(Map<String, dynamic> json) {
    T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
      if (name == null) return fallback;
      return values.firstWhere((e) => e.name == name, orElse: () => fallback);
    }

    return ProxyNode(
      id: json['id'] as String? ?? 'node-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? '未命名',
      flag: json['flag'] as String? ?? '🌐',
      group: json['group'] as String? ?? '其他',
      protocol: enumByName(Protocol.values, json['protocol'] as String?, Protocol.vless),
      server: json['server'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 443,
      uuid: json['uuid'] as String?,
      password: json['password'] as String?,
      method: json['method'] as String?,
      alterId: (json['alterId'] as num?)?.toInt(),
      transport: enumByName(Transport.values, json['transport'] as String?, Transport.tcp),
      path: json['path'] as String?,
      host: json['host'] as String?,
      serviceName: json['serviceName'] as String?,
      security: enumByName(Security.values, json['security'] as String?, Security.none),
      sni: json['sni'] as String?,
      alpn: (json['alpn'] as List?)?.map((e) => e.toString()).toList(),
      fingerprint: json['fingerprint'] as String?,
      publicKey: json['publicKey'] as String?,
      shortId: json['shortId'] as String?,
      obfs: json['obfs'] as String?,
      obfsPassword: json['obfsPassword'] as String?,
      congestion: json['congestion'] as String?,
      privateKey: json['privateKey'] as String?,
      publicKeyWG: json['publicKeyWG'] as String?,
      allowedIPs: (json['allowedIPs'] as List?)?.map((e) => e.toString()).toList(),
      dns: json['dns'] as String?,
      source: enumByName(NodeSource.values, json['source'] as String?, NodeSource.unknown),
      rawUri: json['rawUri'] as String?,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  ProxyNode copyWith({
    String? id,
    String? name,
    String? flag,
    String? group,
    Protocol? protocol,
    String? server,
    int? port,
    String? uuid,
    String? password,
    String? method,
    int? alterId,
    Transport? transport,
    String? path,
    String? host,
    String? serviceName,
    Security? security,
    String? sni,
    List<String>? alpn,
    String? fingerprint,
    String? publicKey,
    String? shortId,
    String? obfs,
    String? obfsPassword,
    String? congestion,
    String? privateKey,
    String? publicKeyWG,
    List<String>? allowedIPs,
    String? dns,
    NodeSource? source,
    String? rawUri,
    DateTime? addedAt,
    int? latencyMs,
    double? downloadMbps,
    double? uploadMbps,
    bool? isReachable,
  }) {
    final n = ProxyNode(
      id: id ?? this.id,
      name: name ?? this.name,
      flag: flag ?? this.flag,
      group: group ?? this.group,
      protocol: protocol ?? this.protocol,
      server: server ?? this.server,
      port: port ?? this.port,
      uuid: uuid ?? this.uuid,
      password: password ?? this.password,
      method: method ?? this.method,
      alterId: alterId ?? this.alterId,
      transport: transport ?? this.transport,
      path: path ?? this.path,
      host: host ?? this.host,
      serviceName: serviceName ?? this.serviceName,
      security: security ?? this.security,
      sni: sni ?? this.sni,
      alpn: alpn ?? (this.alpn != null ? List<String>.from(this.alpn!) : null),
      fingerprint: fingerprint ?? this.fingerprint,
      publicKey: publicKey ?? this.publicKey,
      shortId: shortId ?? this.shortId,
      obfs: obfs ?? this.obfs,
      obfsPassword: obfsPassword ?? this.obfsPassword,
      congestion: congestion ?? this.congestion,
      privateKey: privateKey ?? this.privateKey,
      publicKeyWG: publicKeyWG ?? this.publicKeyWG,
      allowedIPs: allowedIPs ?? this.allowedIPs,
      dns: dns ?? this.dns,
      source: source ?? this.source,
      rawUri: rawUri ?? this.rawUri,
      addedAt: addedAt ?? this.addedAt,
    );
    n.latencyMs    = latencyMs    ?? this.latencyMs;
    n.downloadMbps = downloadMbps ?? this.downloadMbps;
    n.uploadMbps   = uploadMbps   ?? this.uploadMbps;
    n.isReachable  = isReachable  ?? this.isReachable;
    return n;
  }
}
