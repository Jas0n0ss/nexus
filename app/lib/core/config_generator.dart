import '../models/proxy_node.dart';
import '../providers/settings_provider.dart';

/// Generates a complete sing-box 1.9.x JSON config from a ProxyNode + settings.
class ConfigGenerator {
  static Map<String, dynamic> generate(
    ProxyNode node, {
    SettingsProvider? settings,
    bool? tunMode,
    bool? dnsLeakProtection,
    String? routeMode,
    String? remoteDns,
    bool? blockAds,
    bool? allowLan,
    int mixedPort = 7890,
  }) {
    final tun = tunMode ?? settings?.tunMode ?? true;
    final dnsLeak = dnsLeakProtection ?? settings?.dnsLeakProtection ?? true;
    final mode = routeMode ?? settings?.routeMode.name ?? 'rule';
    final dns = remoteDns ?? settings?.remoteDns ?? 'https://1.1.1.1/dns-query';
    final ads = blockAds ?? settings?.blockAds ?? true;
    final lan = allowLan ?? settings?.allowLan ?? false;
    final sniff = settings?.sniffOverride ?? true;

    return {
      'log': {'level': 'info', 'timestamp': true},
      'dns': _dns(dnsLeak, dns),
      'inbounds': _inbounds(tun: tun, allowLan: lan, mixedPort: mixedPort, sniff: sniff),
      'outbounds': [
        _outbound(node, mux: settings?.mux == true),
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block',  'tag': 'block'},
        {'type': 'dns',    'tag': 'dns-out'},
      ],
      'route': _route(mode, blockAds: ads),
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:9090',
          'secret': '',
        },
        'cache_file': {'enabled': true, 'path': 'cache.db'},
      },
    };
  }

  static Map<String, dynamic> _dns(bool leakProtection, String remoteDns) => {
    'servers': [
      {'tag': 'dns-remote', 'address': remoteDns, 'detour': 'proxy'},
      {'tag': 'dns-local',  'address': 'https://223.5.5.5/dns-query', 'detour': 'direct'},
      {'tag': 'dns-block',  'address': 'rcode://success'},
    ],
    'rules': [
      if (leakProtection) ...[
        {'rule_set': ['geosite-cn'], 'server': 'dns-local'},
        {'rule_set': ['geosite-geolocation-!cn'], 'server': 'dns-remote'},
      ] else ...[
        {'rule_set': ['geosite-cn'], 'server': 'dns-local'},
      ],
    ],
    'final': leakProtection ? 'dns-remote' : 'dns-local',
    'strategy': 'prefer_ipv4',
    'independent_cache': true,
  };

  static List<Map<String, dynamic>> _inbounds({
    required bool tun,
    required bool allowLan,
    required int mixedPort,
    required bool sniff,
  }) => [
    {
      'type': 'mixed',
      'tag': 'mixed-in',
      'listen': allowLan ? '0.0.0.0' : '127.0.0.1',
      'listen_port': mixedPort,
      'sniff': sniff,
      'sniff_override_destination': sniff,
    },
    if (tun) {
      'type': 'tun',
      'tag': 'tun-in',
      'interface_name': 'tun0',
      'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
      'mtu': 9000,
      'auto_route': true,
      'strict_route': true,
      'stack': 'system',
      'sniff': sniff,
      'sniff_override_destination': sniff,
    },
  ];

  static Map<String, dynamic> _outbound(ProxyNode n, {bool mux = false}) {
    final ob = <String, dynamic>{
      'type': n.protocol == Protocol.shadowsocks ? 'shadowsocks' : n.protocol.name,
      'tag': 'proxy',
    };

    if (n.protocol == Protocol.wireguard) {
      ob['private_key'] = n.privateKey;
      ob['peers'] = [{
        'public_key': n.publicKeyWG,
        'server': n.server,
        'server_port': n.port,
        'allowed_ips': n.allowedIPs ?? ['0.0.0.0/0', '::/0'],
      }];
      if (n.dns != null) ob['local_address'] = ['10.0.0.2/32'];
      return ob;
    }

    ob['server'] = n.server;
    ob['server_port'] = n.port;

    if (n.security != Security.none) {
      ob['tls'] = {
        'enabled': true,
        if (n.sni != null && n.sni!.isNotEmpty) 'server_name': n.sni,
        if (n.alpn != null && n.alpn!.isNotEmpty) 'alpn': n.alpn,
        if (n.fingerprint != null && n.fingerprint!.isNotEmpty)
          'utls': {'enabled': true, 'fingerprint': n.fingerprint},
        if (n.security == Security.reality) 'reality': {
          'enabled': true,
          'public_key': n.publicKey,
          'short_id': n.shortId ?? '',
        },
      };
    }

    if (n.transport != Transport.tcp && n.transport != Transport.none) {
      ob['transport'] = _transport(n);
    }

    // Mux only for TCP-based protocols
    if (mux &&
        ![Protocol.hysteria2, Protocol.tuic, Protocol.wireguard].contains(n.protocol) &&
        n.transport != Transport.quic) {
      ob['multiplex'] = {'enabled': true, 'protocol': 'h2mux', 'max_streams': 8};
    }

    switch (n.protocol) {
      case Protocol.vless:
        ob['uuid'] = n.uuid;
        if (n.security == Security.reality && n.transport == Transport.tcp) {
          ob['flow'] = 'xtls-rprx-vision';
        }
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
        if (n.obfs != null && n.obfs!.isNotEmpty) {
          ob['obfs'] = {'type': n.obfs, 'password': n.obfsPassword};
        }
        break;
      case Protocol.tuic:
        ob['uuid'] = n.uuid;
        ob['password'] = n.password;
        ob['congestion_control'] = n.congestion ?? 'bbr';
        ob['udp_relay_mode'] = 'native';
        break;
      default:
        break;
    }

    return ob;
  }

  static Map<String, dynamic> _transport(ProxyNode n) {
    switch (n.transport) {
      case Transport.ws:
        return {
          'type': 'ws',
          'path': n.path ?? '/',
          if (n.host != null) 'headers': {'Host': n.host},
        };
      case Transport.grpc:
        return {'type': 'grpc', 'service_name': n.serviceName ?? ''};
      case Transport.http:
        return {
          'type': 'http',
          if (n.path != null) 'path': n.path,
          if (n.host != null) 'host': [n.host],
        };
      case Transport.quic:
        return {'type': 'quic'};
      default:
        return {'type': n.transport.name};
    }
  }

  static Map<String, dynamic> _route(String mode, {required bool blockAds}) {
    final isRule = mode == 'rule';
    final isDirect = mode == 'direct';

    return {
      'rules': [
        {'protocol': 'dns', 'outbound': 'dns-out'},
        {'ip_is_private': true, 'outbound': 'direct'},
        if (isRule) ...[
          {'rule_set': ['geoip-cn', 'geosite-cn'], 'outbound': 'direct'},
          if (blockAds)
            {'rule_set': ['geosite-category-ads-all'], 'outbound': 'block'},
        ],
      ],
      'rule_set': isRule
          ? [
              {
                'tag': 'geoip-cn',
                'type': 'remote',
                'format': 'binary',
                'url': 'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
                'download_detour': 'direct',
                'update_interval': '7d',
              },
              {
                'tag': 'geosite-cn',
                'type': 'remote',
                'format': 'binary',
                'url': 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
                'download_detour': 'direct',
                'update_interval': '7d',
              },
              {
                'tag': 'geosite-geolocation-!cn',
                'type': 'remote',
                'format': 'binary',
                'url':
                    'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs',
                'download_detour': 'direct',
                'update_interval': '7d',
              },
              if (blockAds)
                {
                  'tag': 'geosite-category-ads-all',
                  'type': 'remote',
                  'format': 'binary',
                  'url':
                      'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs',
                  'download_detour': 'direct',
                  'update_interval': '7d',
                },
            ]
          : [],
      // Passwall-like: global → all via proxy; direct → all direct; rule → default proxy + CN direct
      'final': isDirect ? 'direct' : 'proxy',
      'auto_detect_interface': true,
      'override_android_vpn': true,
    };
  }
}
