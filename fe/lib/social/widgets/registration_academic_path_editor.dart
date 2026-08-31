import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

import '../social_models.dart';

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

  return 'Altro percorso universitario';
}

class RegistrationAcademicPathEditorPage
    extends StatefulWidget {
  final SocialAcademicPathDraft? path;

  const RegistrationAcademicPathEditorPage({
    super.key,
    this.path,
  });

  @override
  State<RegistrationAcademicPathEditorPage>
      createState() =>
          _RegistrationAcademicPathEditorPageState();
}

class _RegistrationAcademicPathEditorPageState
    extends State<RegistrationAcademicPathEditorPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final ApiService _apiService =
      ApiService();

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

  final TextEditingController
      _startYearController =
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

  AcademicUniversity?
      _selectedUniversity;

  AcademicDepartment?
      _selectedDepartment;

  AcademicCourse?
      _selectedCourse;

  String _selectedTitle =
      'Laurea triennale';

  AcademicPathStatus _status =
      AcademicPathStatus.enrolled;

  bool _manualUniversity =
      false;

  bool _manualDepartment =
      false;

  bool _manualCourse =
      false;

  bool _manualTitle =
      false;

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

  bool _saving =
      false;

  String? _catalogMessage;

  @override
  void initState() {
    super.initState();

    final SocialAcademicPathDraft? path =
        widget.path;

    if (path != null) {
      _status =
          path.status;

      _isCurrent =
          path.isCurrent;

      _isPrimary =
          path.isPrimary;

      if (path.startYear != null) {
        _startYearController.text =
            path.startYear.toString();
      }

      if (path.graduationYear != null) {
        _graduationYearController.text =
            path.graduationYear.toString();
      }

      if (
        path.degreeType.trim().isNotEmpty &&
        _academicTitleTypes.contains(
          path.degreeType,
        )
      ) {
        _selectedTitle =
            path.degreeType;
      } else if (
        path.degreeType.trim().isNotEmpty
      ) {
        _manualTitle =
            true;

        _manualTitleController.text =
            path.degreeType;
      }
    }

    _loadUniversities();
  }

  @override
  void dispose() {
    _manualUniversityController.dispose();

    _manualDepartmentController.dispose();

    _manualCourseController.dispose();

    _manualTitleController.dispose();

    _startYearController.dispose();

    _graduationYearController.dispose();

    super.dispose();
  }

  Future<void> _loadUniversities() async {
    setState(() {
      _loadingUniversities =
          true;

      _catalogMessage =
          null;
    });

    try {
      final List<AcademicUniversity> values =
          await _apiService
              .getUniversities();

      if (!mounted) {
        return;
      }

      if (values.isEmpty) {
        _activateManualUniversity(
          'Il catalogo degli atenei non contiene voci disponibili. Puoi continuare inserendo i dati manualmente.',
        );

        return;
      }

      AcademicUniversity? selected;

      final SocialAcademicPathDraft? path =
          widget.path;

      if (
        path != null &&
        path.universityCode.trim().isNotEmpty
      ) {
        for (
          final AcademicUniversity value
          in values
        ) {
          if (
            _same(
              value.code,
              path.universityCode,
            )
          ) {
            selected =
                value;

            break;
          }
        }
      }

      if (
        path != null &&
        selected == null &&
        path.university.trim().isNotEmpty
      ) {
        _universities =
            values;

        _manualUniversity =
            true;

        _manualUniversityController.text =
            path.university;

        _manualDepartment =
            true;

        _manualDepartmentController.text =
            path.department;

        _manualCourse =
            true;

        _manualCourseController.text =
            path.course;

        setState(() {
          _catalogMessage =
              'Alcuni dati salvati non sono più presenti nel catalogo. Puoi continuare usando i valori manuali.';
        });

        return;
      }

      selected ??=
          values.first;

      setState(() {
        _universities =
            values;

        _selectedUniversity =
            selected;
      });

      await _loadDepartments(
        selected,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _activateManualUniversity(
        'Il catalogo degli atenei non è disponibile. Puoi continuare inserendo i dati manualmente.',
      );
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
    AcademicUniversity university,
  ) async {
    if (_manualUniversity) {
      return;
    }

    setState(() {
      _loadingDepartments =
          true;

      _departments =
          [];

      _selectedDepartment =
          null;

      _courses =
          [];

      _selectedCourse =
          null;
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

      if (values.isEmpty) {
        _activateManualDepartment(
          'Il catalogo dei dipartimenti non contiene voci disponibili. Puoi continuare manualmente.',
        );

        return;
      }

      AcademicDepartment? selected;

      final SocialAcademicPathDraft? path =
          widget.path;

      if (
        path != null &&
        path.departmentCode.trim().isNotEmpty
      ) {
        for (
          final AcademicDepartment value
          in values
        ) {
          if (
            _same(
              value.code,
              path.departmentCode,
            )
          ) {
            selected =
                value;

            break;
          }
        }
      }

      if (
        path != null &&
        selected == null &&
        path.department.trim().isNotEmpty
      ) {
        setState(() {
          _departments =
              values;

          _manualDepartment =
              true;

          _manualDepartmentController.text =
              path.department;

          _manualCourse =
              true;

          _manualCourseController.text =
              path.course;

          _catalogMessage =
              'Il dipartimento salvato non è più presente nel catalogo. Puoi continuare manualmente.';
        });

        return;
      }

      selected ??=
          values.first;

      setState(() {
        _departments =
            values;

        _selectedDepartment =
            selected;
      });

      await _loadCourses(
        university:
            university,

        department:
            selected,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _activateManualDepartment(
        'Il catalogo dei dipartimenti non è disponibile. Puoi continuare manualmente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingDepartments =
              false;
        });
      }
    }
  }

  Future<void> _loadCourses({
    required AcademicUniversity university,
    required AcademicDepartment department,
  }) async {
    if (
      _manualUniversity ||
      _manualDepartment
    ) {
      return;
    }

    setState(() {
      _loadingCourses =
          true;

      _courses =
          [];

      _selectedCourse =
          null;
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

      if (values.isEmpty) {
        _activateManualCourse(
          'Il catalogo dei corsi non contiene voci disponibili. Puoi continuare manualmente.',
        );

        return;
      }

      AcademicCourse? selected;

      final SocialAcademicPathDraft? path =
          widget.path;

      if (
        path != null &&
        path.courseCode.trim().isNotEmpty
      ) {
        for (
          final AcademicCourse value
          in values
        ) {
          if (
            _same(
              value.code,
              path.courseCode,
            )
          ) {
            selected =
                value;

            break;
          }
        }
      }

      if (
        path != null &&
        selected == null &&
        path.course.trim().isNotEmpty
      ) {
        setState(() {
          _courses =
              values;

          _manualCourse =
              true;

          _manualCourseController.text =
              path.course;

          _catalogMessage =
              'Il corso salvato non è più presente nel catalogo. Puoi continuare manualmente.';
        });

        return;
      }

      final AcademicCourse resolvedCourse =
          selected ??
          values.first;

      setState(() {
        _courses =
            values;

        _selectedCourse =
            resolvedCourse;

        if (!_manualTitle) {
          _selectedTitle =
              _titleTypeFromDegreeType(
            resolvedCourse.degreeType,
          );
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _activateManualCourse(
        'Il catalogo dei corsi non è disponibile. Puoi continuare manualmente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingCourses =
              false;
        });
      }
    }
  }

  void _activateManualUniversity(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    final SocialAcademicPathDraft? path =
        widget.path;

    setState(() {
      _manualUniversity =
          true;

      _manualDepartment =
          true;

      _manualCourse =
          true;

      if (path != null) {
        _manualUniversityController.text =
            path.university;

        _manualDepartmentController.text =
            path.department;

        _manualCourseController.text =
            path.course;
      }

      _catalogMessage =
          message;
    });
  }

  void _activateManualDepartment(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    final SocialAcademicPathDraft? path =
        widget.path;

    setState(() {
      _manualDepartment =
          true;

      _manualCourse =
          true;

      if (path != null) {
        _manualDepartmentController.text =
            path.department;

        _manualCourseController.text =
            path.course;
      }

      _catalogMessage =
          message;
    });
  }

  void _activateManualCourse(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    final SocialAcademicPathDraft? path =
        widget.path;

    setState(() {
      _manualCourse =
          true;

      if (path != null) {
        _manualCourseController.text =
            path.course;
      }

      _catalogMessage =
          message;
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (
      !_formKey.currentState!
          .validate()
    ) {
      return;
    }

    final String university =
        _manualUniversity
            ? _manualUniversityController.text
                .trim()
            : _selectedUniversity?.name.trim() ??
                '';

    final String universityCode =
        _manualUniversity
            ? ''
            : _selectedUniversity?.code.trim() ??
                '';

    final String department =
        _manualDepartment
            ? _manualDepartmentController.text
                .trim()
            : _selectedDepartment?.name.trim() ??
                '';

    final String departmentCode =
        _manualDepartment
            ? ''
            : _selectedDepartment?.code.trim() ??
                '';

    final String course =
        _manualCourse
            ? _manualCourseController.text
                .trim()
            : _selectedCourse?.name.trim() ??
                '';

    final String courseCode =
        _manualCourse
            ? ''
            : _selectedCourse?.code.trim() ??
                '';

    final String degreeType =
        _manualTitle
            ? _manualTitleController.text
                .trim()
            : _selectedTitle.trim();

    if (
      university.isEmpty ||
      department.isEmpty ||
      course.isEmpty ||
      degreeType.isEmpty
    ) {
      return;
    }

    final int? startYear =
        _startYearController.text
                .trim()
                .isEmpty
            ? null
            : int.tryParse(
                _startYearController.text
                    .trim(),
              );

    final int? graduationYear =
        _status ==
                AcademicPathStatus
                    .graduated
            ? int.tryParse(
                _graduationYearController.text
                    .trim(),
              )
            : null;

    setState(() {
      _saving =
          true;
    });

    final SocialAcademicPathDraft result =
        SocialAcademicPathDraft(
      university:
          university,

      universityCode:
          universityCode,

      department:
          department,

      departmentCode:
          departmentCode,

      course:
          course,

      courseCode:
          courseCode,

      degreeType:
          degreeType,

      status:
          _status,

      startYear:
          startYear,

      graduationYear:
          graduationYear,

      isCurrent:
          _status ==
                  AcademicPathStatus.enrolled
              ? _isCurrent
              : false,

      isPrimary:
          _isPrimary,
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(
      context,
      result,
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

  String? _validateGraduationYear(
    String? value,
  ) {
    if (
      _status !=
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

    final int currentYear =
        DateTime.now().year;

    if (
      year == null ||
      year < 1900 ||
      year > currentYear
    ) {
      return 'Anno di conseguimento non valido';
    }

    final int? startYear =
        int.tryParse(
      _startYearController.text
          .trim(),
    );

    if (
      startYear != null &&
      year < startYear
    ) {
      return 'L\'anno di conseguimento non può precedere l\'anno di inizio';
    }

    return null;
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
          widget.path == null
              ? 'Aggiungi percorso'
              : 'Modifica percorso',
        ),
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
                  650,
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
                  if (_catalogMessage != null)
                    _CatalogInfo(
                      message:
                          _catalogMessage!,
                    ),

                  if (_catalogMessage != null)
                    const SizedBox(
                      height:
                          16,
                    ),

                  _HybridFieldHeader(
                    title:
                        'Ateneo',

                    manual:
                        _manualUniversity,

                    canUseCatalog:
                        _universities.isNotEmpty,

                    onToggle:
                        _loadingUniversities
                            ? null
                            : () async {
                                final bool manual =
                                    !_manualUniversity;

                                setState(() {
                                  _manualUniversity =
                                      manual;

                                  if (manual) {
                                    _manualDepartment =
                                        true;

                                    _manualCourse =
                                        true;
                                  } else {
                                    _manualDepartment =
                                        false;

                                    _manualCourse =
                                        false;
                                  }
                                });

                                if (!manual) {
                                  await _loadUniversities();
                                }
                              },
                  ),

                  if (_loadingUniversities)
                    const LinearProgressIndicator()
                  else if (_manualUniversity)
                    TextFormField(
                      controller:
                          _manualUniversityController,

                      validator:
                          _required,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,
                      ),

                      decoration:
                          _decoration(
                        label:
                            'Ateneo',

                        hint:
                            'Inserisci manualmente',

                        icon:
                            Icons.account_balance_outlined,
                      ),
                    )
                  else
                    DropdownButtonFormField<
                        AcademicUniversity>(
                      value:
                          _selectedUniversity,

                      isExpanded:
                          true,

                      dropdownColor:
                          AppColors.eleganceDeepNavy,

                      decoration:
                          _decoration(
                        label:
                            'Ateneo',

                        hint:
                            'Seleziona dal catalogo',

                        icon:
                            Icons.account_balance_outlined,
                      ),

                      validator:
                          (
                        AcademicUniversity?
                            value,
                      ) =>
                              value == null
                                  ? 'Seleziona un ateneo'
                                  : null,

                      items:
                          _universities
                              .map(
                        (
                          AcademicUniversity value,
                        ) =>
                            DropdownMenuItem<
                                AcademicUniversity>(
                          value:
                              value,

                          child:
                              Text(
                            value.name,

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
                          (
                        AcademicUniversity?
                            value,
                      ) async {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _selectedUniversity =
                              value;

                          _manualDepartment =
                              false;

                          _manualCourse =
                              false;
                        });

                        await _loadDepartments(
                          value,
                        );
                      },
                    ),

                  const SizedBox(
                    height:
                        18,
                  ),

                  _HybridFieldHeader(
                    title:
                        'Dipartimento',

                    manual:
                        _manualDepartment,

                    canUseCatalog:
                        !_manualUniversity &&
                        _departments.isNotEmpty,

                    onToggle:
                        _manualUniversity ||
                                _loadingDepartments
                            ? null
                            : () async {
                                final bool manual =
                                    !_manualDepartment;

                                setState(() {
                                  _manualDepartment =
                                      manual;

                                  if (manual) {
                                    _manualCourse =
                                        true;
                                  } else {
                                    _manualCourse =
                                        false;
                                  }
                                });

                                if (
                                  !manual &&
                                  _selectedUniversity != null
                                ) {
                                  await _loadDepartments(
                                    _selectedUniversity!,
                                  );
                                }
                              },
                  ),

                  if (_loadingDepartments)
                    const LinearProgressIndicator()
                  else if (_manualDepartment)
                    TextFormField(
                      controller:
                          _manualDepartmentController,

                      validator:
                          _required,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,
                      ),

                      decoration:
                          _decoration(
                        label:
                            'Dipartimento',

                        hint:
                            'Inserisci manualmente',

                        icon:
                            Icons.business_outlined,
                      ),
                    )
                  else
                    DropdownButtonFormField<
                        AcademicDepartment>(
                      value:
                          _selectedDepartment,

                      isExpanded:
                          true,

                      dropdownColor:
                          AppColors.eleganceDeepNavy,

                      decoration:
                          _decoration(
                        label:
                            'Dipartimento',

                        hint:
                            'Seleziona dal catalogo',

                        icon:
                            Icons.business_outlined,
                      ),

                      validator:
                          (
                        AcademicDepartment?
                            value,
                      ) =>
                              value == null
                                  ? 'Seleziona un dipartimento'
                                  : null,

                      items:
                          _departments
                              .map(
                        (
                          AcademicDepartment value,
                        ) =>
                            DropdownMenuItem<
                                AcademicDepartment>(
                          value:
                              value,

                          child:
                              Text(
                            value.name,

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
                          (
                        AcademicDepartment?
                            value,
                      ) async {
                        if (
                          value == null ||
                          _selectedUniversity == null
                        ) {
                          return;
                        }

                        setState(() {
                          _selectedDepartment =
                              value;

                          _manualCourse =
                              false;
                        });

                        await _loadCourses(
                          university:
                              _selectedUniversity!,

                          department:
                              value,
                        );
                      },
                    ),

                  const SizedBox(
                    height:
                        18,
                  ),

                  _HybridFieldHeader(
                    title:
                        'Corso / percorso',

                    manual:
                        _manualCourse,

                    canUseCatalog:
                        !_manualUniversity &&
                        !_manualDepartment &&
                        _courses.isNotEmpty,

                    onToggle:
                        _manualUniversity ||
                                _manualDepartment ||
                                _loadingCourses
                            ? null
                            : () async {
                                final bool manual =
                                    !_manualCourse;

                                setState(() {
                                  _manualCourse =
                                      manual;
                                });

                                if (
                                  !manual &&
                                  _selectedUniversity != null &&
                                  _selectedDepartment != null
                                ) {
                                  await _loadCourses(
                                    university:
                                        _selectedUniversity!,

                                    department:
                                        _selectedDepartment!,
                                  );
                                }
                              },
                  ),

                  if (_loadingCourses)
                    const LinearProgressIndicator()
                  else if (_manualCourse)
                    TextFormField(
                      controller:
                          _manualCourseController,

                      validator:
                          _required,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,
                      ),

                      decoration:
                          _decoration(
                        label:
                            'Corso / percorso',

                        hint:
                            'Inserisci manualmente',

                        icon:
                            Icons.school_outlined,
                      ),
                    )
                  else
                    DropdownButtonFormField<
                        AcademicCourse>(
                      value:
                          _selectedCourse,

                      isExpanded:
                          true,

                      dropdownColor:
                          AppColors.eleganceDeepNavy,

                      decoration:
                          _decoration(
                        label:
                            'Corso / percorso',

                        hint:
                            'Seleziona dal catalogo',

                        icon:
                            Icons.school_outlined,
                      ),

                      validator:
                          (
                        AcademicCourse?
                            value,
                      ) =>
                              value == null
                                  ? 'Seleziona un corso'
                                  : null,

                      items:
                          _courses
                              .map(
                        (
                          AcademicCourse value,
                        ) =>
                            DropdownMenuItem<
                                AcademicCourse>(
                          value:
                              value,

                          child:
                              Text(
                            value.name,

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
                          (
                        AcademicCourse?
                            value,
                      ) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _selectedCourse =
                              value;

                          if (!_manualTitle) {
                            _selectedTitle =
                                _titleTypeFromDegreeType(
                              value.degreeType,
                            );
                          }
                        });
                      },
                    ),

                  const SizedBox(
                    height:
                        18,
                  ),

                  _HybridFieldHeader(
                    title:
                        'Titolo',

                    manual:
                        _manualTitle,

                    canUseCatalog:
                        true,

                    onToggle:
                        () {
                      setState(() {
                        _manualTitle =
                            !_manualTitle;
                      });
                    },
                  ),

                  if (_manualTitle)
                    TextFormField(
                      controller:
                          _manualTitleController,

                      validator:
                          _required,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,
                      ),

                      decoration:
                          _decoration(
                        label:
                            'Titolo',

                        hint:
                            'Inserisci manualmente',

                        icon:
                            Icons.workspace_premium_outlined,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value:
                          _selectedTitle,

                      isExpanded:
                          true,

                      dropdownColor:
                          AppColors.eleganceDeepNavy,

                      decoration:
                          _decoration(
                        label:
                            'Titolo',

                        hint:
                            'Seleziona il tipo di titolo',

                        icon:
                            Icons.workspace_premium_outlined,
                      ),

                      items:
                          _academicTitleTypes
                              .map(
                        (
                          String value,
                        ) =>
                            DropdownMenuItem<String>(
                          value:
                              value,

                          child:
                              Text(
                            value,

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
                          (
                        String? value,
                      ) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _selectedTitle =
                              value;
                        });
                      },
                    ),

                  const SizedBox(
                    height:
                        18,
                  ),

                  DropdownButtonFormField<
                      AcademicPathStatus>(
                    value:
                        _status,

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
                            AcademicPathStatus.graduated,

                        child:
                            Text(
                          'Completato / titolo conseguito',

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
                      AcademicPathStatus?
                          value,
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

                        if (
                          value !=
                              AcademicPathStatus.graduated
                        ) {
                          _graduationYearController.clear();
                        }
                      });
                    },
                  ),

                  const SizedBox(
                    height:
                        16,
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
                        _decoration(
                      label:
                          'Anno di inizio',

                      hint:
                          'Facoltativo',

                      icon:
                          Icons.calendar_month_outlined,
                    ),
                  ),

                  if (
                    _status ==
                        AcademicPathStatus.graduated
                  ) ...[
                    const SizedBox(
                      height:
                          16,
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
                          _decoration(
                        label:
                            'Anno di conseguimento',

                        hint:
                            'Es. 2026',

                        icon:
                            Icons.workspace_premium_outlined,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height:
                        16,
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
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  Container(
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
                      'Il percorso e il titolo vengono salvati come dichiarazioni dell’utente e devono essere verificati prima di essere considerati verificati.',

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
                        24,
                  ),

                  SizedBox(
                    height:
                        52,

                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _saving
                              ? null
                              : _save,

                      icon:
                          const Icon(
                        Icons.save_outlined,
                      ),

                      label:
                          Text(
                        widget.path == null
                            ? 'Aggiungi percorso'
                            : 'Salva modifiche',
                      ),

                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.socialBlue,

                        foregroundColor:
                            AppColors.pureWhite,
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
          AppColors.eleganceMidnight,

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            BorderSide(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.08,
          ),
        ),
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
}

class _HybridFieldHeader
    extends StatelessWidget {
  final String title;

  final bool manual;

  final bool canUseCatalog;

  final VoidCallback? onToggle;

  const _HybridFieldHeader({
    required this.title,
    required this.manual,
    required this.canUseCatalog,
    required this.onToggle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom:
            7,
      ),

      child:
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
                    11,

                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          TextButton.icon(
            onPressed:
                onToggle,

            icon:
                Icon(
              manual
                  ? Icons.list_alt_outlined
                  : Icons.edit_outlined,

              size:
                  16,
            ),

            label:
                Text(
              manual
                  ? canUseCatalog
                      ? 'Usa catalogo'
                      : 'Manuale'
                  : 'Inserisci manualmente',
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogInfo
    extends StatelessWidget {
  final String message;

  const _CatalogInfo({
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        13,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.skyBlue
                .withOpacity(
          0.06,
        ),

        borderRadius:
            BorderRadius.circular(
          12,
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
          const Icon(
            Icons.info_outline_rounded,

            color:
                AppColors.materialSky,

            size:
                18,
          ),

          const SizedBox(
            width:
                8,
          ),

          Expanded(
            child:
                Text(
              message,

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
        ],
      ),
    );
  }
}