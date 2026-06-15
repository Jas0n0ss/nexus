import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'providers/vpn_provider.dart';
import 'providers/nodes_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/logs_provider.dart';
import 'core/singbox_runner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive storage
  await Hive.initFlutter();
  await Hive.openBox('nodes');
  await Hive.openBox('settings');
  await Hive.openBox('logs');

  // Desktop window setup
  if (_isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(900, 600));
    await windowManager.setSize(const Size(1100, 720));
    await windowManager.setTitle('Nexus VPN');
    await windowManager.center();
  }

  // Lock to portrait on phones
  if (_isMobile) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LogsProvider()),
        ChangeNotifierProvider(create: (_) => NodesProvider()),
        ChangeNotifierProxyProvider<NodesProvider, VpnProvider>(
          create: (ctx) => VpnProvider(
            singboxRunner: SingboxRunner(),
            logsProvider: ctx.read<LogsProvider>(),
          ),
          update: (ctx, nodes, vpn) => vpn!..updateNodes(nodes),
        ),
      ],
      child: const NexusApp(),
    ),
  );
}

bool get _isDesktop =>
    identical(0, 0.0) == false || // always false, just platform check
    const bool.fromEnvironment('dart.library.io');

bool get _isMobile => !_isDesktop;
