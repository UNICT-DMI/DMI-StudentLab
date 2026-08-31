import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../../services/api_service.dart';

import '../social_models.dart';

import 'social_profile_preview.dart';

const List<String> _academicTitleTypes = [
  'Laurea triennale',
  'Laurea magistrale',
  'Laurea magistrale a ciclo unico',
  'Master di I livello',
  'Master di II livello',
  'Dottorato di ricerca',
  'Scuola di specializzazione',
  'Altro percorso universitario',
];

String _titleTypeFromDegreeType(
  String degreeType,
) {
  final String value =
      degreeType
          .trim()
          .toUpperCase();

  if (
    value.startsWith('LMG') ||
    value.contains('CICLO UNICO')
  ) {
    return 'Laurea magistrale a ciclo unico';
  }

  if (
    value.startsWith('LM-') ||
    RegExp(r'^LM\d').hasMatch(
      value,
    )
  ) {
    return 'Laurea magistrale';
  }

  if (
    value.startsWith('L-') ||
    RegExp(r'^L\d').hasMatch(
      value,
    )
  ) {
    return 'Laurea triennale';
  }

  if (value.contains('DOTT')) {
    return 'Dottorato di ricerca';
  }

  if (
    value.contains('MASTER') &&
    (
      value.contains('II') ||
      value.contains('2')
    )
  ) {
    return 'Master di II livello';
  }

  if (value.contains('MASTER')) {
    return 'Master di I livello';
  }

  if (
    value.contains('SPECIAL') ||
    value.contains('SCUOLA')
  ) {
    return 'Scuola di specializzazione';
  }

  return 'Laurea triennale';
}

class StudentSocialForm extends StatefulWidget {
  const StudentSocialForm({
    super.key,
  });

  @override
  State<StudentSocialForm> createState() =>
      _StudentSocialFormState();
}

