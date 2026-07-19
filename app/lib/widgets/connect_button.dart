import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/session_provider.dart';
import '../theme/nexus_theme.dart';

class ConnectButton extends StatelessWidget {
  final SessionState state;
  final VoidCallback onToggle;
  const ConnectButton({super.key, required this.state, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isOn = state == SessionState.connected;
    final isError = state == SessionState.error;
    final isLoading =
        state == SessionState.connecting || state == SessionState.disconnecting;
    final label = isLoading
        ? '…'
        : (isOn ? '断开' : '连接');

    final Color fill;
    final Color border;
    final Color fg;
    if (isOn) {
      fill = NexusColors.accent;
      border = NexusColors.accentDeep;
      fg = const Color(0xFF042F2E);
    } else if (isError) {
      fill = dark ? const Color(0xFF2A1A1C) : const Color(0xFFF8E8E9);
      border = NexusColors.danger;
      fg = NexusColors.danger;
    } else {
      fill = dark ? NexusColors.surfaceLift : const Color(0xFFE4ECF0);
      border = dark ? NexusColors.line : const Color(0x33102027);
      fg = dark ? NexusColors.textDim : NexusColors.lightText.withOpacity(0.7);
    }

    return GestureDetector(
      onTap: isLoading ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn ? null : fill,
          gradient: isOn
              ? const LinearGradient(
                  colors: [NexusColors.accent, NexusColors.accentDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          border: Border.all(color: border, width: 1.4),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: NexusColors.accent,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 28,
                      color: fg,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: fg,
                      ),
                    ),
                  ],
                ),
        ),
      )
          .animate(target: isOn ? 1 : 0)
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.05, 1.05),
            duration: 600.ms,
            curve: Curves.easeInOut,
          ),
    );
  }
}
