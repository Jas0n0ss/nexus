import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_vpn/core/core_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoreLocator.candidatePaths', () {
    test('includes sidecar and support cores for every platform', () {
      final paths = CoreLocator.candidatePaths(
        exeName: 'sing-box',
        exeDir: '/App/Contents/MacOS',
        supportDir: '/Users/x/Library/Containers/com.nexusvpn/Data/Library/Application Support',
        isMacOS: true,
        isLinux: false,
        isWindows: false,
        isAndroid: false,
      );

      expect(paths, contains('/App/Contents/MacOS/sing-box'));
      expect(paths, contains('/App/Contents/MacOS/cores/sing-box'));
      expect(
        paths,
        contains(
          '/Users/x/Library/Containers/com.nexusvpn/Data/Library/Application Support/cores/sing-box',
        ),
      );
      expect(paths, contains('/App/Contents/Resources/cores/sing-box'));
      expect(
        paths,
        contains(
          '/App/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/cores/sing-box',
        ),
      );
      expect(paths, contains('/opt/homebrew/bin/sing-box'));
    });

    test('linux includes deb flutter_assets layout', () {
      final paths = CoreLocator.candidatePaths(
        exeName: 'sing-box',
        exeDir: '/usr/lib/nexus-vpn',
        supportDir: '/home/u/.local/share',
        isMacOS: false,
        isLinux: true,
        isWindows: false,
        isAndroid: false,
      );
      expect(
        paths,
        contains('/usr/lib/nexus-vpn/data/flutter_assets/assets/cores/sing-box'),
      );
      expect(paths, contains('/usr/bin/sing-box'));
    });

    test('android checks files/sing-box (native extract path)', () {
      final paths = CoreLocator.candidatePaths(
        exeName: 'sing-box',
        exeDir: '/system/bin',
        supportDir: '/data/user/0/com.nexusvpn.nexus_vpn/files',
        isMacOS: false,
        isLinux: false,
        isWindows: false,
        isAndroid: true,
      );
      expect(
        paths,
        contains('/data/user/0/com.nexusvpn.nexus_vpn/files/sing-box'),
      );
      expect(
        paths,
        contains('/data/data/com.nexusvpn.nexus_vpn/files/sing-box'),
      );
    });

    test('windows uses .exe name', () {
      final paths = CoreLocator.candidatePaths(
        exeName: 'sing-box.exe',
        exeDir: r'C:\Program Files\NexusVPN',
        supportDir: r'C:\Users\x\AppData\Roaming',
        isMacOS: false,
        isLinux: false,
        isWindows: true,
        isAndroid: false,
      );
      expect(paths, contains(r'C:\Program Files\NexusVPN\sing-box.exe'));
      expect(paths, contains(r'C:\Program Files\NexusVPN\cores\sing-box.exe'));
    });
  });

  group('CoreLocator.extractAssetTo', () {
    test('writes asset bytes to destination', () async {
      final written = <String, List<int>>{};
      final locator = CoreLocator(
        assetLoader: (key) async {
          expect(key, startsWith('assets/cores/'));
          return ByteData.sublistView(Uint8List.fromList([0x7f, 0x45, 0x4c, 0x46]));
        },
        exists: (path) async => written.containsKey(path),
        writeExecutable: (path, bytes) async {
          written[path] = List<int>.from(bytes);
        },
      );

      final path = await locator.extractAssetTo('/tmp/cores/sing-box');
      expect(path, '/tmp/cores/sing-box');
      expect(written['/tmp/cores/sing-box'], [0x7f, 0x45, 0x4c, 0x46]);
    });

    test('returns null when asset missing', () async {
      final locator = CoreLocator(
        assetLoader: (key) async {
          throw Exception('Unable to load asset: $key');
        },
        exists: (_) async => false,
        writeExecutable: (_, __) async {},
      );
      final path = await locator.extractAssetTo('/tmp/cores/sing-box');
      expect(path, isNull);
    });
  });
}
