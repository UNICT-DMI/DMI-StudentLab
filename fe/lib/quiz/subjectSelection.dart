import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';

import '../services/auth_session.dart';

import '../social/social_models.dart';

import 'assigned_quizzes_page.dart';

import 'quiz.dart';

import 'services/free_quiz_api_service.dart';
import 'student_question_proposal_page.dart';
import 'package:fe/quiz/exercises/exercise_catalog_page.dart';

/// Scheda "Esercizi" nella pagina Esercitazione: accesa dalla v24 (tipi generici per ogni corso).
/// Per spegnerla di nuovo basta rimettere false.
const bool kExerciseCatalogEnabled = true;

/// Pagina "Esercitazione" (v23): prima il percorso, poi cosa fare.
///
/// 1. **Percorso**: con l'account si parte dai percorsi del profilo (un tocco);
///    da ospite dall'ultima scelta fatta su questo telefono. "Cambia" riapre
///    ateneo, dipartimento e corso.
/// 2. **Materia**, poi **cosa vuoi fare**: quiz, esercizi (quando attivi),
///    quiz assegnati, proposta di una domanda. Sotto resta la configurazione
///    del quiz di sempre (argomenti e numero di domande).
class SubjectSelection extends StatefulWidget {
  const SubjectSelection({super.key});

  @override
  State<SubjectSelection> createState() => _SubjectSelectionState();
}

class _SubjectSelectionState extends State<SubjectSelection> {
  final ApiService _apiService = ApiService();

  final FreeQuizApiService _quizApiService = FreeQuizApiService();

  final AuthSession _authSession = AuthSession.instance;

  final TextEditingController _questionController = TextEditingController(
    text: '10',
  );

  List<AcademicUniversity> _universities = [];

  List<AcademicDepartment> _departments = [];

  List<AcademicCourse> _courses = [];

  List<String> _subjects = [];

  List<Map<String, String>> _availablePaths = [];

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

  /// Ultimo percorso scelto su questo telefono (solo codici e nome della materia).
  static const String _lastPathKey = 'studentlab_exercise_last_path_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// true = mostra ateneo/dipartimento/corso anche se un percorso è già scelto.
  bool _editingPath = false;

  /// Un percorso del profilo o l'ultimo salvato si sta applicando.
  bool _applyingPath = false;

  final GlobalKey _quizSectionKey = GlobalKey();

  bool get _isAuthenticated => _authSession.isAuthenticated;

  bool get _canSelectDepartment =>
      _selectedUniversity != null && !_loadingDepartments;

  bool get _canSelectCourse => _selectedDepartment != null && !_loadingCourses;

  bool get _canSelectSubject => _selectedCourse != null && !_loadingSubjects;

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

