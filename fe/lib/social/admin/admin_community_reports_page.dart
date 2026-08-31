import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';
import '../widgets/social_user_profile_page.dart';
import '../social_models.dart';

enum AdminCommunityReportKind { users, groups, contents }

class AdminUserReportsPage extends StatelessWidget {
  const AdminUserReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminCommunityReportsPage(kind: AdminCommunityReportKind.users);
  }
}

class AdminGroupReportsPage extends StatelessWidget {
  const AdminGroupReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminCommunityReportsPage(kind: AdminCommunityReportKind.groups);
  }
}

class AdminGroupContentReportsPage extends StatelessWidget {
  const AdminGroupContentReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AdminCommunityReportsPage(kind: AdminCommunityReportKind.contents);
  }
}

class _AdminCommunityReportsPage extends StatefulWidget {
  final AdminCommunityReportKind kind;

  const _AdminCommunityReportsPage({required this.kind});

  @override
  State<_AdminCommunityReportsPage> createState() =>
      _AdminCommunityReportsPageState();
}

class _AdminCommunityReportsPageState extends State<_AdminCommunityReportsPage> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _reports = [];
  Map<int, SocialUser> _users = {};
  bool _loading = true;
  bool _processing = false;
  String _status = 'pending';
  String? _error;

  String get _title {
    switch (widget.kind) {
      case AdminCommunityReportKind.users:
        return 'Segnalazioni utenti';
      case AdminCommunityReportKind.groups:
        return 'Segnalazioni gruppi';
      case AdminCommunityReportKind.contents:
        return 'Segnalazioni contenuti';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      late final List<Map<String, dynamic>> reports;

      switch (widget.kind) {
        case AdminCommunityReportKind.users:
          reports = await _apiService.getAdminUserReports(status: _status);
          break;
        case AdminCommunityReportKind.groups:
          reports = await _apiService.getAdminGroupReports(status: _status);
          break;
        case AdminCommunityReportKind.contents:
          reports =
              await _apiService.getAdminGroupContentReports(status: _status);
          break;
      }

      Map<int, SocialUser> users = {};
      try {
        final List<SocialUser> values = await _apiService.getSocialUsers();
        users = {for (final SocialUser user in values) user.id: user};
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _reports = reports;
        _users = users;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _changeStatus(String value) async {
    if (_status == value || _processing) return;
    setState(() => _status = value);
    await _load();
  }

  Future<void> _openTarget(Map<String, dynamic> report) async {
    switch (widget.kind) {
      case AdminCommunityReportKind.users:
        await _openUser(report);
      case AdminCommunityReportKind.groups:
        await _openGroup(report);
      case AdminCommunityReportKind.contents:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _ReportedContentDetailPage(report: report),
          ),
        );
    }
  }

  Future<void> _openUser(Map<String, dynamic> report) async {
    final int? targetId = _int(
      report['reported_user_id'] ??
          report['target_user_id'] ??
          report['user_id'],
    );

    if (targetId == null) {
      _message('Profilo segnalato non disponibile.');
      return;
    }

    SocialUser? user = _users[targetId];

    if (user == null) {
      try {
        final List<SocialUser> users = await _apiService.getSocialUsers();
        for (final SocialUser value in users) {
          if (value.id == targetId) {
            user = value;
            break;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (user == null) {
      _message('Il profilo segnalato non è più disponibile.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SocialUserProfilePage(user: user!),
      ),
    );
  }

  Future<void> _openGroup(Map<String, dynamic> report) async {
    final int? groupId = _int(
      report['group_id'] ?? report['reported_group_id'],
    );

    if (groupId == null) {
      _message('Gruppo segnalato non disponibile.');
      return;
    }

    try {
      final Map<String, dynamic> group = await _apiService.getGroup(groupId);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ReportedGroupDetailPage(
            groupId: groupId,
            group: group,
          ),
        ),
      );
    } catch (_) {
      _message('Il gruppo segnalato non è più disponibile.');
    }
  }

  Future<void> _manage(Map<String, dynamic> report) async {
    final int? reportId = _int(report['id']);
    if (reportId == null || _processing) return;

    String nextStatus = _status == 'pending' ? 'under_review' : 'resolved';
    String action = _text(
      report,
      ['moderation_action'],
      fallback: 'none',
    );

    if (!{'none', 'hide', 'remove'}.contains(action)) {
      action = 'none';
    }

    final TextEditingController noteController = TextEditingController(
      text: _text(report, ['moderation_note', 'resolution_note']),
    );

    final bool? accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Gestisci ${_title.toLowerCase()}',
                        style: const TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: nextStatus,
                        dropdownColor: AppColors.eleganceDeepNavy,
                        decoration: const InputDecoration(labelText: 'Stato'),
                        items: const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('In attesa'),
                          ),
                          DropdownMenuItem(
                            value: 'under_review',
                            child: Text('In revisione'),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text('Risolta'),
                          ),
                          DropdownMenuItem(
                            value: 'dismissed',
                            child: Text('Archiviata'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value != null) {
                            setSheetState(() => nextStatus = value);
                          }
                        },
                      ),
                      if (widget.kind ==
                          AdminCommunityReportKind.contents) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: action,
                          dropdownColor: AppColors.eleganceDeepNavy,
                          decoration: const InputDecoration(
                            labelText: 'Azione sul contenuto',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('Mantieni'),
                            ),
                            DropdownMenuItem(
                              value: 'hide',
                              child: Text('Nascondi'),
                            ),
                            DropdownMenuItem(
                              value: 'remove',
                              child: Text('Rimuovi'),
                            ),
                          ],
                          onChanged: (String? value) {
                            if (value != null) {
                              setSheetState(() => action = value);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 2000,
                        style: const TextStyle(color: AppColors.pureWhite),
                        decoration: const InputDecoration(
                          labelText: 'Nota moderazione',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salva'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final String note = noteController.text.trim();
    noteController.dispose();

    if (accepted != true) return;

    setState(() => _processing = true);

    try {
      switch (widget.kind) {
        case AdminCommunityReportKind.users:
          await _apiService.moderateUserReport(
            reportId: reportId,
            status: nextStatus,
            moderationNote: note,
          );
          break;
        case AdminCommunityReportKind.groups:
          await _apiService.moderateGroupReport(
            reportId: reportId,
            status: nextStatus,
            moderationNote: note,
          );
          break;
        case AdminCommunityReportKind.contents:
          await _apiService.moderateGroupContentReport(
            reportId: reportId,
            status: nextStatus,
            moderationAction: action,
            moderationNote: note,
          );
          break;
      }

      if (!mounted) return;

      _message('Segnalazione aggiornata.');
      await _load();
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading || _processing ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              children: [
                _buildStatusBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    const values = [
      ('pending', 'In attesa'),
      ('under_review', 'In revisione'),
      ('resolved', 'Risolte'),
      ('dismissed', 'Archiviate'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          for (final item in values) ...[
            ChoiceChip(
              label: Text(item.$2),
              selected: _status == item.$1,
              onSelected: (_) => _changeStatus(item.$1),
              backgroundColor: AppColors.eleganceMidnight,
              selectedColor: AppColors.skyBlue,
              side: BorderSide(
                color: _status == item.$1
                    ? AppColors.skyBlue
                    : AppColors.skyBlue.withValues(alpha: 0.13),
              ),
              labelStyle: TextStyle(
                color: _status == item.$1
                    ? AppColors.brandNightBlue
                    : AppColors.pureWhite.withValues(alpha: 0.65),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        color: Colors.redAccent,
        message: _error!,
        action: 'Riprova',
        onAction: _load,
      );
    }

    if (_reports.isEmpty) {
      return const _StateMessage(
        icon: Icons.verified_outlined,
        color: Colors.greenAccent,
        message: 'Nessuna segnalazione in questa sezione.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> report = _reports[index];

          return _ReportCard(
            kind: widget.kind,
            report: report,
            users: _users,
            processing: _processing,
            onOpen: () => _openTarget(report),
            onManage: () => _manage(report),
          );
        },
      ),
    );
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();

    if (value.contains('401')) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }

    if (value.contains('403')) {
      return 'Non hai i permessi necessari per questa sezione.';
    }

    if (value.contains('network') ||
        value.contains('socket') ||
        value.contains('connection') ||
        value.contains('timeout') ||
        value.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab.';
    }

    return 'Non è stato possibile caricare le segnalazioni.';
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _ReportCard extends StatelessWidget {
  final AdminCommunityReportKind kind;
  final Map<String, dynamic> report;
  final Map<int, SocialUser> users;
  final bool processing;
  final VoidCallback onOpen;
  final VoidCallback onManage;

  const _ReportCard({
    required this.kind,
    required this.report,
    required this.users,
    required this.processing,
    required this.onOpen,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final String status = _text(report, ['status'], fallback: 'pending');
    final String reason = _reasonLabel(
      _text(report, ['reason', 'category']),
    );
    final String description = _text(
      report,
      ['description', 'details', 'message'],
      fallback: 'Nessun dettaglio aggiuntivo.',
    );
    final String date = _formatDate(
      report['created_at'] ?? report['reported_at'],
    );

    final int? reporterId = _int(
      report['reporter_user_id'] ?? report['created_by_user_id'],
    );
    final String reporterName = users[reporterId]?.name ??
        _text(
          report,
          ['reporter_name', 'reporter_user_name'],
          fallback: reporterId == null ? 'Utente' : 'Utente #$reporterId',
        );

    late final IconData targetIcon;
    late final String title;
    late final String subtitle;
    late final String openLabel;

    switch (kind) {
      case AdminCommunityReportKind.users:
        final int? targetId = _int(
          report['reported_user_id'] ??
              report['target_user_id'] ??
              report['user_id'],
        );
        final SocialUser? user = targetId == null ? null : users[targetId];
        final SocialAcademicPath? path =
            user?.primaryAcademicPath ?? user?.currentAcademicPath;

        targetIcon = Icons.person_outline_rounded;
        title = user?.name ??
            _text(
              report,
              ['reported_user_name', 'target_user_name', 'user_name'],
              fallback: 'Utente #${targetId ?? '?'}',
            );
        subtitle = [
          user == null
              ? _text(report, ['reported_user_role', 'role'])
              : user.isTeacher
                  ? 'Docente'
                  : 'Studente',
          path?.course.trim().isNotEmpty == true
              ? path!.course.trim()
              : user?.course.trim() ?? '',
        ].where((String value) => value.isNotEmpty).join(' · ');
        openLabel = 'Apri profilo';
        break;

      case AdminCommunityReportKind.groups:
        final int? groupId =
            _int(report['group_id'] ?? report['reported_group_id']);
        targetIcon = Icons.groups_2_outlined;
        title = _text(
          report,
          ['group_name', 'reported_group_name', 'target_name'],
          fallback: 'Gruppo #${groupId ?? '?'}',
        );
        subtitle = _text(
          report,
          ['subject_name', 'subject', 'course'],
          fallback: 'Gruppo StudentLab',
        );
        openLabel = 'Apri gruppo';
        break;

      case AdminCommunityReportKind.contents:
        final int? contentId =
            _int(report['content_id'] ?? report['target_id']);
        final String type = _text(
          report,
          ['content_type', 'type'],
          fallback: 'contenuto',
        );
        targetIcon = _contentIcon(type);
        title = _text(
          report,
          ['content_title', 'title', 'news_title', 'material_name'],
          fallback: '${_contentTypeLabel(type)} #${contentId ?? '?'}',
        );
        final int? groupId = _int(report['group_id']);
        subtitle = [
          _contentTypeLabel(type),
          if (groupId != null) 'Gruppo #$groupId',
        ].join(' · ');
        openLabel = 'Apri dettagli';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _statusColor(status).withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: AppColors.brandNightBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(targetIcon, color: AppColors.skyBlue),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ReasonBadge(reason: reason),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: Colors.white38,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kind == AdminCommunityReportKind.groups
                      ? 'Segnalato da $reporterName'
                      : 'Segnalazione di $reporterName',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkElegance.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '“$description”',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusBadge(status: status),
              const Spacer(),
              TextButton.icon(
                onPressed: processing ? null : onOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(openLabel),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: processing ? null : onManage,
                icon: const Icon(Icons.gavel_outlined, size: 16),
                label: const Text('Gestisci'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportedGroupDetailPage extends StatelessWidget {
  final int groupId;
  final Map<String, dynamic> group;

  const _ReportedGroupDetailPage({
    required this.groupId,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final String name =
        _text(group, ['name', 'group_name'], fallback: 'Gruppo #$groupId');
    final String description =
        _text(group, ['description'], fallback: 'Nessuna descrizione.');

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _DetailCard(
                  icon: Icons.groups_2_outlined,
                  title: name,
                  description: description,
                  values: [
                    ('Materia', _text(group, ['subject_name', 'subject'])),
                    ('Ateneo', _text(group, ['university'])),
                    ('Dipartimento', _text(group, ['department'])),
                    ('Corso', _text(group, ['course'])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportedContentDetailPage extends StatelessWidget {
  final Map<String, dynamic> report;

  const _ReportedContentDetailPage({
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final String type =
        _text(report, ['content_type', 'type'], fallback: 'Contenuto');
    final int? contentId = _int(report['content_id'] ?? report['target_id']);
    final int? groupId = _int(report['group_id']);
    final String content = _text(
      report,
      ['content', 'content_text', 'body', 'text'],
      fallback:
          'La risposta della segnalazione non contiene una copia del contenuto.',
    );

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Dettaglio contenuto'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _DetailCard(
                  icon: _contentIcon(type),
                  title: '${_contentTypeLabel(type)} #${contentId ?? '?'}',
                  description: content,
                  values: [
                    if (groupId != null) ('Gruppo', '#$groupId'),
                    ('Motivo', _reasonLabel(_text(report, ['reason']))),
                    (
                      'Segnalante',
                      '#${_int(report['reporter_user_id']) ?? '?'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<(String, String)> values;

  const _DetailCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.skyBlue.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.skyBlue, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          SelectableText(
            description,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          for (final value in values)
            if (value.$2.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        value.$1,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
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

class _ReasonBadge extends StatelessWidget {
  final String reason;

  const _ReasonBadge({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_outlined, color: Colors.orangeAccent, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.icon,
    required this.color,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _text(
  Map<String, dynamic> item,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final String value = item[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _reasonLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'spam':
      return 'Spam';
    case 'harassment':
      return 'Molestie';
    case 'hate':
    case 'hate_speech':
      return 'Discriminazione';
    case 'privacy':
      return 'Privacy';
    case 'illegal':
    case 'illegal_content':
      return 'Contenuto illecito';
    case 'impersonation':
      return 'Impersonificazione';
    case 'misleading':
      return 'Ingannevole';
    case 'copyright':
      return 'Copyright';
    case 'abuse':
      return 'Abuso';
    case 'other':
      return 'Altro';
    default:
      return value.trim().isEmpty ? 'Segnalazione' : value.trim();
  }
}

String _statusLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'pending':
      return 'In attesa';
    case 'under_review':
    case 'reviewing':
      return 'In revisione';
    case 'resolved':
      return 'Risolta';
    case 'dismissed':
    case 'rejected':
      return 'Archiviata';
    default:
      return value;
  }
}

Color _statusColor(String value) {
  switch (value.trim().toLowerCase()) {
    case 'pending':
      return Colors.amber;
    case 'under_review':
    case 'reviewing':
      return AppColors.skyBlue;
    case 'resolved':
      return Colors.greenAccent;
    case 'dismissed':
    case 'rejected':
      return Colors.white38;
    default:
      return Colors.white54;
  }
}

String _formatDate(dynamic value) {
  if (value == null) return '';

  final DateTime? parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return '';

  final DateTime date = parsed.toLocal();

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year} · '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _contentTypeLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'news':
    case 'group_news':
      return 'News gruppo';
    case 'material':
    case 'group_material':
      return 'Materiale';
    case 'message':
      return 'Messaggio';
    default:
      return value.trim().isEmpty ? 'Contenuto' : value.trim();
  }
}

IconData _contentIcon(String value) {
  switch (value.trim().toLowerCase()) {
    case 'news':
    case 'group_news':
      return Icons.newspaper_outlined;
    case 'material':
    case 'group_material':
      return Icons.description_outlined;
    case 'message':
      return Icons.chat_bubble_outline_rounded;
    default:
      return Icons.article_outlined;
  }
}
