import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_vpn/core/node_parser.dart';
import 'package:nexus_vpn/core/config_generator.dart';
import 'package:nexus_vpn/core/autofix_engine.dart';
import 'package:nexus_vpn/models/proxy_node.dart';
void main() {
  group('NodeParser', () {
    final parser = NodeParser();

    test('parses vless URI', () async {
      const uri =
          'vless://11111111-2222-3333-4444-555555555555@example.com:443'
          '?encryption=none&security=reality&sni=www.example.com&fp=chrome'
          '&pbk=publickey&sid=abcd&type=tcp#Tokyo-01';
      final r = await parser.parse(uri);
      expect(r.nodes.length, 1);
      expect(r.nodes.first.protocol, Protocol.vless);
      expect(r.nodes.first.security, Security.reality);
      expect(r.nodes.first.server, 'example.com');
      expect(r.nodes.first.name, contains('Tokyo'));
    });

    test('parses ss URI with method:pass@host', () async {
      final user = base64Encode(utf8.encode('aes-256-gcm:secret'));
      final uri = 'ss://$user@1.2.3.4:8388#HK';
      final r = await parser.parse(uri);
      expect(r.nodes.length, 1);
      expect(r.nodes.first.protocol, Protocol.shadowsocks);
      expect(r.nodes.first.method, 'aes-256-gcm');
      expect(r.nodes.first.port, 8388);
    });

    test('parses base64 subscription of URIs', () async {
      const raw = 'trojan://pass@host.example:443?sni=host.example#NodeA\n'
          'ss://YWVzLTI1Ni1nY206cGFzcw==@2.2.2.2:8388#NodeB\n';
      final b64 = base64Encode(utf8.encode(raw));
      final r = await parser.parse(b64);
      expect(r.nodes.length, 2);
      expect(r.detectedSource, anyOf('URI 分享', 'Base64 订阅'));
    });

    test('parses clash yaml proxies', () async {
      const yaml = '''
proxies:
  - name: "JP-01"
    type: ss
    server: 10.0.0.1
    port: 8388
    cipher: aes-256-gcm
    password: hello
  - name: "US-VLESS"
    type: vless
    server: 10.0.0.2
    port: 443
    uuid: 11111111-2222-3333-4444-555555555555
    tls: true
    network: ws
    ws-opts:
      path: /ws
      headers:
        Host: cdn.example.com
''';
      final r = await parser.parse(yaml);
      expect(r.nodes.length, 2);
      expect(r.detectedSource, 'Clash / Meta');
      expect(r.nodes.any((n) => n.protocol == Protocol.shadowsocks), isTrue);
      expect(r.nodes.any((n) => n.protocol == Protocol.vless), isTrue);
    });

    test('parses sing-box outbounds json', () async {
      const json = '''
{
  "outbounds": [
    {"type": "selector", "tag": "proxy"},
    {
      "type": "trojan",
      "tag": "hk-trojan",
      "server": "hk.example.com",
      "server_port": 443,
      "password": "secret",
      "tls": {"enabled": true, "server_name": "hk.example.com"}
    },
    {"type": "direct", "tag": "direct"}
  ]
}
''';
      final r = await parser.parse(json);
      expect(r.nodes.length, 1);
      expect(r.nodes.first.protocol, Protocol.trojan);
      expect(r.nodes.first.name, 'hk-trojan');
    });

    test('partial success keeps valid URIs when one fails', () async {
      const input = 'vless://u@h:443?security=tls#ok\nnot-a-uri\nss://bad';
      final r = await parser.parse(input);
      expect(r.nodes, isNotEmpty);
      expect(r.errors, isNotEmpty);
    });
  });

  group('ConfigGenerator', () {
    test('wires route mode global vs rule', () {
      final node = ProxyNode(
        id: '1',
        name: 't',
        flag: '🌐',
        group: '其他',
        protocol: Protocol.trojan,
        server: 'example.com',
        port: 443,
        password: 'x',
        transport: Transport.tcp,
        security: Security.tls,
        sni: 'example.com',
      );
      final global = ConfigGenerator.generate(node, routeMode: 'global', tunMode: false);
      final rule = ConfigGenerator.generate(node, routeMode: 'rule', tunMode: true);
      expect(global['route']['final'], 'proxy');
      expect((global['route']['rule_set'] as List).isEmpty, isTrue);
      expect((rule['route']['rule_set'] as List).isNotEmpty, isTrue);
      expect((rule['inbounds'] as List).any((e) => e['type'] == 'tun'), isTrue);
      expect((global['inbounds'] as List).any((e) => e['type'] == 'tun'), isFalse);
    });

    test('remote dns and ads flags affect generated config', () {
      final node = ProxyNode(
        id: '1',
        name: 't',
        flag: '🌐',
        group: '其他',
        protocol: Protocol.vless,
        server: 'a.com',
        port: 443,
        uuid: 'u',
        transport: Transport.tcp,
        security: Security.reality,
        fingerprint: 'chrome',
        publicKey: 'k',
      );
      final cfg = ConfigGenerator.generate(
        node,
        routeMode: 'rule',
        remoteDns: 'https://8.8.8.8/dns-query',
        blockAds: false,
      );
      expect(cfg['dns']['servers'][0]['address'], 'https://8.8.8.8/dns-query');
      final tags = (cfg['route']['rule_set'] as List).map((e) => e['tag']).toList();
      expect(tags.contains('geosite-category-ads-all'), isFalse);
    });
  });

  group('AutofixEngine', () {
    test('fills trojan sni and reality fingerprint', () {
      final nodes = [
        ProxyNode(
          id: 't1',
          name: 'trojan',
          flag: '🌐',
          group: '其他',
          protocol: Protocol.trojan,
          server: 'a.com',
          port: 443,
          password: 'p',
          transport: Transport.tcp,
          security: Security.tls,
        ),
        ProxyNode(
          id: 'r1',
          name: 'reality',
          flag: '🌐',
          group: '其他',
          protocol: Protocol.vless,
          server: 'b.com',
          port: 443,
          uuid: 'u',
          transport: Transport.tcp,
          security: Security.reality,
          publicKey: 'pk',
        ),
      ];
      final fixed = AutofixEngine().fixAll(nodes);
      expect(fixed.nodes[0].sni, 'a.com');
      expect(fixed.nodes[1].fingerprint, 'chrome');
      expect(fixed.fixes, isNotEmpty);
    });
  });

  group('ProxyNode persistence', () {
    test('toJson/fromJson roundtrip', () {
      final n = ProxyNode(
        id: 'n1',
        name: 'Node',
        flag: '🇯🇵',
        group: '亚太',
        protocol: Protocol.hysteria2,
        server: '1.1.1.1',
        port: 8443,
        password: 'pw',
        transport: Transport.quic,
        security: Security.tls,
        sni: '1.1.1.1',
      );
      final again = ProxyNode.fromJson(n.toJson());
      expect(again.id, n.id);
      expect(again.protocol, Protocol.hysteria2);
      expect(again.server, '1.1.1.1');
      expect(again.dedupeKey, n.dedupeKey);
    });
  });
}
