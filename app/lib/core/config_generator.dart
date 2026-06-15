import '../models/proxy_node.dart';

/// Generates a complete sing-box 1.9.x JSON config from a ProxyNode.
class ConfigGenerator {
  static Map<String, dynamic> generate(ProxyNode node, {
    bool tunMode = true,
    bool dnsLeakProtection = true,
    String routeMode = 'rule',
  }) {
    return {
      'log': {'level': 'info', 'timestamp': true},
      'dns': _dns(dnsLeakProtection),
      'inbounds': _inbounds(tunMode),
      'outbounds': [
        _outbound(node),
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block',  'tag': 'block'},
        {'type': 'dns',    'tag': 'dns-out'},
      ],
      'route': _route(routeMode),
      'experimental': {
        'clash_api': {'external_controller': '127.0.0.1:9090'},
        'cache_file': {'enabled': true, 'path': 'cache.db'},
      },
    };
  }

  static Map<String, dynamic> _dns(bool leakProtection) => {
    'servers': [
      {'tag': 'dns-remote', 'address': 'https://1.1.1.1/dns-query', 'detour': 'proxy'},
      {'tag': 'dns-local',  'address': 'https://223.5.5.5/dns-query', 'detour': 'direct'},
    ],
    'rules': leakProtection ? [
      {'rule_set': ['geosite-cn'], 'server': 'dns-local'},
      {'rule_set': ['geosite-geolocation-!cn'], 'server': 'dns-remote'},
    ] : [
      {'rule_set': ['geosite-cn'], 'server': 'dns-local'},
    ],
    'final': leakProtection ? 'dns-remote' : 'dns-local',
    'strategy': 'prefer_ipv4',
  };

  static List<Map<String, dynamic>> _inbounds(bool tun) => [
    {'type': 'mixed', 'tag': 'mixed-in', 'listen': '127.0.0.1', 'listen_port': 7890, 'sniff': true},
    if (tun) {
      'type': 'tun', 'tag': 'tun-in',
      'interface_name': 'tun0',
      'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
      'mtu': 9000, 'auto_route': true, 'strict_route': true, 'sniff': true,
    },
  ];

  static Map<String, dynamic> _outbound(ProxyNode n) {
    final ob = <String, dynamic>{
      'type': n.protocol.name,
      'tag': 'proxy',
    };

    // WireGuard is server-less at top level
    if (n.protocol == Protocol.wireguard) {
      ob['private_key'] = n.privateKey;
      ob['peers'] = [{'public_key': n.publicKeyWG, 'server': n.server, 'server_port': n.port, 'allowed_ips': n.allowedIPs}];
      ob['dns_server'] = n.dns ?? '1.1.1.1';
      return ob;
    }

    ob['server'] = n.server;
    ob['server_port'] = n.port;

    // TLS
    if (n.security != Security.none) {
      ob['tls'] = {
        'enabled': true,
        if (n.sni != null) 'server_name': n.sni,
        if (n.alpn != null) 'alpn': n.alpn,
        if (n.fingerprint != null) 'utls': {'enabled': true, 'fingerprint': n.fingerprint},
        if (n.security == Security.reality) 'reality': {
          'enabled': true,
          'public_key': n.publicKey,
          'short_id': n.shortId ?? '',
        },
      };
    }

    // Transport
    if (n.transport != Transport.tcp && n.transport != Transport.none) {
      ob['transport'] = _transport(n);
    }

    // Protocol fields
    switch (n.protocol) {
      case Protocol.vless:
        ob['uuid'] = n.uuid;
        if (n.security == Security.reality) ob['flow'] = 'xtls-rprx-vision';
        break;
      case Protocol.vmess:
        ob['uuid'] = n.uuid;
        ob['alter_id'] = n.alterId ?? 0;
        ob['security'] = 'auto';
        break;
      case Protocol.trojan:
        ob['password'] = n.password;
        break;
      case Protocol.shadowsocks:
        ob['method'] = n.method;
        ob['password'] = n.password;
        break;
      case Protocol.hysteria2:
        ob['password'] = n.password;
        if (n.obfs != null) ob['obfs'] = {'type': n.obfs, 'password': n.obfsPassword};
        break;
      case Protocol.tuic:
        ob['uuid'] = n.uuid;
        ob['password'] = n.password;
        ob['congestion_control'] = n.congestion ?? 'bbr';
        break;
      default: break;
    }

    return ob;
  }

  static Map<String, dynamic> _transport(ProxyNode n) {
    switch (n.transport) {
      case Transport.ws:
        return {'type': 'ws', 'path': n.path ?? '/',
          if (n.host != null) 'headers': {'Host': n.host}};
      case Transport.grpc:
        return {'type': 'grpc', 'service_name': n.serviceName ?? ''};
      case Transport.http:
        return {'type': 'http', 'path': n.path,
          if (n.host != null) 'host': [n.host]};
      case Transport.quic:
        return {'type': 'quic'};
      default:
        return {'type': n.transport.name};
    }
  }

  static Map<String, dynamic> _route(String mode) => {
    'rules': [
      {'protocol': 'dns', 'outbound': 'dns-out'},
      {'ip_is_private': true, 'outbound': 'direct'},
      if (mode == 'rule') ...[
        {'rule_set': ['geoip-cn', 'geosite-cn'], 'outbound': 'direct'},
        {'rule_set': ['geosite-category-ads-all'], 'outbound': 'block'},
      ],
    ],
    'rule_set': mode == 'rule' ? [
      {'tag': 'geoip-cn', 'type': 'remote', 'format': 'binary',
        'url': 'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
        'update_interval': '7d'},
      {'tag': 'geosite-cn', 'type': 'remote', 'format': 'binary',
        'url': 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
        'update_interval': '7d'},
      {'tag': 'geosite-geolocation-!cn', 'type': 'remote', 'format': 'binary',
        'url': 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs',
        'update_interval': '7d'},
      {'tag': 'geosite-category-ads-all', 'type': 'remote', 'format': 'binary',
        'url': 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs',
        'update_interval': '7d'},
    ] : [],
    'final': mode == 'global' ? 'proxy' : mode == 'direct' ? 'direct' : 'proxy',
    'auto_detect_interface': true,
  };
}
