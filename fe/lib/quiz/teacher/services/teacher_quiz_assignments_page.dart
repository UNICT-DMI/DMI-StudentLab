import 'package:flutter/material.dart';

import '../../../../theme/nightTheme.dart';
import '../quiz_assignment_form_page.dart';
import 'quiz_assignment_service.dart';


class TeacherQuizAssignmentsPage
    extends StatefulWidget {
  final int subjectId;
  final String department;
  final String course;
  final String subject;

  const TeacherQuizAssignmentsPage({
    super.key,
    required this.subjectId,
    required this.department,
    required this.course,
    required this.subject,
  });

  @override
  State<TeacherQuizAssignmentsPage>
      createState() =>
          _TeacherQuizAssignmentsPageState();
}


class _TeacherQuizAssignmentsPageState
    extends State<TeacherQuizAssignmentsPage> {
  final QuizAssignmentService _service =
      QuizAssignmentService();

  List<Map<String, dynamic>>
      _assignments = [];

  bool _loading =
      true;

  bool _busy =
      false;

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

      final List<Map<String, dynamic>> filtered =
          all.where(
        (
          Map<String, dynamic> item,
        ) {
          final int? subjectId =
              _toInt(
            item[
              'subject_id'
            ],
          );

          return subjectId ==
              widget.subjectId;
        },
      ).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _assignments =
            filtered;

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
          'Quiz · ${widget.subject}',
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
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _busy
                ? null
                : _create,
        icon:
            const Icon(
          Icons.add_rounded,
        ),
        label:
            const Text(
          'Nuovo quiz',
        ),
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
        'Impossibile caricare i quiz',
        _error!,
      );
    }

    if (_assignments.isEmpty) {
      return _state(
        Icons.assignment_outlined,
        'Nessun quiz assegnato',
        'Crea il primo quiz per questa materia.',
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
          100,
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

          return Padding(
            padding:
                const EdgeInsets.only(
              bottom:
                  12,
            ),
            child:
                _AssignmentCard(
              assignment:
                  assignment,
              onEdit:
                  () =>
                      _edit(
                assignment,
              ),
              onToggle:
                  () =>
                      _toggle(
                assignment,
              ),
              onDelete:
                  () =>
                      _delete(
                assignment,
              ),
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
              color:
                  AppColors.skyBlue,
              size:
                  48,
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


  Future<void> _create() async {
    final Map<String, dynamic>? result =
        await Navigator.of(
      context,
    ).push<
        Map<String, dynamic>>(
      MaterialPageRoute(
        builder:
            (_) =>
                QuizAssignmentFormPage(
          subjectId:
              widget.subjectId,
          department:
              widget.department,
          course:
              widget.course,
          subject:
              widget.subject,
        ),
      ),
    );

    if (
      result != null
    ) {
      await _load();
    }
  }


  Future<void> _edit(
    Map<String, dynamic> assignment,
  ) async {
    final Map<String, dynamic>? result =
        await Navigator.of(
      context,
    ).push<
        Map<String, dynamic>>(
      MaterialPageRoute(
        builder:
            (_) =>
                QuizAssignmentFormPage(
          subjectId:
              widget.subjectId,
          department:
              widget.department,
          course:
              widget.course,
          subject:
              widget.subject,
          assignment:
              assignment,
        ),
      ),
    );

    if (
      result != null
    ) {
      await _load();
    }
  }


  Future<void> _toggle(
    Map<String, dynamic> assignment,
  ) async {
    final int? id =
        _toInt(
      assignment[
        'id'
      ],
    );

    if (id == null) {
      return;
    }

    setState(() {
      _busy =
          true;
    });

    try {
      final bool active =
          assignment[
              'is_active'] !=
          false;

      if (active) {
        await _service
            .deactivateAssignment(
          id,
        );
      } else {
        await _service
            .activateAssignment(
          id,
        );
      }

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            _cleanError(
              error,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy =
              false;
        });
      }
    }
  }


  Future<void> _delete(
    Map<String, dynamic> assignment,
  ) async {
    final int? id =
        _toInt(
      assignment[
        'id'
      ],
    );

    if (id == null) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context:
          context,
      builder:
          (
        BuildContext context,
      ) {
        return AlertDialog(
          title:
              const Text(
            'Eliminare il quiz?',
          ),
          content:
              const Text(
            'Gli snapshot dei tentativi già eseguiti restano gestiti dallo storico.',
          ),
          actions: [
            TextButton(
              onPressed:
                  () =>
                      Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text(
                'Annulla',
              ),
            ),
            FilledButton(
              onPressed:
                  () =>
                      Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text(
                'Elimina',
              ),
            ),
          ],
        );
      },
    );

    if (
      confirmed !=
      true
    ) {
      return;
    }

    try {
      await _service
          .deleteAssignment(
        id,
      );

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            _cleanError(
              error,
            ),
          ),
        ),
      );
    }
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


