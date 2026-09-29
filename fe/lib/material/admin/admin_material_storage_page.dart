import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';
import '../../theme/app_palette.dart';
import '../../widgets/studentlab_ui/studentlab_ui.dart';
import '../../social/admin/admin_material_storage_api_service.dart';
import 'admin_material_publications_page.dart';
import 'admin_material_course_proposals_page.dart';
import 'admin_drive_catalog_page.dart';
import 'admin_studentlab_material_requests_page.dart';
import 'admin_material_upload_page.dart';
import 'admin_teacher_request_dialog.dart';
import 'drive_file_preview.dart';
import 'drive_placement_dialog.dart';

class AdminMaterialStoragePage extends StatefulWidget {
  const AdminMaterialStoragePage({super.key});

  @override
  State<AdminMaterialStoragePage> createState() =>
      _AdminMaterialStoragePageState();
}

class _AdminMaterialStoragePageState extends State<AdminMaterialStoragePage> {
  static const double _maxContentWidth = 1120;
  static const double _wideBreakpoint = 860;
  static const List<String> _sources = <String>[
    'all', 'public', 'teacher', 'group', 'personal_sync', 'shared_user',
  ];

  final AdminMaterialStorageApiService _api = AdminMaterialStorageApiService();
  final ApiService _mainApi = ApiService();
  /// Elementi in attesa per ogni coda; `null` = conteggio non disponibile.
  int? _pendingPublications;
  int? _pendingCourses;
  int? _openRequests;
  bool _loading = true;
  String _source = 'all';
  String _query = '';
  String? _error;
  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _driveStatus = {};
  String? _driveError;
  List<Map<String, dynamic>> _items = [];
  Map<String, int> _sourceCounts = <String, int>{};
  final Set<String> _expanded = <String>{};
  DateTime? _loadedAt;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Map<String, dynamic> overview = {};
    List<Map<String, dynamic>> items = [];
    Map<String, dynamic> driveStatus = {};
    String? error;
    String? driveError;
    try {
      overview = await _api.getOverview();
    } catch (_) { /* Metrics are optional. */ }
    try {
      items = await _api.getItems(source: _source == 'all' ? null : _source);
    } catch (e) { error = 'Inventario non disponibile: $e'; }
    try {
      driveStatus = await _api.getDriveStatus();
    } catch (e) { driveError = 'Stato Drive non disponibile: $e'; }
    // Il backend aggiornato manda già i contatori nel riepilogo; le tre
    // chiamate separate servono solo con un backend non ancora aggiornato.
    final summaryMap = overview['summary'];
    final bool serverCounts = summaryMap is Map && summaryMap.containsKey('pending_publication_requests');
    final (int?, int?, int?) counts = serverCounts ? (null, null, null) : await _loadQueueCounts();
    if (mounted) {
      _pendingPublications = counts.$1;
      _pendingCourses = counts.$2;
      _openRequests = counts.$3;
      setState(() {
        _overview = overview;
        _items = items;
        _driveStatus = driveStatus;
        _driveError = driveError;
        _error = error;
        _loading = false;
        _loadedAt = DateTime.now();
        // Counts are only reliable when the whole inventory was loaded.
        if (_source == 'all' && error == null) _sourceCounts = _countBySource(items);
      });
    }
  }

  /// Conta gli elementi in attesa usando gli endpoint già esistenti delle
  /// tre code, in parallelo. Un errore nasconde solo quel badge.
  Future<(int?, int?, int?)> _loadQueueCounts() async {
    Future<int?> safe(Future<int> Function() load) async {
      try { return await load(); } catch (_) { return null; }
    }
    final results = await Future.wait<int?>(<Future<int?>>[
      safe(() async => (await _mainApi.getAdminMaterialPublications(status: 'pending')).length),
      safe(() async {
        final token = AuthSession.instance.accessToken;
        if (token == null || token.isEmpty) throw StateError('no session');
        final response = await http.get(
          Uri.parse('${_mainApi.baseUrl}/materials/course-proposals/admin'),
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        );
        if (response.statusCode < 200 || response.statusCode >= 300) throw StateError('http');
        final values = jsonDecode(response.body) as List;
        return values.whereType<Map>().where((v) => (v['status']?.toString() ?? 'pending') == 'pending').length;
      }),
      safe(() async => (await _mainApi.getStudentLabMaterialRequests())
          .where((r) => (r['status']?.toString() ?? 'pending') == 'pending').length),
    ]);
    return (results[0], results[1], results[2]);
  }

  Map<String, int> _countBySource(List<Map<String, dynamic>> items) {
    final counts = <String, int>{'all': 0};
    for (final item in items) {
      final source = item['source']?.toString() ?? '';
      if (source == 'publication_request') continue;
      counts[source] = (counts[source] ?? 0) + 1;
      counts['all'] = counts['all']! + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> get _visibleItems => _items.where((item) {
    // Moderation requests have their dedicated queue above; avoid showing
    // the same student proposal twice in the storage inventory.
    if (item['source'] == 'publication_request') return false;
    if (_query.trim().isEmpty) return true;
    // Never search private titles or filenames in the admin view.
    final privateContent = item['private_content'] == true;
    final fields = privateContent
        ? <Object?>[item['owner_ref'], item['source'], item['status']]
        : <Object?>[item['title'], item['original_name'], item['source'],
            item['subject_name'], item['course'], item['status']];
    return fields.any((value) => (value?.toString() ?? '')
        .toLowerCase().contains(_query.trim().toLowerCase()));
  }).toList();

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  /// Optional counters for the work queues. The badge is hidden when the
  /// backend does not send the value yet.
  int? _optionalInt(Map<String, dynamic> summary, String key) =>
      summary.containsKey(key) ? _int(summary[key]) : null;

  String _bytes(dynamic value) {
    final int size = _int(value);
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _open(Widget page, {bool reload = true}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (reload && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final summary = _overview['summary'] is Map
        ? Map<String, dynamic>.from(_overview['summary'])
        : <String, dynamic>{};
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.brandNightBlue,
        foregroundColor: p.pureWhite,
        titleSpacing: 4,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('ADMIN / CONTENUTI',
                style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56))),
            const Text('Materiali e Storage'),
          ],
        ),
        actions: <Widget>[
          if (_loadedAt != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text('Aggiornato alle ${_time(_loadedAt!)}',
                    style: SlText.mono(p, size: 12, color: p.pureWhite.withValues(alpha: 0.56))),
              ),
            ),
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading && _loadedAt == null
            ? Center(child: CircularProgressIndicator(color: p.skyBlue))
            : RefreshIndicator(
                onRefresh: _load,
                child: LayoutBuilder(builder: (context, constraints) {
                  final bool wide = constraints.maxWidth >= _wideBreakpoint;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 20, wide ? 24 : 16, 40),
                        children: <Widget>[
                          _buildHeader(),
                          const SizedBox(height: 22),
                          _buildMetrics(summary, wide),
                          const SizedBox(height: 16),
                          _buildQuickActions(wide),
                          const SizedBox(height: 28),
                          _buildQueues(summary, wide),
                          const SizedBox(height: 22),
                          _buildDrive(wide),
                          const SizedBox(height: 28),
                          _buildInventory(wide),
                        ],
                      ),
                    ),
                  );
                }),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool driveOk = _driveError == null && _driveStatus['configured'] == true;
    return SlPageHeader(
      icon: Icons.storage_rounded,
      title: 'Controllo materiali',
      subtitle: 'Spazio occupato e file pubblicati. Le richieste degli studenti hanno una coda separata.',
      badges: <Widget>[
        const SlStatusBadge(label: 'Blob storage', tone: SlTone.cyan, icon: Icons.dns_outlined),
        SlStatusBadge(
          label: driveOk ? 'Drive connesso' : 'Drive non configurato',
          tone: driveOk ? SlTone.success : SlTone.warning,
          icon: driveOk ? Icons.check_rounded : Icons.cloud_off_outlined,
        ),
        const SlStatusBadge(
          label: 'Contenuti privati oscurati',
          tone: SlTone.warning,
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }

  Widget _grid({required List<Widget> children, required int columns, double spacing = 14}) {
    return LayoutBuilder(builder: (context, constraints) {
      final double width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: <Widget>[for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }

  Widget _buildMetrics(Map<String, dynamic> summary, bool wide) {
    final int reclaimable = _int(summary['reclaimable_bytes']);
    final int orphans = _int(summary['orphan_blob_count']);
    return _grid(columns: wide ? 4 : 2, spacing: wide ? 14 : 10, children: <Widget>[
      SlMetricCard(
        label: 'Blob',
        value: '${_int(summary['blob_count'])}',
        caption: 'File fisici archiviati',
        icon: Icons.dns_outlined,
        tone: SlTone.cyan,
      ),
      SlMetricCard(
        label: 'Storage',
        value: _bytes(summary['total_bytes']),
        caption: 'Occupati su Blob',
        icon: Icons.sd_storage_outlined,
        tone: SlTone.blue,
      ),
      SlMetricCard(
        label: 'Recuperabile',
        value: _bytes(reclaimable),
        caption: reclaimable == 0 ? 'Nessuna pulizia necessaria' : 'Spazio liberabile con la pulizia',
        captionTone: reclaimable == 0 ? SlTone.success : SlTone.warning,
        icon: Icons.restore_rounded,
        tone: SlTone.success,
      ),
      SlMetricCard(
        label: 'Orfani',
        value: '$orphans',
        caption: orphans == 0 ? 'Blob senza riferimenti' : 'Blob senza riferimenti da verificare',
        captionTone: orphans == 0 ? null : SlTone.warning,
        icon: Icons.link_off_rounded,
        tone: SlTone.warning,
      ),
    ]);
  }

  String? _queueBadge(int? count, String singular, String plural) {
    if (count == null) return null;
    if (count == 0) return 'Nessuna';
    return '$count ${count == 1 ? singular : plural}';
  }

  /// Azioni rapide sotto le metriche (canvas: Punti di ingresso).
  Widget _buildQuickActions(bool wide) {
    Widget action(IconData icon, SlTone tone, String title, String description, VoidCallback onTap) {
      final p = context.palette;
      return Material(
        color: p.eleganceMidnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tone.resolve(p).withValues(alpha: 0.18)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              SlIconTile(icon: icon, tone: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(description, style: SlText.muted(p)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: p.pureWhite.withValues(alpha: 0.4)),
            ]),
          ),
        ),
      );
    }

    return _grid(columns: wide ? 3 : 1, children: <Widget>[
      action(Icons.upload_file_rounded, SlTone.info, 'Carica materiale', 'Nelle Dispense o solo su Drive',
          () => _open(const AdminMaterialUploadPage())),
      action(Icons.school_outlined, SlTone.blue, 'Richiedi a un docente', 'Per una materia, con scadenza',
          () async {
        final sent = await showAdminTeacherRequestDialog(context);
        if (sent && mounted) await _load();
      }),
      action(Icons.account_tree_outlined, SlTone.cyan, 'Catalogo Drive', 'Struttura per gli studenti',
          () => _open(const AdminDriveCatalogPage())),
    ]);
  }

  Widget _buildQueues(Map<String, dynamic> summary, bool wide) {
    final int? proposals = _optionalInt(summary, 'pending_publication_requests') ?? _pendingPublications;
    final int? courses = _optionalInt(summary, 'pending_course_proposals') ?? _pendingCourses;
    final int? requests = _optionalInt(summary, 'open_studentlab_requests') ?? _openRequests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SlSectionHeader(
          title: 'Code di lavoro',
          subtitle: 'Tutto ciò che aspetta una decisione di un amministratore.',
        ),
        const SizedBox(height: 12),
        _grid(columns: wide ? 3 : 1, children: <Widget>[
          SlNavCard(
            icon: Icons.fact_check_outlined,
            title: 'Esamina proposte',
            description: 'Materiali proposti dagli studenti da approvare o respingere prima della pubblicazione.',
            badge: _queueBadge(proposals, 'in attesa', 'in attesa'),
            badgeTone: (proposals ?? 0) > 0 ? SlTone.warning : SlTone.neutral,
            onTap: () => _open(const AdminMaterialPublicationsPage()),
          ),
          SlNavCard(
            icon: Icons.school_outlined,
            title: 'Approva corsi aggiuntivi',
            description: 'Nuovi corsi o materie suggeriti per classificare i materiali.',
            tone: SlTone.violet,
            badge: _queueBadge(courses, 'da valutare', 'da valutare'),
            badgeTone: (courses ?? 0) > 0 ? SlTone.warning : SlTone.neutral,
            onTap: () => _open(const AdminMaterialCourseProposalsPage()),
          ),
          SlNavCard(
            icon: Icons.mark_email_unread_outlined,
            title: 'Richieste a StudentLab',
            description: 'Materiale che gli studenti chiedono alla redazione di reperire o produrre.',
            tone: SlTone.cyan,
            badge: _queueBadge(requests, 'nuova', 'nuove'),
            badgeTone: (requests ?? 0) > 0 ? SlTone.warning : SlTone.neutral,
            onTap: () => _open(const AdminStudentLabMaterialRequestsPage(), reload: false),
          ),
        ]),
      ],
    );
  }

  Widget _buildDrive(bool wide) {
    final p = context.palette;
    final bool configured = _driveStatus['configured'] == true;
    final int used = _int(_driveStatus['used_bytes']);
    final int? limit = _driveStatus['limit_bytes'] == null ? null : _int(_driveStatus['limit_bytes']);
    final Widget info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
          Text('Google Drive',
              style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
          Text('Risorse esistenti e copie dei materiali pubblicati', style: SlText.muted(p)),
        ]),
        const SizedBox(height: 10),
        if (_driveError != null)
          Text(_driveError!, style: SlText.muted(p).copyWith(color: p.adminCoral))
        else if (!configured)
          Text('La copia su Drive richiede permessi di scrittura. Puoi comunque provare a esplorare i file esistenti.',
              style: SlText.muted(p))
        else
          Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
            Text('${_driveStatus['account'] ?? '—'}', style: SlText.mono(p, color: p.diamondDust)),
            if (limit != null && limit > 0)
              SizedBox(width: 220, child: SlUsageBar(fraction: used / limit)),
            Text('${_bytes(used)} / ${limit == null ? 'limite non disponibile' : _bytes(limit)}',
                style: SlText.mono(p)),
          ]),
      ],
    );
    final Widget action = SlActionButton(
      icon: Icons.folder_open_outlined,
      label: 'Esplora e classifica',
      primary: true,
      onPressed: () => _open(const AdminDriveCatalogPage()),
    );
    return SlPanel(
      padding: const EdgeInsets.all(20),
      child: wide
          ? Row(children: <Widget>[
              const SlIconTile(icon: Icons.cloud_outlined, size: 48),
              const SizedBox(width: 18),
              Expanded(child: info),
              const SizedBox(width: 18),
              action,
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                const SlIconTile(icon: Icons.cloud_outlined, size: 40),
                const SizedBox(width: 12),
                Expanded(child: info),
              ]),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: action),
            ]),
    );
  }

  Widget _buildInventory(bool wide) {
    final p = context.palette;
    final items = _visibleItems;
    final int totalBytes = items.fold<int>(0, (sum, item) => sum + _int(item['blob_size'] ?? item['size']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SlSectionHeader(
          title: 'Inventario materiali',
          subtitle: 'I contenuti privati mostrano solo metadati e stato di conservazione.',
          trailing: Text('${items.length} elementi · ${_bytes(totalBytes)}', style: SlText.mono(p)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: p.eleganceMidnight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.skyBlue.withValues(alpha: 0.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(14),
                child: wide
                    ? Row(children: <Widget>[
                        Flexible(flex: 3, child: _filterBar()),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _searchField()),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                        _filterBar(),
                        const SizedBox(height: 12),
                        _searchField(),
                      ]),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: SlErrorCard(
                    title: 'Inventario non disponibile',
                    message: 'Metriche e Drive restano consultabili.',
                    onRetry: _load,
                  ),
                )
              else if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: SlEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nessun materiale per questi filtri',
                    message: _source == 'all' && _query.isEmpty
                        ? 'Non ci sono ancora materiali archiviati.'
                        : 'Prova un’altra origine o cerca per materia, corso o stato.',
                    actions: <Widget>[
                      if (_source != 'all' || _query.isNotEmpty)
                        SlActionButton(
                          icon: Icons.filter_alt_off_outlined,
                          label: 'Mostra tutti',
                          primary: true,
                          onPressed: () async {
                            _searchController.clear();
                            setState(() { _source = 'all'; _query = ''; });
                            await _load();
                          },
                        ),
                      SlActionButton(
                        icon: Icons.folder_open_outlined,
                        label: 'Esplora Drive',
                        onPressed: () => _open(const AdminDriveCatalogPage()),
                      ),
                    ],
                  ),
                )
              else ...<Widget>[
                if (wide) _tableHeader(),
                for (final item in items) _row(item, wide),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterBar() {
    return SlFilterBar<String>(
      selected: _source,
      options: <SlFilterOption<String>>[
        for (final source in _sources)
          SlFilterOption<String>(
            value: source,
            label: _label(source),
            count: _sourceCounts.isEmpty ? null : (_sourceCounts[source] ?? 0),
          ),
      ],
      onSelected: (source) async {
        if (source == _source) return;
        setState(() { _source = source; _expanded.clear(); });
        await _load();
      },
    );
  }

  Widget _searchField() {
    final p = context.palette;
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      style: TextStyle(color: p.pureWhite, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Cerca per titolo, file, materia, corso o stato',
        fillColor: p.darkElegance,
      ),
    );
  }

  static const List<int> _flex = <int>[24, 10, 13, 8, 9];

  Widget _tableHeader() {
    final p = context.palette;
    final style = SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: p.pureWhite.withValues(alpha: 0.08))),
      ),
      child: Row(children: <Widget>[
        Expanded(flex: _flex[0], child: Text('MATERIALE', style: style)),
        Expanded(flex: _flex[1], child: Text('ORIGINE', style: style)),
        Expanded(flex: _flex[2], child: Text('STATO', style: style)),
        Expanded(flex: _flex[3], child: Text('DIMENSIONE', style: style)),
        Expanded(flex: _flex[4], child: Text('CARICATO', style: style)),
        const SizedBox(width: 44),
      ]),
    );
  }

  String _label(String source) {
    switch (source) {
      case 'publication_request':
        return 'Proposte';
      case 'public':
        return 'StudentLab';
      case 'teacher':
        return 'Docenti';
      case 'group':
        return 'Gruppi';
      case 'personal_sync':
        return 'Privati';
      case 'shared_user':
        return 'Condivisioni';
      default:
        return 'Tutti';
    }
  }

  Future<void> _changeVisibility(Map<String, dynamic> item, String state) async {
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;
    try {
      await _api.setPublicVisibility(materialId: id, state: state);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Non è stato possibile modificare la visibilità.')));
    }
  }

  Future<void> _copyToDrive(Map<String, dynamic> item) async {
    final materialId = int.tryParse(item['id']?.toString() ?? '');
    if (materialId == null) return;
    try {
      final placement = await showDialog<DrivePlacement>(context: context,
        builder: (_) => DrivePlacementDialog(
          inspect: (path) => _api.previewPublicDrive(materialId, path: path),
          previewProposed: () async {
            if ((int.tryParse(item['size']?.toString() ?? '') ?? 0) > 20 * 1024 * 1024) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Anteprima disponibile per file fino a 20 MB.')));
              return;
            }
            await showDriveFilePreview(context,
              load: () => _api.downloadPublicMaterialPreview(materialId),
              name: item['original_name']?.toString() ?? 'Materiale',
              mimeType: item['mime_type']?.toString() ?? 'application/octet-stream');
          },
          previewExisting: (driveId, fileName, mimeType) =>
              showDriveFilePreview(context,
                load: () => _api.downloadDriveFilePreview(driveId),
                name: fileName, mimeType: mimeType)));
      if (placement == null || !mounted) return;
      await _api.copyPublicToDrive(materialId, path: placement.path,
        allowDuplicate: placement.allowDuplicate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copia Drive verificata. Il file Blob rimane disponibile.')));
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copia Drive non completata. Controlla l’accesso e riprova.')));
    }
  }

  Future<void> _deleteDriveCopy(Map<String, dynamic> item) async {
    final materialId = int.tryParse(item['id']?.toString() ?? '');
    if (materialId == null) return;
    final answer = TextEditingController();
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text('Elimina solo la copia Drive',
          style: TextStyle(color: AppColors.pureWhite)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Il file Blob e i file locali degli studenti non saranno eliminati. Scrivi ELIMINA per confermare.',
            style: TextStyle(color: AppColors.white70)),
          TextField(controller: answer, decoration: const InputDecoration(
            labelText: 'Conferma')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Elimina copia')),
        ]));
    final valid = answer.text.trim() == 'ELIMINA';
    answer.dispose();
    if (confirmed != true || !valid || !mounted) return;
    try {
      await _api.deletePublicDriveCopy(materialId);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Non è stato possibile eliminare la copia Drive.')));
    }
  }

  Future<void> _changeAudience(Map<String, dynamic> item) async {
    final materialId = int.tryParse(item['id']?.toString() ?? '');
    if (materialId == null) return;
    final recipient = TextEditingController(text: item['audience_id']?.toString() ?? '');
    String audience = item['audience_type']?.toString() ?? 'public';
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text('Destinatari del materiale',
          style: TextStyle(color: AppColors.pureWhite)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: audience,
            dropdownColor: AppColors.eleganceDeepNavy,
            decoration: const InputDecoration(labelText: 'Visibile a'),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Tutti')),
              DropdownMenuItem(value: 'course', child: Text('Studenti del corso')),
              DropdownMenuItem(value: 'subject', child: Text('Studenti della materia')),
              DropdownMenuItem(value: 'group', child: Text('Gruppo specifico')),
              DropdownMenuItem(value: 'user', child: Text('Studente specifico')),
            ], onChanged: (v) { if (v != null) update(() => audience = v); }),
          if (audience == 'group' || audience == 'user')
            TextField(controller: recipient, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: audience == 'group'
                ? 'ID del gruppo' : 'ID dello studente')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salva destinatari')),
        ])));
    final id = int.tryParse(recipient.text.trim());
    recipient.dispose();
    if (confirmed != true || !mounted) return;
    if ((audience == 'group' || audience == 'user') && id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Indica un ID valido per il destinatario.')));
      return;
    }
    try {
      await _api.setPublicAudience(materialId: materialId,
        audienceType: audience, audienceId: id);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Destinatario non valido per questo materiale.')));
    }
  }

  Future<void> _placeFile(Map<String, dynamic> item) async {
    final materialId = int.tryParse(item['id']?.toString() ?? '');
    if (materialId == null) return;
    final subjectId = TextEditingController(text: item['subject_id']?.toString() ?? '');
    final rawPath = item['path_segments'];
    final folder = TextEditingController(text: rawPath is List ? rawPath.join(' / ') : '');
    final bool? confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text('Classifica materiale',
          style: TextStyle(color: AppColors.pureWhite)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Modifica la posizione nel catalogo. Il file fisico non viene spostato.',
            style: TextStyle(color: AppColors.white70)),
          TextField(controller: subjectId, keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.pureWhite),
            decoration: const InputDecoration(labelText: 'ID materia')),
          TextField(controller: folder, style: TextStyle(color: AppColors.pureWhite),
            decoration: const InputDecoration(labelText: 'Cartelle (facoltative)',
              helperText: 'Esempio: Livello trasporto / TCP')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salva percorso')),
        ],
      ));
    final targetId = int.tryParse(subjectId.text.trim());
    final segments = folder.text.split('/').map((v) => v.trim())
        .where((v) => v.isNotEmpty).toList();
    subjectId.dispose(); folder.dispose();
    if (confirmed != true || targetId == null || !mounted) return;
    try {
      await _api.placePublicFile(materialId: materialId,
        subjectId: targetId, pathSegments: segments);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Non è stato possibile aggiornare il percorso.')));
    }
  }

  Future<void> _moveFolder(Map<String, dynamic> item) async {
    final subjectId = int.tryParse(item['subject_id']?.toString() ?? '');
    final rawPath = item['path_segments'];
    if (subjectId == null || rawPath is! List || rawPath.isEmpty) return;
    final sourceFolder = TextEditingController(
      text: rawPath.map((part) => part.toString()).join(' / '));
    final destinationSubject = TextEditingController(text: '$subjectId');
    final destinationFolder = TextEditingController();
    final bool? confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text('Sposta intera cartella',
          style: TextStyle(color: AppColors.pureWhite)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tutti i file e le sottocartelle seguiranno la cartella.',
            style: TextStyle(color: AppColors.white70)),
          TextField(controller: sourceFolder,
            style: TextStyle(color: AppColors.pureWhite),
            decoration: const InputDecoration(labelText: 'Cartella da spostare',
              helperText: 'Puoi scegliere anche una cartella superiore')),
          TextField(controller: destinationSubject,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.pureWhite),
            decoration: const InputDecoration(labelText: 'ID materia di destinazione')),
          TextField(controller: destinationFolder,
            style: TextStyle(color: AppColors.pureWhite),
            decoration: const InputDecoration(
              labelText: 'Cartella di destinazione (facoltativa)',
              helperText: 'Esempio: Modulo 1 / Dispense')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sposta')),
        ],
      ));
    final targetId = int.tryParse(destinationSubject.text.trim());
    final sourcePath = sourceFolder.text.split('/')
        .map((segment) => segment.trim()).where((segment) => segment.isNotEmpty).toList();
    final targetPath = destinationFolder.text.split('/')
        .map((segment) => segment.trim()).where((segment) => segment.isNotEmpty).toList();
    destinationSubject.dispose();
    destinationFolder.dispose();
    sourceFolder.dispose();
    if (confirmed != true || targetId == null || sourcePath.isEmpty || !mounted) return;
    try {
      final result = await _api.movePublicFolder(
        sourceSubjectId: subjectId, sourcePath: sourcePath,
        destinationSubjectId: targetId, destinationPath: targetPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Spostati ${result['moved_files'] ?? 0} file.')));
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossibile spostare la cartella. Controlla materia e percorso.')));
    }
  }

  // ---------------------------------------------------------------------------
  // Inventario: righe
  // ---------------------------------------------------------------------------

  String _key(Map<String, dynamic> item) => '${item['source']}:${item['id']}';

  (String, SlTone) _statusBadge(String? status) {
    switch (status) {
      case 'visible':
      case 'active':
        return ('Visibile', SlTone.success);
      case 'in_review':
      case 'pending':
        return ('In revisione', SlTone.warning);
      case 'hidden':
        return ('Nascosto', SlTone.neutral);
      case 'archived':
        return ('Archiviato', SlTone.neutral);
      case 'removed':
        return ('Rimosso', SlTone.danger);
      default:
        return (status ?? '—', SlTone.neutral);
    }
  }

  SlTone _sourceTone(String source, bool privateContent) {
    if (privateContent) return SlTone.private;
    switch (source) {
      case 'teacher':
        return SlTone.violet;
      case 'group':
        return SlTone.cyan;
      default:
        return SlTone.info;
    }
  }

  String _audienceLabel(dynamic value) {
    switch (value?.toString()) {
      case 'course':
        return 'Studenti del corso';
      case 'subject':
        return 'Studenti della materia';
      case 'group':
        return 'Gruppo specifico';
      case 'user':
        return 'Studente specifico';
      case 'public':
        return 'Tutti';
      default:
        return '—';
    }
  }

  Widget _row(Map<String, dynamic> item, bool wide) {
    final p = context.palette;
    final privateContent = item['private_content'] == true;
    final source = item['source']?.toString() ?? '';
    final title = privateContent
        ? (source == 'shared_user' ? 'Condivisione privata' : 'Materiale personale')
        : (item['title']?.toString() ?? item['original_name']?.toString() ?? 'Materiale');
    final subtitle = privateContent
        ? 'Titolo e nome file oscurati'
        : (item['original_name']?.toString() ?? '');
    final bool removed = item['status'] == 'removed' || item['status'] == 'archived';
    final String key = _key(item);
    final bool expanded = _expanded.contains(key);
    final (String statusLabel, SlTone statusTone) = _statusBadge(item['status']?.toString());
    final badges = <Widget>[
      if (privateContent)
        const SlStatusBadge(label: 'Solo metadati', tone: SlTone.private)
      else
        SlStatusBadge(label: statusLabel, tone: statusTone),
      if (item['drive_copied'] == true) const SlStatusBadge(label: 'Drive', tone: SlTone.cyan),
    ];
    final Widget fileIcon = SlIconTile(
      icon: privateContent ? Icons.lock_outline_rounded : Icons.description_outlined,
      tone: removed ? SlTone.neutral : _sourceTone(source, privateContent),
      size: 38,
    );
    final Widget toggle = IconButton(
      tooltip: expanded ? 'Comprimi dettagli' : 'Espandi dettagli',
      onPressed: () => setState(() => expanded ? _expanded.remove(key) : _expanded.add(key)),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: expanded ? p.skyBlue.withValues(alpha: 0.10) : Colors.transparent,
        foregroundColor: expanded ? p.skyBlue : p.pureWhite.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(
              color: expanded ? p.skyBlue.withValues(alpha: 0.30) : p.pureWhite.withValues(alpha: 0.10)),
        ),
      ),
      icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
    );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: removed ? p.pureWhite.withValues(alpha: 0.80) : p.pureWhite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
        if (subtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: privateContent ? SlText.muted(p) : SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56))),
        ],
      ],
    );

    final Widget summaryRow = wide
        ? Row(children: <Widget>[
            Expanded(
              flex: _flex[0],
              child: Row(children: <Widget>[fileIcon, const SizedBox(width: 12), Expanded(child: titleBlock)]),
            ),
            Expanded(flex: _flex[1], child: Text(_label(source), style: SlText.body(p))),
            Expanded(flex: _flex[2], child: Wrap(spacing: 6, runSpacing: 6, children: badges)),
            Expanded(
                flex: _flex[3],
                child: Text(_bytes(item['blob_size'] ?? item['size']), style: SlText.mono(p, size: 13, color: p.pureWhite))),
            Expanded(
                flex: _flex[4],
                child: Text(_date(item['created_at'] ?? item['updated_at']), style: SlText.mono(p, size: 13))),
            toggle,
          ])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            fileIcon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                titleBlock,
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: badges),
                const SizedBox(height: 6),
                Text('${_label(source)} · ${_bytes(item['blob_size'] ?? item['size'])} · ${_date(item['created_at'] ?? item['updated_at'])}',
                    style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.60))),
              ]),
            ),
            toggle,
          ]);

    return Container(
      decoration: BoxDecoration(
        color: expanded ? p.eleganceDeepNavy : Colors.transparent,
        border: Border(bottom: BorderSide(color: p.pureWhite.withValues(alpha: 0.08))),
      ),
      padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          summaryRow,
          if (expanded) ...<Widget>[
            const SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.only(left: wide ? 50 : 0),
              child: _details(item, privateContent, source, wide),
            ),
          ],
        ],
      ),
    );
  }

  Widget _details(Map<String, dynamic> item, bool privateContent, String source, bool wide) {
    final p = context.palette;
    if (privateContent) {
      return Text('Contenuto privato: solo metadati e stato di conservazione.', style: SlText.muted(p));
    }
    final path = item['path_segments'] is List ? (item['path_segments'] as List).join(' / ') : '';
    final bool editable = source == 'public' && item['status'] != 'removed';
    final bool driveCopied = item['drive_copied'] == true;
    final cells = <(String, String, SlTone?)>[
      ('Corso · materia', '${item['course'] ?? '—'} · ${item['subject_name'] ?? '—'}', null),
      ('Cartella', path.isEmpty ? '—' : path, null),
      ('Destinatari', _audienceLabel(item['audience_type']), null),
      ('Copia Drive', driveCopied ? 'Verificata · Blob conservato' : 'Non presente', driveCopied ? SlTone.success : null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _grid(columns: wide ? 4 : 1, spacing: 10, children: <Widget>[
          for (final (label, value, tone) in cells)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.eleganceMidnight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.pureWhite.withValues(alpha: 0.07)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(label.toUpperCase(), style: SlText.mono(p, size: 10, color: p.pureWhite.withValues(alpha: 0.56))),
                const SizedBox(height: 4),
                Text(value, style: SlText.body(p).copyWith(color: tone?.resolve(p))),
              ]),
            ),
        ]),
        if (editable) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
            PopupMenuButton<String>(
              tooltip: 'Visibilità',
              color: p.eleganceDeepNavy,
              onSelected: (value) => _changeVisibility(item, value),
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'visible', child: Text('Visibile')),
                PopupMenuItem(value: 'hidden', child: Text('Nascosto')),
                PopupMenuItem(value: 'in_review', child: Text('In revisione')),
                PopupMenuItem(value: 'archived', child: Text('Archiviato')),
              ],
              child: IgnorePointer(
                child: SlActionButton(
                  icon: Icons.visibility_outlined,
                  label: 'Visibilità: ${_statusBadge(item['status']?.toString()).$1}',
                  primary: true,
                  onPressed: () {},
                ),
              ),
            ),
            SlActionButton(icon: Icons.groups_outlined, label: 'Destinatari', onPressed: () => _changeAudience(item)),
            SlActionButton(icon: Icons.edit_location_alt_outlined, label: 'Percorso', onPressed: () => _placeFile(item)),
            if (item['path_segments'] is List && (item['path_segments'] as List).isNotEmpty)
              SlActionButton(icon: Icons.drive_file_move_outline, label: 'Sposta cartella', onPressed: () => _moveFolder(item)),
            if (!driveCopied)
              SlActionButton(
                icon: Icons.add_to_drive_outlined,
                label: 'Copia su Drive',
                onPressed: _driveStatus['configured'] == true ? () => _copyToDrive(item) : null,
              )
            else
              Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(Icons.check_rounded, size: 16, color: p.adminGreen),
                const SizedBox(width: 6),
                Text('Già copiato su Drive', style: SlText.muted(p)),
              ]),
          ]),
        ],
        if (source == 'public' && item['status'] == 'removed' && driveCopied) ...<Widget>[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SlActionButton(
              icon: Icons.delete_outline,
              label: 'Rimuovi copia Drive',
              onPressed: () => _deleteDriveCopy(item),
            ),
          ),
        ],
      ],
    );
  }
}
