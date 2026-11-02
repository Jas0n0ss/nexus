import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/node_parser.dart';
import 'package:nexus/core/config_generator.dart';
import 'package:nexus/core/autofix_engine.dart';
import 'package:nexus/models/proxy_node.dart';
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

  group('Real-world URI fixtures', () {
    final parser = NodeParser();
    const realityUri =
        'vless://06aad3ae-3e69-407e-8f49-ec0388d5b41f@20.2.114.89:4321'
        '?encryption=none&security=reality&flow=xtls-rprx-vision&type=tcp'
        '&sni=dash.cloudflare.com&pbk=zqeJ2aZnYNjcL88pqkKaeZ1oxAjcV6ZuAWydbyWYMwo'
        '&fp=chrome#233boy-reality-20.2.114.89';

    test('parses 233boy VLESS+REALITY URI end-to-end', () async {
      final r = await parser.parse(realityUri);
      expect(r.errors, isEmpty);
      expect(r.nodes.length, 1);
      final n = r.nodes.first;
      expect(n.protocol, Protocol.vless);
      expect(n.security, Security.reality);
      expect(n.server, '20.2.114.89');
      expect(n.port, 4321);
      expect(n.uuid, '06aad3ae-3e69-407e-8f49-ec0388d5b41f');
      expect(n.sni, 'dash.cloudflare.com');
      expect(n.publicKey, 'zqeJ2aZnYNjcL88pqkKaeZ1oxAjcV6ZuAWydbyWYMwo');
      expect(n.fingerprint, 'chrome');
      expect(n.flow, 'xtls-rprx-vision');
      expect(n.transport, Transport.tcp);
      expect(n.name, contains('233boy-reality'));
    });

    test('generates valid sing-box config with flow + reality', () async {
      final r = await parser.parse(realityUri);
      final cfg = ConfigGenerator.generate(r.nodes.first, tunMode: false);
      final ob = (cfg['outbounds'] as List).first as Map<String, dynamic>;
      expect(ob['type'], 'vless');
      expect(ob['server'], '20.2.114.89');
      expect(ob['server_port'], 4321);
      expect(ob['uuid'], '06aad3ae-3e69-407e-8f49-ec0388d5b41f');
      expect(ob['flow'], 'xtls-rprx-vision');
      final tls = ob['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'dash.cloudflare.com');
      expect((tls['utls'] as Map)['fingerprint'], 'chrome');
      final reality = tls['reality'] as Map<String, dynamic>;
      expect(reality['enabled'], true);
      expect(reality['public_key'], 'zqeJ2aZnYNjcL88pqkKaeZ1oxAjcV6ZuAWydbyWYMwo');
      // JSON must be serializable (what gets written to disk for the core)
      expect(jsonEncode(cfg), isNotEmpty);
    });

    test('roundtrip preserves flow through toJson/fromJson', () async {
      final r = await parser.parse(realityUri);
      final again = ProxyNode.fromJson(r.nodes.first.toJson());
      expect(again.flow, 'xtls-rprx-vision');
      expect(again.dedupeKey, r.nodes.first.dedupeKey);
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