class _AssignmentCard
    extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AssignmentCard({
    required this.assignment,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final bool active =
        assignment[
            'is_active'] !=
        false;

    final String title =
        assignment[
                'title']
            ?.toString() ??
        'Quiz';

    final String mode =
        assignment[
                'selection_mode']
            ?.toString() ??
        'random';

    final int recipients =
        assignment[
                    'recipients']
                is List
            ? (
                assignment[
                  'recipients'
                ] as List
              ).length
            : 0;

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
          16,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      9,
                  vertical:
                      5,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      active
                          ? Colors.greenAccent
                              .withValues(
                            alpha:
                                0.1,
                          )
                          : Colors.white10,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child:
                    Text(
                  active
                      ? 'Attivo'
                      : 'Disattivato',
                  style:
                      TextStyle(
                    color:
                        active
                            ? Colors.greenAccent
                            : Colors.white54,
                    fontSize:
                        10,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected:
                    (
                  String value,
                ) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;

                    case 'toggle':
                      onToggle();
                      break;

                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder:
                    (_) => [
                  const PopupMenuItem(
                    value:
                        'edit',
                    child:
                        Text(
                      'Modifica',
                    ),
                  ),
                  PopupMenuItem(
                    value:
                        'toggle',
                    child:
                        Text(
                      active
                          ? 'Disattiva'
                          : 'Riattiva',
                    ),
                  ),
                  const PopupMenuItem(
                    value:
                        'delete',
                    child:
                        Text(
                      'Elimina',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(
            height:
                10,
          ),
          Wrap(
            spacing:
                8,
            runSpacing:
                8,
            children: [
              _chip(
                Icons.shuffle_rounded,
                _modeLabel(
                  mode,
                ),
              ),
              _chip(
                Icons.quiz_outlined,
                '${assignment['question_count'] ?? 0} domande',
              ),
              _chip(
                Icons.people_outline_rounded,
                '$recipients destinatari',
              ),
              if (
                assignment[
                    'time_limit_seconds'] !=
                null
              )
                _chip(
                  Icons.timer_outlined,
                  '${((assignment['time_limit_seconds'] as num) / 60).ceil()} min',
                ),
            ],
          ),
        ],
      ),
    );
  }


  static Widget _chip(
    IconData icon,
    String text,
  ) {
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
            AppColors.brandNightBlue
                .withValues(
          alpha:
              0.35,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
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
                AppColors.skyBlue,
          ),
          const SizedBox(
            width:
                5,
          ),
          Text(
            text,
            style:
                const TextStyle(
              color:
                  Colors.white70,
              fontSize:
                  10,
            ),
          ),
        ],
      ),
    );
  }


  static String _modeLabel(
    String mode,
  ) {
    switch (mode) {
      case 'arguments':
        return 'Per argomento';

      case 'selected_questions':
        return 'Domande specifiche';

      default:
        return 'Casuale';
    }
  }
}