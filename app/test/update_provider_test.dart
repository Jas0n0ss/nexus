import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/providers/update_provider.dart';

void main() {
  group('UpdateProvider version comparison', () {
    test('detects a newer minor release', () {
      expect(UpdateProvider.isNewerVersion('0.16.0', '0.15.0'), isTrue);
    });

    test('does not offer the same or older version', () {
      expect(UpdateProvider.isNewerVersion('v1.2.0', '1.2.0'), isFalse);
      expect(UpdateProvider.isNewerVersion('1.1.9', '1.2.0'), isFalse);
    });

    test('supports major increments and missing patch components', () {
      expect(UpdateProvider.isNewerVersion('2.0', '1.9.9'), isTrue);
      expect(UpdateProvider.isNewerVersion(null, '1.0.0'), isFalse);
    });
  });
}
