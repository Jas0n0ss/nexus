import 'package:flutter/material.dart';
import '../theme/nexus_theme.dart';

/// Interactive surface — use only when the container is itself a control or list unit.
class NexusSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final double radius;
  final VoidCallback? onTap;

  const NexusSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.gradient,
    this.radius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = color ??
        (dark ? NexusColors.surface : NexusColors.lightSurface);
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? fill : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? NexusColors.line),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
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
    super.color,
  }) : super(padding: padding);
}
