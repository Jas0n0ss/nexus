import 'package:flutter/material.dart';

/// Consistent page container for every screen.
///
/// * Responsive horizontal padding: 16dp on phones, 28dp on desktop/tablet.
/// * Centers content and caps its width so cards never stretch across an
///   ultra-wide monitor (macOS / Windows / Linux desktops).
/// * [scroll] wraps the body in a [SingleChildScrollView] for content screens;
///   set it to false for screens that own a scrolling child (e.g. node list).
class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool scroll;
  final double extraBottom;

  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.scroll = true,
    this.extraBottom = 0,
  });

  /// Phones and small windows.
  static const double compactBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        final horizontal = compact ? 16.0 : 28.0;
        final top = compact ? 16.0 : 28.0;
        final bottom = (compact ? 24.0 : 36.0) + extraBottom;

        final padded = Padding(
          padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );

        return scroll ? SingleChildScrollView(child: padded) : padded;
      },
    );
  }
}
