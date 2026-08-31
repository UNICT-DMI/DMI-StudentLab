import 'package:flutter/material.dart';

import '../../../theme/nightTheme.dart';

import '../models/developer_models.dart';
import '../theme/developer_ui_style.dart';

class DeveloperRelationTile extends StatelessWidget {
  final DeveloperRelation relation;
  final VoidCallback? onTap;

  const DeveloperRelationTile({
    super.key,
    required this.relation,
    this.onTap,
  });

  IconData get icon => switch (relation.type) {
        DeveloperRelationType.calls =>
          Icons.call_made_rounded,
        DeveloperRelationType.calledBy =>
          Icons.call_received_rounded,
        DeveloperRelationType.usesModel =>
          Icons.storage_outlined,
        DeveloperRelationType.usesConfig =>
          Icons.tune_rounded,
        DeveloperRelationType.frontend =>
          Icons.phone_android_rounded,
        DeveloperRelationType.flow =>
          Icons.account_tree_outlined,
        DeveloperRelationType.security =>
          Icons.shield_outlined,
        DeveloperRelationType.endpoint =>
          Icons.api_outlined,
        DeveloperRelationType.imports =>
          Icons.input_rounded,
        DeveloperRelationType.contains =>
          Icons.account_tree_rounded,
        DeveloperRelationType.unknown =>
          Icons.link_rounded,
      };

  Color get accentColor {
    switch (relation.type) {
      case DeveloperRelationType.security:
        return Colors.redAccent;
      case DeveloperRelationType.calls:
      case DeveloperRelationType.calledBy:
        return AppColors.materialSky;
      case DeveloperRelationType.imports:
      case DeveloperRelationType.contains:
        return AppColors.lavenderBlue;
      case DeveloperRelationType.usesModel:
        return AppColors.availableGreen;
      default:
        return AppColors.skyBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String target = relation.targetFunction == null
        ? relation.targetPath
        : '${relation.targetPath} → '
            '${relation.targetFunction}()';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: DeveloperUiStyle.panelDecoration(
          borderColor: accentColor,
          radius: 13,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.brandNightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 17,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    relation.label,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    target,
                    style: DeveloperUiStyle.bodyMuted,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white30,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
