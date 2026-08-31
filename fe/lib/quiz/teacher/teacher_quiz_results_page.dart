import 'package:flutter/material.dart';

import '../../../theme/nightTheme.dart';
import 'services/quiz_assignment_service.dart';
import 'teacher_student_quiz_statistics_page.dart';


class TeacherQuizResultsPage
    extends StatefulWidget {
  final int subjectId;
  final String department;
  final String course;
  final String subject;

  const TeacherQuizResultsPage({
    super.key,
    required this.subjectId,
    required this.department,
    required this.course,
    required this.subject,
  });

  @override
  State<TeacherQuizResultsPage>
      createState() =>
          _TeacherQuizResultsPageState();
}


class _TeacherQuizResultsPageState
    extends State<TeacherQuizResultsPage> {
  final QuizAssignmentService _service =
      QuizAssignmentService();

  List<Map<String, dynamic>>
      _assignments = [];

  final Map<int, List<Map<String, dynamic>>>
      _resultsByAssignment = {};

  bool _loading =
      true;

  String? _error;


  @override
  void initState() {
    super.initState();
    _load();
  }


  Future<void> _load() async {
    setState(() {
      _loading =
          true;

      _error =
          null;
    });

    try {
      final List<Map<String, dynamic>> all =
          await _service
              .getTeacherAssignments();

      final List<Map<String, dynamic>> assignments =
          all.where(
        (
          Map<String, dynamic> item,
        ) {
          return _toInt(
                item[
                  'subject_id'
                ],
              ) ==
              widget.subjectId;
        },
      ).toList();

      final Map<int, List<Map<String, dynamic>>>
          results = {};

      for (
        final Map<String, dynamic> assignment
        in assignments
      ) {
        final int? id =
            _toInt(
          assignment[
            'id'
          ],
        );

        if (id == null) {
          continue;
        }

        results[
          id
        ] =
            await _service
                .getAssignmentResults(
          id,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _assignments =
            assignments;

        _resultsByAssignment
          ..clear()
          ..addAll(
            results,
          );

        _loading =
            false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _error =
            _cleanError(
          error,
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
        title:
            Text(
          'Risultati · ${widget.subject}',
          maxLines:
              1,
          overflow:
              TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip:
                'Aggiorna',
            onPressed:
                _loading
                    ? null
                    : _load,
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body:
          SafeArea(
        child:
            _body(),
      ),
    );
  }


  Widget _body() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _state(
        Icons.error_outline_rounded,
        'Impossibile caricare i risultati',
        _error!,
      );
    }

    if (_assignments.isEmpty) {
      return _state(
        Icons.analytics_outlined,
        'Nessun quiz disponibile',
        'Crea e assegna almeno un quiz per visualizzare i risultati.',
      );
    }

    return RefreshIndicator(
      onRefresh:
          _load,
      child:
          ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),
        itemCount:
            _assignments.length,
        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final Map<String, dynamic> assignment =
              _assignments[
                index
              ];

          final int? assignmentId =
              _toInt(
            assignment[
              'id'
            ],
          );

          final List<Map<String, dynamic>> results =
              assignmentId == null
                  ? []
                  : _resultsByAssignment[
                        assignmentId
                      ] ??
                      [];

          return Padding(
            padding:
                const EdgeInsets.only(
              bottom:
                  14,
            ),
            child:
                _AssignmentResultsCard(
              assignment:
                  assignment,
              results:
                  results,
              onOpenStudent:
                  (
                    int studentId,
                    String studentLabel,
                  ) {
                Navigator.of(
                  context,
                ).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) =>
                            TeacherStudentQuizStatisticsPage(
                      studentId:
                          studentId,
                      studentLabel:
                          studentLabel,
                      department:
                          widget.department,
                      course:
                          widget.course,
                      subject:
                          widget.subject,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }


  Widget _state(
    IconData icon,
    String title,
    String message,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size:
                  48,
              color:
                  AppColors.skyBlue,
            ),
            const SizedBox(
              height:
                  12,
            ),
            Text(
              title,
              textAlign:
                  TextAlign.center,
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
                  6,
            ),
            Text(
              message,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }


  int? _toInt(
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


  String _cleanError(
    Object error,
  ) {
    String value =
        error.toString();

    if (
      value.startsWith(
        'Exception: ',
      )
    ) {
      value =
          value.substring(
        11,
      );
    }

    return value.trim();
  }
}


class _AssignmentResultsCard
    extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final List<Map<String, dynamic>> results;
  final void Function(
    int studentId,
    String studentLabel,
  ) onOpenStudent;

  const _AssignmentResultsCard({
    required this.assignment,
    required this.results,
    required this.onOpenStudent,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final String title =
        assignment[
                'title']
            ?.toString() ??
        'Quiz';

    final int totalRecipients =
        assignment[
                    'recipients']
                is List
            ? (
                assignment[
                  'recipients'
                ] as List
              ).length
            : 0;

    final int completed =
        results.where(
      (
        Map<String, dynamic> result,
      ) =>
          result[
              'status'] ==
          'completed',
    ).length;

    final List<double> percentages =
        results
            .map(
              (
                Map<String, dynamic> result,
              ) =>
                  _toDouble(
                result[
                  'percentage'
                ],
              ),
            )
            .whereType<double>()
            .toList();

    final double? average =
        percentages.isEmpty
            ? null
            : percentages.reduce(
                    (
                      double a,
                      double b,
                    ) =>
                        a + b,
                  ) /
                  percentages.length;

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
      ),
      child:
          Column(
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
                  16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height:
                12,
          ),
          Wrap(
            spacing:
                8,
            runSpacing:
                8,
            children: [
              _metric(
                'Destinatari',
                '$totalRecipients',
              ),
              _metric(
                'Completati',
                '$completed',
              ),
              _metric(
                'Media',
                average == null
                    ? '—'
                    : '${average.toStringAsFixed(1)}%',
              ),
            ],
          ),
          if (
            results.isNotEmpty
          ) ...[
            const SizedBox(
              height:
                  16,
            ),
            const Divider(),
            const SizedBox(
              height:
                  6,
            ),
            for (
              final Map<String, dynamic> result
              in results
            )
              _AttemptRow(
                result:
                    result,
                onOpenStudent:
                    onOpenStudent,
              ),
          ],
        ],
      ),
    );
  }


  static Widget _metric(
    String label,
    String value,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            11,
        vertical:
            8,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue
                .withValues(
          alpha:
              0.35,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style:
                const TextStyle(
              color:
                  AppColors.pureWhite,
              fontSize:
                  14,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height:
                2,
          ),
          Text(
            label,
            style:
                const TextStyle(
              color:
                  Colors.white54,
              fontSize:
                  9,
            ),
          ),
        ],
      ),
    );
  }


  static double? _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ??
          '',
    );
  }
}


