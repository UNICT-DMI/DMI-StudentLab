import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';

import '../models/study_group.dart';

class StudyGroupCard extends StatelessWidget {
  final StudyGroup group;
  final VoidCallback onTap;

  const StudyGroupCard({
    super.key,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool compact =
            constraints.maxWidth < 220;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                compact ? 13 : 16,
              ),
              decoration: BoxDecoration(
                color:
                    AppColors.eleganceMidnight,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.skyBlue
                      .withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: compact ? 42 : 46,
                        height: compact ? 42 : 46,
                        decoration: BoxDecoration(
                          color: AppColors
                              .brandNightBlue,
                          borderRadius:
                              BorderRadius.circular(
                            13,
                          ),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color:
                              AppColors.skyBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          group.name.isEmpty
                              ? 'Gruppo senza nome'
                              : group.name,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                AppColors.pureWhite,
                            fontSize:
                                compact ? 14 : 16,
                            fontWeight:
                                FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      const Icon(
                        Icons
                            .chevron_right_rounded,
                        color: Colors.white38,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _Badge(
                        icon: group.isPrivate
                            ? Icons
                                .lock_outline_rounded
                            : Icons.public_rounded,
                        label:
                            group.visibilityLabel,
                      ),
                      if (group.isOwner)
                        const _Badge(
                          icon: Icons
                              .workspace_premium_outlined,
                          label: 'Owner',
                        ),
                      if (!group.isOwner &&
                          group.isAdmin)
                        const _Badge(
                          icon: Icons
                              .admin_panel_settings_outlined,
                          label: 'Admin',
                        ),
                    ],
                  ),
                  if (group.creatorName
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 11,
                    ),
                    _InfoRow(
                      icon:
                          Icons.person_outline_rounded,
                      text:
                          'Creato da ${group.creatorName}',
                    ),
                  ],
                  if (group.university
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 8,
                    ),
                    _InfoRow(
                      icon: Icons
                          .account_balance_outlined,
                      text: group.university,
                    ),
                  ],
                  if (group.department
                          .trim()
                          .isNotEmpty ||
                      group.course
                          .trim()
                          .isNotEmpty) ...[
                    const SizedBox(
                      height: 7,
                    ),
                    _InfoRow(
                      icon:
                          Icons.school_outlined,
                      text: _academicPath(),
                    ),
                  ],
                  if (group.subject
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 7,
                    ),
                    _InfoRow(
                      icon:
                          Icons.menu_book_outlined,
                      text: group.subject,
                      highlighted: true,
                    ),
                  ],
                  const SizedBox(
                    height: 12,
                  ),
                  Expanded(
                    child: Text(
                      group.description
                              .trim()
                              .isEmpty
                          ? 'Nessuna descrizione.'
                          : group.description,
                      maxLines: compact ? 2 : 3,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.pureWhite
                            .withValues(
                          alpha: 0.50,
                        ),
                        fontSize:
                            compact ? 10 : 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Row(
                    children: [
                      _Counter(
                        icon: Icons
                            .people_outline_rounded,
                        value:
                            '${group.memberCount}',
                        label: 'membri',
                      ),
                      const SizedBox(
                        width: 14,
                      ),
                      _Counter(
                        icon:
                            Icons.folder_outlined,
                        value:
                            '${group.materialCount}',
                        label: 'materiali',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _academicPath() {
    final List<String> values = [
      group.department.trim(),
      group.course.trim(),
    ].where((String value) => value.isNotEmpty).toList();

    return values.isEmpty
        ? 'Percorso non specificato'
        : values.join(' • ');
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.skyBlue
            .withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.skyBlue
              .withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color:
                AppColors.materialSky,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style: const TextStyle(
              color:
                  AppColors.materialSky,
              fontSize: 9,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlighted;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 14,
          color: highlighted
              ? AppColors.materialSky
              : AppColors.pureWhite
                  .withValues(alpha: 0.42),
        ),
        const SizedBox(
          width: 7,
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              color: highlighted
                  ? AppColors.materialSky
                  : AppColors.pureWhite
                      .withValues(alpha: 0.58),
              fontSize: 10,
              fontWeight: highlighted
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Counter({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color:
              AppColors.materialSky,
          size: 15,
        ),
        const SizedBox(
          width: 5,
        ),
        Text(
          '$value $label',
          style: TextStyle(
            color: AppColors.pureWhite
                .withValues(alpha: 0.58),
            fontSize: 9,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ],
    );
  }
}