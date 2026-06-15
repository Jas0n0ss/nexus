import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/vpn_provider.dart';

class ConnectButton extends StatelessWidget {
  final VpnState state;
  final VoidCallback onToggle;
  const ConnectButton({super.key, required this.state, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isOn = state == VpnState.connected;
    final isLoading = state == VpnState.connecting || state == VpnState.disconnecting;

    return GestureDetector(
      onTap: isLoading ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isOn
              ? const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
              : LinearGradient(
                  colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.06)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: isOn ? [
            BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.4), blurRadius: 24, spreadRadius: 0),
          ] : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.power_settings_new_rounded,
                    size: 26, color: isOn ? Colors.white : Colors.white.withOpacity(0.4)),
                  const SizedBox(height: 2),
                  Text(isOn ? '断开' : '连接',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: isOn ? Colors.white : Colors.white.withOpacity(0.4))),
                ]),
        ),
      )
        .animate(target: isOn ? 1 : 0)
        .scale(begin: const Offset(1, 1), end: const Offset(1.04, 1.04)),
    );
  }
}
