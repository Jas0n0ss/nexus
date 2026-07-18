import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'providers/settings_provider.dart';

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Nexus VPN',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const MainShell(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F13) : const Color(0xFFF2F2F7);
    final surface = isDark ? const Color(0xFF1C1C24) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: const Color(0xFF3B82F6),
        onPrimary: Colors.white,
        secondary: const Color(0xFF6366F1),
        onSecondary: Colors.white,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.5),
        titleLarge:   TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.3),
        titleMedium:  TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 16),
        bodyMedium:   TextStyle(color: text.withOpacity(0.7), fontSize: 14),
        bodySmall:    TextStyle(color: text.withOpacity(0.45), fontSize: 12),
        labelSmall:   TextStyle(color: text.withOpacity(0.35), fontSize: 11, letterSpacing: 0.6),
      ),
      cardTheme: CardTheme(
        color: isDark ? const Color(0xFF1C1C24) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        hintStyle: TextStyle(color: text.withOpacity(0.3), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
