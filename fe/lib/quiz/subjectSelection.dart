import 'package:flutter/material.dart';

import '../services/api_service.dart';

import '../services/auth_session.dart';

import '../social/social_models.dart';

import 'assigned_quizzes_page.dart';

import 'quiz.dart';

import 'services/free_quiz_api_service.dart';

class SubjectSelection extends StatefulWidget {

  const SubjectSelection({

super.key,

  });

  @override

  State<SubjectSelection> createState() => _SubjectSelectionState();

}

class _SubjectSelectionState extends State<SubjectSelection> {

  final ApiService _apiService = ApiService();

  final FreeQuizApiService _quizApiService = FreeQuizApiService();

  final AuthSession _authSession = AuthSession.instance;

  final TextEditingController _questionController =

      TextEditingController(text: '10');

  List<AcademicUniversity> _universities = [];

  List<AcademicDepartment> _departments = [];

  List<AcademicCourse> _courses = [];

  List<String> _subjects = [];

  List<String> _availableArguments = [];

  final List<String> _selectedArguments = [];

  AcademicUniversity? _selectedUniversity;

  AcademicDepartment? _selectedDepartment;

  AcademicCourse? _selectedCourse;

  String? _selectedSubject;

  bool _loadingUniversities = false;

  bool _loadingDepartments = false;

  bool _loadingCourses = false;

  bool _loadingSubjects = false;

  bool _loadingArguments = false;

  bool _loadingQuestions = false;

  int _selectedQuiz = 10;

  int _availableQuestions = 0;

  bool get _isAuthenticated => _authSession.isAuthenticated;

  bool get _canSelectDepartment =>

      _selectedUniversity != null && !_loadingDepartments;

  bool get _canSelectCourse =>

      _selectedDepartment != null && !_loadingCourses;

  bool get _canSelectSubject =>

      _selectedCourse != null && !_loadingSubjects;

  bool get _canSelectArguments =>

      _selectedSubject != null &&

      !_loadingArguments &&

      _availableArguments.isNotEmpty;

  bool get _canStart =>

      _selectedDepartment != null &&

      _selectedCourse != null &&

      _selectedSubject != null &&

      _selectedArguments.isNotEmpty &&

      _availableQuestions > 0 &&

      _selectedQuiz >= 1 &&

      _selectedQuiz <= _availableQuestions &&

      !_loadingQuestions;

  @override

  void initState() {

super.initState();

    _authSession.addListener(_onAuthChanged);

    _loadUniversities();

  }

  @override

  void dispose() {

    _authSession.removeListener(_onAuthChanged);

    _questionController.dispose();

super.dispose();

  }

  void _onAuthChanged() {

    if (!mounted) {

      return;

    }

    setState(() {});

  }

  Future<void> _loadUniversities() async {

    setState(() {

      _loadingUniversities = true;

    });

    try {

      final List<AcademicUniversity> values =

          await _apiService.getUniversities();

      if (!mounted) {

        return;

      }

      setState(() {

        _universities = values;

        _loadingUniversities = false;

      });

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _universities = [];

        _loadingUniversities = false;

      });

