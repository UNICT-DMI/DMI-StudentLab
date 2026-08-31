import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';

import '../social_models.dart';

import 'manage_profile_subjects_page.dart';

class EditSocialProfilePage extends StatefulWidget {
  final SocialUser user;

  const EditSocialProfilePage({super.key, required this.user});

  @override
  State<EditSocialProfilePage> createState() => _EditSocialProfilePageState();
}

class _EditSocialProfilePageState extends State<EditSocialProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ApiService _apiService = ApiService();

  final AuthSession _session = AuthSession.instance;

  late SocialUser _user;

  late final TextEditingController _firstNameController;

  late final TextEditingController _lastNameController;

  late final TextEditingController _emailController;

  late final TextEditingController _descriptionController;

  late bool _available;

  late bool _availableForHelp;

  late bool _availableForPrivateLessons;

  bool _saving = false;

  bool _academicWorking = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _user = widget.user;

    _firstNameController = TextEditingController(text: _user.firstName);

    _lastNameController = TextEditingController(text: _user.lastName);

    _emailController = TextEditingController(text: _user.email);

    _descriptionController = TextEditingController(text: _user.description);

    _available = _user.available;

    _availableForHelp = _user.availableForHelp;

    _availableForPrivateLessons = _user.availableForPrivateLessons;
  }

  @override
  void dispose() {
    _firstNameController.dispose();

    _lastNameController.dispose();

    _emailController.dispose();

    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;

      _error = null;
    });

    bool completed = false;

    try {
      final SocialUser updatedUser = await _apiService.updateSocialUser(
        userId: _user.id,

        firstName: _firstNameController.text.trim(),

        lastName: _lastNameController.text.trim(),

        description: _descriptionController.text.trim(),

        available: _available,

        availableForHelp: _availableForHelp,

        availableForPrivateLessons: _availableForPrivateLessons,
      );

      _session.updateUser(updatedUser);

      _user = updatedUser;

      if (!mounted) {
        return;
      }

      completed = true;

      Navigator.pop(context, updatedUser);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanErrorMessage(e);
      });
    } finally {
      if (!completed && mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _refreshUser() async {
    final SocialUser user = await _apiService.getCurrentUser();

    _session.updateUser(user);

    if (!mounted) {
      return;
    }

    setState(() {
      _user = user;
    });
  }

  Future<void> _manageSubjects() async {
    if (_saving || _academicWorking) {
      return;
    }

    final SocialUser? updatedUser = await Navigator.of(context)
        .push<SocialUser>(
          MaterialPageRoute(
            builder: (_) => ManageProfileSubjectsPage(user: _user),
          ),
        );

    if (!mounted || updatedUser == null) {
      return;
    }

    _session.updateUser(updatedUser);

    setState(() {
      _user = updatedUser;
    });
  }

  Future<void> _openAddAcademicPath() async {
    if (_saving || _academicWorking) {
      return;
    }

    final _AcademicPathFormResult? result =
        await showModalBottomSheet<_AcademicPathFormResult>(
          context: context,

          isScrollControlled: true,

          backgroundColor: AppColors.eleganceDeepNavy,

          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),

          builder: (_) => const _AcademicPathEditorSheet(),
        );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _academicWorking = true;

      _error = null;
    });

    try {
      await _apiService.createAcademicPath(
        university: result.university.name,

        universityCode: result.university.code,

        department: result.department.name,

        departmentCode: result.department.code,

        course: result.course.name,

        courseCode: result.course.code,

        degreeType: result.course.degreeType,

        status: result.status,

        startYear: result.startYear,

        graduationYear: result.graduationYear,

        isCurrent: result.isCurrent,

        isPrimary: result.isPrimary,
      );

      await _refreshUser();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _academicWorking = false;
        });
      }
    }
  }

  Future<void> _openEditAcademicPath(SocialAcademicPath path) async {
    if (_saving || _academicWorking) {
      return;
    }

    final _AcademicPathFormResult? result =
        await showModalBottomSheet<_AcademicPathFormResult>(
          context: context,

          isScrollControlled: true,

          backgroundColor: AppColors.eleganceDeepNavy,

          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),

          builder: (_) => _AcademicPathEditorSheet(initialPath: path),
        );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _academicWorking = true;

      _error = null;
    });

    try {
      await _apiService.updateAcademicPath(
        academicPathId: path.id,

        university: result.university.name,

        universityCode: result.university.code,

        department: result.department.name,

        departmentCode: result.department.code,

        course: result.course.name,

        courseCode: result.course.code,

        degreeType: result.course.degreeType,

        status: result.status,

        startYear: result.startYear,

        clearStartYear: result.startYear == null,

        graduationYear: result.graduationYear,

        clearGraduationYear: result.graduationYear == null,

        isCurrent: result.isCurrent,

        isPrimary: result.isPrimary ? true : null,
      );

      await _refreshUser();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _academicWorking = false;
        });
      }
    }
  }

  Future<void> _setCurrentAcademicPath(SocialAcademicPath path) async {
    if (_saving || _academicWorking || path.isCurrent) {
      return;
    }

    setState(() {
      _academicWorking = true;

      _error = null;
    });

    try {
      await _apiService.setCurrentAcademicPath(path.id);

      await _refreshUser();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _academicWorking = false;
        });
      }
    }
  }

  Future<void> _setPrimaryAcademicPath(SocialAcademicPath path) async {
    if (_saving || _academicWorking || path.isPrimary) {
      return;
    }

    setState(() {
      _academicWorking = true;

      _error = null;
    });

    try {
      await _apiService.setPrimaryAcademicPath(path.id);

      await _refreshUser();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _academicWorking = false;
        });
      }
    }
  }

  Future<void> _removeAcademicPath(SocialAcademicPath path) async {
    if (_saving || _academicWorking) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,

          title: const Text(
            'Rimuovi percorso',

            style: TextStyle(color: AppColors.pureWhite),
          ),

          content: Text(
            'Vuoi rimuovere "${path.course}" dai tuoi percorsi accademici?',

            style: TextStyle(color: AppColors.pureWhite.withOpacity(0.65)),
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
                'Rimuovi',

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
      _academicWorking = true;

      _error = null;
    });

    try {
      await _apiService.removeAcademicPath(path.id);

      await _refreshUser();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _cleanErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _academicWorking = false;
        });
      }
    }
  }

  String _cleanErrorMessage(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('401') || message.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (message.contains('403') || message.contains('forbidden')) {
      return 'Non hai i permessi necessari per completare questa operazione.';
    }

    if (message.contains('404') || message.contains('not found')) {
      return 'Alcune informazioni del profilo non sono più disponibili. Aggiorna la pagina e riprova.';
    }

    if (message.contains('409') ||
        message.contains('conflict') ||
        message.contains('already')) {
      return 'La modifica richiesta è in conflitto con informazioni già presenti nel profilo.';
    }

    if (message.contains('422') ||
        message.contains('validation') ||
        message.contains('invalid')) {
      return 'Alcuni dati inseriti non sono validi. Controllali e riprova.';
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

    return 'Non è stato possibile completare la modifica del profilo. Riprova.';
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obbligatorio';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeacher = _user.type == SocialUserType.teacher;

    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        elevation: 0,

        title: const Text(
          'Modifica profilo',

          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),

        actions: [
          TextButton(
            onPressed: _saving || _academicWorking ? null : _save,

            child: const Text(
              'Salva',

              style: TextStyle(
                color: AppColors.skyBlue,

                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),

            child: Form(
              key: _formKey,

              child: ListView(
                padding: const EdgeInsets.all(20),

                children: [
                  _buildHeader(isTeacher),

                  const SizedBox(height: 20),

                  _buildPersonalSection(),

                  const SizedBox(height: 16),

                  _buildAcademicSection(),

                  const SizedBox(height: 16),

                  _buildSubjectsSection(),

                  const SizedBox(height: 16),

                  _buildRoleSection(),

                  const SizedBox(height: 16),

                  _buildAvailabilitySection(),

                  const SizedBox(height: 16),

                  _buildDescriptionSection(),

                  if (_error != null) ...[
                    const SizedBox(height: 18),

                    _buildError(),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,

                    child: ElevatedButton.icon(
                      onPressed: _saving || _academicWorking ? null : _save,

                      icon: _saving
                          ? const SizedBox(
                              width: 18,

                              height: 18,

                              child: CircularProgressIndicator(
                                strokeWidth: 2,

                                color: AppColors.pureWhite,
                              ),
                            )
                          : const Icon(Icons.save_outlined),

                      label: Text(
                        _saving ? 'Salvataggio...' : 'Salva modifiche',

                        style: const TextStyle(
                          fontSize: 15,

                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTeacher
                            ? AppColors.teacherIndigo
                            : AppColors.socialBlue,

                        foregroundColor: AppColors.pureWhite,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTeacher) {
    final String name =
        '${_firstNameController.text} '
                '${_lastNameController.text}'
            .trim();

    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.skyBlue.withOpacity(0.12)),
      ),

      child: Row(
        children: [
          CircleAvatar(
            radius: 26,

            backgroundColor: isTeacher
                ? AppColors.teacherIndigo
                : AppColors.studentBlue,

            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',

              style: const TextStyle(
                color: AppColors.pureWhite,

                fontSize: 18,

                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  name.isEmpty ? 'Profilo StudentLab' : name,

                  style: const TextStyle(
                    color: AppColors.pureWhite,

                    fontSize: 16,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  isTeacher ? 'Insegnante' : 'Studente',

                  style: const TextStyle(
                    color: AppColors.materialSky,

                    fontSize: 10,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (isTeacher && _user.isVerifiedTeacher) ...[
                  const SizedBox(height: 4),

                  const Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,

                        color: Colors.greenAccent,

                        size: 13,
                      ),

                      SizedBox(width: 4),

                      Text(
                        'Docente verificato',

                        style: TextStyle(
                          color: Colors.greenAccent,

                          fontSize: 9,

                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalSection() {
    return _EditSection(
      title: 'Informazioni personali',

      icon: Icons.person_outline_rounded,

      child: Column(
        children: [
          TextFormField(
            controller: _firstNameController,

            enabled: !_saving,

            validator: _requiredValidator,

            textInputAction: TextInputAction.next,

            onChanged: (_) {
              setState(() {});
            },

            style: const TextStyle(color: AppColors.pureWhite),

            decoration: _inputDecoration(
              label: 'Nome',

              icon: Icons.badge_outlined,
            ),
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: _lastNameController,

            enabled: !_saving,

            validator: _requiredValidator,

            textInputAction: TextInputAction.next,

            onChanged: (_) {
              setState(() {});
            },

            style: const TextStyle(color: AppColors.pureWhite),

            decoration: _inputDecoration(
              label: 'Cognome',

              icon: Icons.badge_outlined,
            ),
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: _emailController,

            readOnly: true,

            style: TextStyle(color: AppColors.pureWhite.withOpacity(0.60)),

            decoration: _inputDecoration(
              label: 'Email',

              icon: Icons.email_outlined,

              hint: 'Email account',
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'L\'email dell\'account non viene modificata da questa schermata.',

            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.35),

              fontSize: 9,

              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicSection() {
    return _EditSection(
      title: 'Percorsi accademici',

      icon: Icons.school_outlined,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          Text(
            _user.academicPaths.isEmpty
                ? 'Non hai ancora aggiunto percorsi accademici.'
                : 'Gestisci le lauree e i percorsi universitari associati al tuo profilo.',

            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.48),

              fontSize: 10,

              height: 1.4,
            ),
          ),

          if (_academicWorking) ...[
            const SizedBox(height: 14),

            const LinearProgressIndicator(),
          ],

          if (_user.academicPaths.isNotEmpty) ...[
            const SizedBox(height: 15),

            ..._user.academicPaths.map(
              (SocialAcademicPath path) => Padding(
                padding: const EdgeInsets.only(bottom: 10),

                child: _AcademicPathCard(
                  path: path,

                  disabled: _saving || _academicWorking,

                  onEdit: () {
                    _openEditAcademicPath(path);
                  },

                  onSetCurrent: () {
                    _setCurrentAcademicPath(path);
                  },

                  onSetPrimary: () {
                    _setPrimaryAcademicPath(path);
                  },

                  onRemove: () {
                    _removeAcademicPath(path);
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 5),

          OutlinedButton.icon(
            onPressed: _saving || _academicWorking
                ? null
                : _openAddAcademicPath,

            icon: const Icon(Icons.add_rounded),

            label: const Text('Aggiungi percorso accademico'),

            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.materialSky,

              side: BorderSide(color: AppColors.skyBlue.withOpacity(0.25)),

              padding: const EdgeInsets.symmetric(vertical: 12),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsSection() {
    return _EditSection(
      title: 'Materie',

      icon: Icons.menu_book_outlined,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          Text(
            _user.subjects.isEmpty
                ? 'Non hai ancora aggiunto materie al tuo profilo.'
                : '${_user.subjects.length} '
                      '${_user.subjects.length == 1 ? 'materia associata' : 'materie associate'} '
                      'al profilo.',

            style: TextStyle(
              color: AppColors.pureWhite.withOpacity(0.48),

              fontSize: 10,

              height: 1.4,
            ),
          ),

          if (_user.subjects.isNotEmpty) ...[
            const SizedBox(height: 13),

            Wrap(
              spacing: 7,

              runSpacing: 7,

              children: _user.subjects
                  .map(
                    (SocialSubject subject) =>
                        _ProfileSubjectChip(subject: subject),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: 15),

          OutlinedButton.icon(
            onPressed: _saving || _academicWorking ? null : _manageSubjects,

            icon: const Icon(Icons.tune_rounded),

            label: const Text('Gestisci materie'),

            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.materialSky,

              side: BorderSide(color: AppColors.skyBlue.withOpacity(0.25)),

              padding: const EdgeInsets.symmetric(vertical: 12),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection() {
    final bool isTeacher = _user.type == SocialUserType.teacher;

    return _EditSection(
      title: 'Tipo di profilo',

      icon: Icons.manage_accounts_outlined,

      child: Container(
        padding: const EdgeInsets.all(13),

        decoration: BoxDecoration(
          color: AppColors.brandNightBlue,

          borderRadius: BorderRadius.circular(13),

          border: Border.all(
            color: (isTeacher ? AppColors.teacherIndigo : AppColors.studentBlue)
                .withOpacity(0.25),
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 42,

              height: 42,

              decoration: BoxDecoration(
                color:
                    (isTeacher
                            ? AppColors.teacherIndigo
                            : AppColors.studentBlue)
                        .withOpacity(0.14),

                borderRadius: BorderRadius.circular(11),
              ),

              child: Icon(
                isTeacher
                    ? Icons.cast_for_education_rounded
                    : Icons.school_rounded,

                color: isTeacher
                    ? AppColors.teacherIndigo
                    : AppColors.studentBlue,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    isTeacher ? 'Insegnante' : 'Studente',

                    style: const TextStyle(
                      color: AppColors.pureWhite,

                      fontSize: 12,

                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    isTeacher
                        ? 'Il ruolo docente è gestito dal sistema di verifica StudentLab.'
                        : 'Il ruolo studente è associato al tuo account.',

                    style: TextStyle(
                      color: AppColors.pureWhite.withOpacity(0.40),

                      fontSize: 9,

                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return _EditSection(
      title: 'Disponibilità',

      icon: Icons.schedule_outlined,

      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,

            value: _available,

            onChanged: _saving
                ? null
                : (bool value) {
                    setState(() {
                      _available = value;
                    });
                  },

            activeColor: AppColors.skyBlue,

            title: const Text(
              'Disponibile',

              style: TextStyle(
                color: AppColors.pureWhite,

                fontSize: 13,

                fontWeight: FontWeight.w500,
              ),
            ),

            subtitle: Text(
              'Indica agli altri utenti che sei disponibile a essere contattato.',

              style: TextStyle(
                color: AppColors.pureWhite.withOpacity(0.42),

                fontSize: 10,

                height: 1.35,
              ),
            ),
          ),

          Divider(color: AppColors.pureWhite.withOpacity(0.06)),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,

            value: _availableForHelp,

            onChanged: _saving
                ? null
                : (bool value) {
                    setState(() {
                      _availableForHelp = value;
                    });
                  },

            activeColor: AppColors.skyBlue,

            title: const Text(
              'Disponibile ad aiutare',

              style: TextStyle(
                color: AppColors.pureWhite,

                fontSize: 13,

                fontWeight: FontWeight.w500,
              ),
            ),

            subtitle: Text(
              'Abilita globalmente la tua disponibilità per aiutare altri utenti nelle materie selezionate.',

              style: TextStyle(
                color: AppColors.pureWhite.withOpacity(0.42),

                fontSize: 10,

                height: 1.35,
              ),
            ),
          ),

          Divider(color: AppColors.pureWhite.withOpacity(0.06)),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,

            value: _availableForPrivateLessons,

            onChanged: _saving
                ? null
                : (bool value) {
                    setState(() {
                      _availableForPrivateLessons = value;
                    });
                  },

            activeColor: AppColors.skyBlue,

            title: const Text(
              'Lezioni private',

              style: TextStyle(
                color: AppColors.pureWhite,

                fontSize: 13,

                fontWeight: FontWeight.w500,
              ),
            ),

            subtitle: Text(
              'Abilita globalmente la possibilità di offrire lezioni private nelle materie selezionate.',

              style: TextStyle(
                color: AppColors.pureWhite.withOpacity(0.42),

                fontSize: 10,

                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _EditSection(
      title: 'Descrizione',

      icon: Icons.notes_rounded,

      child: TextFormField(
        controller: _descriptionController,

        enabled: !_saving,

        minLines: 4,

        maxLines: 7,

        maxLength: 1000,

        style: const TextStyle(color: AppColors.pureWhite),

        decoration: _inputDecoration(
          label: 'Parla di te',

          icon: Icons.edit_note_rounded,

          hint: 'Interessi, materie, obiettivi di studio...',
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.redAccent.withOpacity(0.20)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.error_outline_rounded,

            color: Colors.redAccent,

            size: 19,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              _error ?? 'Errore durante il salvataggio.',

              style: const TextStyle(
                color: Colors.white70,

                fontSize: 10,

                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,

      hintText: hint,

      labelStyle: TextStyle(color: AppColors.pureWhite.withOpacity(0.55)),

      hintStyle: TextStyle(color: AppColors.pureWhite.withOpacity(0.28)),

      prefixIcon: Icon(icon, color: AppColors.skyBlue),

      filled: true,

      fillColor: AppColors.brandNightBlue,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: AppColors.skyBlue.withOpacity(0.08)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: AppColors.skyBlue.withOpacity(0.50)),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: const BorderSide(color: Colors.redAccent),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  final String title;

  final IconData icon;

  final Widget child;

  const _EditSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.skyBlue.withOpacity(0.10)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.skyBlue, size: 19),

              const SizedBox(width: 8),

              Text(
                title,

                style: const TextStyle(
                  color: AppColors.pureWhite,

                  fontSize: 14,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          child,
        ],
      ),
    );
  }
}

class _ProfileSubjectChip extends StatelessWidget {
  final SocialSubject subject;

  const _ProfileSubjectChip({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),

      decoration: BoxDecoration(
        color: AppColors.brandNightBlue,

        borderRadius: BorderRadius.circular(10),

        border: Border.all(color: AppColors.skyBlue.withOpacity(0.08)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          const Icon(
            Icons.menu_book_outlined,

            color: AppColors.materialSky,

            size: 13,
          ),

          const SizedBox(width: 5),

          Flexible(
            child: Text(
              subject.name,

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                color: AppColors.pureWhite,

                fontSize: 9,

                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          if (subject.grade != null) ...[
            const SizedBox(width: 6),

            Text(
              '${subject.grade}/30',

              style: const TextStyle(
                color: AppColors.materialSky,

                fontSize: 8,

                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          if (subject.canHelp) ...[
            const SizedBox(width: 5),

            const Icon(
              Icons.volunteer_activism_outlined,

              color: AppColors.materialSky,

              size: 11,
            ),
          ],

          if (subject.canGivePrivateLessons) ...[
            const SizedBox(width: 5),

            const Icon(
              Icons.cast_for_education_outlined,

              color: AppColors.materialSky,

              size: 11,
            ),
          ],
        ],
      ),
    );
  }
}

class _AcademicPathCard extends StatelessWidget {
  final SocialAcademicPath path;

  final bool disabled;

  final VoidCallback onEdit;

  final VoidCallback onSetCurrent;

  final VoidCallback onSetPrimary;

  final VoidCallback onRemove;

  const _AcademicPathCard({
    required this.path,
    required this.disabled,
    required this.onEdit,
    required this.onSetCurrent,
    required this.onSetPrimary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: AppColors.brandNightBlue,

        borderRadius: BorderRadius.circular(13),

        border: Border.all(
          color: path.isPrimary
              ? AppColors.skyBlue.withOpacity(0.25)
              : AppColors.skyBlue.withOpacity(0.07),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.school_outlined,

                color: AppColors.skyBlue,

                size: 18,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      path.degreeType.isEmpty
                          ? path.course
                          : '${path.course} ${path.degreeType}',

                      style: const TextStyle(
                        color: AppColors.pureWhite,

                        fontSize: 12,

                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      path.university,

                      style: TextStyle(
                        color: AppColors.pureWhite.withOpacity(0.40),

                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                enabled: !disabled,

                icon: const Icon(
                  Icons.more_vert_rounded,

                  color: Colors.white54,
                ),

                color: AppColors.eleganceDeepNavy,

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

                    case 'remove':
                      onRemove();
                      break;
                  }
                },

                itemBuilder: (_) {
                  return [
                    const PopupMenuItem(
                      value: 'edit',

                      child: Text(
                        'Modifica',

                        style: TextStyle(color: AppColors.pureWhite),
                      ),
                    ),

                    if (path.isEnrolled && !path.isCurrent)
                      const PopupMenuItem(
                        value: 'current',

                        child: Text(
                          'Imposta corrente',

                          style: TextStyle(color: AppColors.pureWhite),
                        ),
                      ),

                    if (!path.isPrimary)
                      const PopupMenuItem(
                        value: 'primary',

                        child: Text(
                          'Imposta principale',

                          style: TextStyle(color: AppColors.pureWhite),
                        ),
                      ),

                    const PopupMenuItem(
                      value: 'remove',

                      child: Text(
                        'Rimuovi',

                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 6,

            runSpacing: 6,

            children: [
              _AcademicPathBadge(
                label: _academicStatusLabel(path.status),

                icon: _academicStatusIcon(path.status),
              ),

              if (path.isPrimary)
                const _AcademicPathBadge(
                  label: 'Principale',

                  icon: Icons.star_outline_rounded,
                ),

              if (path.isCurrent)
                const _AcademicPathBadge(
                  label: 'Corrente',

                  icon: Icons.play_circle_outline_rounded,
                ),

              if (path.isGraduated && path.isVerified)
                const _AcademicPathBadge(
                  label: 'Laurea verificata',

                  icon: Icons.verified_rounded,

                  color: Colors.greenAccent,
                ),

              if (path.isGraduated && path.isVerificationPending)
                const _AcademicPathBadge(
                  label: 'Verifica in corso',

                  icon: Icons.schedule_rounded,

                  color: Colors.amber,
                ),

              if (path.isGraduated && path.isVerificationRejected)
                const _AcademicPathBadge(
                  label: 'Verifica rifiutata',

                  icon: Icons.cancel_outlined,

                  color: Colors.redAccent,
                ),
            ],
          ),

          if (path.startYear != null || path.graduationYear != null) ...[
            const SizedBox(height: 9),

            Text(
              _academicYearsLabel(path),

              style: TextStyle(
                color: AppColors.pureWhite.withOpacity(0.38),

                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AcademicPathEditorSheet extends StatefulWidget {
  final SocialAcademicPath? initialPath;

  const _AcademicPathEditorSheet({this.initialPath});

  @override
  State<_AcademicPathEditorSheet> createState() =>
      _AcademicPathEditorSheetState();
}

class _AcademicPathEditorSheetState extends State<_AcademicPathEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ApiService _apiService = ApiService();

  final TextEditingController _startYearController = TextEditingController();

  final TextEditingController _graduationYearController =
      TextEditingController();

  List<AcademicUniversity> _universities = [];

  List<AcademicDepartment> _departments = [];

  List<AcademicCourse> _courses = [];

  AcademicUniversity? _university;

  AcademicDepartment? _department;

  AcademicCourse? _course;

  AcademicPathStatus _status = AcademicPathStatus.enrolled;

  bool _isCurrent = false;

  bool _isPrimary = false;

  bool _loading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    final SocialAcademicPath? path = widget.initialPath;

    if (path != null) {
      _status = path.status;

      _isCurrent = path.isCurrent;

      _isPrimary = path.isPrimary;

      if (path.startYear != null) {
        _startYearController.text = path.startYear.toString();
      }

      if (path.graduationYear != null) {
        _graduationYearController.text = path.graduationYear.toString();
      }
    }

    _load();
  }

  @override
  void dispose() {
    _startYearController.dispose();

    _graduationYearController.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<AcademicUniversity> universities = await _apiService
          .getUniversities();

      if (!mounted) {
        return;
      }

      AcademicUniversity? selectedUniversity;

      final SocialAcademicPath? initialPath = widget.initialPath;

      if (initialPath != null) {
        for (final AcademicUniversity university in universities) {
          if (university.code == initialPath.universityCode) {
            selectedUniversity = university;

            break;
          }
        }
      }

      selectedUniversity ??= universities.isEmpty ? null : universities.first;

      setState(() {
        _universities = universities;

        _university = selectedUniversity;
      });

      if (selectedUniversity != null) {
        await _loadDepartments(
          selectedUniversity.code,
          initialDepartmentCode: initialPath?.departmentCode,
          initialCourseCode: initialPath?.courseCode,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;

        _error = e.toString();
      });
    }
  }

  Future<void> _loadDepartments(
    String universityCode, {
    String? initialDepartmentCode,
    String? initialCourseCode,
  }) async {
    final List<AcademicDepartment> departments = await _apiService
        .getDepartments(universityCode);

    if (!mounted) {
      return;
    }

    AcademicDepartment? selectedDepartment;

    if (initialDepartmentCode != null) {
      for (final AcademicDepartment department in departments) {
        if (department.code == initialDepartmentCode) {
          selectedDepartment = department;

          break;
        }
      }
    }

    selectedDepartment ??= departments.isEmpty ? null : departments.first;

    setState(() {
      _departments = departments;

      _department = selectedDepartment;

      _courses = [];

      _course = null;
    });

    if (selectedDepartment != null) {
      await _loadCourses(
        universityCode: universityCode,

        departmentCode: selectedDepartment.code,

        initialCourseCode: initialCourseCode,
      );
    }
  }

  Future<void> _loadCourses({
    required String universityCode,
    required String departmentCode,
    String? initialCourseCode,
  }) async {
    final List<AcademicCourse> courses = await _apiService.getCourses(
      universityCode: universityCode,

      departmentCode: departmentCode,
    );

    if (!mounted) {
      return;
    }

    AcademicCourse? selectedCourse;

    if (initialCourseCode != null) {
      for (final AcademicCourse course in courses) {
        if (course.code == initialCourseCode) {
          selectedCourse = course;

          break;
        }
      }
    }

    selectedCourse ??= courses.isEmpty ? null : courses.first;

    setState(() {
      _courses = courses;

      _course = selectedCourse;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final AcademicUniversity? university = _university;

    final AcademicDepartment? department = _department;

    final AcademicCourse? course = _course;

    if (university == null || department == null || course == null) {
      return;
    }

    final int? startYear = _startYearController.text.trim().isEmpty
        ? null
        : int.tryParse(_startYearController.text.trim());

    final int? graduationYear = _status == AcademicPathStatus.graduated
        ? _graduationYearController.text.trim().isEmpty
              ? null
              : int.tryParse(_graduationYearController.text.trim())
        : null;

    Navigator.pop(
      context,
      _AcademicPathFormResult(
        university: university,

        department: department,

        course: course,

        status: _status,

        startYear: startYear,

        graduationYear: graduationYear,

        isCurrent: _status == AcademicPathStatus.enrolled ? _isCurrent : false,

        isPrimary: _isPrimary,
      ),
    );
  }

  String? _validateYear(String? value) {
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
      return 'Inserisci l\'anno di laurea';
    }

    final int? year = int.tryParse(value.trim());

    if (year == null) {
      return 'Anno non valido';
    }

    final int currentYear = DateTime.now().year;

    if (year < 1900 || year > currentYear) {
      return 'Anno di laurea non valido';
    }

    final int? startYear = int.tryParse(_startYearController.text.trim());

    if (startYear != null && year < startYear) {
      return 'L\'anno di laurea non può precedere l\'anno di inizio';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, keyboard + 20),

      child: SingleChildScrollView(
        child: Form(
          key: _formKey,

          child: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                widget.initialPath == null
                    ? 'Aggiungi percorso'
                    : 'Modifica percorso',

                style: const TextStyle(
                  color: AppColors.pureWhite,

                  fontSize: 19,

                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),

                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (_error != null) ...[
                  Text(
                    _error!,

                    style: const TextStyle(
                      color: Colors.redAccent,

                      fontSize: 10,
                    ),
                  ),

                  const SizedBox(height: 12),
                ],

                DropdownButtonFormField<AcademicUniversity>(
                  value: _university,

                  isExpanded: true,

                  dropdownColor: AppColors.eleganceDeepNavy,

                  decoration: _sheetDecoration(
                    label: 'Ateneo',

                    icon: Icons.account_balance_outlined,
                  ),

                  validator: (value) {
                    if (value == null) {
                      return 'Seleziona un ateneo';
                    }

                    return null;
                  },

                  items: _universities
                      .map(
                        (AcademicUniversity university) => DropdownMenuItem(
                          value: university,

                          child: Text(
                            university.name,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(color: AppColors.pureWhite),
                          ),
                        ),
                      )
                      .toList(),

                  onChanged: (AcademicUniversity? value) async {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _university = value;

                      _department = null;

                      _course = null;
                    });

                    await _loadDepartments(value.code);
                  },
                ),

                const SizedBox(height: 13),

                DropdownButtonFormField<AcademicDepartment>(
                  value: _department,

                  isExpanded: true,

                  dropdownColor: AppColors.eleganceDeepNavy,

                  decoration: _sheetDecoration(
                    label: 'Dipartimento',

                    icon: Icons.business_outlined,
                  ),

                  validator: (value) {
                    if (value == null) {
                      return 'Seleziona un dipartimento';
                    }

                    return null;
                  },

                  items: _departments
                      .map(
                        (AcademicDepartment department) => DropdownMenuItem(
                          value: department,

                          child: Text(
                            department.name,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(color: AppColors.pureWhite),
                          ),
                        ),
                      )
                      .toList(),

                  onChanged: (AcademicDepartment? value) async {
                    final AcademicUniversity? university = _university;

                    if (value == null || university == null) {
                      return;
                    }

                    setState(() {
                      _department = value;

                      _course = null;
                    });

                    await _loadCourses(
                      universityCode: university.code,

                      departmentCode: value.code,
                    );
                  },
                ),

                const SizedBox(height: 13),

                DropdownButtonFormField<AcademicCourse>(
                  value: _course,

                  isExpanded: true,

                  dropdownColor: AppColors.eleganceDeepNavy,

                  decoration: _sheetDecoration(
                    label: 'Corso',

                    icon: Icons.school_outlined,
                  ),

                  validator: (value) {
                    if (value == null) {
                      return 'Seleziona un corso';
                    }

                    return null;
                  },

                  items: _courses
                      .map(
                        (AcademicCourse course) => DropdownMenuItem(
                          value: course,

                          child: Text(
                            course.name,

                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(color: AppColors.pureWhite),
                          ),
                        ),
                      )
                      .toList(),

                  onChanged: (AcademicCourse? value) {
                    setState(() {
                      _course = value;
                    });
                  },
                ),

                const SizedBox(height: 13),

                DropdownButtonFormField<AcademicPathStatus>(
                  value: _status,

                  dropdownColor: AppColors.eleganceDeepNavy,

                  decoration: _sheetDecoration(
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
                        'Laureato',

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

                  onChanged: (AcademicPathStatus? value) {
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

                const SizedBox(height: 13),

                TextFormField(
                  controller: _startYearController,

                  keyboardType: TextInputType.number,

                  validator: _validateYear,

                  style: const TextStyle(color: AppColors.pureWhite),

                  decoration: _sheetDecoration(
                    label: 'Anno di inizio',

                    icon: Icons.calendar_month_outlined,

                    hint: 'Facoltativo',
                  ),
                ),

                if (_status == AcademicPathStatus.graduated) ...[
                  const SizedBox(height: 13),

                  TextFormField(
                    controller: _graduationYearController,

                    keyboardType: TextInputType.number,

                    validator: _validateGraduationYear,

                    style: const TextStyle(color: AppColors.pureWhite),

                    decoration: _sheetDecoration(
                      label: 'Anno di laurea',

                      icon: Icons.workspace_premium_outlined,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                if (_status == AcademicPathStatus.enrolled)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,

                    value: _isCurrent,

                    onChanged: (bool value) {
                      setState(() {
                        _isCurrent = value;
                      });
                    },

                    activeColor: AppColors.skyBlue,

                    title: const Text(
                      'Percorso corrente',

                      style: TextStyle(
                        color: AppColors.pureWhite,

                        fontSize: 12,

                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,

                  value: _isPrimary,

                  onChanged: (bool value) {
                    if (widget.initialPath?.isPrimary == true && !value) {
                      return;
                    }

                    setState(() {
                      _isPrimary = value;
                    });
                  },

                  activeColor: AppColors.skyBlue,

                  title: const Text(
                    'Percorso principale',

                    style: TextStyle(
                      color: AppColors.pureWhite,

                      fontSize: 12,

                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  subtitle: Text(
                    'È il percorso mostrato come riferimento principale nel profilo.',

                    style: TextStyle(
                      color: AppColors.pureWhite.withOpacity(0.38),

                      fontSize: 9,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,

                  height: 50,

                  child: ElevatedButton.icon(
                    onPressed: _submit,

                    icon: const Icon(Icons.check_rounded),

                    label: Text(
                      widget.initialPath == null
                          ? 'Aggiungi percorso'
                          : 'Salva percorso',
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.socialBlue,

                      foregroundColor: AppColors.pureWhite,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _sheetDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,

      hintText: hint,

      prefixIcon: Icon(icon, color: AppColors.skyBlue),

      labelStyle: const TextStyle(color: Colors.white54),

      hintStyle: const TextStyle(color: Colors.white24),

      filled: true,

      fillColor: AppColors.brandNightBlue,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: AppColors.skyBlue.withOpacity(0.08)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: AppColors.skyBlue.withOpacity(0.45)),
      ),
    );
  }
}

class _AcademicPathFormResult {
  final AcademicUniversity university;

  final AcademicDepartment department;

  final AcademicCourse course;

  final AcademicPathStatus status;

  final int? startYear;

  final int? graduationYear;

  final bool isCurrent;

  final bool isPrimary;

  const _AcademicPathFormResult({
    required this.university,
    required this.department,
    required this.course,
    required this.status,
    required this.startYear,
    required this.graduationYear,
    required this.isCurrent,
    required this.isPrimary,
  });
}

class _AcademicPathBadge extends StatelessWidget {
  final String label;

  final IconData icon;

  final Color color;

  const _AcademicPathBadge({
    required this.label,
    required this.icon,
    this.color = AppColors.materialSky,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),

      decoration: BoxDecoration(
        color: color.withOpacity(0.10),

        borderRadius: BorderRadius.circular(8),
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

              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _academicStatusLabel(AcademicPathStatus status) {
  switch (status) {
    case AcademicPathStatus.enrolled:
      return 'Studente';

    case AcademicPathStatus.graduated:
      return 'Laureato';

    case AcademicPathStatus.suspended:
      return 'Sospeso';

    case AcademicPathStatus.withdrawn:
      return 'Interrotto';

    case AcademicPathStatus.transferred:
      return 'Trasferito';
  }
}

IconData _academicStatusIcon(AcademicPathStatus status) {
  switch (status) {
    case AcademicPathStatus.enrolled:
      return Icons.school_outlined;

    case AcademicPathStatus.graduated:
      return Icons.workspace_premium_outlined;

    case AcademicPathStatus.suspended:
      return Icons.pause_circle_outline_rounded;

    case AcademicPathStatus.withdrawn:
      return Icons.remove_circle_outline;

    case AcademicPathStatus.transferred:
      return Icons.swap_horiz_rounded;
  }
}

String _academicYearsLabel(SocialAcademicPath path) {
  if (path.startYear != null && path.graduationYear != null) {
    return '${path.startYear} - ${path.graduationYear}';
  }

  if (path.startYear != null) {
    return 'Dal ${path.startYear}';
  }

  if (path.graduationYear != null) {
    return 'Laurea ${path.graduationYear}';
  }

  return '';
}
