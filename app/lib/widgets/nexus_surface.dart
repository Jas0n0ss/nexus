import 'package:flutter/material.dart';
import '../theme/nexus_theme.dart';

/// Interactive surface — use only when the container is itself a control or list unit.
class NexusSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Gradient? gradient;
  final double radius;
  final VoidCallback? onTap;

  const NexusSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.gradient,
    this.radius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? (dark ? NexusColors.surface.withOpacity(0.92) : Colors.white.withOpacity(0.9))
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? NexusColors.line),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: box,
      ),
    );
  }
}

/// Back-compat alias used by older call sites.
class GlassCard extends NexusSurface {
  const GlassCard({
    super.key,
    required super.child,
    EdgeInsets? padding,
    super.gradient,
    super.borderColor,
  }) : super(padding: padding);
}
