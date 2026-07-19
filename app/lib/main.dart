import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
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
import 'providers/shell_nav.dart';
import 'core/singbox_runner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('nodes');
  await Hive.openBox('settings');
  await Hive.openBox('logs');

  if (!kIsWeb && _isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(900, 600));
    await windowManager.setSize(const Size(1100, 720));
    await windowManager.setTitle('Nexus VPN');
    await windowManager.center();
  }

  if (!kIsWeb && _isMobile) {
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
        ChangeNotifierProvider(create: (_) => ShellNav()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LogsProvider()),
        ChangeNotifierProvider(create: (_) => NodesProvider()),
        ChangeNotifierProxyProvider2<NodesProvider, SettingsProvider, VpnProvider>(
          create: (ctx) => VpnProvider(
            singboxRunner: SingboxRunner(),
            logsProvider: ctx.read<LogsProvider>(),
          )..bindSettings(ctx.read<SettingsProvider>()),
          update: (ctx, nodes, settings, vpn) {
            vpn!.bindSettings(settings);
            vpn.updateNodes(nodes);
            return vpn;
          },
        ),
      ],
      child: const NexusApp(),
    ),
  );
}

bool get _isDesktop {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

bool get _isMobile {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}
