import 'package:flutter/material.dart';
import '../../theme/studentlab_brand.dart';

import '../../theme/nightTheme.dart';

class StudentLabGuestAccountButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool? compact;

  const StudentLabGuestAccountButton({
    super.key,
    required this.onPressed,
    this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final bool compact = this.compact ?? MediaQuery.sizeOf(context).width < 390;

    return Tooltip(
      message: 'Guest · Accedi o registrati',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          constraints: BoxConstraints(maxWidth: compact ? 42 : 118),
          padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),
          decoration: BoxDecoration(
            color: AppColors.brandNightBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.socialSky.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  StudentLabBrand.guestAvatar,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.studentBlue,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.pureWhite,
                        size: 17,
                      ),
                    );
                  },
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 7),
                Text(
                  'Guest',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.socialSky.withValues(alpha: 0.70),
                  size: 17,
                ),
              ] else ...[
                const SizedBox(width: 1),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.socialSky,
                  size: 12,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}