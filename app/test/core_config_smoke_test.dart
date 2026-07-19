import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/config_generator.dart';
import 'package:nexus/core/node_parser.dart';
import 'package:nexus/models/proxy_node.dart';

const _syntheticRealityUri =
    'vless://11111111-2222-3333-4444-555555555555@198.51.100.10:443'
    '?encryption=none&security=reality&flow=xtls-rprx-vision&type=tcp'
    '&sni=www.example.com&pbk=j-MkJ1h6tFY1eE_Dp0FRNz1IyFX5jD-Jfph3gTF-cFw'
    '&fp=chrome#ci-reality-smoke';

void main() {
  test('Reality URI produces sing-box-checkable desktop configs', () async {
    final liveUri = Platform.environment['NEXUS_E2E_TEST_URI']?.trim();
    final input =
        liveUri == null || liveUri.isEmpty ? _syntheticRealityUri : liveUri;
    final parsed = await NodeParser().parse(input);

    expect(parsed.errors, isEmpty);
    expect(parsed.nodes, hasLength(1));
    final node = parsed.nodes.single;
    expect(node.protocol, Protocol.vless);
    expect(node.security, Security.reality);
    expect(node.transport, Transport.tcp);
    expect(node.uuid, isNotEmpty);
    expect(node.publicKey, isNotEmpty);
    expect(node.sni, isNotEmpty);

    final output = Directory('build/app-smoke');
    await output.create(recursive: true);

    for (final entry in <(String, bool)>[
      ('config-proxy.json', false),
      ('config-tun.json', true),
    ]) {
      final config = ConfigGenerator.generate(
        node,
        tunMode: entry.$2,
        routeMode: 'global',
        blockAds: false,
        allowLan: false,
        mixedPort: 17890,
      );

      final routeRuleSets = config['route']['rule_set'] as List;
      final dnsRules = config['dns']['rules'] as List;
      expect(routeRuleSets, isEmpty);
      expect(
        dnsRules.where((rule) => rule.containsKey('rule_set')),
        isEmpty,
        reason: 'global mode must not reference undefined rule sets',
      );

      final file = File('${output.path}/${entry.$1}');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config),
      );
    }
  });
}
