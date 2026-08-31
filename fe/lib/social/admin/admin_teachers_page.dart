import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

import '../social_models.dart';


class AdminTeachersPage
    extends StatefulWidget {
  const AdminTeachersPage({
    super.key,
  });

  @override
  State<AdminTeachersPage> createState() =>
      _AdminTeachersPageState();
}


class _AdminTeachersPageState
    extends State<AdminTeachersPage> {
  final ApiService _apiService =
      ApiService();

  List<SocialUser> _teachers =
      [];

  final Set<int> _processingIds =
      {};

  bool _loading =
      true;

  bool _refreshing =
      false;

  String? _error;


  @override
  void initState() {
    super.initState();

    _loadTeachers();
  }


  Future<void> _loadTeachers({
    bool refresh = false,
  }) async {
    if (refresh) {
      if (_refreshing) {
        return;
      }

      setState(() {
        _refreshing =
            true;
      });
    } else {
      setState(() {
        _loading =
            true;

        _error =
            null;
      });
    }

    try {
      final List<SocialUser> teachers =
          await _apiService
              .getPendingTeachers();

      if (!mounted) {
        return;
      }

      setState(() {
        _teachers =
            teachers;

        _error =
            null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _cleanError(
          e,
        );
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _refreshing =
            false;
      });
    }
  }


  bool _isProcessing(
    SocialUser teacher,
  ) {
    return _processingIds.contains(
      teacher.id,
    );
  }


  Future<void> _approveTeacher(
    SocialUser teacher,
  ) async {
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
            'Verifica docente',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              Text(
            'Vuoi verificare ${teacher.name} come docente?\n\n'
            'Dopo la verifica l\'account potrà accedere alle funzioni riservate ai docenti.',

            style:
                const TextStyle(
              color:
                  Colors.white70,

              height:
                  1.45,
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
                'Verifica',
                
                style:
                    TextStyle(
                  color:
                      Colors.greenAccent,
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

    await _setTeacherVerification(
      teacher:
          teacher,

      verified:
          true,

      successMessage:
          '${teacher.name} è stato verificato come docente.',
    );
  }


  Future<void> _rejectTeacher(
    SocialUser teacher,
  ) async {
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
            'Rifiuta verifica',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              Text(
            'Vuoi rifiutare la richiesta di verifica docente di ${teacher.name}?',

            style:
                const TextStyle(
              color:
                  Colors.white70,

              height:
                  1.45,
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
                'Rifiuta',

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

    await _setTeacherVerification(
      teacher:
          teacher,

      verified:
          false,

      successMessage:
          'Verifica docente rifiutata.',
    );
  }


  Future<void> _setTeacherVerification({
    required SocialUser teacher,
    required bool verified,
    required String successMessage,
  }) async {
    if (
      _processingIds.contains(
        teacher.id,
      )
    ) {
      return;
    }

    setState(() {
      _processingIds.add(
        teacher.id,
      );
    });

    try {
      await _apiService
          .updateTeacherVerification(
        userId:
            teacher.id,

        verified:
            verified,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _teachers.removeWhere(
          (
            SocialUser item,
          ) =>
              item.id ==
              teacher.id,
        );
      });

      _showMessage(
        successMessage,
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
          _processingIds.remove(
            teacher.id,
          );
        });
      }
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
            const Text(
          'Verifica docenti',

          style:
              TextStyle(
            fontSize:
                18,

            fontWeight:
                FontWeight.w500,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Aggiorna',

            onPressed:
                _refreshing
                    ? null
                    : () {
                        _loadTeachers(
                          refresh:
                              true,
                        );
                      },

            icon:
                _refreshing
                    ? const SizedBox(
                        width:
                            19,

                        height:
                            19,

                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,

                          color:
                              AppColors.pureWhite,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                      ),
          ),
        ],
      ),

      body:
          SafeArea(
        child:
            Center(
          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  900,
            ),

            child:
                _buildBody(),
          ),
        ),
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
      return _AdminTeacherError(
        message:
            _error!,

        onRetry:
            _loadTeachers,
      );
    }

    if (_teachers.isEmpty) {
      return const _EmptyTeachers();
    }

    return RefreshIndicator(
      onRefresh:
          () =>
              _loadTeachers(
        refresh:
            true,
      ),

      child:
          ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          16,
        ),

        itemCount:
            _teachers.length,

        separatorBuilder:
            (
          BuildContext context,
          int index,
        ) =>
                const SizedBox(
          height:
              14,
        ),

        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final SocialUser teacher =
              _teachers[index];

          return _TeacherVerificationCard(
            teacher:
                teacher,

            processing:
                _isProcessing(
              teacher,
            ),

            onApprove:
                () {
              _approveTeacher(
                teacher,
              );
            },

            onReject:
                () {
              _rejectTeacher(
                teacher,
              );
            },
          );
        },
      ),
    );
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


