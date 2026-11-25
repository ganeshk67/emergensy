import 'package:flutter/material.dart';

/// Adds a quiet, section-specific visual treatment behind page content.
class SectionBackdrop extends StatelessWidget {
  const SectionBackdrop({
    required this.child,
    required this.icon,
    this.accent,
    super.key,
  });

  final Widget child;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = accent ?? colors.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        Positioned(
          top: -96,
          right: -82,
          child: IgnorePointer(
            child: Icon(
              icon,
              size: 280,
              color: tint.withValues(alpha: .045),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: -130,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    tint.withValues(alpha: .10),
                    tint.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
