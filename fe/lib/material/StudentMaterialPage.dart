import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';

import 'package:fe/services/api_service.dart';
import 'package:fe/services/auth_session.dart';
import 'package:fe/services/picked_file_bridge.dart';

import 'package:fe/social/social_models.dart';

import 'package:fe/material/models/study_material.dart';
import 'package:fe/material/widgets/material_card.dart';

import 'package:fe/local_storage/models/material_local.dart';
import 'package:fe/local_storage/models/material_offline_entry.dart';
import 'package:fe/local_storage/repositories/material_repository.dart';
import 'package:fe/local_storage/services/local_material_import_service.dart';
import 'package:fe/local_storage/services/material_download_service.dart';
import 'package:fe/local_storage/services/material_sync_service.dart';

class StudentMaterialPage extends StatefulWidget {
  const StudentMaterialPage({super.key});

  @override
  State<StudentMaterialPage> createState() => _StudentMaterialPageState();
}

class _StudentMaterialPageState extends State<StudentMaterialPage> {
  final MaterialDownloadService _downloadService = MaterialDownloadService();
  final LocalMaterialImportService _localImportService =
      LocalMaterialImportService();
  final MaterialRepository _materialRepository = MaterialRepository();
  final MaterialSyncService _syncService = MaterialSyncService();
  final ApiService _apiService = ApiService();
  final AuthSession _authSession = AuthSession.instance;

  List<MaterialLocal> _materials = [];
  List<MaterialOfflineEntry> _offlineMaterials = [];
  final Set<int> _processingMaterialIds = <int>{};
  bool _usingOfflineCache = false;

  String? _selectedUniversity;

  String? _selectedDepartment;

  String? _selectedCourse;

  _LocalSubject? _selectedSubject;

  bool _loading = true;

  bool _openingPublicationForm = false;

  bool _openingOfflineForm = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _authSession.addListener(_onAuthChanged);

