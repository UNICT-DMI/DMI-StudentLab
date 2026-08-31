import 'package:flutter/material.dart';

import '../../../theme/nightTheme.dart';

import '../models/developer_models.dart';
import 'developer_status_badges.dart';

class DeveloperTreeView extends StatelessWidget {
  final DeveloperTreeNode root;
  final ValueChanged<DeveloperTreeNode> onNodeTap;

  const DeveloperTreeView({
    super.key,
    required this.root,
    required this.onNodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Node(
      node: root,
      depth: 0,
      onNodeTap: onNodeTap,
      initiallyExpanded: true,
    );
  }
}

class _Node extends StatelessWidget {
  final DeveloperTreeNode node;
  final int depth;
  final ValueChanged<DeveloperTreeNode> onNodeTap;
  final bool initiallyExpanded;

  const _Node({
    required this.node,
    required this.depth,
    required this.onNodeTap,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFolder =
        node.type == DeveloperNodeType.folder;

    if (!isFolder) {
      return Padding(
        padding: EdgeInsets.only(
          left: depth * 10.0,
          bottom: 7,
        ),
        child: InkWell(
          onTap: () => onNodeTap(node),
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.eleganceDeepNavy,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: node.securityCritical
                    ? Colors.redAccent.withValues(alpha: 0.16)
                    : AppColors.skyBlue.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brandNightBlue,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _fileIcon(node.name),
                    color: node.securityCritical
                        ? Colors.redAccent
                        : AppColors.skyBlue,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      DeveloperStatusBadges(
                        documented: node.documented,
                        outdated: node.outdated,
                        changed: node.changed,
                        securityCritical:
                            node.securityCritical,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                if (node.functionCount != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandNightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${node.functionCount} fn',
                      style: const TextStyle(
                        color: AppColors.materialSky,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.fromLTRB(
          8.0 + depth * 8,
          0,
          8,
          0,
        ),
        childrenPadding: EdgeInsets.zero,
        collapsedIconColor: Colors.white38,
        iconColor: AppColors.skyBlue,
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.brandNightBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.folder_outlined,
            color: AppColors.skyBlue,
            size: 18,
          ),
        ),
        title: Text(
          node.name,
          style: const TextStyle(
            color: AppColors.pureWhite,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: node.children
            .map(
              (DeveloperTreeNode child) => _Node(
                node: child,
                depth: depth + 1,
                onNodeTap: onNodeTap,
              ),
            )
            .toList(),
      ),
    );
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.dart')) {
      return Icons.flutter_dash_outlined;
    }

    if (name.endsWith('.py')) {
      return Icons.code_rounded;
    }

    if (name.endsWith('.md') ||
        name.endsWith('.txt')) {
      return Icons.description_outlined;
    }

    if (name.endsWith('.json')) {
      return Icons.data_object_rounded;
    }

    return Icons.insert_drive_file_outlined;
  }
}
