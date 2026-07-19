import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus/core/singbox_runner.dart';
import 'package:nexus/providers/logs_provider.dart';
import 'package:nexus/providers/session_provider.dart';
import 'package:nexus/providers/settings_provider.dart';
import 'package:nexus/providers/update_provider.dart';
import 'package:nexus/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings uses balanced sections and exposes online updates',
      (tester) async {
    SharedPreferences.setMockInitialValues({'autoUpdate': false});
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final logs = LogsProvider();
    final session = SessionProvider(
      singboxRunner: SingboxRunner(),
      logsProvider: logs,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('核心'), findsOneWidget);
    expect(find.text('自动化 · 高可用'), findsOneWidget);
    expect(find.text('应用与组件更新'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
