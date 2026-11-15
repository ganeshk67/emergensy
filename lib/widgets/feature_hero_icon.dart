import 'package:flutter/material.dart';

class FeatureHeroIcon extends StatelessWidget {
  const FeatureHeroIcon({
    required this.tag,
    required this.icon,
    this.size = 46,
    super.key,
  });

  final String tag;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withValues(alpha: .16),
                colors.tertiary.withValues(alpha: .22),
              ],
            ),
            borderRadius: BorderRadius.circular(size * .36),
          ),
          child: Icon(icon, color: colors.primary, size: size * .52),
        ),
      ),
    );
  }
}
