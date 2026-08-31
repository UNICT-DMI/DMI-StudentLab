import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../social/social_models.dart';
import '../../theme/nightTheme.dart';

import 'teacher_material_assignments_section.dart';

class TeacherMaterialsSection extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;

  const TeacherMaterialsSection({
    super.key,
    required this.subjects,
  });

  @override
  State<TeacherMaterialsSection> createState() =>
      _TeacherMaterialsSectionState();
}

class _TeacherMaterialsSectionState extends State<TeacherMaterialsSection> {
  final ApiService _apiService = ApiService();

  bool _loading = true;
  bool _processing = false;
  String? _error;
  List<Map<String, dynamic>> _materials = [];
  List<_TeacherGroupMaterial> _groupMaterials = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final SocialUser currentUser = await _apiService.getCurrentUser();
      final List<Map<String, dynamic>> materials =
          await _apiService.getTeacherMaterials();

      List<_TeacherGroupMaterial> groupMaterials = [];

      try {
        final List<Map<String, dynamic>> groups =
            await _apiService.getUserGroups(currentUser.id);

        for (final Map<String, dynamic> group in groups) {
          final int? groupId = _toInt(group['id']);
          if (groupId == null) {
            continue;
          }

          try {
            final List<Map<String, dynamic>> items =
                await _apiService.getGroupMaterials(groupId);
            final String groupName =
                _firstNonEmpty([group['name'], group['title'], 'Gruppo $groupId']);

            for (final Map<String, dynamic> item in items) {
              final int? uploaderId = _toInt(
                item['uploaded_by'] ??
                    item['uploaded_by_user_id'] ??
                    item['user_id'],
              );

              if (uploaderId == currentUser.id) {
                groupMaterials.add(
                  _TeacherGroupMaterial(
                    groupId: groupId,
                    groupName: groupName,
                    data: item,
                  ),
                );
              }
            }
          } catch (_) {}
        }
      } catch (_) {}

      if (!mounted) {
        return;
      }

