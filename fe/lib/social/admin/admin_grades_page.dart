import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';


class AdminGradesPage
    extends StatefulWidget {
  const AdminGradesPage({
    super.key,
  });

  @override
  State<AdminGradesPage> createState() =>
      _AdminGradesPageState();
}


class _AdminGradesPageState
    extends State<AdminGradesPage> {
  final ApiService _apiService =
      ApiService();

  List<Map<String, dynamic>> _grades =
      [];

  final Set<String> _processingKeys =
      {};

  bool _loading =
      true;

  bool _refreshing =
      false;

  String? _error;


  @override
  void initState() {
    super.initState();

    _loadGrades();
  }


  Future<void> _loadGrades({
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
      final List<Map<String, dynamic>>
          grades =
          await _apiService
              .getPendingGrades();

      if (!mounted) {
        return;
      }

      setState(() {
        _grades =
            grades;

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


  String _itemKey(
    Map<String, dynamic> item,
  ) {
    final int userId =
        _toInt(
              item['user_id'],
            ) ??
            0;

    final int subjectId =
        _toInt(
              item['subject_id'],
            ) ??
            0;

    return '$userId:$subjectId';
  }


  bool _isProcessing(
    Map<String, dynamic> item,
  ) {
    return _processingKeys.contains(
      _itemKey(
        item,
      ),
    );
  }


  Future<void> _verifyGrade(
    Map<String, dynamic> item,
  ) async {
    final int? userId =
        _toInt(
      item['user_id'],
    );

    final int? subjectId =
        _toInt(
      item['subject_id'],
    );

    if (
      userId == null ||
      subjectId == null
    ) {
      _showMessage(
        'Dati del voto non validi.',
      );

      return;
    }

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
            'Verifica voto',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              Text(
            'Vuoi verificare il voto ${_gradeLabel(item)} per ${_userName(item)}?',

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

    await _executeAction(
      item:
          item,

      action:
          () =>
              _apiService
                  .verifyGrade(
        userId:
            userId,

        subjectId:
            subjectId,
      ),

      successMessage:
          'Voto verificato.',
    );
  }


  Future<void> _rejectGrade(
    Map<String, dynamic> item,
  ) async {
    final int? userId =
        _toInt(
      item['user_id'],
    );

    final int? subjectId =
        _toInt(
      item['subject_id'],
    );

    if (
      userId == null ||
      subjectId == null
    ) {
      _showMessage(
        'Dati del voto non validi.',
      );

      return;
    }

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
            'Rifiuta voto',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              Text(
            'Vuoi rifiutare il voto ${_gradeLabel(item)} dichiarato da ${_userName(item)}?',

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

    await _executeAction(
      item:
          item,

      action:
          () =>
              _apiService
                  .rejectGrade(
        userId:
            userId,

        subjectId:
            subjectId,
      ),

      successMessage:
          'Voto rifiutato.',
    );
  }


  Future<void> _executeAction({
    required Map<String, dynamic> item,
    required Future<Map<String, dynamic>>
        Function() action,
    required String successMessage,
  }) async {
    final String key =
        _itemKey(
      item,
    );

    if (
      _processingKeys.contains(
        key,
      )
    ) {
      return;
    }

    setState(() {
      _processingKeys.add(
        key,
      );
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      setState(() {
        _grades.removeWhere(
          (
            Map<String, dynamic> grade,
          ) =>
              _itemKey(
                grade,
              ) ==
              key,
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
          _processingKeys.remove(
            key,
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
          'Verifica voti',

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
                        _loadGrades(
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
      return _AdminGradesError(
        message:
            _error!,

        onRetry:
            _loadGrades,
      );
    }

    if (_grades.isEmpty) {
      return const _EmptyGrades();
    }

    return RefreshIndicator(
      onRefresh:
          () =>
              _loadGrades(
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
            _grades.length,

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
          final Map<String, dynamic> item =
              _grades[index];

          return _GradeVerificationCard(
            userName:
                _userName(
              item,
            ),

            email:
                _email(
              item,
            ),

            subjectName:
                _subjectName(
              item,
            ),

            subjectCode:
                _subjectCode(
              item,
            ),

            grade:
                _toInt(
              item['grade'],
            ),

            note:
                item['note']
                        ?.toString() ??
                    '',

            university:
                _field(
              item,
              'university',
            ),

            department:
                _field(
              item,
              'department',
            ),

            course:
                _field(
              item,
              'course',
            ),

            processing:
                _isProcessing(
              item,
            ),

            onVerify:
                () {
              _verifyGrade(
                item,
              );
            },

            onReject:
                () {
              _rejectGrade(
                item,
              );
            },
          );
        },
      ),
    );
  }


  String _userName(
    Map<String, dynamic> item,
  ) {
    final String name =
        item['user_name']
                ?.toString()
                .trim() ??
            '';

    if (name.isNotEmpty) {
      return name;
    }

    final String firstName =
        item['first_name']
                ?.toString()
                .trim() ??
            '';

    final String lastName =
        item['last_name']
                ?.toString()
                .trim() ??
            '';

    final String fullName =
        '$firstName $lastName'
            .trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    return 'Utente';
  }


  String _email(
    Map<String, dynamic> item,
  ) {
    return item['email']
            ?.toString()
            .trim() ??
        '';
  }


  String _subjectName(
    Map<String, dynamic> item,
  ) {
    final String name =
        item['subject_name']
                ?.toString()
                .trim() ??
            '';

    if (name.isNotEmpty) {
      return name;
    }

    final dynamic subject =
        item['subject'];

    if (subject is Map) {
      final String nested =
          subject['name']
                  ?.toString()
                  .trim() ??
              '';

      if (nested.isNotEmpty) {
        return nested;
      }
    }

    return 'Materia';
  }


  String _subjectCode(
    Map<String, dynamic> item,
  ) {
    final String code =
        item['subject_code']
                ?.toString()
                .trim() ??
            '';

    if (code.isNotEmpty) {
      return code;
    }

    final dynamic subject =
        item['subject'];

    if (subject is Map) {
      return subject['code']
              ?.toString()
              .trim() ??
          '';
    }

    return '';
  }


  String _gradeLabel(
    Map<String, dynamic> item,
  ) {
    final int? grade =
        _toInt(
      item['grade'],
    );

    if (grade == null) {
      return 'non specificato';
    }

    return '$grade/30';
  }


  String _field(
    Map<String, dynamic> item,
    String key,
  ) {
    final String direct =
        item[key]
                ?.toString()
                .trim() ??
            '';

    if (direct.isNotEmpty) {
      return direct;
    }

    final dynamic academicPath =
        item['academic_path'];

    if (academicPath is Map) {
      return academicPath[key]
              ?.toString()
              .trim() ??
          '';
    }

    return '';
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


  static int? _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
    );
  }
}


class _GradeVerificationCard
    extends StatelessWidget {
  final String userName;

  final String email;

  final String subjectName;

  final String subjectCode;

  final int? grade;

  final String note;

  final String university;

  final String department;

  final String course;

  final bool processing;

  final VoidCallback onVerify;

  final VoidCallback onReject;


  const _GradeVerificationCard({
    required this.userName,
    required this.email,
    required this.subjectName,
    required this.subjectCode,
    required this.grade,
    required this.note,
    required this.university,
    required this.department,
    required this.course,
    required this.processing,
    required this.onVerify,
    required this.onReject,
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
              Colors.amber
                  .withOpacity(
            0.18,
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
                      AppColors.brandNightBlue,

                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),

                child:
                    Text(
                  userName.isNotEmpty
                      ? userName[0]
                          .toUpperCase()
                      : '?',

                  style:
                      const TextStyle(
                    color:
                        AppColors.skyBlue,

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
                      userName,

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

                    if (email.isNotEmpty) ...[
                      const SizedBox(
                        height:
                            4,
                      ),

                      Text(
                        email,

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
                    ],

                    const SizedBox(
                      height:
                          7,
                    ),

                    const _GradePendingBadge(),
                  ],
                ),
              ),

              Container(
                constraints:
                    const BoxConstraints(
                  minWidth:
                      58,
                ),

                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      10,

                  vertical:
                      9,
                ),

                alignment:
                    Alignment.center,

                decoration:
                    BoxDecoration(
                  color:
                      Colors.amber
                          .withOpacity(
                    0.10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    11,
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
                    Text(
                  grade == null
                      ? '--'
                      : '$grade/30',

                  style:
                      const TextStyle(
                    color:
                        Colors.amber,

                    fontSize:
                        15,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                16,
          ),

          Container(
            width:
                double.infinity,

            padding:
                const EdgeInsets.all(
              13,
            ),

            decoration:
                BoxDecoration(
              color:
                  AppColors.brandNightBlue,

              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),

            child:
                Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,

                  color:
                      AppColors.skyBlue,

                  size:
                      19,
                ),

                const SizedBox(
                  width:
                      9,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        subjectName,

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,

                          fontSize:
                              12,

                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      if (
                        subjectCode
                            .isNotEmpty
                      ) ...[
                        const SizedBox(
                          height:
                              3,
                        ),

                        Text(
                          subjectCode,

                          style:
                              const TextStyle(
                            color:
                                Colors.white38,

                            fontSize:
                                9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (
            university.isNotEmpty ||
            department.isNotEmpty ||
            course.isNotEmpty
          ) ...[
            const SizedBox(
              height:
                  14,
            ),

            if (
              university.isNotEmpty
            )
              _GradeInfoRow(
                icon:
                    Icons
                        .account_balance_outlined,

                label:
                    'Ateneo',

                value:
                    university,
              ),

            if (
              university.isNotEmpty &&
              (
                department.isNotEmpty ||
                course.isNotEmpty
              )
            )
              const SizedBox(
                height:
                    9,
              ),

            if (
              department.isNotEmpty
            )
              _GradeInfoRow(
                icon:
                    Icons.business_outlined,

                label:
                    'Dipartimento',

                value:
                    department,
              ),

            if (
              department.isNotEmpty &&
              course.isNotEmpty
            )
              const SizedBox(
                height:
                    9,
              ),

            if (course.isNotEmpty)
              _GradeInfoRow(
                icon:
                    Icons.school_outlined,

                label:
                    'Corso',

                value:
                    course,
              ),
          ],

          if (
            note
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
                    AppColors.brandNightBlue
                        .withOpacity(
                  0.65,
                ),

                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Nota',

                    style:
                        TextStyle(
                      color:
                          AppColors.materialSky,

                      fontSize:
                          9,

                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height:
                        5,
                  ),

                  Text(
                    note.trim(),

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
                ],
              ),
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
                        onVerify,

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
                      Icons.verified_outlined,
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


class _GradePendingBadge
    extends StatelessWidget {
  const _GradePendingBadge();


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
            'Voto da verificare',

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


class _GradeInfoRow
    extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;


  const _GradeInfoRow({
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


class _EmptyGrades
    extends StatelessWidget {
  const _EmptyGrades();


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
                    .workspace_premium_outlined,

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
                'Nessun voto in attesa di verifica.',

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


class _AdminGradesError
    extends StatelessWidget {
  final String message;

  final Future<void> Function({
    bool refresh,
  }) onRetry;


  const _AdminGradesError({
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
                'Impossibile caricare i voti',

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