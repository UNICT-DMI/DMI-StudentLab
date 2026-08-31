import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';

class DeveloperUiStyle {
  const DeveloperUiStyle._();

  static const double maxContentWidth = 1120;

  static BoxDecoration panelDecoration({
    Color? borderColor,
    double radius = 18,
  }) {
    return BoxDecoration(
      color: AppColors.eleganceMidnight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: (borderColor ?? AppColors.skyBlue)
            .withValues(alpha: 0.12),
      ),
    );
  }

  static BoxDecoration elevatedPanelDecoration({
    Color? borderColor,
    double radius = 18,
  }) {
    return BoxDecoration(
      color: AppColors.eleganceDeepNavy,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: (borderColor ?? AppColors.skyBlue)
            .withValues(alpha: 0.18),
      ),
    );
  }

  static TextStyle get sectionTitle => const TextStyle(
        color: AppColors.pureWhite,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get bodyMuted => TextStyle(
        color: AppColors.pureWhite.withValues(alpha: 0.52),
        fontSize: 11,
        height: 1.4,
      );

  static TextStyle get bodyStrong => const TextStyle(
        color: AppColors.pureWhite,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  static Color riskColor(String risk) {
    switch (risk.trim().toLowerCase()) {
      case 'critical':
        return Colors.redAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'medium':
        return Colors.amber;
      default:
        return AppColors.materialSky;
    }
  }

  static Color layerColor(String layer) {
    final String value = layer.trim().toLowerCase();

    if (value.contains('frontend')) {
      return AppColors.socialSky;
    }

    if (value.contains('service')) {
      return AppColors.materialSky;
    }

    if (value.contains('model') ||
        value.contains('database')) {
      return AppColors.availableGreen;
    }

    if (value.contains('security') ||
        value.contains('core')) {
      return Colors.amber;
    }

    if (value.contains('api')) {
      return AppColors.lavenderBlue;
    }

    return AppColors.skyBlue;
  }
}
