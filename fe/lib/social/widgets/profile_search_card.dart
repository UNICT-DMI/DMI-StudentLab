import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../social_models.dart';

import 'studentlab_user_avatar.dart';

class StudentLabProfileSearchCard extends StatelessWidget {
  final SocialUser user;
  final String typeLabel;
  final Color accent;

  const StudentLabProfileSearchCard({
    super.key,
    required this.user,
    required this.typeLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final SocialAcademicPath? path = user.currentAcademicPath;

    final String university = _firstNotEmpty([
      path?.university ?? '',
      user.university,
    ]);

    final String department = _firstNotEmpty([
      path?.department ?? '',
      user.department,
    ]);

    final String course = _firstNotEmpty([
      path?.course ?? '',
      user.course,
    ]);

    final List<SocialAcademicTitle> titles = user.academicTitles
        .where((SocialAcademicTitle title) => title.isVerified)
        .toList();

    final List<SocialSubject> activeSubjects = user.subjects
        .where((SocialSubject subject) => subject.isActive)
        .toList();

    final bool canHelp = user.availableForHelp ||
        activeSubjects.any(
          (SocialSubject subject) => subject.canHelp,
        );

    final bool privateLessons = user.availableForPrivateLessons ||
        activeSubjects.any(
          (SocialSubject subject) =>
              subject.canGivePrivateLessons,
        );

    final bool hasAcademicOrigin =
        university.isNotEmpty ||
        department.isNotEmpty ||
        course.isNotEmpty;

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool compact =
            constraints.maxWidth < 360;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(
            compact ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color:
                AppColors.eleganceMidnight,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color:
                  accent.withValues(
                alpha:
                    0.18,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildHeader(
                compact:
                    compact,
              ),

              if (user.availableForHelp) ...[
                const SizedBox(
                  height:
                      12,
                ),

                const _AvailabilityStatus(),
              ],

              if (hasAcademicOrigin) ...[
                const SizedBox(
                  height:
                      16,
                ),

                const _SectionDivider(),

                const SizedBox(
                  height:
                      13,
                ),

                const _SectionTitle(
                  icon:
                      Icons.account_balance_outlined,
                  label:
                      'Provenienza accademica',
                ),

                const SizedBox(
                  height:
                      10,
                ),

                if (university.isNotEmpty)
                  _AcademicInfoRow(
                    label:
                        'Ateneo',
                    value:
                        university,
                  ),

                if (department.isNotEmpty)
                  _AcademicInfoRow(
                    label:
                        'Dipartimento',
                    value:
                        department,
                  ),

                if (course.isNotEmpty)
                  _AcademicInfoRow(
                    label:
                        'Corso',
                    value:
                        course,
                  ),
              ],

              if (titles.isNotEmpty) ...[
                const SizedBox(
                  height:
                      14,
                ),

                const _SectionDivider(),

                const SizedBox(
                  height:
                      13,
                ),

                const _SectionTitle(
                  icon:
                      Icons.workspace_premium_outlined,
                  label:
                      'Titoli conseguiti',
                ),

                const SizedBox(
                  height:
                      9,
                ),

                ...titles
                    .take(2)
                    .map(
                      (
                        SocialAcademicTitle title,
                      ) =>
                          Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom:
                              7,
                        ),
                        child:
                            _CompactInfoCard(
                          icon:
                              Icons.school_outlined,
                          text:
                              _titleLabel(
                            title,
                          ),
                        ),
                      ),
                    ),

                if (titles.length > 2)
                  Text(
                    '+${titles.length - 2} altri titoli',
                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withValues(
                        alpha:
                            0.40,
                      ),
                      fontSize:
                          9.5,
                    ),
                  ),
              ],

              if (activeSubjects.isNotEmpty) ...[
                const SizedBox(
                  height:
                      14,
                ),

                const _SectionDivider(),

                const SizedBox(
                  height:
                      13,
                ),

                const _SectionTitle(
                  icon:
                      Icons.menu_book_outlined,
                  label:
                      'Materie',
                ),

                const SizedBox(
                  height:
                      9,
                ),

                Wrap(
                  spacing:
                      7,
                  runSpacing:
                      7,
                  children:
                      activeSubjects
                          .take(4)
                          .map(
                            (
                              SocialSubject subject,
                            ) =>
                                _SubjectChip(
                              label:
                                  subject.name,
                            ),
                          )
                          .toList(),
                ),

                if (activeSubjects.length > 4) ...[
                  const SizedBox(
                    height:
                        7,
                  ),

                  Text(
                    '+${activeSubjects.length - 4} altre materie',
                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withValues(
                        alpha:
                            0.40,
                      ),
                      fontSize:
                          9.5,
                    ),
                  ),
                ],
              ],

              const SizedBox(
                height:
                    14,
              ),

              const _SectionDivider(),

              const SizedBox(
                height:
                    12,
              ),

