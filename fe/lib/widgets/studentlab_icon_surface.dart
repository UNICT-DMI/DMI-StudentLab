import 'package:flutter/material.dart';

import '../theme/nightTheme.dart';

class StudentLabIconSurface extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final Color accent;
  final double size;
  final double iconSize;
  final double borderRadius;

  const StudentLabIconSurface({
    super.key,
    this.icon,
    this.child,
    this.accent = AppColors.adminCyan,
    this.size = 44,
    this.iconSize = 22,
    this.borderRadius = 13,
  }) : assert(
          icon != null || child != null,
          'Serve icon oppure child.',
        );

  @override
  Widget build(BuildContext context) {
    final double innerRadius =
        borderRadius > 1.5 ? borderRadius - 1.5 : borderRadius;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.adminIconGradient,
          borderRadius: BorderRadius.circular(
            borderRadius,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            1.5,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.adminDarkSurfaceGradient,
              borderRadius: BorderRadius.circular(
                innerRadius,
              ),
            ),
            child: Center(
              child: child ??
                  Icon(
                    icon,
                    color: accent,
                    size: iconSize,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}