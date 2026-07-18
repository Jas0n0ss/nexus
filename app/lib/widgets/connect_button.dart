import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/vpn_provider.dart';
import '../theme/nexus_theme.dart';

class ConnectButton extends StatelessWidget {
  final VpnState state;
  final VoidCallback onToggle;
  const ConnectButton({super.key, required this.state, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isOn = state == VpnState.connected;
    final isLoading =
        state == VpnState.connecting || state == VpnState.disconnecting;
    final label = isLoading
        ? (state == VpnState.connecting ? '…' : '…')
        : (isOn ? '断开' : '连接');

    return GestureDetector(
      onTap: isLoading ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isOn
              ? const LinearGradient(
                  colors: [NexusColors.accent, NexusColors.accentDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.10),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
          border: Border.all(
            color: isOn
                ? NexusColors.accent.withOpacity(0.55)
                : Colors.white.withOpacity(0.14),
            width: 1.2,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: NexusColors.accent.withOpacity(0.28),
                    blurRadius: 28,
                    spreadRadius: 0,
                  ),
                ]
              : null,
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
                      color: isOn ? const Color(0xFF042F2E) : NexusColors.textDim,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: isOn ? const Color(0xFF042F2E) : NexusColors.textDim,
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
