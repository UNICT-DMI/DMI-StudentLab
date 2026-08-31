import 'package:flutter/material.dart';

import '../theme/nightTheme.dart';

class StudentLabComingSoonBadge extends StatelessWidget {
  final String label;

  const StudentLabComingSoonBadge({
    super.key,
    this.label = 'IN ARRIVO',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.materialSky.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(
          9,
        ),
        border: Border.all(
          color: AppColors.materialSky.withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(
          color: AppColors.materialSky.withValues(
            alpha: 0.88,
          ),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}