    // Sessione ripristinata dopo il caricamento degli atenei: si propone il percorso del profilo.
    if (_selectedUniversity == null && _universities.isNotEmpty) {
      unawaited(_restoreInitialPath());
    }
  }

  Future<void> _loadUniversities() async {
    setState(() {
      _loadingUniversities = true;
    });

    try {
      final paths = await _quizApiService.getAvailablePaths();
      final List<AcademicUniversity> values = await _apiService
          .getUniversities();

      if (!mounted) {
        return;
      }

      setState(() {
        _universities = values;
        _availablePaths = paths;

        _loadingUniversities = false;
      });

      if (paths.isEmpty) {
        _showMessage('Non ci sono ancora quiz nella banca delle domande.');
      }

      unawaited(_restoreInitialPath());
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _universities = [];
        _availablePaths = [];

        _loadingUniversities = false;
      });

      _showMessage('Non è stato possibile caricare gli atenei disponibili.');
    }
  }

  Future<void> _onUniversityChanged(AcademicUniversity? university) async {
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
      final List<AcademicDepartment> values = await _apiService.getDepartments(
        university.code,
      );

      if (!mounted || _selectedUniversity?.code != university.code) {
        return;
      }

      setState(() {
        _departments = values.where((d) => _availablePaths.any((path) =>
            path['department'] == d.code.trim().toUpperCase())).toList();

        _loadingDepartments = false;
      });
      if (_departments.isEmpty) _showMessage('Nessun quiz disponibile per questo ateneo.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _departments = [];

        _loadingDepartments = false;
      });

      _showMessage('Non è stato possibile caricare i dipartimenti.');
    }
  }

  Future<void> _onDepartmentChanged(AcademicDepartment? department) async {
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
        _courses = values.where((c) => _availablePaths.any((path) =>
            path['department'] == department.code.trim().toUpperCase() &&
            path['course'] == c.code.trim().toUpperCase())).toList();

        _loadingCourses = false;
      });
      if (_courses.isEmpty) _showMessage('Nessun corso con quiz disponibili in questo dipartimento.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _courses = [];

        _loadingCourses = false;
      });

      _showMessage('Non è stato possibile caricare i corsi.');
    }
  }

  Future<void> _onCourseChanged(AcademicCourse? course) async {
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

      final List<String> availableSubjects =
          values
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
        _showMessage('Non ci sono ancora quiz disponibili per questo corso.');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = [];
        _loadingSubjects = false;
      });

      _showMessage('Non è stato possibile caricare le materie.');
    }
  }

  Future<void> _onSubjectChanged(String? subject) async {
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

      unawaited(_saveLastPath());
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

  // ------------------------------------------------------------------ percorso

  /// Percorsi del profilo con i codici del catalogo (principale e attuali prima).
  List<SocialAcademicPath> get _profilePaths {
    if (!_isAuthenticated) return const <SocialAcademicPath>[];
    final List<SocialAcademicPath> paths = (_authSession.currentUser?.academicPaths ?? const <SocialAcademicPath>[])
        .where((SocialAcademicPath p) =>
            p.universityCode.trim().isNotEmpty &&
            p.departmentCode.trim().isNotEmpty &&
            p.courseCode.trim().isNotEmpty)
        .toList();
    int rank(SocialAcademicPath p) => (p.isPrimary ? 0 : 2) + (p.isCurrent || p.isEnrolled ? 0 : 1);
    paths.sort((SocialAcademicPath a, SocialAcademicPath b) => rank(a).compareTo(rank(b)));
    return paths;
  }

  bool _isSelectedPath(SocialAcademicPath path) =>
      _selectedUniversity?.code == path.universityCode &&
      _selectedDepartment?.code == path.departmentCode &&
      (_selectedCourse?.code == path.courseCode ||
          (_selectedCourse?.name == 'Informatica (L-31)' &&
              _sameL31Course(path.courseCode, path.course)));

  bool _sameL31Course(String code, String name) {
    final String normalizedName = name.trim().toLowerCase();
    return _selectedDepartment?.code.toUpperCase() == 'DMI' &&
        (code.trim().toUpperCase() == 'L-31' ||
            normalizedName == 'informatica' ||
            normalizedName == 'scienze e tecnologie informatiche' ||
            normalizedName == 'informatica l-31' ||
            normalizedName == 'l-31 informatica');
  }

  /// Primo percorso: quello principale del profilo, altrimenti l'ultimo usato qui.
  Future<void> _restoreInitialPath() async {
    if (!mounted || _selectedUniversity != null || _applyingPath) return;
    final Map<String, dynamic>? last = await _readLastPath();
    // Durante la lettura l'utente può aver già scelto a mano: la sua scelta vince.
    if (!mounted || _selectedUniversity != null || _applyingPath) return;
    final List<SocialAcademicPath> profile = _profilePaths;
    if (profile.isNotEmpty) {
      // Tra i percorsi del profilo, quello usato l'ultima volta; altrimenti il principale.
      final SocialAcademicPath path = profile.firstWhere(
        (SocialAcademicPath p) => p.courseCode == last?['course']?.toString(),
        orElse: () => profile.first,
      );
      await _applyPath(
        universityCode: path.universityCode,
        departmentCode: path.departmentCode,
        courseCode: path.courseCode,
        courseName: path.course,
        subject: last != null && last['course']?.toString() == path.courseCode ? last['subject']?.toString() : null,
      );
      return;
    }
    if (last == null) return;
    await _applyPath(
      universityCode: last['university']?.toString() ?? '',
      departmentCode: last['department']?.toString() ?? '',
      courseCode: last['course']?.toString() ?? '',
      subject: last['subject']?.toString(),
    );
  }

  Future<Map<String, dynamic>?> _readLastPath() async {
    try {
      final String? raw = await _storage.read(key: _lastPathKey);
      if (raw == null || raw.isEmpty) return null;
      final dynamic value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastPath() async {
    final AcademicUniversity? university = _selectedUniversity;
    final AcademicDepartment? department = _selectedDepartment;
    final AcademicCourse? course = _selectedCourse;
    if (university == null || department == null || course == null) return;
    try {
      await _storage.write(
        key: _lastPathKey,
        value: jsonEncode(<String, String>{
          'university': university.code,
          'department': department.code,
          'course': course.code,
          if (_selectedSubject != null) 'subject': _selectedSubject!,
        }),
      );
    } catch (_) {
      // Ricordare la scelta è una comodità: se il telefono non lo permette si va avanti.
    }
  }

  /// Applica un percorso completo usando gli stessi passaggi dei menu a tendina.
  Future<void> _applyPath({
    required String universityCode,
    required String departmentCode,
    required String courseCode,
    String? courseName,
    String? subject,
  }) async {
    if (!mounted || _applyingPath) return;
    setState(() {
      _applyingPath = true;
      _editingPath = false;
    });
    try {
      final AcademicUniversity? university =
          _universities.where((AcademicUniversity u) => u.code == universityCode).firstOrNull;
      if (university == null) return;
      await _onUniversityChanged(university);
      if (!mounted) return;
      final AcademicDepartment? department =
          _departments.where((AcademicDepartment d) => d.code == departmentCode).firstOrNull;
      if (department == null) return;
      await _onDepartmentChanged(department);
      if (!mounted) return;
      final AcademicCourse? course = _courses.where((AcademicCourse c) => c.code == courseCode).firstOrNull ??
          (_sameL31Course(courseCode, courseName ?? courseCode)
              ? _courses.where((AcademicCourse c) => c.name == 'Informatica (L-31)').firstOrNull
              : null);
      if (course == null) return;
      await _onCourseChanged(course);
      if (!mounted) return;
      if (subject != null && _subjects.contains(subject)) {
        await _onSubjectChanged(subject);
      }
    } finally {
      if (mounted) setState(() => _applyingPath = false);
    }
  }

  void _scrollToQuiz() {
    final BuildContext? target = _quizSectionKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.05);
    }
  }

  Future<void> _selectArguments() async {
    if (!_canSelectArguments) {
      return;
    }

    final List<String> temporary = List<String>.from(_selectedArguments);

    final List<String>? result = await showModalBottomSheet<List<String>>(
      context: context,

      isScrollControlled: true,

      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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

                        itemBuilder: (BuildContext context, int index) {
                          final String argument = _availableArguments[index];

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

        _questionController.text = _selectedQuiz == 0
            ? ''
            : _selectedQuiz.toString();

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

      _showMessage('Non è stato possibile calcolare le domande disponibili.');
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

    final int value = (_selectedQuiz + delta).clamp(1, _availableQuestions);

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

  Future<void> _openQuestionProposal() async {
    if (!_isAuthenticated) {
      _showMessage('Accedi per proporre una domanda.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const StudentQuestionProposalPage(),
      ),
    );
  }

  Future<void> _openAssignedQuizzes() async {
    if (!_isAuthenticated) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AssignedQuizzesPage()),
    );
  }

  void _startQuiz() {
    final AcademicDepartment? department = _selectedDepartment;

    final AcademicCourse? course = _selectedCourse;

    final String? subject = _selectedSubject;

    if (!_canStart || department == null || course == null || subject == null) {
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

  /// v18: esercizi dei nuovi tipi e flashcard della materia scelta.
  void _openExercises() {
    final AcademicDepartment? department = _selectedDepartment;
    final AcademicCourse? course = _selectedCourse;
    final String? subject = _selectedSubject;
    if (department == null || course == null || subject == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseCatalogPage(
          department: department.code,
          course: course.code,
          subject: subject,
          subjectLabel: _subjectLabel(subject),
          initialArguments: List<String>.from(_selectedArguments),
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Esercitazione')),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),

            child: ListView(
              padding: const EdgeInsets.all(20),

              children: [
                const Text(
                  'Scegli il percorso e la materia, poi cosa vuoi fare.',

                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),

                const SizedBox(height: 20),

                if (_applyingPath) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],

                if (_selectedCourse != null && !_editingPath)
                  _PathSummaryCard(
                    university: _selectedUniversity?.name ?? '',
                    department: _selectedDepartment?.name ?? '',
                    course: _selectedCourse?.name ?? '',
                    onChange: _applyingPath ? null : () => setState(() => _editingPath = true),
                  )
                else ...[
                  Row(
                    children: [
                      const Expanded(child: _StepTitle(number: 1, title: 'Il tuo percorso')),
                      if (_editingPath && _selectedCourse != null)
                        TextButton(
                          onPressed: () => setState(() => _editingPath = false),
                          child: const Text('Annulla'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (_profilePaths.isNotEmpty) ...[
                    for (final SocialAcademicPath path in _profilePaths)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProfilePathTile(
                          path: path,
                          selected: _isSelectedPath(path),
                          onTap: _applyingPath
                              ? null
                              : _isSelectedPath(path)
                              ? () => setState(() => _editingPath = false)
                              : () => _applyPath(
                                    universityCode: path.universityCode,
                                    departmentCode: path.departmentCode,
                                    courseCode: path.courseCode,
                                    courseName: path.course,
                                  ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    const Text(
                      'Oppure scegli un altro ateneo o corso:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                  ],

                  _CatalogDropdown<AcademicUniversity>(
                    label: 'Ateneo',

                    value: _selectedUniversity,

                    items: _universities,

                    itemLabel: (AcademicUniversity value) => value.name,

                    loading: _loadingUniversities,

                    enabled: !_loadingUniversities && !_applyingPath,

                    onChanged: _onUniversityChanged,
                  ),

                  const SizedBox(height: 16),

                  _CatalogDropdown<AcademicDepartment>(
                    label: 'Dipartimento',

                    value: _selectedDepartment,

                    items: _departments,

                    itemLabel: (AcademicDepartment value) => value.name,

                    loading: _loadingDepartments,

                    enabled: _canSelectDepartment && !_applyingPath,

                    onChanged: _onDepartmentChanged,
                  ),

                  const SizedBox(height: 16),

                  _CatalogDropdown<AcademicCourse>(
                    label: 'Corso',

                    value: _selectedCourse,

                    items: _courses,

                    itemLabel: (AcademicCourse value) => value.name,

                    loading: _loadingCourses,

                    enabled: _canSelectCourse && !_applyingPath,

                    onChanged: (AcademicCourse? course) async {
                      await _onCourseChanged(course);
                      if (mounted && _selectedCourse != null) {
                        setState(() => _editingPath = false);
                      }
                    },
                  ),
                ],

                const SizedBox(height: 20),

                const _StepTitle(number: 2, title: 'Materia'),

                const SizedBox(height: 10),

                _CatalogDropdown<String>(
                  label: 'Materia',

                  value: _selectedSubject,

                  items: _subjects,

                  itemLabel: (String value) => _subjectLabel(value),

                  loading: _loadingSubjects,

                  enabled: _canSelectSubject,

                  onChanged: _onSubjectChanged,
                ),

                const SizedBox(height: 20),

                const _StepTitle(number: 3, title: 'Cosa vuoi fare?'),

                const SizedBox(height: 10),

                _HubGrid(
                  children: [
                    _HubCard(
                      icon: Icons.quiz_outlined,
                      title: 'Quiz',
                      description: 'Domande a risposta multipla sugli argomenti che scegli.',
                      onTap: _selectedSubject == null ? null : _scrollToQuiz,
                    ),
                    if (kExerciseCatalogEnabled)
                      _HubCard(
                        icon: Icons.extension_outlined,
                        title: 'Esercizi',
                        description: 'Ordina, abbina, casi pratici e quiz su misura.',
                        onTap: _selectedSubject == null ? null : _openExercises,
                      ),
                    if (_isAuthenticated)
                      _HubCard(
                        icon: Icons.assignment_outlined,
                        title: 'Quiz assegnati',
                        description: 'Ricevuti dai docenti o da StudentLab.',
                        onTap: _openAssignedQuizzes,
                      ),
                    if (_isAuthenticated)
                      _HubCard(
                        icon: Icons.add_comment_outlined,
                        title: 'Proponi una domanda',
                        description: 'Form guidato o JSON, con revisione.',
                        onTap: _openQuestionProposal,
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  'Configura il quiz',
                  key: _quizSectionKey,

                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

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
                        color: _selectedArguments.isEmpty ? Colors.grey : null,
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

                    style: TextStyle(fontWeight: FontWeight.w600),
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

                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                      'Avvia quiz',

                      style: TextStyle(
                        fontSize: 16,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

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

                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),

      hint: Text(loading ? 'Caricamento...' : 'Seleziona $label'),

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
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.35),

        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        children: [
          const Icon(Icons.quiz_outlined),

          const SizedBox(width: 12),

          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  final int number;
  final String title;

  const _StepTitle({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PathSummaryCard extends StatelessWidget {
  final String university;
  final String department;
  final String course;
  final VoidCallback? onChange;

  const _PathSummaryCard({
    required this.university,
    required this.department,
    required this.course,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withOpacity(0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.school_outlined, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  <String>[university, department].where((String v) => v.trim().isNotEmpty).join(' › '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 11.5),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Cambia')),
        ],
      ),
    );
  }
}

class _ProfilePathTile extends StatelessWidget {
  final SocialAcademicPath path;
  final bool selected;
  final VoidCallback? onTap;

  const _ProfilePathTile({required this.path, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer.withOpacity(0.35) : colors.surfaceContainerHighest.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? colors.primary.withOpacity(0.55) : colors.outline.withOpacity(0.20)),
          ),
          child: Row(
            children: [
              Icon(Icons.school_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(path.course, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        path.university,
                        path.department,
                        if (path.isPrimary) 'principale',
                      ].where((String v) => v.trim().isNotEmpty).join(' › '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Griglia a due colonne (una su schermi molto stretti).
class _HubGrid extends StatelessWidget {
  final List<Widget> children;

  const _HubGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final int columns = box.maxWidth >= 340 ? 2 : 1;
        final double width = ((box.maxWidth - (columns - 1) * 10) / columns).floorToDouble();
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final Widget child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const _HubCard({required this.icon, required this.title, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.secondary.withOpacity(0.18)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 104),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 26, color: colors.primary),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 11.5, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
