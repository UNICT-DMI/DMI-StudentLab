import 'package:flutter/material.dart';

import '../../../theme/nightTheme.dart';

class DeveloperStatusBadges extends StatelessWidget {
  final bool documented;
  final bool outdated;
  final bool changed;
  final bool securityCritical;
  final bool compact;

  const DeveloperStatusBadges({
    super.key,
    required this.documented,
    required this.outdated,
    required this.changed,
    required this.securityCritical,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> badges = <Widget>[];

    if (documented) {
      badges.add(
        _StatusBadge(
          icon: Icons.verified_outlined,
          label: compact ? 'DOC' : 'DOCUMENTED',
          color: Colors.greenAccent,
          compact: compact,
        ),
      );
    } else {
      badges.add(
        _StatusBadge(
          icon: Icons.radio_button_unchecked_rounded,
          label: compact ? 'N/A' : 'NOT ANALYZED',
          color: Colors.white38,
          compact: compact,
        ),
      );
    }

    if (outdated) {
      badges.add(
        _StatusBadge(
          icon: Icons.warning_amber_rounded,
          label: compact ? 'OLD' : 'OUTDATED',
          color: Colors.amber,
          compact: compact,
        ),
      );
    }

    if (changed) {
      badges.add(
        _StatusBadge(
          icon: Icons.change_circle_outlined,
          label: compact ? 'CHG' : 'CHANGED',
          color: AppColors.materialSky,
          compact: compact,
        ),
      );
    }

    if (securityCritical) {
      badges.add(
        _StatusBadge(
          icon: Icons.lock_outline_rounded,
          label: compact ? 'SEC' : 'SECURITY CRITICAL',
          color: Colors.redAccent,
          compact: compact,
        ),
      );
    }

    return Wrap(
      spacing: compact ? 5 : 7,
      runSpacing: compact ? 5 : 7,
      children: badges,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 9 : 11,
            color: color,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 7 : 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
