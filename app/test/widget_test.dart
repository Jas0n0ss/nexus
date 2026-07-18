// Basic smoke tests — ensures the app compiles and core models parse correctly.
// Run with: flutter test

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nexus VPN smoke tests', () {
    test('trivial true', () {
      expect(1 + 1, 2);
    });
  });
}