      _showMessage(

        'Non è stato possibile caricare gli atenei disponibili.',

      );

    }

  }

  Future<void> _onUniversityChanged(

    AcademicUniversity? university,

  ) async {

    if (university == null) {

      return;

    }

    setState(() {

      _selectedUniversity = university;

      _departments = [];

      _courses = [];

      _subjects = [];

      _availableArguments = [];

      _selectedDepartment = null;

      _selectedCourse = null;

      _selectedSubject = null;

      _selectedArguments.clear();

      _resetQuestions();

      _loadingDepartments = true;

    });

    try {

      final List<AcademicDepartment> values =

          await _apiService.getDepartments(university.code);

      if (!mounted || _selectedUniversity?.code != university.code) {

        return;

      }

      setState(() {

        _departments = values;

        _loadingDepartments = false;

      });

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _departments = [];

        _loadingDepartments = false;

      });

      _showMessage(

        'Non è stato possibile caricare i dipartimenti.',

      );

    }

  }

  Future<void> _onDepartmentChanged(

    AcademicDepartment? department,

  ) async {

    final AcademicUniversity? university = _selectedUniversity;

    if (department == null || university == null) {

      return;

    }

    setState(() {

      _selectedDepartment = department;

      _courses = [];

      _subjects = [];

      _availableArguments = [];

      _selectedCourse = null;

      _selectedSubject = null;

      _selectedArguments.clear();

      _resetQuestions();

      _loadingCourses = true;

    });

    try {

      final List<AcademicCourse> values = await _apiService.getCourses(

        universityCode: university.code,

        departmentCode: department.code,

      );

      if (!mounted || _selectedDepartment?.code != department.code) {

        return;

      }

      setState(() {

        _courses = values;

        _loadingCourses = false;

      });

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _courses = [];

        _loadingCourses = false;

      });

      _showMessage(

        'Non è stato possibile caricare i corsi.',

      );

    }

  }

  Future<void> _onCourseChanged(
    AcademicCourse? course,
  ) async {
    final AcademicDepartment? department = _selectedDepartment;
    if (course == null || department == null) {
      return;
    }

    setState(() {
      _selectedCourse = course;
      _subjects = [];
      _availableArguments = [];
      _selectedSubject = null;
      _selectedArguments.clear();
      _resetQuestions();
      _loadingSubjects = true;
    });

    try {
      final List<String> values = await _quizApiService.getAvailableSubjects(
        department: department.code,
        course: course.code,
      );

      if (!mounted || _selectedCourse?.code != course.code) {
        return;
      }

      final List<String> availableSubjects = values
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort(
          (String a, String b) =>
              a.toLowerCase().compareTo(b.toLowerCase()),
        );

      setState(() {
        _subjects = availableSubjects;
        _loadingSubjects = false;
      });

      if (availableSubjects.isEmpty) {
        _showMessage(
          'Non ci sono ancora quiz disponibili per questo corso.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = [];
        _loadingSubjects = false;
      });

      _showMessage(
        'Non è stato possibile caricare le materie.',
      );
    }
  }

  Future<void> _onSubjectChanged(
    String? subject,
  ) async {

    final AcademicDepartment? department = _selectedDepartment;

    final AcademicCourse? course = _selectedCourse;

    if (subject == null || department == null || course == null) {

      return;

    }

    setState(() {

      _selectedSubject = subject;

      _availableArguments = [];

      _selectedArguments.clear();

      _resetQuestions();

      _loadingArguments = true;

    });

    try {

      final List<String> values = await _quizApiService.getArguments(

        department: department.code,

        course: course.code,

        subject: subject,

      );

      if (!mounted || _selectedSubject != subject) {

        return;

      }

      setState(() {

        _availableArguments = values;

        _loadingArguments = false;

      });

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _availableArguments = [];

        _loadingArguments = false;

      });

      _showMessage(

        'Non è stato possibile caricare gli argomenti di questa materia.',

      );

    }

  }

  Future<void> _selectArguments() async {

    if (!_canSelectArguments) {

      return;

    }

    final List<String> temporary =

        List<String>.from(_selectedArguments);

    final List<String>? result =

        await showModalBottomSheet<List<String>>(

      context: context,

      isScrollControlled: true,

      builder: (BuildContext modalContext) {

        return StatefulBuilder(

          builder: (

            BuildContext context,

            StateSetter setModalState,

          ) {

            final bool allSelected =

                temporary.length == _availableArguments.length &&

                _availableArguments.isNotEmpty;

            return SafeArea(

              child: FractionallySizedBox(

                heightFactor: 0.78,

                child: Column(

                  children: [

                    const SizedBox(height: 10),

                    Container(

                      width: 42,

                      height: 4,

                      decoration: BoxDecoration(

                        color: Colors.grey.withOpacity(0.4),

                        borderRadius: BorderRadius.circular(20),

                      ),

                    ),

                    const Padding(

                      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),

                      child: Align(

                        alignment: Alignment.centerLeft,

                        child: Text(

                          'Argomenti',

                          style: TextStyle(

                            fontSize: 20,

                            fontWeight: FontWeight.bold,

                          ),

                        ),

                      ),

                    ),

                    CheckboxListTile(

                      value: allSelected,

                      title: const Text('Tutti gli argomenti'),

                      onChanged: (bool? value) {

                        setModalState(() {

                          temporary.clear();

                          if (value == true) {

                            temporary.addAll(_availableArguments);

                          }

                        });

                      },

                    ),

                    const Divider(height: 1),

                    Expanded(

                      child: ListView.builder(

                        itemCount: _availableArguments.length,

                        itemBuilder: (

                          BuildContext context,

                          int index,

                        ) {

                          final String argument =

                              _availableArguments[index];

                          return CheckboxListTile(

                            value: temporary.contains(argument),

                            title: Text(argument),

                            onChanged: (bool? value) {

                              setModalState(() {

                                if (value == true) {

                                  if (!temporary.contains(argument)) {

                                    temporary.add(argument);

                                  }

                                } else {

                                  temporary.remove(argument);

                                }

                              });

                            },

                          );

                        },

                      ),

                    ),

                    Padding(

                      padding: const EdgeInsets.all(20),

                      child: SizedBox(

                        width: double.infinity,

                        height: 50,

                        child: ElevatedButton(

                          onPressed: temporary.isEmpty

                              ? null

                              : () {

                                  Navigator.pop(

                                    modalContext,

                                    List<String>.from(temporary),

                                  );

                                },

                          child: const Text('Conferma'),

                        ),

                      ),

                    ),

                  ],

                ),

              ),

            );

          },

        );

      },

    );

    if (result == null) {

      return;

    }

    setState(() {

      _selectedArguments

        ..clear()

        ..addAll(result);

      _resetQuestions();

    });

    await _updateQuestionCount();

  }

  Future<void> _updateQuestionCount() async {

    final AcademicDepartment? department = _selectedDepartment;

    final AcademicCourse? course = _selectedCourse;

    final String? subject = _selectedSubject;

    if (department == null ||

        course == null ||

        subject == null ||

        _selectedArguments.isEmpty) {

      return;

    }

    setState(() {

      _loadingQuestions = true;

    });

    try {

      final int count = await _quizApiService.getQuestionCount(

        department: department.code,

        course: course.code,

        subject: subject,

        arguments: _selectedArguments,

      );

      if (!mounted) {

        return;

      }

      setState(() {

        _availableQuestions = count;

        _selectedQuiz = count == 0 ? 0 : (count >= 10 ? 10 : count);

        _questionController.text =

            _selectedQuiz == 0 ? '' : _selectedQuiz.toString();

        _loadingQuestions = false;

      });

    } catch (_) {

      if (!mounted) {

        return;

      }

      setState(() {

        _loadingQuestions = false;

        _availableQuestions = 0;

        _selectedQuiz = 0;

        _questionController.clear();

      });

      _showMessage(

        'Non è stato possibile calcolare le domande disponibili.',

      );

    }

  }

  void _resetQuestions() {

    _availableQuestions = 0;

    _selectedQuiz = 10;

    _questionController.text = '10';

    _loadingQuestions = false;

  }

  void _changeQuestionNumber(int delta) {

    if (_availableQuestions <= 0) {

      return;

    }

    final int value =

        (_selectedQuiz + delta).clamp(1, _availableQuestions);

    setState(() {

      _selectedQuiz = value;

      _questionController.text = value.toString();

      _questionController.selection = TextSelection.collapsed(

        offset: _questionController.text.length,

      );

    });

  }

  void _onQuestionNumberChanged(String value) {

    if (_availableQuestions <= 0) {

      return;

    }

    final int? parsed = int.tryParse(value);

    if (parsed == null) {

      return;

    }

    final int normalized = parsed.clamp(1, _availableQuestions);

    if (normalized != parsed) {

      _questionController.text = normalized.toString();

      _questionController.selection = TextSelection.collapsed(

        offset: _questionController.text.length,

      );

    }

    setState(() {

      _selectedQuiz = normalized;

    });

  }

  Future<void> _openAssignedQuizzes() async {

    if (!_isAuthenticated) {

      return;

    }

    await Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => const AssignedQuizzesPage(),

      ),

    );

  }

  void _startQuiz() {

    final AcademicDepartment? department = _selectedDepartment;

    final AcademicCourse? course = _selectedCourse;

    final String? subject = _selectedSubject;

    if (!_canStart ||

        department == null ||

        course == null ||

        subject == null) {

      return;

    }

    Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => QuizPage(

          department: department.code,

          course: course.code,

          sub: subject,

          arguments: List<String>.unmodifiable(_selectedArguments),

          numberOfQuestions: _selectedQuiz,

        ),

      ),

    );

  }

  String _argumentsLabel() {

    if (_selectedSubject == null) {

      return 'Seleziona prima una materia';

    }

    if (_loadingArguments) {

      return 'Caricamento argomenti...';

    }

    if (_availableArguments.isEmpty) {

      return 'Nessun argomento disponibile';

    }

    if (_selectedArguments.isEmpty) {

      return 'Seleziona uno o più argomenti';

    }

    if (_selectedArguments.length == _availableArguments.length) {

      return 'Tutti gli argomenti';

    }

    return _selectedArguments.join(', ');

  }

  String _subjectLabel(String value) {
    final List<String> words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();

    return words
        .map(
          (String word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  void _showMessage(String message) {

    if (!mounted) {

      return;

    }

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(message),

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text('Quiz libero'),

      ),

      body: SafeArea(

        child: Center(

          child: ConstrainedBox(

            constraints: const BoxConstraints(maxWidth: 620),

            child: ListView(

              padding: const EdgeInsets.all(20),

              children: [

                if (_isAuthenticated) ...[

                  _AssignedQuizEntryCard(

                    onTap: _openAssignedQuizzes,

                  ),

                  const SizedBox(height: 22),

                ],

                const Text(

                  'Configura il quiz',

                  style: TextStyle(

                    fontSize: 23,

                    fontWeight: FontWeight.bold,

                  ),

                ),

                const SizedBox(height: 6),

                const Text(

                  'Le scelte disponibili vengono caricate dal catalogo StudentLab.',

                  style: TextStyle(

                    color: Colors.grey,

                    fontSize: 12,

                  ),

                ),

                const SizedBox(height: 24),

                _CatalogDropdown<AcademicUniversity>(

                  label: 'Ateneo',

                  value: _selectedUniversity,

                  items: _universities,

                  itemLabel: (AcademicUniversity value) => value.name,

                  loading: _loadingUniversities,

                  enabled: !_loadingUniversities,

                  onChanged: _onUniversityChanged,

                ),

                const SizedBox(height: 16),

                _CatalogDropdown<AcademicDepartment>(

                  label: 'Dipartimento',

                  value: _selectedDepartment,

                  items: _departments,

                  itemLabel: (AcademicDepartment value) => value.name,

                  loading: _loadingDepartments,

                  enabled: _canSelectDepartment,

                  onChanged: _onDepartmentChanged,

                ),

                const SizedBox(height: 16),

                _CatalogDropdown<AcademicCourse>(

                  label: 'Corso',

                  value: _selectedCourse,

                  items: _courses,

                  itemLabel: (AcademicCourse value) => value.name,

                  loading: _loadingCourses,

                  enabled: _canSelectCourse,

                  onChanged: _onCourseChanged,

                ),

                const SizedBox(height: 16),

                _CatalogDropdown<String>(

                  label: 'Materia',

                  value: _selectedSubject,

                  items: _subjects,

                  itemLabel: (String value) => _subjectLabel(value),

                  loading: _loadingSubjects,

                  enabled: _canSelectSubject,

                  onChanged: _onSubjectChanged,

                ),

                const SizedBox(height: 16),

                InkWell(

                  onTap: _canSelectArguments ? _selectArguments : null,

                  borderRadius: BorderRadius.circular(4),

                  child: InputDecorator(

                    decoration: InputDecoration(

                      labelText: 'Argomenti',

                      border: const OutlineInputBorder(),

                      suffixIcon: _loadingArguments

                          ? const Padding(

                              padding: EdgeInsets.all(13),

                              child: SizedBox(

                                width: 18,

                                height: 18,

                                child: CircularProgressIndicator(

                                  strokeWidth: 2,

                                ),

                              ),

                            )

                          : const Icon(Icons.keyboard_arrow_down_rounded),

                    ),

                    child: Text(

                      _argumentsLabel(),

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(

                        color: _selectedArguments.isEmpty

                            ? Colors.grey

                            : null,

                      ),

                    ),

                  ),

                ),

                const SizedBox(height: 18),

                _QuestionAvailabilityCard(

                  loading: _loadingQuestions,

                  count: _availableQuestions,

                  hasArguments: _selectedArguments.isNotEmpty,

                ),

                if (_availableQuestions > 0) ...[

                  const SizedBox(height: 20),

                  const Text(

                    'Numero di domande',

                    style: TextStyle(

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                  const SizedBox(height: 8),

                  Row(

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      IconButton(

                        onPressed: _selectedQuiz <= 1

                            ? null

                            : () => _changeQuestionNumber(-1),

                        icon: const Icon(Icons.remove_rounded),

                      ),

                      SizedBox(

                        width: 90,

                        child: TextField(

                          controller: _questionController,

                          textAlign: TextAlign.center,

                          keyboardType: TextInputType.number,

                          onChanged: _onQuestionNumberChanged,

                          decoration: const InputDecoration(

                            border: OutlineInputBorder(),

                            isDense: true,

                          ),

                        ),

                      ),

                      IconButton(

                        onPressed: _selectedQuiz >= _availableQuestions

                            ? null

                            : () => _changeQuestionNumber(1),

                        icon: const Icon(Icons.add_rounded),

                      ),

                    ],

                  ),

                  const SizedBox(height: 4),

                  Center(

                    child: Text(

                      'Massimo: $_availableQuestions',

                      style: const TextStyle(

                        color: Colors.grey,

                        fontSize: 12,

                      ),

                    ),

                  ),

                ],

                const SizedBox(height: 28),

                SizedBox(

                  height: 52,

                  child: ElevatedButton.icon(

                    onPressed: _canStart ? _startQuiz : null,

                    icon: const Icon(Icons.play_arrow_rounded),

                    label: const Text(

                      'Avvia Quiz',

                      style: TextStyle(

                        fontSize: 16,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}

class _CatalogDropdown<T> extends StatelessWidget {

  final String label;

  final T? value;

  final List<T> items;

  final String Function(T value) itemLabel;

  final bool loading;

  final bool enabled;

  final ValueChanged<T?> onChanged;

  const _CatalogDropdown({

    required this.label,

    required this.value,

    required this.items,

    required this.itemLabel,

    required this.loading,

    required this.enabled,

    required this.onChanged,

  });

  @override

  Widget build(BuildContext context) {

    return DropdownButtonFormField<T>(

      value: value,

      isExpanded: true,

      decoration: InputDecoration(

        labelText: label,

        border: const OutlineInputBorder(),

        suffixIcon: loading

            ? const Padding(

                padding: EdgeInsets.all(13),

                child: SizedBox(

                  width: 18,

                  height: 18,

                  child: CircularProgressIndicator(

                    strokeWidth: 2,

                  ),

                ),

              )

            : null,

      ),

      hint: Text(

        loading ? 'Caricamento...' : 'Seleziona $label',

      ),

      items: items

          .map(

            (T item) => DropdownMenuItem<T>(

              value: item,

              child: Text(

                itemLabel(item),

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

              ),

            ),

          )

          .toList(),

      onChanged: enabled ? onChanged : null,

    );

  }

}

class _QuestionAvailabilityCard extends StatelessWidget {

  final bool loading;

  final int count;

  final bool hasArguments;

  const _QuestionAvailabilityCard({

    required this.loading,

    required this.count,

    required this.hasArguments,

  });

  @override

  Widget build(BuildContext context) {

    String value;

    if (loading) {

      value = 'Calcolo in corso...';

    } else if (!hasArguments) {

      value = 'Seleziona gli argomenti';

    } else {

      value = '$count domande disponibili';

    }

    return Container(

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: Theme.of(context)

            .colorScheme

            .surfaceContainerHighest

            .withOpacity(0.35),

        borderRadius: BorderRadius.circular(12),

      ),

      child: Row(

        children: [

          const Icon(Icons.quiz_outlined),

          const SizedBox(width: 12),

          Expanded(

            child: Text(value),

          ),

        ],

      ),

    );

  }

}

class _AssignedQuizEntryCard extends StatelessWidget {

  final VoidCallback onTap;

  const _AssignedQuizEntryCard({

    required this.onTap,

  });

  @override

  Widget build(BuildContext context) {

    final ColorScheme colors = Theme.of(context).colorScheme;

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Ink(

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(

            color: colors.primaryContainer.withOpacity(0.35),

            borderRadius: BorderRadius.circular(14),

            border: Border.all(

              color: colors.primary.withOpacity(0.18),

            ),

          ),

          child: const Row(

            children: [

              Icon(

                Icons.assignment_outlined,

                size: 28,

              ),

              SizedBox(width: 13),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'Quiz assegnati',

                      style: TextStyle(

                        fontSize: 15,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                    SizedBox(height: 4),

                    Text(

                      'Visualizza i quiz ricevuti dai docenti.',

                      style: TextStyle(

                        color: Colors.grey,

                        fontSize: 11,

                      ),

                    ),

                  ],

                ),

              ),

              Icon(

                Icons.arrow_forward_ios_rounded,

                size: 15,

              ),

            ],

          ),

        ),

      ),

    );

  }

}