    _loadMaterials();
  }

  @override
  void dispose() {
    _authSession.removeListener(_onAuthChanged);

    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
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
          await _syncService.syncMaterials(
            userId: currentUserId,
            forceFull: true,
          );
        } catch (_) {
          syncFailed = true;
        }
      }
    }

    try {
      final List<MaterialLocal> availableMaterials =
          await _materialRepository.getAvailableByUser(localUserId);

      final List<MaterialLocal> materials = availableMaterials
          .where(_isDisplayableMaterial)
          .toList();

      final List<MaterialOfflineEntry> offline = await _downloadService
          .getDownloadedMaterialEntries(userId: localUserId);

      if (!mounted) {
        return;
      }

      setState(() {
        _materials = materials;
        _offlineMaterials = offline;
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

  bool _isDisplayableMaterial(MaterialLocal material) {
    final String university = material.university?.trim() ?? '';
    final String department = material.department?.trim() ?? '';
    final String course = material.course?.trim() ?? '';
    final String subjectName = material.subjectName?.trim() ?? '';

    final bool hasSubject = material.subjectId != null || subjectName.isNotEmpty;

    return university.isNotEmpty &&
        department.isNotEmpty &&
        course.isNotEmpty &&
        hasSubject;
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
          material.displayCourse != course) {
        continue;
      }

      final String name = material.subjectName?.trim() ?? '';

      if (material.subjectId == null && name.isEmpty) {
        continue;
      }

      final String key = material.subjectId != null
          ? 'id:${material.subjectId}'
          : 'name:${name.toLowerCase()}';

      grouped.putIfAbsent(key, () => <MaterialLocal>[]).add(material);
    }

    final List<_LocalSubject> result = grouped.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) {
          final MaterialLocal first = entry.value.first;
          return _LocalSubject(
            id: entry.key,
            subjectId: first.subjectId,
            name: first.displaySubjectName,
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
          material.displayCourse != course) {
        return false;
      }

      if (subject.subjectId != null) {
        return material.subjectId == subject.subjectId;
      }

      return material.displaySubjectName.toLowerCase() ==
          subject.name.toLowerCase();
    }).toList();

    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
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

  int _countCourse(String course) {
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
              _sameText(material.displayCourse, course),
        )
        .length;
  }

  bool get _hasSelection {
    return _selectedUniversity != null ||
        _selectedDepartment != null ||
        _selectedCourse != null ||
        _selectedSubject != null;
  }

  String get _pageTitle {
    if (_selectedSubject != null) {
      return _selectedSubject!.name;
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

    return 'Materiale';
  }

  void _goBack() {
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: _buildAppBar(),

      body: SafeArea(child: _buildBody()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.brandNightBlue,

      foregroundColor: AppColors.pureWhite,

      automaticallyImplyLeading: false,

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

        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
      ),

      actions: [
        IconButton(
          tooltip: 'Aggiorna',

          onPressed: _loading ? null : _loadMaterials,

          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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

  Widget _buildUniversityPage() {
    return RefreshIndicator(
      onRefresh: _loadMaterials,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(20),

        children: [
          if (_usingOfflineCache) ...[
            _buildOfflineSyncBanner(),
            const SizedBox(height: 14),
          ],
          _buildMaterialActions(),

          const SizedBox(height: 20),

          if (_universities.isEmpty)
            _buildEmptyLibrary()
          else
            _buildGrid(
              _universities.map((String university) {
                return _HierarchyCard(
                  icon: Icons.account_balance_rounded,

                  title: university,

                  subtitle: _materialCountText(_countUniversity(university)),

                  onTap: () {
                    setState(() {
                      _selectedUniversity = university;

                      _selectedDepartment = null;

                      _selectedCourse = null;

                      _selectedSubject = null;
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentPage() {
    return _buildHierarchyList(
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
    return _buildHierarchyList(
      children: _courses.map((String course) {
        return _HierarchyCard(
          icon: Icons.school_rounded,

          title: course,

          subtitle: _materialCountText(_countCourse(course)),

          onTap: () {
            setState(() {
              _selectedCourse = course;

              _selectedSubject = null;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSubjectPage() {
    final List<_LocalSubject> subjects = _subjects;

    if (subjects.isEmpty) {
      return Center(
        child: _buildEmptyHierarchy('Nessuna materia disponibile.'),
      );
    }

    return _buildHierarchyList(
      children: subjects.map((_LocalSubject subject) {
        return _HierarchyCard(
          icon: Icons.menu_book_rounded,

          title: subject.name,

          subtitle: _materialCountText(subject.materialCount),

          onTap: () {
            setState(() {
              _selectedSubject = subject;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildHierarchyList({required List<Widget> children}) {
    return RefreshIndicator(
      onRefresh: _loadMaterials,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(20),

        children: [
          if (children.isEmpty)
            _buildEmptyHierarchy('Nessun contenuto disponibile.')
          else
            _buildGrid(children),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        int columns = 2;

        if (constraints.maxWidth < 480) {
          columns = 1;
        } else if (constraints.maxWidth >= 820) {
          columns = 3;
        }

        return GridView.count(
          crossAxisCount: columns,

          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          crossAxisSpacing: 14,

          mainAxisSpacing: 14,

          childAspectRatio: columns == 1 ? 2.65 : 1.55,

          children: children,
        );
      },
    );
  }

  Widget _buildMaterialPage() {
    final _LocalSubject subject = _selectedSubject!;
    final List<MaterialLocal> materials = _selectedMaterials;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: _loadMaterials,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildSubjectHeader(subject),
              const SizedBox(height: 14),
              _buildSourceSummary(materials),
              const SizedBox(height: 24),
              const Text(
                'Materiali',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _materialCountText(materials.length),
                style: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.48),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              if (materials.isEmpty)
                _buildEmptyMaterials()
              else
                ...materials.map(_buildMaterialEntry),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialEntry(MaterialLocal material) {
    final MaterialOfflineEntry? offline = _offlineEntryFor(material);
    final bool isOffline = offline != null;
    final bool isLocal = material.source == MaterialSourceLocal.local;
    final bool processing =
        material.id != null && _processingMaterialIds.contains(material.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MaterialCard(
            material: _toStudyMaterial(material, offline),
            provenanceLabel: _provenanceLabel(material.source),
            provenanceIcon: _provenanceIcon(material.source),
            provenanceVerified: material.source == MaterialSourceLocal.teacher,
            onTap: () {
              if (processing) {
                return;
              }

              if (isOffline) {
                _openMaterial(material);
              } else if (!isLocal) {
                _downloadRemoteMaterial(material);
              }
            },
          ),
          const SizedBox(height: 7),
          _buildAvailabilityRow(material: material, offline: isOffline),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: isLocal
                    ? OutlinedButton.icon(
                        onPressed: processing
                            ? null
                            : () {
                                _confirmDeleteMaterial(material);
                              },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Elimina',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : isOffline
                    ? OutlinedButton.icon(
                        onPressed: processing
                            ? null
                            : () {
                                _removeRemoteDownload(material);
                              },
                        icon: const Icon(Icons.cloud_off_outlined, size: 16),
                        label: const Text('Rimuovi offline'),
                      )
                    : OutlinedButton.icon(
                        onPressed: processing
                            ? null
                            : () {
                                _downloadRemoteMaterial(material);
                              },
                        icon: processing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 16),
                        label: Text(processing ? 'Download...' : 'Scarica'),
                      ),
              ),
              if (isLocal && _authSession.isAuthenticated) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openingPublicationForm || processing
                        ? null
                        : () {
                            _openPublicationForMaterial(material);
                          },
                    icon: const Icon(Icons.publish_outlined, size: 16),
                    label: const Text('Proponi a StudentLab'),
                  ),
                ),
              ],
              if (!isLocal && isOffline) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: processing
                        ? null
                        : () {
                            _openMaterial(material);
                          },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Apri'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityRow({
    required MaterialLocal material,
    required bool offline,
  }) {
    final bool local = material.source == MaterialSourceLocal.local;
    final String label = local
        ? 'Sul dispositivo'
        : offline
        ? 'Disponibile offline'
        : 'Solo online';
    final IconData icon = local || offline
        ? Icons.offline_pin_rounded
        : Icons.cloud_outlined;

    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.materialSky),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.pureWhite.withValues(alpha: 0.54),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (material.source == MaterialSourceLocal.group &&
            material.groupId != null) ...[
          const SizedBox(width: 8),
          Text(
            '• Gruppo ${material.groupId}',
            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.36),
              fontSize: 9,
            ),
          ),
        ],
        if (material.remoteVersion != null &&
            material.source != MaterialSourceLocal.local) ...[
          const SizedBox(width: 8),
          Text(
            '• v${material.remoteVersion}',
            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.36),
              fontSize: 9,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSourceSummary(List<MaterialLocal> materials) {
    final Map<MaterialSourceLocal, int> counts = {
      for (final MaterialSourceLocal source in MaterialSourceLocal.values)
        source: 0,
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: visible.map((MaterialSourceLocal source) {
        final int count = counts[source] ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.brandNightBlue.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.skyBlue.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _provenanceIcon(source),
              const SizedBox(width: 6),
              Text(
                '${_provenanceLabel(source)} • $count',
                style: TextStyle(
                  color: AppColors.pureWhite.withValues(alpha: 0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceDeepNavy,
          title: const Text(
            'Elimina materiale',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: Text(
            material.source == MaterialSourceLocal.local
                ? 'Vuoi eliminare "${material.originalName}" dalla libreria locale?'
                : 'Vuoi rimuovere "${material.originalName}" dai materiali disponibili offline?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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

  Widget _buildMaterialActions() {
    return Column(
      children: [
        _buildActionCard(
          icon: Icons.create_new_folder_outlined,
          title: 'Aggiungi offline',
          description: 'Salva un tuo file nelle dispense locali di StudentLab.',
          loading: _openingOfflineForm,
          onTap: _openingOfflineForm ? null : _openOfflineMaterial,
        ),
        if (_authSession.isAuthenticated) ...[
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.publish_outlined,
            title: 'Proponi a StudentLab',
            description:
                'Invia un materiale alla revisione prima della pubblicazione.',
            loading: _openingPublicationForm,
            onTap: _openingPublicationForm ? null : _openPublication,
          ),
        ] else ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.brandNightBlue.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.materialSky,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Accedi o registrati quando vuoi proporre uno dei tuoi materiali alla community.',
                    style: TextStyle(
                      color: AppColors.pureWhite.withValues(alpha: 0.52),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
        decoration: BoxDecoration(
          color: AppColors.eleganceMidnight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.30)),
        ),
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
                  ? const Padding(
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
                    style: const TextStyle(
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
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
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

    final String? filePath = await _downloadService.getFileForMaterial(material);

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

  Widget _buildSubjectHeader(_LocalSubject subject) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.15)),
      ),

      child: Row(
        children: [
          Container(
            width: 54,

            height: 54,

            decoration: BoxDecoration(
              color: AppColors.brandNightBlue,

              borderRadius: BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.menu_book_rounded,

              color: AppColors.skyBlue,

              size: 28,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  subject.name,

                  style: const TextStyle(
                    color: AppColors.pureWhite,

                    fontSize: 17,

                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${subject.department} • ${subject.course}',

                  style: TextStyle(
                    color: AppColors.pureWhite.withValues(alpha: 0.46),

                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
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
    }
  }

  Widget _provenanceIcon(MaterialSourceLocal source) {
    switch (source) {
      case MaterialSourceLocal.local:
        return const Icon(
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
                  return const Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: AppColors.materialSky,
                  );
                },
          ),
        );
      case MaterialSourceLocal.teacher:
        return const Icon(
          Icons.co_present_rounded,
          size: 15,
          color: AppColors.materialSky,
        );
      case MaterialSourceLocal.group:
        return const Icon(
          Icons.groups_rounded,
          size: 15,
          color: AppColors.materialSky,
        );
    }
  }

  StudyMaterial _toStudyMaterial(
    MaterialLocal material,
    MaterialOfflineEntry? offline,
  ) {
    return StudyMaterial(
      id: (material.id ?? material.remoteId ?? 0).toString(),
      name: material.originalName,
      type: _materialType(material, offline),
      size: offline == null ? 'Solo online' : _formatSize(offline.file.size),
    );
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.brandNightBlue.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.materialSky,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Sincronizzazione non disponibile. Stai visualizzando i materiali già salvati sul dispositivo.',
              style: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: 0.58),
                fontSize: 10,
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

          const Text(
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

      child: const Column(
        children: [
          Icon(Icons.folder_open_rounded, color: Colors.white38, size: 45),

          SizedBox(height: 12),

          Text(
            'Nessun materiale disponibile',

            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.white70, fontSize: 14),
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
          const Icon(
            Icons.error_outline_rounded,

            color: Colors.redAccent,

            size: 40,
          ),

          const SizedBox(height: 12),

          Text(
            _error ?? 'Impossibile caricare la libreria dei materiali.',

            textAlign: TextAlign.center,

            style: const TextStyle(color: Colors.white60, fontSize: 11),
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

  String? _filePath;
  String? _fileName;

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
      final String path = await _fileBridge.materialize(file);

      setState(() {
        _filePath = path;
        _fileName = file.name;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Non è stato possibile selezionare il file.');
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String? filePath = _filePath;

    if (filePath == null || filePath.trim().isEmpty) {
      _showMessage('Seleziona il file da aggiungere alle dispense.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    bool completed = false;

    try {
      final SocialSubject? catalogSubject = _resolvedCatalogSubject;

      final String university = _universityController.text.trim();
      final String department = _departmentController.text.trim();
      final String course = _courseController.text.trim();
      final String subjectName = _subjectController.text.trim();
      final String? originalName = _fileName;

      await widget.importService.importMaterial(
        sourcePath: filePath,
        university: university,
        department: department,
        course: course,
        subjectName: subjectName,
        originalName: originalName,
        subjectId: catalogSubject?.id,
      );

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
        title: const Text('Aggiungi offline'),
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
                      'Ateneo, dipartimento, corso e materia sono obbligatori per organizzare correttamente '
                      'le dispense e permettere il collegamento automatico alle card.',
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
                  const SizedBox(height: 13),
                  _hybridField(
                    controller: _subjectController,
                    label: 'Materia *',
                    icon: Icons.menu_book_outlined,
                    options: _subjectOptions,
                    loading: _loadingSubjects,
                    onOptionSelected: _selectSubjectOption,
                    requiredField: true,
                  ),
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
                          const Icon(
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
                                    ? Colors.white54
                                    : AppColors.pureWhite,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 15),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
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
                          ? const SizedBox(
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

      style: const TextStyle(color: AppColors.pureWhite),

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
            ? const Padding(
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

                icon: const Icon(
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

                            style: const TextStyle(color: AppColors.pureWhite),
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
      final String path = await _fileBridge.materialize(selected);

      setState(() {
        _selectedFilePath = path;
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

    if (subject == null) {
      _showMessage('Seleziona la materia del materiale.');
      return;
    }

    if (filePath == null || filePath.trim().isEmpty) {
      _showMessage('Seleziona il file da proporre.');
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
      await widget.apiService.uploadMaterialPublication(
        subjectId: subject.id,
        title: title,
        description: description,
        filePath: filePath,
        onPossibleDuplicate: () async {
          if (!mounted) {
            return;
          }

          _showMessage(
            'StudentLab ha rilevato un materiale simile. '
            'La tua proposta verrà comunque inviata alla revisione.',
          );
        },
      );

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

                          style: const TextStyle(color: AppColors.pureWhite),

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

                          style: const TextStyle(color: AppColors.pureWhite),

                          decoration: _decoration(
                            label: 'Descrizione',

                            icon: Icons.notes_rounded,

                            hint:
                                'Descrivi brevemente il contenuto del materiale',
                          ),
                        ),

                        const SizedBox(height: 8),

                        _buildFilePicker(),

                        const SizedBox(height: 24),

                        SizedBox(
                          height: 54,

                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,

                            icon: _submitting
                                ? const SizedBox(
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
          const Icon(
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

            style: const TextStyle(color: AppColors.pureWhite),
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

            style: const TextStyle(color: AppColors.pureWhite),
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

            style: const TextStyle(color: AppColors.pureWhite),
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

            style: const TextStyle(color: AppColors.pureWhite),
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
            const Icon(Icons.attach_file_rounded, color: AppColors.skyBlue),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    _selectedFileName ?? 'Seleziona file',

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
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

            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.20)),
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
              _error!,

              style: const TextStyle(
                color: Colors.white70,

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

        borderSide: const BorderSide(color: AppColors.socialBlue),
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

class _HierarchyCard extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;

  const _HierarchyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(18),

        child: Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: AppColors.eleganceMidnight,

            borderRadius: BorderRadius.circular(18),

            border: Border.all(
              color: AppColors.skyBlue.withValues(alpha: 0.10),
            ),
          ),

          child: Row(
            children: [
              Container(
                width: 44,

                height: 44,

                decoration: BoxDecoration(
                  color: AppColors.brandNightBlue,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Icon(icon, color: AppColors.skyBlue, size: 22),
              ),

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

                      style: const TextStyle(
                        color: AppColors.pureWhite,

                        fontSize: 13,

                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,

                      style: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: 0.42),

                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,

                color: Colors.white30,

                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}