class _TeacherVerificationCard
    extends StatelessWidget {
  final SocialUser teacher;

  final bool processing;

  final VoidCallback onApprove;

  final VoidCallback onReject;


  const _TeacherVerificationCard({
    required this.teacher,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final SocialAcademicPath? path =
        teacher.primaryAcademicPath ??
            teacher.currentAcademicPath;

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
              AppColors.teacherIndigo
                  .withOpacity(
            0.22,
          ),
        ),
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
              Container(
                width:
                    52,

                height:
                    52,

                alignment:
                    Alignment.center,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.teacherIndigo,

                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),

                child:
                    Text(
                  teacher.name.isNotEmpty
                      ? teacher.name[0]
                          .toUpperCase()
                      : '?',

                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,

                    fontSize:
                        20,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    13,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      teacher.name,

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
                      teacher.email,

                      maxLines:
                          1,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          const TextStyle(
                        color:
                            Colors.white54,

                        fontSize:
                            10,
                      ),
                    ),

                    const SizedBox(
                      height:
                          7,
                    ),

                    const _TeacherPendingBadge(),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                16,
          ),

          Divider(
            height:
                1,

            color:
                AppColors.pureWhite
                    .withOpacity(
              0.07,
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          if (path != null) ...[
            _TeacherInfoRow(
              icon:
                  Icons
                      .account_balance_outlined,

              label:
                  'Ateneo',

              value:
                  path.university.isEmpty
                      ? 'Non specificato'
                      : path.university,
            ),

            const SizedBox(
              height:
                  10,
            ),

            _TeacherInfoRow(
              icon:
                  Icons.business_outlined,

              label:
                  'Dipartimento',

              value:
                  path.department.isEmpty
                      ? 'Non specificato'
                      : path.department,
            ),

            const SizedBox(
              height:
                  10,
            ),

            _TeacherInfoRow(
              icon:
                  Icons.school_outlined,

              label:
                  'Corso',

              value:
                  path.course.isEmpty
                      ? 'Non specificato'
                      : path.course,
            ),
          ] else ...[
            _TeacherInfoRow(
              icon:
                  Icons
                      .account_balance_outlined,

              label:
                  'Ateneo',

              value:
                  teacher.university.isEmpty
                      ? 'Non specificato'
                      : teacher.university,
            ),

            const SizedBox(
              height:
                  10,
            ),

            _TeacherInfoRow(
              icon:
                  Icons.business_outlined,

              label:
                  'Dipartimento',

              value:
                  teacher.department.isEmpty
                      ? 'Non specificato'
                      : teacher.department,
            ),

            const SizedBox(
              height:
                  10,
            ),

            _TeacherInfoRow(
              icon:
                  Icons.school_outlined,

              label:
                  'Corso',

              value:
                  teacher.course.isEmpty
                      ? 'Non specificato'
                      : teacher.course,
            ),
          ],

          if (
            teacher.description
                .trim()
                .isNotEmpty
          ) ...[
            const SizedBox(
              height:
                  14,
            ),

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                12,
              ),

              decoration:
                  BoxDecoration(
                color:
                    AppColors.brandNightBlue,

                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),

              child:
                  Text(
                teacher.description,

                style:
                    const TextStyle(
                  color:
                      Colors.white60,

                  fontSize:
                      10,

                  height:
                      1.4,
                ),
              ),
            ),
          ],

          if (
            teacher.subjects
                .isNotEmpty
          ) ...[
            const SizedBox(
              height:
                  14,
            ),

            const Text(
              'Materie',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,

                fontSize:
                    11,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            Wrap(
              spacing:
                  6,

              runSpacing:
                  6,

              children:
                  teacher.subjects
                      .map(
                        (
                          SocialSubject subject,
                        ) =>
                            _TeacherSubjectBadge(
                          subject:
                              subject,
                        ),
                      )
                      .toList(),
            ),
          ],

          const SizedBox(
            height:
                18,
          ),

          if (processing)
            const LinearProgressIndicator()
          else
            Row(
              children: [
                Expanded(
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        onApprove,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.greenAccent,

                      foregroundColor:
                          AppColors
                              .eleganceSoftNight,

                      elevation:
                          0,

                      padding:
                          const EdgeInsets.symmetric(
                        vertical:
                            12,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),

                    icon:
                        const Icon(
                      Icons
                          .verified_outlined,
                    ),

                    label:
                        const Text(
                      'Verifica',
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      10,
                ),

                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        onReject,

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

                      padding:
                          const EdgeInsets.symmetric(
                        vertical:
                            12,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),

                    icon:
                        const Icon(
                      Icons.close_rounded,
                    ),

                    label:
                        const Text(
                      'Rifiuta',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}


class _TeacherPendingBadge
    extends StatelessWidget {
  const _TeacherPendingBadge();


  @override
  Widget build(
    BuildContext context,
  ) {
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
            Colors.amber
                .withOpacity(
          0.09,
        ),

        borderRadius:
            BorderRadius.circular(
          8,
        ),

        border:
            Border.all(
          color:
              Colors.amber
                  .withOpacity(
            0.20,
          ),
        ),
      ),

      child:
          const Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            Icons.schedule_rounded,

            color:
                Colors.amber,

            size:
                12,
          ),

          SizedBox(
            width:
                4,
          ),

          Text(
            'Verifica in attesa',

            style:
                TextStyle(
              color:
                  Colors.amber,

              fontSize:
                  8,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


class _TeacherInfoRow
    extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;


  const _TeacherInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Icon(
          icon,

          color:
              AppColors.materialSky,

          size:
              17,
        ),

        const SizedBox(
          width:
              9,
        ),

        SizedBox(
          width:
              92,

          child:
              Text(
            label,

            style:
                const TextStyle(
              color:
                  Colors.white38,

              fontSize:
                  9,
            ),
          ),
        ),

        Expanded(
          child:
              Text(
            value,

            textAlign:
                TextAlign.right,

            style:
                const TextStyle(
              color:
                  Colors.white70,

              fontSize:
                  10,

              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}


class _TeacherSubjectBadge
    extends StatelessWidget {
  final SocialSubject subject;


  const _TeacherSubjectBadge({
    required this.subject,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
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
                .withOpacity(
          0.08,
        ),

        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),

      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          const Icon(
            Icons.menu_book_outlined,

            color:
                AppColors.materialSky,

            size:
                11,
          ),

          const SizedBox(
            width:
                4,
          ),

          Text(
            subject.name,

            style:
                const TextStyle(
              color:
                  AppColors.materialSky,

              fontSize:
                  8,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


class _EmptyTeachers
    extends StatelessWidget {
  const _EmptyTeachers();


  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding:
          const EdgeInsets.all(
        20,
      ),

      children: [
        const SizedBox(
          height:
              100,
        ),

        Container(
          width:
              double.infinity,

          padding:
              const EdgeInsets.all(
            28,
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
                0.10,
              ),
            ),
          ),

          child:
              const Column(
            children: [
              Icon(
                Icons
                    .cast_for_education_outlined,

                color:
                    Colors.white38,

                size:
                    46,
              ),

              SizedBox(
                height:
                    13,
              ),

              Text(
                'Nessun docente in attesa di verifica.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      Colors.white60,

                  fontSize:
                      12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _AdminTeacherError
    extends StatelessWidget {
  final String message;

  final Future<void> Function({
    bool refresh,
  }) onRetry;


  const _AdminTeacherError({
    required this.message,
    required this.onRetry,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          20,
        ),

        child:
            Container(
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
                0.18,
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
                'Impossibile caricare i docenti',

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
        ),
      ),
    );
  }
}