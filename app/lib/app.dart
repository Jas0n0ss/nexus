import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'providers/settings_provider.dart';
import 'theme/nexus_theme.dart';

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Nexus VPN',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: NexusTheme.light(),
      darkTheme: NexusTheme.dark(),
      home: const MainShell(),
    );
  }
}