      setState(() {
        _materials = materials;
        _groupMaterials = groupMaterials;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _createMaterial() async {
    if (_processing) {
      return;
    }

    if (widget.subjects.isEmpty) {
      _showMessage(
        'Serve almeno una materia verificata per caricare un materiale.',
      );
      return;
    }

    final _TeacherMaterialDraft? draft =
        await showModalBottomSheet<_TeacherMaterialDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceMidnight,
      builder: (BuildContext context) {
        return _TeacherMaterialCreateSheet(subjects: widget.subjects);
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _apiService.uploadTeacherMaterial(
        subjectId: draft.subjectId,
        title: draft.title,
        description: draft.description,
        visibility: draft.visibility,
        filePath: draft.filePath,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Materiale caricato correttamente.');
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(_cleanError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _editMaterial(Map<String, dynamic> material) async {
    if (_processing) {
      return;
    }

    final _TeacherMaterialEdit? edit =
        await showDialog<_TeacherMaterialEdit>(
      context: context,
      builder: (BuildContext context) {
        return _TeacherMaterialEditDialog(material: material);
      },
    );

    if (edit == null || !mounted) {
      return;
    }

    final int? materialId = _toInt(material['id']);
    if (materialId == null) {
      _showMessage('Materiale non valido.');
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _apiService.updateTeacherMaterial(
        materialId: materialId,
        title: edit.title,
        description: edit.description,
        visibility: edit.visibility,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Materiale aggiornato.');
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(_cleanError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _deleteMaterial(Map<String, dynamic> material) async {
    if (_processing) {
      return;
    }

    final int? materialId = _toInt(material['id']);
    if (materialId == null) {
      _showMessage('Materiale non valido.');
      return;
    }

    final String title = _firstNonEmpty([
      material['title'],
      material['original_name'],
      'questo materiale',
    ]);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.eleganceMidnight,
          title: const Text(
            'Elimina materiale',
            style: TextStyle(color: AppColors.pureWhite),
          ),
          content: Text(
            'Vuoi eliminare definitivamente “$title”?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Elimina',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _apiService.deleteTeacherMaterial(materialId);

      if (!mounted) {
        return;
      }

      _showMessage('Materiale eliminato.');
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage(_cleanError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Materiali docente',
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gestisci i tuoi materiali e controlla quelli pubblicati nei gruppi.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Aggiorna materiali',
              onPressed: _processing ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.materialSky,
            ),
            FilledButton.icon(
              onPressed: _processing ? null : _createMaterial,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nuovo'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teacherIndigo,
                foregroundColor: AppColors.pureWhite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          const _TeacherMaterialsLoading()
        else if (_error != null)
          _TeacherMaterialsError(
            message: _error!,
            onRetry: _load,
          )
        else ...[
          _TeacherMaterialSummary(
            materialCount: _materials.length,
            groupPublicationCount: _groupMaterials.length,
          ),
          const SizedBox(height: 14),
          _buildOwnMaterials(),
          const SizedBox(height: 14),
          _buildGroupMaterials(),
          const SizedBox(height: 14),
          TeacherMaterialAssignmentsSection(materials: _materials),
        ],
      ],
    );
  }

  Widget _buildOwnMaterials() {
    return _SectionCard(
      icon: Icons.folder_copy_outlined,
      title: 'I miei materiali',
      badge: '${_materials.length}',
      child: _materials.isEmpty
          ? const _EmptyMessage(
              icon: Icons.folder_open_outlined,
              text: 'Non hai ancora caricato materiali.',
            )
          : Column(
              children: [
                for (int index = 0; index < _materials.length; index++) ...[
                  _TeacherMaterialRow(
                    material: _materials[index],
                    subjectName: _subjectName(_toInt(_materials[index]['subject_id'])),
                    processing: _processing,
                    onEdit: () => _editMaterial(_materials[index]),
                    onDelete: () => _deleteMaterial(_materials[index]),
                  ),
                  if (index != _materials.length - 1)
                    const Divider(height: 1, color: Colors.white10),
                ],
              ],
            ),
    );
  }

  Widget _buildGroupMaterials() {
    return _SectionCard(
      icon: Icons.groups_2_outlined,
      title: 'Pubblicati nei gruppi',
      badge: '${_groupMaterials.length}',
      child: _groupMaterials.isEmpty
          ? const _EmptyMessage(
              icon: Icons.group_work_outlined,
              text: 'Nessun materiale pubblicato direttamente da te nei gruppi.',
            )
          : Column(
              children: [
                for (int index = 0;
                    index < _groupMaterials.length;
                    index++) ...[
                  _GroupMaterialRow(item: _groupMaterials[index]),
                  if (index != _groupMaterials.length - 1)
                    const Divider(height: 1, color: Colors.white10),
                ],
              ],
            ),
    );
  }

  String _subjectName(int? subjectId) {
    if (subjectId == null) {
      return '';
    }

    for (final Map<String, dynamic> subject in widget.subjects) {
      if (_toInt(subject['id']) == subjectId) {
        return _firstNonEmpty([
          subject['name'],
          subject['code'],
        ]);
      }
    }

    return 'Materia #$subjectId';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String normalized = value?.toString().trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  String _cleanError(Object error) {
    String message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }
    return message.isEmpty
        ? 'Impossibile caricare i materiali docente.'
        : message;
  }
}

class _TeacherMaterialSummary extends StatelessWidget {
  final int materialCount;
  final int groupPublicationCount;

  const _TeacherMaterialSummary({
    required this.materialCount,
    required this.groupPublicationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.description_outlined,
            value: '$materialCount',
            label: 'Materiali docente',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            icon: Icons.groups_outlined,
            value: '$groupPublicationCount',
            label: 'Pubblicati nei gruppi',
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.teacherIndigo.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.materialSky, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.teacherIndigo.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.teacherIndigo, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        AppColors.teacherIndigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: AppColors.teacherIndigo,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          child,
        ],
      ),
    );
  }
}

class _TeacherMaterialRow extends StatelessWidget {
  final Map<String, dynamic> material;
  final String subjectName;
  final bool processing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TeacherMaterialRow({
    required this.material,
    required this.subjectName,
    required this.processing,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final String title =
        _value(material['title'], material['original_name'], 'Materiale');
    final String fileName =
        _value(material['original_name'], null, 'File');
    final String description = material['description']?.toString().trim() ?? '';
    final String visibility =
        material['visibility']?.toString().trim().toLowerCase() ?? 'private';
    final String status =
        material['status']?.toString().trim().toLowerCase() ?? 'active';
    final int version = _asInt(material['version']) ?? 1;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.materialSky.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.insert_drive_file_outlined,
              color: AppColors.materialSky,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (subjectName.isNotEmpty)
                      _MiniBadge(
                        label: subjectName,
                        icon: Icons.school_outlined,
                      ),
                    _MiniBadge(
                      label: visibility == 'students'
                          ? 'Tutti gli studenti'
                          : 'Privato',
                      icon: visibility == 'students'
                          ? Icons.public_outlined
                          : Icons.lock_outline_rounded,
                    ),
                    _MiniBadge(
                      label: status == 'active' ? 'Attivo' : status,
                      icon: Icons.circle,
                    ),
                    _MiniBadge(
                      label: 'v$version',
                      icon: Icons.history_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Azioni materiale',
            enabled: !processing,
            color: AppColors.eleganceMidnight,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
            onSelected: (String value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 9),
                    Text('Modifica'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.redAccent),
                    SizedBox(width: 9),
                    Text(
                      'Elimina',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _value(dynamic first, dynamic second, String fallback) {
    final String a = first?.toString().trim() ?? '';
    if (a.isNotEmpty) {
      return a;
    }
    final String b = second?.toString().trim() ?? '';
    return b.isNotEmpty ? b : fallback;
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

class _GroupMaterialRow extends StatelessWidget {
  final _TeacherGroupMaterial item;

  const _GroupMaterialRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final String name =
        item.data['original_name']?.toString().trim().isNotEmpty == true
            ? item.data['original_name'].toString().trim()
            : 'Materiale gruppo';

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teacherIndigo.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.group_work_outlined,
              color: AppColors.teacherIndigo,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.materialSky,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const _MiniBadge(
            label: 'Gruppo',
            icon: Icons.groups_outlined,
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniBadge({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyMessage({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 25),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherMaterialsLoading extends StatelessWidget {
  const _TeacherMaterialsLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const CircularProgressIndicator(
        color: AppColors.teacherIndigo,
      ),
    );
  }
}

class _TeacherMaterialsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _TeacherMaterialsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ),
          TextButton(
            onPressed: () {
              onRetry();
            },
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}

class _TeacherMaterialCreateSheet extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;

  const _TeacherMaterialCreateSheet({
    required this.subjects,
  });

  @override
  State<_TeacherMaterialCreateSheet> createState() =>
      _TeacherMaterialCreateSheetState();
}

class _TeacherMaterialCreateSheetState
    extends State<_TeacherMaterialCreateSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  int? _subjectId;
  String _visibility = 'students';
  PlatformFile? _file;

  @override
  void initState() {
    super.initState();
    if (widget.subjects.length == 1) {
      _subjectId = _toInt(widget.subjects.first['id']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'txt',
        'zip',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'csv',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final PlatformFile file = result.files.single;
    if (file.path == null || file.path!.trim().isEmpty) {
      return;
    }

    setState(() {
      _file = file;
    });
  }

  void _submit() {
    final String title = _titleController.text.trim();
    final int? subjectId = _subjectId;
    final String? filePath = _file?.path;

    if (subjectId == null) {
      _message('Seleziona una materia.');
      return;
    }

    if (title.isEmpty) {
      _message('Inserisci il titolo del materiale.');
      return;
    }

    if (filePath == null || filePath.trim().isEmpty) {
      _message('Seleziona un file.');
      return;
    }

    Navigator.pop(
      context,
      _TeacherMaterialDraft(
        subjectId: subjectId,
        title: title,
        description: _descriptionController.text.trim(),
        visibility: _visibility,
        filePath: filePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nuovo materiale docente',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Il file verrà associato a una delle tue materie verificate.',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: _subjectId,
                dropdownColor: AppColors.eleganceMidnight,
                decoration: const InputDecoration(
                  labelText: 'Materia',
                  border: OutlineInputBorder(),
                ),
                items: widget.subjects
                    .map(
                      (Map<String, dynamic> subject) {
                        final int? id = _toInt(subject['id']);
                        if (id == null) {
                          return null;
                        }
                        final String name =
                            subject['name']?.toString().trim().isNotEmpty ==
                                    true
                                ? subject['name'].toString().trim()
                                : 'Materia #$id';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name),
                        );
                      },
                    )
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: (int? value) {
                  setState(() {
                    _subjectId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Titolo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                dropdownColor: AppColors.eleganceMidnight,
                decoration: const InputDecoration(
                  labelText: 'Visibilità',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'students',
                    child: Text('Visibile agli studenti'),
                  ),
                  DropdownMenuItem(
                    value: 'private',
                    child: Text('Privato / solo assegnazioni'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _visibility = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.darkElegance.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.materialSky,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _file?.name ?? 'Seleziona file',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _file == null
                                ? Colors.white54
                                : AppColors.pureWhite,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Carica materiale'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teacherIndigo,
                    foregroundColor: AppColors.pureWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
}

class _TeacherMaterialEditDialog extends StatefulWidget {
  final Map<String, dynamic> material;

  const _TeacherMaterialEditDialog({
    required this.material,
  });

  @override
  State<_TeacherMaterialEditDialog> createState() =>
      _TeacherMaterialEditDialogState();
}

class _TeacherMaterialEditDialogState
    extends State<_TeacherMaterialEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _visibility;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.material['title']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.material['description']?.toString() ?? '',
    );

    final String value =
        widget.material['visibility']?.toString().trim().toLowerCase() ?? '';
    _visibility = value == 'students' ? 'students' : 'private';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.pop(
      context,
      _TeacherMaterialEdit(
        title: title,
        description: _descriptionController.text.trim(),
        visibility: _visibility,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.eleganceMidnight,
      title: const Text(
        'Modifica materiale',
        style: TextStyle(color: AppColors.pureWhite),
      ),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width < 460
            ? double.maxFinite
            : 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Titolo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                dropdownColor: AppColors.eleganceMidnight,
                decoration: const InputDecoration(
                  labelText: 'Visibilità',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'students',
                    child: Text('Visibile agli studenti'),
                  ),
                  DropdownMenuItem(
                    value: 'private',
                    child: Text('Privato / solo assegnazioni'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _visibility = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _TeacherMaterialDraft {
  final int subjectId;
  final String title;
  final String description;
  final String visibility;
  final String filePath;

  const _TeacherMaterialDraft({
    required this.subjectId,
    required this.title,
    required this.description,
    required this.visibility,
    required this.filePath,
  });
}

class _TeacherMaterialEdit {
  final String title;
  final String description;
  final String visibility;

  const _TeacherMaterialEdit({
    required this.title,
    required this.description,
    required this.visibility,
  });
}

class _TeacherGroupMaterial {
  final int groupId;
  final String groupName;
  final Map<String, dynamic> data;

  const _TeacherGroupMaterial({
    required this.groupId,
    required this.groupName,
    required this.data,
  });
}