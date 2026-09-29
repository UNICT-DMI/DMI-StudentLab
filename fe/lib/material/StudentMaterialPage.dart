import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fe/material/material_requests_page.dart';
import 'package:fe/social/auth/login_page.dart';
import 'package:fe/developer/theme/developer_ui_style.dart';
import 'package:fe/theme/app_palette.dart';
import 'package:fe/theme/nightTheme.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';

import 'package:fe/services/api_service.dart';
import 'package:fe/services/auth_session.dart';
import 'package:fe/services/picked_file_bridge.dart';

import 'package:fe/social/social_models.dart';
import 'package:fe/faq/faq_home_page.dart';
import 'package:fe/calendar/calendar_home_page.dart';
import 'package:fe/faq/faq_exam_page.dart';


import 'package:fe/local_storage/models/material_local.dart';
import 'package:fe/local_storage/models/material_offline_entry.dart';
import 'package:fe/local_storage/repositories/material_repository.dart';
import 'package:fe/local_storage/services/local_material_import_service.dart';
import 'package:fe/local_storage/services/local_storage_identity.dart';
import 'package:fe/local_storage/services/material_download_service.dart';
import 'package:fe/local_storage/services/material_sync_service.dart';
import 'package:fe/local_storage/services/material_preference_service.dart';

class StudentMaterialPage extends StatefulWidget {
  final String? initialAction;
  const StudentMaterialPage({super.key, this.initialAction});

  @override
  State<StudentMaterialPage> createState() => _StudentMaterialPageState();
}

class _StudentMaterialPageState extends State<StudentMaterialPage> {
  final MaterialDownloadService _downloadService = MaterialDownloadService();
  final LocalMaterialImportService _localImportService =
      LocalMaterialImportService();
  final MaterialRepository _materialRepository = MaterialRepository();
  final MaterialSyncService _syncService = MaterialSyncService();
  final MaterialPreferenceService _preferenceService = MaterialPreferenceService();
  final ApiService _apiService = ApiService();
  final AuthSession _authSession = AuthSession.instance;

  List<MaterialLocal> _materials = [];
  List<MaterialOfflineEntry> _offlineMaterials = [];
  Map<String, int> _preferredByHash = <String, int>{};
  final Set<int> _processingMaterialIds = <int>{};
  bool _usingOfflineCache = false;
  bool _exploreAllPublicCourses = false;
  String? _browseCourseKey;
  bool _choosingBrowseCourse = false;
  Set<String> _enrolledCourseKeys = <String>{};

  /// Percorso corrente dello studente (per la card "Il tuo percorso"),
  /// anche quando il suo corso non ha ancora materiali.
  SocialAcademicPath? _currentPath;
  String? _rootUniversityFilter;
  String? _rootDepartmentFilter;

  String? _selectedUniversity;

  String? _selectedDepartment;

  String? _selectedCourse;

  _LocalSubject? _selectedSubject;
  String _selectedCourseScope = 'degree';
  final List<String> _selectedFolders = <String>[];

  bool _loading = true;

  /// Livello aperto direttamente dalla home ('subject' o 'course'):
  /// "Indietro" da lì torna alla home invece di risalire la gerarchia.
  String? _rootEntryLevel;

  bool _downloadingAll = false;

  /// File importati da ospite e passati all'account all'ultimo caricamento.
  int _claimedGuestFiles = 0;

  /// Ordine dei file nella materia: 'recent', 'name' oppure 'offline'.
  String _fileOrder = 'recent';

  /// Duplicati per cui in questa sessione si è scelto "Tienile entrambe".
  final Set<String> _dismissedDuplicateHashes = <String>{};

  /// Copia selezionata nella scheda duplicato, prima di confermare.
  final Map<String, int> _duplicateChoice = <String, int>{};

  bool _openingPublicationForm = false;

  bool _openingOfflineForm = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _authSession.addListener(_onAuthChanged);

