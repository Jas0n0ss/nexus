// Responsive layout regression test.
//
// Every screen must render without overflow (RenderFlex / RenderBox errors) on
// phone, tablet, laptop and ultra-wide desktop widths. This is what keeps the
// UI usable across macOS / Windows / Linux / Android / iOS in one codebase.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/core/singbox_runner.dart';
import 'package:nexus/providers/logs_provider.dart';
import 'package:nexus/providers/nodes_provider.dart';
import 'package:nexus/providers/session_provider.dart';
import 'package:nexus/providers/settings_provider.dart';
import 'package:nexus/providers/shell_nav.dart';
import 'package:nexus/providers/update_provider.dart';
import 'package:nexus/screens/dashboard_screen.dart';
import 'package:nexus/screens/import_screen.dart';
import 'package:nexus/screens/logs_screen.dart';
import 'package:nexus/screens/nodes_screen.dart';
import 'package:nexus/screens/settings_screen.dart';
import 'package:nexus/theme/nexus_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('nexus_responsive_test');
    Hive.init(dir.path);
    await Hive.openBox('nodes');
    await Hive.openBox('settings');
    await Hive.openBox('logs');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  final screens = <String, Widget>{
    'dashboard': const DashboardScreen(),
    'nodes': const NodesScreen(),
    'import': const ImportScreen(),
    'logs': const LogsScreen(),
    'settings': const SettingsScreen(),
  };

  // (label, width, height) — phone → ultra-wide
  const viewports = <(String, double, double)>[
    ('phone', 360, 780),
    ('tablet', 768, 1024),
    ('desktop', 1440, 900),
    ('ultrawide', 2560, 1440),
  ];

  for (final entry in screens.entries) {
    for (final vp in viewports) {
      testWidgets('${entry.key} renders at ${vp.$1} (${vp.$2.toInt()}dp)',
          (tester) async {
        SharedPreferences.setMockInitialValues({'autoUpdate': false});
        await tester.binding.setSurfaceSize(Size(vp.$2, vp.$3));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final logs = LogsProvider();
        final session = SessionProvider(
          singboxRunner: SingboxRunner(),
          logsProvider: logs,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ShellNav()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
              ChangeNotifierProvider(create: (_) => NodesProvider()),
              ChangeNotifierProvider(create: (_) => UpdateProvider()),
              ChangeNotifierProvider<LogsProvider>.value(value: logs),
              ChangeNotifierProvider<SessionProvider>.value(value: session),
            ],
            child: MaterialApp(
              theme: NexusTheme.light(),
              darkTheme: NexusTheme.dark(),
              home: entry.value,
            ),
          ),
        );
        // Let async provider loads (SharedPreferences / Hive) settle.
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} overflowed or threw at ${vp.$1} width',
        );
      });
    }
  }
}
