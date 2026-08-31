import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';

import '../social_models.dart';


class ReviewFormPage extends StatefulWidget {
  final SocialUser reviewedUser;

  const ReviewFormPage({
    super.key,
    required this.reviewedUser,
  });

  @override
  State<ReviewFormPage> createState() =>
      _ReviewFormPageState();
}


class _ReviewFormPageState
    extends State<ReviewFormPage> {
  final ApiService _apiService =
      ApiService();

  final TextEditingController
      _commentController =
      TextEditingController();

  SocialReview? _existingReview;

  int _rating =
      0;

  int? _selectedSubjectId;

  bool _loading =
      true;

  bool _saving =
      false;

  bool _deleting =
      false;

  String? _error;


  SocialUser get reviewedUser {
    return widget.reviewedUser;
  }


  bool get isEditing {
    return _existingReview != null;
  }


  bool get isCurrentUser {
    return AuthSession
            .instance
            .currentUserId ==
        reviewedUser.id;
  }


  List<SocialSubject>
      get reviewableSubjects {
    return reviewedUser.subjects
        .where(
          (
            SocialSubject subject,
          ) =>
              subject.canHelp ||
              subject
                  .canGivePrivateLessons,
        )
        .toList();
  }


  bool get canSubmit {
    return !_saving &&
        !_deleting &&
        !isCurrentUser &&
        _rating >= 1 &&
        _rating <= 5;
  }


  @override
  void initState() {
    super.initState();

    _loadReview();
  }


  @override
  void dispose() {
    _commentController.dispose();

    super.dispose();
  }


  Future<void> _loadReview() async {
    if (isCurrentUser) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;
      });

      return;
    }

    setState(() {
      _loading =
          true;

      _error =
          null;
    });

    try {
      final SocialReview? review =
          await _apiService
              .getMyReviewForUser(
        reviewedUser.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _existingReview =
            review;

        if (review != null) {
          _rating =
              review.rating
                  .round();

          _commentController.text =
              review.comment;

          _selectedSubjectId =
              review.subject?.id;
        }

        _loading =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _error =
            _cleanError(
          e,
        );
      });
    }
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,

      appBar:
          AppBar(
        backgroundColor:
            AppColors.brandNightBlue,

        foregroundColor:
            AppColors.pureWhite,

        elevation:
            0,

        title:
            Text(
          isEditing
              ? 'Modifica recensione'
              : 'Scrivi recensione',

          style:
              const TextStyle(
            fontSize:
                18,

            fontWeight:
                FontWeight.w500,
          ),
        ),
      ),

      body:
          SafeArea(
        child:
            _buildBody(),
      ),
    );
  }


  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            20,
          ),

          child:
              _ReviewErrorCard(
            message:
                _error!,

            onRetry:
                _loadReview,
          ),
        ),
      );
    }

    if (isCurrentUser) {
      return const Center(
        child:
            Padding(
          padding:
              EdgeInsets.all(
            24,
          ),

          child:
              _SelfReviewCard(),
        ),
      );
    }

    return Center(
      child:
          LayoutBuilder(
        builder:
            (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final double width =
              constraints.maxWidth >
                      700
                  ? 700
                  : constraints
                      .maxWidth;

          return SizedBox(
            width:
                width,

            child:
                SingleChildScrollView(
              padding:
                  const EdgeInsets.all(
                20,
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  _buildUserCard(),

                  const SizedBox(
                    height:
                        24,
                  ),

                  if (
                    _existingReview !=
                        null
                  ) ...[
                    _buildModerationCard(),

                    const SizedBox(
                      height:
                          24,
                    ),
                  ],

                  _buildSectionTitle(
                    'Valutazione',
                    'Assegna da 1 a 5 stelle.',
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _buildRatingCard(),

                  const SizedBox(
                    height:
                        24,
                  ),

                  _buildSectionTitle(
                    'Materia',
                    'Puoi indicare la materia per cui hai ricevuto aiuto o una lezione.',
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _buildSubjectCard(),

                  const SizedBox(
                    height:
                        24,
                  ),

                  _buildSectionTitle(
                    'Recensione',
                    'Descrivi la tua esperienza.',
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _buildCommentCard(),

                  const SizedBox(
                    height:
                        28,
                  ),

                  _buildSaveButton(),

                  if (isEditing) ...[
                    const SizedBox(
                      height:
                          12,
                    ),

                    _buildDeleteButton(),
                  ],

                  const SizedBox(
                    height:
                        24,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildUserCard() {
    final SocialAcademicPath? path =
        reviewedUser.primaryAcademicPath ??
            reviewedUser.currentAcademicPath;

    final String academicContext =
        _academicContext(
      path,
    );

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.14,
          ),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          CircleAvatar(
            radius:
                25,

            backgroundColor:
                AppColors.brandNightBlue,

            child:
                Text(
              _initials(
                reviewedUser.name,
              ),

              style:
                  const TextStyle(
                color:
                    AppColors.skyBlue,

                fontWeight:
                    FontWeight.bold,

                fontSize:
                    15,
              ),
            ),
          ),

          const SizedBox(
            width:
                14,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  reviewedUser.name,

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
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      4,
                ),

                Text(
                  reviewedUser.isTeacher
                      ? 'Insegnante'
                      : 'Studente',

                  style:
                      const TextStyle(
                    color:
                        AppColors.materialSky,

                    fontSize:
                        11,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                if (
                  academicContext
                      .isNotEmpty
                ) ...[
                  const SizedBox(
                    height:
                        5,
                  ),

                  Text(
                    academicContext,

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withOpacity(
                        0.52,
                      ),

                      fontSize:
                          11,

                      height:
                          1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildModerationCard() {
    final SocialReview review =
        _existingReview!;

    String title;
    String description;
    IconData icon;
    Color color;

    switch (review.moderationStatus) {
      case ReviewModerationStatus.pending:
        title =
            'Recensione in attesa';

        description =
            'La recensione verrà mostrata pubblicamente dopo l\'approvazione.';

        icon =
            Icons.hourglass_top_rounded;

        color =
            Colors.orangeAccent;

        break;

      case ReviewModerationStatus.approved:
        title =
            'Recensione pubblicata';

        description =
            'La recensione è visibile nel profilo. Se la modifichi tornerà in attesa di approvazione.';

        icon =
            Icons.verified_rounded;

        color =
            Colors.greenAccent;

        break;

      case ReviewModerationStatus.rejected:
        title =
            'Recensione rifiutata';

        description =
            'Puoi modificarla e inviarla nuovamente alla moderazione.';

        icon =
            Icons.cancel_outlined;

        color =
            Colors.redAccent;

        break;

      case ReviewModerationStatus.hidden:
        title =
            'Recensione nascosta';

        description =
            'La recensione non è attualmente visibile pubblicamente.';

        icon =
            Icons.visibility_off_outlined;

        color =
            Colors.orangeAccent;

        break;
    }

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        15,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.06,
        ),

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        border:
            Border.all(
          color:
              color.withOpacity(
            0.20,
          ),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,

            color:
                color,

            size:
                22,
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                      TextStyle(
                    color:
                        color,

                    fontSize:
                        13,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      4,
                ),

                Text(
                  description,

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.55,
                    ),

                    fontSize:
                        11,

                    height:
                        1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style:
              const TextStyle(
            color:
                AppColors.pureWhite,

            fontSize:
                17,

            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height:
              4,
        ),

        Text(
          subtitle,

          style:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withOpacity(
              0.48,
            ),

            fontSize:
                11,
          ),
        ),
      ],
    );
  }


  Widget _buildRatingCard() {
    return _ReviewSectionCard(
      child:
          Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children:
                List.generate(
              5,
              (
                int index,
              ) {
                final int value =
                    index + 1;

                return IconButton(
                  tooltip:
                      '$value stelle',

                  onPressed:
                      _saving ||
                              _deleting
                          ? null
                          : () {
                              setState(() {
                                _rating =
                                    value;
                              });
                            },

                  icon:
                      Icon(
                    value <=
                            _rating
                        ? Icons
                            .star_rounded
                        : Icons
                            .star_outline_rounded,

                    color:
                        value <=
                                _rating
                            ? Colors.amber
                            : Colors.white30,

                    size:
                        38,
                  ),
                );
              },
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            _ratingLabel(),

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  _rating == 0
                      ? Colors.white38
                      : AppColors
                          .materialSky,

              fontSize:
                  12,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSubjectCard() {
    final List<SocialSubject> subjects =
        reviewableSubjects;

    return _ReviewSectionCard(
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          if (subjects.isEmpty)
            Text(
              'Questo utente non ha materie disponibili per aiuto o lezioni private.',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.50,
                ),

                fontSize:
                    11,

                height:
                    1.4,
              ),
            )
          else
            DropdownButtonFormField<int?>(
              value:
                  _selectedSubjectId,

              isExpanded:
                  true,

              dropdownColor:
                  AppColors.eleganceDeepNavy,

              style:
                  const TextStyle(
                color:
                    AppColors.pureWhite,

                fontSize:
                    12,
              ),

              decoration:
                  InputDecoration(
                prefixIcon:
                    const Icon(
                  Icons.menu_book_outlined,

                  color:
                      AppColors.skyBlue,

                  size:
                      20,
                ),

                filled:
                    true,

                fillColor:
                    AppColors.brandNightBlue
                        .withOpacity(
                  0.50,
                ),

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),

                  borderSide:
                      BorderSide.none,
                ),
              ),

              items: [
                const DropdownMenuItem<int?>(
                  value:
                      null,

                  child:
                      Text(
                    'Nessuna materia specifica',
                  ),
                ),

                ...subjects.map(
                  (
                    SocialSubject subject,
                  ) {
                    return DropdownMenuItem<int?>(
                      value:
                          subject.id,

                      child:
                          Text(
                        subject.name,

                        maxLines:
                            1,

                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ],

              onChanged:
                  _saving ||
                          _deleting
                      ? null
                      : (
                          int? value,
                        ) {
                          setState(() {
                            _selectedSubjectId =
                                value;
                          });
                        },
            ),
        ],
      ),
    );
  }


  Widget _buildCommentCard() {
    return _ReviewSectionCard(
      child:
          TextField(
        controller:
            _commentController,

        enabled:
            !_saving &&
            !_deleting,

        minLines:
            5,

        maxLines:
            8,

        maxLength:
            2000,

        style:
            const TextStyle(
          color:
              AppColors.pureWhite,

          fontSize:
              13,

          height:
              1.4,
        ),

        decoration:
            InputDecoration(
          hintText:
              'Racconta la tua esperienza...',

          hintStyle:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withOpacity(
              0.32,
            ),
          ),

          filled:
              true,

          fillColor:
              AppColors.brandNightBlue
                  .withOpacity(
            0.42,
          ),

          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),

            borderSide:
                BorderSide.none,
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),

            borderSide:
                const BorderSide(
              color:
                  AppColors.skyBlue,
            ),
          ),

          counterStyle:
              const TextStyle(
            color:
                Colors.white38,

            fontSize:
                10,
          ),
        ),
      ),
    );
  }


  Widget _buildSaveButton() {
    return SizedBox(
      width:
          double.infinity,

      height:
          52,

      child:
          ElevatedButton.icon(
        onPressed:
            canSubmit
                ? _saveReview
                : null,

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              AppColors.skyBlue,

          foregroundColor:
              AppColors.brandNightBlue,

          disabledBackgroundColor:
              AppColors.skyBlue
                  .withOpacity(
            0.35,
          ),

          disabledForegroundColor:
              AppColors.brandNightBlue
                  .withOpacity(
            0.55,
          ),

          elevation:
              0,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),

        icon:
            _saving
                ? const SizedBox(
                    width:
                        18,

                    height:
                        18,

                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2,

                      color:
                          AppColors
                              .brandNightBlue,
                    ),
                  )
                : Icon(
                    isEditing
                        ? Icons
                            .save_outlined
                        : Icons
                            .rate_review_outlined,
                  ),

        label:
            Text(
          _saving
              ? 'Salvataggio...'
              : isEditing
                  ? 'Salva modifiche'
                  : 'Invia recensione',

          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }


  Widget _buildDeleteButton() {
    return SizedBox(
      width:
          double.infinity,

      height:
          48,

      child:
          OutlinedButton.icon(
        onPressed:
            _saving ||
                    _deleting
                ? null
                : _confirmDelete,

        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              Colors.redAccent,

          side:
              BorderSide(
            color:
                Colors.redAccent
                    .withOpacity(
              0.40,
            ),
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),

        icon:
            _deleting
                ? const SizedBox(
                    width:
                        17,

                    height:
                        17,

                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2,

                      color:
                          Colors.redAccent,
                    ),
                  )
                : const Icon(
                    Icons.delete_outline_rounded,
                  ),

        label:
            Text(
          _deleting
              ? 'Eliminazione...'
              : 'Elimina recensione',
        ),
      ),
    );
  }


  Future<void> _saveReview() async {
    if (!canSubmit) {
      return;
    }

    setState(() {
      _saving =
          true;
    });

    try {
      final String comment =
          _commentController.text
              .trim();

      if (isEditing) {
        final int? oldSubjectId =
            _existingReview
                ?.subject
                ?.id;

        final bool clearSubject =
            oldSubjectId != null &&
            _selectedSubjectId ==
                null;

        await _apiService
            .updateMyReview(
          userId:
              reviewedUser.id,

          rating:
              _rating,

          comment:
              comment,

          subjectId:
              _selectedSubjectId,

          clearSubject:
              clearSubject,
        );
      } else {
        await _apiService
            .createReview(
          userId:
              reviewedUser.id,

          rating:
              _rating,

          comment:
              comment,

          subjectId:
              _selectedSubjectId,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        isEditing
            ? 'Recensione aggiornata. Verrà nuovamente controllata prima della pubblicazione.'
            : 'Recensione inviata. Verrà pubblicata dopo la moderazione.',
      );

      Navigator.of(
        context,
      ).pop(
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving =
              false;
        });
      }
    }
  }


  Future<void> _confirmDelete() async {
    final bool? confirmed =
        await showDialog<bool>(
      context:
          context,

      builder:
          (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              AppColors.eleganceDeepNavy,

          title:
              const Text(
            'Elimina recensione',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              const Text(
            'Vuoi eliminare definitivamente questa recensione?',

            style:
                TextStyle(
              color:
                  Colors.white70,
            ),
          ),

          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
                  const Text(
                'Annulla',
              ),
            ),

            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
                  const Text(
                'Elimina',

                style:
                    TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteReview();
  }


  Future<void> _deleteReview() async {
    setState(() {
      _deleting =
          true;
    });

    try {
      await _apiService
          .deleteMyReview(
        reviewedUser.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Recensione eliminata.',
      );

      Navigator.of(
        context,
      ).pop(
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deleting =
              false;
        });
      }
    }
  }


  String _ratingLabel() {
    switch (_rating) {
      case 1:
        return 'Esperienza negativa';

      case 2:
        return 'Sotto le aspettative';

      case 3:
        return 'Buona esperienza';

      case 4:
        return 'Molto buona';

      case 5:
        return 'Esperienza eccellente';

      default:
        return 'Seleziona una valutazione';
    }
  }


  String _academicContext(
    SocialAcademicPath? path,
  ) {
    if (path == null) {
      final List<String> fallback =
          [];

      if (
        reviewedUser.course
            .trim()
            .isNotEmpty
      ) {
        fallback.add(
          reviewedUser.course.trim(),
        );
      }

      if (
        reviewedUser.department
            .trim()
            .isNotEmpty
      ) {
        fallback.add(
          reviewedUser.department.trim(),
        );
      }

      if (
        reviewedUser.university
            .trim()
            .isNotEmpty
      ) {
        fallback.add(
          reviewedUser.university.trim(),
        );
      }

      return fallback.join(
        ' • ',
      );
    }

    final List<String> values =
        [];

    if (
      path.course
          .trim()
          .isNotEmpty
    ) {
      values.add(
        path.course.trim(),
      );
    }

    if (
      path.department
          .trim()
          .isNotEmpty &&
      path.department.trim() !=
          path.course.trim()
    ) {
      values.add(
        path.department.trim(),
      );
    }

    if (
      path.university
          .trim()
          .isNotEmpty
    ) {
      values.add(
        path.university.trim(),
      );
    }

    return values.join(
      ' • ',
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
                String part,
              ) =>
                  part.isNotEmpty,
            )
            .toList();

    if (parts.isEmpty) {
      return '?';
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


  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }


  String _cleanError(
    Object error,
  ) {
    String message =
        error.toString();

    if (
      message.startsWith(
        'Exception: ',
      )
    ) {
      message =
          message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }
}


class _ReviewSectionCard
    extends StatelessWidget {
  final Widget child;


  const _ReviewSectionCard({
    required this.child,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.12,
          ),
        ),
      ),

      child:
          child,
    );
  }
}


class _SelfReviewCard
    extends StatelessWidget {
  const _SelfReviewCard();


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        maxWidth:
            500,
      ),

      padding:
          const EdgeInsets.all(
        24,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.12,
          ),
        ),
      ),

      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Container(
            width:
                58,

            height:
                58,

            decoration:
                BoxDecoration(
              color:
                  AppColors.brandNightBlue,

              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child:
                const Icon(
              Icons.person_off_outlined,

              color:
                  AppColors.skyBlue,

              size:
                  29,
            ),
          ),

          const SizedBox(
            height:
                16,
          ),

          const Text(
            'Non puoi recensire il tuo profilo',

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,

              fontSize:
                  16,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
                7,
          ),

          const Text(
            'Le recensioni possono essere lasciate soltanto ad altri utenti.',

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  Colors.white54,

              fontSize:
                  11,

              height:
                  1.4,
            ),
          ),
        ],
      ),
    );
  }
}


class _ReviewErrorCard
    extends StatelessWidget {
  final String message;

  final Future<void> Function()
      onRetry;


  const _ReviewErrorCard({
    required this.message,
    required this.onRetry,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        maxWidth:
            500,
      ),

      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        24,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              Colors.redAccent
                  .withOpacity(
            0.20,
          ),
        ),
      ),

      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          const Icon(
            Icons.error_outline_rounded,

            color:
                Colors.redAccent,

            size:
                40,
          ),

          const SizedBox(
            height:
                12,
          ),

          const Text(
            'Impossibile caricare la recensione',

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,

              fontSize:
                  15,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            message,

            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color:
                  Colors.white60,

              fontSize:
                  11,
            ),
          ),

          const SizedBox(
            height:
                16,
          ),

          OutlinedButton.icon(
            onPressed:
                () {
              onRetry();
            },

            icon:
                const Icon(
              Icons.refresh_rounded,
            ),

            label:
                const Text(
              'Riprova',
            ),
          ),
        ],
      ),
    );
  }
}