    _loadMaterials().then((_) {
      if (mounted && widget.initialAction == 'publish') _openPublication();
    });
  }

  @override
  void dispose() {
    _authSession.removeListener(_onAuthChanged);

    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _usingOfflineCache = false;
      });
    }

    final int localUserId = _downloadService.currentLocalUserId;
    bool syncFailed = false;

    if (_authSession.isAuthenticated) {
      final int? currentUserId = _authSession.currentUserId;
      if (currentUserId != null) {
        try {
          final int claimed =
              await _materialRepository.claimGuestLocalMaterials(currentUserId);
          if (claimed > 0 && mounted) {
            setState(() => _claimedGuestFiles = claimed);
          }
          await _preferenceService.claimGuest(currentUserId);
          await _syncService.syncMaterials(
            userId: currentUserId,
            forceFull: true,
          );
        } catch (_) {
          syncFailed = true;
        }
      }
    } else {
      try {
        await _syncService.syncMaterials(
          userId: LocalStorageIdentity.guestUserId,
          forceFull: true,
        );
      } catch (_) {
        syncFailed = true;
      }
    }

    try {
      if (_authSession.isAuthenticated) {
        try { await _linkApprovedCourses(localUserId); } catch (_) {
          // Catalog lookup never prevents access to locally saved files.
        }
      }
      final List<MaterialLocal> availableMaterials = await _materialRepository
          .getAvailableByUser(localUserId);

      Set<String> enrolledCourses = {};
      Set<String> enrolledDepartments = {};
      SocialAcademicPath? currentPath;
      if (_authSession.isAuthenticated && _authSession.currentUserId != null) {
        try {
          final paths = await _apiService.getUserAcademicPaths(_authSession.currentUserId!);
          final enrolled = paths.where((path) => path.status == AcademicPathStatus.enrolled).toList();
          enrolledCourses = enrolled
            .map((path) => _courseKey(path.university, path.department, path.course)).toSet();
          enrolledDepartments = enrolled
            .map((path) => _courseKey(path.university, path.department, '')).toSet();
          final current = enrolled.where((path) => path.isCurrent);
          final primary = enrolled.where((path) => path.isPrimary);
          currentPath = current.isNotEmpty
              ? current.first
              : (primary.isNotEmpty ? primary.first : (enrolled.isNotEmpty ? enrolled.first : null));
        } catch (_) {
          // The backend still enforces access to restricted files.
        }
      }

      final List<MaterialLocal> materials = availableMaterials
          .where(_isDisplayableMaterial)
          .where((material) => !_authSession.isAuthenticated || _exploreAllPublicCourses ||
            enrolledCourses.isEmpty || material.source != MaterialSourceLocal.public ||
            enrolledCourses.contains(_courseKey(material.university, material.department,
              material.course)) ||
            // "Corsi del dipartimento" (senza materie) restano visibili nel tab
            // Il mio corso, come nel canvas.
            ((material.subjectName?.trim().isEmpty ?? true) &&
              enrolledDepartments.contains(_courseKey(material.university, material.department, ''))))
          .toList();

      final List<MaterialOfflineEntry> offline = await _downloadService
          .getDownloadedMaterialEntries(userId: localUserId);
      final Map<String, int> preferred = await _preferenceService.byUser(localUserId);

      if (!mounted) {
        return;
      }

      setState(() {
        _materials = materials;
        _offlineMaterials = offline;
        _preferredByHash = preferred;
        _enrolledCourseKeys = enrolledCourses;
        _currentPath = currentPath;
        _usingOfflineCache = syncFailed;
        _loading = false;
      });

      _validateSelection();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  String _courseKey(String? university, String? department, String? course) =>
      '${university?.trim().toLowerCase() ?? ''}\u0000'
      '${department?.trim().toLowerCase() ?? ''}\u0000'
      '${course?.trim().toLowerCase() ?? ''}';

  Future<void> _linkApprovedCourses(int userId) async {
    final approved = await _apiService.myMaterialCourseProposals();
    final ids = <String, int>{};
    for (final proposal in approved) {
      if (proposal['status'] != 'approved') continue;
      final id = int.tryParse(proposal['subject_id']?.toString() ?? '');
      if (id == null) continue;
      ids[_courseKey(proposal['university']?.toString(),
        proposal['department']?.toString(), proposal['course']?.toString())] = id;
    }
    if (ids.isEmpty) return;
    final local = await _materialRepository.getAvailableByUser(userId);
    final updates = <MaterialLocal>[];
    for (final material in local) {
      if (material.source != MaterialSourceLocal.local ||
          material.courseScope != 'additional' || material.subjectId != null ||
          (material.subjectName?.trim().isNotEmpty ?? false)) continue;
      final id = ids[_courseKey(material.university, material.department, material.course)];
      if (id == null) continue;
      updates.add(material.copyWith(subjectId: id,
        subjectName: 'Materiali del corso', updatedAt: DateTime.now().toUtc()));
    }
    if (updates.isNotEmpty) await _materialRepository.saveAll(updates);
  }

  bool _isDisplayableMaterial(MaterialLocal material) {
    // Legacy and directly shared files can lack one or more catalog fields.
    // Show them under "Altro" instead of making personal files disappear.
    return material.originalName.trim().isNotEmpty;
  }

  void _validateSelection() {
    final String? university = _selectedUniversity;

    if (university != null && !_universities.contains(university)) {
      setState(() {
        _selectedUniversity = null;

        _selectedDepartment = null;

        _selectedCourse = null;

        _selectedSubject = null;
      });

      return;
    }

    final String? department = _selectedDepartment;

    if (department != null && !_departments.contains(department)) {
      setState(() {
        _selectedDepartment = null;

        _selectedCourse = null;

        _selectedSubject = null;
      });

      return;
    }

    final String? course = _selectedCourse;

    if (course != null && !_courses.contains(course)) {
      setState(() {
        _selectedCourse = null;

        _selectedSubject = null;
      });

      return;
    }

    final _LocalSubject? subject = _selectedSubject;

    if (subject != null) {
      final bool exists = _subjects.any(
        (_LocalSubject current) => current.id == subject.id,
      );

      if (!exists) {
        setState(() {
          _selectedSubject = null;
        });
      }
    }
  }

  List<String> get _universities {
    final Map<String, String> values = {};

    for (final MaterialLocal material in _materials) {
      _addCaseInsensitiveValue(values, material.displayUniversity);
    }

    final List<String> result = values.values.toList();

    result.sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return result;
  }

  List<String> get _departments {
    final String? university = _selectedUniversity;

    if (university == null) {
      return [];
    }

    final Set<String> values = {};

    for (final MaterialLocal material in _materials) {
      if (material.displayUniversity != university) {
        continue;
      }

      values.add(material.displayDepartment);
    }

    final List<String> result = values.toList();

    result.sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return result;
  }

  List<String> get _courses {
    final String? university = _selectedUniversity;

    final String? department = _selectedDepartment;

    if (university == null || department == null) {
      return [];
    }

    final Set<String> values = {};

    for (final MaterialLocal material in _materials) {
      if (material.displayUniversity != university ||
          material.displayDepartment != department) {
        continue;
      }

      values.add(material.displayCourse);
    }

    final List<String> result = values.toList();

    result.sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return result;
  }

  List<_LocalSubject> get _subjects {
    final String? university = _selectedUniversity;
    final String? department = _selectedDepartment;
    final String? course = _selectedCourse;

    if (university == null || department == null || course == null) {
      return [];
    }

    final Map<String, List<MaterialLocal>> grouped =
        <String, List<MaterialLocal>>{};

    for (final MaterialLocal material in _materials) {
      if (material.displayUniversity != university ||
          material.displayDepartment != department ||
          material.displayCourse != course ||
          material.courseScope != _selectedCourseScope) {
        continue;
      }

      final String name = material.subjectName?.trim() ?? '';

      final String key = material.subjectId != null
          ? 'id:${material.subjectId}'
          : name.isEmpty ? 'course:direct' : 'name:${name.toLowerCase()}';

      grouped.putIfAbsent(key, () => <MaterialLocal>[]).add(material);
    }

    final List<_LocalSubject> result = grouped.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) {
          final MaterialLocal first = entry.value.first;
          return _LocalSubject(
            id: entry.key,
            subjectId: first.subjectId,
            name: entry.key == 'course:direct'
                ? 'Materiali del corso'
                : first.displaySubjectName,
            university: university,
            department: department,
            course: course,
            materialCount: entry.value.length,
          );
        })
        .toList();

    result.sort(
      (_LocalSubject a, _LocalSubject b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return result;
  }

  List<MaterialLocal> get _selectedMaterials {
    final String? university = _selectedUniversity;
    final String? department = _selectedDepartment;
    final String? course = _selectedCourse;
    final _LocalSubject? subject = _selectedSubject;

    if (university == null ||
        department == null ||
        course == null ||
        subject == null) {
      return [];
    }

    final List<MaterialLocal> result = _materials.where((material) {
      if (material.displayUniversity != university ||
          material.displayDepartment != department ||
          material.displayCourse != course ||
          material.courseScope != _selectedCourseScope) {
        return false;
      }

      if (subject.subjectId != null) {
        return material.subjectId == subject.subjectId;
      }

      if (subject.id == 'course:direct') {
        return material.subjectId == null &&
            (material.subjectName?.trim().isEmpty ?? true);
      }
      return material.displaySubjectName.toLowerCase() ==
          subject.name.toLowerCase();
    }).toList();

    result.sort((a, b) {
      final aPreferred = _isPreferredMaterial(a) ? 1 : 0;
      final bPreferred = _isPreferredMaterial(b) ? 1 : 0;
      if (aPreferred != bPreferred) return bPreferred.compareTo(aPreferred);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return result;
  }

  bool _isPreferredMaterial(MaterialLocal material) {
    final hash = (material.remoteFileHash ?? _offlineEntryFor(material)?.fileHash)
        ?.toLowerCase();
    return hash != null && material.id != null &&
        _preferredByHash[hash] == material.id;
  }

  int _countUniversity(String university) {
    return _materials
        .where((material) => _sameText(material.displayUniversity, university))
        .length;
  }

  int _countDepartment(String department) {
    final String? university = _selectedUniversity;

    if (university == null) {
      return 0;
    }

    return _materials
        .where(
          (material) =>
              _sameText(material.displayUniversity, university) &&
              _sameText(material.displayDepartment, department),
        )
        .length;
  }

  int _countCourse(String course, String scope) {
    final String? university = _selectedUniversity;
    final String? department = _selectedDepartment;

    if (university == null || department == null) {
      return 0;
    }

    return _materials
        .where(
          (material) =>
              _sameText(material.displayUniversity, university) &&
              _sameText(material.displayDepartment, department) &&
              _sameText(material.displayCourse, course) &&
              material.courseScope == scope,
        )
        .length;
  }

  bool get _hasSelection {
    return _selectedFolders.isNotEmpty || _selectedUniversity != null ||
        _selectedDepartment != null ||
        _selectedCourse != null ||
        _selectedSubject != null;
  }

  String get _pageTitle {
    if (_selectedFolders.isNotEmpty) return _selectedFolders.last;
    if (_selectedSubject != null) {
      return _selectedSubject!.id == 'course:direct'
          ? _selectedSubject!.course
          : _selectedSubject!.name;
    }

    if (_selectedCourse != null) {
      return _selectedCourse!;
    }

    if (_selectedDepartment != null) {
      return _selectedDepartment!;
    }

    if (_selectedUniversity != null) {
      return _selectedUniversity!;
    }

    return 'Dispense';
  }

  void _goBack() {
    setState(() {
      if (_selectedFolders.isNotEmpty) {
        _selectedFolders.removeLast();
        return;
      }
      final bool backToRoot =
          (_rootEntryLevel == 'subject' && _selectedSubject != null) ||
          (_rootEntryLevel == 'course' && _selectedSubject == null && _selectedCourse != null);
      if (backToRoot) {
        _rootEntryLevel = null;
        _selectedSubject = null;
        _selectedCourse = null;
        _selectedDepartment = null;
        _selectedUniversity = null;
        return;
      }
      if (_selectedSubject != null) {
        _selectedSubject = null;

        return;
      }

      if (_selectedCourse != null) {
        _selectedCourse = null;

        return;
      }

      if (_selectedDepartment != null) {
        _selectedDepartment = null;

        return;
      }

      _selectedUniversity = null;
    });
  }

  // ===========================================================================
  // UI DISPENSE (stile StudentLab)
  // La logica di caricamento, sincronizzazione e download è quella di prima:
  // qui cambia solo la presentazione.
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final bool showActions =
        _authSession.isAuthenticated && !_loading && _error == null;
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: _buildAppBar(),
      body: SafeArea(child: _buildBody()),
      floatingActionButton: showActions
          ? FloatingActionButton.extended(
              onPressed: _showActionsSheet,
              backgroundColor: AppColors.skyBlue,
              foregroundColor: AppColors.darkElegance,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Richiedi o pubblica',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final bool signedIn = _authSession.isAuthenticated;
    return AppBar(
      backgroundColor: AppColors.eleganceMidnight,
      foregroundColor: AppColors.pureWhite,
      automaticallyImplyLeading: false,
      titleSpacing: 4,
      shape: Border(
        bottom: BorderSide(color: AppColors.pureWhite.withValues(alpha: 0.06)),
      ),
      leading: IconButton(
        tooltip: _hasSelection ? 'Indietro' : 'Torna alla Home',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          if (_hasSelection) {
            _goBack();
            return;
          }
          Navigator.of(context).pop();
        },
      ),
      title: Text(
        _pageTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: _hasSelection ? 17 : 19,
          fontWeight: _hasSelection ? FontWeight.w600 : FontWeight.w700,
        ),
      ),
      actions: [
        if (!signedIn && !_hasSelection)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: 4),
              child: SlStatusBadge(label: 'Ospite'),
            ),
          ),
        IconButton(
          tooltip: 'Cerca nelle Dispense',
          onPressed: _loading ? null : _openSearch,
          icon: const Icon(Icons.search_rounded),
        ),
        if (signedIn && !_hasSelection)
          IconButton(
            tooltip: 'Le mie richieste',
            onPressed: _openRequests,
            icon: const Icon(Icons.mail_outline_rounded),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Cerca per nome del file, materia o cartella e apre la cartella del file.
  Future<void> _openSearch() async {
    final MaterialLocal? found = await showSearch<MaterialLocal?>(
      context: context,
      delegate: _DispenseSearchDelegate(_materials),
    );
    if (found == null || !mounted) return;
    setState(() {
      _rootEntryLevel = 'subject';
      _selectedUniversity = found.displayUniversity;
      _selectedDepartment = found.displayDepartment;
      _selectedCourse = found.displayCourse;
      _selectedCourseScope = found.courseScope;
      _selectedSubject = _subjectFor(
        found,
        _materials.where((m) => _subjectFor(m, 0).id == _subjectFor(found, 0).id &&
            m.displayCourse == found.displayCourse).length,
      );
      _selectedFolders
        ..clear()
        ..addAll(found.pathSegments);
    });
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.skyBlue));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildErrorCard(),
        ),
      );
    }
    if (_selectedSubject != null) {
      return _buildMaterialPage();
    }
    if (_selectedCourse != null) {
      return _buildSubjectPage();
    }
    if (_selectedDepartment != null) {
      return _buildCoursePage();
    }
    if (_selectedUniversity != null) {
      return _buildDepartmentPage();
    }
    return _buildUniversityPage();
  }

  // ---------------------------------------------------------------------------
  // Pannello delle azioni ("Richiedi o pubblica")
  // ---------------------------------------------------------------------------

  Future<void> _showActionsSheet() async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.eleganceDeepNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final String context_ = _selectedSubject?.name ??
            (_selectedCourse ?? 'il tuo percorso');
        Widget option(String value, IconData icon, SlTone tone, String title,
            String description, {bool highlighted = false}) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: highlighted
                  ? AppColors.skyBlue.withValues(alpha: 0.08)
                  : AppColors.eleganceMidnight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: highlighted
                      ? AppColors.skyBlue.withValues(alpha: 0.34)
                      : AppColors.pureWhite.withValues(alpha: 0.08),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(sheetContext, value),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      SlIconTile(icon: icon, tone: tone, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(
                                    color: AppColors.pureWhite,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(description,
                                style: TextStyle(
                                    color: AppColors.pureWhite.withValues(alpha: 0.60),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }

        Widget overline(String text) => Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(text,
                  style: TextStyle(
                      color: AppColors.pureWhite.withValues(alpha: 0.56),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            );

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Cosa ti serve?',
                    style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Per $context_${_selectedCourse == null || _selectedSubject == null ? '' : ' · $_selectedCourse'}',
                    style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.62),
                        fontSize: 12)),
                const SizedBox(height: 10),
                overline('CHIEDI MATERIALE'),
                option('studentlab', Icons.mail_outline_rounded, SlTone.cyan,
                    'A StudentLab', 'La redazione lo cerca o lo produce'),
                option('teacher', Icons.school_outlined, SlTone.blue,
                    'Al docente',
                    '${_selectedSubject?.name ?? 'La materia scelta'} · se non ci sono docenti va a StudentLab'),
                option('student', Icons.people_outline_rounded, SlTone.private,
                    'A uno studente', 'Un compagno del tuo corso o gruppo'),
                overline('CONDIVIDI'),
                option('publish', Icons.upload_rounded, SlTone.info,
                    'Pubblica un tuo materiale',
                    'StudentLab lo verifica prima di pubblicarlo',
                    highlighted: true),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'teacher':
      case 'studentlab':
      case 'student':
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => MaterialRequestsPage(
            initialSubjectId: _selectedSubject?.subjectId,
            initialSubjectName: _selectedSubject?.name,
            initialAction: choice,
            hasTeacherMaterials: _selectedSubject?.subjectId != null &&
                _materials.any((material) =>
                    material.subjectId == _selectedSubject!.subjectId &&
                    material.source == MaterialSourceLocal.teacher &&
                    material.isAvailableRemote),
          ),
        ));
      case 'publish':
        if (!_openingPublicationForm) await _openPublication();
    }
  }

  // ---------------------------------------------------------------------------
  // Home delle Dispense
  // ---------------------------------------------------------------------------

  /// Ingresso Dispense: percorsi e file restano quelli della sincronizzazione
  /// esistente; questa vista modifica solo la navigazione, non SQLite.
  Widget _buildUniversityPage() {
    final bool signedIn = _authSession.isAuthenticated;
    final ownCourses = <String, List<MaterialLocal>>{};
    final publicCourses = <String, List<MaterialLocal>>{};
    final deviceFiles =
        _materials.where((m) => m.source == MaterialSourceLocal.local).toList();
    final currentKey = _currentPath == null ? null : _courseKey(
        _currentPath!.university, _currentPath!.department, _currentPath!.course);
    final selectedKey = _browseCourseKey ?? currentKey;
    for (final material in _materials) {
      if (material.source == MaterialSourceLocal.local) continue;
      final academicKey =
          _courseKey(material.university, material.department, material.course);
      final key = '$academicKey\u0000${material.courseScope}';
      final own = signedIn && selectedKey != null && academicKey == selectedKey;
      (own ? ownCourses : publicCourses)
          .putIfAbsent(key, () => <MaterialLocal>[])
          .add(material);
    }
    final showOwn = signedIn;
    // I file locali si vedono sotto le materie, senza cambiare schermata.
    final showDevice = false;
    final ownMaterial = ownCourses.values.expand((e) => e).toList();
    final ownSubjects = <String, List<MaterialLocal>>{};
    for (final item in ownMaterial
        .where((m) => m.subjectName?.trim().isNotEmpty ?? false)) {
      ownSubjects
          .putIfAbsent('${item.displayCourse}\u0000${item.displaySubjectName}',
              () => <MaterialLocal>[])
          .add(item);
    }
    final departmentCourses = publicCourses.values
        .where((items) =>
            items.isNotEmpty &&
            (selectedKey == null || selectedKey.startsWith(
                _courseKey(items.first.university, items.first.department, ''))) &&
            items.every((m) => m.subjectName?.trim().isEmpty ?? true))
        .toList();
    final courses = showOwn ? ownCourses : publicCourses;
    final universities = courses.values
        .expand((items) => items.map((m) => m.displayUniversity))
        .toSet()
        .toList()
      ..sort();
    final selectedUniversity = universities.contains(_rootUniversityFilter)
        ? _rootUniversityFilter
        : null;
    final departments = courses.values
        .expand((items) => items)
        .where((m) =>
            selectedUniversity == null || m.displayUniversity == selectedUniversity)
        .map((m) => m.displayDepartment)
        .toSet()
        .toList()
      ..sort();
    final selectedDepartment = departments.contains(_rootDepartmentFilter)
        ? _rootDepartmentFilter
        : null;
    final shown = courses.values
        .where((items) =>
            (selectedUniversity == null ||
                items.first.displayUniversity == selectedUniversity) &&
            (selectedDepartment == null ||
                items.first.displayDepartment == selectedDepartment))
        .toList();
    shown.sort((a, b) => a.first.displayCourse
        .toLowerCase()
        .compareTo(b.first.displayCourse.toLowerCase()));
    final List<MaterialLocal> ownFirstCourse =
        ownCourses.values.isEmpty ? const <MaterialLocal>[] : ownCourses.values.first;

    return RefreshIndicator(
      onRefresh: _loadMaterials,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            children: <Widget>[
              if (_usingOfflineCache) ...[
                _buildOfflineSyncBanner(),
                const SizedBox(height: 14),
              ],
              if (!signedIn) ...[
                _dispensePanel(
                  icon: Icons.person_outline_rounded,
                  title: 'Stai usando StudentLab senza account',
                  detail:
                      'I file che aggiungi restano solo su questo dispositivo. Quando accedi, entrano nel tuo albero e vedrai solo il tuo corso.',
                  elevated: true,
                  action: FilledButton(
                    style: _primaryButtonStyle(),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const LoginPage())),
                    child: const Text('Accedi o registrati'),
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                if (_claimedGuestFiles > 0) ...[
                  _buildClaimNotice(deviceFiles),
                  const SizedBox(height: 14),
                ],
                _buildPathCard(ownFirstCourse),
                const SizedBox(height: 20),
              ],
              if (!showDevice) ...[
                if (showOwn) ...[
                  _sectionTitle('Materie'),
                  const SizedBox(height: 10),
                ] else ...[
                  // Ospite e "Corsi DMI": filtri sempre visibili, come nel canvas.
                  Text('Scegli tu cosa vedere',
                      style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.62), fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                    _dispenseFilter('Ateneo', selectedUniversity,
                        universities, (value) => setState(() {
                              _rootUniversityFilter = value;
                              _rootDepartmentFilter = null;
                            })),
                    _dispenseFilter('Dipartimento', selectedDepartment,
                        departments,
                        (value) => setState(() => _rootDepartmentFilter = value)),
                    _dispenseFilter('Corso', null,
                        shown.map((items) => items.first.displayCourse).toSet().toList()..sort(),
                        (value) {
                      if (value == null) return;
                      final match = shown.where((items) => items.first.displayCourse == value);
                      if (match.isNotEmpty) _openCourseFromRoot(match.first);
                    }, dashed: true),
                  ]),
                  const SizedBox(height: 18),
                  _sectionTitle(selectedDepartment == null
                      ? 'Corsi'
                      : 'Corsi del $selectedDepartment'),
                  const SizedBox(height: 10),
                ],
                if (showOwn && ownSubjects.isNotEmpty) ...[
                  for (final group in ownSubjects.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SubjectCard(
                        title: group.first.displaySubjectName,
                        topics: group
                            .where((m) => m.pathSegments.isNotEmpty)
                            .map((m) => m.pathSegments.first)
                            .toSet()
                            .length,
                        files: group.length,
                        offline: group.where(_isOnDevice).length,
                        onTap: () => setState(() {
                          final first = group.first;
                          _rootEntryLevel = 'subject';
                          _selectedUniversity = first.displayUniversity;
                          _selectedDepartment = first.displayDepartment;
                          _selectedCourse = first.displayCourse;
                          _selectedCourseScope = first.courseScope;
                          _selectedSubject = _subjectFor(first, group.length);
                          _selectedFolders.clear();
                        }),
                      ),
                    ),
                  if (departmentCourses.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionTitle('Corsi del dipartimento',
                        subtitle: 'Senza materie: aprendoli vedi subito i file'),
                    const SizedBox(height: 10),
                    for (final items in departmentCourses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HierarchyCard(
                          icon: Icons.shield_outlined,
                          tone: SlTone.violet,
                          title: items.first.displayCourse,
                          subtitle: _materialCountText(items.length),
                          onTap: () => _openDirectCourse(items),
                        ),
                      ),
                  ],
                ] else if (shown.isEmpty)
                  _dispensePanel(
                    icon: Icons.menu_book_outlined,
                    title: showOwn
                        ? 'Nessun materiale per il tuo percorso'
                        : 'Nessun corso pubblico disponibile',
                    detail: showOwn
                        ? 'Controlla il percorso nel profilo oppure esplora i corsi pubblici.'
                        : 'Qui compariranno i file che StudentLab ha classificato e reso visibili nel catalogo.',
                    action: showOwn
                        ? OutlinedButton(
                            style: _secondaryButtonStyle(),
                            onPressed: () {
                              setState(() => _choosingBrowseCourse = true);
                              if (!_exploreAllPublicCourses) {
                                _exploreAllPublicCourses = true;
                                _loadMaterials();
                              }
                            },
                            child: const Text('Cambia percorso'),
                          )
                        : null,
                  )
                else
                  ...shown.map((items) {
                    final first = items.first;
                    final bool direct = items.every(
                        (m) => m.subjectName?.trim().isEmpty ?? true);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HierarchyCard(
                        icon: direct
                            ? Icons.shield_outlined
                            : (first.courseScope == 'additional'
                                ? Icons.auto_stories_outlined
                                : Icons.school_outlined),
                        tone: direct ? SlTone.violet : SlTone.info,
                        title: first.displayCourse,
                        subtitle: direct
                            ? 'Corso del dipartimento · ${_materialCountText(items.length)}'
                            : 'Percorso · ${_subjectCountText(items)}',
                        onTap: () => _openCourseFromRoot(items),
                      ),
                    );
                  }),
              ],
              ...[
                const SizedBox(height: 20),
                _sectionTitle(signedIn ? 'Sul dispositivo, da sistemare' : 'Sul dispositivo'),
                const SizedBox(height: 10),
                if ((signedIn ? deviceFiles.where(_isUnclassified).toList() : deviceFiles).isEmpty)
                  _dispensePanel(
                    icon: Icons.insert_drive_file_outlined,
                    title: 'Nessun file importato',
                    detail:
                        'Puoi aggiungere un file sul dispositivo anche senza un account.',
                  )
                else if (!signedIn)
                  _HierarchyCard(
                    icon: Icons.insert_drive_file_outlined,
                    tone: SlTone.neutral,
                    dashed: true,
                    title: '${deviceFiles.length} file importati',
                    subtitle:
                        deviceFiles.take(2).map((m) => m.originalName).join(', '),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: AppColors.eleganceDeepNavy,
                      builder: (sheetContext) => SafeArea(
                        child: ListView(shrinkWrap: true, children: [
                          for (final file in deviceFiles)
                            ListTile(
                              leading: Icon(Icons.insert_drive_file_outlined,
                                  color: AppColors.skyBlue),
                              title: Text(file.originalName,
                                  style: TextStyle(color: AppColors.pureWhite)),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _openMaterial(file);
                              },
                            ),
                        ]),
                      ),
                    ),
                  )
                else
                  ...deviceFiles.where(_isUnclassified).map((material) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _deviceFileCard(material),
                      )),
                const SizedBox(height: 8),
                if (signedIn)
                  OutlinedButton.icon(
                    style: _secondaryButtonStyle(),
                    onPressed: _openingOfflineForm ? null : _openOfflineMaterial,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Aggiungi un file dal dispositivo'),
                  ),
                if (!signedIn) ...[
                  FilledButton.icon(
                    style: _primaryButtonStyle(),
                    onPressed: _openingOfflineForm ? null : _openOfflineMaterial,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Aggiungi un file'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Per chiedere o pubblicare materiale serve un account.',
                    style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.56),
                        fontSize: 12),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Materia selezionabile a partire da un materiale di quella materia.
  _LocalSubject _subjectFor(MaterialLocal first, int count) {
    return _LocalSubject(
      id: first.subjectId == null
          ? ((first.subjectName?.trim().isEmpty ?? true)
              ? 'course:direct'
              : 'name:${first.subjectName!.trim().toLowerCase()}')
          : 'id:${first.subjectId}',
      subjectId: first.subjectId,
      name: (first.subjectName?.trim().isEmpty ?? true)
          ? 'Materiali del corso'
          : first.displaySubjectName,
      university: first.displayUniversity,
      department: first.displayDepartment,
      course: first.displayCourse,
      materialCount: count,
    );
  }

  /// Corso senza materie: si aprono subito i file.
  void _openDirectCourse(List<MaterialLocal> items) {
    final first = items.first;
    setState(() {
      _rootEntryLevel = 'subject';
      _selectedUniversity = first.displayUniversity;
      _selectedDepartment = first.displayDepartment;
      _selectedCourse = first.displayCourse;
      _selectedCourseScope = first.courseScope;
      _selectedSubject = _subjectFor(first, items.length);
      _selectedFolders.clear();
    });
  }

  /// Avviso dopo l'accesso: i file aggiunti da ospite ora sono nel tuo albero.
  Widget _buildClaimNotice(List<MaterialLocal> deviceFiles) {
    final int toClassify = deviceFiles
        .where((m) => m.subjectId == null && (m.subjectName?.trim().isNotEmpty ?? false))
        .length;
    final int count = _claimedGuestFiles;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.adminGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.adminGreen.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check_rounded, color: AppColors.adminGreen, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 file del dispositivo aggiunto al tuo albero'
                      : '$count file del dispositivo aggiunti al tuo albero',
                  style: TextStyle(
                      color: AppColors.pureWhite, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (toClassify > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    toClassify == 1
                        ? '1 è da classificare: lo trovi in Dispositivo.'
                        : '$toClassify sono da classificare: li trovi in Dispositivo.',
                    style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.66), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chiudi avviso',
            onPressed: () => setState(() => _claimedGuestFiles = 0),
            icon: Icon(Icons.close_rounded,
                size: 18, color: AppColors.pureWhite.withValues(alpha: 0.66)),
          ),
        ],
      ),
    );
  }

  int _offlineBytes(List<MaterialLocal> materials) => materials
      .map((m) => _offlineEntryFor(m)?.file.size ?? 0)
      .fold<int>(0, (sum, size) => sum + size);

  bool _isUnclassified(MaterialLocal material) =>
      material.source == MaterialSourceLocal.local &&
      material.subjectId == null &&
      (material.subjectName?.trim().isNotEmpty ?? false);

  String _subjectCountText(List<MaterialLocal> items) {
    final int count = items
        .where((m) => m.subjectName?.trim().isNotEmpty ?? false)
        .map((m) => m.displaySubjectName.toLowerCase())
        .toSet()
        .length;
    return count == 1 ? '1 materia' : '$count materie';
  }

  /// Apre un corso dalla home: i corsi senza materie mostrano subito i file.
  void _openCourseFromRoot(List<MaterialLocal> items) {
    if (items.every((m) => m.subjectName?.trim().isEmpty ?? true)) {
      _openDirectCourse(items);
      return;
    }
    final first = items.first;
    setState(() {
      _rootEntryLevel = 'course';
      _selectedUniversity = first.displayUniversity;
      _selectedDepartment = first.displayDepartment;
      _selectedCourse = first.displayCourse;
      _selectedCourseScope = first.courseScope;
      _selectedSubject = null;
      _selectedFolders.clear();
    });
  }

  /// File "solo tuo" sul dispositivo; se non è classificato, card tratteggiata
  /// con "Classifica" come nel canvas.
  Widget _deviceFileCard(MaterialLocal material) {
    final bool unclassified = _isUnclassified(material);
    return _HierarchyCard(
      icon: Icons.insert_drive_file_outlined,
      tone: unclassified ? SlTone.warning : SlTone.neutral,
      dashed: unclassified,
      title: material.originalName,
      subtitle: unclassified
          ? 'Aggiunto da ospite · solo tuo'
          : '${material.displayCourse} · ${material.displaySubjectName} · solo tuo',
      trailing: unclassified
          ? OutlinedButton(
              style: _secondaryButtonStyle(tone: SlTone.warning),
              onPressed: _processingMaterialIds.contains(material.id)
                  ? null
                  : () => _reconcileLocalPath(material),
              child: const Text('Classifica'),
            )
          : null,
      onTap: () => _openMaterial(material),
    );
  }

  /// Domande e "Com'è l'esame" della materia (sezione Domande).
  Widget _buildSubjectFaqLinks(_LocalSubject subject) {
    Widget link(IconData icon, SlTone tone, String title, String subtitle, Widget page) {
      return Expanded(
        child: Material(
          color: AppColors.eleganceMidnight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.12)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  SlIconTile(icon: icon, tone: tone, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          style: TextStyle(color: AppColors.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      link(Icons.forum_outlined, SlTone.cyan, 'Domande', 'Dubbi e risposte',
          FaqHomePage(subjectId: subject.subjectId, subjectName: subject.name)),
      const SizedBox(width: 8),
      link(Icons.event_note_outlined, SlTone.warning, 'Com’è l’esame', 'Racconti degli appelli',
          FaqExamPage(subjectId: subject.subjectId!, subjectName: subject.name)),
      const SizedBox(width: 8),
      link(Icons.edit_calendar_outlined, SlTone.danger, 'Appelli', 'Date e promemoria',
          CalendarHomePage(subjectId: subject.subjectId, subjectName: subject.name)),
    ]);
  }

  bool _isOnDevice(MaterialLocal material) =>
      material.source == MaterialSourceLocal.local ||
      _offlineEntryFor(material) != null;

  Widget _buildPathCard(List<MaterialLocal> ownFirstCourse) {
    final MaterialLocal? first =
        ownFirstCourse.isEmpty ? null : ownFirstCourse.first;
    final SocialAcademicPath? path = _browseCourseKey == null ? _currentPath : null;
    String pick(String code, String name) => code.trim().isNotEmpty && code.trim().length <= 8 ? code.trim() : name.trim();
    final chips = <String>[
      if (path != null) ...[
        pick(path.universityCode, path.university),
        pick(path.departmentCode, path.department),
        path.course,
        if (path.startYear != null) 'dal ${path.startYear}',
      ] else if (first != null) ...[
        first.displayUniversity,
        first.displayDepartment,
        first.displayCourse,
      ],
    ].where((c) => c.trim().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.materialSky.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('IL TUO PERCORSO',
                style: TextStyle(
                    color: AppColors.adminCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
            const Spacer(),
            TextButton(
              onPressed: () {
                final opening = !_choosingBrowseCourse;
                setState(() => _choosingBrowseCourse = opening);
                if (opening && !_exploreAllPublicCourses) {
                  _exploreAllPublicCourses = true;
                  _loadMaterials();
                }
              },
              child: Text(_choosingBrowseCourse ? 'Chiudi' : 'Cambia'),
            ),
          ]),
          if (_choosingBrowseCourse) ...[
            const SizedBox(height: 8),
            Text('Scegli il corso da visualizzare',
                style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.70), fontSize: 12)),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final options = _materials.where((m) => m.source != MaterialSourceLocal.local).toList();
              final universities = options.map((m) => m.displayUniversity).toSet().toList()..sort();
              final departments = options
                  .where((m) => _rootUniversityFilter == null || m.displayUniversity == _rootUniversityFilter)
                  .map((m) => m.displayDepartment).toSet().toList()..sort();
              final courses = options
                  .where((m) => (_rootUniversityFilter == null || m.displayUniversity == _rootUniversityFilter) &&
                      (_rootDepartmentFilter == null || m.displayDepartment == _rootDepartmentFilter))
                  .fold(<String, MaterialLocal>{}, (Map<String, MaterialLocal> result, MaterialLocal m) {
                    result.putIfAbsent(_courseKey(m.university, m.department, m.course), () => m);
                    return result;
                  }).values.toList()..sort((a, b) => a.displayCourse.compareTo(b.displayCourse));
              return Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                _dispenseFilter('Ateneo', _rootUniversityFilter, universities, (value) => setState(() {
                  _rootUniversityFilter = value;
                  _rootDepartmentFilter = null;
                })),
                _dispenseFilter('Dipartimento', _rootDepartmentFilter, departments,
                    (value) => setState(() => _rootDepartmentFilter = value)),
                _dispenseFilter('Corso', null, courses.map((m) => m.displayCourse).toList(), (value) {
                  if (value == null) return;
                  for (final course in courses) {
                    if (course.displayCourse != value) continue;
                    setState(() {
                      _browseCourseKey = _courseKey(course.university, course.department, course.course);
                      _choosingBrowseCourse = false;
                    });
                    break;
                  }
                }),
                if (_browseCourseKey != null)
                  TextButton(onPressed: () => setState(() {
                    _browseCourseKey = null;
                    _choosingBrowseCourse = false;
                  }), child: const Text('Il mio percorso')),
              ]);
            }),
          ],
          const SizedBox(height: 4),
          if (chips.isEmpty)
            Text(
              'Aggiungi il tuo percorso accademico al profilo per vedere qui le materie del corso.',
              style: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.4),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (int i = 0; i < chips.length; i++) ...[
                  if (i > 0)
                    Text('›',
                        style: TextStyle(
                            color: AppColors.pureWhite.withValues(alpha: 0.40))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: i == chips.length - 1
                          ? AppColors.skyBlue.withValues(alpha: 0.14)
                          : AppColors.eleganceMidnight,
                      borderRadius: BorderRadius.circular(8),
                      border: i == chips.length - 1
                          ? Border.all(color: AppColors.skyBlue.withValues(alpha: 0.34))
                          : null,
                    ),
                    child: Text(chips[i],
                        style: TextStyle(
                            color: i == chips.length - 1
                                ? AppColors.diamondDust
                                : AppColors.pureWhite,
                            fontSize: 13)),
                  ),
                ],
                if (_enrolledCourseKeys.length > 1)
                  Text('+${_enrolledCourseKeys.length - 1}',
                      style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.60),
                          fontSize: 12)),
              ],
            ),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _usingOfflineCache ? AppColors.adminAmber : AppColors.adminGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _usingOfflineCache
                    ? 'Stai vedendo i file salvati sul dispositivo'
                    : 'Offline pronto · dispense sincronizzate',
                style: TextStyle(
                    color: AppColors.pureWhite.withValues(alpha: 0.66),
                    fontSize: 12),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: AppColors.pureWhite,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.60),
                  fontSize: 12)),
        ],
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() => FilledButton.styleFrom(
        backgroundColor: AppColors.skyBlue,
        foregroundColor: AppColors.darkElegance,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      );

  ButtonStyle _secondaryButtonStyle({SlTone tone = SlTone.info}) {
    final Color color = tone == SlTone.warning ? AppColors.adminAmber : AppColors.diamondDust;
    final Color border = tone == SlTone.warning ? AppColors.adminAmber : AppColors.skyBlue;
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      side: BorderSide(color: border.withValues(alpha: 0.40)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  Widget _dispensePanel({
    required IconData icon,
    required String title,
    required String detail,
    Widget? action,
    bool elevated = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: elevated ? AppColors.eleganceDeepNavy : AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: elevated
              ? AppColors.materialSky.withValues(alpha: 0.30)
              : AppColors.skyBlue.withValues(alpha: 0.14),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          SlIconTile(icon: icon, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(detail,
            style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.70),
                fontSize: 12,
                height: 1.5)),
        if (action != null) ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: action),
        ],
      ]),
    );
  }

  /// Filtro a "chip" con menu: stesso comportamento del vecchio menu a tendina.
  Widget _dispenseFilter(String label, String? selected, List<String> options,
      ValueChanged<String?> onChange, {bool dashed = false}) {
    final bool active = selected != null && !dashed;
    return PopupMenuButton<String>(
      tooltip: label,
      color: AppColors.eleganceDeepNavy,
      onSelected: (value) => onChange(value.isEmpty ? null : value),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: '', child: Text(label)),
        ...options.map((option) =>
            PopupMenuItem<String>(value: option, child: Text(option))),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.skyBlue.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.skyBlue.withValues(alpha: 0.40)
                : AppColors.pureWhite.withValues(alpha: 0.24),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(selected ?? label,
              style: TextStyle(
                  color: active
                      ? AppColors.diamondDust
                      : AppColors.pureWhite.withValues(alpha: 0.72),
                  fontSize: 13)),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active
                  ? AppColors.diamondDust
                  : AppColors.pureWhite.withValues(alpha: 0.72)),
        ]),
      ),
    );
  }

  Widget _buildDepartmentPage() {
    return _buildHierarchyList(
      title: 'Dipartimenti',
      children: _departments.map((String department) {
        return _HierarchyCard(
          icon: Icons.apartment_rounded,
          title: department,
          subtitle: _materialCountText(_countDepartment(department)),
          onTap: () {
            setState(() {
              _selectedDepartment = department;
              _selectedCourse = null;
              _selectedSubject = null;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildCoursePage() {
    final cards = <Widget>[];
    for (final scope in const <String>['degree', 'additional']) {
      for (final course in _courses) {
        final count = _countCourse(course, scope);
        if (count == 0) continue;
        cards.add(_HierarchyCard(
          icon: scope == 'degree' ? Icons.school_rounded : Icons.auto_stories_outlined,
          tone: scope == 'degree' ? SlTone.info : SlTone.violet,
          title: course,
          subtitle:
              '${scope == 'degree' ? 'Corso di laurea' : 'Corso aggiuntivo'} · ${_materialCountText(count)}',
          onTap: () => setState(() {
            _selectedCourse = course;
            _selectedCourseScope = scope;
            _selectedSubject = null;
            _selectedFolders.clear();
          }),
        ));
      }
    }
    return _buildHierarchyList(title: 'Corsi', children: cards);
  }

  Widget _buildSubjectPage() {
    final List<_LocalSubject> subjects = _subjects;
    if (subjects.isEmpty) {
      return Center(
        child: _buildEmptyHierarchy('Nessuna materia disponibile.'),
      );
    }
    return _buildHierarchyList(
      title: 'Materie',
      breadcrumb: '${_selectedDepartment ?? ''} › ${_selectedCourse ?? ''}',
      children: subjects.map((_LocalSubject subject) {
        final bool direct = subject.id == 'course:direct';
        return _HierarchyCard(
          icon: direct ? Icons.folder_open_rounded : Icons.menu_book_rounded,
          tone: direct ? SlTone.violet : SlTone.info,
          title: subject.name,
          subtitle: direct
              ? 'File senza materia · ${_materialCountText(subject.materialCount)}'
              : _materialCountText(subject.materialCount),
          onTap: () {
            setState(() {
              _selectedSubject = subject;
              _selectedFolders.clear();
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildHierarchyList({
    required List<Widget> children,
    String? title,
    String? breadcrumb,
  }) {
    return RefreshIndicator(
      onRefresh: _loadMaterials,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            children: [
              if (breadcrumb != null) ...[
                Text(breadcrumb,
                    style: TextStyle(color: AppColors.materialSky, fontSize: 12)),
                const SizedBox(height: 10),
              ],
              if (title != null) ...[
                _sectionTitle(title),
                const SizedBox(height: 10),
              ],
              if (children.isEmpty)
                _buildEmptyHierarchy('Nessun contenuto disponibile.')
              else
                for (final child in children)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildMaterialPage() {
    final _LocalSubject subject = _selectedSubject!;
    final List<MaterialLocal> materials = _selectedMaterials;
    final int depth = _selectedFolders.length;
    final matching = materials.where((material) {
      if (material.pathSegments.length < depth) return false;
      for (int i = 0; i < depth; i++) {
        if (material.pathSegments[i] != _selectedFolders[i]) return false;
      }
      return true;
    }).toList();
    final folders = matching
        .where((material) => material.pathSegments.length > depth)
        .map((material) => material.pathSegments[depth])
        .toSet()
        .toList()
      ..sort();
    final allVisibleFiles =
        matching.where((material) => material.pathSegments.length == depth).toList();
    final visibleFiles = _fileOrder == 'offline'
        ? allVisibleFiles.where(_isOnDevice).toList()
        : List<MaterialLocal>.of(allVisibleFiles);
    if (_fileOrder == 'name') {
      visibleFiles.sort((a, b) =>
          a.originalName.toLowerCase().compareTo(b.originalName.toLowerCase()));
    }
    final bool direct = subject.id == 'course:direct';
    final String folderLabel = depth == 0
        ? (direct ? 'Cartelle' : 'Argomenti')
        : 'Cartelle';
    final String filesTitle = depth == 0
        ? (folders.isNotEmpty && !direct ? 'File della materia' : 'Materiali')
        : 'File in questa cartella';
    final duplicates = depth == 0 ? _duplicateGroups(materials) : const <_DuplicatePair>[];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: _loadMaterials,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            children: [
              Text(
                <String>[
                  subject.course,
                  if (!direct) subject.name,
                  ..._selectedFolders,
                ].join(' › '),
                style: TextStyle(color: AppColors.materialSky, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _buildSubjectHeader(subject, materials),
              const SizedBox(height: 12),
              _buildSourceSummary(materials),
              if (subject.subjectId != null && depth == 0) ...[
                const SizedBox(height: 12),
                _buildSubjectFaqLinks(subject),
              ],
              if (folders.isNotEmpty) ...[
                const SizedBox(height: 18),
                _sectionTitle(folderLabel),
                const SizedBox(height: 8),
                ...folders.map((folder) {
                  final inFolder = matching
                      .where((m) => m.pathSegments.length > depth &&
                          m.pathSegments[depth] == folder)
                      .toList();
                  final int onDevice = inFolder.where(_isOnDevice).length;
                  final String status = onDevice == inFolder.length
                      ? 'tutto offline'
                      : (onDevice == 0 ? 'da scaricare' : '$onDevice di ${inFolder.length} offline');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HierarchyCard(
                      icon: Icons.folder_outlined,
                      title: folder,
                      subtitle: '${_materialCountText(inFolder.length)} · $status',
                      onTap: () => setState(() => _selectedFolders.add(folder)),
                    ),
                  );
                }),
              ],
              for (final pair in duplicates) ...[
                const SizedBox(height: 12),
                _buildDuplicateCard(pair),
              ],
              const SizedBox(height: 20),
              _sectionTitle(
                filesTitle,
                subtitle: depth == 0 && direct
                    ? '${_materialCountText(allVisibleFiles.length)} · nessuna materia, li trovi tutti qui'
                    : (depth == 0 && folders.isNotEmpty
                        ? 'Non appartengono a un argomento'
                        : _materialCountText(allVisibleFiles.length)),
              ),
              const SizedBox(height: 10),
              if (allVisibleFiles.length > 1) ...[
                SlFilterBar<String>(
                  selected: _fileOrder,
                  options: const <SlFilterOption<String>>[
                    SlFilterOption(value: 'recent', label: 'Recenti'),
                    SlFilterOption(value: 'name', label: 'Nome'),
                    SlFilterOption(value: 'offline', label: 'Solo offline'),
                  ],
                  onSelected: (value) => setState(() => _fileOrder = value),
                ),
                const SizedBox(height: 10),
              ],
              if (visibleFiles.isEmpty && folders.isEmpty && _fileOrder != 'offline')
                _buildEmptyMaterials()
              else if (visibleFiles.isEmpty && _fileOrder == 'offline')
                Text('Nessun file di questa cartella è ancora offline.',
                    style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 12))
              else
                ...visibleFiles.map(_buildMaterialEntry),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // File
  // ---------------------------------------------------------------------------

  String _fileKind(MaterialLocal material, MaterialOfflineEntry? offline) {
    switch (_materialType(material, offline)) {
      case 'PDF':
        return 'PDF';
      case 'PPTX':
        return 'PPT';
      case 'Document':
        return 'DOC';
      case 'Image':
        return 'IMG';
      case 'ZIP':
        return 'ZIP';
      default:
        return 'FILE';
    }
  }

  Widget _buildMaterialEntry(MaterialLocal material) {
    final MaterialOfflineEntry? offline = _offlineEntryFor(material);
    final bool isOffline = offline != null;
    final bool isLocal = material.source == MaterialSourceLocal.local;
    final bool personalSynced = material.source == MaterialSourceLocal.personalSync;
    final bool shared = material.source == MaterialSourceLocal.sharedUser;
    final bool sharedPending = shared && material.remoteStatus == 'pending';
    final bool signedIn = _authSession.isAuthenticated;
    final bool processing =
        material.id != null && _processingMaterialIds.contains(material.id);

    final meta = <String>[
      _provenanceLabel(material.source),
      if (offline != null) _formatSize(offline.file.size),
      if (!isLocal) (isOffline ? 'offline' : 'solo online'),
      if (material.source == MaterialSourceLocal.group && material.groupId != null)
        'gruppo ${material.groupId}',
      if (material.remoteVersion != null && !isLocal) 'v${material.remoteVersion}',
    ];
    final badges = <Widget>[
      if (_isPreferredMaterial(material))
        const SlStatusBadge(label: 'Principale', tone: SlTone.info),
      if (isLocal) const SlStatusBadge(label: 'Solo tuo', tone: SlTone.private),
      if (material.source == MaterialSourceLocal.teacher)
        const SlStatusBadge(label: 'Docente', tone: SlTone.violet, icon: Icons.verified_rounded),
      if (personalSynced) const SlStatusBadge(label: 'Sincronizzato', tone: SlTone.cyan),
      if (sharedPending) const SlStatusBadge(label: 'Da accettare', tone: SlTone.warning),
      if (material.cloudExpiresAt != null)
        SlStatusBadge(label: _cloudExpiryLabel(material.cloudExpiresAt!), tone: SlTone.warning),
    ];

    void onPrimaryTap() {
      if (processing) return;
      if (isOffline || isLocal) {
        _openMaterial(material);
      } else if (sharedPending) {
        _acceptSharedMaterial(material);
      } else {
        _downloadWithDuplicateChoice(material);
      }
    }

    // Azione principale a destra: aperto/offline, scarica, accetta.
    Widget trailing;
    if (processing) {
      trailing = SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.skyBlue),
          ),
        ),
      );
    } else if (isOffline || isLocal) {
      trailing = IconButton(
        tooltip: 'Apri',
        onPressed: () => _openMaterial(material),
        icon: Icon(Icons.check_rounded, color: AppColors.adminGreen),
      );
    } else if (sharedPending) {
      trailing = IconButton(
        tooltip: 'Accetta e scarica',
        onPressed: () => _acceptSharedMaterial(material),
        icon: Icon(Icons.download_done_outlined, color: AppColors.adminAmber),
      );
    } else {
      trailing = IconButton(
        tooltip: 'Scarica offline',
        onPressed: () => _downloadWithDuplicateChoice(material),
        style: IconButton.styleFrom(
          side: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.24)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        icon: Icon(Icons.download_rounded, color: AppColors.skyBlue),
      );
    }

    // Tutte le altre azioni di prima, raccolte nel menu "Altre azioni".
    final actions = <PopupMenuEntry<String>>[
      if (isOffline && !isLocal) const PopupMenuItem(value: 'open', child: Text('Apri')),
      if (isOffline && !isLocal)
        const PopupMenuItem(value: 'removeOffline', child: Text('Rimuovi offline')),
      if (!isOffline && !isLocal && !sharedPending)
        const PopupMenuItem(value: 'download', child: Text('Scarica')),
      if (sharedPending)
        const PopupMenuItem(value: 'accept', child: Text('Accetta e scarica')),
      if (isLocal && signedIn) ...[
        const PopupMenuItem(value: 'publish', child: Text('Proponi a StudentLab')),
        const PopupMenuItem(value: 'sync', child: Text('Sincronizza')),
        const PopupMenuItem(value: 'share', child: Text('Condividi con uno studente')),
      ],
      if (isLocal &&
          material.subjectId == null &&
          (material.subjectName?.trim().isNotEmpty ?? false))
        const PopupMenuItem(value: 'reconcile', child: Text('Cerca materia nel catalogo')),
      if (isLocal && signedIn && material.courseScope == 'additional' && material.subjectId == null)
        const PopupMenuItem(value: 'proposeCourse', child: Text('Proponi il corso per la pubblicazione')),
      if (isLocal) const PopupMenuItem(value: 'delete', child: Text('Elimina')),
    ];

    void runAction(String value) {
      switch (value) {
        case 'open':
          _openMaterial(material);
        case 'removeOffline':
          _removeRemoteDownload(material);
        case 'download':
          _downloadWithDuplicateChoice(material);
        case 'accept':
          _acceptSharedMaterial(material);
        case 'publish':
          if (!_openingPublicationForm) _openPublicationForMaterial(material);
        case 'sync':
          _syncPersonalMaterial(material);
        case 'share':
          _shareMaterial(material);
        case 'reconcile':
          _reconcileLocalPath(material);
        case 'proposeCourse':
          _proposeCourse(material);
        case 'delete':
          _confirmDeleteMaterial(material);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.eleganceMidnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.10)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPrimaryTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              children: [
                SlFileTile(kind: _fileKind(material, offline), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.originalName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta.join(' · '),
                        style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.60),
                          fontSize: 11,
                        ),
                      ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: badges),
                      ],
                    ],
                  ),
                ),
                trailing,
                if (actions.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'Altre azioni',
                    enabled: !processing,
                    color: AppColors.eleganceDeepNavy,
                    icon: Icon(Icons.more_vert_rounded,
                        color: AppColors.pureWhite.withValues(alpha: 0.72)),
                    onSelected: runAction,
                    itemBuilder: (_) => actions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Duplicati: stessa impronta SHA-256 tra una copia tua e una del catalogo
  // ---------------------------------------------------------------------------

  List<_DuplicatePair> _duplicateGroups(List<MaterialLocal> materials) {
    final byHash = <String, List<MaterialLocal>>{};
    for (final material in materials) {
      final hash = (material.remoteFileHash ?? _offlineEntryFor(material)?.fileHash)
          ?.toLowerCase();
      if (hash == null || hash.isEmpty || material.id == null) continue;
      byHash.putIfAbsent(hash, () => <MaterialLocal>[]).add(material);
    }
    final pairs = <_DuplicatePair>[];
    byHash.forEach((hash, items) {
      final local = items.where((m) => m.source == MaterialSourceLocal.local).toList();
      final remote = items.where((m) => m.source != MaterialSourceLocal.local).toList();
      if (local.isEmpty || remote.isEmpty) return;
      // Mostriamo la scelta solo finché non è stata presa (o rimandata con
      // "Tienile entrambe" in questa sessione).
      if (!_preferredByHash.containsKey(hash) &&
          !_dismissedDuplicateHashes.contains(hash)) {
        pairs.add(_DuplicatePair(hash: hash, mine: local.first, catalog: remote.first));
      }
    });
    return pairs;
  }

  Widget _buildDuplicateCard(_DuplicatePair pair) {
    // Scelta locale (radio) finché non si preme "Tieni una copia".
    final int keepId = _duplicateChoice[pair.hash] ?? pair.catalog.id!;
    final MaterialLocal keep = keepId == pair.mine.id ? pair.mine : pair.catalog;
    final MaterialLocal other = identical(keep, pair.mine) ? pair.catalog : pair.mine;
    final int? freed = _offlineEntryFor(other)?.file.size;

    Widget option(MaterialLocal material, String subtitle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SlChoiceTile(
          title: material.originalName,
          description: subtitle,
          selected: material.id == keepId,
          onTap: () => setState(() => _duplicateChoice[pair.hash] = material.id!),
        ),
      );
    }

    final ButtonStyle outline = OutlinedButton.styleFrom(
      foregroundColor: AppColors.pureWhite.withValues(alpha: 0.86),
      minimumSize: const Size(0, 42),
      side: BorderSide(color: AppColors.pureWhite.withValues(alpha: 0.14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: const TextStyle(fontSize: 13),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.adminAmber.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const SlIconTile(icon: Icons.content_copy_rounded, tone: SlTone.warning, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hai questo file due volte',
                      style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Stesso contenuto, due copie offline',
                      style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.66),
                          fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          option(pair.catalog, '${_provenanceLabel(pair.catalog.source)} · riceve gli aggiornamenti'),
          option(pair.mine, 'La tua copia · aggiunta dal dispositivo'),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: outline,
                onPressed: () => _keepBothCopies(pair.hash),
                child: const Text('Tienile entrambe'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.skyBlue,
                  foregroundColor: AppColors.darkElegance,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: () => _keepOneCopy(pair.hash, keep, other),
                child: const Text('Tieni una copia'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            freed == null
                ? 'L’altra copia verrà rimossa solo da questo dispositivo.'
                : 'L’altra copia verrà rimossa solo da questo dispositivo, libererai ${_formatSize(freed)}.',
            style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.56), fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// "Tieni una copia": la copia scelta diventa principale e l'altra lascia
  /// il dispositivo. Una tua copia locale si elimina solo dopo la conferma
  /// già usata dall'app; la copia offline del catalogo si può riscaricare.
  Future<void> _keepOneCopy(String hash, MaterialLocal keep, MaterialLocal other) async {
    await _choosePreferred(hash, keep);
    if (!mounted) return;
    if (other.source == MaterialSourceLocal.local) {
      await _confirmDeleteMaterial(other);
    } else if (_offlineEntryFor(other) != null) {
      await _removeRemoteDownload(other);
    }
  }

  Future<void> _choosePreferred(String hash, MaterialLocal material) async {
    if (material.id == null) return;
    await _preferenceService.choose(
        userId: _downloadService.currentLocalUserId,
        hash: hash,
        materialId: material.id!);
    if (!mounted) return;
    setState(() => _preferredByHash[hash] = material.id!);
    _showMessage('“${material.originalName}” è ora la copia principale.');
  }

  Future<void> _keepBothCopies(String hash) async {
    await _preferenceService.keepBoth(
        userId: _downloadService.currentLocalUserId, hash: hash);
    if (mounted) {
      setState(() {
        _preferredByHash.remove(hash);
        _dismissedDuplicateHashes.add(hash);
      });
    }
  }

  /// Scarica offline, uno dopo l'altro, i file della materia non ancora
  /// presenti sul dispositivo. Ogni download passa dal controllo duplicati.
  Future<void> _downloadRemaining(List<MaterialLocal> materials) async {
    if (_downloadingAll) return;
    final pending = materials
        .where((m) =>
            m.source != MaterialSourceLocal.local &&
            m.isAvailableRemote &&
            _offlineEntryFor(m) == null &&
            !(m.source == MaterialSourceLocal.sharedUser && m.remoteStatus == 'pending'))
        .toList();
    if (pending.isEmpty) return;
    setState(() => _downloadingAll = true);
    try {
      for (final material in pending) {
        if (!mounted) return;
        await _downloadWithDuplicateChoice(material);
      }
    } finally {
      if (mounted) setState(() => _downloadingAll = false);
    }
  }

  Widget _buildSourceSummary(List<MaterialLocal> materials) {
    final Map<MaterialSourceLocal, int> counts = {
      for (final MaterialSourceLocal source in MaterialSourceLocal.values) source: 0,
    };
    for (final MaterialLocal material in materials) {
      counts[material.source] = (counts[material.source] ?? 0) + 1;
    }
    final List<MaterialSourceLocal> visible = counts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }
    final int onDevice = materials.where(_isOnDevice).length;
    Widget chip(Widget icon, String text, {bool good = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: good
                ? AppColors.adminGreen.withValues(alpha: 0.08)
                : AppColors.eleganceMidnight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: good
                  ? AppColors.adminGreen.withValues(alpha: 0.24)
                  : AppColors.pureWhite.withValues(alpha: 0.08),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(
                  color: good
                      ? AppColors.adminGreen
                      : AppColors.pureWhite.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ]),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...visible.map((MaterialSourceLocal source) => chip(
            _provenanceIcon(source), '${_provenanceLabel(source)} · ${counts[source] ?? 0}')),
        chip(Icon(Icons.offline_pin_rounded, size: 14, color: AppColors.adminGreen),
            '$onDevice di ${materials.length} offline',
            good: onDevice == materials.length),
      ],
    );
  }
  MaterialOfflineEntry? _offlineEntryFor(MaterialLocal material) {
    for (final MaterialOfflineEntry entry in _offlineMaterials) {
      if (material.id != null && entry.material.id == material.id) {
        return entry;
      }

      if (material.remoteKey != null &&
          material.remoteKey == entry.material.remoteKey) {
        return entry;
      }
    }

    return null;
  }

  Future<void> _confirmDeleteMaterial(MaterialLocal material) async {
    final TextEditingController confirmation = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, updateDialog) => AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: Text(
            'Elimina materiale',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Vuoi eliminare "${material.originalName}" dalla libreria locale? Scrivi ELIMINA per confermare.',
              style: TextStyle(color: AppColors.white70)),
            const SizedBox(height: 12),
            TextField(controller: confirmation,
              onChanged: (_) => updateDialog(() {}),
              style: TextStyle(color: AppColors.pureWhite),
              decoration: const InputDecoration(labelText: 'ELIMINA')),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: confirmation.text == 'ELIMINA' ? () {
                Navigator.of(dialogContext).pop(true);
              } : null,
              child: Text(
                'Elimina',
                style: TextStyle(color: AppColors.redAccent),
              ),
            ),
          ],
        ));
      },
    );
    confirmation.dispose();

    if (confirmed != true || material.id == null) {
      return;
    }

    _setMaterialProcessing(material, true);

    try {
      await _downloadService.removeMaterialDownloadV6(material);

      if (material.source == MaterialSourceLocal.local) {
        await _materialRepository.deleteLocal(material.id!);
      }

      await _loadMaterials();

      if (!mounted) {
        return;
      }

      _showMessage(
        material.source == MaterialSourceLocal.local
            ? 'Materiale personale eliminato.'
            : 'Download rimosso. Il materiale resta disponibile online.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _friendlyMaterialError(
          error,
          fallback: 'Non è stato possibile eliminare il materiale.',
        ),
      );
    } finally {
      _setMaterialProcessing(material, false);
    }
  }

  Future<void> _removeRemoteDownload(MaterialLocal material) async {
    if (material.source == MaterialSourceLocal.local || material.id == null) {
      return;
    }

    _setMaterialProcessing(material, true);

    try {
      await _downloadService.removeMaterialDownloadV6(material);
      await _loadMaterials();

      if (!mounted) {
        return;
      }

      _showMessage('Download rimosso. Il materiale resta disponibile online.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _friendlyMaterialError(
          error,
          fallback: 'Non è stato possibile rimuovere il download.',
        ),
      );
    } finally {
      _setMaterialProcessing(material, false);
    }
  }

  Future<void> _downloadWithDuplicateChoice(MaterialLocal remote) async {
    final hash = remote.remoteFileHash?.toLowerCase();
    if (hash == null || hash.isEmpty) {
      await _downloadRemoteMaterial(remote);
      return;
    }
    MaterialOfflineEntry? existing;
    for (final entry in _offlineMaterials) {
      if (entry.material.source == MaterialSourceLocal.local &&
          entry.fileHash?.toLowerCase() == hash) {
        existing = entry;
        break;
      }
    }
    if (existing == null || !mounted) {
      await _downloadRemoteMaterial(remote);
      return;
    }
    final local = existing.material;
    final String? choice = await showDialog<String>(context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text('Possibile duplicato',
          style: TextStyle(color: AppColors.pureWhite)),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Il contenuto dei due file ha lo stesso hash SHA-256.',
              style: TextStyle(color: AppColors.white70)),
            const SizedBox(height: 12),
            Text('IL TUO FILE: ${local.originalName}',
              style: TextStyle(color: AppColors.pureWhite)),
            Text('Offline · ${existing!.size ?? 0} byte · ${existing.mimeType ?? 'File'}',
              style: TextStyle(color: AppColors.white60)),
            TextButton.icon(onPressed: () => Navigator.pop(dialogContext, 'openLocal'),
              icon: const Icon(Icons.open_in_new), label: const Text('Apri il mio')),
            const SizedBox(height: 12),
            Text('STUDENTLAB: ${remote.originalName}',
              style: TextStyle(color: AppColors.pureWhite)),
            Text('Online · puoi scaricarlo e aprirlo',
              style: TextStyle(color: AppColors.white60)),
            TextButton.icon(onPressed: () => Navigator.pop(dialogContext, 'openRemote'),
              icon: const Icon(Icons.open_in_new), label: const Text('Apri StudentLab')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'mine'),
            child: const Text('Usa il mio')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'both'),
            child: const Text('Conserva entrambi')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'remote'),
            child: const Text('Usa StudentLab')),
        ],
      ));
    if (!mounted) return;
    if (choice == 'mine' || choice == 'openLocal') {
      if (choice == 'mine' && local.id != null) {
        await _preferenceService.choose(userId: _downloadService.currentLocalUserId,
          hash: hash, materialId: local.id!);
        if (mounted) setState(() => _preferredByHash[hash] = local.id!);
      }
      _showMessage('La copia StudentLab resta disponibile online nel catalogo.');
      await _openMaterial(local);
      return;
    }
    if (choice == 'both' || choice == 'remote' || choice == 'openRemote') {
      await _downloadRemoteMaterial(remote);
      if (!mounted) return;
      if (choice == 'both') {
        await _preferenceService.keepBoth(
          userId: _downloadService.currentLocalUserId, hash: hash);
        if (mounted) setState(() => _preferredByHash.remove(hash));
      } else if (choice == 'remote' && remote.id != null) {
        await _preferenceService.choose(userId: _downloadService.currentLocalUserId,
          hash: hash, materialId: remote.id!);
        if (mounted) setState(() => _preferredByHash[hash] = remote.id!);
      }
      if (choice == 'remote' && mounted) {
        final bool? deleteLocal = await showDialog<bool>(context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.eleganceDeepNavy,
            title: Text('Conservare il tuo file?',
              style: TextStyle(color: AppColors.pureWhite)),
            content: Text('Il file "${local.originalName}" resta nella tua libreria. Vuoi eliminarlo?',
              style: TextStyle(color: AppColors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Conserva')),
              TextButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continua con eliminazione')),
            ],
          ));
        if (deleteLocal == true && mounted) await _confirmDeleteMaterial(local);
      }
    }
  }

  Future<void> _downloadRemoteMaterial(MaterialLocal material) async {
    if (material.source == MaterialSourceLocal.local ||
        material.remoteId == null ||
        material.remoteId! <= 0) {
      return;
    }

    _setMaterialProcessing(material, true);

    try {
      final MaterialLocal downloaded = await _downloadService.downloadMaterial(
        userId: material.userId,
        source: material.source,
        materialId: material.remoteId!,
        groupId: material.groupId,
        university: material.university,
        department: material.department,
        course: material.course,
        subjectId: material.subjectId,
        subjectName: material.subjectName,
        originalName: material.originalName,
        remoteVersion: material.remoteVersion,
        remoteStatus: material.remoteStatus ?? 'active',
      );

      await _loadMaterials();

      if (!mounted) {
        return;
      }

      _showMessage('Materiale disponibile offline.');
      await _openMaterial(downloaded);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_friendlyDownloadError(error));
    } finally {
      _setMaterialProcessing(material, false);
    }
  }

  void _setMaterialProcessing(MaterialLocal material, bool processing) {
    final int? id = material.id;

    if (!mounted || id == null) {
      return;
    }

    setState(() {
      if (processing) {
        _processingMaterialIds.add(id);
      } else {
        _processingMaterialIds.remove(id);
      }
    });
  }

  final Map<int, Map<String, dynamic>> _materialRequestOptions = {};

  Future<_LocalSubject?> _selectSubjectForMaterialRequest() async {
    List<Map<String, dynamic>> options;
    try {
      options = await _apiService.getMaterialRequestSubjects();
    } catch (e) {
      _showMessage(_friendlyError(e));
      return null;
    }
    if (!mounted) return null;
    _materialRequestOptions
      ..clear()
      ..addEntries(options.map((option) => MapEntry(
        int.parse(option['subject_id'].toString()), option)));
    final subjects = options.map((option) => _LocalSubject(
      id: 'id:${option['subject_id']}',
      subjectId: int.parse(option['subject_id'].toString()),
      name: option['subject_name']?.toString() ?? 'Materia',
      university: option['university']?.toString() ?? '',
      department: option['department']?.toString() ?? '',
      course: option['course']?.toString() ?? '',
      materialCount: 0,
    )).toList();

    if (subjects.isEmpty) {
      _showMessage(
        'Non ci sono ancora materie disponibili per inviare una richiesta.',
      );
      return null;
    }

    return showModalBottomSheet<_LocalSubject>(
      context: context,
      backgroundColor: AppColors.eleganceDeepNavy,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Seleziona la materia',
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.pureWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Scegli la materia per la quale vuoi richiedere un materiale.',
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppColors.pureWhite.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final _LocalSubject subject = subjects[index];
                      final details = _materialRequestOptions[subject.subjectId] ?? {};
                      final year = details['study_year'];
                      final teacherNames = ((details['teachers'] as List?) ?? [])
                        .map((teacher) => (teacher as Map)['name']?.toString() ?? '')
                        .where((name) => name.isNotEmpty).join(', ');
                      final recipient = details['recipient_kind'] == 'studentlab'
                        ? 'StudentLab' : teacherNames;
                      return ListTile(
                        leading: Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.materialSky,
                        ),
                        title: Text(
                          subject.name,
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${subject.course} · ${subject.department} · '
                          '${year == null ? 'Anno non specificato' : '$year° anno'} · $recipient',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.pureWhite.withValues(alpha: 0.54),
                            fontSize: 11,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.pureWhite,
                        ),
                        onTap: () => Navigator.pop(sheetContext, subject),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestTeacherMaterialFromLibrary() async {
    final _LocalSubject? subject = await _selectSubjectForMaterialRequest();
    if (subject == null || !mounted) {
      return;
    }
    await _requestTeacherMaterial(subject);
  }

  void _openRequestsFromLibrary() => _openRequests();

  void _openRequests() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MaterialRequestsPage(
        initialSubjectId: _selectedSubject?.subjectId,
        initialSubjectName: _selectedSubject?.name,
        hasTeacherMaterials: _selectedSubject?.subjectId != null && _materials.any(
          (material) => material.subjectId == _selectedSubject!.subjectId &&
            material.source == MaterialSourceLocal.teacher && material.isAvailableRemote),
      ),
    ));
  }

  Widget _buildMaterialActions() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: DeveloperUiStyle.panelDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('La tua biblioteca', style: TextStyle(
          color: AppColors.pureWhite, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(
          'Aggiungi e organizza i tuoi materiali sul dispositivo e consulta quelli disponibili nel catalogo StudentLab.',
          style: TextStyle(
            color: AppColors.pureWhite.withValues(alpha: 0.60),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: _openingOfflineForm ? null : _openOfflineMaterial,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi materiale'),
          ),
          if (_authSession.isAuthenticated) ...[
            OutlinedButton.icon(onPressed: () {
              setState(() => _exploreAllPublicCourses = !_exploreAllPublicCourses);
              _loadMaterials();
            }, icon: Icon(_exploreAllPublicCourses ? Icons.school_outlined : Icons.explore_outlined),
              label: Text(_exploreAllPublicCourses ? 'Solo i miei corsi' : 'Esplora corsi pubblici')),
            OutlinedButton.icon(
              onPressed: _openingPublicationForm ? null : _openPublication,
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Pubblica materiale'),
            ),
            OutlinedButton.icon(
              onPressed: _openRequestsFromLibrary,
              icon: const Icon(Icons.people_outline_rounded),
              label: const Text('Richieste e condivisioni'),
            ),
          ],
        ]),
        if (!_authSession.isAuthenticated) ...[
          const SizedBox(height: 14),
          Text(
            'Accedendo a StudentLab potrai proporre e pubblicare materiali, condividerli con altri studenti, inviare richieste di materiale e utilizzare le funzioni disponibili per il tuo percorso di studi. Puoi continuare ad aggiungere e consultare i tuoi file locali anche senza effettuare l’accesso.',
            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.72),
              fontSize: 12,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: DeveloperUiStyle.panelDecoration(),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.brandNightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: loading
                  ? Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.skyBlue,
                      ),
                    )
                  : Icon(icon, color: AppColors.skyBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppColors.pureWhite.withValues(alpha: 0.50),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.white38),
          ],
        ),
      ),
    );
  }

  Future<void> _openOfflineMaterial() async {
    if (_openingOfflineForm) {
      return;
    }

    setState(() {
      _openingOfflineForm = true;
    });

    try {
      final bool? imported = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _LocalMaterialImportPage(
            importService: _localImportService,
            apiService: _apiService,
            existingMaterials: _offlineMaterials,
            initialUniversity: _selectedUniversity,
            initialDepartment: _selectedDepartment,
            initialCourse: _selectedCourse,
            initialSubject: _selectedSubject?.name,
          ),
        ),
      );

      if (imported != true || !mounted) {
        return;
      }

      await _loadMaterials();

      if (!mounted) {
        return;
      }

      _showMessage('Materiale aggiunto alle dispense offline.');
    } finally {
      if (mounted) {
        setState(() {
          _openingOfflineForm = false;
        });
      }
    }
  }

  Future<void> _openPublication() async {
    if (!_authSession.isAuthenticated) {
      return;
    }

    await _openPublicationPage();
  }

  Future<void> _openPublicationForMaterial(MaterialLocal material) async {
    if (!_authSession.isAuthenticated ||
        material.source != MaterialSourceLocal.local) {
      return;
    }

    final String? filePath = await _downloadService.getFileForMaterial(
      material,
    );

    if (!mounted) {
      return;
    }

    if (filePath == null) {
      _showMessage('Il file non è più disponibile sul dispositivo.');
      return;
    }

    await _openPublicationPage(
      initialFilePath: filePath,
      initialFileName: material.originalName,
      initialUniversity: material.university,
      initialDepartment: material.department,
      initialCourse: material.course,
      initialSubjectId: material.subjectId,
      initialSubjectName: material.subjectName,
    );
  }

  Future<void> _openPublicationPage({
    String? initialFilePath,
    String? initialFileName,
    String? initialUniversity,
    String? initialDepartment,
    String? initialCourse,
    int? initialSubjectId,
    String? initialSubjectName,
  }) async {
    if (_openingPublicationForm || !mounted) {
      return;
    }

    setState(() {
      _openingPublicationForm = true;
    });

    bool? submitted;

    try {
      submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _MaterialPublicationPage(
            apiService: _apiService,
            initialFilePath: initialFilePath,
            initialFileName: initialFileName,
            initialUniversity: initialUniversity,
            initialDepartment: initialDepartment,
            initialCourse: initialCourse,
            initialSubjectId: initialSubjectId,
            initialSubjectName: initialSubjectName,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingPublicationForm = false;
        });
      }
    }

    if (!mounted || submitted != true) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _showMessage('Materiale inviato. La proposta è ora in revisione.');
    });
  }

  Widget _buildSubjectHeader(_LocalSubject subject, [List<MaterialLocal>? materials]) {
    final list = materials ?? const <MaterialLocal>[];
    final bool direct = subject.id == 'course:direct';
    final int remaining = list
        .where((m) =>
            m.source != MaterialSourceLocal.local &&
            m.isAvailableRemote &&
            _offlineEntryFor(m) == null &&
            !(m.source == MaterialSourceLocal.sharedUser && m.remoteStatus == 'pending'))
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: direct
              ? AppColors.adminIndigo.withValues(alpha: 0.24)
              : AppColors.skyBlue.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SlIconTile(
                icon: direct ? Icons.shield_outlined : Icons.school_outlined,
                tone: direct ? SlTone.violet : SlTone.info,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      direct ? subject.course : subject.name,
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (direct)
                      const SlStatusBadge(label: 'Corso del dipartimento', tone: SlTone.violet)
                    else
                      Text(
                        <String>[
                          _materialCountText(list.length),
                          if (_offlineBytes(list) > 0) '${_formatSize(_offlineBytes(list))} offline',
                          subject.course,
                        ].join(' · '),
                        style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.62),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _downloadingAll ? null : () => _downloadRemaining(list),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.adminGreen,
                minimumSize: const Size(0, 42),
                side: BorderSide(color: AppColors.adminGreen.withValues(alpha: 0.35)),
                backgroundColor: AppColors.adminGreen.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              icon: _downloadingAll
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.adminGreen),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_downloadingAll
                  ? 'Download in corso…'
                  : 'Scarica il resto offline · ${_materialCountText(remaining)}'),
            ),
          ],
        ],
      ),
    );
  }
  String _provenanceLabel(MaterialSourceLocal source) {
    switch (source) {
      case MaterialSourceLocal.local:
        return 'Personale';
      case MaterialSourceLocal.public:
        return 'StudentLab';
      case MaterialSourceLocal.teacher:
        return 'Docente';
      case MaterialSourceLocal.group:
        return 'Gruppo';
      case MaterialSourceLocal.personalSync:
        return 'Personale sincronizzato';
      case MaterialSourceLocal.sharedUser:
        return 'Condiviso';
    }
  }

  Widget _provenanceIcon(MaterialSourceLocal source) {
    switch (source) {
      case MaterialSourceLocal.local:
        return Icon(
          Icons.school_rounded,
          size: 15,
          color: AppColors.materialSky,
        );
      case MaterialSourceLocal.public:
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/icons/studentlab_material_source.png',
            width: 17,
            height: 17,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) {
                  return Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: AppColors.materialSky,
                  );
                },
          ),
        );
      case MaterialSourceLocal.teacher:
        return Icon(
          Icons.co_present_rounded,
          size: 15,
          color: AppColors.materialSky,
        );
      case MaterialSourceLocal.group:
        return Icon(
          Icons.groups_rounded,
          size: 15,
          color: AppColors.materialSky,
        );
      case MaterialSourceLocal.personalSync:
        return Icon(
          Icons.cloud_done_outlined,
          size: 15,
          color: AppColors.materialSky,
        );
      case MaterialSourceLocal.sharedUser:
        return Icon(
          Icons.share_outlined,
          size: 15,
          color: AppColors.materialSky,
        );
    }
  }

  String _materialType(MaterialLocal material, MaterialOfflineEntry? offline) {
    final String mimeType = offline?.file.mimeType?.trim().toLowerCase() ?? '';
    final String name = material.originalName.trim().toLowerCase();

    if (mimeType == 'application/pdf' || name.endsWith('.pdf')) {
      return 'PDF';
    }

    if (mimeType.contains('wordprocessingml') ||
        name.endsWith('.docx') ||
        name.endsWith('.doc')) {
      return 'Document';
    }

    if (mimeType.contains('presentationml') ||
        name.endsWith('.pptx') ||
        name.endsWith('.ppt')) {
      return 'PPTX';
    }

    if (mimeType == 'text/plain' || name.endsWith('.txt')) {
      return 'Document';
    }

    if (mimeType.contains('zip') || name.endsWith('.zip')) {
      return 'ZIP';
    }

    if (mimeType.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp')) {
      return 'Image';
    }

    return 'File';
  }

  String _formatSize(int? size) {
    if (size == null || size <= 0) {
      return 'Dimensione sconosciuta';
    }

    if (size < 1024) {
      return '$size B';
    }

    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }

    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _openMaterial(MaterialLocal material) async {
    try {
      await _downloadService.openLocalMaterial(material);
    } catch (error) {
      await _loadMaterials();
      if (!mounted) return;
      if (material.source != MaterialSourceLocal.local &&
          material.isAvailableRemote) {
        _showMessage(
          'Il materiale non è più offline. Puoi scaricarlo nuovamente.',
        );
      } else {
        _showMessage(_friendlyMaterialError(error));
      }
    }
  }

  Widget _buildOfflineSyncBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.adminAmber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.adminAmber.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppColors.adminAmber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sincronizzazione non disponibile. Stai visualizzando i materiali già salvati sul dispositivo.',
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildEmptyLibrary() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(30),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.10)),
      ),

      child: Column(
        children: [
          Icon(
            Icons.offline_pin_outlined,

            color: AppColors.pureWhite.withValues(alpha: 0.28),

            size: 46,
          ),

          const SizedBox(height: 14),

          Text(
            'Nessun materiale offline',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.pureWhite,

              fontSize: 15,

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'I materiali personali e quelli disponibili da StudentLab, docenti e gruppi verranno organizzati qui per ateneo, dipartimento, corso e materia.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.46),

              fontSize: 11,

              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHierarchy(String message) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(28),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Text(
        message,

        textAlign: TextAlign.center,

        style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.48)),
      ),
    );
  }

  Widget _buildEmptyMaterials() {
    return Container(
      padding: const EdgeInsets.all(30),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, color: AppColors.white38, size: 45),

          SizedBox(height: 12),

          Text(
            'Nessun materiale disponibile',

            textAlign: TextAlign.center,

            style: TextStyle(color: AppColors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            Icons.error_outline_rounded,

            color: AppColors.redAccent,

            size: 40,
          ),

          const SizedBox(height: 12),

          Text(
            _error ?? 'Impossibile caricare la libreria dei materiali.',

            textAlign: TextAlign.center,

            style: TextStyle(color: AppColors.white60, fontSize: 11),
          ),

          const SizedBox(height: 15),

          OutlinedButton.icon(
            onPressed: _loadMaterials,

            icon: const Icon(Icons.refresh_rounded),

            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  bool _sameText(String a, String b) {
    return _normalizeText(a) == _normalizeText(b);
  }

  String _normalizeText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  void _addCaseInsensitiveValue(Map<String, String> values, String value) {
    final String trimmed = value.trim();

    if (trimmed.isEmpty) {
      return;
    }

    values.putIfAbsent(_normalizeText(trimmed), () => trimmed);
  }

  String _friendlyMaterialError(
    Object error, {
    String fallback = 'Non è stato possibile completare l’operazione.',
  }) {
    final String value = error.toString().toLowerCase();

    if (value.contains('permission')) {
      return 'StudentLab non ha il permesso necessario per modificare il file sul dispositivo.';
    }

    if (value.contains('not found') || value.contains('non disponibile')) {
      return 'Il file non è più disponibile sul dispositivo.';
    }

    return fallback;
  }

  String _friendlyDownloadError(Object error) {
    final String value = error.toString().toLowerCase();

    if (value.contains('401') ||
        value.contains('sessione') ||
        value.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (value.contains('403') ||
        value.contains('404') ||
        value.contains('non è più disponibile')) {
      return 'Il materiale non è più disponibile.';
    }

    if (value.contains('network') ||
        value.contains('socket') ||
        value.contains('connection') ||
        value.contains('timeout') ||
        value.contains('host lookup')) {
      return 'Download non disponibile. Controlla la connessione e riprova.';
    }

    if (value.contains('integrità') ||
        value.contains('hash') ||
        value.contains('dimensione')) {
      return 'Il file ricevuto non ha superato il controllo di integrità.';
    }

    return 'Non è stato possibile scaricare il materiale. Riprova.';
  }

  String _materialCountText(int count) {
    return count == 1 ? '1 materiale' : '$count materiali';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('401') || message.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (message.contains('403') || message.contains('forbidden')) {
      return 'Non hai i permessi necessari per completare questa operazione.';
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

    return 'Non è stato possibile completare l’operazione. Riprova.';
  }

  String _cloudExpiryLabel(DateTime value) {
    final Duration remaining = value.toLocal().difference(DateTime.now());
    final int days = remaining.inDays < 0 ? 0 : remaining.inDays + 1;
    return days == 1 ? 'Cloud: 1 giorno' : 'Cloud: $days giorni';
  }

  Future<void> _syncPersonalMaterial(MaterialLocal material) async {
    if (material.id == null) return;
    final String? path = await _downloadService.getFileForMaterial(material);
    if (path == null) {
      _showMessage('Il file locale non è disponibile.');
      return;
    }
    _setMaterialProcessing(material, true);
    try {
      final Map<String, dynamic> remote = await _apiService
          .syncPersonalMaterial(
            filePath: path,
            subjectId: material.subjectId,
            university: material.university,
            department: material.department,
            course: material.course,
            subjectName: material.subjectName,
          );
      final int? remoteId = _toIntMaterial(remote['id']);
      if (remoteId == null)
        throw StateError('Identificativo remoto non valido.');
      await _materialRepository.save(
        material.copyWith(
          source: MaterialSourceLocal.personalSync,
          remoteKey: 'personal_sync:$remoteId',
          remoteId: remoteId,
          remoteVersion: _toIntMaterial(remote['version']) ?? 1,
          remoteStatus: remote['status']?.toString() ?? 'active',
          isAvailableRemote: true,
          isPersonal: true,
          cloudPolicy: 'my_devices',
          retentionStatus: remote['retention_status']?.toString(),
          cloudExpiresAt: DateTime.tryParse(
            remote['retention_expires_at']?.toString() ?? '',
          ),
          updatedAt: DateTime.now().toUtc(),
          lastSyncedAt: DateTime.now().toUtc(),
        ),
      );
      await _loadMaterials();
      _showMessage('Materiale sincronizzato sui tuoi dispositivi.');
    } catch (e) {
      _showMessage(_friendlyError(e));
    } finally {
      _setMaterialProcessing(material, false);
    }
  }

  Future<void> _shareMaterial(MaterialLocal material) async {
    final String? path = await _downloadService.getFileForMaterial(material);
    if (path == null) {
      _showMessage('Il file locale non è disponibile.');
      return;
    }
    List<SocialUser> users;
    try {
      users = await _apiService.getSocialUsers();
    } catch (e) {
      _showMessage('Non è stato possibile caricare gli utenti.');
      return;
    }
    if (!mounted) return;
    final SocialUser? recipient = await showModalBottomSheet<SocialUser>(
      context: context,
      backgroundColor: AppColors.eleganceDeepNavy,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Condividi con',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...users
                  .where((u) => u.id != _authSession.currentUserId)
                  .map(
                    (SocialUser user) => ListTile(
                      leading: Icon(
                        Icons.person_outline,
                        color: AppColors.skyBlue,
                      ),
                      title: Text(
                        '${user.firstName} ${user.lastName}'.trim(),
                        style: TextStyle(color: AppColors.pureWhite),
                      ),
                      onTap: () => Navigator.pop(sheetContext, user),
                    ),
                  ),
            ],
          ),
        );
      },
    );
    if (recipient == null || !mounted) return;
    _setMaterialProcessing(material, true);
    try {
      await _apiService.shareMaterialWithUser(
        filePath: path,
        recipientUserId: recipient.id,
        subjectId: material.subjectId,
      );
      _showMessage(
        'Condivisione inviata. Il file resta nel cloud per massimo 8 giorni.',
      );
    } catch (e) {
      _showMessage(_friendlyError(e));
    } finally {
      _setMaterialProcessing(material, false);
    }
  }

  Future<void> _acceptSharedMaterial(MaterialLocal material) async {
    final int? shareId = material.remoteId;
    if (shareId == null) return;
    _setMaterialProcessing(material, true);
    try {
      await _apiService.acceptMaterialShare(shareId);
      await _downloadRemoteMaterial(
        material.copyWith(remoteStatus: 'accepted'),
      );
      await _apiService.markMaterialShareDelivered(shareId);
      await _loadMaterials();
      _showMessage('Materiale ricevuto e salvato offline.');
    } catch (e) {
      _showMessage(_friendlyError(e));
    } finally {
      _setMaterialProcessing(material, false);
    }
  }

  Future<void> _requestTeacherMaterial(_LocalSubject subject) async {
    final existing = _materials.where((material) =>
      material.subjectId == subject.subjectId &&
      material.source == MaterialSourceLocal.teacher &&
      material.isAvailableRemote).toList();
    if (existing.isNotEmpty && mounted) {
      final continueRequest = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: Text('Materiale docente già disponibile',
            style: TextStyle(color: AppColors.pureWhite)),
          content: Text('Per questa materia ci sono già ${existing.length} materiali dei docenti. Controlla la cartella della materia prima di inviare una nuova richiesta.',
            style: TextStyle(color: AppColors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vedi materiali')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Richiedi comunque')),
          ],
        ));
      if (continueRequest != true || !mounted) return;
    }
    final TextEditingController topic = TextEditingController();
    final TextEditingController message = TextEditingController();
    final bool? send = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text(
          'Richiedi materiale',
          style: TextStyle(color: AppColors.pureWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: topic,
              style: TextStyle(color: AppColors.pureWhite),
              decoration: const InputDecoration(
                labelText: 'Argomento facoltativo',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: message,
              minLines: 3,
              maxLines: 6,
              style: TextStyle(color: AppColors.pureWhite),
              decoration: const InputDecoration(
                labelText: 'Di quale materiale hai bisogno?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Invia'),
          ),
        ],
      ),
    );
    if (send != true ||
        message.text.trim().isEmpty ||
        subject.subjectId == null) {
      topic.dispose();
      message.dispose();
      return;
    }
    try {
      final response = await _apiService.createTeacherMaterialRequest(
        subjectId: subject.subjectId!,
        topic: topic.text.trim(),
        message: message.text.trim(),
      );
      _showMessage(response['recipient_kind'] == 'studentlab'
        ? 'Nessun docente registrato per la materia: richiesta inviata a StudentLab.'
        : 'Richiesta inviata ai docenti registrati per questa materia.');
    } catch (e) {
      _showMessage(_friendlyError(e));
    } finally {
      topic.dispose();
      message.dispose();
    }
  }

  Future<void> _reconcileLocalPath(MaterialLocal material) async {
    if (material.id == null || material.subjectId != null || !mounted) return;
    _setMaterialProcessing(material, true);
    try {
      final matches = await _apiService.getMaterialPathSuggestions(
        university: material.university ?? '',
        department: material.department ?? '',
        course: material.course ?? '', subject: material.subjectName);
      if (!mounted) return;
      final candidates = matches.where((match) =>
        match['subject_id'] != null &&
        ((match['confidence'] as num?)?.toDouble() ?? 0) >= 0.70).toList();
      if (candidates.isEmpty) {
        _showMessage('Non ho trovato una materia corrispondente. Il tuo percorso resta invariato.');
        return;
      }
      final selected = await showDialog<Map<String, dynamic>>(context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: Text('Associa al catalogo',
            style: TextStyle(color: AppColors.pureWhite)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            children: [Text('Scegli una materia. Il file resta sul tuo dispositivo.',
              style: TextStyle(color: AppColors.white70)),
              for (final match in candidates) ListTile(
                title: Text('${match['course']} / ${match['subject']}',
                  style: TextStyle(color: AppColors.pureWhite)),
                subtitle: Text('${match['university']} / ${match['department']}',
                  style: TextStyle(color: AppColors.white60)),
                onTap: () => Navigator.pop(dialogContext, match))])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Lascia invariato'))]));
      if (selected == null || !mounted) return;
      final subjectId = int.tryParse(selected['subject_id'].toString());
      if (subjectId == null) return;
      await _materialRepository.save(material.copyWith(subjectId: subjectId,
        university: selected['university']?.toString(),
        department: selected['department']?.toString(),
        course: selected['course']?.toString(),
        subjectName: selected['subject']?.toString(),
        updatedAt: DateTime.now().toUtc()));
      await _loadMaterials();
      if (mounted) _showMessage('Percorso associato al catalogo. Il file non è stato caricato.');
    } catch (_) {
      if (mounted) _showMessage('Catalogo non disponibile. Il percorso locale resta invariato.');
    } finally {
      _setMaterialProcessing(material, false);
    }
  }

  Future<void> _proposeCourse(MaterialLocal material) async {
    final university = material.university?.trim() ?? '';
    final department = material.department?.trim() ?? '';
    final course = material.course?.trim() ?? '';
    if (university.isEmpty || department.isEmpty || course.isEmpty) {
      _showMessage('Completa ateneo, dipartimento e corso prima di proporlo.');
      return;
    }
    try {
      final result = await _apiService.proposeMaterialCourse(
        university: university, department: department, course: course);
      if (!mounted) return;
      final status = result['status']?.toString();
      _showMessage(status == 'pending'
        ? 'Corso inviato per approvazione. I file restano sul dispositivo.'
        : 'Proposta registrata.');
    } catch (e) {
      if (mounted) _showMessage(_friendlyError(e));
    }
  }

  int? _toIntMaterial(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _LocalMaterialImportPage extends StatefulWidget {
  final LocalMaterialImportService importService;
  final ApiService apiService;
  final List<MaterialOfflineEntry> existingMaterials;
  final String? initialUniversity;
  final String? initialDepartment;
  final String? initialCourse;
  final String? initialSubject;

  const _LocalMaterialImportPage({
    required this.importService,
    required this.apiService,
    required this.existingMaterials,
    this.initialUniversity,
    this.initialDepartment,
    this.initialCourse,
    this.initialSubject,
  });

  @override
  State<_LocalMaterialImportPage> createState() =>
      _LocalMaterialImportPageState();
}

class _LocalMaterialImportPageState extends State<_LocalMaterialImportPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final PickedFileBridge _fileBridge = PickedFileBridge();

  late final TextEditingController _universityController;

  late final TextEditingController _departmentController;

  late final TextEditingController _courseController;

  late final TextEditingController _subjectController;
  final TextEditingController _foldersController = TextEditingController();

  bool _additionalCourse = false;
  bool _manualSubjectEnabled = false;
  bool _manualTopicEnabled = false;

  String? _filePath;
  String? _fileName;
  Uint8List? _fileBytes;

  List<AcademicUniversity> _catalogUniversities = [];

  List<AcademicDepartment> _catalogDepartments = [];

  List<AcademicCourse> _catalogCourses = [];

  List<SocialSubject> _catalogSubjects = [];

  bool _loadingUniversities = false;

  bool _loadingDepartments = false;

  bool _loadingCourses = false;

  bool _loadingSubjects = false;

  bool _saving = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _universityController = TextEditingController(
      text: widget.initialUniversity ?? '',
    );

    _departmentController = TextEditingController(
      text: widget.initialDepartment ?? '',
    );

    _courseController = TextEditingController(text: widget.initialCourse ?? '');

    _subjectController = TextEditingController(
      text: widget.initialSubject ?? '',
    );

    _loadCatalogUniversities();
  }

  @override
  void dispose() {
    _universityController.dispose();
    _departmentController.dispose();
    _courseController.dispose();
    _subjectController.dispose();
    _foldersController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_saving) {
      return;
    }

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final PlatformFile file = result.files.single;

      final Uint8List? bytes = file.bytes;

      String? path;

      if (kIsWeb) {
        if (bytes == null || bytes.isEmpty) {
          throw StateError(
            'Il browser non ha reso disponibile il contenuto del file.',
          );
        }
      } else {
        path = await _fileBridge.materialize(file);
      }

      setState(() {
        _filePath = path;
        _fileName = file.name;
        _fileBytes = bytes;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Non è stato possibile selezionare il file.');
    }
  }

  List<String> get _folderSegments => _foldersController.text.split('/')
      .map((segment) => segment.trim()).where((segment) => segment.isNotEmpty).toList();

  Future<int?> _resolveManualPath() async {
    final university = _universityController.text.trim();
    final department = _departmentController.text.trim();
    final course = _courseController.text.trim();
    final subject = _manualSubjectEnabled
        ? _subjectController.text.trim()
        : '';
    if (university.isEmpty || department.isEmpty || course.isEmpty) return null;
    try {
      final matches = await widget.apiService.getMaterialPathSuggestions(
        university: university, department: department, course: course,
        subject: subject.isEmpty ? null : subject,
      );
      if (!mounted || matches.isEmpty) return null;
      Map<String, dynamic>? selected;
      final first = matches.first;
      final confidence = (first['confidence'] as num?)?.toDouble() ?? 0;
      if (matches.length == 1 && confidence >= 0.98) {
        selected = first;
      } else {
        selected = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.eleganceDeepNavy,
            title: Text('Possibili percorsi',
              style: TextStyle(color: AppColors.pureWhite)),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final match in matches)
                ListTile(
                  title: Text('${match['course']} · ${match['subject'] ?? 'Materiali del corso'}',
                    style: TextStyle(color: AppColors.pureWhite)),
                  subtitle: Text('${match['university']} / ${match['department']}',
                    style: TextStyle(color: AppColors.white60)),
                  onTap: () => Navigator.pop(dialogContext, match),
                ),
              ],
            )),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Mantieni il percorso inserito'))],
          ),
        );
      }
      if (selected == null || !mounted) return null;
      _universityController.text = selected['university']?.toString() ?? university;
      _departmentController.text = selected['department']?.toString() ?? department;
      _courseController.text = selected['course']?.toString() ?? course;
      _subjectController.text = selected['subject']?.toString() ?? subject;
      return int.tryParse(selected['subject_id']?.toString() ?? '');
    } catch (_) {
      // Offline import must remain available when catalog matching fails.
      return null;
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isCatalogCoursePath && _resolvedCatalogSubject == null) {
      _showMessage('Seleziona una materia valida dal catalogo.');
      return;
    }

    final String? filePath = _filePath;
    if (_folderSegments.length > 8 || _folderSegments.any((v) => v.length > 80 || v == '.' || v == '..')) {
      _showMessage('Percorso troppo lungo o nome della cartella non valido.');
      return;
    }
    final Uint8List? fileBytes = _fileBytes;

    final bool hasPath = filePath != null && filePath.trim().isNotEmpty;

    final bool hasBytes = fileBytes != null && fileBytes.isNotEmpty;

    if (!hasPath && !hasBytes) {
      _showMessage('Seleziona il file da aggiungere alle dispense.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    bool completed = false;

    try {
      int? resolvedSubjectId = _resolvedCatalogSubject?.id;
      // An explicitly selected catalog subject is authoritative; manual paths
      // may be matched when online, and remain exactly as entered offline.
      if (resolvedSubjectId == null) {
        resolvedSubjectId = await _resolveManualPath();
        if (!mounted) return;
      }
      final String university = _universityController.text.trim();
      final String department = _departmentController.text.trim();
      final String course = _courseController.text.trim();
      final bool catalogPath = _isCatalogCoursePath;
      final String subjectName = catalogPath || _manualSubjectEnabled
          ? _subjectController.text.trim()
          : '';
      final List<String> pathSegments = !catalogPath && _manualTopicEnabled
          ? _folderSegments
          : const <String>[];
      final String? originalName = _fileName;

      if (fileBytes != null && fileBytes.isNotEmpty) {
        await widget.importService.importMaterialBytes(
          bytes: fileBytes,
          fileName: originalName ?? 'materiale',
          university: university,
          department: department,
          course: course,
          subjectName: subjectName,
          subjectId: resolvedSubjectId,
          courseScope: _additionalCourse ? 'additional' : 'degree',
          pathSegments: pathSegments,
        );
      } else {
        await widget.importService.importMaterial(
          sourcePath: filePath!,
          university: university,
          department: department,
          course: course,
          subjectName: subjectName,
          originalName: originalName,
          subjectId: resolvedSubjectId,
          courseScope: _additionalCourse ? 'additional' : 'degree',
          pathSegments: pathSegments,
        );
      }

      if (!mounted) {
        return;
      }

      completed = true;
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('OFFLINE MATERIAL IMPORT ERROR: $e');
      debugPrintStack(
        label: 'OFFLINE MATERIAL IMPORT STACK',
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _error = _friendlyLocalError(e);
      });
    } finally {
      if (!completed && mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Aggiungi materiale'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.eleganceMidnight,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'Il file resterà sul tuo dispositivo e non viene inviato a StudentLab. '
                      'Puoi scegliere il percorso dal catalogo oppure inserirlo manualmente. '
                      'Per un corso inserito manualmente puoi aggiungere una materia, un argomento, entrambi oppure associare direttamente il file al corso.',
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.58),
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _hybridField(
                    controller: _universityController,
                    label: 'Ateneo *',
                    icon: Icons.account_balance_outlined,
                    options: _universityOptions,
                    loading: _loadingUniversities,
                    onOptionSelected: _selectUniversityOption,
                    requiredField: true,
                  ),
                  const SizedBox(height: 13),
                  _hybridField(
                    controller: _departmentController,
                    label: 'Dipartimento *',
                    icon: Icons.apartment_outlined,
                    options: _departmentOptions,
                    loading: _loadingDepartments,
                    onOptionSelected: _selectDepartmentOption,
                    requiredField: true,
                  ),
                  const SizedBox(height: 13),
                  _hybridField(
                    controller: _courseController,
                    label: 'Corso *',
                    icon: Icons.school_outlined,
                    options: _courseOptions,
                    loading: _loadingCourses,
                    onOptionSelected: _selectCourseOption,
                    requiredField: true,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _additionalCourse,
                    onChanged: _saving ? null : (value) => setState(() => _additionalCourse = value),
                    title: Text('Corso aggiuntivo, separato da L-31',
                      style: TextStyle(color: AppColors.pureWhite)),
                    subtitle: Text('Resta un percorso accademico nella stessa biblioteca.',
                      style: TextStyle(color: AppColors.white60)),
                  ),
                  const SizedBox(height: 13),
                  if (_isCatalogCoursePath) ...[
                    _hybridField(
                      controller: _subjectController,
                      label: 'Materia *',
                      icon: Icons.menu_book_outlined,
                      options: _subjectOptions,
                      loading: _loadingSubjects,
                      onOptionSelected: _selectSubjectOption,
                      requiredField: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Per i materiali associati a un corso del catalogo la materia viene scelta dal catalogo accademico.',
                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.52),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ] else if (_courseController.text.trim().isNotEmpty) ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (!_manualSubjectEnabled)
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _manualSubjectEnabled = true;
                                    }),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Materia'),
                          ),
                        if (!_manualTopicEnabled)
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _manualTopicEnabled = true;
                                    }),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Argomento'),
                          ),
                      ],
                    ),
                    if (_manualSubjectEnabled) ...[
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _subjectController,
                        enabled: !_saving,
                        style: TextStyle(color: AppColors.pureWhite),
                        decoration: InputDecoration(
                          labelText: 'Materia',
                          prefixIcon: const Icon(Icons.menu_book_outlined),
                          suffixIcon: IconButton(
                            tooltip: 'Rimuovi materia',
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _subjectController.clear();
                                      _manualSubjectEnabled = false;
                                    }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ],
                    if (_manualTopicEnabled) ...[
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _foldersController,
                        enabled: !_saving,
                        style: TextStyle(color: AppColors.pureWhite),
                        decoration: InputDecoration(
                          labelText: 'Argomento',
                          prefixIcon: const Icon(Icons.topic_outlined),
                          suffixIcon: IconButton(
                            tooltip: 'Rimuovi argomento',
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _foldersController.clear();
                                      _manualTopicEnabled = false;
                                    }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  InkWell(
                    onTap: _saving ? null : _pickFile,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.eleganceMidnight,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.skyBlue.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            color: AppColors.skyBlue,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              _fileName ?? 'Seleziona file',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _fileName == null
                                    ? AppColors.white54
                                    : AppColors.pureWhite,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.white38,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 15),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: AppColors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pureWhite,
                              ),
                            )
                          : const Icon(Icons.save_alt_rounded),
                      label: Text(
                        _saving ? 'Salvataggio...' : 'Salva nelle dispense',
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

  List<String> get _universityOptions {
    return _uniqueOptions([
      ...widget.existingMaterials.map(
        (MaterialOfflineEntry entry) => entry.material.displayUniversity,
      ),
      ..._catalogUniversities.map(
        (AcademicUniversity university) => university.name,
      ),
    ]);
  }

  List<String> get _departmentOptions {
    final String university = _universityController.text;

    return _uniqueOptions([
      ...widget.existingMaterials
          .where(
            (MaterialOfflineEntry entry) =>
                _sameLocalText(entry.material.displayUniversity, university),
          )
          .map(
            (MaterialOfflineEntry entry) => entry.material.displayDepartment,
          ),
      ..._catalogDepartments.map(
        (AcademicDepartment department) => department.name,
      ),
    ]);
  }

  List<String> get _courseOptions {
    final String university = _universityController.text;

    final String department = _departmentController.text;

    return _uniqueOptions([
      ...widget.existingMaterials
          .where(
            (MaterialOfflineEntry entry) =>
                _sameLocalText(entry.material.displayUniversity, university) &&
                _sameLocalText(entry.material.displayDepartment, department),
          )
          .map((MaterialOfflineEntry entry) => entry.material.displayCourse),
      ..._catalogCourses.map((AcademicCourse course) => course.name),
    ]);
  }

  List<String> get _subjectOptions {
    final String university = _universityController.text;

    final String department = _departmentController.text;

    final String course = _courseController.text;

    return _uniqueOptions([
      ...widget.existingMaterials
          .where(
            (MaterialOfflineEntry entry) =>
                _sameLocalText(entry.material.displayUniversity, university) &&
                _sameLocalText(entry.material.displayDepartment, department) &&
                _sameLocalText(entry.material.displayCourse, course),
          )
          .map(
            (MaterialOfflineEntry entry) => entry.material.displaySubjectName,
          ),
      ..._catalogSubjects
          .where((SocialSubject subject) => subject.isActive)
          .map((SocialSubject subject) => subject.name),
    ]);
  }

  Future<void> _loadCatalogUniversities() async {
    if (_loadingUniversities) {
      return;
    }

    setState(() {
      _loadingUniversities = true;
    });

    try {
      final List<AcademicUniversity> values = await widget.apiService
          .getUniversities();

      if (!mounted) {
        return;
      }

      setState(() {
        _catalogUniversities = values;
      });

      await _restoreCatalogSelection();
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingUniversities = false;
        });
      }
    }
  }

  Future<void> _restoreCatalogSelection() async {
    final AcademicUniversity? university = _findUniversity(
      _universityController.text,
    );

    if (university == null) {
      return;
    }

    await _loadCatalogDepartments(university, clearChildren: false);

    final AcademicDepartment? department = _findDepartment(
      _departmentController.text,
    );

    if (department == null) {
      return;
    }

    await _loadCatalogCourses(university, department, clearChildren: false);

    final AcademicCourse? course = _findCourse(_courseController.text);

    if (course == null) {
      return;
    }

    await _loadCatalogSubjects(
      university,
      department,
      course,
      clearSubject: false,
    );
  }

  Future<void> _selectUniversityOption(String value) async {
    _universityController.text = value;

    _universityController.selection = TextSelection.collapsed(
      offset: value.length,
    );

    final AcademicUniversity? university = _findUniversity(value);

    setState(() {
      _departmentController.clear();
      _courseController.clear();
      _subjectController.clear();
      _foldersController.clear();
      _manualSubjectEnabled = false;
      _manualTopicEnabled = false;
      _catalogDepartments = [];
      _catalogCourses = [];
      _catalogSubjects = [];
    });

    if (university == null) {
      return;
    }

    await _loadCatalogDepartments(university);
  }

  Future<void> _selectDepartmentOption(String value) async {
    _departmentController.text = value;

    _departmentController.selection = TextSelection.collapsed(
      offset: value.length,
    );

    final AcademicUniversity? university = _findUniversity(
      _universityController.text,
    );

    final AcademicDepartment? department = _findDepartment(value);

    setState(() {
      _courseController.clear();
      _subjectController.clear();
      _foldersController.clear();
      _manualSubjectEnabled = false;
      _manualTopicEnabled = false;
      _catalogCourses = [];
      _catalogSubjects = [];
    });

    if (university == null || department == null) {
      return;
    }

    await _loadCatalogCourses(university, department);
  }

  Future<void> _selectCourseOption(String value) async {
    _courseController.text = value;

    _courseController.selection = TextSelection.collapsed(offset: value.length);

    final AcademicUniversity? university = _findUniversity(
      _universityController.text,
    );

    final AcademicDepartment? department = _findDepartment(
      _departmentController.text,
    );

    final AcademicCourse? course = _findCourse(value);

    setState(() {
      _subjectController.clear();
      _foldersController.clear();
      _manualSubjectEnabled = false;
      _manualTopicEnabled = false;
      _catalogSubjects = [];
    });

    if (university == null || department == null || course == null) {
      return;
    }

    await _loadCatalogSubjects(university, department, course);
  }

  void _selectSubjectOption(String value) {
    _subjectController.text = value;

    _subjectController.selection = TextSelection.collapsed(
      offset: value.length,
    );

    setState(() {});
  }

  Future<void> _loadCatalogDepartments(
    AcademicUniversity university, {
    bool clearChildren = true,
  }) async {
    setState(() {
      _loadingDepartments = true;

      if (clearChildren) {
        _catalogDepartments = [];
      }
    });

    try {
      final List<AcademicDepartment> values = await widget.apiService
          .getDepartments(university.code);

      if (!mounted) {
        return;
      }

      setState(() {
        _catalogDepartments = values;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDepartments = false;
        });
      }
    }
  }

  Future<void> _loadCatalogCourses(
    AcademicUniversity university,
    AcademicDepartment department, {
    bool clearChildren = true,
  }) async {
    setState(() {
      _loadingCourses = true;

      if (clearChildren) {
        _catalogCourses = [];
      }
    });

    try {
      final List<AcademicCourse> values = await widget.apiService.getCourses(
        universityCode: university.code,
        departmentCode: department.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _catalogCourses = values;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingCourses = false;
        });
      }
    }
  }

  Future<void> _loadCatalogSubjects(
    AcademicUniversity university,
    AcademicDepartment department,
    AcademicCourse course, {
    bool clearSubject = true,
  }) async {
    setState(() {
      _loadingSubjects = true;

      if (clearSubject) {
        _catalogSubjects = [];
      }
    });

    try {
      final List<SocialSubject> values = await widget.apiService
          .getCatalogSubjects(
            universityCode: university.code,
            departmentCode: department.code,
            courseCode: course.code,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _catalogSubjects = values;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingSubjects = false;
        });
      }
    }
  }

  AcademicUniversity? _findUniversity(String value) {
    for (final AcademicUniversity university in _catalogUniversities) {
      if (_sameLocalText(university.name, value) ||
          _sameLocalText(university.code, value)) {
        return university;
      }
    }

    return null;
  }

  AcademicDepartment? _findDepartment(String value) {
    for (final AcademicDepartment department in _catalogDepartments) {
      if (_sameLocalText(department.name, value) ||
          _sameLocalText(department.code, value)) {
        return department;
      }
    }

    return null;
  }

  AcademicCourse? _findCourse(String value) {
    for (final AcademicCourse course in _catalogCourses) {
      if (_sameLocalText(course.name, value) ||
          _sameLocalText(course.code, value)) {
        return course;
      }
    }

    return null;
  }

  bool get _isCatalogCoursePath {
    return _findUniversity(_universityController.text) != null &&
        _findDepartment(_departmentController.text) != null &&
        _findCourse(_courseController.text) != null;
  }

  SocialSubject? get _resolvedCatalogSubject {
    final AcademicUniversity? university = _findUniversity(
      _universityController.text,
    );
    final AcademicDepartment? department = _findDepartment(
      _departmentController.text,
    );
    final AcademicCourse? course = _findCourse(_courseController.text);

    if (university == null || department == null || course == null) {
      return null;
    }

    final String value = _subjectController.text.trim();

    if (value.isEmpty) {
      return null;
    }

    for (final SocialSubject subject in _catalogSubjects) {
      if (subject.isActive && _sameLocalText(subject.name, value)) {
        return subject;
      }
    }

    return null;
  }

  List<String> _uniqueOptions(Iterable<String> source) {
    final Map<String, String> values = {};

    for (final String value in source) {
      final String trimmed = value.trim();

      if (trimmed.isEmpty) {
        continue;
      }

      values.putIfAbsent(_normalizeLocalText(trimmed), () => trimmed);
    }

    final List<String> result = values.values.toList();

    result.sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return result;
  }

  bool _sameLocalText(String a, String b) {
    return _normalizeLocalText(a) == _normalizeLocalText(b);
  }

  String _normalizeLocalText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  Widget _hybridField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> options,
    required bool loading,
    required ValueChanged<String> onOptionSelected,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,

      enabled: !_saving,

      onChanged: (_) {
        setState(() {});
      },

      style: TextStyle(color: AppColors.pureWhite),

      validator: (String? value) {
        if (requiredField && (value == null || value.trim().isEmpty)) {
          return 'Campo obbligatorio';
        }

        return null;
      },

      decoration: InputDecoration(
        labelText: label,

        helperText: loading
            ? 'Caricamento opzioni...'
            : requiredField
            ? options.isEmpty
                  ? 'Campo obbligatorio • inserisci un valore valido'
                  : 'Campo obbligatorio • scrivi oppure scegli tra quelli esistenti'
            : options.isEmpty
            ? 'Puoi lasciare vuoto'
            : 'Scrivi oppure scegli tra quelli esistenti',

        helperStyle: TextStyle(
          color: AppColors.pureWhite.withValues(alpha: 0.35),

          fontSize: 9,
        ),

        prefixIcon: Icon(icon, color: AppColors.skyBlue),

        suffixIcon: loading
            ? Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.materialSky,
                  ),
                ),
              )
            : options.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Scegli $label',

                color: AppColors.eleganceDeepNavy,

                icon: Icon(
                  Icons.arrow_drop_down_rounded,

                  color: AppColors.materialSky,
                ),

                onSelected: onOptionSelected,

                itemBuilder: (BuildContext context) {
                  return options
                      .map(
                        (String option) => PopupMenuItem<String>(
                          value: option,

                          child: Text(
                            option,

                            style: TextStyle(color: AppColors.pureWhite),
                          ),
                        ),
                      )
                      .toList();
                },
              ),

        filled: true,

        fillColor: AppColors.eleganceMidnight,

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  String? _optionalText(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? null : normalized;
  }

  String _friendlyLocalError(Object error) {
    final String value = error.toString().toLowerCase();

    if (value.contains('permission')) {
      return 'StudentLab non ha il permesso di salvare il file sul dispositivo.';
    }

    if (value.contains('space') || value.contains('storage')) {
      return 'Lo spazio disponibile sul dispositivo non è sufficiente.';
    }

    if (value.contains('not found') || value.contains('non disponibile')) {
      return 'Il file selezionato non è più disponibile.';
    }

    return 'Non è stato possibile aggiungere il materiale alle dispense offline.';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MaterialPublicationPage extends StatefulWidget {
  final ApiService apiService;
  final String? initialFilePath;
  final String? initialFileName;
  final String? initialUniversity;
  final String? initialDepartment;
  final String? initialCourse;
  final int? initialSubjectId;
  final String? initialSubjectName;

  const _MaterialPublicationPage({
    required this.apiService,
    this.initialFilePath,
    this.initialFileName,
    this.initialUniversity,
    this.initialDepartment,
    this.initialCourse,
    this.initialSubjectId,
    this.initialSubjectName,
  });

  @override
  State<_MaterialPublicationPage> createState() =>
      _MaterialPublicationPageState();
}

class _MaterialPublicationPageState extends State<_MaterialPublicationPage> {
  String _attributionMode = 'anonymous';
  final PickedFileBridge _fileBridge = PickedFileBridge();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  List<AcademicUniversity> _universities = [];

  List<AcademicDepartment> _departments = [];

  List<AcademicCourse> _courses = [];

  List<SocialSubject> _subjects = [];

  AcademicUniversity? _selectedUniversity;

  AcademicDepartment? _selectedDepartment;

  AcademicCourse? _selectedCourse;

  SocialSubject? _selectedSubject;

  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;

  String? _selectedFileName;

  bool _loadingCatalog = true;

  bool _loadingDepartments = false;

  bool _loadingCourses = false;

  bool _loadingSubjects = false;

  bool _submitting = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _selectedFilePath = widget.initialFilePath;

    _selectedFileName = widget.initialFileName;

    if (widget.initialFileName != null &&
        widget.initialFileName!.trim().isNotEmpty) {
      _titleController.text = _titleFromFileName(widget.initialFileName!);
    }

    _loadUniversities();
  }

  String _titleFromFileName(String fileName) {
    final String normalized = fileName.trim();

    final int dot = normalized.lastIndexOf('.');

    if (dot <= 0) {
      return normalized;
    }

    return normalized.substring(0, dot);
  }

  @override
  void dispose() {
    _titleController.dispose();

    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _loadUniversities() async {
    setState(() {
      _loadingCatalog = true;

      _error = null;
    });

    try {
      final List<AcademicUniversity> universities = await widget.apiService
          .getUniversities();

      if (!mounted) {
        return;
      }

      setState(() {
        _universities = universities;

        _loadingCatalog = false;
      });

      await _restoreInitialHierarchy();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingCatalog = false;

        _error = _friendlyPublicationError(e);
      });
    }
  }

  Future<void> _restoreInitialHierarchy() async {
    final String universityValue = widget.initialUniversity?.trim() ?? '';
    final String departmentValue = widget.initialDepartment?.trim() ?? '';
    final String courseValue = widget.initialCourse?.trim() ?? '';

    if (universityValue.isEmpty ||
        departmentValue.isEmpty ||
        courseValue.isEmpty) {
      return;
    }

    final AcademicUniversity? university = _findInitialUniversity(
      universityValue,
    );

    if (university == null) {
      return;
    }

    await _selectUniversity(university);

    if (!mounted) {
      return;
    }

    final AcademicDepartment? department = _findInitialDepartment(
      departmentValue,
    );

    if (department == null) {
      return;
    }

    await _selectDepartment(department);

    if (!mounted) {
      return;
    }

    final AcademicCourse? course = _findInitialCourse(courseValue);

    if (course == null) {
      return;
    }

    await _selectCourse(course);

    if (!mounted) {
      return;
    }

    SocialSubject? subject;

    final int? initialSubjectId = widget.initialSubjectId;

    if (initialSubjectId != null) {
      for (final SocialSubject current in _subjects) {
        if (current.id == initialSubjectId) {
          subject = current;
          break;
        }
      }
    }

    if (subject == null) {
      final String subjectName = widget.initialSubjectName?.trim() ?? '';

      if (subjectName.isNotEmpty) {
        for (final SocialSubject current in _subjects) {
          if (_samePublicationText(current.name, subjectName)) {
            subject = current;
            break;
          }
        }
      }
    }

    if (subject != null && mounted) {
      setState(() {
        _selectedSubject = subject;
      });
    }
  }

  AcademicUniversity? _findInitialUniversity(String value) {
    for (final AcademicUniversity university in _universities) {
      if (_samePublicationText(university.name, value) ||
          _samePublicationText(university.code, value)) {
        return university;
      }
    }

    return null;
  }

  AcademicDepartment? _findInitialDepartment(String value) {
    for (final AcademicDepartment department in _departments) {
      if (_samePublicationText(department.name, value) ||
          _samePublicationText(department.code, value)) {
        return department;
      }
    }

    return null;
  }

  AcademicCourse? _findInitialCourse(String value) {
    for (final AcademicCourse course in _courses) {
      if (_samePublicationText(course.name, value) ||
          _samePublicationText(course.code, value)) {
        return course;
      }
    }

    return null;
  }

  bool _samePublicationText(String a, String b) {
    return a.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ==
        b.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  Future<void> _selectUniversity(AcademicUniversity? university) async {
    if (university == null) {
      return;
    }

    setState(() {
      _selectedUniversity = university;

      _selectedDepartment = null;

      _selectedCourse = null;

      _selectedSubject = null;

      _departments = [];

      _courses = [];

      _subjects = [];

      _loadingDepartments = true;

      _error = null;
    });

    try {
      final List<AcademicDepartment> departments = await widget.apiService
          .getDepartments(university.code);

      if (!mounted) {
        return;
      }

      setState(() {
        _departments = departments;

        _loadingDepartments = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingDepartments = false;

        _error = _friendlyPublicationError(e);
      });
    }
  }

  Future<void> _selectDepartment(AcademicDepartment? department) async {
    final AcademicUniversity? university = _selectedUniversity;

    if (department == null || university == null) {
      return;
    }

    setState(() {
      _selectedDepartment = department;

      _selectedCourse = null;

      _selectedSubject = null;

      _courses = [];

      _subjects = [];

      _loadingCourses = true;

      _error = null;
    });

    try {
      final List<AcademicCourse> courses = await widget.apiService.getCourses(
        universityCode: university.code,

        departmentCode: department.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _courses = courses;

        _loadingCourses = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingCourses = false;

        _error = _friendlyPublicationError(e);
      });
    }
  }

  Future<void> _selectCourse(AcademicCourse? course) async {
    final AcademicUniversity? university = _selectedUniversity;

    final AcademicDepartment? department = _selectedDepartment;

    if (course == null || university == null || department == null) {
      return;
    }

    setState(() {
      _selectedCourse = course;

      _selectedSubject = null;

      _subjects = [];

      _loadingSubjects = true;

      _error = null;
    });

    try {
      final List<SocialSubject> subjects = await widget.apiService
          .getCatalogSubjects(
            universityCode: university.code,

            departmentCode: department.code,

            courseCode: course.code,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = subjects
            .where((SocialSubject subject) => subject.isActive)
            .toList();

        _loadingSubjects = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSubjects = false;

        _error = _friendlyPublicationError(e);
      });
    }
  }

  Future<void> _pickFile() async {
    if (_submitting) {
      return;
    }

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final PlatformFile selected = result.files.single;

      String? path;
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = selected.bytes;

        if (bytes == null || bytes.isEmpty) {
          throw StateError(
            'Il browser non ha reso disponibile il contenuto del file.',
          );
        }
      } else {
        path = await _fileBridge.materialize(selected);
      }

      setState(() {
        _selectedFilePath = path;
        _selectedFileBytes = bytes;
        _selectedFileName = selected.name;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Non è stato possibile selezionare il file.');
    }
  }

  Future<void> _submit() async {
    if (_submitting || !mounted) {
      return;
    }

    final FormState? formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final SocialSubject? subject = _selectedSubject;
    final String? filePath = _selectedFilePath;
    final Uint8List? fileBytes = _selectedFileBytes;
    final String? fileName = _selectedFileName;

    if (subject == null) {
      _showMessage('Seleziona la materia del materiale.');
      return;
    }

    if ((fileBytes == null || fileBytes.isEmpty) &&
        (filePath == null || filePath.trim().isEmpty)) {
      _showMessage('Seleziona il file da proporre.');
      return;
    }

    if (fileName == null || fileName.trim().isEmpty) {
      _showMessage('Nome del file non disponibile.');
      return;
    }

    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();

    setState(() {
      _submitting = true;
      _error = null;
    });

    bool completed = false;

    try {
      Future<Map<String, dynamic>> onDuplicateDecision(Map<String, dynamic> duplicate) async {
        if (!mounted) return const <String, dynamic>{'decision': 'cancel'};
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => _PublicationDuplicatePage(
              duplicate: duplicate,
              fileName: fileName,
              fileSize: fileBytes?.length,
            ),
          ),
        );
        return result ?? const <String, dynamic>{'decision': 'cancel'};
      }

      final Map<String, dynamic> result;
      if (fileBytes != null && fileBytes.isNotEmpty) {
        result = await widget.apiService.uploadMaterialPublicationBytes(
          subjectId: subject.id,
          title: title,
          description: description,
          bytes: fileBytes,
          originalName: fileName,
          attributionMode: _attributionMode,
          onDuplicateDecision: onDuplicateDecision,
        );
        if (result['cancelled'] == true) {
          if (mounted) Navigator.of(context).pop(false);
          completed = true;
          return;
        }
      } else {
        result = await widget.apiService.uploadMaterialPublication(
          subjectId: subject.id,
          title: title,
          description: description,
          filePath: filePath!,
          attributionMode: _attributionMode,
          onDuplicateDecision: onDuplicateDecision,
        );
        if (result['cancelled'] == true) {
          if (mounted) Navigator.of(context).pop(false);
          completed = true;
          return;
        }
      }

      if (!mounted) {
        return;
      }

      completed = true;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _friendlyPublicationError(e);
      });
    } finally {
      if (!completed && mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        title: const Text('Proponi materiale'),
      ),

      body: SafeArea(
        child: _loadingCatalog
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),

                  child: Form(
                    key: _formKey,

                    child: ListView(
                      padding: const EdgeInsets.all(20),

                      children: [
                        _buildIntro(),

                        const SizedBox(height: 20),

                        if (_error != null) ...[
                          _buildError(),

                          const SizedBox(height: 16),
                        ],

                        _buildUniversityField(),

                        const SizedBox(height: 14),

                        _buildDepartmentField(),

                        const SizedBox(height: 14),

                        _buildCourseField(),

                        const SizedBox(height: 14),

                        _buildSubjectField(),

                        const SizedBox(height: 18),

                        TextFormField(
                          controller: _titleController,

                          enabled: !_submitting,

                          maxLength: 180,

                          style: TextStyle(color: AppColors.pureWhite),

                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Inserisci un titolo';
                            }

                            return null;
                          },

                          decoration: _decoration(
                            label: 'Titolo',

                            icon: Icons.title_rounded,

                            hint: 'Es. Appunti sulle strutture dati',
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _descriptionController,

                          enabled: !_submitting,

                          minLines: 3,

                          maxLines: 6,

                          maxLength: 1000,

                          style: TextStyle(color: AppColors.pureWhite),

                          decoration: _decoration(
                            label: 'Descrizione',

                            icon: Icons.notes_rounded,

                            hint:
                                'Descrivi brevemente il contenuto del materiale',
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: AppColors.eleganceMidnight,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: AppColors.skyBlue.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attribuzione pubblica',
                                style: TextStyle(
                                  color: AppColors.pureWhite,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'anonymous',
                                    icon: Icon(Icons.visibility_off_outlined),
                                    label: Text('Anonimo'),
                                  ),
                                  ButtonSegment(
                                    value: 'named',
                                    icon: Icon(Icons.badge_outlined),
                                    label: Text('Nome e cognome'),
                                  ),
                                ],
                                selected: {_attributionMode},
                                onSelectionChanged: _submitting
                                    ? null
                                    : (Set<String> values) {
                                        setState(() {
                                          _attributionMode = values.first;
                                        });
                                      },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'L’amministratore può forzare la pubblicazione anonima durante la moderazione.',
                                style: TextStyle(
                                  color: AppColors.white38,
                                  fontSize: 9,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        _buildFilePicker(),

                        const SizedBox(height: 24),

                        SizedBox(
                          height: 54,

                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,

                            icon: _submitting
                                ? SizedBox(
                                    width: 18,

                                    height: 18,

                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,

                                      color: AppColors.pureWhite,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_outlined),

                            label: Text(
                              _submitting
                                  ? 'Invio in corso...'
                                  : 'Invia alla revisione',
                            ),

                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.socialBlue,

                              foregroundColor: AppColors.pureWhite,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(
            Icons.fact_check_outlined,

            color: AppColors.skyBlue,

            size: 24,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Ogni materiale proposto viene controllato prima della pubblicazione. '
              'Ateneo, dipartimento, corso e materia sono obbligatori per collocarlo '
              'correttamente nelle card di StudentLab.',

              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.58),

                fontSize: 11,

                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniversityField() {
    return DropdownButtonFormField<AcademicUniversity>(
      key: ValueKey<String>(
        'publication-university-${_selectedUniversity?.code ?? 'none'}',
      ),
      initialValue: _selectedUniversity,

      isExpanded: true,

      dropdownColor: AppColors.eleganceDeepNavy,

      decoration: _decoration(
        label: 'Ateneo *',

        icon: Icons.account_balance_outlined,
      ),

      validator: (AcademicUniversity? value) {
        if (value == null) {
          return 'Seleziona un ateneo';
        }

        return null;
      },

      items: _universities.map((AcademicUniversity university) {
        return DropdownMenuItem<AcademicUniversity>(
          value: university,

          child: Text(
            university.name,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(color: AppColors.pureWhite),
          ),
        );
      }).toList(),

      onChanged: _submitting ? null : _selectUniversity,
    );
  }

  Widget _buildDepartmentField() {
    return DropdownButtonFormField<AcademicDepartment>(
      key: ValueKey<String>(
        'publication-department-${_selectedDepartment?.code ?? 'none'}',
      ),
      initialValue: _selectedDepartment,

      isExpanded: true,

      dropdownColor: AppColors.eleganceDeepNavy,

      decoration: _decoration(
        label: _loadingDepartments
            ? 'Caricamento dipartimenti...'
            : 'Dipartimento *',

        icon: Icons.apartment_outlined,
      ),

      validator: (AcademicDepartment? value) {
        if (value == null) {
          return 'Seleziona un dipartimento';
        }

        return null;
      },

      items: _departments.map((AcademicDepartment department) {
        return DropdownMenuItem<AcademicDepartment>(
          value: department,

          child: Text(
            department.name,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(color: AppColors.pureWhite),
          ),
        );
      }).toList(),

      onChanged:
          (_submitting || _loadingDepartments || _selectedUniversity == null)
          ? null
          : _selectDepartment,
    );
  }

  Widget _buildCourseField() {
    return DropdownButtonFormField<AcademicCourse>(
      key: ValueKey<String>(
        'publication-course-${_selectedCourse?.code ?? 'none'}',
      ),
      initialValue: _selectedCourse,

      isExpanded: true,

      dropdownColor: AppColors.eleganceDeepNavy,

      decoration: _decoration(
        label: _loadingCourses ? 'Caricamento corsi...' : 'Corso *',

        icon: Icons.school_outlined,
      ),

      validator: (AcademicCourse? value) {
        if (value == null) {
          return 'Seleziona un corso';
        }

        return null;
      },

      items: _courses.map((AcademicCourse course) {
        return DropdownMenuItem<AcademicCourse>(
          value: course,

          child: Text(
            course.name,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(color: AppColors.pureWhite),
          ),
        );
      }).toList(),

      onChanged: (_submitting || _loadingCourses || _selectedDepartment == null)
          ? null
          : _selectCourse,
    );
  }

  Widget _buildSubjectField() {
    return DropdownButtonFormField<SocialSubject>(
      key: ValueKey<String>(
        'publication-subject-${_selectedSubject?.id ?? 'none'}',
      ),
      initialValue: _selectedSubject,

      isExpanded: true,

      dropdownColor: AppColors.eleganceDeepNavy,

      decoration: _decoration(
        label: _loadingSubjects ? 'Caricamento materie...' : 'Materia *',

        icon: Icons.menu_book_outlined,
      ),

      validator: (SocialSubject? value) {
        if (value == null) {
          return 'Seleziona una materia';
        }

        return null;
      },

      items: _subjects.map((SocialSubject subject) {
        return DropdownMenuItem<SocialSubject>(
          value: subject,

          child: Text(
            subject.name,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(color: AppColors.pureWhite),
          ),
        );
      }).toList(),

      onChanged: (_submitting || _loadingSubjects || _selectedCourse == null)
          ? null
          : (SocialSubject? value) {
              setState(() {
                _selectedSubject = value;
              });
            },
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _submitting ? null : _pickFile,

      borderRadius: BorderRadius.circular(15),

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: AppColors.eleganceMidnight,

          borderRadius: BorderRadius.circular(15),

          border: Border.all(
            color: _selectedFilePath != null
                ? AppColors.skyBlue.withValues(alpha: 0.40)
                : AppColors.skyBlue.withValues(alpha: 0.12),
          ),
        ),

        child: Row(
          children: [
            Icon(Icons.attach_file_rounded, color: AppColors.skyBlue),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    _selectedFileName ?? 'Seleziona file',

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: AppColors.pureWhite,

                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _selectedFilePath == null
                        ? 'Dimensione massima 250 MB'
                        : 'Tocca per scegliere un altro file',

                    style: TextStyle(
                      color: AppColors.pureWhite.withValues(alpha: 0.42),

                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right_rounded, color: AppColors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: AppColors.redAccent.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: AppColors.redAccent.withValues(alpha: 0.20)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(
            Icons.error_outline_rounded,

            color: AppColors.redAccent,

            size: 19,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              _error!,

              style: TextStyle(
                color: AppColors.white70,

                fontSize: 11,

                height: 1.4,
              ),
            ),
          ),
        ],
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

      labelStyle: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.55)),

      hintStyle: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.28)),

      prefixIcon: Icon(icon, color: AppColors.skyBlue),

      filled: true,

      fillColor: AppColors.eleganceMidnight,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(
          color: AppColors.skyBlue.withValues(alpha: 0.10),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: AppColors.socialBlue),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: AppColors.redAccent),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),

        borderSide: BorderSide(color: AppColors.redAccent),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyPublicationError(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('401') || message.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (message.contains('403') || message.contains('forbidden')) {
      return 'Non hai i permessi necessari per proporre questo materiale.';
    }

    if (message.contains('250 mb') || message.contains('dimensione massima')) {
      return 'Il file supera la dimensione massima consentita di 250 MB.';
    }

    if (message.contains('mime') ||
        message.contains('tipo di file') ||
        message.contains('formato')) {
      return 'Questo tipo di file non è supportato per la pubblicazione.';
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

    return 'Non è stato possibile inviare il materiale alla revisione. Riprova.';
  }
}

extension _MaterialLocalUi on MaterialLocal {
  String get displayUniversity {
    final String value = university?.trim() ?? '';
    return value.isEmpty ? 'Ateneo non specificato' : value;
  }

  String get displayDepartment {
    final String value = department?.trim() ?? '';
    return value.isEmpty ? 'Dipartimento non specificato' : value;
  }

  String get displayCourse {
    final String value = course?.trim() ?? '';
    return value.isEmpty ? 'Corso non specificato' : value;
  }

  String get displaySubjectName {
    final String value = subjectName?.trim() ?? '';
    return value.isEmpty ? 'Materia non specificata' : value;
  }
}

class _LocalSubject {
  final String id;

  final int? subjectId;

  final String name;

  final String university;

  final String department;

  final String course;

  final int materialCount;

  const _LocalSubject({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.university,
    required this.department,
    required this.course,
    required this.materialCount,
  });
}

class _DuplicatePair {
  final String hash;
  final MaterialLocal mine;
  final MaterialLocal catalog;

  const _DuplicatePair({required this.hash, required this.mine, required this.catalog});
}

/// Riga di navigazione (ateneo, corso, materia, cartella, file sul dispositivo).
class _HierarchyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final SlTone tone;
  final bool dashed;
  final Widget? trailing;

  const _HierarchyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone = SlTone.info,
    this.dashed = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color accent = tone.resolve(p);
    return Material(
      color: dashed ? accent.withValues(alpha: 0.05) : AppColors.eleganceMidnight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dashed
              ? accent.withValues(alpha: 0.40)
              : (tone == SlTone.violet
                  ? accent.withValues(alpha: 0.20)
                  : AppColors.skyBlue.withValues(alpha: 0.10)),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SlIconTile(icon: icon, tone: tone, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.pureWhite.withValues(alpha: 0.60),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.pureWhite.withValues(alpha: 0.40),
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Materia del proprio corso con avanzamento dei file offline.
class _SubjectCard extends StatelessWidget {
  final String title;
  final int topics;
  final int files;
  final int offline;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.title,
    required this.topics,
    required this.files,
    required this.offline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = files == 0 ? 0 : offline / files;
    final bool complete = files > 0 && offline == files;
    final String detail = topics > 0
        ? '$topics ${topics == 1 ? 'argomento' : 'argomenti'} · $files file'
        : '$files file · nessun argomento';
    return Material(
      color: AppColors.eleganceMidnight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SlIconTile(icon: Icons.school_outlined, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(detail,
                        style: TextStyle(
                            color: AppColors.pureWhite.withValues(alpha: 0.60),
                            fontSize: 12)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4,
                        backgroundColor: AppColors.pureWhite.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.adminGreen),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('$offline di $files offline',
                        style: TextStyle(
                            color: complete
                                ? AppColors.adminGreen
                                : AppColors.pureWhite.withValues(alpha: 0.60),
                            fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.pureWhite.withValues(alpha: 0.40), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}


/// "Pubblica con StudentLab" quando il server trova un materiale già visibile
/// allo studente (canvas: Pubblica · duplicato rilevato).
/// Restituisce {'decision': 'cancel' | 'new_version' | 'separate', 'note': ...}.
class _PublicationDuplicatePage extends StatefulWidget {
  final Map<String, dynamic> duplicate;
  final String fileName;
  final int? fileSize;

  const _PublicationDuplicatePage({
    required this.duplicate,
    required this.fileName,
    required this.fileSize,
  });

  @override
  State<_PublicationDuplicatePage> createState() => _PublicationDuplicatePageState();
}

class _PublicationDuplicatePageState extends State<_PublicationDuplicatePage> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _size(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _close(String decision) {
    Navigator.of(context).pop(<String, dynamic>{'decision': decision, 'note': _note.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    final bool exact = widget.duplicate['exact'] == true;
    final bool canLink = widget.duplicate['id'] != null;
    final String title = widget.duplicate['title']?.toString() ?? 'Materiale già pubblicato';
    final List<String> path = widget.duplicate['path_segments'] is List
        ? (widget.duplicate['path_segments'] as List).map((e) => '$e').toList()
        : const <String>[];
    final String size = _size(widget.fileSize);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close('cancel');
      },
      child: Scaffold(
        backgroundColor: AppColors.darkElegance,
        appBar: AppBar(
          backgroundColor: AppColors.eleganceMidnight,
          foregroundColor: AppColors.pureWhite,
          leading: IconButton(
            tooltip: 'Chiudi',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _close('cancel'),
          ),
          title: const Text('Pubblica con StudentLab'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.eleganceMidnight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.pureWhite.withValues(alpha: 0.08)),
                ),
                child: Row(children: [
                  SlFileTile(kind: slFileKind(null, widget.fileName), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.fileName,
                          style: TextStyle(color: AppColors.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(size.isEmpty ? 'Dal tuo dispositivo' : 'Dal tuo dispositivo · $size',
                          style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.adminAmber.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.adminAmber.withValues(alpha: 0.40)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.content_copy_rounded, size: 20, color: AppColors.adminAmber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(exact ? 'Questo file è già su StudentLab' : 'Esiste un materiale simile',
                            style: TextStyle(color: AppColors.adminAmber, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          exact
                              ? 'Il contenuto è identico a un materiale già pubblicato, quindi non serve inviarlo di nuovo.'
                              : 'Nella stessa materia c’è un materiale con lo stesso nome o la stessa dimensione.',
                          style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.78), fontSize: 13, height: 1.45),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.eleganceMidnight, borderRadius: BorderRadius.circular(11)),
                    child: Row(children: [
                      SlFileTile(kind: slFileKind(null, widget.fileName), size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title,
                              style: TextStyle(color: AppColors.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                          if (path.isNotEmpty)
                            Text(path.join(' › '),
                                style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 11)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _close('cancel'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.skyBlue,
                      foregroundColor: AppColors.darkElegance,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Usa quello pubblicato'),
                  ),
                  const SizedBox(height: 8),
                  Text('La tua copia resta nelle tue dispense finché non decidi di rimuoverla.',
                      style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.62), fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.eleganceMidnight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.pureWhite.withValues(alpha: 0.08)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Hai modificato il file?',
                      style: TextStyle(color: AppColors.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    'Se contiene correzioni o aggiunte, proponilo come nuova versione: StudentLab confronterà le due copie.',
                    style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.66), fontSize: 12, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 5,
                    style: TextStyle(color: AppColors.pureWhite, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Cosa hai cambiato',
                      hintText: 'Es. corrette le slide 14–18',
                      filled: true,
                      fillColor: AppColors.darkElegance,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: canLink ? () => _close('new_version') : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.diamondDust,
                      backgroundColor: AppColors.skyBlue.withValues(alpha: 0.08),
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Proponi come nuova versione'),
                  ),
                  if (!exact) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _close('separate'),
                      child: const Text('È un materiale diverso: invia come nuovo'),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Ricerca nelle Dispense: nome del file, materia, corso o cartella.
class _DispenseSearchDelegate extends SearchDelegate<MaterialLocal?> {
  final List<MaterialLocal> materials;

  _DispenseSearchDelegate(this.materials)
      : super(searchFieldLabel: 'Cerca file, materia o cartella');

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData base = Theme.of(context);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: AppColors.eleganceMidnight),
      inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
      scaffoldBackgroundColor: AppColors.darkElegance,
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Cancella',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        tooltip: 'Indietro',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, null),
      );

  List<MaterialLocal> _matches() {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    return materials.where((m) {
      final text = <String>[
        m.originalName,
        m.displaySubjectName,
        m.displayCourse,
        ...m.pathSegments,
      ].join(' ').toLowerCase();
      return text.contains(q);
    }).take(50).toList();
  }

  Widget _list(BuildContext context) {
    final results = _matches();
    if (query.trim().length < 2) {
      return Center(
        child: Text('Scrivi almeno due lettere.',
            style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60))),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Text('Nessun file trovato.',
            style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = results[index];
        return Material(
          color: AppColors.eleganceMidnight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.10)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => close(context, m),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                SlFileTile(kind: slFileKind(null, m.originalName), size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.originalName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(
                      <String>[m.displayCourse, m.displaySubjectName, ...m.pathSegments]
                          .where((e) => e.trim().isNotEmpty)
                          .join(' › '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.60), fontSize: 11),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);
}
