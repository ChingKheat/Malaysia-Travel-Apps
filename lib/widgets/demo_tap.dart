import 'package:flutter/material.dart';

import '../core/demo_feedback.dart';

class DemoTapCard extends StatelessWidget {
  const DemoTapCard({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = 18,
    this.margin,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap == null
              ? null
              : () {
                  demoHaptic();
                  onTap!();
                },
          child: child,
        ),
      ),
    );
  }
}

/// Computes quick-action tile width for 2–4 columns depending on screen size.
double quickActionWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  const horizontalPadding = 40.0;
  const spacing = 10.0;
  final columns = width < 360
      ? 2.0
      : width < 520
      ? 3.0
      : 4.0;
  final gaps = (columns - 1) * spacing;
  return ((width - horizontalPadding - gaps) / columns).clamp(96.0, 132.0);
}
