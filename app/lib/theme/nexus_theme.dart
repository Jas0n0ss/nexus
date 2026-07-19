import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Graphite tide design tokens — see `.cursor/skills/nexus-ui/SKILL.md`.
abstract final class NexusColors {
  static const bgDeep = Color(0xFF0B1014);
  static const bgMid = Color(0xFF121A21);
  static const surface = Color(0xFF18232C);
  static const surfaceLift = Color(0xFF1E2C38);
  static const line = Color(0x1AE8F0F5);
  static const text = Color(0xFFE8F0F5);
  static const textDim = Color(0x8CE8F0F5);
  static const textFaint = Color(0x57E8F0F5);
  static const accent = Color(0xFF2DD4BF);
  static const accentDeep = Color(0xFF0F766E);
  static const ok = Color(0xFF3DDC97);
  static const warn = Color(0xFFE8B84A);
  static const danger = Color(0xFFF07178);

  // Light
  static const lightBg = Color(0xFFEEF3F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF102027);
}

abstract final class NexusTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? NexusColors.bgDeep : NexusColors.lightBg;
    final surface = dark ? NexusColors.surface : NexusColors.lightSurface;
    final on = dark ? NexusColors.text : NexusColors.lightText;

    final display = GoogleFonts.syneTextTheme();
    final body = GoogleFonts.ibmPlexSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: NexusColors.accent,
        onPrimary: const Color(0xFF042F2E),
        secondary: NexusColors.accentDeep,
        onSecondary: Colors.white,
        error: NexusColors.danger,
        onError: Colors.white,
        surface: surface,
        onSurface: on,
      ),
      textTheme: TextTheme(
        displayLarge: display.displayLarge?.copyWith(
          color: on,
          fontWeight: FontWeight.w700,
          fontSize: 30,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        titleLarge: display.titleLarge?.copyWith(
          color: on,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.4,
        ),
        titleMedium: body.titleMedium?.copyWith(
          color: on,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: body.bodyMedium?.copyWith(
          color: dark ? NexusColors.textDim : on.withOpacity(0.72),
          fontSize: 14,
          height: 1.45,
        ),
        bodySmall: body.bodySmall?.copyWith(
          color: dark ? NexusColors.textFaint : on.withOpacity(0.5),
          fontSize: 12,
        ),
        labelSmall: body.labelSmall?.copyWith(
          color: dark ? NexusColors.textFaint : on.withOpacity(0.4),
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: NexusColors.line,
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((s) {
          if (s.contains(MaterialState.selected)) return NexusColors.accent;
          return dark ? const Color(0xFF6B7C88) : const Color(0xFF90A0AB);
        }),
        trackColor: MaterialStateProperty.resolveWith((s) {
          if (s.contains(MaterialState.selected)) {
            return NexusColors.accent.withOpacity(0.35);
          }
          return dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? NexusColors.surfaceLift : const Color(0xFFE4ECF0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NexusColors.accent, width: 1.4),
        ),
        hintStyle: TextStyle(
          color: dark ? NexusColors.textFaint : on.withOpacity(0.35),
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NexusColors.accent,
          foregroundColor: const Color(0xFF042F2E),
          textStyle: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: on,
          side: BorderSide(color: on.withOpacity(0.16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? NexusColors.bgMid : NexusColors.lightSurface,
        indicatorColor: NexusColors.accent.withOpacity(0.18),
        labelTextStyle: MaterialStatePropertyAll(
          body.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
        ),
      ),
    );
  }
}

/// Solid themed scaffold background used across the app.
class NexusAtmosphere extends StatelessWidget {
  final Widget child;
  const NexusAtmosphere({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? NexusColors.bgDeep : NexusColors.lightBg,
      child: child,
    );
  }
}
