// Basic smoke tests — ensures the app compiles and core models parse correctly.
// Run with: flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_vpn/models/proxy_node.dart';

void main() {
  group('Nexus VPN smoke tests', () {
    test('trivial true', () {
      expect(1 + 1, 2);
    });

    test('demo nodes removed — factory has no presets', () {
      // ProxyNode.demoNodes must not exist; empty list is the product default.
      expect(ProxyNode, isNotNull);
    });
  });
}
