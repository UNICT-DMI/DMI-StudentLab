import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../social/social_models.dart';
import '../../theme/nightTheme.dart';

class TeacherMaterialAssignmentsSection extends StatefulWidget {
  final List<Map<String, dynamic>> materials;

  const TeacherMaterialAssignmentsSection({
    super.key,
    required this.materials,
  });

  @override
  State<TeacherMaterialAssignmentsSection> createState() =>
      _TeacherMaterialAssignmentsSectionState();
}

class _TeacherMaterialAssignmentsSectionState
    extends State<TeacherMaterialAssignmentsSection> {
  final ApiService _apiService = ApiService();

  bool _loading = true;
  bool _processing = false;
  bool _includeRevoked = false;
  String? _error;
  int? _currentUserId;

  List<SocialUser> _students = [];
  List<Map<String, dynamic>> _groups = [];
  final Map<int, List<Map<String, dynamic>>> _assignmentsByMaterial = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant TeacherMaterialAssignmentsSection oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final Set<int> oldIds = oldWidget.materials
        .map((material) => _toInt(material['id']))
        .whereType<int>()
        .toSet();
    final Set<int> newIds = widget.materials
        .map((material) => _toInt(material['id']))
        .whereType<int>()
        .toSet();

    if (oldIds.length != newIds.length ||
        !oldIds.containsAll(newIds) ||
        !newIds.containsAll(oldIds)) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final SocialUser currentUser = await _apiService.getCurrentUser();
      final List<SocialUser> users = await _apiService.getSocialUsers();
      final List<Map<String, dynamic>> groups =
          await _apiService.getUserGroups(currentUser.id);

      final Map<int, List<Map<String, dynamic>>> assignments = {};

      for (final Map<String, dynamic> material in widget.materials) {
        final int? materialId = _toInt(material['id']);
        if (materialId == null) {
          continue;
        }

        assignments[materialId] =
            await _apiService.getTeacherMaterialAssignments(
          materialId: materialId,
          includeRevoked: _includeRevoked,
        );
      }

      final List<SocialUser> students = users
          .where(
            (user) =>
                user.id != currentUser.id &&
                user.isStudent &&
                user.isActive,
          )
          .toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

      final List<Map<String, dynamic>> sortedGroups =
          List<Map<String, dynamic>>.from(groups)
            ..sort(
              (a, b) => _groupName(a)
                  .toLowerCase()
                  .compareTo(_groupName(b).toLowerCase()),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserId = currentUser.id;
        _students = students;
        _groups = sortedGroups;
        _assignmentsByMaterial
          ..clear()
          ..addAll(assignments);
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

  Future<void> _openAssignmentDialog() async {
    if (_processing || widget.materials.isEmpty) {
      return;
    }

    final _AssignmentDraft? draft = await showModalBottomSheet<_AssignmentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceMidnight,
      builder: (context) => _AssignmentCreateSheet(
        materials: widget.materials,
        students: _students,
        groups: _groups,
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      if (draft.userIds.length + draft.groupIds.length == 1) {
        await _apiService.createTeacherMaterialAssignment(
          materialId: draft.materialId,
          userId: draft.userIds.isEmpty ? null : draft.userIds.first,
          groupId: draft.groupIds.isEmpty ? null : draft.groupIds.first,
        );
      } else {
        await _apiService.createTeacherMaterialAssignmentsBulk(
          materialId: draft.materialId,
          userIds: draft.userIds,
          groupIds: draft.groupIds,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        draft.userIds.length + draft.groupIds.length == 1
            ? 'Materiale assegnato.'
            : 'Materiale assegnato ai destinatari selezionati.',
      );

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

  Future<void> _revoke(Map<String, dynamic> assignment) async {
    if (_processing) {
      return;
    }

    final int? assignmentId = _toInt(assignment['id']);
    if (assignmentId == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.eleganceMidnight,
        title: const Text(
          'Revoca assegnazione',
          style: TextStyle(color: AppColors.pureWhite),
        ),
        content: const Text(
          'Il destinatario non avrà più questa assegnazione attiva. Vuoi continuare?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Revoca',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      await _apiService.revokeTeacherMaterialAssignment(assignmentId);

      if (!mounted) {
        return;
      }

      _showMessage('Assegnazione revocata.');
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
    if (_loading) {
      return _card(
        child: const SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.teacherIndigo,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
              ),
              TextButton(
                onPressed: _load,
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    final int activeCount = _assignmentsByMaterial.values
        .expand((items) => items)
        .where(
          (assignment) =>
              assignment['status']?.toString().toLowerCase() == 'active',
        )
        .length;

    return _card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool narrow = constraints.maxWidth < 420;

                final Widget titleBlock = Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            AppColors.teacherIndigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.assignment_ind_outlined,
                        color: AppColors.materialSky,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assegnazioni',
                            style: TextStyle(
                              color: AppColors.pureWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Assegna i tuoi materiali a singoli studenti o gruppi.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            AppColors.teacherIndigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount attive',
                        style: const TextStyle(
                          color: AppColors.teacherIndigo,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );

                final Widget assignButton = FilledButton.icon(
                  onPressed: _processing || widget.materials.isEmpty
                      ? null
                      : _openAssignmentDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Assegna'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teacherIndigo,
                    foregroundColor: AppColors.pureWhite,
                  ),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      assignButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    assignButton,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          SwitchListTile(
            value: _includeRevoked,
            onChanged: _processing
                ? null
                : (value) async {
                    setState(() {
                      _includeRevoked = value;
                    });
                    await _load();
                  },
            title: const Text(
              'Mostra anche revocate',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
            activeThumbColor: AppColors.teacherIndigo,
            dense: true,
          ),
          const Divider(height: 1, color: Colors.white10),
          if (widget.materials.isEmpty)
            const _AssignmentEmpty(
              text: 'Carica prima un materiale docente.',
            )
          else if (_assignmentsByMaterial.values
              .every((items) => items.isEmpty))
            const _AssignmentEmpty(
              text: 'Nessuna assegnazione presente.',
            )
          else
            for (final Map<String, dynamic> material in widget.materials)
              _buildMaterialAssignments(material),
        ],
      ),
    );
  }

  Widget _buildMaterialAssignments(Map<String, dynamic> material) {
    final int? materialId = _toInt(material['id']);
    if (materialId == null) {
      return const SizedBox.shrink();
    }

    final List<Map<String, dynamic>> assignments =
        _assignmentsByMaterial[materialId] ?? const [];

    if (assignments.isEmpty) {
      return const SizedBox.shrink();
    }

    final String title = _materialTitle(material);

    return ExpansionTile(
      iconColor: AppColors.materialSky,
      collapsedIconColor: Colors.white38,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.pureWhite,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${assignments.length} ${assignments.length == 1 ? 'assegnazione' : 'assegnazioni'}',
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 8,
        ),
      ),
      children: [
        for (final Map<String, dynamic> assignment in assignments)
          _AssignmentRow(
            assignment: assignment,
            targetName: _targetName(assignment),
            processing: _processing,
            onRevoke:
                assignment['status']?.toString().toLowerCase() == 'active'
                    ? () => _revoke(assignment)
                    : null,
          ),
      ],
    );
  }

  String _targetName(Map<String, dynamic> assignment) {
    final int? userId = _toInt(assignment['user_id']);
    if (userId != null) {
      for (final SocialUser user in _students) {
        if (user.id == userId) {
          return user.name.isEmpty ? 'Studente #$userId' : user.name;
        }
      }

      if (userId == _currentUserId) {
        return 'Il tuo account';
      }

      return 'Studente #$userId';
    }

    final int? groupId = _toInt(assignment['group_id']);
    if (groupId != null) {
      for (final Map<String, dynamic> group in _groups) {
        if (_toInt(group['id']) == groupId) {
          return _groupName(group);
        }
      }

      return 'Gruppo #$groupId';
    }

    return 'Destinatario non disponibile';
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.materialSky.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _cleanError(Object error) {
    String message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }
    return message.isEmpty
        ? 'Impossibile gestire le assegnazioni.'
        : message;
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static String _groupName(Map<String, dynamic> group) {
    final String name =
        group['name']?.toString().trim() ??
        group['title']?.toString().trim() ??
        '';
    final int? id = _toInt(group['id']);
    return name.isEmpty ? 'Gruppo${id == null ? '' : ' #$id'}' : name;
  }

  static String _materialTitle(Map<String, dynamic> material) {
    final String title = material['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }

    final String fileName =
        material['original_name']?.toString().trim() ?? '';
    return fileName.isEmpty ? 'Materiale' : fileName;
  }
}

class _AssignmentCreateSheet extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  final List<SocialUser> students;
  final List<Map<String, dynamic>> groups;

  const _AssignmentCreateSheet({
    required this.materials,
    required this.students,
    required this.groups,
  });

  @override
  State<_AssignmentCreateSheet> createState() =>
      _AssignmentCreateSheetState();
}

class _AssignmentCreateSheetState extends State<_AssignmentCreateSheet> {
  int? _materialId;
  final Set<int> _selectedUsers = {};
  final Set<int> _selectedGroups = {};

  @override
  void initState() {
    super.initState();

    if (widget.materials.length == 1) {
      _materialId =
          _TeacherMaterialAssignmentsSectionState._toInt(
        widget.materials.first['id'],
      );
    }
  }

  void _submit() {
    final int? materialId = _materialId;

    if (materialId == null) {
      _message('Seleziona un materiale.');
      return;
    }

    if (_selectedUsers.isEmpty && _selectedGroups.isEmpty) {
      _message('Seleziona almeno uno studente o un gruppo.');
      return;
    }

    Navigator.pop(
      context,
      _AssignmentDraft(
        materialId: materialId,
        userIds: _selectedUsers.toList(),
        groupIds: _selectedGroups.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assegna materiale',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Puoi selezionare uno o più studenti e gruppi.',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _materialId,
                dropdownColor: AppColors.eleganceMidnight,
                decoration: const InputDecoration(
                  labelText: 'Materiale',
                  border: OutlineInputBorder(),
                ),
                items: widget.materials
                    .map((material) {
                      final int? id =
                          _TeacherMaterialAssignmentsSectionState._toInt(
                        material['id'],
                      );

                      if (id == null) {
                        return null;
                      }

                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          _TeacherMaterialAssignmentsSectionState
                              ._materialTitle(material),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _materialId = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    const _TargetHeader(
                      icon: Icons.person_outline_rounded,
                      title: 'Studenti',
                    ),
                    if (widget.students.isEmpty)
                      const _TargetEmpty(
                        text: 'Nessuno studente disponibile.',
                      )
                    else
                      for (final SocialUser user in widget.students)
                        CheckboxListTile(
                          value: _selectedUsers.contains(user.id),
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedUsers.add(user.id);
                              } else {
                                _selectedUsers.remove(user.id);
                              }
                            });
                          },
                          title: Text(
                            user.name.isEmpty ? 'Studente #${user.id}' : user.name,
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontSize: 11,
                            ),
                          ),
                          subtitle: user.course.trim().isEmpty
                              ? null
                              : Text(
                                  user.course,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 8,
                                  ),
                                ),
                          dense: true,
                          activeColor: AppColors.teacherIndigo,
                        ),
                    const SizedBox(height: 12),
                    const _TargetHeader(
                      icon: Icons.groups_outlined,
                      title: 'Gruppi',
                    ),
                    if (widget.groups.isEmpty)
                      const _TargetEmpty(
                        text: 'Nessun gruppo disponibile.',
                      )
                    else
                      for (final Map<String, dynamic> group in widget.groups)
                        _groupTile(group),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(
                    'Assegna a ${_selectedUsers.length + _selectedGroups.length} destinatari',
                  ),
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

  Widget _groupTile(Map<String, dynamic> group) {
    final int? groupId =
        _TeacherMaterialAssignmentsSectionState._toInt(group['id']);

    if (groupId == null) {
      return const SizedBox.shrink();
    }

    return CheckboxListTile(
      value: _selectedGroups.contains(groupId),
      onChanged: (selected) {
        setState(() {
          if (selected == true) {
            _selectedGroups.add(groupId);
          } else {
            _selectedGroups.remove(groupId);
          }
        });
      },
      title: Text(
        _TeacherMaterialAssignmentsSectionState._groupName(group),
        style: const TextStyle(
          color: AppColors.pureWhite,
          fontSize: 11,
        ),
      ),
      dense: true,
      activeColor: AppColors.teacherIndigo,
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final String targetName;
  final bool processing;
  final VoidCallback? onRevoke;

  const _AssignmentRow({
    required this.assignment,
    required this.targetName,
    required this.processing,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final bool group = assignment['group_id'] != null;
    final String status =
        assignment['status']?.toString().toLowerCase() ?? 'active';
    final DateTime? assignedAt = DateTime.tryParse(
      assignment['assigned_at']?.toString() ?? '',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.teacherIndigo.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              group ? Icons.groups_outlined : Icons.person_outline_rounded,
              color: AppColors.teacherIndigo,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetName,
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _AssignmentBadge(
                      label: group ? 'Gruppo' : 'Studente',
                    ),
                    _AssignmentBadge(
                      label: status == 'active' ? 'Attiva' : 'Revocata',
                    ),
                    if (assignedAt != null)
                      _AssignmentBadge(
                        label: _date(assignedAt),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onRevoke != null)
            TextButton.icon(
              onPressed: processing ? null : onRevoke,
              icon: const Icon(
                Icons.block_outlined,
                size: 15,
                color: Colors.redAccent,
              ),
              label: const Text(
                'Revoca',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime value) {
    final DateTime local = value.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _AssignmentBadge extends StatelessWidget {
  final String label;

  const _AssignmentBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 7,
        ),
      ),
    );
  }
}

class _AssignmentEmpty extends StatelessWidget {
  final String text;

  const _AssignmentEmpty({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: Colors.white24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _TargetHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.materialSky,
            size: 17,
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetEmpty extends StatelessWidget {
  final String text;

  const _TargetEmpty({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _AssignmentDraft {
  final int materialId;
  final List<int> userIds;
  final List<int> groupIds;

  const _AssignmentDraft({
    required this.materialId,
    required this.userIds,
    required this.groupIds,
  });
}