class _StudentSocialFormState
    extends State<StudentSocialForm> {

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final ApiService _apiService =
      ApiService();

  final TextEditingController
      _firstNameController =
      TextEditingController();

  final TextEditingController
      _lastNameController =
      TextEditingController();

  final TextEditingController
      _emailController =
      TextEditingController();

  final TextEditingController
      _passwordController =
      TextEditingController();

  final TextEditingController
      _confirmPasswordController =
      TextEditingController();

  final TextEditingController
      _dateOfBirthController =
      TextEditingController();

  final TextEditingController
      _descriptionController =
      TextEditingController();

  final TextEditingController
      _startYearController =
      TextEditingController();

  final TextEditingController
      _graduationYearController =
      TextEditingController();

  final TextEditingController
      _manualUniversityController =
      TextEditingController();

  final TextEditingController
      _manualDepartmentController =
      TextEditingController();

  final TextEditingController
      _manualCourseController =
      TextEditingController();

  final TextEditingController
      _manualTitleController =
      TextEditingController();

  DateTime? _selectedDateOfBirth;

  bool _available =
      false;

  bool _availableForHelp =
      false;

  bool _availableForPrivateLessons =
      false;

  bool _loadingAcademicData =
      false;

  bool _loadingSubjects =
      false;

  bool _passwordVisible =
      false;

  bool _confirmPasswordVisible =
      false;

  String? _academicError;

  String? _subjectsError;

  String? _passwordError;

  String? _titlesError;

  List<AcademicUniversity>
      _universities =
      [];

  List<AcademicDepartment>
      _departments =
      [];

  List<AcademicCourse>
      _courses =
      [];

  List<SocialSubject>
      _availableSubjects =
      [];

  List<AcademicDepartment>
      _subjectDepartments =
      [];

  List<AcademicCourse>
      _subjectCourses =
      [];

  AcademicUniversity?
      _subjectUniversity;

  AcademicDepartment?
      _subjectDepartment;

  AcademicCourse?
      _subjectCourse;

  bool _loadingSubjectCatalog =
      false;

  AcademicUniversity?
      _selectedUniversity;

  AcademicDepartment?
      _selectedDepartment;

  AcademicCourse?
      _selectedCourse;

  AcademicPathStatus
      _academicStatus =
      AcademicPathStatus.enrolled;

  String _academicTitleType =
      'Laurea triennale';

  bool _manualUniversity =
      false;

  bool _manualDepartment =
      false;

  bool _manualCourse =
      false;

  bool _manualTitle =
      false;

  bool _showAcademicPathEditor =
      false;

  bool _primaryAcademicPathEnabled =
      false;

  int? _editingAcademicPathIndex;

  final List<SocialAcademicPathDraft>
      _additionalAcademicPaths =
      [];

  final List<SocialAcademicPathDraft>
      _academicTitles =
      [];

  bool _showAcademicTitleEditor =
      false;

  int? _editingAcademicTitleIndex;

  final List<_StudentSubjectData>
      _subjects = [];

  bool get _hasSelectedSubjects =>
      _subjects.any((item) => item.selectedSubject != null);

  @override
  void initState() {
    super.initState();

    _loadAcademicCatalog();
  }

  @override
  void dispose() {
    _firstNameController.dispose();

    _lastNameController.dispose();

    _emailController.dispose();

    _passwordController.dispose();

    _confirmPasswordController.dispose();

    _dateOfBirthController.dispose();

    _descriptionController.dispose();

    _startYearController.dispose();

    _graduationYearController
        .dispose();

    _manualUniversityController.dispose();

    _manualDepartmentController.dispose();

    _manualCourseController.dispose();

    _manualTitleController.dispose();

    for (
      final _StudentSubjectData subject
      in _subjects
    ) {
      subject.dispose();
    }

    super.dispose();
  }

  Future<void> _loadAcademicCatalog() async {
    setState(() {
      _loadingAcademicData =
          true;

      _academicError =
          null;
    });

    try {
      final List<AcademicUniversity>
          universities =
          await _apiService
              .getUniversities();

      if (!mounted) {
        return;
      }

      if (universities.isEmpty) {
        setState(() {
          _universities =
              [];

          _selectedUniversity =
              null;

          _manualUniversity =
              true;

          _manualDepartment =
              true;

          _manualCourse =
              true;

          _loadingAcademicData =
              false;

          _academicError =
              'Il catalogo degli atenei non contiene voci disponibili. Puoi continuare inserendo i dati manualmente.';
        });

        return;
      }

      AcademicUniversity?
          selectedUniversity;

      for (
        final AcademicUniversity university
        in universities
      ) {
        if (
          university.code
                  .toUpperCase() ==
              'UNICT'
        ) {
          selectedUniversity =
              university;

          break;
        }
      }

      selectedUniversity ??=
          universities.first;

      setState(() {
        _universities =
            universities;

        _selectedUniversity =
            selectedUniversity;

        _subjectUniversity =
            selectedUniversity;

        _manualUniversity =
            false;

        _manualDepartment =
            false;

        _manualCourse =
            false;

        _manualUniversityController.text =
            selectedUniversity!.name;
      });

      await _loadDepartments(
        selectedUniversity.code,
        selectDefault:
            true,
      );

      await _loadSubjectDepartments(
        selectedUniversity.code,
        selectDefault:
            true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingAcademicData =
            false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _universities =
            [];

        _departments =
            [];

        _courses =
            [];

        _selectedUniversity =
            null;

        _selectedDepartment =
            null;

        _selectedCourse =
            null;

        _manualUniversity =
            true;

        _manualDepartment =
            true;

        _manualCourse =
            true;

        _loadingAcademicData =
            false;

        _academicError =
            'Il catalogo accademico non è disponibile. Puoi continuare inserendo ateneo, dipartimento, corso e titolo manualmente.';
      });
    }
  }

  Future<void> _loadDepartments(
    String universityCode, {
    bool selectDefault = false,
  }) async {
    setState(() {
      _departments =
          [];

      _courses =
          [];

      _availableSubjects =
          [];

      _selectedDepartment =
          null;

      _selectedCourse =
          null;

      _subjectsError =
          null;

      for (
        final _StudentSubjectData item
        in _subjects
      ) {
        item.selectedSubject =
            null;
      }
    });

    if (_manualUniversity) {
      return;
    }

    try {
      final List<AcademicDepartment>
          departments =
          await _apiService
              .getDepartments(
        universityCode,
      );

      if (!mounted) {
        return;
      }

      if (departments.isEmpty) {
        setState(() {
          _manualDepartment =
              true;

          _manualCourse =
              true;

          _academicError =
              'Il catalogo non contiene dipartimenti disponibili per questo ateneo. Puoi continuare manualmente.';
        });

        return;
      }

      AcademicDepartment?
          selectedDepartment;

      if (selectDefault) {
        for (
          final AcademicDepartment department
          in departments
        ) {
          if (
            department.code
                    .toUpperCase() ==
                'DMI'
          ) {
            selectedDepartment =
                department;

            break;
          }
        }
      }

      selectedDepartment ??=
          departments.first;

      setState(() {
        _departments =
            departments;

        _selectedDepartment =
            selectedDepartment;

        _manualDepartment =
            false;

        _manualCourse =
            false;

        _manualDepartmentController.text =
            selectedDepartment!.name;
      });

      await _loadCourses(
        universityCode:
            universityCode,

        departmentCode:
            selectedDepartment.code,

        selectDefault:
            true,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _departments =
            [];

        _courses =
            [];

        _selectedDepartment =
            null;

        _selectedCourse =
            null;

        _manualDepartment =
            true;

        _manualCourse =
            true;

        _academicError =
            'Il catalogo dei dipartimenti non è disponibile. Puoi continuare manualmente.';
      });
    }
  }

  Future<void> _loadCourses({
    required String universityCode,
    required String departmentCode,
    bool selectDefault = false,
  }) async {
    setState(() {
      _courses =
          [];

      _availableSubjects =
          [];

      _selectedCourse =
          null;

      _subjectsError =
          null;

      for (
        final _StudentSubjectData item
        in _subjects
      ) {
        item.selectedSubject =
            null;
      }
    });

    if (
      _manualUniversity ||
      _manualDepartment
    ) {
      return;
    }

    try {
      final List<AcademicCourse>
          courses =
          await _apiService.getCourses(
        universityCode:
            universityCode,
        departmentCode:
            departmentCode,
      );

      if (!mounted) {
        return;
      }

      AcademicCourse?
          selectedCourse;

      if (
        selectDefault &&
        courses.isNotEmpty
      ) {
        for (
          final AcademicCourse course
          in courses
        ) {
          if (
            course.name
                .toLowerCase()
                .contains(
                  'informatica',
                )
          ) {
            selectedCourse =
                course;

            break;
          }
        }

        selectedCourse ??=
            courses.first;
      } else if (courses.isNotEmpty) {
        selectedCourse =
            courses.first;
      }

      if (courses.isEmpty) {
        setState(() {
          _manualCourse =
              true;

          _subjectsError =
              'Il catalogo dei corsi non contiene voci disponibili. Puoi continuare inserendo il corso manualmente.';
        });

        return;
      }

      setState(() {
        _courses =
            courses;

        _selectedCourse =
            selectedCourse;

        _manualCourse =
            selectedCourse == null;

        if (selectedCourse != null) {
          _manualCourseController.text =
              selectedCourse.name;

          _academicTitleType =
              selectedCourse.degreeType.trim();
        }
      });

      if (selectedCourse !=
          null) {
        await _loadSubjects();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _manualCourse =
            true;

        _courses =
            [];

        _selectedCourse =
            null;

        _availableSubjects =
            [];

        _subjectsError =
            'Il catalogo dei corsi non è disponibile. Puoi continuare inserendo il corso manualmente.';
      });
    }
  }

  Future<void> _loadSubjectDepartments(
    String universityCode, {
    bool selectDefault = false,
  }) async {
    setState(() {
      _loadingSubjectCatalog =
          true;

      _subjectDepartments =
          [];

      _subjectCourses =
          [];

      _subjectDepartment =
          null;

      _subjectCourse =
          null;

      _availableSubjects =
          [];

      _subjectsError =
          null;

      _resetSubjectSelections();
    });

    try {
      final List<AcademicDepartment>
          departments =
          await _apiService
              .getDepartments(
        universityCode,
      );

      if (!mounted) {
        return;
      }

      if (departments.isEmpty) {
        setState(() {
          _loadingSubjectCatalog =
              false;

          _subjectsError =
              'Nessun dipartimento disponibile per l’ateneo selezionato.';
        });
        return;
      }

      AcademicDepartment?
          selectedDepartment;

      if (selectDefault) {
        for (
          final AcademicDepartment department
          in departments
        ) {
          if (
            department.code
                    .toUpperCase() ==
                'DMI'
          ) {
            selectedDepartment =
                department;
            break;
          }
        }
      }

      selectedDepartment ??=
          departments.first;

      setState(() {
        _subjectDepartments =
            departments;

        _subjectDepartment =
            selectedDepartment;
      });

      await _loadSubjectCourses(
        universityCode:
            universityCode,
        departmentCode:
            selectedDepartment.code,
        selectDefault:
            true,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSubjectCatalog =
            false;

        _subjectsError =
            'Non è stato possibile caricare i dipartimenti per gli insegnamenti.';
      });
    }
  }


  Future<void> _loadSubjectCourses({
    required String universityCode,
    required String departmentCode,
    bool selectDefault = false,
  }) async {
    setState(() {
      _loadingSubjectCatalog =
          true;

      _subjectCourses =
          [];

      _subjectCourse =
          null;

      _availableSubjects =
          [];

      _subjectsError =
          null;

      _resetSubjectSelections();
    });

    try {
      final List<AcademicCourse>
          courses =
          await _apiService
              .getCourses(
        universityCode:
            universityCode,
        departmentCode:
            departmentCode,
      );

      if (!mounted) {
        return;
      }

      if (courses.isEmpty) {
        setState(() {
          _loadingSubjectCatalog =
              false;

          _subjectsError =
              'Nessun corso disponibile per il dipartimento selezionato.';
        });
        return;
      }

      AcademicCourse?
          selectedCourse;

      if (selectDefault) {
        for (
          final AcademicCourse course
          in courses
        ) {
          if (
            course.name
                .toLowerCase()
                .contains(
                  'informatica',
                )
          ) {
            selectedCourse =
                course;
            break;
          }
        }
      }

      selectedCourse ??=
          courses.first;

      setState(() {
        _subjectCourses =
            courses;

        _subjectCourse =
            selectedCourse;

        _loadingSubjectCatalog =
            false;
      });

      await _loadSubjects();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSubjectCatalog =
            false;

        _subjectsError =
            'Non è stato possibile caricare i corsi per gli insegnamenti.';
      });
    }
  }


  Future<void> _loadSubjects() async {
    final AcademicUniversity?
        university =
        _subjectUniversity ??
        _selectedUniversity;

    final AcademicDepartment?
        department =
        _subjectDepartment;

    final AcademicCourse?
        course =
        _subjectCourse;

    if (
      university == null ||
      department == null ||
      course == null
    ) {
      if (mounted) {
        setState(() {
          _subjectsError =
              'Seleziona ateneo, dipartimento e corso nella sezione Insegnamenti.';
        });
      }
      return;
    }

    setState(() {
      _loadingSubjects =
          true;

      _subjectsError =
          null;
    });

    try {
      final List<SocialSubject>
          loadedSubjects =
          await _apiService
              .getCatalogSubjects(
        universityCode:
            university.code,
        departmentCode:
            department.code,
        courseCode:
            course.code,
      );

      if (!mounted) {
        return;
      }

      final List<SocialSubject> subjects =
          loadedSubjects
              .where(
                (
                  SocialSubject subject,
                ) =>
                    subject.isActive,
              )
              .toList()
            ..sort(
              (
                SocialSubject a,
                SocialSubject b,
              ) {
                final int yearCompare =
                    (a.studyYear ?? 999)
                        .compareTo(
                  b.studyYear ?? 999,
                );

                if (yearCompare != 0) {
                  return yearCompare;
                }

                return a.name
                    .toLowerCase()
                    .compareTo(
                  b.name.toLowerCase(),
                );
              },
            );

      setState(() {
        _availableSubjects =
            subjects;

        _loadingSubjects =
            false;

        _subjectsError =
            subjects.isEmpty
                ? 'Nessuna materia attiva trovata per il corso selezionato.'
                : null;

        _resetSubjectSelections();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSubjects =
            false;

        _subjectsError =
            'Non è stato possibile caricare le materie. Riprova.';
      });
    }
  }

  void _resetSubjectSelections() {
    for (
      final _StudentSubjectData item
      in _subjects
    ) {
      item.selectedSubject =
          null;
    }
  }




  void _addSubject() {
    setState(() {
      _subjects.add(
        _StudentSubjectData(),
      );
    });
  }

  void _removeSubject(
    int index,
  ) {
    if (_subjects.length ==
        1) {
      return;
    }

    setState(() {
      _subjects[index]
          .dispose();

      _subjects.removeAt(
        index,
      );
    });
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime today =
        DateTime.now();

    final DateTime maximumDate =
        DateTime(
      today.year - 14,
      today.month,
      today.day,
    );

    final DateTime minimumDate =
        DateTime(
      1900,
      1,
      1,
    );

    final DateTime initialDate =
        _selectedDateOfBirth ??
        DateTime(
          maximumDate.year - 4,
          maximumDate.month,
          maximumDate.day,
        );

    final DateTime? selectedDate =
        await showDatePicker(
      context:
          context,

      initialDate:
          initialDate,

      firstDate:
          minimumDate,

      lastDate:
          maximumDate,

      helpText:
          'Seleziona la data di nascita',

      cancelText:
          'Annulla',

      confirmText:
          'Conferma',

      fieldLabelText:
          'Data di nascita',

      errorFormatText:
          'Inserisci una data valida',

      errorInvalidText:
          'La data selezionata non è valida',
    );

    if (
      selectedDate == null ||
      !mounted
    ) {
      return;
    }

    setState(() {
      _selectedDateOfBirth =
          selectedDate;

      _dateOfBirthController.text =
          _formatDate(
        selectedDate,
      );
    });
  }

  Future<void> _continue() async {
    final bool formValid =
        _formKey.currentState!
            .validate();

    String? passwordError =
        _validatePassword(
      _passwordController.text,
    );

    if (passwordError == null &&
        _passwordController.text !=
            _confirmPasswordController.text) {
      passwordError =
          'Le password non coincidono.';
    }

    setState(() {
      _passwordError =
          passwordError;
    });

    if (!formValid ||
        passwordError != null ||
        _selectedDateOfBirth == null) {
      return;
    }

    final DateTime dateOfBirth =
        _selectedDateOfBirth!;

    final AcademicUniversity?
        university =
        _selectedUniversity;

    final AcademicDepartment?
        department =
        _selectedDepartment;

    final AcademicCourse?
        course =
        _selectedCourse;

    final String universityName =
        !_primaryAcademicPathEnabled
            ? ''
            : _manualUniversity
                ? _manualUniversityController.text
                    .trim()
                : university?.name.trim() ??
                    '';

    final String universityCode =
        !_primaryAcademicPathEnabled ||
                _manualUniversity
            ? ''
            : university?.code.trim() ??
                '';

    final String departmentName =
        !_primaryAcademicPathEnabled
            ? ''
            : _manualDepartment
                ? _manualDepartmentController.text
                    .trim()
                : department?.name.trim() ??
                    '';

    final String departmentCode =
        !_primaryAcademicPathEnabled ||
                _manualDepartment
            ? ''
            : department?.code.trim() ??
                '';

    final String courseName =
        !_primaryAcademicPathEnabled
            ? ''
            : _manualCourse
                ? _manualCourseController.text
                    .trim()
                : course?.name.trim() ??
                    '';

    final String courseCode =
        !_primaryAcademicPathEnabled ||
                _manualCourse
            ? ''
            : course?.code.trim() ??
                '';

    final String degreeType =
        !_primaryAcademicPathEnabled ||
                _manualCourse
            ? ''
            : course?.degreeType.trim() ??
                _academicTitleType.trim();

    final int? startYear =
        _startYearController.text
                .trim()
                .isEmpty
            ? null
            : int.tryParse(
                _startYearController.text
                    .trim(),
              );

    const int? graduationYear =
        null;

    final List<SocialSubject>
        subjects =
        [];

    final Set<int>
        usedSubjectIds =
        {};

    if (!_manualCourse) {
      for (
        final _StudentSubjectData item
        in _subjects
      ) {
        final SocialSubject? selected =
            item.selectedSubject;

      if (selected == null) {
        continue;
      }

      if (
        usedSubjectIds.contains(
          selected.id,
        )
      ) {
        setState(() {
          _subjectsError =
              'Hai selezionato la stessa materia più di una volta.';
        });

        return;
      }

      usedSubjectIds.add(
        selected.id,
      );

      final String gradeText =
          item.gradeController.text
              .trim();

      final int? grade =
          gradeText.isEmpty
              ? null
              : int.tryParse(
                  gradeText,
                );

        subjects.add(
          SocialSubject(
            id:
                selected.id,

            code:
                selected.code,

            name:
                selected.name,

            university:
                selected.university,

            universityCode:
                selected.universityCode,

            department:
                selected.department,

            departmentCode:
                selected.departmentCode,

            course:
                selected.course,

            courseCode:
                selected.courseCode,

            degreeType:
                selected.degreeType,

            studyYear:
                selected.studyYear,

            offerings:
                selected.offerings,

            grade:
                grade,

            note:
                item.noteController.text
                    .trim(),

            canHelp:
                item.canHelp,

            canGivePrivateLessons:
                item
                    .canGivePrivateLessons,

            isActive:
                selected.isActive,
          ),
        );
      }
    }

    final SocialProfileDraft draft =
        SocialProfileDraft(
      firstName:
          _firstNameController.text
              .trim(),

      lastName:
          _lastNameController.text
              .trim(),

      email:
          _emailController.text
              .trim(),

      password:
          _passwordController.text,

      dateOfBirth:
          dateOfBirth,

      university:
          universityName,

      universityCode:
          universityCode,

      department:
          departmentName,

      departmentCode:
          departmentCode,

      course:
          courseName,

      courseCode:
          courseCode,

      degreeType:
          degreeType,

      academicStatus:
          _academicStatus,

      startYear:
          startYear,

      graduationYear:
          graduationYear,

      additionalAcademicPaths:
          List<SocialAcademicPathDraft>.unmodifiable(
        [
          ..._additionalAcademicPaths,
          ..._academicTitles,
        ],
      ),

      subjects:
          subjects,

      description:
          _descriptionController.text
              .trim(),

      type:
          SocialUserType.student,

      available:
          _available,

      availableForHelp:
          _availableForHelp,

      availableForPrivateLessons:
          _availableForPrivateLessons,
    );

    final SocialUser? user =
        await Navigator.push<SocialUser>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                SocialProfilePreview(
          draft:
              draft,
        ),
      ),
    );

    if (
      user != null &&
      mounted
    ) {
      Navigator.pop(
        context,
        user,
      );
    }
  }

  List<String> get _universityOptions {
    return _uniqueAcademicOptions(
      _universities.map(
        (
          AcademicUniversity university,
        ) =>
            university.name,
      ),
    );
  }

  List<String> get _departmentOptions {
    return _uniqueAcademicOptions(
      _departments.map(
        (
          AcademicDepartment department,
        ) =>
            department.name,
      ),
    );
  }

  List<String> get _courseOptions {
    return _uniqueAcademicOptions(
      _courses.map(
        (
          AcademicCourse course,
        ) =>
            course.name,
      ),
    );
  }

  List<String> _uniqueAcademicOptions(
    Iterable<String> source,
  ) {
    final Map<String, String> values =
        {};

    for (final String value in source) {
      final String trimmed =
          value.trim();

      if (trimmed.isEmpty) {
        continue;
      }

      values.putIfAbsent(
        _normalizeAcademicValue(
          trimmed,
        ),
        () =>
            trimmed,
      );
    }

    final List<String> result =
        values.values.toList();

    result.sort(
      (
        String a,
        String b,
      ) =>
          a.toLowerCase().compareTo(
                b.toLowerCase(),
              ),
    );

    return result;
  }

  String _normalizeAcademicValue(
    String value,
  ) {
    return value
        .trim()
        .replaceAll(
          RegExp(
            r'\s+',
          ),
          ' ',
        )
        .toLowerCase();
  }

  AcademicUniversity? _findUniversity(
    String value,
  ) {
    for (
      final AcademicUniversity university
      in _universities
    ) {
      if (
        _sameAcademicValue(
          university.name,
          value,
        ) ||
        _sameAcademicValue(
          university.code,
          value,
        )
      ) {
        return university;
      }
    }

    return null;
  }

  AcademicDepartment? _findDepartment(
    String value,
  ) {
    for (
      final AcademicDepartment department
      in _departments
    ) {
      if (
        _sameAcademicValue(
          department.name,
          value,
        ) ||
        _sameAcademicValue(
          department.code,
          value,
        )
      ) {
        return department;
      }
    }

    return null;
  }

  AcademicCourse? _findCourse(
    String value,
  ) {
    for (
      final AcademicCourse course
      in _courses
    ) {
      if (
        _sameAcademicValue(
          course.name,
          value,
        ) ||
        _sameAcademicValue(
          course.code,
          value,
        )
      ) {
        return course;
      }
    }

    return null;
  }

  void _onUniversityChanged(
    String value,
  ) {
    final AcademicUniversity? university =
        _findUniversity(
      value,
    );

    setState(() {
      _selectedUniversity =
          university;

      _manualUniversity =
          university == null;

      if (university == null) {
        _selectedDepartment =
            null;

        _selectedCourse =
            null;

        _manualDepartment =
            true;

        _manualCourse =
            true;

        _departments =
            [];

        _courses =
            [];

        _availableSubjects =
            [];
      }
    });
  }

  void _onDepartmentChanged(
    String value,
  ) {
    final AcademicDepartment? department =
        _findDepartment(
      value,
    );

    setState(() {
      _selectedDepartment =
          department;

      _manualDepartment =
          department == null;

      if (department == null) {
        _selectedCourse =
            null;

        _manualCourse =
            true;

        _courses =
            [];

        _availableSubjects =
            [];
      }
    });
  }

  void _onCourseChanged(
    String value,
  ) {
    final AcademicCourse? course =
        _findCourse(
      value,
    );

    setState(() {
      _selectedCourse =
          course;

      _manualCourse =
          course == null;

      if (course == null) {
        _availableSubjects =
            [];
      } else {
        _academicTitleType =
            course.degreeType.trim();
      }
    });
  }

  Future<void> _selectUniversityOption(
    String value,
  ) async {
    _manualUniversityController.text =
        value;

    _manualUniversityController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    final AcademicUniversity? university =
        _findUniversity(
      value,
    );

    setState(() {
      _selectedUniversity =
          university;

      _manualUniversity =
          university == null;

      _manualDepartment =
          university == null;

      _manualCourse =
          university == null;

      _manualDepartmentController.clear();

      _manualCourseController.clear();

      _selectedDepartment =
          null;

      _selectedCourse =
          null;

      _departments =
          [];

      _courses =
          [];

      _availableSubjects =
          [];
    });

    if (university == null) {
      return;
    }

    await _loadDepartments(
      university.code,
    );
  }

  Future<void> _selectDepartmentOption(
    String value,
  ) async {
    _manualDepartmentController.text =
        value;

    _manualDepartmentController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    final AcademicUniversity? university =
        _selectedUniversity;

    final AcademicDepartment? department =
        _findDepartment(
      value,
    );

    setState(() {
      _selectedDepartment =
          department;

      _manualDepartment =
          department == null;

      _manualCourse =
          department == null;

      _manualCourseController.clear();

      _selectedCourse =
          null;

      _courses =
          [];

      _availableSubjects =
          [];
    });

    if (
      university == null ||
      department == null
    ) {
      return;
    }

    await _loadCourses(
      universityCode:
          university.code,

      departmentCode:
          department.code,
    );
  }

  Future<void> _selectCourseOption(
    String value,
  ) async {
    _manualCourseController.text =
        value;

    _manualCourseController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    final AcademicCourse? course =
        _findCourse(
      value,
    );

    setState(() {
      _selectedCourse =
          course;

      _manualCourse =
          course == null;

      _availableSubjects =
          [];

      if (course != null) {
        _academicTitleType =
            course.degreeType.trim();
      }
    });

    if (course != null) {
      await _loadSubjects();
    }
  }

  Widget _hybridAcademicField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> options,
    required bool loading,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onOptionSelected,
  }) {
    return TextFormField(
      controller:
          controller,

      onChanged:
          onChanged,

      style:
          const TextStyle(
        color:
            AppColors.pureWhite,
      ),

      validator:
          _requiredValidator,

      decoration:
          InputDecoration(
        labelText:
            label,

        helperText:
            loading
                ? 'Caricamento opzioni...'
                : options.isEmpty
                    ? 'Scrivi un nuovo nome'
                    : 'Scrivi oppure scegli tra quelli esistenti',

        helperStyle:
            TextStyle(
          color:
              AppColors.pureWhite
                  .withOpacity(
            0.35,
          ),

          fontSize:
              9,
        ),

        prefixIcon:
            Icon(
          icon,

          color:
              AppColors.skyBlue,
        ),

        suffixIcon:
            loading
                ? const Padding(
                    padding:
                        EdgeInsets.all(
                      14,
                    ),

                    child:
                        SizedBox(
                      width:
                          18,

                      height:
                          18,

                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,

                        color:
                            AppColors.materialSky,
                      ),
                    ),
                  )
                : options.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        tooltip:
                            'Scegli $label',

                        color:
                            AppColors.eleganceDeepNavy,

                        icon:
                            const Icon(
                          Icons.arrow_drop_down_rounded,

                          color:
                              AppColors.materialSky,
                        ),

                        onSelected:
                            onOptionSelected,

                        itemBuilder:
                            (
                          BuildContext context,
                        ) {
                          return options
                              .map(
                                (
                                  String option,
                                ) =>
                                    PopupMenuItem<String>(
                                  value:
                                      option,

                                  child:
                                      Text(
                                    option,

                                    style:
                                        const TextStyle(
                                      color:
                                          AppColors.pureWhite,
                                    ),
                                  ),
                                ),
                              )
                              .toList();
                        },
                      ),

        filled:
            true,

        fillColor:
            AppColors.eleganceMidnight,

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

  void _addAcademicTitle() {
    setState(() {
      _editingAcademicTitleIndex =
          null;

      _showAcademicTitleEditor =
          true;
    });
  }

  void _editAcademicTitle(
    int index,
  ) {
    setState(() {
      _editingAcademicTitleIndex =
          index;

      _showAcademicTitleEditor =
          true;
    });
  }

  void _cancelAcademicTitle() {
    setState(() {
      _editingAcademicTitleIndex =
          null;

      _showAcademicTitleEditor =
          false;
    });
  }

  void _saveAcademicTitle(
    SocialAcademicPathDraft title,
  ) {
    final int? editingIndex =
        _editingAcademicTitleIndex;

    for (
      int index = 0;
      index < _academicTitles.length;
      index++
    ) {
      if (index == editingIndex) {
        continue;
      }

      final SocialAcademicPathDraft current =
          _academicTitles[index];

      final bool sameUniversity =
          current.universityCode.trim().isNotEmpty &&
                  title.universityCode.trim().isNotEmpty
              ? _sameAcademicValue(
                  current.universityCode,
                  title.universityCode,
                )
              : _sameAcademicValue(
                  current.university,
                  title.university,
                );

      final bool sameCourse =
          current.courseCode.trim().isNotEmpty &&
                  title.courseCode.trim().isNotEmpty
              ? _sameAcademicValue(
                  current.courseCode,
                  title.courseCode,
                )
              : _sameAcademicValue(
                  current.course,
                  title.course,
                );

      if (
        sameUniversity &&
        sameCourse &&
        _sameAcademicValue(
          current.degreeType,
          title.degreeType,
        ) &&
        current.graduationYear ==
            title.graduationYear
      ) {
        setState(() {
          _titlesError =
              'Questo titolo è già stato aggiunto.';
        });

        return;
      }
    }

    setState(() {
      _titlesError =
          null;

      if (editingIndex == null) {
        _academicTitles.add(
          title,
        );
      } else {
        _academicTitles[editingIndex] =
            title;
      }

      _editingAcademicTitleIndex =
          null;

      _showAcademicTitleEditor =
          false;
    });
  }

  void _addAdditionalAcademicPath() {
    setState(() {
      _editingAcademicPathIndex =
          null;

      _showAcademicPathEditor =
          true;
    });
  }

  void _editAdditionalAcademicPath(
    int index,
  ) {
    setState(() {
      _editingAcademicPathIndex =
          index;

      _showAcademicPathEditor =
          true;
    });
  }

  void _cancelAdditionalAcademicPath() {
    setState(() {
      _editingAcademicPathIndex =
          null;

      _showAcademicPathEditor =
          false;
    });
  }

  void _saveAdditionalAcademicPath(
    SocialAcademicPathDraft path,
  ) {
    final int? editingIndex =
        _editingAcademicPathIndex;

    if (editingIndex == null) {
      if (
        _containsAcademicPath(
          path,
        )
      ) {
        setState(() {
          _academicError =
              'Questo percorso accademico è già stato aggiunto.';
        });

        return;
      }
    } else {
      for (
        int index = 0;
        index < _additionalAcademicPaths.length;
        index++
      ) {
        if (index == editingIndex) {
          continue;
        }

        if (
          _sameAcademicPath(
            _additionalAcademicPaths[index],
            path,
          )
        ) {
          setState(() {
            _academicError =
                'Questo percorso accademico è già presente.';
          });

          return;
        }
      }
    }

    setState(() {
      if (path.isPrimary) {
        for (
          int index = 0;
          index < _additionalAcademicPaths.length;
          index++
        ) {
          if (index == editingIndex) {
            continue;
          }

          final SocialAcademicPathDraft value =
              _additionalAcademicPaths[index];

          _additionalAcademicPaths[index] =
              SocialAcademicPathDraft(
            university:
                value.university,
            universityCode:
                value.universityCode,
            department:
                value.department,
            departmentCode:
                value.departmentCode,
            course:
                value.course,
            courseCode:
                value.courseCode,
            degreeType:
                value.degreeType,
            status:
                value.status,
            startYear:
                value.startYear,
            graduationYear:
                value.graduationYear,
            isCurrent:
                value.isCurrent,
            isPrimary:
                false,
          );
        }
      }

      if (editingIndex == null) {
        _additionalAcademicPaths.add(
          path,
        );
      } else {
        _additionalAcademicPaths[editingIndex] =
            path;
      }

      _editingAcademicPathIndex =
          null;

      _showAcademicPathEditor =
          false;
    });
  }

  bool _containsAcademicPath(
    SocialAcademicPathDraft path,
  ) {
    final AcademicCourse? primaryCourse =
        _selectedCourse;

    final AcademicUniversity? primaryUniversity =
        _selectedUniversity;

    final String primaryUniversityName =
        _manualUniversity
            ? _manualUniversityController.text
                .trim()
            : primaryUniversity?.name.trim() ??
                '';

    final String primaryUniversityCode =
        _manualUniversity
            ? ''
            : primaryUniversity?.code.trim() ??
                '';

    final String primaryCourseName =
        _manualCourse
            ? _manualCourseController.text
                .trim()
            : primaryCourse?.name.trim() ??
                '';

    final String primaryCourseCode =
        _manualCourse
            ? ''
            : primaryCourse?.code.trim() ??
                '';

    if (
      primaryUniversityName.isNotEmpty &&
      primaryCourseName.isNotEmpty
    ) {
      final bool sameUniversity =
          primaryUniversityCode.isNotEmpty &&
                  path.universityCode.trim().isNotEmpty
              ? _sameAcademicValue(
                  primaryUniversityCode,
                  path.universityCode,
                )
              : _sameAcademicValue(
                  primaryUniversityName,
                  path.university,
                );

      final bool sameCourse =
          primaryCourseCode.isNotEmpty &&
                  path.courseCode.trim().isNotEmpty
              ? _sameAcademicValue(
                  primaryCourseCode,
                  path.courseCode,
                )
              : _sameAcademicValue(
                  primaryCourseName,
                  path.course,
                );

      if (
        sameUniversity &&
        sameCourse
      ) {
        return true;
      }
    }

    return _additionalAcademicPaths.any(
      (
        SocialAcademicPathDraft value,
      ) =>
          _sameAcademicPath(
        value,
        path,
      ),
    );
  }

  bool _sameAcademicPath(
    SocialAcademicPathDraft a,
    SocialAcademicPathDraft b,
  ) {
    final bool sameUniversity =
        a.universityCode.trim().isNotEmpty &&
                b.universityCode.trim().isNotEmpty
            ? _sameAcademicValue(
                a.universityCode,
                b.universityCode,
              )
            : _sameAcademicValue(
                a.university,
                b.university,
              );

    if (!sameUniversity) {
      return false;
    }

    if (
      a.courseCode.trim().isNotEmpty &&
      b.courseCode.trim().isNotEmpty
    ) {
      return _sameAcademicValue(
        a.courseCode,
        b.courseCode,
      );
    }

    return _sameAcademicValue(
      a.course,
      b.course,
    );
  }

  bool _sameAcademicValue(
    String a,
    String b,
  ) {
    return a
            .trim()
            .toLowerCase() ==
        b
            .trim()
            .toLowerCase();
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
            const Text(
          'Profilo studente',
        ),
      ),

      body:
          SafeArea(
        child:
            Center(
          child:
              LayoutBuilder(
            builder:
                (
              context,
              constraints,
            ) {
              final double width =
                  constraints.maxWidth >
                          700
                      ? 650
                      : constraints
                          .maxWidth;

              return SizedBox(
                width:
                    width,

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
                      const Text(
                        'Crea il tuo profilo',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite,

                          fontSize:
                              24,

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height:
                            8,
                      ),

                      Text(
                        'Crea il tuo account StudentLab e presentati agli altri studenti.',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.60,
                          ),

                          fontSize:
                              14,

                          height:
                              1.4,
                        ),
                      ),

                      const SizedBox(
                        height:
                            28,
                      ),

                      _buildRequiredField(
                        controller:
                            _firstNameController,

                        label:
                            'Nome',

                        hint:
                            'Es. Franz',

                        icon:
                            Icons.person_outline,
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      _buildRequiredField(
                        controller:
                            _lastNameController,

                        label:
                            'Cognome',

                        hint:
                            'Es. Amoroso',

                        icon:
                            Icons.person_outline,
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      TextFormField(
                        controller:
                            _dateOfBirthController,

                        readOnly:
                            true,

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        validator:
                            _validateDateOfBirth,

                        onTap:
                            _selectDateOfBirth,

                        decoration:
                            _decoration(
                          label:
                              'Data di nascita',

                          hint:
                              'Seleziona la data di nascita',

                          icon:
                              Icons.cake_outlined,
                        ).copyWith(
                          suffixIcon:
                              const Icon(
                            Icons.calendar_month_outlined,

                            color:
                                AppColors.skyBlue,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      TextFormField(
                        controller:
                            _emailController,

                        keyboardType:
                            TextInputType.emailAddress,

                        autofillHints:
                            const [
                          AutofillHints.email,
                        ],

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        validator:
                            _validateEmail,

                        decoration:
                            _decoration(
                          label:
                              'Email',

                          hint:
                              'nome@example.com',

                          icon:
                              Icons.email_outlined,
                        ),
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      TextFormField(
                        controller:
                            _passwordController,

                        obscureText:
                            !_passwordVisible,

                        enableSuggestions:
                            false,

                        autocorrect:
                            false,

                        autofillHints:
                            const [
                          AutofillHints.newPassword,
                        ],

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        validator:
                            _validatePassword,

                        decoration:
                            _passwordDecoration(
                          label:
                              'Password',

                          hint:
                              'Inserisci una password',

                          visible:
                              _passwordVisible,

                          onVisibilityPressed:
                              () {
                            setState(() {
                              _passwordVisible =
                                  !_passwordVisible;
                            });
                          },
                        ),
                      ),

                      const SizedBox(
                        height:
                            8,
                      ),

                      Text(
                        'Usa almeno 8 caratteri.',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.40,
                          ),

                          fontSize:
                              11,
                        ),
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      TextFormField(
                        controller:
                            _confirmPasswordController,

                        obscureText:
                            !_confirmPasswordVisible,

                        enableSuggestions:
                            false,

                        autocorrect:
                            false,

                        textInputAction:
                            TextInputAction.next,

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        validator:
                            _validateConfirmPassword,

                        decoration:
                            _passwordDecoration(
                          label:
                              'Conferma password',

                          hint:
                              'Ripeti la password',

                          visible:
                              _confirmPasswordVisible,

                          onVisibilityPressed:
                              () {
                            setState(() {
                              _confirmPasswordVisible =
                                  !_confirmPasswordVisible;
                            });
                          },
                        ),
                      ),

                      if (_passwordError != null) ...[
                        const SizedBox(
                          height:
                              12,
                        ),

                        _buildInlineError(
                          _passwordError!,
                        ),
                      ],

                      const SizedBox(
                        height:
                            28,
                      ),

                      const Text(
                        'Percorsi accademici',

                        style:
                            TextStyle(
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
                            8,
                      ),

                      Text(
                        'Aggiungi il percorso che stai frequentando o che hai frequentato. Puoi scrivere direttamente oppure scegliere una voce proposta dal catalogo.',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.50,
                          ),

                          fontSize:
                              12,

                          height:
                              1.4,
                        ),
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      if (_academicError != null) ...[
                        _buildInlineError(
                          _academicError!,
                        ),

                        const SizedBox(
                          height:
                              14,
                        ),
                      ],

                      if (_primaryAcademicPathEnabled) ...[
                      Container(
                        width:
                            double.infinity,

                        padding:
                            const EdgeInsets.all(
                          16,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.brandNightBlue,

                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),

                          border:
                              Border.all(
                            color:
                                AppColors.socialBlue
                                    .withOpacity(
                              0.20,
                            ),
                          ),
                        ),

                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.school_outlined,

                                  color:
                                      AppColors.skyBlue,
                                ),

                                SizedBox(
                                  width:
                                      10,
                                ),

                                Text(
                                  'Percorso 1',

                                  style:
                                      TextStyle(
                                    color:
                                        AppColors.pureWhite,

                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                                  14,
                            ),

                            _hybridAcademicField(
                              controller:
                                  _manualUniversityController,

                              label:
                                  'Ateneo',

                              icon:
                                  Icons.account_balance_outlined,

                              options:
                                  _universityOptions,

                              loading:
                                  _loadingAcademicData,

                              onChanged:
                                  _onUniversityChanged,

                              onOptionSelected:
                                  (
                                String value,
                              ) {
                                _selectUniversityOption(
                                  value,
                                );
                              },
                            ),

                            const SizedBox(
                              height:
                                  13,
                            ),

                            _hybridAcademicField(
                              controller:
                                  _manualDepartmentController,

                              label:
                                  'Dipartimento',

                              icon:
                                  Icons.apartment_outlined,

                              options:
                                  _departmentOptions,

                              loading:
                                  false,

                              onChanged:
                                  _onDepartmentChanged,

                              onOptionSelected:
                                  (
                                String value,
                              ) {
                                _selectDepartmentOption(
                                  value,
                                );
                              },
                            ),

                            const SizedBox(
                              height:
                                  13,
                            ),

                            _hybridAcademicField(
                              controller:
                                  _manualCourseController,

                              label:
                                  'Corso / percorso',

                              icon:
                                  Icons.school_outlined,

                              options:
                                  _courseOptions,

                              loading:
                                  false,

                              onChanged:
                                  _onCourseChanged,

                              onOptionSelected:
                                  (
                                String value,
                              ) {
                                _selectCourseOption(
                                  value,
                                );
                              },
                            ),

                            const SizedBox(
                              height:
                                  13,
                            ),

                            DropdownButtonFormField<
                                AcademicPathStatus>(
                              value:
                                  _academicStatus,

                              dropdownColor:
                                  AppColors.eleganceDeepNavy,

                              decoration:
                                  _decoration(
                                label:
                                    'Stato del percorso',

                                hint:
                                    'Seleziona lo stato',

                                icon:
                                    Icons.timeline_outlined,
                              ),

                              items:
                                  const [
                                DropdownMenuItem<
                                    AcademicPathStatus>(
                                  value:
                                      AcademicPathStatus.enrolled,

                                  child:
                                      Text(
                                    'Attualmente iscritto',

                                    style:
                                        TextStyle(
                                      color:
                                          AppColors.pureWhite,
                                    ),
                                  ),
                                ),

                                DropdownMenuItem<
                                    AcademicPathStatus>(
                                  value:
                                      AcademicPathStatus.suspended,

                                  child:
                                      Text(
                                    'Percorso sospeso',

                                    style:
                                        TextStyle(
                                      color:
                                          AppColors.pureWhite,
                                    ),
                                  ),
                                ),

                                DropdownMenuItem<
                                    AcademicPathStatus>(
                                  value:
                                      AcademicPathStatus.transferred,

                                  child:
                                      Text(
                                    'Trasferito',

                                    style:
                                        TextStyle(
                                      color:
                                          AppColors.pureWhite,
                                    ),
                                  ),
                                ),

                                DropdownMenuItem<
                                    AcademicPathStatus>(
                                  value:
                                      AcademicPathStatus.withdrawn,

                                  child:
                                      Text(
                                    'Percorso interrotto',

                                    style:
                                        TextStyle(
                                      color:
                                          AppColors.pureWhite,
                                    ),
                                  ),
                                ),
                              ],

                              onChanged:
                                  (
                                AcademicPathStatus? value,
                              ) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  _academicStatus =
                                      value;
                                });
                              },
                            ),

                            const SizedBox(
                              height:
                                  13,
                            ),

                            TextFormField(
                              controller:
                                  _startYearController,

                              keyboardType:
                                  TextInputType.number,

                              style:
                                  const TextStyle(
                                color:
                                    AppColors.pureWhite,
                              ),

                              validator:
                                  _validateStartYear,

                              decoration:
                                  _decoration(
                                label:
                                    'Anno di inizio (facoltativo)',

                                hint:
                                    'Es. 2023',

                                icon:
                                    Icons.calendar_month_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),


                        const SizedBox(
                          height:
                              10,
                        ),

                        Align(
                          alignment:
                              Alignment.centerRight,
                          child:
                              TextButton.icon(
                            onPressed:
                                () {
                              setState(() {
                                _primaryAcademicPathEnabled =
                                    false;
                              });
                            },
                            icon:
                                const Icon(
                              Icons.delete_outline_rounded,
                              size:
                                  17,
                            ),
                            label:
                                const Text(
                              'Rimuovi percorso',
                            ),
                            style:
                                TextButton.styleFrom(
                              foregroundColor:
                                  Colors.redAccent,
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets.all(
                            14,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                AppColors.eleganceMidnight,
                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),
                          child:
                              Text(
                            'Nessun percorso accademico inserito.',
                            style:
                                TextStyle(
                              color:
                                  AppColors.pureWhite
                                      .withValues(alpha: 0.38),
                              fontSize:
                                  10,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height:
                              10,
                        ),

                        OutlinedButton.icon(
                          onPressed:
                              () {
                            setState(() {
                              _primaryAcademicPathEnabled =
                                  true;
                            });
                          },
                          icon:
                              const Icon(
                            Icons.add_rounded,
                          ),
                          label:
                              const Text(
                            'Aggiungi percorso',
                          ),
                          style:
                              OutlinedButton.styleFrom(
                            foregroundColor:
                                AppColors.skyBlue,
                            side:
                                BorderSide(
                              color:
                                  AppColors.skyBlue
                                      .withValues(alpha: 0.30),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(
                        height:
                            18,
                      ),

                      Row(
                        children: [
                          const Expanded(
                            child:
                                Text(
                              'Altri percorsi',

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
                          ),

                          IconButton(
                            tooltip:
                                'Aggiungi percorso',

                            onPressed:
                                _addAdditionalAcademicPath,

                            icon:
                                const Icon(
                              Icons.add_circle_outline_rounded,

                              color:
                                  AppColors.skyBlue,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                            10,
                      ),

                      if (_showAcademicPathEditor)
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom:
                                14,
                          ),

                          child:
                              _InlineAcademicPathEditor(
                            key:
                                ValueKey<String>(
                              'academic-path-${_editingAcademicPathIndex ?? 'new'}',
                            ),

                            initialPath:
                                _editingAcademicPathIndex == null
                                    ? null
                                    : _additionalAcademicPaths[
                                        _editingAcademicPathIndex!
                                      ],

                            onSave:
                                _saveAdditionalAcademicPath,

                            onCancel:
                                _cancelAdditionalAcademicPath,
                          ),
                        ),

                      if (_additionalAcademicPaths.isEmpty)
                        Container(
                          width:
                              double.infinity,

                          padding:
                              const EdgeInsets.all(
                            14,
                          ),

                          decoration:
                              BoxDecoration(
                            color:
                                AppColors.eleganceMidnight,

                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),

                          child:
                              Text(
                            'Nessun altro percorso inserito.',

                            style:
                                TextStyle(
                              color:
                                  AppColors.pureWhite
                                      .withOpacity(
                                0.38,
                              ),

                              fontSize:
                                  10,
                            ),
                          ),
                        )
                      else
                        ...List.generate(
                          _additionalAcademicPaths.length,
                          (
                            int index,
                          ) {
                            final SocialAcademicPathDraft path =
                                _additionalAcademicPaths[index];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom:
                                    10,
                              ),

                              child:
                                  _AdditionalAcademicPathCard(
                                path:
                                    path,

                                onEdit:
                                    () {
                                  _editAdditionalAcademicPath(
                                    index,
                                  );
                                },

                                onDelete:
                                    () {
                                  setState(() {
                                    _additionalAcademicPaths.removeAt(
                                      index,
                                    );
                                  });
                                },
                              ),
                            );
                          },
                        ),

                      const SizedBox(
                        height:
                            10,
                      ),

                      OutlinedButton.icon(
                        onPressed:
                            _showAcademicPathEditor
                                ? null
                                : _addAdditionalAcademicPath,

                        icon:
                            const Icon(
                          Icons.add_rounded,
                        ),

                        label:
                            const Text(
                          'Aggiungi percorso',
                        ),

                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              AppColors.skyBlue,

                          side:
                              BorderSide(
                            color:
                                AppColors.skyBlue
                                    .withOpacity(
                              0.30,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            28,
                      ),

                      const Text(
                        'Titoli conseguiti',

                        style:
                            TextStyle(
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
                            8,
                      ),

                      Text(
                        'Aggiungi separatamente lauree, master, dottorati o altri titoli già conseguiti. Anche i titoli selezionati dal catalogo dovranno essere verificati.',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.50,
                          ),

                          fontSize:
                              12,

                          height:
                              1.4,
                        ),
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      if (_showAcademicTitleEditor)
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom:
                                14,
                          ),

                          child:
                              _InlineAcademicTitleEditor(
                            key:
                                ValueKey<String>(
                              'academic-title-${_editingAcademicTitleIndex ?? 'new'}',
                            ),

                            initialTitle:
                                _editingAcademicTitleIndex == null
                                    ? null
                                    : _academicTitles[
                                        _editingAcademicTitleIndex!
                                      ],

                            onSave:
                                _saveAcademicTitle,

                            onCancel:
                                _cancelAcademicTitle,
                          ),
                        ),

                      if (_academicTitles.isEmpty)
                        Container(
                          width:
                              double.infinity,

                          padding:
                              const EdgeInsets.all(
                            14,
                          ),

                          decoration:
                              BoxDecoration(
                            color:
                                AppColors.eleganceMidnight,

                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),

                          child:
                              Text(
                            'Nessun titolo conseguito inserito.',

                            style:
                                TextStyle(
                              color:
                                  AppColors.pureWhite
                                      .withOpacity(
                                0.38,
                              ),

                              fontSize:
                                  10,
                            ),
                          ),
                        )
                      else
                        ...List.generate(
                          _academicTitles.length,
                          (
                            int index,
                          ) {
                            final SocialAcademicPathDraft title =
                                _academicTitles[index];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom:
                                    10,
                              ),

                              child:
                                  _AcademicTitleDraftCard(
                                title:
                                    title,

                                onEdit:
                                    () {
                                  _editAcademicTitle(
                                    index,
                                  );
                                },

                                onDelete:
                                    () {
                                  setState(() {
                                    _academicTitles.removeAt(
                                      index,
                                    );
                                  });
                                },
                              ),
                            );
                          },
                        ),

                      const SizedBox(
                        height:
                            10,
                      ),

                      OutlinedButton.icon(
                        onPressed:
                            _showAcademicTitleEditor
                                ? null
                                : _addAcademicTitle,

                        icon:
                            const Icon(
                          Icons.add_rounded,
                        ),

                        label:
                            const Text(
                          'Aggiungi titolo conseguito',
                        ),

                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              AppColors.skyBlue,

                          side:
                              BorderSide(
                            color:
                                AppColors.skyBlue
                                    .withOpacity(
                              0.30,
                            ),
                          ),
                        ),
                      ),

                      if (_titlesError != null) ...[
                        const SizedBox(
                          height:
                              10,
                        ),

                        _buildInlineError(
                          _titlesError!,
                        ),
                      ],

                      const SizedBox(
                        height:
                            20,
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
                              Colors.amber.withOpacity(
                            0.06,
                          ),

                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),

                          border:
                              Border.all(
                            color:
                                Colors.amber.withOpacity(
                              0.16,
                            ),
                          ),
                        ),

                        child:
                            Text(
                          'Percorsi e titoli sono dichiarazioni dell’utente. La presenza nel catalogo non equivale a verifica: ogni dichiarazione può essere approvata o rifiutata.',

                          style:
                              TextStyle(
                            color:
                                AppColors.pureWhite
                                    .withOpacity(
                              0.58,
                            ),

                            fontSize:
                                10,

                            height:
                                1.4,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            20,
                      ),

                      Text(
                        'Seleziona il contesto accademico da cui caricare le materie. Questa scelta serve solo a cercare gli materie e non aggiunge automaticamente un percorso al profilo.',
                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withValues(
                                alpha:
                                    0.48,
                              ),
                          fontSize:
                              11,
                          height:
                              1.4,
                        ),
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      DropdownButtonFormField<
                          AcademicUniversity>(
                        initialValue:
                            _subjectUniversity,
                        isExpanded:
                            true,
                        dropdownColor:
                            AppColors.eleganceDeepNavy,
                        decoration:
                            _decoration(
                          label:
                              'Ateneo per materie',
                          hint:
                              'Seleziona ateneo',
                          icon:
                              Icons.account_balance_outlined,
                        ),
                        items:
                            _universities
                                .map(
                                  (
                                    AcademicUniversity university,
                                  ) =>
                                      DropdownMenuItem<
                                          AcademicUniversity>(
                                    value:
                                        university,
                                    child:
                                        Text(
                                      university.name,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          const TextStyle(
                                        color:
                                            AppColors.pureWhite,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            _loadingSubjectCatalog
                                ? null
                                : (
                          AcademicUniversity? value,
                        ) async {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _subjectUniversity =
                                value;
                          });

                          await _loadSubjectDepartments(
                            value.code,
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      DropdownButtonFormField<
                          AcademicDepartment>(
                        initialValue:
                            _subjectDepartment,
                        isExpanded:
                            true,
                        dropdownColor:
                            AppColors.eleganceDeepNavy,
                        decoration:
                            _decoration(
                          label:
                              'Dipartimento per materie',
                          hint:
                              'Seleziona dipartimento',
                          icon:
                              Icons.apartment_outlined,
                        ),
                        items:
                            _subjectDepartments
                                .map(
                                  (
                                    AcademicDepartment department,
                                  ) =>
                                      DropdownMenuItem<
                                          AcademicDepartment>(
                                    value:
                                        department,
                                    child:
                                        Text(
                                      department.name,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          const TextStyle(
                                        color:
                                            AppColors.pureWhite,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            _loadingSubjectCatalog ||
                                    _subjectUniversity ==
                                        null
                                ? null
                                : (
                          AcademicDepartment? value,
                        ) async {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _subjectDepartment =
                                value;
                          });

                          await _loadSubjectCourses(
                            universityCode:
                                _subjectUniversity!.code,
                            departmentCode:
                                value.code,
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      DropdownButtonFormField<
                          AcademicCourse>(
                        initialValue:
                            _subjectCourse,
                        isExpanded:
                            true,
                        dropdownColor:
                            AppColors.eleganceDeepNavy,
                        decoration:
                            _decoration(
                          label:
                              'Corso per materie',
                          hint:
                              'Seleziona corso',
                          icon:
                              Icons.school_outlined,
                        ),
                        items:
                            _subjectCourses
                                .map(
                                  (
                                    AcademicCourse course,
                                  ) =>
                                      DropdownMenuItem<
                                          AcademicCourse>(
                                    value:
                                        course,
                                    child:
                                        Text(
                                      course.name,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          const TextStyle(
                                        color:
                                            AppColors.pureWhite,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            _loadingSubjectCatalog ||
                                    _subjectUniversity ==
                                        null ||
                                    _subjectDepartment ==
                                        null
                                ? null
                                : (
                          AcademicCourse? value,
                        ) async {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _subjectCourse =
                                value;

                            _availableSubjects =
                                [];

                            _subjectsError =
                                null;

                            _resetSubjectSelections();
                          });

                          await _loadSubjects();
                        },
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      OutlinedButton.icon(
                        onPressed:
                            _loadingSubjects ||
                                    _loadingSubjectCatalog ||
                                    _subjectCourse ==
                                        null
                                ? null
                                : _loadSubjects,



                        icon:
                            _loadingSubjects
                                ? const SizedBox(
                                    width:
                                        17,

                                    height:
                                        17,

                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                  ),

                        label:
                            const Text(
                          'Carica materie',
                        ),
                      ),

                      if (_subjectsError != null) ...[
                        const SizedBox(
                          height:
                              8,
                        ),

                        _buildInlineError(
                          _subjectsError!,
                        ),
                      ],

                      const SizedBox(
                        height:
                            28,
                      ),

                      const Row(
                        children: [
                          Icon(
                            Icons.menu_book_outlined,

                            color:
                                AppColors.skyBlue,
                          ),

                          SizedBox(
                            width:
                                9,
                          ),

                          Text(
                            'Materie',

                            style:
                                TextStyle(
                              color:
                                  AppColors.pureWhite,

                              fontSize:
                                  17,

                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                            8,
                      ),

                      Text(
                        'Aggiungi le materie che fanno parte del tuo profilo e scegli separatamente quelle per cui puoi aiutare o offrire lezioni private.',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.50,
                          ),

                          fontSize:
                              12,
                        ),
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      if (_subjects.isEmpty)
                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets.all(
                            14,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                AppColors.eleganceMidnight,
                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),
                          ),
                          child:
                              Text(
                            'Nessuna materia inserita.',
                            style:
                                TextStyle(
                              color:
                                  AppColors.pureWhite
                                      .withValues(alpha: 0.38),
                              fontSize:
                                  10,
                            ),
                          ),
                        )
                      else
                        ...List.generate(
                          _subjects.length,
                          (
                            int index,
                          ) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom:
                                    14,
                              ),
                              child:
                                  _buildSubject(
                                index,
                              ),
                            );
                          },
                        ),

                      OutlinedButton.icon(
                        onPressed:
                            _addSubject,
                        icon:
                            const Icon(
                          Icons.add,
                        ),
                        label:
                            const Text(
                          'Aggiungi materia',
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              AppColors.skyBlue,
                          side:
                              BorderSide(
                            color:
                                AppColors.skyBlue
                                    .withOpacity(
                              0.30,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            28,
                      ),

                      TextFormField(
                        controller:
                            _descriptionController,

                        maxLines:
                            5,

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        decoration:
                            _decoration(
                          label:
                              'Descrizione',

                          hint:
                              'Presentati agli altri studenti...',

                          icon:
                              Icons
                                  .description_outlined,
                        ),
                      ),

                      const SizedBox(
                        height:
                            20,
                      ),

                      _switchCard(
                        title:
                            'Online',

                        subtitle:
                            'Attivo solo quando sei disponibile ad aiutare.',

                        value:
                            _available,

                        onChanged:
                            !_availableForHelp
                                ? null
                                : (
                          bool value,
                        ) {
                          setState(() {
                            _available =
                                value;
                          });
                        },
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      _switchCard(
                        title:
                            'Disponibile ad aiutare',

                        subtitle:
                            'Abilita globalmente la tua disponibilità ad aiutare altri studenti.',

                        value:
                            _availableForHelp,

                        onChanged:
                            (
                          bool value,
                        ) {
                          setState(() {
                            _availableForHelp =
                                value;

                            _available =
                                value;

                            if (!value) {
                              _availableForPrivateLessons =
                                  false;
                            }
                          });
                        },
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      _switchCard(
                        title:
                            'Disponibile per lezioni private',

                        subtitle:
                            'Abilita globalmente la possibilità di offrire lezioni private.',

                        value:
                            _availableForPrivateLessons,

                        onChanged:
                            !_availableForHelp
                                ? null
                                : (
                          bool value,
                        ) {
                          setState(() {
                            _availableForPrivateLessons =
                                value;
                          });
                        },
                      ),

                      const SizedBox(
                        height:
                            28,
                      ),

                      SizedBox(
                        height:
                            54,

                        child:
                            ElevatedButton.icon(
                          onPressed:
                              _continue,

                          icon:
                              const Icon(
                            Icons
                                .arrow_forward_rounded,
                          ),

                          label:
                              const Text(
                            'Visualizza anteprima',

                            style:
                                TextStyle(
                              fontSize:
                                  16,

                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.socialBlue,

                            foregroundColor:
                                AppColors.pureWhite,

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSubject(
    int index,
  ) {
    final _StudentSubjectData item =
        _subjects[index];

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.socialBlue
                  .withOpacity(
            0.20,
          ),
        ),
      ),

      child:
          Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,

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
                  'Materia ${index + 1}',

                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              if (_subjects.length >
                  1)
                IconButton(
                  onPressed:
                      () {
                    _removeSubject(
                      index,
                    );
                  },

                  icon:
                      const Icon(
                    Icons.delete_outline,
                  ),

                  color:
                      Colors.redAccent,
                ),
            ],
          ),

          const SizedBox(
            height:
                12,
          ),

          DropdownButtonFormField<
              SocialSubject>(
            value:
                item.selectedSubject,

            isExpanded:
                true,

            dropdownColor:
                AppColors
                    .eleganceDeepNavy,

            validator:
                (
              SocialSubject? value,
            ) {
              if (value == null) {
                return 'Seleziona una materia';
              }

              return null;
            },

            decoration:
                _decoration(
              label:
                  'Materia',

              hint:
                  'Seleziona una materia',

              icon:
                  Icons.book_outlined,
            ),

            items:
                _availableSubjects.map(
              (
                SocialSubject subject,
              ) {
                return DropdownMenuItem<
                    SocialSubject>(
                  value:
                      subject,

                  child:
                      Text(
                    subject.name,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      color:
                          AppColors.pureWhite,
                    ),
                  ),
                );
              },
            ).toList(),

            onChanged:
                (
              SocialSubject? value,
            ) {
              setState(() {
                item.selectedSubject =
                    value;
              });
            },
          ),

          const SizedBox(
            height:
                12,
          ),

          TextFormField(
            controller:
                item.gradeController,

            keyboardType:
                TextInputType.number,

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
                value == null ||
                value.trim().isEmpty
              ) {
                return null;
              }

              final int? grade =
                  int.tryParse(
                value.trim(),
              );

              if (grade == null) {
                return 'Inserisci un numero valido';
              }

              if (
                grade < 18 ||
                grade > 30
              ) {
                return 'Il voto deve essere tra 18 e 30';
              }

              return null;
            },

            decoration:
                _decoration(
              label:
                  'Voto (facoltativo)',

              hint:
                  'Es. 28',

              icon:
                  Icons.grade_outlined,
            ),
          ),

          const SizedBox(
            height:
                12,
          ),

          SwitchListTile(
            contentPadding:
                EdgeInsets.zero,

            value:
                item.canHelp,

            onChanged:
                (
              bool value,
            ) {
              setState(() {
                item.canHelp =
                    value;
              });
            },

            activeColor:
                AppColors.skyBlue,

            title:
                const Text(
              'Posso aiutare',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,

                fontSize:
                    13,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            subtitle:
                Text(
              'Rendi questa materia disponibile per le richieste di aiuto.',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.45,
                ),

                fontSize:
                    10,
              ),
            ),
          ),

          SwitchListTile(
            contentPadding:
                EdgeInsets.zero,

            value:
                item
                    .canGivePrivateLessons,

            onChanged:
                (
              bool value,
            ) {
              setState(() {
                item.canGivePrivateLessons =
                    value;
              });
            },

            activeColor:
                AppColors.skyBlue,

            title:
                const Text(
              'Lezioni private',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,

                fontSize:
                    13,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            subtitle:
                Text(
              'Indica se offri lezioni private su questa materia.',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.45,
                ),

                fontSize:
                    10,
              ),
            ),
          ),

          const SizedBox(
            height:
                4,
          ),

          TextFormField(
            controller:
                item.noteController,

            maxLines:
                3,

            style:
                const TextStyle(
              color:
                  AppColors.pureWhite,
            ),

            decoration:
                _decoration(
              label:
                  'Nota (facoltativa)',

              hint:
                  'Es. Posso aiutare con esercizi e teoria...',

              icon:
                  Icons.notes_outlined,
            ),
          ),
        ],
      ),
    );
  }

  String? _validateDateOfBirth(
    String? value,
  ) {
    final DateTime? date =
        _selectedDateOfBirth;

    if (date == null) {
      return 'Seleziona la tua data di nascita';
    }

    final DateTime today =
        DateTime.now();

    if (date.isAfter(today)) {
      return 'La data di nascita non può essere futura';
    }

    if (
      _calculateAge(
        date,
      ) <
          14
    ) {
      return 'Devi avere almeno 14 anni per creare un account StudentLab';
    }

    return null;
  }

  int _calculateAge(
    DateTime dateOfBirth,
  ) {
    final DateTime today =
        DateTime.now();

    int age =
        today.year -
        dateOfBirth.year;

    final bool birthdayNotReached =
        today.month <
                dateOfBirth.month ||
            (
              today.month ==
                      dateOfBirth.month &&
                  today.day <
                      dateOfBirth.day
            );

    if (birthdayNotReached) {
      age--;
    }

    return age;
  }

  String _formatDate(
    DateTime date,
  ) {
    final String day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }

  String? _requiredValidator(
    String? value,
  ) {
    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return 'Campo obbligatorio';
    }

    return null;
  }

  String? _validateEmail(
    String? value,
  ) {
    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return 'Campo obbligatorio';
    }

    final String email =
        value.trim();

    final RegExp emailRegex =
        RegExp(
      r'^[^@\s]+@[^@\s]+.[^@\s]+$',
    );

    if (
      !emailRegex.hasMatch(
        email,
      )
    ) {
      return 'Inserisci una email valida';
    }

    return null;
  }

  String? _validatePassword(
    String? value,
  ) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return 'Inserisci una password';
    }
    if (password.length < 8) {
      return 'Usa almeno 8 caratteri';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Aggiungi almeno una lettera minuscola';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Aggiungi almeno una lettera maiuscola';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Aggiungi almeno un numero';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Aggiungi almeno un carattere speciale';
    }
    return null;
  }

  String? _validateConfirmPassword(
    String? value,
  ) {
    if (
      value == null ||
      value.isEmpty
    ) {
      return 'Conferma la password';
    }

    if (
      value !=
          _passwordController.text
    ) {
      return 'Le password non coincidono';
    }

    return null;
  }

  String? _validateStartYear(
    String? value,
  ) {
    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return null;
    }

    final int? year =
        int.tryParse(
      value.trim(),
    );

    if (year == null) {
      return 'Inserisci un anno valido';
    }

    final int currentYear =
        DateTime.now().year;

    if (
      year < 1900 ||
      year > currentYear + 1
    ) {
      return 'Anno non valido';
    }

    return null;
  }

  String? _validateGraduationYear(
    String? value,
  ) {
    if (
      _academicStatus !=
          AcademicPathStatus.graduated
    ) {
      return null;
    }

    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return 'Inserisci l\'anno di conseguimento';
    }

    final int? year =
        int.tryParse(
      value.trim(),
    );

    if (year == null) {
      return 'Inserisci un anno valido';
    }

    final int currentYear =
        DateTime.now().year;

    if (
      year < 1900 ||
      year > currentYear
    ) {
      return 'Anno di conseguimento non valido';
    }

    final String startYearText =
        _startYearController.text
            .trim();

    if (startYearText.isNotEmpty) {
      final int? startYear =
          int.tryParse(
        startYearText,
      );

      if (
        startYear != null &&
        year < startYear
      ) {
        return 'L\'anno di conseguimento non può precedere l\'anno di inizio';
      }
    }

    return null;
  }

  Widget _buildRequiredField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller:
          controller,

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
          value == null ||
          value.trim().isEmpty
        ) {
          return 'Campo obbligatorio';
        }

        return null;
      },

      decoration:
          _decoration(
        label:
            label,

        hint:
            hint,

        icon:
            icon,
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText:
          label,

      hintText:
          hint,

      labelStyle:
          TextStyle(
        color:
            AppColors.pureWhite
                .withOpacity(
          0.60,
        ),
      ),

      hintStyle:
          TextStyle(
        color:
            AppColors.pureWhite
                .withOpacity(
          0.30,
        ),
      ),

      prefixIcon:
          Icon(
        icon,

        color:
            AppColors.skyBlue,
      ),

      filled:
          true,

      fillColor:
          AppColors.darkElegance,

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            BorderSide.none,
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            const BorderSide(
          color:
              AppColors.socialBlue,
        ),
      ),
    );
  }

  InputDecoration
      _passwordDecoration({
    required String label,
    required String hint,
    required bool visible,
    required VoidCallback onVisibilityPressed,
  }) {
    return InputDecoration(
      labelText:
          label,

      hintText:
          hint,

      labelStyle:
          TextStyle(
        color:
            AppColors.pureWhite
                .withOpacity(
          0.60,
        ),
      ),

      hintStyle:
          TextStyle(
        color:
            AppColors.pureWhite
                .withOpacity(
          0.30,
        ),
      ),

      prefixIcon:
          const Icon(
        Icons.lock_outline_rounded,

        color:
            AppColors.skyBlue,
      ),

      suffixIcon:
          IconButton(
        tooltip:
            visible
                ? 'Nascondi password'
                : 'Mostra password',

        onPressed:
            onVisibilityPressed,

        icon:
            Icon(
          visible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,

          color:
              AppColors.pureWhite
                  .withOpacity(
            0.55,
          ),
        ),
      ),

      filled:
          true,

      fillColor:
          AppColors.darkElegance,

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            BorderSide.none,
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            const BorderSide(
          color:
              AppColors.socialBlue,
        ),
      ),
    );
  }

  Widget _switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
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
          SwitchListTile(
        value:
            value,

        onChanged:
            onChanged,

        activeColor:
            AppColors.skyBlue,

        title:
            Text(
          title,

          style:
              const TextStyle(
            color:
                AppColors.pureWhite,

            fontWeight:
                FontWeight.w600,
          ),
        ),

        subtitle:
            Text(
          subtitle,

          style:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withOpacity(
              0.50,
            ),

            fontSize:
                12,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineError(
    String message,
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
            Colors.redAccent
                .withValues(alpha: 0.08),

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border:
            Border.all(
          color:
              Colors.redAccent
                  .withValues(alpha: 0.20),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.error_outline_rounded,

            color:
                Colors.redAccent,

            size:
                20,
          ),

          const SizedBox(
            width:
                9,
          ),

          Expanded(
            child:
                Text(
              message,

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withValues(alpha: 0.75),

                fontSize:
                    11,

                height:
                    1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentSubjectData {
  SocialSubject? selectedSubject;

  final TextEditingController
      gradeController =
      TextEditingController();

  final TextEditingController
      noteController =
      TextEditingController();

  bool canHelp =
      false;

  bool canGivePrivateLessons =
      false;

  void dispose() {
    gradeController.dispose();

    noteController.dispose();
  }
}


class _InlineAcademicPathEditor
    extends StatefulWidget {
  final SocialAcademicPathDraft? initialPath;

  final ValueChanged<SocialAcademicPathDraft>
      onSave;

  final VoidCallback onCancel;

  const _InlineAcademicPathEditor({
    super.key,
    this.initialPath,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_InlineAcademicPathEditor>
      createState() =>
          _InlineAcademicPathEditorState();
}

class _InlineAcademicPathEditorState
    extends State<_InlineAcademicPathEditor> {
  final ApiService _apiService =
      ApiService();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _universityController =
      TextEditingController();

  final TextEditingController
      _departmentController =
      TextEditingController();

  final TextEditingController
      _courseController =
      TextEditingController();

  final TextEditingController
      _startYearController =
      TextEditingController();

  List<AcademicUniversity> _universities =
      [];

  List<AcademicDepartment> _departments =
      [];

  List<AcademicCourse> _courses =
      [];

  AcademicUniversity? _selectedUniversity;

  AcademicDepartment? _selectedDepartment;

  AcademicCourse? _selectedCourse;

  AcademicPathStatus _status =
      AcademicPathStatus.enrolled;

  bool _isCurrent =
      false;

  bool _isPrimary =
      false;

  bool _loadingUniversities =
      true;

  bool _loadingDepartments =
      false;

  bool _loadingCourses =
      false;

  String? _error;

  @override
  void initState() {
    super.initState();

    final SocialAcademicPathDraft? path =
        widget.initialPath;

    if (path != null) {
      _universityController.text =
          path.university;

      _departmentController.text =
          path.department;

      _courseController.text =
          path.course;

      _startYearController.text =
          path.startYear?.toString() ??
              '';

      _status =
          path.status ==
                  AcademicPathStatus.graduated
              ? AcademicPathStatus.enrolled
              : path.status;

      _isCurrent =
          path.isCurrent;

      _isPrimary =
          path.isPrimary;
    }

    _loadUniversities();
  }

  @override
  void dispose() {
    _universityController.dispose();

    _departmentController.dispose();

    _courseController.dispose();

    _startYearController.dispose();

    super.dispose();
  }

  Future<void> _loadUniversities() async {
    setState(() {
      _loadingUniversities =
          true;

      _error =
          null;
    });

    try {
      final List<AcademicUniversity> values =
          await _apiService
              .getUniversities();

      if (!mounted) {
        return;
      }

      setState(() {
        _universities =
            values;

        _selectedUniversity =
            _findUniversity(
          _universityController.text,
        );
      });

      final AcademicUniversity? university =
          _selectedUniversity;

      if (university != null) {
        await _loadDepartments(
          university,
          clearChildren:
              false,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Il catalogo accademico non è disponibile. Puoi continuare scrivendo i dati manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUniversities =
              false;
        });
      }
    }
  }

  Future<void> _loadDepartments(
    AcademicUniversity university, {
    bool clearChildren =
        true,
  }) async {
    setState(() {
      _loadingDepartments =
          true;

      if (clearChildren) {
        _departments =
            [];

        _courses =
            [];
      }
    });

    try {
      final List<AcademicDepartment> values =
          await _apiService
              .getDepartments(
        university.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _departments =
            values;

        _selectedDepartment =
            _findDepartment(
          _departmentController.text,
        );
      });

      final AcademicDepartment? department =
          _selectedDepartment;

      if (department != null) {
        await _loadCourses(
          university,
          department,
          clearCourse:
              false,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Il catalogo dei dipartimenti non è disponibile. Puoi continuare manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDepartments =
              false;
        });
      }
    }
  }

  Future<void> _loadCourses(
    AcademicUniversity university,
    AcademicDepartment department, {
    bool clearCourse =
        true,
  }) async {
    setState(() {
      _loadingCourses =
          true;

      if (clearCourse) {
        _courses =
            [];
      }
    });

    try {
      final List<AcademicCourse> values =
          await _apiService
              .getCourses(
        universityCode:
            university.code,

        departmentCode:
            department.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _courses =
            values;

        _selectedCourse =
            _findCourse(
          _courseController.text,
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Il catalogo dei corsi non è disponibile. Puoi continuare manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCourses =
              false;
        });
      }
    }
  }

  Future<void> _selectUniversity(
    String value,
  ) async {
    _universityController.text =
        value;

    _universityController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    final AcademicUniversity? university =
        _findUniversity(
      value,
    );

    setState(() {
      _selectedUniversity =
          university;

      _departmentController.clear();

      _courseController.clear();

      _selectedDepartment =
          null;

      _selectedCourse =
          null;

      _departments =
          [];

      _courses =
          [];
    });

    if (university != null) {
      await _loadDepartments(
        university,
      );
    }
  }

  Future<void> _selectDepartment(
    String value,
  ) async {
    _departmentController.text =
        value;

    _departmentController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    final AcademicUniversity? university =
        _findUniversity(
      _universityController.text,
    );

    final AcademicDepartment? department =
        _findDepartment(
      value,
    );

    setState(() {
      _selectedDepartment =
          department;

      _courseController.clear();

      _selectedCourse =
          null;

      _courses =
          [];
    });

    if (
      university != null &&
      department != null
    ) {
      await _loadCourses(
        university,
        department,
      );
    }
  }

  void _selectCourse(
    String value,
  ) {
    _courseController.text =
        value;

    _courseController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    setState(() {
      _selectedCourse =
          _findCourse(
        value,
      );
    });
  }

  void _onUniversityChanged(
    String value,
  ) {
    setState(() {
      _selectedUniversity =
          _findUniversity(
        value,
      );

      if (_selectedUniversity == null) {
        _selectedDepartment =
            null;

        _selectedCourse =
            null;

        _departments =
            [];

        _courses =
            [];
      }
    });
  }

  void _onDepartmentChanged(
    String value,
  ) {
    setState(() {
      _selectedDepartment =
          _findDepartment(
        value,
      );

      if (_selectedDepartment == null) {
        _selectedCourse =
            null;

        _courses =
            [];
      }
    });
  }

  void _onCourseChanged(
    String value,
  ) {
    setState(() {
      _selectedCourse =
          _findCourse(
        value,
      );
    });
  }

  void _save() {
    if (
      !_formKey.currentState!
          .validate()
    ) {
      return;
    }

    final String university =
        _universityController.text
            .trim();

    final String department =
        _departmentController.text
            .trim();

    final String course =
        _courseController.text
            .trim();

    final AcademicUniversity? catalogUniversity =
        _findUniversity(
      university,
    );

    final AcademicDepartment? catalogDepartment =
        _findDepartment(
      department,
    );

    final AcademicCourse? catalogCourse =
        _findCourse(
      course,
    );

    final int? startYear =
        _startYearController.text
                .trim()
                .isEmpty
            ? null
            : int.tryParse(
                _startYearController.text
                    .trim(),
              );

    widget.onSave(
      SocialAcademicPathDraft(
        university:
            university,

        universityCode:
            catalogUniversity?.code ??
                '',

        department:
            department,

        departmentCode:
            catalogDepartment?.code ??
                '',

        course:
            course,

        courseCode:
            catalogCourse?.code ??
                '',

        degreeType:
            catalogCourse?.degreeType ??
                widget.initialPath?.degreeType ??
                '',

        status:
            _status,

        startYear:
            startYear,

        graduationYear:
            null,

        isCurrent:
            _status ==
                    AcademicPathStatus.enrolled &&
                _isCurrent,

        isPrimary:
            _isPrimary,
      ),
    );
  }

  String? _required(
    String? value,
  ) {
    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return 'Campo obbligatorio';
    }

    return null;
  }

  String? _validateStartYear(
    String? value,
  ) {
    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return null;
    }

    final int? year =
        int.tryParse(
      value.trim(),
    );

    final int currentYear =
        DateTime.now().year;

    if (
      year == null ||
      year < 1900 ||
      year > currentYear + 1
    ) {
      return 'Anno non valido';
    }

    return null;
  }

  AcademicUniversity? _findUniversity(
    String value,
  ) {
    for (
      final AcademicUniversity university
      in _universities
    ) {
      if (
        _same(
          university.name,
          value,
        ) ||
        _same(
          university.code,
          value,
        )
      ) {
        return university;
      }
    }

    return null;
  }

  AcademicDepartment? _findDepartment(
    String value,
  ) {
    for (
      final AcademicDepartment department
      in _departments
    ) {
      if (
        _same(
          department.name,
          value,
        ) ||
        _same(
          department.code,
          value,
        )
      ) {
        return department;
      }
    }

    return null;
  }

  AcademicCourse? _findCourse(
    String value,
  ) {
    for (
      final AcademicCourse course
      in _courses
    ) {
      if (
        _same(
          course.name,
          value,
        ) ||
        _same(
          course.code,
          value,
        )
      ) {
        return course;
      }
    }

    return null;
  }

  List<String> _options(
    Iterable<String> source,
  ) {
    final Map<String, String> values =
        {};

    for (final String value in source) {
      final String trimmed =
          value.trim();

      if (trimmed.isEmpty) {
        continue;
      }

      values.putIfAbsent(
        trimmed.toLowerCase(),
        () =>
            trimmed,
      );
    }

    final List<String> result =
        values.values.toList();

    result.sort(
      (
        String a,
        String b,
      ) =>
          a.toLowerCase().compareTo(
                b.toLowerCase(),
              ),
    );

    return result;
  }

  bool _same(
    String a,
    String b,
  ) {
    return a
            .trim()
            .toLowerCase() ==
        b
            .trim()
            .toLowerCase();
  }

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
            AppColors.brandNightBlue,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.22,
          ),
        ),
      ),

      child:
          Form(
        key:
            _formKey,

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
                    widget.initialPath == null
                        ? 'Nuovo percorso'
                        : 'Modifica percorso',

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

                IconButton(
                  tooltip:
                      'Chiudi',

                  onPressed:
                      widget.onCancel,

                  icon:
                      const Icon(
                    Icons.close_rounded,

                    color:
                        Colors.white54,
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              Text(
                _error!,

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withOpacity(
                    0.52,
                  ),

                  fontSize:
                      10,
                ),
              ),

              const SizedBox(
                height:
                    12,
              ),
            ],

            _InlineHybridAcademicField(
              controller:
                  _universityController,

              label:
                  'Ateneo',

              icon:
                  Icons.account_balance_outlined,

              options:
                  _options(
                _universities.map(
                  (
                    AcademicUniversity value,
                  ) =>
                      value.name,
                ),
              ),

              loading:
                  _loadingUniversities,

              onChanged:
                  _onUniversityChanged,

              onOptionSelected:
                  (
                String value,
              ) {
                _selectUniversity(
                  value,
                );
              },
            ),

            const SizedBox(
              height:
                  13,
            ),

            _InlineHybridAcademicField(
              controller:
                  _departmentController,

              label:
                  'Dipartimento',

              icon:
                  Icons.apartment_outlined,

              options:
                  _options(
                _departments.map(
                  (
                    AcademicDepartment value,
                  ) =>
                      value.name,
                ),
              ),

              loading:
                  _loadingDepartments,

              onChanged:
                  _onDepartmentChanged,

              onOptionSelected:
                  (
                String value,
              ) {
                _selectDepartment(
                  value,
                );
              },
            ),

            const SizedBox(
              height:
                  13,
            ),

            _InlineHybridAcademicField(
              controller:
                  _courseController,

              label:
                  'Corso / percorso',

              icon:
                  Icons.school_outlined,

              options:
                  _options(
                _courses.map(
                  (
                    AcademicCourse value,
                  ) =>
                      value.name,
                ),
              ),

              loading:
                  _loadingCourses,

              onChanged:
                  _onCourseChanged,

              onOptionSelected:
                  _selectCourse,
            ),

            const SizedBox(
              height:
                  13,
            ),

            DropdownButtonFormField<
                AcademicPathStatus>(
              value:
                  _status,

              dropdownColor:
                  AppColors.eleganceDeepNavy,

              decoration:
                  _fieldDecoration(
                label:
                    'Stato del percorso',

                icon:
                    Icons.timeline_outlined,
              ),

              items:
                  const [
                DropdownMenuItem(
                  value:
                      AcademicPathStatus.enrolled,

                  child:
                      Text(
                    'Attualmente iscritto',

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite,
                    ),
                  ),
                ),

                DropdownMenuItem(
                  value:
                      AcademicPathStatus.suspended,

                  child:
                      Text(
                    'Percorso sospeso',

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite,
                    ),
                  ),
                ),

                DropdownMenuItem(
                  value:
                      AcademicPathStatus.transferred,

                  child:
                      Text(
                    'Trasferito',

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite,
                    ),
                  ),
                ),

                DropdownMenuItem(
                  value:
                      AcademicPathStatus.withdrawn,

                  child:
                      Text(
                    'Percorso interrotto',

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite,
                    ),
                  ),
                ),
              ],

              onChanged:
                  (
                AcademicPathStatus? value,
              ) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _status =
                      value;

                  if (
                    value !=
                        AcademicPathStatus.enrolled
                  ) {
                    _isCurrent =
                        false;
                  }
                });
              },
            ),

            const SizedBox(
              height:
                  13,
            ),

            TextFormField(
              controller:
                  _startYearController,

              keyboardType:
                  TextInputType.number,

              validator:
                  _validateStartYear,

              style:
                  const TextStyle(
                color:
                    AppColors.pureWhite,
              ),

              decoration:
                  _fieldDecoration(
                label:
                    'Anno di inizio',

                icon:
                    Icons.calendar_month_outlined,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,

              value:
                  _isCurrent,

              onChanged:
                  _status ==
                          AcademicPathStatus.enrolled
                      ? (
                          bool value,
                        ) {
                          setState(() {
                            _isCurrent =
                                value;
                          });
                        }
                      : null,

              title:
                  const Text(
                'Percorso corrente',

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite,

                  fontSize:
                      12,
                ),
              ),
            ),

            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,

              value:
                  _isPrimary,

              onChanged:
                  (
                bool value,
              ) {
                setState(() {
                  _isPrimary =
                      value;
                });
              },

              title:
                  const Text(
                'Percorso principale',

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite,

                  fontSize:
                      12,
                ),
              ),
            ),

            const SizedBox(
              height:
                  12,
            ),

            SizedBox(
              width:
                  double.infinity,

              child:
                  ElevatedButton.icon(
                onPressed:
                    _save,

                icon:
                    const Icon(
                  Icons.save_outlined,
                ),

                label:
                    Text(
                  widget.initialPath == null
                      ? 'Aggiungi percorso'
                      : 'Salva modifiche',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText:
          label,

      prefixIcon:
          Icon(
        icon,

        color:
            AppColors.skyBlue,
      ),

      filled:
          true,

      fillColor:
          AppColors.eleganceMidnight,

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
    );
  }
}