              Wrap(
                spacing:
                    14,
                runSpacing:
                    8,
                children: [
                  _AvailabilityText(
                    icon:
                        Icons.volunteer_activism_outlined,
                    label:
                        canHelp
                            ? 'Disponibile ad aiutare'
                            : 'Aiuto non disponibile',
                    enabled:
                        canHelp,
                  ),

                  _AvailabilityText(
                    icon:
                        Icons.school_outlined,
                    label:
                        privateLessons
                            ? 'Lezioni private'
                            : 'Niente lezioni private',
                    enabled:
                        privateLessons,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader({
    required bool compact,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        StudentLabUserAvatar(
          type:
              user.type,
          radius:
              compact ? 24 : 27,
        ),

        const SizedBox(
          width:
              12,
        ),

        Expanded(
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                user.name.isEmpty
                    ? 'Utente StudentLab'
                    : user.name,
                maxLines:
                    1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      AppColors.pureWhite,
                  fontSize:
                      16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              if (user.email.trim().isNotEmpty) ...[
                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  user.email.trim(),
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withValues(
                      alpha:
                          0.44,
                    ),
                    fontSize:
                        10.5,
                  ),
                ),
              ],

              const SizedBox(
                height:
                    5,
              ),

              Text(
                _roleLabel(),
                style:
                    TextStyle(
                  color:
                      accent,
                  fontSize:
                      10,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width:
              8,
        ),

        const Padding(
          padding:
              EdgeInsets.only(
            top:
                5,
          ),
          child:
              Icon(
            Icons.arrow_forward_ios_rounded,
            color:
                Colors.white30,
            size:
                14,
          ),
        ),
      ],
    );
  }

  String _roleLabel() {
    switch (
      user.role
          .trim()
          .toLowerCase()
    ) {
      case 'creator':
        return 'Creator';

      case 'admin':
        return 'Amministratore';

      case 'devsyst':
        return 'Developer';

      case 'teacher':
        return user.isVerifiedTeacher
            ? 'Docente verificato'
            : typeLabel;

      default:
        return typeLabel;
    }
  }

  String _titleLabel(
    SocialAcademicTitle title,
  ) {
    final List<String> values = [
      title.titleTypeLabel,
      title.course,
    ]
        .map(
          (
            String value,
          ) =>
              value.trim(),
        )
        .where(
          (
            String value,
          ) =>
              value.isNotEmpty,
        )
        .toList();

    return values.isEmpty
        ? 'Titolo accademico'
        : values.join(
            ' · ',
          );
  }

  String _firstNotEmpty(
    List<String> values,
  ) {
    for (
      final String value in values
    ) {
      if (
        value.trim().isNotEmpty
      ) {
        return value.trim();
      }
    }

    return '';
  }
}

class _AvailabilityStatus
    extends StatelessWidget {
  const _AvailabilityStatus();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        SizedBox(
          width:
              8,
          height:
              8,
          child:
              DecoratedBox(
            decoration:
                BoxDecoration(
              color:
                  Colors.greenAccent,
              shape:
                  BoxShape.circle,
            ),
          ),
        ),

        SizedBox(
          width:
              6,
        ),

        Text(
          'Disponibile',
          style:
              TextStyle(
            color:
                Colors.greenAccent,
            fontSize:
                11,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SectionDivider
    extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height:
          1,
      color:
          AppColors.pureWhite
              .withValues(
        alpha:
            0.07,
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size:
              15,
          color:
              AppColors.materialSky,
        ),

        const SizedBox(
          width:
              7,
        ),

        Text(
          label,
          style:
              const TextStyle(
            color:
                AppColors.pureWhite,
            fontSize:
                11.5,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AcademicInfoRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _AcademicInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom:
            7,
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width:
                86,
            child:
                Text(
              label,
              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withValues(
                  alpha:
                      0.38,
                ),
                fontSize:
                    9.5,
              ),
            ),
          ),

          const SizedBox(
            width:
                6,
          ),

          Expanded(
            child:
                Text(
              value,
              maxLines:
                  2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withValues(
                  alpha:
                      0.70,
                ),
                fontSize:
                    10.5,
                height:
                    1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactInfoCard
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CompactInfoCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,
        vertical:
            8,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withValues(
            alpha:
                0.08,
          ),
        ),
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            size:
                13,
            color:
                AppColors.materialSky,
          ),

          const SizedBox(
            width:
                7,
          ),

          Expanded(
            child:
                Text(
              text,
              maxLines:
                  2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withValues(
                  alpha:
                      0.68,
                ),
                fontSize:
                    10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectChip
    extends StatelessWidget {
  final String label;

  const _SubjectChip({
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String value =
        label.trim();

    if (
      value.isEmpty
    ) {
      return const SizedBox.shrink();
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            8,
        vertical:
            5,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.skyBlue
                .withValues(
          alpha:
              0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          9,
        ),
      ),
      child:
          Text(
        value,
        style:
            const TextStyle(
          color:
              AppColors.materialSky,
          fontSize:
              9.5,
          fontWeight:
              FontWeight.w500,
        ),
      ),
    );
  }
}

class _AvailabilityText
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;

  const _AvailabilityText({
    required this.icon,
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color color =
        enabled
            ? AppColors.materialSky
            : AppColors.pureWhite
                .withValues(
                alpha:
                    0.30,
              );

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size:
              13,
          color:
              color,
        ),

        const SizedBox(
          width:
              5,
        ),

        Text(
          label,
          style:
              TextStyle(
            color:
                color,
            fontSize:
                9.5,
            fontWeight:
                enabled
                    ? FontWeight.w600
                    : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}