class _AttemptRow
    extends StatelessWidget {
  final Map<String, dynamic> result;
  final void Function(
    int studentId,
    String studentLabel,
  ) onOpenStudent;

  const _AttemptRow({
    required this.result,
    required this.onOpenStudent,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final int? userId =
        _toInt(
      result[
        'user_id'
      ],
    );

    final String label =
        result[
                'user_name']
            ?.toString()
            .trim()
            .isNotEmpty ==
        true
            ? result[
                    'user_name']
                .toString()
            : userId == null
                ? 'Studente'
                : 'Studente #$userId';

    final String status =
        result[
                'status']
            ?.toString() ??
        '';

    final double? percentage =
        _toDouble(
      result[
        'percentage'
      ],
    );

    return ListTile(
      contentPadding:
          EdgeInsets.zero,
      leading:
          CircleAvatar(
        backgroundColor:
            AppColors.brandNightBlue,
        child:
            const Icon(
          Icons.person_outline_rounded,
          color:
              AppColors.skyBlue,
        ),
      ),
      title:
          Text(
        label,
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
      subtitle:
          Text(
        status ==
                'completed'
            ? 'Completato'
            : status ==
                    'in_progress'
                ? 'In corso'
                : 'Non completato',
        style:
            const TextStyle(
          color:
              Colors.white54,
          fontSize:
              10,
        ),
      ),
      trailing:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          if (
            percentage != null
          )
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style:
                  const TextStyle(
                color:
                    AppColors.skyBlue,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          if (
            userId != null
          )
            IconButton(
              tooltip:
                  'Statistiche studente',
              onPressed:
                  () =>
                      onOpenStudent(
                userId,
                label,
              ),
              icon:
                  const Icon(
                Icons.analytics_outlined,
                color:
                    Colors.white54,
              ),
            ),
        ],
      ),
    );
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


  static double? _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ??
          '',
    );
  }
}