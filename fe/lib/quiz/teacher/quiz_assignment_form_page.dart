import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../theme/nightTheme.dart';
import '../../social/social_models.dart';
import 'services/question_management_service.dart';
import 'services/quiz_assignment_service.dart';
import 'widgets/quiz_assignment_mode_section.dart';


class QuizAssignmentFormPage
    extends StatefulWidget {
  final int subjectId;
  final String department;
  final String course;
  final String subject;
  final Map<String, dynamic>? assignment;

  const QuizAssignmentFormPage({
    super.key,
    required this.subjectId,
    required this.department,
    required this.course,
    required this.subject,
    this.assignment,
  });

  bool get isEditing =>
      assignment != null;

  @override
  State<QuizAssignmentFormPage>
      createState() =>
          _QuizAssignmentFormPageState();
}


class _QuizAssignmentFormPageState
    extends State<QuizAssignmentFormPage> {
  final ApiService _apiService =
      ApiService();

  final QuizAssignmentService _service =
      QuizAssignmentService();

  final QuestionManagementService
      _questionService =
      QuestionManagementService();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController
      _descriptionController =
      TextEditingController();

  final TextEditingController
      _questionCountController =
      TextEditingController(
    text: '10',
  );

  final TextEditingController
      _timeLimitController =
      TextEditingController(
    text: '30',
  );

  String _selectionMode =
      'random';

  String _executionMode =
      'practice';

  String _externalActivityPolicy =
      'disabled';

  DateTime? _dueAt;

  List<SocialUser> _users =
      [];

  List<Map<String, dynamic>> _groups =
      [];

  List<Map<String, dynamic>> _questions =
      [];

  final Set<int> _selectedUserIds =
      {};

  final Set<int> _selectedGroupIds =
      {};

  final Set<int> _selectedQuestionIds =
      {};

  final Set<String> _selectedArguments =
      {};

  bool _loading =
      true;

  bool _saving =
      false;

  String? _error;


  @override
  void initState() {
    super.initState();
    _load();
  }


  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _questionCountController.dispose();
    _timeLimitController.dispose();
    super.dispose();
  }


  Future<void> _load() async {
    try {
      final List<SocialUser> users =
          await _apiService
              .getSocialUsers();

      final List<Map<String, dynamic>> groups =
          await _apiService
              .getGroups();

      final List<Map<String, dynamic>> questions =
          await _questionService
              .getQuestions(
        department:
            widget.department,
        course:
            widget.course,
        subject:
            widget.subject,
        includeHidden:
            false,
      );

      _loadAssignmentValues();

      if (!mounted) {
        return;
      }

      setState(() {
        _users =
            users;

        _groups =
            groups;

        _questions =
            questions;

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


  void _loadAssignmentValues() {
    final Map<String, dynamic>? data =
        widget.assignment;

    if (data == null) {
      return;
    }

    _titleController.text =
        data['title']
            ?.toString() ??
        '';

    _descriptionController.text =
        data['description']
            ?.toString() ??
        '';

    _selectionMode =
        data['selection_mode']
            ?.toString() ??
        'random';

    _executionMode =
        data['execution_mode']
            ?.toString() ??
        'practice';

    _externalActivityPolicy =
        data['external_activity_policy']
            ?.toString() ??
        'disabled';

    _questionCountController.text =
        data['question_count']
            ?.toString() ??
        '10';

    final dynamic secondsRaw =
        data['time_limit_seconds'];

    if (secondsRaw != null) {
      final int? seconds =
          int.tryParse(
        secondsRaw.toString(),
      );

      if (seconds != null) {
        _timeLimitController.text =
            (seconds / 60)
                .ceil()
                .toString();
      }
    }

    final String due =
        data['due_at']
            ?.toString() ??
        '';

    if (due.isNotEmpty) {
      _dueAt =
          DateTime.tryParse(
        due,
      )?.toLocal();
    }

    final dynamic args =
        data['selected_arguments'];

    if (args is List) {
      _selectedArguments.addAll(
        args
            .map(
              (dynamic e) =>
                  e.toString(),
            )
            .where(
              (String e) =>
                  e.trim().isNotEmpty,
            ),
      );
    }

    final dynamic questionIds =
        data['selected_question_ids'];

    if (questionIds is List) {
      for (final dynamic raw in questionIds) {
        final int? id =
            _toInt(
          raw,
        );

        if (id != null) {
          _selectedQuestionIds.add(
            id,
          );
        }
      }
    }

    final dynamic recipients =
        data['recipients'];

    if (recipients is List) {
      for (final dynamic raw in recipients) {
        if (raw is! Map) {
          continue;
        }

        final int? userId =
            _toInt(
          raw['user_id'],
        );

        final int? groupId =
            _toInt(
          raw['group_id'],
        );

        if (userId != null) {
          _selectedUserIds.add(
            userId,
          );
        }

        if (groupId != null) {
          _selectedGroupIds.add(
            groupId,
          );
        }
      }
    }
  }


  List<String> get _arguments {
    final Set<String> values =
        {};

    for (final Map<String, dynamic> question in _questions) {
      final dynamic metadata =
          question['metadata'];

      if (metadata is! Map) {
        continue;
      }

      final String argument =
          metadata['argoment']
              ?.toString()
              .trim() ??
          '';

      if (argument.isNotEmpty) {
        values.add(
          argument,
        );
      }
    }

    final List<String> result =
        values.toList()
          ..sort();

    return result;
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
          widget.isEditing
              ? 'Modifica quiz'
              : 'Nuovo quiz',
        ),
      ),
      body:
          _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : _error != null
                  ? Center(
                      child:
                          Padding(
                        padding:
                            const EdgeInsets.all(
                          24,
                        ),
                        child:
                            Text(
                          _error!,
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                          ),
                        ),
                      ),
                    )
                  : SafeArea(
                      child:
                          Center(
                        child:
                            ConstrainedBox(
                          constraints:
                              const BoxConstraints(
                            maxWidth:
                                820,
                          ),
                          child:
                              Form(
                            key:
                                _formKey,
                            child:
                                ListView(
                              padding:
                                  const EdgeInsets.all(
                                20,
                              ),
                              children: [
                                _header(),
                                const SizedBox(
                                  height:
                                      20,
                                ),
                                _textField(
                                  controller:
                                      _titleController,
                                  label:
                                      'Titolo',
                                  required:
                                      true,
                                  icon:
                                      Icons.title_rounded,
                                ),
                                const SizedBox(
                                  height:
                                      14,
                                ),
                                _textField(
                                  controller:
                                      _descriptionController,
                                  label:
                                      'Descrizione',
                                  icon:
                                      Icons.notes_rounded,
                                  minLines:
                                      3,
                                  maxLines:
                                      6,
                                ),
                                const SizedBox(
                                  height:
                                      22,
                                ),
                                _section(
                                  'Modalità di svolgimento',
                                ),
                                const SizedBox(
                                  height:
                                      10,
                                ),
                                QuizAssignmentModeSection(
                                  executionMode:
                                      _executionMode,
                                  externalActivityPolicy:
                                      _externalActivityPolicy,
                                  onExecutionModeChanged:
                                      (value) {
                                    setState(() {
                                      _executionMode =
                                          value;
                                      if (value ==
                                          'practice') {
                                        _externalActivityPolicy =
                                            'disabled';
                                      }
                                    });
                                  },
                                  onExternalActivityPolicyChanged:
                                      (value) {
                                    setState(() {
                                      _externalActivityPolicy =
                                          value;
                                    });
                                  },
                                ),
                                const SizedBox(
                                  height:
                                      22,
                                ),
                                _section(
                                  'Selezione domande',
                                ),
                                const SizedBox(
                                  height:
                                      10,
                                ),
                                _selectionModeCard(),
                                if (
                                  _selectionMode ==
                                  'random'
                                ) ...[
                                  const SizedBox(
                                    height:
                                        14,
                                  ),
                                  _textField(
                                    controller:
                                        _questionCountController,
                                    label:
                                        'Numero domande',
                                    required:
                                        true,
                                    icon:
                                        Icons.numbers_rounded,
                                    keyboardType:
                                        TextInputType.number,
                                  ),
                                ],
                                if (
                                  _selectionMode ==
                                  'arguments'
                                ) ...[
                                  const SizedBox(
                                    height:
                                        14,
                                  ),
                                  _argumentsCard(),
                                  const SizedBox(
                                    height:
                                        14,
                                  ),
                                  _textField(
                                    controller:
                                        _questionCountController,
                                    label:
                                        'Numero domande',
                                    required:
                                        true,
                                    icon:
                                        Icons.numbers_rounded,
                                    keyboardType:
                                        TextInputType.number,
                                  ),
                                ],
                                if (
                                  _selectionMode ==
                                  'selected_questions'
                                ) ...[
                                  const SizedBox(
                                    height:
                                        14,
                                  ),
                                  _questionsCard(),
                                ],
                                const SizedBox(
                                  height:
                                      22,
                                ),
                                _section(
                                  'Tempo e scadenza',
                                ),
                                const SizedBox(
                                  height:
                                      10,
                                ),
                                _textField(
                                  controller:
                                      _timeLimitController,
                                  label:
                                      'Tempo limite',
                                  icon:
                                      Icons.timer_outlined,
                                  keyboardType:
                                      TextInputType.number,
                                  suffixText:
                                      'minuti',
                                ),
                                const SizedBox(
                                  height:
                                      12,
                                ),
                                _dueDateCard(),
                                const SizedBox(
                                  height:
                                      22,
                                ),
                                _section(
                                  'Destinatari',
                                ),
                                const SizedBox(
                                  height:
                                      10,
                                ),
                                _recipientsCard(),
                                if (
                                  _error != null
                                ) ...[
                                  const SizedBox(
                                    height:
                                        16,
                                  ),
                                  Text(
                                    _error!,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.redAccent,
                                    ),
                                  ),
                                ],
                                const SizedBox(
                                  height:
                                      24,
                                ),
                                SizedBox(
                                  height:
                                      52,
                                  child:
                                      FilledButton.icon(
                                    onPressed:
                                        _saving
                                            ? null
                                            : _save,
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
                                                ),
                                              )
                                            : const Icon(
                                                Icons.assignment_turned_in_outlined,
                                              ),
                                    label:
                                        Text(
                                      _saving
                                          ? 'Salvataggio...'
                                          : widget.isEditing
                                              ? 'Salva modifiche'
                                              : 'Assegna quiz',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }


  Widget _header() {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
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
          Row(
        children: [
          const Icon(
            Icons.quiz_outlined,
            color:
                AppColors.skyBlue,
            size:
                30,
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
                  widget.subject,
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
                      3,
                ),
                Text(
                  '${widget.department} • ${widget.course}',
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize:
                        11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _section(
    String title,
  ) {
    return Text(
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
    );
  }


  Widget _selectionModeCard() {
    return _card(
      Column(
        children: [
          RadioListTile<String>(
            value:
                'random',
            groupValue:
                _selectionMode,
            onChanged:
                _setMode,
            title:
                const Text(
              'Casuale',
              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,
              ),
            ),
            subtitle:
                const Text(
              'Il server sceglie casualmente le domande.',
              style:
                  TextStyle(
                color:
                    Colors.white54,
                fontSize:
                    11,
              ),
            ),
          ),
          RadioListTile<String>(
            value:
                'arguments',
            groupValue:
                _selectionMode,
            onChanged:
                _setMode,
            title:
                const Text(
              'Per argomento',
              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,
              ),
            ),
          ),
          RadioListTile<String>(
            value:
                'selected_questions',
            groupValue:
                _selectionMode,
            onChanged:
                _setMode,
            title:
                const Text(
              'Domande specifiche',
              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _setMode(
    String? value,
  ) {
    if (value == null) {
      return;
    }

    setState(() {
      _selectionMode =
          value;
    });
  }


  Widget _argumentsCard() {
    final List<String> arguments =
        _arguments;

    return _card(
      arguments.isEmpty
          ? const Text(
              'Nessun argomento disponibile.',
              style:
                  TextStyle(
                color:
                    Colors.white54,
              ),
            )
          : Wrap(
              spacing:
                  8,
              runSpacing:
                  8,
              children: [
                for (
                  final String argument
                  in arguments
                )
                  FilterChip(
                    selected:
                        _selectedArguments
                            .contains(
                      argument,
                    ),
                    label:
                        Text(
                      argument,
                    ),
                    onSelected:
                        (
                      bool value,
                    ) {
                      setState(() {
                        if (value) {
                          _selectedArguments.add(
                            argument,
                          );
                        } else {
                          _selectedArguments.remove(
                            argument,
                          );
                        }
                      });
                    },
                  ),
              ],
            ),
    );
  }


  Widget _questionsCard() {
    return _card(
      Column(
        children: [
          for (
            final Map<String, dynamic> question
            in _questions
          )
            CheckboxListTile(
              value:
                  _selectedQuestionIds
                      .contains(
                _toInt(
                  question[
                    'id_question'
                  ],
                ),
              ),
              onChanged:
                  (
                bool? value,
              ) {
                final int? id =
                    _toInt(
                  question[
                    'id_question'
                  ],
                );

                if (id == null) {
                  return;
                }

                setState(() {
                  if (value == true) {
                    _selectedQuestionIds.add(
                      id,
                    );
                  } else {
                    _selectedQuestionIds.remove(
                      id,
                    );
                  }
                });
              },
              title:
                  Text(
                question[
                        'text']
                    ?.toString() ??
                    'Domanda',
                maxLines:
                    2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      AppColors.pureWhite,
                  fontSize:
                      12,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _dueDateCard() {
    return _card(
      Row(
        children: [
          const Icon(
            Icons.event_outlined,
            color:
                AppColors.skyBlue,
          ),
          const SizedBox(
            width:
                10,
          ),
          Expanded(
            child:
                Text(
              _dueAt == null
                  ? 'Nessuna scadenza'
                  : _formatDate(
                      _dueAt!,
                    ),
              style:
                  const TextStyle(
                color:
                    AppColors.pureWhite,
              ),
            ),
          ),
          TextButton(
            onPressed:
                _pickDueAt,
            child:
                const Text(
              'Imposta',
            ),
          ),
          if (
            _dueAt != null
          )
            IconButton(
              tooltip:
                  'Rimuovi scadenza',
              onPressed:
                  () {
                setState(() {
                  _dueAt =
                      null;
                });
              },
              icon:
                  const Icon(
                Icons.close_rounded,
              ),
            ),
        ],
      ),
    );
  }


  Widget _recipientsCard() {
    return _card(
      Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Studenti',
            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height:
                8,
          ),
          for (
            final SocialUser user
            in _users
          )
            CheckboxListTile(
              dense:
                  true,
              value:
                  _selectedUserIds
                      .contains(
                user.id,
              ),
              onChanged:
                  (
                bool? selected,
              ) {
                setState(() {
                  if (selected == true) {
                    _selectedUserIds.add(
                      user.id,
                    );
                  } else {
                    _selectedUserIds.remove(
                      user.id,
                    );
                  }
                });
              },
              title:
                  Text(
                user.name,
                style:
                    const TextStyle(
                  color:
                      AppColors.pureWhite,
                  fontSize:
                      12,
                ),
              ),
            ),
          const Divider(),
          const Text(
            'Gruppi',
            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height:
                8,
          ),
          for (
            final Map<String, dynamic> group
            in _groups
          )
            Builder(
              builder:
                  (
                BuildContext context,
              ) {
                final int? id =
                    _toInt(
                  group[
                    'id'
                  ],
                );

                if (id == null) {
                  return const SizedBox.shrink();
                }

                return CheckboxListTile(
                  dense:
                      true,
                  value:
                      _selectedGroupIds
                          .contains(
                    id,
                  ),
                  onChanged:
                      (
                    bool? selected,
                  ) {
                    setState(() {
                      if (selected == true) {
                        _selectedGroupIds.add(
                          id,
                        );
                      } else {
                        _selectedGroupIds.remove(
                          id,
                        );
                      }
                    });
                  },
                  title:
                      Text(
                    group[
                            'name']
                        ?.toString() ??
                        'Gruppo #$id',
                    style:
                        const TextStyle(
                      color:
                          AppColors.pureWhite,
                      fontSize:
                          12,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }


  Widget _card(
    Widget child,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child:
          child,
    );
  }


  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? suffixText,
  }) {
    return TextFormField(
      controller:
          controller,
      minLines:
          minLines,
      maxLines:
          maxLines,
      keyboardType:
          keyboardType,
      style:
          const TextStyle(
        color:
            AppColors.pureWhite,
      ),
      validator:
          (
        String? value,
      ) {
        if (
          required &&
          (
            value == null ||
            value.trim().isEmpty
          )
        ) {
          return 'Campo obbligatorio.';
        }

        return null;
      },
      decoration:
          InputDecoration(
        labelText:
            label,
        prefixIcon:
            Icon(
          icon,
        ),
        suffixText:
            suffixText,
        filled:
            true,
        fillColor:
            AppColors.eleganceDeepNavy,
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            13,
          ),
        ),
      ),
    );
  }


  Future<void> _pickDueAt() async {
    final DateTime now =
        DateTime.now();

    final DateTime? date =
        await showDatePicker(
      context:
          context,
      firstDate:
          now,
      lastDate:
          DateTime(
        now.year + 5,
      ),
      initialDate:
          _dueAt ??
          now.add(
            const Duration(
              days:
                  1,
            ),
          ),
    );

    if (
      date == null ||
      !mounted
    ) {
      return;
    }

    final TimeOfDay? time =
        await showTimePicker(
      context:
          context,
      initialTime:
          _dueAt == null
              ? const TimeOfDay(
                  hour:
                      23,
                  minute:
                      59,
                )
              : TimeOfDay.fromDateTime(
                  _dueAt!,
                ),
    );

    if (
      time == null
    ) {
      return;
    }

    setState(() {
      _dueAt =
          DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }


  Future<void> _save() async {
    FocusScope.of(
      context,
    ).unfocus();

    if (
      !(
        _formKey.currentState
                ?.validate() ??
            false
      )
    ) {
      return;
    }

    if (
      _selectedUserIds.isEmpty &&
      _selectedGroupIds.isEmpty
    ) {
      setState(() {
        _error =
            'Seleziona almeno uno studente o un gruppo.';
      });

      return;
    }

    if (
      _selectionMode ==
          'arguments' &&
      _selectedArguments.isEmpty
    ) {
      setState(() {
        _error =
            'Seleziona almeno un argomento.';
      });

      return;
    }

    if (
      _selectionMode ==
          'selected_questions' &&
      _selectedQuestionIds.isEmpty
    ) {
      setState(() {
        _error =
            'Seleziona almeno una domanda.';
      });

      return;
    }

    final int? questionCount =
        int.tryParse(
      _questionCountController
          .text
          .trim(),
    );

    if (
      _selectionMode !=
          'selected_questions' &&
      (
        questionCount == null ||
        questionCount <= 0
      )
    ) {
      setState(() {
        _error =
            'Numero domande non valido.';
      });

      return;
    }

    final String timeText =
        _timeLimitController.text
            .trim();

    final int? minutes =
        timeText.isEmpty
            ? null
            : int.tryParse(
                timeText,
              );

    if (
      minutes != null &&
      minutes <= 0
    ) {
      setState(() {
        _error =
            'Tempo limite non valido.';
      });

      return;
    }

    setState(() {
      _saving =
          true;

      _error =
          null;
    });

    try {
      final Map<String, dynamic> payload = {
        'department':
            widget.department,
        'course':
            widget.course,
        'subject':
            widget.subject,
        'title':
            _titleController.text
                .trim(),
        'description':
            _descriptionController.text
                .trim(),
        'selection_mode':
            _selectionMode,
        'execution_mode':
            _executionMode,
        'external_activity_policy':
            _executionMode == 'simulation'
                ? _externalActivityPolicy
                : 'disabled',
        'arguments':
            _selectionMode ==
                    'arguments'
                ? _selectedArguments
                    .toList()
                : <String>[],
        'question_ids':
            _selectionMode ==
                    'selected_questions'
                ? _selectedQuestionIds
                    .toList()
                : <int>[],
        'question_count':
            _selectionMode ==
                    'selected_questions'
                ? _selectedQuestionIds.length
                : questionCount,
        'time_limit_seconds':
            minutes == null
                ? null
                : minutes * 60,
        'due_at':
            _dueAt
                ?.toUtc()
                .toIso8601String(),
        'user_ids':
            _selectedUserIds
                .toList(),
        'group_ids':
            _selectedGroupIds
                .toList(),
      };

      late final Map<String, dynamic> result;

      if (
        widget.isEditing
      ) {
        final int? assignmentId =
            _toInt(
          widget.assignment![
            'id'
          ],
        );

        if (assignmentId == null) {
          throw Exception(
            'Quiz non valido.',
          );
        }

        result =
            await _service
                .updateAssignment(
          assignmentId:
              assignmentId,
          data:
              payload,
        );
      } else {
        result =
            await _service
                .createAssignment(
          payload,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        result,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _cleanError(
          error,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving =
              false;
        });
      }
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


  String _formatDate(
    DateTime value,
  ) {
    final String day =
        value.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String month =
        value.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String hour =
        value.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String minute =
        value.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${value.year} $hour:$minute';
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