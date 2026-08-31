import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';

import '../social_models.dart';


class TeacherAssignmentsPage
    extends StatefulWidget {
  const TeacherAssignmentsPage({
    super.key,
  });

  @override
  State<TeacherAssignmentsPage>
      createState() =>
          _TeacherAssignmentsPageState();
}


class _TeacherAssignmentsPageState
    extends State<TeacherAssignmentsPage> {
  final ApiService _apiService =
      ApiService();

  final AuthSession _authSession =
      AuthSession.instance;

  List<TeacherAssignment>
      _assignments =
      [];

  bool _loading =
      true;

  bool _processing =
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
      final List<TeacherAssignment>
          assignments =
          await _apiService
              .getMyTeacherAssignments();

      if (!mounted) {
        return;
      }

      setState(() {
        _assignments =
            assignments;

        _loading =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _error =
            _cleanError(
          e,
        );
      });
    }
  }


  Future<void> _refreshUser() async {
    final SocialUser user =
        await _apiService
            .getCurrentUser();

    _authSession.updateUser(
      user,
    );
  }


  Future<void> _addAssignment() async {
    final bool? changed =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                const TeacherAssignmentEditorPage(),
      ),
    );

    if (
      changed == true &&
      mounted
    ) {
      await _load();
      await _refreshUser();
    }
  }


  Future<void> _editAssignment(
    TeacherAssignment assignment,
  ) async {
    final bool? changed =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                TeacherAssignmentEditorPage(
          assignment:
              assignment,
        ),
      ),
    );

    if (
      changed == true &&
      mounted
    ) {
      await _load();
      await _refreshUser();
    }
  }


  Future<void> _deleteAssignment(
    TeacherAssignment assignment,
  ) async {
    if (_processing) {
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
            'Elimina insegnamento',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              Text(
            'Vuoi eliminare "${assignment.subject.name}" dai tuoi insegnamenti?',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite
                      .withOpacity(
                0.70,
              ),
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
                'Elimina',

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

    setState(() {
      _processing =
          true;
    });

    try {
      await _apiService
          .deleteTeacherAssignment(
        assignment.id,
      );

      await _load();
      await _refreshUser();

      if (!mounted) {
        return;
      }

      _showMessage(
        'Insegnamento eliminato.',
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
          _processing =
              false;
        });
      }
    }
  }


  String _cleanError(
    Object error,
  ) {
    final String message =
        error
            .toString()
            .toLowerCase();

    if (
      message.contains(
            '401',
          ) ||
          message.contains(
            'unauthorized',
          )
    ) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (
      message.contains(
            '403',
          ) ||
          message.contains(
            'forbidden',
          )
    ) {
      return 'Non hai i permessi necessari per gestire gli insegnamenti.';
    }

    if (
      message.contains(
            '404',
          ) ||
          message.contains(
            'not found',
          )
    ) {
      return 'L’insegnamento richiesto non è più disponibile. Aggiorna la pagina e riprova.';
    }

    if (
      message.contains(
            '409',
          ) ||
          message.contains(
            'conflict',
          ) ||
          message.contains(
            'already',
          )
    ) {
      return 'Questa modifica è in conflitto con un insegnamento già presente.';
    }

    if (
      message.contains(
            '422',
          ) ||
          message.contains(
            'validation',
          ) ||
          message.contains(
            'invalid',
          )
    ) {
      return 'Alcuni dati dell’insegnamento non sono validi. Controllali e riprova.';
    }

    if (
      message.contains(
            'network',
          ) ||
          message.contains(
            'socket',
          ) ||
          message.contains(
            'connection',
          ) ||
          message.contains(
            'timeout',
          ) ||
          message.contains(
            'host lookup',
          )
    ) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    if (
      message.contains(
            '500',
          ) ||
          message.contains(
            '502',
          ) ||
          message.contains(
            '503',
          )
    ) {
      return 'StudentLab non è temporaneamente disponibile. Riprova tra qualche momento.';
    }

    return 'Non è stato possibile completare l’operazione sull’insegnamento. Riprova.';
  }


  void _showMessage(
    String message,
  ) {
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
          'I miei insegnamenti',
        ),

        actions: [
          IconButton(
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
          _loading
              ? null
              : FloatingActionButton.extended(
                  onPressed:
                      _processing
                          ? null
                          : _addAssignment,

                  backgroundColor:
                      AppColors.teacherIndigo,

                  foregroundColor:
                      AppColors.pureWhite,

                  icon:
                      const Icon(
                    Icons.add_rounded,
                  ),

                  label:
                      const Text(
                    'Aggiungi insegnamento',
                  ),
                ),

      body:
          SafeArea(
        child:
            _buildBody(),
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
              const Icon(
                Icons
                    .error_outline_rounded,

                color:
                    Colors.redAccent,

                size:
                    42,
              ),

              const SizedBox(
                height:
                    14,
              ),

              Text(
                _error!,

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withOpacity(
                    0.70,
                  ),
                ),
              ),

              const SizedBox(
                height:
                    16,
              ),

              OutlinedButton.icon(
                onPressed:
                    _load,

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
      );
    }

    return Center(
      child:
          LayoutBuilder(
        builder:
            (
          context,
          constraints,
        ) {
          final double width =
              constraints.maxWidth >
                      750
                  ? 700
                  : constraints
                      .maxWidth;

          return SizedBox(
            width:
                width,

            child:
                RefreshIndicator(
              onRefresh:
                  _load,

              child:
                  ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  110,
                ),

                children: [
                  const Text(
                    'Insegnamenti',

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite,

                      fontSize:
                          23,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                        7,
                  ),

                  Text(
                    'Qui puoi indicare le materie che insegni e, quando disponibile, il modulo o il canale specifico. Ogni nuovo insegnamento viene sottoposto a verifica.',

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withOpacity(
                        0.55,
                      ),

                      fontSize:
                          13,

                      height:
                          1.4,
                    ),
                  ),

                  const SizedBox(
                    height:
                        22,
                  ),

                  if (_assignments.isEmpty)
                    _EmptyAssignments(
                      onAdd:
                          _addAssignment,
                    )
                  else
                    ..._assignments.map(
                      (
                        TeacherAssignment
                            assignment,
                      ) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom:
                                14,
                          ),

                          child:
                              _AssignmentCard(
                            assignment:
                                assignment,

                            processing:
                                _processing,

                            onEdit:
                                () =>
                                    _editAssignment(
                              assignment,
                            ),

                            onDelete:
                                () =>
                                    _deleteAssignment(
                              assignment,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


class _AssignmentCard
    extends StatelessWidget {
  final TeacherAssignment assignment;

  final bool processing;

  final VoidCallback onEdit;

  final VoidCallback onDelete;


  const _AssignmentCard({
    required this.assignment,
    required this.processing,
    required this.onEdit,
    required this.onDelete,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final SubjectOffering? offering =
        assignment.offering;

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
            AppColors.eleganceDeepNavy,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              _verificationColor()
                  .withOpacity(
            0.25,
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
                    42,

                height:
                    42,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .teacherIndigo
                          .withOpacity(
                    0.13,
                  ),

                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .cast_for_education_outlined,

                  color:
                      AppColors.skyBlue,
                ),
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
                      assignment.subject.name,

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

                    if (
                      assignment.subject
                          .course
                          .trim()
                          .isNotEmpty
                    ) ...[
                      const SizedBox(
                        height:
                            4,
                      ),

                      Text(
                        assignment.subject.course,

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.42,
                          ),

                          fontSize:
                              10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              PopupMenuButton<String>(
                enabled:
                    !processing,

                color:
                    AppColors.eleganceDeepNavy,

                icon:
                    const Icon(
                  Icons.more_vert,

                  color:
                      AppColors.pureWhite,
                ),

                onSelected:
                    (
                  String value,
                ) {
                  switch (value) {
                    case 'edit':
                      onEdit();

                      break;

                    case 'delete':
                      onDelete();

                      break;
                  }
                },

                itemBuilder:
                    (
                  BuildContext context,
                ) =>
                        const [
                  PopupMenuItem(
                    value:
                        'edit',

                    child:
                        _MenuItem(
                      icon:
                          Icons.edit_outlined,

                      label:
                          'Modifica',
                    ),
                  ),

                  PopupMenuItem(
                    value:
                        'delete',

                    child:
                        _MenuItem(
                      icon:
                          Icons.delete_outline,

                      label:
                          'Elimina',

                      danger:
                          true,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(
            height:
                14,
          ),

          Wrap(
            spacing:
                7,

            runSpacing:
                7,

            children: [
              _VerificationBadge(
                assignment:
                    assignment,
              ),

              _SimpleBadge(
                label:
                    assignment.isCurrent
                        ? 'ATTUALE'
                        : 'PASSATO',

                icon:
                    assignment.isCurrent
                        ? Icons
                            .check_circle_outline_rounded
                        : Icons
                            .history_rounded,
              ),
            ],
          ),

          if (offering != null) ...[
            const SizedBox(
              height:
                  14,
            ),

            _OfferingInfo(
              offering:
                  offering,
            ),
          ],

          if (
            offering == null
          ) ...[
            const SizedBox(
              height:
                  14,
            ),

            Text(
              'Assegnazione relativa all\'intera materia.',

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
          ],
        ],
      ),
    );
  }


  Color _verificationColor() {
    if (assignment.isVerified) {
      return Colors.greenAccent;
    }

    if (assignment.isRejected) {
      return Colors.redAccent;
    }

    return Colors.amber;
  }
}


class TeacherAssignmentEditorPage
    extends StatefulWidget {
  final TeacherAssignment? assignment;


  const TeacherAssignmentEditorPage({
    super.key,
    this.assignment,
  });


  @override
  State<TeacherAssignmentEditorPage>
      createState() =>
          _TeacherAssignmentEditorPageState();
}


class _TeacherAssignmentEditorPageState
    extends State<TeacherAssignmentEditorPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final ApiService _apiService =
      ApiService();


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
      _subjects =
      [];


  AcademicUniversity?
      _selectedUniversity;

  AcademicDepartment?
      _selectedDepartment;

  AcademicCourse?
      _selectedCourse;

  SocialSubject?
      _selectedSubject;

  SubjectOffering?
      _selectedOffering;


  bool _isCurrent =
      true;

  bool _loading =
      true;

  bool _loadingSubjects =
      false;

  bool _saving =
      false;

  String? _error;


  bool get _editing {
    return widget.assignment !=
        null;
  }


  @override
  void initState() {
    super.initState();

    final TeacherAssignment?
        assignment =
        widget.assignment;

    if (assignment != null) {
      _isCurrent =
          assignment.isCurrent;
    }

    _loadCatalog();
  }


  Future<void> _loadCatalog() async {
    setState(() {
      _loading =
          true;

      _error =
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

      AcademicUniversity?
          selectedUniversity;

      final TeacherAssignment?
          assignment =
          widget.assignment;

      if (assignment != null) {
        for (
          final AcademicUniversity university
          in universities
        ) {
          if (
            university.code ==
                assignment.subject
                    .universityCode
          ) {
            selectedUniversity =
                university;

            break;
          }
        }
      }

      if (
        selectedUniversity == null &&
        universities.isNotEmpty
      ) {
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
      }

      setState(() {
        _universities =
            universities;

        _selectedUniversity =
            selectedUniversity;
      });

      if (
        selectedUniversity !=
            null
      ) {
        await _loadDepartments(
          selectedUniversity.code,

          initialDepartmentCode:
              assignment?.subject
                  .departmentCode,

          initialCourseCode:
              assignment?.subject
                  .courseCode,

          initialSubjectId:
              assignment?.subjectId,

          initialOfferingId:
              assignment?.offeringId,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _error =
            _cleanError(
          e,
        );
      });
    }
  }


  Future<void> _loadDepartments(
    String universityCode, {
    String? initialDepartmentCode,
    String? initialCourseCode,
    int? initialSubjectId,
    int? initialOfferingId,
  }) async {
    setState(() {
      _departments =
          [];

      _courses =
          [];

      _subjects =
          [];

      _selectedDepartment =
          null;

      _selectedCourse =
          null;

      _selectedSubject =
          null;

      _selectedOffering =
          null;
    });

    final List<AcademicDepartment>
        departments =
        await _apiService
            .getDepartments(
      universityCode,
    );

    if (!mounted) {
      return;
    }

    AcademicDepartment?
        selectedDepartment;

    if (
      initialDepartmentCode !=
          null
    ) {
      for (
        final AcademicDepartment department
        in departments
      ) {
        if (
          department.code ==
              initialDepartmentCode
        ) {
          selectedDepartment =
              department;

          break;
        }
      }
    }

    if (
      selectedDepartment == null &&
      departments.isNotEmpty
    ) {
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

      selectedDepartment ??=
          departments.first;
    }

    setState(() {
      _departments =
          departments;

      _selectedDepartment =
          selectedDepartment;
    });

    if (
      selectedDepartment != null
    ) {
      await _loadCourses(
        universityCode:
            universityCode,

        departmentCode:
            selectedDepartment.code,

        initialCourseCode:
            initialCourseCode,

        initialSubjectId:
            initialSubjectId,

        initialOfferingId:
            initialOfferingId,
      );
    }
  }


  Future<void> _loadCourses({
    required String universityCode,
    required String departmentCode,
    String? initialCourseCode,
    int? initialSubjectId,
    int? initialOfferingId,
  }) async {
    setState(() {
      _courses =
          [];

      _subjects =
          [];

      _selectedCourse =
          null;

      _selectedSubject =
          null;

      _selectedOffering =
          null;
    });

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

    AcademicCourse?
        selectedCourse;

    if (initialCourseCode != null) {
      for (
        final AcademicCourse course
        in courses
      ) {
        if (
          course.code ==
              initialCourseCode
        ) {
          selectedCourse =
              course;

          break;
        }
      }
    }

    selectedCourse ??=
        courses.isEmpty
            ? null
            : courses.first;

    setState(() {
      _courses =
          courses;

      _selectedCourse =
          selectedCourse;
    });

    if (selectedCourse != null) {
      await _loadSubjects(
        initialSubjectId:
            initialSubjectId,

        initialOfferingId:
            initialOfferingId,
      );
    }
  }


  Future<void> _loadSubjects({
    int? initialSubjectId,
    int? initialOfferingId,
  }) async {
    final AcademicUniversity?
        university =
        _selectedUniversity;

    final AcademicDepartment?
        department =
        _selectedDepartment;

    final AcademicCourse?
        course =
        _selectedCourse;

    if (
      university == null ||
      department == null ||
      course == null
    ) {
      return;
    }

    setState(() {
      _loadingSubjects =
          true;

      _subjects =
          [];

      _selectedSubject =
          null;

      _selectedOffering =
          null;
    });

    try {
      final List<SocialSubject>
          subjects =
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

      SocialSubject?
          selectedSubject;

      if (initialSubjectId != null) {
        for (
          final SocialSubject subject
          in subjects
        ) {
          if (
            subject.id ==
                initialSubjectId
          ) {
            selectedSubject =
                subject;

            break;
          }
        }
      }

      SubjectOffering?
          selectedOffering;

      if (
        selectedSubject != null &&
        initialOfferingId != null
      ) {
        for (
          final SubjectOffering offering
          in selectedSubject.offerings
        ) {
          if (
            offering.id ==
                initialOfferingId
          ) {
            selectedOffering =
                offering;

            break;
          }
        }
      }

      setState(() {
        _subjects =
            subjects;

        _selectedSubject =
            selectedSubject;

        _selectedOffering =
            selectedOffering;

        _loadingSubjects =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSubjects =
            false;

        _error =
            _cleanError(
          e,
        );
      });
    }
  }


  Future<void> _save() async {
    if (
      !_formKey.currentState!
          .validate()
    ) {
      return;
    }

    final SocialSubject? subject =
        _selectedSubject;

    if (subject == null) {
      _showMessage(
        'Seleziona una materia.',
      );

      return;
    }

    setState(() {
      _saving =
          true;

      _error =
          null;
    });

    try {
      if (_editing) {
        final TeacherAssignment
            assignment =
            widget.assignment!;

        final bool clearOffering =
            assignment.offeringId !=
                    null &&
                _selectedOffering ==
                    null;

        await _apiService
            .updateTeacherAssignment(
          assignmentId:
              assignment.id,

          subjectId:
              subject.id,

          offeringId:
              _selectedOffering?.id,

          clearOffering:
              clearOffering,

          isCurrent:
              _isCurrent,
        );
      } else {
        await _apiService
            .createTeacherAssignment(
          subjectId:
              subject.id,

          offeringId:
              _selectedOffering?.id,

          isCurrent:
              _isCurrent,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
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
      if (mounted) {
        setState(() {
          _saving =
              false;
        });
      }
    }
  }


  String _cleanError(
    Object error,
  ) {
    final String message =
        error
            .toString()
            .toLowerCase();

    if (
      message.contains(
            '401',
          ) ||
          message.contains(
            'unauthorized',
          )
    ) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (
      message.contains(
            '403',
          ) ||
          message.contains(
            'forbidden',
          )
    ) {
      return 'Non hai i permessi necessari per gestire gli insegnamenti.';
    }

    if (
      message.contains(
            '404',
          ) ||
          message.contains(
            'not found',
          )
    ) {
      return 'L’insegnamento richiesto non è più disponibile. Aggiorna la pagina e riprova.';
    }

    if (
      message.contains(
            '409',
          ) ||
          message.contains(
            'conflict',
          ) ||
          message.contains(
            'already',
          )
    ) {
      return 'Questa modifica è in conflitto con un insegnamento già presente.';
    }

    if (
      message.contains(
            '422',
          ) ||
          message.contains(
            'validation',
          ) ||
          message.contains(
            'invalid',
          )
    ) {
      return 'Alcuni dati dell’insegnamento non sono validi. Controllali e riprova.';
    }

    if (
      message.contains(
            'network',
          ) ||
          message.contains(
            'socket',
          ) ||
          message.contains(
            'connection',
          ) ||
          message.contains(
            'timeout',
          ) ||
          message.contains(
            'host lookup',
          )
    ) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    if (
      message.contains(
            '500',
          ) ||
          message.contains(
            '502',
          ) ||
          message.contains(
            '503',
          )
    ) {
      return 'StudentLab non è temporaneamente disponibile. Riprova tra qualche momento.';
    }

    return 'Non è stato possibile completare l’operazione sull’insegnamento. Riprova.';
  }


  void _showMessage(
    String message,
  ) {
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


  String _offeringLabel(
    SubjectOffering offering,
  ) {
    final List<String> parts =
        [];

    if (
      offering.module
          .trim()
          .isNotEmpty
    ) {
      parts.add(
        offering.module.trim(),
      );
    }

    if (
      offering.channel
          .trim()
          .isNotEmpty
    ) {
      parts.add(
        'Canale ${offering.channel.trim()}',
      );
    }

    if (
      offering.academicYear
          .trim()
          .isNotEmpty
    ) {
      parts.add(
        offering.academicYear.trim(),
      );
    }

    if (parts.isEmpty) {
      return 'Offering ${offering.id}';
    }

    return parts.join(
      ' • ',
    );
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
          _editing
              ? 'Modifica insegnamento'
              : 'Aggiungi insegnamento',
        ),
      ),

      body:
          SafeArea(
        child:
            _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : _buildForm(),
      ),
    );
  }


  Widget _buildForm() {
    return Center(
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
                    'Insegnamento',

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite,

                      fontSize:
                          22,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                        7,
                  ),

                  Text(
                    'Seleziona il corso e la materia che insegni. La modifica di materia, modulo o canale richiederà una nuova verifica.',

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
                        22,
                  ),

                  if (_error != null) ...[
                    Container(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.redAccent
                                .withOpacity(
                          0.08,
                        ),

                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),

                      child:
                          Text(
                        _error!,

                        style:
                            const TextStyle(
                          color:
                              Colors.redAccent,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          16,
                    ),
                  ],

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

                      icon:
                          Icons
                              .account_balance_outlined,
                    ),

                    validator:
                        (
                      AcademicUniversity?
                          value,
                    ) {
                      if (value == null) {
                        return 'Seleziona un ateneo';
                      }

                      return null;
                    },

                    items:
                        _universities.map(
                      (
                        AcademicUniversity university,
                      ) {
                        return DropdownMenuItem<
                            AcademicUniversity>(
                          value:
                              university,

                          child:
                              Text(
                            university.name,

                            overflow:
                                TextOverflow
                                    .ellipsis,

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
                        _saving
                            ? null
                            : (
                                AcademicUniversity?
                                    value,
                              ) async {
                                if (
                                  value ==
                                      null
                                ) {
                                  return;
                                }

                                setState(() {
                                  _selectedUniversity =
                                      value;
                                });

                                await _loadDepartments(
                                  value.code,
                                );
                              },
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

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

                      icon:
                          Icons.business_outlined,
                    ),

                    validator:
                        (
                      AcademicDepartment?
                          value,
                    ) {
                      if (value == null) {
                        return 'Seleziona un dipartimento';
                      }

                      return null;
                    },

                    items:
                        _departments.map(
                      (
                        AcademicDepartment department,
                      ) {
                        return DropdownMenuItem<
                            AcademicDepartment>(
                          value:
                              department,

                          child:
                              Text(
                            department.name,

                            overflow:
                                TextOverflow
                                    .ellipsis,

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
                        _saving
                            ? null
                            : (
                                AcademicDepartment?
                                    value,
                              ) async {
                                final AcademicUniversity?
                                    university =
                                    _selectedUniversity;

                                if (
                                  value ==
                                      null ||
                                  university ==
                                      null
                                ) {
                                  return;
                                }

                                setState(() {
                                  _selectedDepartment =
                                      value;
                                });

                                await _loadCourses(
                                  universityCode:
                                      university.code,

                                  departmentCode:
                                      value.code,
                                );
                              },
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

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
                          'Corso',

                      icon:
                          Icons.school_outlined,
                    ),

                    validator:
                        (
                      AcademicCourse? value,
                    ) {
                      if (value == null) {
                        return 'Seleziona un corso';
                      }

                      return null;
                    },

                    items:
                        _courses.map(
                      (
                        AcademicCourse course,
                      ) {
                        return DropdownMenuItem<
                            AcademicCourse>(
                          value:
                              course,

                          child:
                              Text(
                            course.name,

                            overflow:
                                TextOverflow
                                    .ellipsis,

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
                        _saving
                            ? null
                            : (
                                AcademicCourse?
                                    value,
                              ) async {
                                if (
                                  value ==
                                      null
                                ) {
                                  return;
                                }

                                setState(() {
                                  _selectedCourse =
                                      value;
                                });

                                await _loadSubjects();
                              },
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

                  if (_loadingSubjects)
                    const Center(
                      child:
                          Padding(
                        padding:
                            EdgeInsets.all(
                          14,
                        ),

                        child:
                            CircularProgressIndicator(),
                      ),
                    )
                  else
                    DropdownButtonFormField<
                        SocialSubject>(
                      value:
                          _selectedSubject,

                      isExpanded:
                          true,

                      dropdownColor:
                          AppColors
                              .eleganceDeepNavy,

                      decoration:
                          _decoration(
                        label:
                            'Materia',

                        icon:
                            Icons.book_outlined,
                      ),

                      validator:
                          (
                        SocialSubject? value,
                      ) {
                        if (value == null) {
                          return 'Seleziona una materia';
                        }

                        return null;
                      },

                      items:
                          _subjects
                              .where(
                                (
                                  SocialSubject subject,
                                ) =>
                                    subject.isActive,
                              )
                              .map(
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
                                  TextOverflow
                                      .ellipsis,

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
                          _saving
                              ? null
                              : (
                                  SocialSubject?
                                      value,
                                ) {
                                  setState(() {
                                    _selectedSubject =
                                        value;

                                    _selectedOffering =
                                        null;
                                  });
                                },
                    ),

                  if (
                    _selectedSubject !=
                        null &&
                    _selectedSubject!
                        .offerings
                        .where(
                          (
                            SubjectOffering offering,
                          ) =>
                              offering.isActive,
                        )
                        .isNotEmpty
                  ) ...[
                    const SizedBox(
                      height:
                          16,
                    ),

                    DropdownButtonFormField<
                        SubjectOffering?>(
                      value:
                          _selectedOffering,

                      isExpanded:
                          true,

                      dropdownColor:
                          AppColors
                              .eleganceDeepNavy,

                      decoration:
                          _decoration(
                        label:
                            'Modulo / canale',

                        icon:
                            Icons
                                .account_tree_outlined,

                        hint:
                            'Tutta la materia',
                      ),

                      items:
                          [
                        const DropdownMenuItem<
                            SubjectOffering?>(
                          value:
                              null,

                          child:
                              Text(
                            'Tutta la materia',

                            style:
                                TextStyle(
                              color:
                                  AppColors.pureWhite,
                            ),
                          ),
                        ),

                        ..._selectedSubject!
                            .offerings
                            .where(
                              (
                                SubjectOffering
                                    offering,
                              ) =>
                                  offering.isActive,
                            )
                            .map(
                          (
                            SubjectOffering offering,
                          ) {
                            return DropdownMenuItem<
                                SubjectOffering?>(
                              value:
                                  offering,

                              child:
                                  Text(
                                _offeringLabel(
                                  offering,
                                ),

                                overflow:
                                    TextOverflow
                                        .ellipsis,

                                style:
                                    const TextStyle(
                                  color:
                                      AppColors.pureWhite,
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      onChanged:
                          _saving
                              ? null
                              : (
                                  SubjectOffering?
                                      value,
                                ) {
                                  setState(() {
                                    _selectedOffering =
                                        value;
                                  });
                                },
                    ),
                  ],

                  const SizedBox(
                    height:
                        20,
                  ),

                  Container(
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
                        SwitchListTile(
                      value:
                          _isCurrent,

                      onChanged:
                          _saving
                              ? null
                              : (
                                  bool value,
                                ) {
                                  setState(() {
                                    _isCurrent =
                                        value;
                                  });
                                },

                      activeColor:
                          AppColors.skyBlue,

                      title:
                          const Text(
                        'Insegnamento attuale',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite,

                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      subtitle:
                          Text(
                        'Disattivalo se non insegni più questa materia.',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.45,
                          ),

                          fontSize:
                              11,
                        ),
                      ),
                    ),
                  ),

                  if (_editing) ...[
                    const SizedBox(
                      height:
                          16,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.all(
                        13,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.amber
                                .withOpacity(
                          0.07,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),

                      child:
                          Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          const Icon(
                            Icons.info_outline,

                            color:
                                Colors.amber,

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
                              'Se cambi materia, modulo o canale, lo stato di verifica tornerà in attesa.',

                              style:
                                  TextStyle(
                                color:
                                    AppColors.pureWhite
                                        .withOpacity(
                                  0.60,
                                ),

                                fontSize:
                                    11,

                                height:
                                    1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

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

                                    color:
                                        AppColors.pureWhite,
                                  ),
                                )
                              : Icon(
                                  _editing
                                      ? Icons.save_outlined
                                      : Icons.add_rounded,
                                ),

                      label:
                          Text(
                        _saving
                            ? 'Salvataggio...'
                            : _editing
                                ? 'Salva modifiche'
                                : 'Aggiungi insegnamento',

                        style:
                            const TextStyle(
                          fontSize:
                              15,

                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.teacherIndigo,

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
    );
  }


  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
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
          AppColors.eleganceDeepNavy,

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
              AppColors.teacherIndigo,
        ),
      ),
    );
  }
}


class _OfferingInfo
    extends StatelessWidget {
  final SubjectOffering offering;


  const _OfferingInfo({
    required this.offering,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final List<Widget> badges =
        [];

    if (
      offering.module
          .trim()
          .isNotEmpty
    ) {
      badges.add(
        _SimpleBadge(
          label:
              offering.module,

          icon:
              Icons.book_outlined,
        ),
      );
    }

    if (
      offering.channel
          .trim()
          .isNotEmpty
    ) {
      badges.add(
        _SimpleBadge(
          label:
              'Canale ${offering.channel}',

          icon:
              Icons
                  .account_tree_outlined,
        ),
      );
    }

    if (
      offering.academicYear
          .trim()
          .isNotEmpty
    ) {
      badges.add(
        _SimpleBadge(
          label:
              offering.academicYear,

          icon:
              Icons
                  .calendar_month_outlined,
        ),
      );
    }

    return Container(
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
          12,
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          if (badges.isNotEmpty)
            Wrap(
              spacing:
                  6,

              runSpacing:
                  6,

              children:
                  badges,
            ),

          if (
            offering.teachers
                .isNotEmpty
          ) ...[
            if (badges.isNotEmpty)
              const SizedBox(
                height:
                    9,
              ),

            Text(
              'Docenti catalogo: ${offering.teachers.map((AcademicTeacher teacher) => teacher.name).join(', ')}',

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
          ],
        ],
      ),
    );
  }
}


class _VerificationBadge
    extends StatelessWidget {
  final TeacherAssignment
      assignment;


  const _VerificationBadge({
    required this.assignment,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    if (assignment.isVerified) {
      return const _ColoredBadge(
        label:
            'VERIFICATO',

        icon:
            Icons.verified_rounded,

        color:
            Colors.greenAccent,
      );
    }

    if (assignment.isRejected) {
      return const _ColoredBadge(
        label:
            'RIFIUTATO',

        icon:
            Icons.cancel_outlined,

        color:
            Colors.redAccent,
      );
    }

    return const _ColoredBadge(
      label:
          'IN VERIFICA',

      icon:
          Icons.schedule_rounded,

      color:
          Colors.amber,
    );
  }
}


class _ColoredBadge
    extends StatelessWidget {
  final String label;

  final IconData icon;

  final Color color;


  const _ColoredBadge({
    required this.label,
    required this.icon,
    required this.color,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            7,

        vertical:
            5,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.09,
        ),

        borderRadius:
            BorderRadius.circular(
          8,
        ),

        border:
            Border.all(
          color:
              color.withOpacity(
            0.16,
          ),
        ),
      ),

      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            icon,

            color:
                color,

            size:
                11,
          ),

          const SizedBox(
            width:
                4,
          ),

          Text(
            label,

            style:
                TextStyle(
              color:
                  color,

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


class _SimpleBadge
    extends StatelessWidget {
  final String label;

  final IconData icon;


  const _SimpleBadge({
    required this.label,
    required this.icon,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            7,

        vertical:
            5,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.skyBlue
                .withOpacity(
          0.09,
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
          Icon(
            icon,

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
            label,

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


class _EmptyAssignments
    extends StatelessWidget {
  final VoidCallback onAdd;


  const _EmptyAssignments({
    required this.onAdd,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        22,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child:
          Column(
        children: [
          const Icon(
            Icons
                .cast_for_education_outlined,

            color:
                AppColors.skyBlue,

            size:
                42,
          ),

          const SizedBox(
            height:
                12,
          ),

          const Text(
            'Nessun insegnamento',

            style:
                TextStyle(
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
                6,
          ),

          Text(
            'Aggiungi la prima materia che insegni.',

            textAlign:
                TextAlign.center,

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
                16,
          ),

          OutlinedButton.icon(
            onPressed:
                onAdd,

            icon:
                const Icon(
              Icons.add_rounded,
            ),

            label:
                const Text(
              'Aggiungi insegnamento',
            ),
          ),
        ],
      ),
    );
  }
}


class _MenuItem
    extends StatelessWidget {
  final IconData icon;

  final String label;

  final bool danger;


  const _MenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final Color color =
        danger
            ? Colors.redAccent
            : AppColors.pureWhite;

    return Row(
      children: [
        Icon(
          icon,

          color:
              color,

          size:
              18,
        ),

        const SizedBox(
          width:
              9,
        ),

        Text(
          label,

          style:
              TextStyle(
            color:
                color,
          ),
        ),
      ],
    );
  }
}