class _InlineAcademicTitleEditor
    extends StatefulWidget {
  final SocialAcademicPathDraft? initialTitle;

  final ValueChanged<SocialAcademicPathDraft>
      onSave;

  final VoidCallback onCancel;

  const _InlineAcademicTitleEditor({
    super.key,
    this.initialTitle,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_InlineAcademicTitleEditor>
      createState() =>
          _InlineAcademicTitleEditorState();
}

class _InlineAcademicTitleEditorState
    extends State<_InlineAcademicTitleEditor> {
  final ApiService _apiService =
      ApiService();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _titleController =
      TextEditingController();

  final TextEditingController
      _universityController =
      TextEditingController();

  final TextEditingController
      _departmentController =
      TextEditingController();

  final TextEditingController
      _courseController =
      TextEditingController();

  final TextEditingController
      _graduationYearController =
      TextEditingController();

  List<AcademicUniversity> _universities =
      [];

  List<AcademicDepartment> _departments =
      [];

  List<AcademicCourse> _courses =
      [];

  AcademicUniversity? _selectedUniversity;

  AcademicDepartment? _selectedDepartment;

  AcademicCourse? _selectedCourse;

  bool _loadingUniversities =
      true;

  bool _loadingDepartments =
      false;

  bool _loadingCourses =
      false;

  String? _error;

  @override
  void initState() {
    super.initState();

    final SocialAcademicPathDraft? title =
        widget.initialTitle;

    if (title != null) {
      _titleController.text =
          title.degreeType;

      _universityController.text =
          title.university;

      _departmentController.text =
          title.department;

      _courseController.text =
          title.course;

      _graduationYearController.text =
          title.graduationYear?.toString() ??
              '';
    }

    _loadUniversities();
  }

  @override
  void dispose() {
    _titleController.dispose();

    _universityController.dispose();

    _departmentController.dispose();

    _courseController.dispose();

    _graduationYearController.dispose();

    super.dispose();
  }

  Future<void> _loadUniversities() async {
    setState(() {
      _loadingUniversities =
          true;

      _error =
          null;
    });

    try {
      final List<AcademicUniversity> values =
          await _apiService
              .getUniversities();

      if (!mounted) {
        return;
      }

      setState(() {
        _universities =
            values;

        _selectedUniversity =
            _findUniversity(
          _universityController.text,
        );
      });

      final AcademicUniversity? university =
          _selectedUniversity;

      if (university != null) {
        await _loadDepartments(
          university,
          clearChildren:
              false,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Il catalogo accademico non è disponibile. Puoi continuare scrivendo i dati manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUniversities =
              false;
        });
      }
    }
  }

  Future<void> _loadDepartments(
    AcademicUniversity university, {
    bool clearChildren =
        true,
  }) async {
    setState(() {
      _loadingDepartments =
          true;

      if (clearChildren) {
        _departments =
            [];

        _courses =
            [];
      }
    });

    try {
      final List<AcademicDepartment> values =
          await _apiService
              .getDepartments(
        university.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _departments =
            values;

        _selectedDepartment =
            _findDepartment(
          _departmentController.text,
        );
      });

      final AcademicDepartment? department =
          _selectedDepartment;

      if (department != null) {
        await _loadCourses(
          university,
          department,
          clearCourse:
              false,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Il catalogo dei dipartimenti non è disponibile. Puoi continuare manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDepartments =
              false;
        });
      }
    }
  }

  Future<void> _loadCourses(
    AcademicUniversity university,
    AcademicDepartment department, {
    bool clearCourse =
        true,
  }) async {
    setState(() {
      _loadingCourses =
          true;

      if (clearCourse) {
        _courses =
            [];
      }
    });

    try {
      final List<AcademicCourse> values =
          await _apiService
              .getCourses(
        universityCode:
            university.code,

        departmentCode:
            department.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _courses =
            values;

        _selectedCourse =
            _findCourse(
          _courseController.text,
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Il catalogo dei corsi non è disponibile. Puoi continuare manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCourses =
              false;
        });
      }
    }
  }

  Future<void> _selectUniversity(
    String value,
  ) async {
    _universityController.text =
        value;

    _universityController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    final AcademicUniversity? university =
        _findUniversity(
      value,
    );

    setState(() {
      _selectedUniversity =
          university;

      _departmentController.clear();

      _courseController.clear();

      _selectedDepartment =
          null;

      _selectedCourse =
          null;

      _departments =
          [];

      _courses =
          [];
    });

    if (university != null) {
      await _loadDepartments(
        university,
      );
    }
  }

  Future<void> _selectDepartment(
    String value,
  ) async {
    _departmentController.text =
        value;

    _departmentController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    final AcademicUniversity? university =
        _findUniversity(
      _universityController.text,
    );

    final AcademicDepartment? department =
        _findDepartment(
      value,
    );

    setState(() {
      _selectedDepartment =
          department;

      _courseController.clear();

      _selectedCourse =
          null;

      _courses =
          [];
    });

    if (
      university != null &&
      department != null
    ) {
      await _loadCourses(
        university,
        department,
      );
    }
  }

  void _selectCourse(
    String value,
  ) {
    _courseController.text =
        value;

    _courseController.selection =
        TextSelection.collapsed(
      offset:
          value.length,
    );

    final AcademicCourse? course =
        _findCourse(
      value,
    );

    setState(() {
      _selectedCourse =
          course;

      if (
        course != null &&
        _titleController.text
            .trim()
            .isEmpty
      ) {
        _titleController.text =
            _titleTypeFromDegreeType(
          course.degreeType,
        );
      }
    });
  }

  void _save() {
    if (
      !_formKey.currentState!
          .validate()
    ) {
      return;
    }

    final String university =
        _universityController.text
            .trim();

    final String department =
        _departmentController.text
            .trim();

    final String course =
        _courseController.text
            .trim();

    final String title =
        _titleController.text
            .trim();

    final int graduationYear =
        int.parse(
      _graduationYearController.text
          .trim(),
    );

    final AcademicUniversity? catalogUniversity =
        _findUniversity(
      university,
    );

    final AcademicDepartment? catalogDepartment =
        _findDepartment(
      department,
    );

    final AcademicCourse? catalogCourse =
        _findCourse(
      course,
    );

    widget.onSave(
      SocialAcademicPathDraft(
        university:
            university,

        universityCode:
            catalogUniversity?.code ??
                '',

        department:
            department,

        departmentCode:
            catalogDepartment?.code ??
                '',

        course:
            course,

        courseCode:
            catalogCourse?.code ??
                '',

        degreeType:
            title,

        status:
            AcademicPathStatus.graduated,

        startYear:
            null,

        graduationYear:
            graduationYear,

        isCurrent:
            false,

        isPrimary:
            false,
      ),
    );
  }

  String? _required(
    String? value,
  ) {
    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return 'Campo obbligatorio';
    }

    return null;
  }

  String? _validateGraduationYear(
    String? value,
  ) {
    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return 'Inserisci l’anno di conseguimento';
    }

    final int? year =
        int.tryParse(
      value.trim(),
    );

    final int currentYear =
        DateTime.now().year;

    if (
      year == null ||
      year < 1900 ||
      year > currentYear
    ) {
      return 'Anno di conseguimento non valido';
    }

    return null;
  }

  AcademicUniversity? _findUniversity(
    String value,
  ) {
    for (
      final AcademicUniversity university
      in _universities
    ) {
      if (
        _same(
          university.name,
          value,
        ) ||
        _same(
          university.code,
          value,
        )
      ) {
        return university;
      }
    }

    return null;
  }

  AcademicDepartment? _findDepartment(
    String value,
  ) {
    for (
      final AcademicDepartment department
      in _departments
    ) {
      if (
        _same(
          department.name,
          value,
        ) ||
        _same(
          department.code,
          value,
        )
      ) {
        return department;
      }
    }

    return null;
  }

  AcademicCourse? _findCourse(
    String value,
  ) {
    for (
      final AcademicCourse course
      in _courses
    ) {
      if (
        _same(
          course.name,
          value,
        ) ||
        _same(
          course.code,
          value,
        )
      ) {
        return course;
      }
    }

    return null;
  }

  List<String> _options(
    Iterable<String> source,
  ) {
    final Map<String, String> values =
        {};

    for (final String value in source) {
      final String trimmed =
          value.trim();

      if (trimmed.isEmpty) {
        continue;
      }

      values.putIfAbsent(
        trimmed.toLowerCase(),
        () =>
            trimmed,
      );
    }

    final List<String> result =
        values.values.toList();

    result.sort(
      (
        String a,
        String b,
      ) =>
          a.toLowerCase().compareTo(
                b.toLowerCase(),
              ),
    );

    return result;
  }

  bool _same(
    String a,
    String b,
  ) {
    return a
            .trim()
            .toLowerCase() ==
        b
            .trim()
            .toLowerCase();
  }

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
            AppColors.brandNightBlue,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              Colors.amber.withOpacity(
            0.20,
          ),
        ),
      ),

      child:
          Form(
        key:
            _formKey,

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
                    widget.initialTitle == null
                        ? 'Nuovo titolo'
                        : 'Modifica titolo',

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

                IconButton(
                  tooltip:
                      'Chiudi',

                  onPressed:
                      widget.onCancel,

                  icon:
                      const Icon(
                    Icons.close_rounded,

                    color:
                        Colors.white54,
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              Text(
                _error!,

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withOpacity(
                    0.52,
                  ),

                  fontSize:
                      10,
                ),
              ),

              const SizedBox(
                height:
                    12,
              ),
            ],

            _InlineHybridAcademicField(
              controller:
                  _titleController,

              label:
                  'Titolo conseguito',

              icon:
                  Icons.workspace_premium_outlined,

              options:
                  _academicTitleTypes,

              loading:
                  false,

              onChanged:
                  (_) {
                setState(() {});
              },

              onOptionSelected:
                  (
                String value,
              ) {
                _titleController.text =
                    value;

                _titleController.selection =
                    TextSelection.collapsed(
                  offset:
                      value.length,
                );

                setState(() {});
              },
            ),

            const SizedBox(
              height:
                  13,
            ),

            _InlineHybridAcademicField(
              controller:
                  _universityController,

              label:
                  'Ateneo',

              icon:
                  Icons.account_balance_outlined,

              options:
                  _options(
                _universities.map(
                  (
                    AcademicUniversity value,
                  ) =>
                      value.name,
                ),
              ),

              loading:
                  _loadingUniversities,

              onChanged:
                  (
                String value,
              ) {
                setState(() {
                  _selectedUniversity =
                      _findUniversity(
                    value,
                  );
                });
              },

              onOptionSelected:
                  (
                String value,
              ) {
                _selectUniversity(
                  value,
                );
              },
            ),

            const SizedBox(
              height:
                  13,
            ),

            _InlineHybridAcademicField(
              controller:
                  _departmentController,

              label:
                  'Dipartimento',

              icon:
                  Icons.apartment_outlined,

              options:
                  _options(
                _departments.map(
                  (
                    AcademicDepartment value,
                  ) =>
                      value.name,
                ),
              ),

              loading:
                  _loadingDepartments,

              onChanged:
                  (
                String value,
              ) {
                setState(() {
                  _selectedDepartment =
                      _findDepartment(
                    value,
                  );
                });
              },

              onOptionSelected:
                  (
                String value,
              ) {
                _selectDepartment(
                  value,
                );
              },
            ),

            const SizedBox(
              height:
                  13,
            ),

            _InlineHybridAcademicField(
              controller:
                  _courseController,

              label:
                  'Corso',

              icon:
                  Icons.school_outlined,

              options:
                  _options(
                _courses.map(
                  (
                    AcademicCourse value,
                  ) =>
                      value.name,
                ),
              ),

              loading:
                  _loadingCourses,

              onChanged:
                  (
                String value,
              ) {
                setState(() {
                  _selectedCourse =
                      _findCourse(
                    value,
                  );
                });
              },

              onOptionSelected:
                  _selectCourse,
            ),

            const SizedBox(
              height:
                  13,
            ),

            TextFormField(
              controller:
                  _graduationYearController,

              keyboardType:
                  TextInputType.number,

              validator:
                  _validateGraduationYear,

              style:
                  const TextStyle(
                color:
                    AppColors.pureWhite,
              ),

              decoration:
                  InputDecoration(
                labelText:
                    'Anno di conseguimento',

                prefixIcon:
                    const Icon(
                  Icons.calendar_month_outlined,

                  color:
                      AppColors.skyBlue,
                ),

                filled:
                    true,

                fillColor:
                    AppColors.eleganceMidnight,

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height:
                  14,
            ),

            SizedBox(
              width:
                  double.infinity,

              child:
                  ElevatedButton.icon(
                onPressed:
                    _save,

                icon:
                    const Icon(
                  Icons.save_outlined,
                ),

                label:
                    Text(
                  widget.initialTitle == null
                      ? 'Aggiungi titolo'
                      : 'Salva modifiche',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineHybridAcademicField
    extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> options;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onOptionSelected;

  const _InlineHybridAcademicField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.options,
    required this.loading,
    required this.onChanged,
    required this.onOptionSelected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller:
          controller,

      onChanged:
          onChanged,

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
          value == null ||
          value.trim().isEmpty
        ) {
          return 'Campo obbligatorio';
        }

        return null;
      },

      decoration:
          InputDecoration(
        labelText:
            label,

        helperText:
            loading
                ? 'Caricamento opzioni...'
                : options.isEmpty
                    ? 'Scrivi un nuovo nome'
                    : 'Scrivi oppure scegli tra quelli esistenti',

        helperStyle:
            TextStyle(
          color:
              AppColors.pureWhite
                  .withOpacity(
            0.35,
          ),

          fontSize:
              9,
        ),

        prefixIcon:
            Icon(
          icon,

          color:
              AppColors.skyBlue,
        ),

        suffixIcon:
            loading
                ? const Padding(
                    padding:
                        EdgeInsets.all(
                      14,
                    ),

                    child:
                        SizedBox(
                      width:
                          18,

                      height:
                          18,

                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,

                        color:
                            AppColors.materialSky,
                      ),
                    ),
                  )
                : options.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        tooltip:
                            'Scegli $label',

                        color:
                            AppColors.eleganceDeepNavy,

                        icon:
                            const Icon(
                          Icons.arrow_drop_down_rounded,

                          color:
                              AppColors.materialSky,
                        ),

                        onSelected:
                            onOptionSelected,

                        itemBuilder:
                            (
                          BuildContext context,
                        ) {
                          return options
                              .map(
                                (
                                  String option,
                                ) =>
                                    PopupMenuItem<String>(
                                  value:
                                      option,

                                  child:
                                      Text(
                                    option,

                                    style:
                                        const TextStyle(
                                      color:
                                          AppColors.pureWhite,
                                    ),
                                  ),
                                ),
                              )
                              .toList();
                        },
                      ),

        filled:
            true,

        fillColor:
            AppColors.eleganceMidnight,

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
}

class _AcademicTitleDraftCard
    extends StatelessWidget {
  final SocialAcademicPathDraft title;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AcademicTitleDraftCard({
    required this.title,
    required this.onEdit,
    required this.onDelete,
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

        border:
            Border.all(
          color:
              Colors.amber.withOpacity(
            0.18,
          ),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.workspace_premium_outlined,

            color:
                Colors.amber,

            size:
                20,
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
                  title.degreeType,

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

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  title.course,

                  style:
                      TextStyle(
                    color:
                        AppColors.materialSky
                            .withOpacity(
                      0.85,
                    ),

                    fontSize:
                        10,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  '${title.university} · ${title.department}',

                  maxLines:
                      2,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.42,
                    ),

                    fontSize:
                        9,
                  ),
                ),

                if (title.graduationYear != null) ...[
                  const SizedBox(
                    height:
                        7,
                  ),

                  _AcademicDraftBadge(
                    label:
                        'Conseguito ${title.graduationYear}',
                  ),
                ],
              ],
            ),
          ),

          IconButton(
            tooltip:
                'Modifica',

            onPressed:
                onEdit,

            icon:
                const Icon(
              Icons.edit_outlined,

              color:
                  AppColors.materialSky,

              size:
                  18,
            ),
          ),

          IconButton(
            tooltip:
                'Elimina',

            onPressed:
                onDelete,

            icon:
                const Icon(
              Icons.delete_outline_rounded,

              color:
                  Colors.redAccent,

              size:
                  18,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdditionalAcademicPathCard
    extends StatelessWidget {
  final SocialAcademicPathDraft path;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdditionalAcademicPathCard({
    required this.path,
    required this.onEdit,
    required this.onDelete,
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.school_outlined,
                color:
                    AppColors.skyBlue,
                size:
                    18,
              ),
              const SizedBox(
                width:
                    8,
              ),
              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.course,
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
                    const SizedBox(
                      height:
                          3,
                    ),
                    Text(
                      '${path.university} · ${path.department}',
                      maxLines:
                          2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          TextStyle(
                        color:
                            AppColors.pureWhite
                                .withOpacity(
                          0.42,
                        ),
                        fontSize:
                            9,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip:
                    'Modifica',
                onPressed:
                    onEdit,
                icon:
                    const Icon(
                  Icons.edit_outlined,
                  color:
                      AppColors.materialSky,
                  size:
                      18,
                ),
              ),
              IconButton(
                tooltip:
                    'Elimina',
                onPressed:
                    onDelete,
                icon:
                    const Icon(
                  Icons.delete_outline_rounded,
                  color:
                      Colors.redAccent,
                  size:
                      18,
                ),
              ),
            ],
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
            children: [
              _AcademicDraftBadge(
                label:
                    _statusLabel(
                  path.status,
                ),
              ),
              if (path.startYear != null)
                _AcademicDraftBadge(
                  label:
                      'Dal ${path.startYear}',
                ),
              if (path.graduationYear != null)
                _AcademicDraftBadge(
                  label:
                      'Conseguito ${path.graduationYear}',
                ),
              if (path.isCurrent)
                const _AcademicDraftBadge(
                  label:
                      'Corrente',
                ),
              if (path.isPrimary)
                const _AcademicDraftBadge(
                  label:
                      'Principale',
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusLabel(
    AcademicPathStatus status,
  ) {
    switch (status) {
      case AcademicPathStatus.enrolled:
        return 'In corso';
      case AcademicPathStatus.graduated:
        return 'Completato';
      case AcademicPathStatus.suspended:
        return 'Sospeso';
      case AcademicPathStatus.withdrawn:
        return 'Interrotto';
      case AcademicPathStatus.transferred:
        return 'Trasferito';
    }
  }
}

class _AcademicDraftBadge
    extends StatelessWidget {
  final String label;

  const _AcademicDraftBadge({
    required this.label,
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
            AppColors.eleganceMidnight,
        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),
      child:
          Text(
        label,
        style:
            const TextStyle(
          color:
              Colors.white60,
          fontSize:
              9,
        ),
      ),
    );
  }
}