import 'package:flutter/material.dart';

import '../social_models.dart';


class ReviewCard extends StatelessWidget {
  final SocialReview review;

  final bool showModerationStatus;

  final VoidCallback? onTap;

  final EdgeInsetsGeometry margin;


  const ReviewCard({
    super.key,
    required this.review,
    this.showModerationStatus = false,
    this.onTap,
    this.margin = EdgeInsets.zero,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(
      context,
    );

    final ColorScheme colors =
        theme.colorScheme;

    final SocialAcademicPath? path =
        review.reviewerAcademicPath;

    final String academicContext =
        _academicContext(
      path,
    );

    final Widget content =
        Container(
      margin:
          margin,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              colors.outlineVariant
                  .withValues(
            alpha:
                0.45,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withValues(
              alpha:
                  0.06,
            ),
            blurRadius:
                18,
            offset:
                const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _ReviewerAvatar(
                review:
                    review,
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
                      review.authorName.isNotEmpty
                          ? review.authorName
                          : 'Utente',
                      maxLines:
                          1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height:
                          2,
                    ),

                    Text(
                      _roleLabel(
                        review.reviewerRole,
                      ),
                      style:
                          theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                        color:
                            colors.onSurfaceVariant,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),

                    if (
                      academicContext
                          .isNotEmpty
                    ) ...[
                      const SizedBox(
                        height:
                            4,
                      ),

                      Text(
                        academicContext,
                        maxLines:
                            2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                          color:
                              colors.onSurfaceVariant,
                          height:
                              1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (
                showModerationStatus
              ) ...[
                const SizedBox(
                  width:
                      8,
                ),

                _ModerationBadge(
                  status:
                      review.moderationStatus,
                ),
              ],
            ],
          ),

          const SizedBox(
            height:
                16,
          ),

          Row(
            children: [
              _RatingStars(
                rating:
                    review.rating,
              ),

              const SizedBox(
                width:
                    8,
              ),

              Text(
                review.rating
                    .toStringAsFixed(
                  1,
                ),
                style:
                    theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          if (
            review.subject !=
                null
          ) ...[
            const SizedBox(
              height:
                  14,
            ),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    12,
                vertical:
                    7,
              ),
              decoration:
                  BoxDecoration(
                color:
                    colors.primaryContainer
                        .withValues(
                  alpha:
                      0.55,
                ),
                borderRadius:
                    BorderRadius.circular(
                  999,
                ),
              ),
              child:
                  Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size:
                        16,
                    color:
                        colors.onPrimaryContainer,
                  ),

                  const SizedBox(
                    width:
                        6,
                  ),

                  Flexible(
                    child:
                        Text(
                      _subjectLabel(
                        review.subject!,
                      ),
                      maxLines:
                          1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                        color:
                            colors.onPrimaryContainer,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (
            review.comment
                .trim()
                .isNotEmpty
          ) ...[
            const SizedBox(
              height:
                  16,
            ),

            Text(
              review.comment.trim(),
              style:
                  theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                height:
                    1.5,
              ),
            ),
          ],

          if (
            review.createdAt !=
                null
          ) ...[
            const SizedBox(
              height:
                  16,
            ),

            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size:
                      15,
                  color:
                      colors.onSurfaceVariant,
                ),

                const SizedBox(
                  width:
                      5,
                ),

                Text(
                  _formatDate(
                    review.createdAt!,
                  ),
                  style:
                      theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color:
          Colors.transparent,
      child:
          InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child:
            content,
      ),
    );
  }


  String _academicContext(
    SocialAcademicPath? path,
  ) {
    if (path == null) {
      return '';
    }

    final List<String> values =
        [];

    final String course =
        path.course.trim();

    final String department =
        path.department.trim();

    final String university =
        path.university.trim();

    if (course.isNotEmpty) {
      values.add(
        course,
      );
    }

    if (
      department.isNotEmpty &&
      department != course
    ) {
      values.add(
        department,
      );
    }

    if (university.isNotEmpty) {
      values.add(
        university,
      );
    }

    return values.join(
      ' • ',
    );
  }


  String _subjectLabel(
    ReviewSubject subject,
  ) {
    final String code =
        subject.code.trim();

    final String name =
        subject.name.trim();

    if (
      code.isNotEmpty &&
      name.isNotEmpty
    ) {
      return '$code • $name';
    }

    if (name.isNotEmpty) {
      return name;
    }

    if (code.isNotEmpty) {
      return code;
    }

    return 'Materia';
  }


  String _roleLabel(
    String role,
  ) {
    switch (
        role
            .trim()
            .toLowerCase()) {
      case 'teacher':
        return 'Docente';

      case 'admin':
        return 'Amministratore';

      case 'creator':
        return 'Creator';

      case 'student':
      default:
        return 'Studente';
    }
  }


  String _formatDate(
    DateTime date,
  ) {
    final DateTime localDate =
        date.toLocal();

    final String day =
        localDate.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String month =
        localDate.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${localDate.year}';
  }
}


class _ReviewerAvatar
    extends StatelessWidget {
  final SocialReview review;


  const _ReviewerAvatar({
    required this.review,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final ColorScheme colors =
        Theme.of(
      context,
    ).colorScheme;

    final String initials =
        _initials(
      review.authorName,
    );

    return CircleAvatar(
      radius:
          23,
      backgroundColor:
          colors.primaryContainer,
      foregroundColor:
          colors.onPrimaryContainer,
      child:
          initials.isNotEmpty
              ? Text(
                  initials,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                )
              : const Icon(
                  Icons.person_rounded,
                ),
    );
  }


  String _initials(
    String name,
  ) {
    final List<String> parts =
        name
            .trim()
            .split(
              RegExp(
                r'\s+',
              ),
            )
            .where(
              (
                String value,
              ) =>
                  value.isNotEmpty,
            )
            .toList();

    if (parts.isEmpty) {
      return '';
    }

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            1,
          )
          .toUpperCase();
    }

    return (
      parts.first.substring(
        0,
        1,
      ) +
      parts.last.substring(
        0,
        1,
      )
    ).toUpperCase();
  }
}


class _RatingStars
    extends StatelessWidget {
  final double rating;


  const _RatingStars({
    required this.rating,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final double normalized =
        rating.clamp(
      0,
      5,
    );

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children:
          List.generate(
        5,
        (
          int index,
        ) {
          final double difference =
              normalized -
              index;

          IconData icon;

          if (difference >= 1) {
            icon =
                Icons.star_rounded;
          } else if (
            difference >= 0.5
          ) {
            icon =
                Icons.star_half_rounded;
          } else {
            icon =
                Icons.star_outline_rounded;
          }

          return Icon(
            icon,
            size:
                21,
            color:
                Colors.amber,
          );
        },
      ),
    );
  }
}


class _ModerationBadge
    extends StatelessWidget {
  final ReviewModerationStatus
      status;


  const _ModerationBadge({
    required this.status,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final ColorScheme colors =
        Theme.of(
      context,
    ).colorScheme;

    final String label;

    final IconData icon;

    switch (status) {
      case ReviewModerationStatus
            .pending:
        label =
            'In attesa';
        icon =
            Icons.hourglass_top_rounded;
        break;

      case ReviewModerationStatus
            .approved:
        label =
            'Approvata';
        icon =
            Icons.verified_rounded;
        break;

      case ReviewModerationStatus
            .rejected:
        label =
            'Rifiutata';
        icon =
            Icons.cancel_rounded;
        break;

      case ReviewModerationStatus
            .hidden:
        label =
            'Nascosta';
        icon =
            Icons.visibility_off_rounded;
        break;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            9,
        vertical:
            6,
      ),
      decoration:
          BoxDecoration(
        color:
            colors.surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          999,
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size:
                14,
            color:
                colors.onSurfaceVariant,
          ),

          const SizedBox(
            width:
                4,
          ),

          Text(
            label,
            style:
                Theme.of(
              context,
            )
                    .textTheme
                    .labelSmall
                    ?.copyWith(
              color:
                  colors.onSurfaceVariant,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}