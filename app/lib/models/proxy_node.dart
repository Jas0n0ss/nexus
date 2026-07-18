// ignore_for_file: invalid_annotation_target
import 'dart:ui' show Color;

import 'package:hive/hive.dart';

enum Protocol { vless, vmess, trojan, shadowsocks, hysteria2, tuic, wireguard }
enum Transport { tcp, ws, grpc, http, quic, none }
enum Security  { tls, reality, none }
enum NodeSource { sub233boySingbox, sub233boyXray, sub233boyV2ray, mackA, yonggekkk, manual, unknown }

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
      case NodeSource.unknown:         return '未知';
    }
  }

  ProxyNode copyWith({
    int? latencyMs,
    double? downloadMbps,
    double? uploadMbps,
    bool? isReachable,
  }) {
    final n = ProxyNode(
      id: id, name: name, flag: flag, group: group,
      protocol: protocol, server: server, port: port,
      uuid: uuid, password: password, method: method, alterId: alterId,
      transport: transport, path: path, host: host, serviceName: serviceName,
      security: security, sni: sni, alpn: alpn, fingerprint: fingerprint,
      publicKey: publicKey, shortId: shortId,
      obfs: obfs, obfsPassword: obfsPassword, congestion: congestion,
      privateKey: privateKey, publicKeyWG: publicKeyWG,
      allowedIPs: allowedIPs, dns: dns,
      source: source, rawUri: rawUri, addedAt: addedAt,
    );
    n.latencyMs    = latencyMs    ?? this.latencyMs;
    n.downloadMbps = downloadMbps ?? this.downloadMbps;
    n.uploadMbps   = uploadMbps   ?? this.uploadMbps;
    n.isReachable  = isReachable  ?? this.isReachable;
    return n;
  }

  // Demo nodes for UI testing
  static List<ProxyNode> get demoNodes => [
    ProxyNode(id:'n1', name:'Tokyo 01', flag:'🇯🇵', group:'亚太',
      protocol:Protocol.vless, server:'103.218.64.12', port:443,
      uuid:'abc12345-1234-1234-1234-abc123456789',
      transport:Transport.tcp, security:Security.reality,
      sni:'yahoo.com', fingerprint:'chrome',
      publicKey:'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=',
      shortId:'deadbeef', source:NodeSource.sub233boySingbox)
      ..latencyMs=42,
    ProxyNode(id:'n2', name:'Singapore Prime', flag:'🇸🇬', group:'亚太',
      protocol:Protocol.hysteria2, server:'103.100.72.8', port:8443,
      password:'mypassword', transport:Transport.quic, security:Security.tls,
      sni:'103.100.72.8', source:NodeSource.yonggekkk)
      ..latencyMs=68,
    ProxyNode(id:'n3', name:'Los Angeles', flag:'🇺🇸', group:'北美',
      protocol:Protocol.vless, server:'172.67.82.4', port:443,
      uuid:'def45678-5678-5678-5678-def456789012',
      transport:Transport.ws, security:Security.tls,
      path:'/ws', host:'cdn.example.com', sni:'cdn.example.com',
      source:NodeSource.mackA)
      ..latencyMs=156,
    ProxyNode(id:'n4', name:'HK Ultra', flag:'🇭🇰', group:'亚太',
      protocol:Protocol.trojan, server:'43.153.86.19', port:443,
      password:'trojanpassword', transport:Transport.tcp, security:Security.tls,
      sni:'43.153.86.19', source:NodeSource.sub233boyXray)
      ..latencyMs=18,
    ProxyNode(id:'n5', name:'Frankfurt', flag:'🇩🇪', group:'欧洲',
      protocol:Protocol.vmess, server:'104.21.44.7', port:80,
      uuid:'ghi90123-9012-9012-9012-ghi901234567',
      transport:Transport.ws, security:Security.none,
      path:'/vmess', host:'104.21.44.7', source:NodeSource.sub233boyV2ray)
      ..latencyMs=212,
    ProxyNode(id:'n6', name:'Seoul 03', flag:'🇰🇷', group:'亚太',
      protocol:Protocol.tuic, server:'211.249.220.4', port:8443,
      uuid:'jkl34567-3456-3456-3456-jkl345678901', password:'tuicpass',
      transport:Transport.quic, security:Security.tls,
      congestion:'bbr', source:NodeSource.yonggekkk)
      ..latencyMs=55,
    ProxyNode(id:'n7', name:'Taipei Speed', flag:'🇹🇼', group:'亚太',
      protocol:Protocol.shadowsocks, server:'60.251.90.3', port:8388,
      method:'2022-blake3-aes-256-gcm',
      password:'base64encodedpassword==',
      transport:Transport.tcp, security:Security.none,
      source:NodeSource.mackA)
      ..latencyMs=35,
    ProxyNode(id:'n8', name:'London WG', flag:'🇬🇧', group:'欧洲',
      protocol:Protocol.wireguard, server:'185.246.208.7', port:51820,
      privateKey:'wgPrivateKeyBase64==', publicKeyWG:'wgPeerPublicKeyBase64==',
      allowedIPs:['0.0.0.0/0','::/0'], dns:'1.1.1.1',
      transport:Transport.none, security:Security.none,
      source:NodeSource.manual)
      ..latencyMs=188,
  ];
}
