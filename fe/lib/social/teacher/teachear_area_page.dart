import 'package:flutter/material.dart';

import 'teacher_materials_page.dart';
import '../../material/teacher/teacher_materials_section.dart';
import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';
import '../news/public_news_editor_page.dart';
import '../../quiz/teacher/teacher_subject_tools_page.dart';

class TeacherAreaPage extends StatefulWidget {
  const TeacherAreaPage({super.key});

  @override
  State<TeacherAreaPage> createState() => _TeacherAreaPageState();
}

class _TeacherAreaPageState extends State<TeacherAreaPage> {
  final ApiService _apiService = ApiService();

  bool _loading = true;
  bool _authorized = false;
  String? _error;
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final bool authorized = await _apiService.canAccessTeacherArea();

      if (!mounted) {
        return;
      }

      if (!authorized) {
        setState(() {
          _authorized = false;
          _subjects = [];
          _loading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> subjects =
          await _apiService.getTeacherSubjects();

      if (!mounted) {
        return;
      }

      setState(() {
        _authorized = true;
        _subjects = subjects;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authorized = false;
        _subjects = [];
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<bool> _verifyBeforeAction() async {
    try {
      final bool authorized = await _apiService.canAccessTeacherArea();

      if (!mounted) {
        return false;
      }

      if (!authorized) {
        setState(() {
          _authorized = false;
        });
        return false;
      }

      return true;
    } catch (_) {
      _showMessage(
        'Impossibile verificare i permessi docente.',
      );
      return false;
    }
  }

  Future<void> _openSubject(Map<String, dynamic> subject) async {
    final bool authorized = await _verifyBeforeAction();

    if (!authorized || !mounted) {
      return;
    }

    final int? subjectId = _toInt(subject['id']);
    final String subjectCode = _stringValue(subject['code']);
    final String subjectName = _stringValue(subject['name']);
    final String department = _stringValue(subject['department']);
    final String course = _stringValue(subject['course']);
    final String departmentCode = _firstNonEmpty([
      subject['department_code'],
      subject['departmentCode'],
      department,
    ]);
    final String courseCode = _firstNonEmpty([
      subject['course_code'],
      subject['courseCode'],
      course,
    ]);
    final String university = _firstNonEmpty([
      subject['university'],
    ]);
    final String universityCode = _firstNonEmpty([
      subject['university_code'],
      subject['universityCode'],
    ]);

    if (subjectId == null ||
        subjectName.isEmpty ||
        department.isEmpty ||
        course.isEmpty) {
      _showMessage(
        'I dati della materia non sono completi.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeacherSubjectToolsPage(
          subjectId: subjectId,
          subjectCode: subjectCode,
          subjectName: subjectName,
          department: department,
          departmentCode: departmentCode,
          course: course,
          courseCode: courseCode,
          university: university,
          universityCode: universityCode,
        ),
      ),
    );

    if (mounted) {
      await _initialize();
    }
  }

  Future<void> _openMaterials() async {
    final bool authorized = await _verifyBeforeAction();

    if (!authorized || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TeacherMaterialsPage(),
      ),
    );

    if (mounted) {
      await _initialize();
    }
  }

  Future<void> _openNewsEditor() async {
    final bool authorized = await _verifyBeforeAction();

    if (!authorized || !mounted) {
      return;
    }

    final bool? created =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PublicNewsEditorPage.teacher(
          subjects: _subjects,
        ),
      ),
    );

    if (!mounted || created != true) {
      return;
    }

    _showMessage('News pubblicata correttamente.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.darkElegance,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.teacherIndigo,
          ),
        ),
      );
    }

    if (!_authorized) {
      return _TeacherAccessDeniedPage(
        error: _error,
        onRetry: _initialize,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text('Area Docenti'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _initialize,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: RefreshIndicator(
              onRefresh: _initialize,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 26),
                  const _TeacherSectionTitle(
                    title: 'Pubblicazione',
                    subtitle:
                        'Gestisci news e materiali associati alle tue materie verificate.',
                  ),
                  const SizedBox(height: 14),
                  _buildPublishingGrid(),
                  const SizedBox(height: 28),
                  const _TeacherSectionTitle(
                    title: 'Le tue materie',
                    subtitle:
                        'Apri una materia verificata per quiz, banca domande, simulazioni, materiali e risultati.',
                  ),
                  const SizedBox(height: 14),
                  if (_subjects.isEmpty)
                    const _EmptySubjectsCard()
                  else
                    _buildSubjectsGrid(),
                  const SizedBox(height: 30),
                  TeacherMaterialsSection(
                    subjects: _subjects,
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.teacherIndigo.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.teacherIndigo.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.cast_for_education_outlined,
              color: AppColors.teacherIndigo,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Area Docenti StudentLab',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _subjects.length == 1
                      ? 'Hai 1 materia verificata disponibile.'
                      : 'Hai ${_subjects.length} materie verificate disponibili.',
                  style: TextStyle(
                    color: AppColors.pureWhite.withValues(alpha: 0.52),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Docente verificato dal server',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishingGrid() {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final int columns = constraints.maxWidth >= 720 ? 2 : 1;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 180,
          children: [
            _TeacherActionCard(
              icon: Icons.campaign_outlined,
              title: 'Pubblica news',
              description:
                  'Prepara una news pubblica nel contesto delle tue materie verificate.',
              onTap: _openNewsEditor,
            ),
            _TeacherActionCard(
              icon: Icons.folder_copy_outlined,
              title: 'Materiali e dispense',
              description:
                  'Carica, modifica, elimina e assegna materiali a studenti e gruppi.',
              onTap: _openMaterials,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubjectsGrid() {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final int columns = constraints.maxWidth >= 760 ? 2 : 1;

        return GridView.builder(
          itemCount: _subjects.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 180,
          ),
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final Map<String, dynamic> subject = _subjects[index];

            return _TeacherSubjectCard(
              subject: subject,
              onTap: () => _openSubject(subject),
            );
          },
        );
      },
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String normalized = _stringValue(value);

      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return '';
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();

    if (value.contains('401') || value.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }

    if (value.contains('403') || value.contains('forbidden')) {
      return 'Il tuo account non dispone dei permessi docente richiesti.';
    }

    if (value.contains('socket') ||
        value.contains('connection') ||
        value.contains('network') ||
        value.contains('timeout') ||
        value.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    return 'Impossibile caricare l’area docente.';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _TeacherActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool pending;

  const _TeacherActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.eleganceMidnight,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: AppColors.teacherIndigo.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: AppColors.teacherIndigo.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.teacherIndigo,
                      size: 23,
                    ),
                  ),
                  const Spacer(),
                  if (pending)
                    const Text(
                      'BACKEND DA COLLEGARE',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white30,
                      size: 14,
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherSubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback onTap;

  const _TeacherSubjectCard({
    required this.subject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String code = subject['code']?.toString().trim() ?? '';
    final String name = subject['name']?.toString().trim() ?? 'Materia';
    final String department =
        subject['department']?.toString().trim() ?? '';
    final String course = subject['course']?.toString().trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.eleganceMidnight,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: AppColors.teacherIndigo.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.school_outlined,
                color: AppColors.teacherIndigo,
                size: 25,
              ),
              const SizedBox(height: 10),
              if (code.isNotEmpty)
                Text(
                  code,
                  style: const TextStyle(
                    color: AppColors.materialSky,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                [department, course]
                    .where((String value) => value.isNotEmpty)
                    .join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TeacherSectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.pureWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.pureWhite.withValues(alpha: 0.45),
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _EmptySubjectsCard extends StatelessWidget {
  const _EmptySubjectsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Text(
        'Nessuna materia verificata disponibile.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white54,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TeacherAccessDeniedPage extends StatelessWidget {
  final String? error;
  final Future<void> Function() onRetry;

  const _TeacherAccessDeniedPage({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Area Docenti'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: AppColors.eleganceMidnight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.gpp_bad_outlined,
                    color: Colors.redAccent,
                    size: 44,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Accesso docente non autorizzato',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    error ??
                        'Il server non riconosce questa sessione come appartenente a un docente verificato e attivo.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Riprova'),
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
