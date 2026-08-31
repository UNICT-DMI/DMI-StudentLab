import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';

import '../social_models.dart';

class AcademicPathsPage extends StatefulWidget {
  final SocialUser? initialUser;
  final List<SocialAcademicPath>? initialPaths;

  const AcademicPathsPage({super.key, this.initialUser, this.initialPaths});

  @override
  State<AcademicPathsPage> createState() => _AcademicPathsPageState();
}

class _AcademicPathsPageState extends State<AcademicPathsPage> {
  final ApiService _apiService = ApiService();

  final AuthSession _authSession = AuthSession.instance;

  SocialUser? _currentUser;

  List<SocialAcademicPath> _paths = [];

  bool _loading = true;

  bool _processing = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    final SocialUser? initialUser = widget.initialUser;

    final List<SocialAcademicPath>? initialPaths = widget.initialPaths;

    if (initialUser != null && initialPaths != null) {
      _currentUser = initialUser.copyWith(academicPaths: initialPaths);

      _paths = List<SocialAcademicPath>.from(initialPaths);

      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      final SocialUser user = await _apiService.getCurrentUser();

      final List<SocialAcademicPath> paths = await _apiService
          .getUserAcademicPaths(user.id);

      if (!mounted) {
        return;
      }

      final SocialUser completeUser = user.copyWith(academicPaths: paths);

      setState(() {
        _currentUser = completeUser;

        _paths = paths;

        _loading = false;
      });

      _authSession.updateUser(completeUser);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;

        _error = _cleanError(e);
      });
    }
  }

  Future<void> _refreshUser() async {
    final SocialUser user = await _apiService.getCurrentUser();

    final List<SocialAcademicPath> paths = await _apiService
        .getUserAcademicPaths(user.id);

    if (!mounted) {
      return;
    }

    final SocialUser completeUser = user.copyWith(academicPaths: paths);

    setState(() {
      _currentUser = completeUser;

      _paths = paths;
    });

    _authSession.updateUser(completeUser);
  }

  Future<void> _addPath() async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AcademicPathEditorPage()),
    );

    if (changed == true && mounted) {
      await _refreshUser();
    }
  }

  Future<void> _editPath(SocialAcademicPath path) async {
    if (_processing) {
      return;
    }

    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AcademicPathEditorPage(path: path)),
    );

    if (changed == true && mounted) {
      await _refreshUser();
    }
  }

  Future<void> _setCurrent(SocialAcademicPath path) async {
    if (path.isCurrent || _processing) {
      return;
    }

    if (!path.isEnrolled) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _apiService.setCurrentAcademicPath(path.id);

      await _refreshUser();

      if (!mounted) {
        return;
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _setPrimary(SocialAcademicPath path) async {
    if (path.isPrimary || _processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _apiService.setPrimaryAcademicPath(path.id);

      await _refreshUser();

      if (!mounted) {
        return;
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _deletePath(SocialAcademicPath path) async {
    if (_processing) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,

          title: const Text(
            'Elimina percorso',

            style: TextStyle(color: AppColors.pureWhite),
          ),

          content: Text(
            'Vuoi eliminare il percorso "${path.course}"?',

            style: TextStyle(color: AppColors.pureWhite.withOpacity(0.70)),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Annulla'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text(
                'Elimina',

                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _apiService.removeAcademicPath(path.id);

      await _refreshUser();

      if (!mounted) {
        return;
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('401') || message.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (message.contains('403') || message.contains('forbidden')) {
      return 'Non hai i permessi necessari per modificare i percorsi accademici.';
    }

    if (message.contains('404') || message.contains('not found')) {
      return 'Il percorso accademico richiesto non è più disponibile. Aggiorna la pagina e riprova.';
    }

    if (message.contains('409') ||
        message.contains('conflict') ||
        message.contains('already')) {
      return 'Questa modifica è in conflitto con un percorso accademico già presente.';
    }

    if (message.contains('422') ||
        message.contains('validation') ||
        message.contains('invalid')) {
      return 'Alcuni dati del percorso accademico non sono validi. Controllali e riprova.';
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    if (message.contains('500') ||
        message.contains('502') ||
        message.contains('503')) {
      return 'StudentLab non è temporaneamente disponibile. Riprova tra qualche momento.';
    }

    return 'Non è stato possibile completare l’operazione sul percorso accademico. Riprova.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        title: const Text('Percorsi accademici'),

        actions: [
          IconButton(
            onPressed: _loading ? null : _load,

            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _processing ? null : _addPath,

              backgroundColor: AppColors.socialBlue,

              foregroundColor: AppColors.pureWhite,

              icon: const Icon(Icons.add_rounded),

              label: const Text('Aggiungi percorso'),
            ),

      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(
                Icons.error_outline_rounded,

                color: Colors.redAccent,

                size: 42,
              ),

              const SizedBox(height: 14),

              Text(
                _error!,

                textAlign: TextAlign.center,

                style: TextStyle(color: AppColors.pureWhite.withOpacity(0.70)),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _load,

                icon: const Icon(Icons.refresh_rounded),

                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth > 750
              ? 700
              : constraints.maxWidth;

          return SizedBox(
            width: width,

            child: RefreshIndicator(
              onRefresh: _load,

              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),

                children: [
                  const Text(
                    'I tuoi percorsi',

                    style: TextStyle(
                      color: AppColors.pureWhite,

                      fontSize: 23,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    'Puoi aggiungere più percorsi accademici, come laurea triennale, magistrale, ciclo unico, master o dottorato. Un percorso può essere principale e, se ancora frequentato, corrente.',

                    style: TextStyle(
                      color: AppColors.pureWhite.withOpacity(0.55),

                      fontSize: 13,

                      height: 1.4,
                    ),
                  ),

                  if (_currentUser != null) ...[
                    const SizedBox(height: 8),

                    Text(
                      _currentUser!.isTeacher
                          ? 'Questi percorsi descrivono la tua formazione. Gli insegnamenti che svolgi sono gestiti separatamente.'
                          : 'I percorsi descrivono la tua carriera universitaria e distinguono corso, tipo di percorso e stato.',

                      style: TextStyle(
                        color: AppColors.skyBlue.withOpacity(0.70),

                        fontSize: 11,

                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  if (_paths.isEmpty)
                    _EmptyPaths(onAdd: _addPath)
                  else
                    ..._paths.map((SocialAcademicPath path) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),

                        child: _AcademicPathCard(
                          path: path,

                          processing: _processing,

                          onEdit: () => _editPath(path),

                          onSetCurrent: () => _setCurrent(path),

                          onSetPrimary: () => _setPrimary(path),

                          onDelete: () => _deletePath(path),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AcademicPathCard extends StatelessWidget {
  final SocialAcademicPath path;

  final bool processing;

  final VoidCallback onEdit;

  final VoidCallback onSetCurrent;

  final VoidCallback onSetPrimary;

  final VoidCallback onDelete;

  const _AcademicPathCard({
    required this.path,
    required this.processing,
    required this.onEdit,
    required this.onSetCurrent,
    required this.onSetPrimary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: path.isPrimary
              ? AppColors.skyBlue.withOpacity(0.45)
              : AppColors.pureWhite.withOpacity(0.08),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 42,

                height: 42,

                decoration: BoxDecoration(
                  color: AppColors.socialBlue.withOpacity(0.13),

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Icon(
                  Icons.school_outlined,

                  color: AppColors.skyBlue,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      path.course,

                      style: const TextStyle(
                        color: AppColors.pureWhite,

                        fontSize: 16,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (path.degreeType.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),

                      Text(
                        academicPathTypeLabel(path.degreeType),

                        style: const TextStyle(
                          color: AppColors.skyBlue,

                          fontSize: 11,

                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              PopupMenuButton<String>(
                enabled: !processing,

                color: AppColors.eleganceDeepNavy,

                icon: const Icon(Icons.more_vert, color: AppColors.pureWhite),

                onSelected: (String value) {
                  switch (value) {
                    case 'edit':
                      onEdit();

                      break;

                    case 'current':
                      onSetCurrent();

                      break;

                    case 'primary':
                      onSetPrimary();

                      break;

                    case 'delete':
                      onDelete();

                      break;
                  }
                },

                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'edit',

                    child: _MenuItem(
                      icon: Icons.edit_outlined,

                      label: 'Modifica',
                    ),
                  ),

                  if (path.isEnrolled && !path.isCurrent)
                    const PopupMenuItem(
                      value: 'current',

                      child: _MenuItem(
                        icon: Icons.location_on_outlined,

                        label: 'Imposta corrente',
                      ),
                    ),

                  if (!path.isPrimary)
                    const PopupMenuItem(
                      value: 'primary',

                      child: _MenuItem(
                        icon: Icons.star_outline_rounded,

                        label: 'Imposta principale',
                      ),
                    ),

                  const PopupMenuItem(
                    value: 'delete',

                    child: _MenuItem(
                      icon: Icons.delete_outline,

                      label: 'Elimina',

                      danger: true,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          _InfoLine(
            icon: Icons.account_balance_outlined,

            value: path.university,
          ),

          const SizedBox(height: 7),

          _InfoLine(icon: Icons.business_outlined, value: path.department),

          const SizedBox(height: 14),

          Wrap(
            spacing: 7,

            runSpacing: 7,

            children: [
              _StatusBadge(path: path),

              if (path.isCurrent)
                const _Badge(
                  label: 'CORRENTE',

                  icon: Icons.location_on_rounded,

                  color: Colors.greenAccent,
                ),

              if (path.isPrimary)
                const _Badge(
                  label: 'PRINCIPALE',

                  icon: Icons.star_rounded,

                  color: Colors.amber,
                ),

              if (path.isGraduated && path.isVerified)
                const _Badge(
                  label: 'VERIFICATO',

                  icon: Icons.verified_rounded,

                  color: Colors.greenAccent,
                ),

              if (path.isVerificationPending)
                const _Badge(
                  label: 'VERIFICA IN ATTESA',

                  icon: Icons.schedule_rounded,

                  color: Colors.amber,
                ),

              if (path.isVerificationRejected)
                const _Badge(
                  label: 'VERIFICA RIFIUTATA',

                  icon: Icons.cancel_outlined,

                  color: Colors.redAccent,
                ),
            ],
          ),

          if (path.startYear != null || path.graduationYear != null) ...[
            const SizedBox(height: 12),

            Text(
              _yearsLabel(path),

              style: TextStyle(
                color: AppColors.pureWhite.withOpacity(0.45),

                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _yearsLabel(SocialAcademicPath path) {
    if (path.startYear != null && path.graduationYear != null) {
      return '${path.startYear} - ${path.graduationYear}';
    }

    if (path.startYear != null) {
      return 'Dal ${path.startYear}';
    }

    if (path.graduationYear != null) {
      return 'Conseguito ${path.graduationYear}';
    }

    return '';
  }
}

class AcademicPathEditorPage extends StatefulWidget {
  final SocialAcademicPath? path;

  const AcademicPathEditorPage({super.key, this.path});

  @override
  State<AcademicPathEditorPage> createState() => _AcademicPathEditorPageState();
}

class _AcademicPathEditorPageState extends State<AcademicPathEditorPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ApiService _apiService = ApiService();

  final TextEditingController _startYearController = TextEditingController();

  final TextEditingController _graduationYearController =
      TextEditingController();

  List<AcademicUniversity> _universities = [];

  List<AcademicDepartment> _departments = [];

  List<AcademicCourse> _courses = [];

  AcademicUniversity? _selectedUniversity;

  AcademicDepartment? _selectedDepartment;

  AcademicCourse? _selectedCourse;

  AcademicPathStatus _status = AcademicPathStatus.enrolled;

  bool _isCurrent = false;

  bool _isPrimary = false;

  bool _loading = true;

  bool _saving = false;

  String? _error;

  bool get _editing {
    return widget.path != null;
  }

  @override
  void initState() {
    super.initState();

    final SocialAcademicPath? path = widget.path;

    if (path != null) {
      _status = path.status;

      _isCurrent = path.isCurrent;

      _isPrimary = path.isPrimary;

      final AcademicUniversity currentUniversity = AcademicUniversity(
        code: path.universityCode,
        name: path.university,
      );

      final AcademicDepartment currentDepartment = AcademicDepartment(
        code: path.departmentCode,
        name: path.department,
      );

      final AcademicCourse currentCourse = AcademicCourse(
        code: path.courseCode,
        name: path.course,
        degreeType: path.degreeType,
      );

      _universities = [currentUniversity];

      _departments = [currentDepartment];

      _courses = [currentCourse];

      _selectedUniversity = currentUniversity;

      _selectedDepartment = currentDepartment;

      _selectedCourse = currentCourse;

      if (path.startYear != null) {
        _startYearController.text = path.startYear.toString();
      }

      if (path.graduationYear != null) {
        _graduationYearController.text = path.graduationYear.toString();
      }
    }

    _loadCatalog();
  }

  @override
  void dispose() {
    _startYearController.dispose();

    _graduationYearController.dispose();

    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      final List<AcademicUniversity> universities = await _apiService
          .getUniversities();

      if (!mounted) {
        return;
      }

      AcademicUniversity? selectedUniversity;

      final SocialAcademicPath? path = widget.path;

      if (path != null) {
        for (final AcademicUniversity university in universities) {
          if (university.code.trim().toLowerCase() ==
                  path.universityCode.trim().toLowerCase() ||
              university.name.trim().toLowerCase() ==
                  path.university.trim().toLowerCase()) {
            selectedUniversity = university;

            break;
          }
        }
      }

      selectedUniversity ??= _selectedUniversity;

      if (selectedUniversity == null && universities.isNotEmpty) {
        for (final AcademicUniversity university in universities) {
          if (university.code.toUpperCase() == 'UNICT') {
            selectedUniversity = university;

            break;
          }
        }

        selectedUniversity ??= universities.first;
      }

      setState(() {
        _universities = universities;

        _selectedUniversity = selectedUniversity;
      });

      if (selectedUniversity != null) {
        await _loadDepartments(
          selectedUniversity.code,

          initialDepartmentCode: path?.departmentCode,

          initialDepartmentName: path?.department,

          initialCourseCode: path?.courseCode,

          initialCourseName: path?.course,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = null;
      });
    }
  }

  Future<void> _loadDepartments(
    String universityCode, {
    String? initialDepartmentCode,
    String? initialDepartmentName,
    String? initialCourseCode,
    String? initialCourseName,
  }) async {
    final AcademicDepartment? previousDepartment = _selectedDepartment;

    final AcademicCourse? previousCourse = _selectedCourse;

    try {
      final List<AcademicDepartment> departments = await _apiService
          .getDepartments(universityCode);

      if (!mounted) {
        return;
      }

      AcademicDepartment? selectedDepartment;

      for (final AcademicDepartment department in departments) {
        final bool codeMatch =
            initialDepartmentCode != null &&
            department.code.trim().toLowerCase() ==
                initialDepartmentCode.trim().toLowerCase();

        final bool nameMatch =
            initialDepartmentName != null &&
            department.name.trim().toLowerCase() ==
                initialDepartmentName.trim().toLowerCase();

        if (codeMatch || nameMatch) {
          selectedDepartment = department;
          break;
        }
      }

      selectedDepartment ??= previousDepartment;

      selectedDepartment ??= departments.isEmpty ? null : departments.first;

      setState(() {
        _departments = departments;

        if (selectedDepartment != null &&
            !_departments.contains(selectedDepartment)) {
          _departments = [selectedDepartment, ..._departments];
        }

        _selectedDepartment = selectedDepartment;
      });

      if (selectedDepartment != null) {
        await _loadCourses(
          universityCode: universityCode,
          departmentCode: selectedDepartment.code,
          initialCourseCode: initialCourseCode,
          initialCourseName: initialCourseName,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDepartment = previousDepartment;
        _selectedCourse = previousCourse;

        if (previousDepartment != null) {
          _departments = [previousDepartment];
        }

        if (previousCourse != null) {
          _courses = [previousCourse];
        }
      });
    }
  }

  Future<void> _loadCourses({
    required String universityCode,
    required String departmentCode,
    String? initialCourseCode,
    String? initialCourseName,
  }) async {
    final AcademicCourse? previousCourse = _selectedCourse;

    try {
      final List<AcademicCourse> courses = await _apiService.getCourses(
        universityCode: universityCode,
        departmentCode: departmentCode,
      );

      if (!mounted) {
        return;
      }

      AcademicCourse? selectedCourse;

      for (final AcademicCourse course in courses) {
        final bool codeMatch =
            initialCourseCode != null &&
            course.code.trim().toLowerCase() ==
                initialCourseCode.trim().toLowerCase();

        final bool nameMatch =
            initialCourseName != null &&
            course.name.trim().toLowerCase() ==
                initialCourseName.trim().toLowerCase();

        if (codeMatch || nameMatch) {
          selectedCourse = course;
          break;
        }
      }

      selectedCourse ??= previousCourse;

      selectedCourse ??= courses.isEmpty ? null : courses.first;

      setState(() {
        _courses = courses;

        if (selectedCourse != null && !_courses.contains(selectedCourse)) {
          _courses = [selectedCourse, ..._courses];
        }

        _selectedCourse = selectedCourse;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedCourse = previousCourse;

        if (previousCourse != null) {
          _courses = [previousCourse];
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final AcademicUniversity? university = _selectedUniversity;

    final AcademicDepartment? department = _selectedDepartment;

    final AcademicCourse? course = _selectedCourse;

    if (university == null || department == null || course == null) {
      return;
    }

    if (_isCurrent && _status != AcademicPathStatus.enrolled) {
      return;
    }

    final int? startYear = _startYearController.text.trim().isEmpty
        ? null
        : int.tryParse(_startYearController.text.trim());

    final int? graduationYear = _status == AcademicPathStatus.graduated
        ? int.tryParse(_graduationYearController.text.trim())
        : null;

    setState(() {
      _saving = true;

      _error = null;
    });

    try {
      if (_editing) {
        final SocialAcademicPath path = widget.path!;

        await _apiService.updateAcademicPath(
          academicPathId: path.id,

          university: university.name,

          universityCode: university.code,

          department: department.name,

          departmentCode: department.code,

          course: course.name,

          courseCode: course.code,

          degreeType: course.degreeType,

          status: _status,

          startYear: startYear,

          clearStartYear: startYear == null,

          graduationYear: graduationYear,

          clearGraduationYear: graduationYear == null,

          isCurrent: _isCurrent,

          isPrimary: _isPrimary,
        );
      } else {
        await _apiService.createAcademicPath(
          university: university.name,

          universityCode: university.code,

          department: department.name,

          departmentCode: department.code,

          course: course.name,

          courseCode: course.code,

          degreeType: course.degreeType,

          status: _status,

          startYear: startYear,

          graduationYear: graduationYear,

          isCurrent: _isCurrent,

          isPrimary: _isPrimary,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _validateStartYear(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final int? year = int.tryParse(value.trim());

    if (year == null) {
      return 'Anno non valido';
    }

    final int currentYear = DateTime.now().year;

    if (year < 1900 || year > currentYear + 1) {
      return 'Anno non valido';
    }

    return null;
  }

  String? _validateGraduationYear(String? value) {
    if (_status != AcademicPathStatus.graduated) {
      return null;
    }

    if (value == null || value.trim().isEmpty) {
      return 'Inserisci l\'anno di conseguimento';
    }

    final int? year = int.tryParse(value.trim());

    if (year == null) {
      return 'Anno non valido';
    }

    final int currentYear = DateTime.now().year;

    if (year < 1900 || year > currentYear) {
      return 'Anno di conseguimento non valido';
    }

    final int? startYear = int.tryParse(_startYearController.text.trim());

    if (startYear != null && year < startYear) {
      return 'L\'anno di conseguimento non può precedere l\'anno di inizio';
    }

    return null;
  }

  String _cleanError(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('401') || message.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (message.contains('403') || message.contains('forbidden')) {
      return 'Non hai i permessi necessari per modificare i percorsi accademici.';
    }

    if (message.contains('404') || message.contains('not found')) {
      return 'Il percorso accademico richiesto non è più disponibile. Aggiorna la pagina e riprova.';
    }

    if (message.contains('409') ||
        message.contains('conflict') ||
        message.contains('already')) {
      return 'Questa modifica è in conflitto con un percorso accademico già presente.';
    }

    if (message.contains('422') ||
        message.contains('validation') ||
        message.contains('invalid')) {
      return 'Alcuni dati del percorso accademico non sono validi. Controllali e riprova.';
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    if (message.contains('500') ||
        message.contains('502') ||
        message.contains('503')) {
      return 'StudentLab non è temporaneamente disponibile. Riprova tra qualche momento.';
    }

    return 'Non è stato possibile completare l’operazione sul percorso accademico. Riprova.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        title: Text(_editing ? 'Modifica' : 'Aggiungi percorso'),
      ),

      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth > 700
              ? 650
              : constraints.maxWidth;

          return SizedBox(
            width: width,

            child: Form(
              key: _formKey,

              child: ListView(
                padding: const EdgeInsets.all(20),

                children: [
                  const Text(
                    'Percorso universitario',

                    style: TextStyle(
                      color: AppColors.pureWhite,

                      fontSize: 22,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    'Inserisci un percorso aggiuntivo oppure modifica quello selezionato.',

                    style: TextStyle(
                      color: AppColors.pureWhite.withOpacity(0.50),

                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 22),

                  DropdownButtonFormField<AcademicUniversity>(
                    value: _selectedUniversity,

                    isExpanded: true,

                    dropdownColor: AppColors.eleganceDeepNavy,

                    decoration: _decoration(
                      label: 'Ateneo',

                      icon: Icons.account_balance_outlined,
                    ),

                    validator: (AcademicUniversity? value) {
                      if (value == null) {
                        return 'Seleziona un ateneo';
                      }

                      return null;
                    },

                    items: _universities.map((AcademicUniversity university) {
                      return DropdownMenuItem(
                        value: university,

                        child: Text(
                          university.name,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(color: AppColors.pureWhite),
                        ),
                      );
                    }).toList(),

                    onChanged: _saving
                        ? null
                        : (AcademicUniversity? value) async {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _selectedUniversity = value;
                            });

                            await _loadDepartments(value.code);
                          },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<AcademicDepartment>(
                    value: _selectedDepartment,

                    isExpanded: true,

                    dropdownColor: AppColors.eleganceDeepNavy,

                    decoration: _decoration(
                      label: 'Dipartimento',

                      icon: Icons.business_outlined,
                    ),

                    validator: (AcademicDepartment? value) {
                      if (value == null) {
                        return 'Seleziona un dipartimento';
                      }

                      return null;
                    },

                    items: _departments.map((AcademicDepartment department) {
                      return DropdownMenuItem(
                        value: department,

                        child: Text(
                          department.name,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(color: AppColors.pureWhite),
                        ),
                      );
                    }).toList(),

                    onChanged: _saving
                        ? null
                        : (AcademicDepartment? value) async {
                            final AcademicUniversity? university =
                                _selectedUniversity;

                            if (value == null || university == null) {
                              return;
                            }

                            setState(() {
                              _selectedDepartment = value;
                            });

                            await _loadCourses(
                              universityCode: university.code,

                              departmentCode: value.code,
                            );
                          },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<AcademicCourse>(
                    value: _selectedCourse,

                    isExpanded: true,

                    dropdownColor: AppColors.eleganceDeepNavy,

                    decoration: _decoration(
                      label: 'Corso',

                      icon: Icons.school_outlined,
                    ),

                    validator: (AcademicCourse? value) {
                      if (value == null) {
                        return 'Seleziona un corso';
                      }

                      return null;
                    },

                    items: _courses.map((AcademicCourse course) {
                      return DropdownMenuItem(
                        value: course,

                        child: Text(
                          course.name,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(color: AppColors.pureWhite),
                        ),
                      );
                    }).toList(),

                    onChanged: _saving
                        ? null
                        : (AcademicCourse? value) {
                            setState(() {
                              _selectedCourse = value;
                            });
                          },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<AcademicPathStatus>(
                    value: _status,

                    dropdownColor: AppColors.eleganceDeepNavy,

                    decoration: _decoration(
                      label: 'Stato',

                      icon: Icons.workspace_premium_outlined,
                    ),

                    items: const [
                      DropdownMenuItem(
                        value: AcademicPathStatus.enrolled,

                        child: Text(
                          'Attualmente iscritto',

                          style: TextStyle(color: AppColors.pureWhite),
                        ),
                      ),

                      DropdownMenuItem(
                        value: AcademicPathStatus.graduated,

                        child: Text(
                          'Completato / titolo conseguito',

                          style: TextStyle(color: AppColors.pureWhite),
                        ),
                      ),

                      DropdownMenuItem(
                        value: AcademicPathStatus.suspended,

                        child: Text(
                          'Percorso sospeso',

                          style: TextStyle(color: AppColors.pureWhite),
                        ),
                      ),

                      DropdownMenuItem(
                        value: AcademicPathStatus.transferred,

                        child: Text(
                          'Trasferito',

                          style: TextStyle(color: AppColors.pureWhite),
                        ),
                      ),

                      DropdownMenuItem(
                        value: AcademicPathStatus.withdrawn,

                        child: Text(
                          'Percorso interrotto',

                          style: TextStyle(color: AppColors.pureWhite),
                        ),
                      ),
                    ],

                    onChanged: _saving
                        ? null
                        : (AcademicPathStatus? value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _status = value;

                              if (value != AcademicPathStatus.enrolled) {
                                _isCurrent = false;
                              }

                              if (value != AcademicPathStatus.graduated) {
                                _graduationYearController.clear();
                              }
                            });
                          },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _startYearController,

                    keyboardType: TextInputType.number,

                    enabled: !_saving,

                    style: const TextStyle(color: AppColors.pureWhite),

                    validator: _validateStartYear,

                    decoration: _decoration(
                      label: 'Anno di inizio',

                      icon: Icons.calendar_month_outlined,

                      hint: 'Es. 2022',
                    ),
                  ),

                  if (_status == AcademicPathStatus.graduated) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _graduationYearController,

                      keyboardType: TextInputType.number,

                      enabled: !_saving,

                      style: const TextStyle(color: AppColors.pureWhite),

                      validator: _validateGraduationYear,

                      decoration: _decoration(
                        label: 'Anno di conseguimento',

                        icon: Icons.workspace_premium_outlined,

                        hint: 'Es. 2026',
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  _OptionCard(
                    title: 'Percorso corrente',

                    subtitle: _status == AcademicPathStatus.enrolled
                        ? 'Indica che stai frequentando attualmente questo percorso.'
                        : 'Solo un percorso con stato "Attualmente iscritto" può essere corrente.',

                    value: _isCurrent,

                    enabled: !_saving && _status == AcademicPathStatus.enrolled,

                    onChanged: (bool value) {
                      setState(() {
                        _isCurrent = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  _OptionCard(
                    title: 'Percorso principale',

                    subtitle:
                        'È il percorso mostrato come riferimento principale nel tuo profilo.',

                    value: _isPrimary,

                    enabled: !_saving,

                    onChanged: (bool value) {
                      setState(() {
                        _isPrimary = value;
                      });
                    },
                  ),

                  if (_status == AcademicPathStatus.graduated) ...[
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(13),

                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.07),

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(
                          color: Colors.amber.withOpacity(0.18),
                        ),
                      ),

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Icon(
                            Icons.verified_outlined,

                            color: Colors.amber,

                            size: 18,
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              'I percorsi dichiarati come laureati vengono sottoposti a verifica.',

                              style: TextStyle(
                                color: AppColors.pureWhite.withOpacity(0.60),

                                fontSize: 11,

                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  SizedBox(
                    height: 54,

                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,

                      icon: _saving
                          ? const SizedBox(
                              width: 18,

                              height: 18,

                              child: CircularProgressIndicator(
                                strokeWidth: 2,

                                color: AppColors.pureWhite,
                              ),
                            )
                          : Icon(
                              _editing
                                  ? Icons.save_outlined
                                  : Icons.add_rounded,
                            ),

                      label: Text(
                        _saving
                            ? 'Salvataggio...'
                            : _editing
                            ? 'Salva modifiche'
                            : 'Aggiungi percorso',

                        style: const TextStyle(
                          fontSize: 15,

                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.socialBlue,

                        foregroundColor: AppColors.pureWhite,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,

      hintText: hint,

      labelStyle: TextStyle(color: AppColors.pureWhite.withOpacity(0.60)),

      hintStyle: TextStyle(color: AppColors.pureWhite.withOpacity(0.30)),

      prefixIcon: Icon(icon, color: AppColors.skyBlue),

      filled: true,

      fillColor: AppColors.eleganceDeepNavy,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),

        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),

        borderSide: const BorderSide(color: AppColors.socialBlue),
      ),
    );
  }
}

class _EmptyPaths extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyPaths({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          const Icon(Icons.school_outlined, color: AppColors.skyBlue, size: 42),

          const SizedBox(height: 12),

          const Text(
            'Nessun percorso',

            style: TextStyle(
              color: AppColors.pureWhite,

              fontSize: 16,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Aggiungi il tuo primo percorso accademico.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.50),

              fontSize: 12,
            ),
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: onAdd,

            icon: const Icon(Icons.add_rounded),

            label: const Text('Aggiungi percorso'),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;

  final String subtitle;

  final bool value;

  final bool enabled;

  final ValueChanged<bool> onChanged;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,

        borderRadius: BorderRadius.circular(15),
      ),

      child: SwitchListTile(
        value: value,

        onChanged: enabled ? onChanged : null,

        activeColor: AppColors.skyBlue,

        title: Text(
          title,

          style: TextStyle(
            color: enabled
                ? AppColors.pureWhite
                : AppColors.pureWhite.withOpacity(0.35),

            fontWeight: FontWeight.w600,
          ),
        ),

        subtitle: Text(
          subtitle,

          style: TextStyle(
            color: AppColors.pureWhite.withOpacity(enabled ? 0.45 : 0.25),

            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;

  final String value;

  const _InfoLine({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, color: AppColors.pureWhite.withOpacity(0.35), size: 15),

        const SizedBox(width: 7),

        Expanded(
          child: Text(
            value,

            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.60),

              fontSize: 11,

              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SocialAcademicPath path;

  const _StatusBadge({required this.path});

  @override
  Widget build(BuildContext context) {
    switch (path.status) {
      case AcademicPathStatus.enrolled:
        return const _Badge(
          label: 'ISCRITTO',

          icon: Icons.school_outlined,

          color: AppColors.skyBlue,
        );

      case AcademicPathStatus.graduated:
        return const _Badge(
          label: 'LAUREATO',

          icon: Icons.workspace_premium_outlined,

          color: AppColors.skyBlue,
        );

      case AcademicPathStatus.transferred:
        return const _Badge(
          label: 'TRASFERITO',

          icon: Icons.swap_horiz_rounded,

          color: AppColors.skyBlue,
        );

      case AcademicPathStatus.suspended:
        return const _Badge(
          label: 'SOSPESO',

          icon: Icons.pause_circle_outline_rounded,

          color: Colors.amber,
        );

      case AcademicPathStatus.withdrawn:
        return const _Badge(
          label: 'INTERROTTO',

          icon: Icons.remove_circle_outline,

          color: Colors.orangeAccent,
        );
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;

  final IconData icon;

  final Color color;

  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),

      decoration: BoxDecoration(
        color: color.withOpacity(0.09),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: color.withOpacity(0.16)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, color: color, size: 11),

          const SizedBox(width: 4),

          Text(
            label,

            style: TextStyle(
              color: color,

              fontSize: 8,

              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;

  final String label;

  final bool danger;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? Colors.redAccent : AppColors.pureWhite;

    return Row(
      children: [
        Icon(icon, color: color, size: 18),

        const SizedBox(width: 9),

        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
