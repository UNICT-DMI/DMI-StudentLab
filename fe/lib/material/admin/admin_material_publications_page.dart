import 'package:flutter/material.dart';
import 'package:fe/theme/nightTheme.dart';

import '../../services/api_service.dart';
import '../../social/admin/admin_material_storage_api_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/studentlab_ui/studentlab_ui.dart';
import 'drive_file_preview.dart';
import 'drive_placement_dialog.dart';

/// Coda "Esamina proposte": elenco a sinistra, dettaglio a destra (desktop),
/// elenco + pagina di dettaglio (mobile).
///
/// Il pannello duplicato usa i campi reali del backend:
/// `duplicate_status` (none | suspected | confirmed | not_duplicate),
/// `comparison_status`, `request_type` e `possible_duplicate_material_id`.
class AdminMaterialPublicationsPage extends StatefulWidget {
  const AdminMaterialPublicationsPage({super.key});

  @override
  State<AdminMaterialPublicationsPage> createState() =>
      _AdminMaterialPublicationsPageState();
}

/// Decisione scelta dall'admin nel pannello di dettaglio.
enum _Decision { publishNew, newVersion, separate, alreadyAvailable }

class _AdminMaterialPublicationsPageState
    extends State<AdminMaterialPublicationsPage> {
  static const double _wideBreakpoint = 1000;

  final ApiService _api = ApiService();
  final AdminMaterialStorageApiService _storage = AdminMaterialStorageApiService();
  final Set<int> _processing = <int>{};
  final Set<int> _checkingDuplicates = <int>{};
  final Set<int> _duplicateCheckFailed = <int>{};
  final Map<int, Future<Map<String, dynamic>>> _duplicates = {};
  final TextEditingController _searchController = TextEditingController();
  String _status = 'pending';
  String _query = '';
  String? _error;
  bool _loading = true;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  int? _selectedId;

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

  int? _id(Map<String, dynamic> item) => int.tryParse(item['id']?.toString() ?? '');

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _api.getAdminMaterialPublications(
        status: _status == 'all' ? null : _status,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _duplicates.clear();
        if (_selectedId == null || !items.any((i) => _id(i) == _selectedId)) {
          _selectedId = items.isEmpty ? null : _id(items.first);
        }
      });
      if (_selectedId != null && _status == 'pending') {
        await _recheckDuplicate(_selectedId!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Impossibile caricare le proposte.'; });
    }
  }

  void _message(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(MaterialBanner(
      content: Text(message), leading: const Icon(Icons.info_outline),
      actions: [TextButton(onPressed: () => messenger.hideCurrentMaterialBanner(),
        child: const Text('Chiudi'))]));
  }

  List<Map<String, dynamic>> get _visibleItems => _items.where((item) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return <Object?>[item['title'], item['original_name'], item['subject_name'],
        item['status'], _proposerName(item)]
      .any((value) => (value?.toString() ?? '').toLowerCase().contains(query));
  }).toList();

  // ---------------------------------------------------------------------------
  // Dati derivati
  // ---------------------------------------------------------------------------

  String _duplicateStatus(Map<String, dynamic> item) =>
      item['duplicate_status']?.toString().toLowerCase() ?? 'none';

  String _requestType(Map<String, dynamic> item) =>
      item['request_type']?.toString().toLowerCase() ?? 'new_material';

  bool _hasDuplicatePanel(Map<String, dynamic> item) {
    final dup = _duplicateStatus(item);
    return dup == 'suspected' || dup == 'confirmed' || _requestType(item) == 'update_candidate' ||
        item['possible_duplicate_material_id'] != null;
  }

  String? _proposerName(Map<String, dynamic> item) {
    for (final key in const ['requester_name', 'user_name', 'student_name', 'author_name', 'proposer_name']) {
      final value = item[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  List<_Decision> _decisions(Map<String, dynamic> item) {
    final dup = _duplicateStatus(item);
    if (dup == 'confirmed') return const <_Decision>[_Decision.alreadyAvailable];
    if (_hasDuplicatePanel(item)) {
      return const <_Decision>[_Decision.newVersion, _Decision.separate, _Decision.alreadyAvailable];
    }
    return const <_Decision>[_Decision.publishNew];
  }

  _Decision _defaultDecision(Map<String, dynamic> item) {
    final options = _decisions(item);
    if (_requestType(item) == 'update_candidate' && options.contains(_Decision.newVersion)) {
      return _Decision.newVersion;
    }
    return options.first;
  }

  String _bytes(dynamic value) {
    final int size = int.tryParse(value?.toString() ?? '') ?? 0;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _relative(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min fa';
    if (diff.inHours < 24) return '${diff.inHours} h fa';
    if (diff.inDays == 1) return 'ieri';
    if (diff.inDays < 7) return '${diff.inDays} gg fa';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _shortHash(dynamic value) {
    final hash = value?.toString() ?? '';
    if (hash.length < 12) return hash;
    return '${hash.substring(0, 4)}…${hash.substring(hash.length - 4)}';
  }

  Future<Map<String, dynamic>> _duplicateFor(int id) =>
      _duplicates.putIfAbsent(id, () => _api.getAdminPossibleDuplicateMaterial(id));

  Future<void> _recheckDuplicate(int id) async {
    if (_checkingDuplicates.contains(id)) return;
    setState(() { _checkingDuplicates.add(id); _duplicateCheckFailed.remove(id); });
    try {
      final checked = await _api.recheckAdminPublicationDuplicate(id);
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((item) => _id(item) == id);
        if (index >= 0) _items[index] = checked;
        _duplicates.remove(id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _duplicateCheckFailed.add(id));
    } finally {
      if (mounted) setState(() => _checkingDuplicates.remove(id));
    }
  }

  // ---------------------------------------------------------------------------
  // Azioni
  // ---------------------------------------------------------------------------

  Future<void> _preview(Map<String, dynamic> item) async {
    final int? id = _id(item);
    if (id == null) return;
    await showDriveFilePreview(context,
        load: () => _api.downloadAdminMaterialPublicationFile(id),
        name: item['original_name']?.toString() ?? 'Materiale',
        mimeType: item['mime_type']?.toString() ?? 'application/octet-stream');
  }

  /// Chiede la cartella Drive quando Drive è configurato. `null` = annullato.
  Future<({bool ok, DrivePlacement? placement})> _askDrivePlacement(
      Map<String, dynamic> item, int id) async {
    try {
      final drive = await _storage.getDriveStatus();
      if (!mounted) return (ok: false, placement: null);
      if (drive['configured'] != true) return (ok: true, placement: null);
      final placement = await showDialog<DrivePlacement>(
        context: context,
        builder: (_) => DrivePlacementDialog(
          inspect: (path) => _api.previewAdminPublicationDrive(requestId: id, path: path),
          previewProposed: () => _preview(item),
          previewExisting: (driveId, fileName, mimeType) => showDriveFilePreview(context,
              load: () => _storage.downloadDriveFilePreview(driveId), name: fileName, mimeType: mimeType),
        ),
      );
      return (ok: placement != null, placement: placement);
    } catch (_) {
      _message('Non posso controllare il percorso Drive. Riprova prima di approvare.');
      return (ok: false, placement: null);
    }
  }

  Future<bool> _approve(Map<String, dynamic> item, _Decision decision, bool forceAnonymous,
      List<String>? catalogPath, String? audienceType) async {
    final int? id = _id(item);
    if (id == null || _processing.contains(id)) return false;
    if (_checkingDuplicates.contains(id) || _duplicateCheckFailed.contains(id)) {
      _message('Controlla di nuovo le versioni disponibili prima di approvare.');
      return false;
    }

    setState(() => _processing.add(id));
    DrivePlacement? placement;
    if (decision != _Decision.alreadyAvailable) {
      final drive = await _askDrivePlacement(item, id);
      if (!drive.ok || !mounted) {
        if (mounted) setState(() => _processing.remove(id));
        return false;
      }
      placement = drive.placement;
    }

    try {
      final dup = _duplicateStatus(item);
      final comparison = item['comparison_status']?.toString().toLowerCase() ?? 'pending';
      String action = 'publish_new';
      switch (decision) {
        case _Decision.publishNew:
          action = 'publish_new';
        case _Decision.newVersion:
          if (!const {'candidate_update', 'pending'}.contains(comparison)) {
            await _api.reviewAdminMaterialDuplicate(requestId: id, data: {
              'duplicate_status': 'not_duplicate', 'comparison_status': 'candidate_update'});
          }
          action = 'update_existing';
        case _Decision.separate:
          if (!const {'different_material', 'not_required'}.contains(comparison)) {
            await _api.reviewAdminMaterialDuplicate(requestId: id, data: {
              'duplicate_status': 'not_duplicate', 'comparison_status': 'different_material'});
          }
          action = _requestType(item) == 'new_material' ? 'publish_new' : 'publish_separate';
        case _Decision.alreadyAvailable:
          if (dup != 'confirmed') {
            await _api.reviewAdminMaterialDuplicate(requestId: id, data: {'duplicate_status': 'confirmed'});
          }
          action = 'keep_existing';
      }
      await _api.approveAdminMaterialPublication(requestId: id, data: {
        'approved_action': action,
        'force_anonymous': forceAnonymous,
        if (decision != _Decision.alreadyAvailable && catalogPath != null)
          'catalog_path_segments': catalogPath,
        if (decision != _Decision.alreadyAvailable && audienceType != null)
          'audience_type': audienceType,
        if (placement != null) 'drive_path_segments': placement.path,
        if (placement != null) 'allow_drive_duplicate': placement.allowDuplicate,
      });
      _message(decision == _Decision.alreadyAvailable
          ? 'Proposta chiusa: il materiale era già disponibile.'
          : 'Materiale approvato. Se Drive è momentaneamente indisponibile resta in attesa, senza perdere il file.');
      await _load();
      return true;
    } catch (error) {
      _message(slErrorMessage(error, fallback: 'Operazione non riuscita. La proposta non è stata modificata.'));
      return false;
    } finally {
      if (mounted) setState(() => _processing.remove(id));
    }
  }

  Future<bool> _reject(Map<String, dynamic> item) async {
    final int? id = _id(item);
    if (id == null || _processing.contains(id)) return false;
    final p = context.palette;
    final controller = TextEditingController();
    const presets = <String>[
      'Il materiale è già disponibile su StudentLab.',
      'Il file non è leggibile o è incompleto.',
      'Il contenuto non riguarda la materia indicata.',
    ];
    final String? reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('Rifiuta proposta'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('Lo studente riceverà il motivo nella notifica.', style: SlText.muted(p)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                for (final preset in presets)
                  ActionChip(
                    label: Text(preset, style: const TextStyle(fontSize: 12)),
                    onPressed: () => update(() => controller.text = preset),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                onChanged: (_) => update(() {}),
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Motivo del rifiuto'),
              ),
            ]),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.adminCoral, foregroundColor: p.darkElegance),
              onPressed: controller.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Rifiuta'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return false;
    setState(() => _processing.add(id));
    try {
      await _api.rejectAdminMaterialPublication(requestId: id, data: {'rejection_reason': reason});
      _message('Proposta rifiutata.');
      await _load();
      return true;
    } catch (error) {
      _message(slErrorMessage(error));
      return false;
    } finally {
      if (mounted) setState(() => _processing.remove(id));
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pendingCount = _status == 'pending' ? _items.length : null;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: slAdminAppBar(context, title: 'Esamina proposte', actions: <Widget>[
        IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final bool wide = constraints.maxWidth >= _wideBreakpoint;
          final Widget filters = Padding(
            padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 0),
            child: SlFilterBar<String>(
              selected: _status,
              options: <SlFilterOption<String>>[
                SlFilterOption(value: 'pending', label: 'In attesa', count: pendingCount),
                const SlFilterOption(value: 'approved', label: 'Approvate'),
                const SlFilterOption(value: 'rejected', label: 'Rifiutate'),
                const SlFilterOption(value: 'all', label: 'Tutte'),
              ],
              onSelected: (status) {
                if (status == _status) return;
                setState(() { _status = status; _selectedId = null; });
                _load();
              },
            ),
          );
          if (_loading && _items.isEmpty) {
            return Column(children: <Widget>[filters, Expanded(child: Center(child: CircularProgressIndicator(color: p.skyBlue)))]);
          }
          if (_error != null) {
            return Column(children: <Widget>[
              filters,
              Padding(padding: const EdgeInsets.all(16), child: SlErrorCard(title: _error!, message: 'Controlla la connessione e riprova.', onRetry: _load)),
            ]);
          }
          final items = _visibleItems;
          final list = _buildQueue(items, wide);
          if (!wide) return Column(children: <Widget>[filters, Expanded(child: list)]);
          final matches = items.where((i) => _id(i) == _selectedId);
          final Map<String, dynamic>? selected = matches.isNotEmpty ? matches.first : (items.isNotEmpty ? items.first : null);
          return Column(children: <Widget>[
            filters,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  SizedBox(width: 400, child: _queuePanel(list)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: selected == null
                        ? const SlEmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Nessuna proposta selezionata',
                            message: 'Scegli una proposta dall’elenco per vederne i dettagli.')
                        : _PublicationDetail(
                            key: ValueKey<int?>(_id(selected)),
                            state: this,
                            item: selected,
                          ),
                  ),
                ]),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _queuePanel(Widget list) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }

  Widget _buildQueue(List<Map<String, dynamic>> items, bool wide) {
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(wide ? 8 : 16),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 6 : 0, wide ? 6 : 0, wide ? 6 : 0, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(color: p.pureWhite, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Cerca per titolo, materia o studente',
                fillColor: p.darkElegance,
              ),
            ),
          ),
          if (items.isEmpty)
            const SlEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Nessuna proposta qui',
              message: 'Quando uno studente propone un materiale lo trovi in questa coda.',
            )
          else
            for (final item in items) _queueTile(item, wide),
        ],
      ),
    );
  }

  Widget _queueTile(Map<String, dynamic> item, bool wide) {
    final p = context.palette;
    final id = _id(item);
    final bool selected = wide && id == _selectedId;
    final dup = _duplicateStatus(item);
    final status = item['status']?.toString().toLowerCase() ?? 'pending';
    final proposer = _proposerName(item);
    final badges = <Widget>[
      if (status == 'approved') const SlStatusBadge(label: 'Approvata', tone: SlTone.success)
      else if (status == 'rejected') const SlStatusBadge(label: 'Rifiutata', tone: SlTone.danger)
      else if (dup == 'confirmed') const SlStatusBadge(label: 'Duplicato', tone: SlTone.warning)
      else if (dup == 'suspected') const SlStatusBadge(label: 'Possibile duplicato', tone: SlTone.warning)
      else if (_requestType(item) == 'update_candidate') const SlStatusBadge(label: 'Aggiornamento', tone: SlTone.blue)
      else const SlStatusBadge(label: 'Nuovo', tone: SlTone.success),
      SlStatusBadge(label: item['attribution_mode'] == 'named' ? 'Con nome' : 'Anonimo'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? p.skyBlue.withValues(alpha: 0.10) : (wide ? Colors.transparent : p.eleganceMidnight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? p.skyBlue.withValues(alpha: 0.36) : (wide ? Colors.transparent : p.skyBlue.withValues(alpha: 0.12))),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (wide) {
              setState(() => _selectedId = id);
              if (id != null && item['status'] == 'pending') await _recheckDuplicate(id);
            } else {
              if (id != null && item['status'] == 'pending') await _recheckDuplicate(id);
              if (!mounted) return;
              final fresh = _items.where((entry) => _id(entry) == id);
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
                _PublicationDetailPage(state: this, item: fresh.isEmpty ? item : fresh.first)));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Expanded(
                  child: Text(item['title']?.toString() ?? item['original_name']?.toString() ?? 'Materiale',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text(_relative(item['created_at']), style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56))),
              ]),
              const SizedBox(height: 4),
              Text(<String>[
                if ((item['subject_name']?.toString() ?? '').isNotEmpty) item['subject_name'].toString(),
                if (proposer != null) proposer,
              ].join(' · '), style: SlText.muted(p)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: badges),
            ]),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Dettaglio
// -----------------------------------------------------------------------------

class _PublicationDetailPage extends StatelessWidget {
  final _AdminMaterialPublicationsPageState state;
  final Map<String, dynamic> item;

  const _PublicationDetailPage({required this.state, required this.item});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: slAdminAppBar(context, title: 'Proposta', breadcrumb: 'ADMIN / ESAMINA PROPOSTE'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _PublicationDetail(state: state, item: item, popOnDone: true),
        ),
      ),
    );
  }
}

class _PublicationDetail extends StatefulWidget {
  final _AdminMaterialPublicationsPageState state;
  final Map<String, dynamic> item;
  final bool popOnDone;

  const _PublicationDetail({super.key, required this.state, required this.item, this.popOnDone = false});

  @override
  State<_PublicationDetail> createState() => _PublicationDetailState();
}

class _PublicationDetailState extends State<_PublicationDetail> {
  late _Decision _decision;
  late bool _forceAnonymous;
  late List<String> _catalogPath;
  late String _audienceType;
  bool _catalogPathChanged = false;
  bool _audienceChanged = false;

  _AdminMaterialPublicationsPageState get s => widget.state;
  Map<String, dynamic> get item => widget.item;

  @override
  void initState() {
    super.initState();
    _decision = s._defaultDecision(item);
    _forceAnonymous = item['attribution_mode'] != 'named';
    _catalogPath = item['path_segments'] is List
        ? (item['path_segments'] as List).map((value) => value.toString()).toList()
        : <String>[];
    _audienceType = 'course';
  }

  @override
  void didUpdateWidget(covariant _PublicationDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['possible_duplicate_material_id'] !=
            item['possible_duplicate_material_id'] ||
        oldWidget.item['duplicate_status'] != item['duplicate_status']) {
      _decision = s._defaultDecision(item);
    }
  }

  bool get _pending => (item['status']?.toString().toLowerCase() ?? 'pending') == 'pending';

  String _approveLabel() {
    switch (_decision) {
      case _Decision.publishNew:
        return 'Approva e pubblica';
      case _Decision.newVersion:
        return 'Approva come nuova versione';
      case _Decision.separate:
        return 'Pubblica come materiale separato';
      case _Decision.alreadyAvailable:
        return 'Chiudi: già disponibile';
    }
  }

  Future<void> _done(Future<bool> action) async {
    final ok = await action;
    if (ok && widget.popOnDone && mounted) Navigator.of(context).pop();
  }

  Future<void> _editCatalogPath() async {
    final controller = TextEditingController(text: _catalogPath.join(' / '));
    String? error;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, update) {
        return AlertDialog(
          title: const Text('Cambia posizione nelle Dispense'),
          content: SizedBox(width: 480, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Materia: ${item['subject_name'] ?? 'materia della proposta'}'),
              const SizedBox(height: 8),
              const Text('Indica le cartelle dentro questa materia, separate da /. '
                  'Il file sul dispositivo e la cartella Drive restano al loro posto.'),
              const SizedBox(height: 12),
              TextField(controller: controller,
                decoration: const InputDecoration(labelText: 'Cartelle (facoltative)',
                  hintText: 'Livello trasporto / TCP')),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: TextStyle(color: AppColors.orangeAccent))),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
            FilledButton(onPressed: () {
              final parts = controller.text.trim().isEmpty ? <String>[] :
                controller.text.split('/').map((part) => part.trim()).toList();
              if (parts.length > 20 || parts.any((part) => part.isEmpty ||
                  part.length > 150 || part == '.' || part == '..' ||
                  part.contains('\\'))) {
                update(() => error = 'Controlla le cartelle: massimo 20 livelli, 150 caratteri per nome.');
                return;
              }
              Navigator.pop(dialogContext, parts);
            }, child: const Text('Usa questa posizione')),
          ],
        );
      }),
    );
    controller.dispose();
    if (selected != null && mounted) setState(() {
      _catalogPath = selected;
      _catalogPathChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final id = s._id(item);
    final busy = id != null && (s._processing.contains(id) || s._checkingDuplicates.contains(id));
    final description = item['description']?.toString().trim() ?? '';
    return Container(
      decoration: BoxDecoration(
        color: p.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(builder: (context, width) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            SlFileTile(kind: slFileKind(item['mime_type']?.toString(), item['original_name']?.toString()), size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(item['title']?.toString() ?? 'Materiale', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.pureWhite, fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(<String>[
                  item['original_name']?.toString() ?? '',
                  s._bytes(item['file_size'] ?? item['size']),
                  if ((item['sha256'] ?? item['file_hash']) != null) 'SHA-256 ${s._shortHash(item['sha256'] ?? item['file_hash'])}',
                ].where((v) => v.isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: SlText.mono(p, size: 12)),
                if (description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('“$description”', style: SlText.body(p)),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            if (width.maxWidth >= 410)
              SlActionButton(icon: Icons.visibility_outlined, label: 'Anteprima', primary: true, onPressed: () => s._preview(item))
            else IconButton(onPressed: () => s._preview(item), tooltip: 'Anteprima', icon: const Icon(Icons.visibility_outlined)),
          ])),
        ),
        Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final bool twoColumns = constraints.maxWidth >= 720;
            final left = _leftColumn();
            final right = _rightColumn();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: twoColumns
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Expanded(child: left),
                      const SizedBox(width: 18),
                      SizedBox(width: 320, child: right),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[left, const SizedBox(height: 18), right]),
            );
          }),
        ),
        if (_pending) ...<Widget>[
          Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
          if (id != null && s._duplicateCheckFailed.contains(id))
            Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: SlErrorCard(title: 'Controllo delle versioni non disponibile',
                message: 'La proposta è ancora in attesa. Riprova prima di approvare.',
                onRetry: () => s._recheckDuplicate(id))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Text('Lo studente riceverà una notifica con l’esito.', style: SlText.muted(p)),
                OutlinedButton(
                  onPressed: busy ? null : () => _done(s._reject(item)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.adminCoral,
                    minimumSize: const Size(0, 44),
                    side: BorderSide(color: p.adminCoral.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Rifiuta…'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => _done(s._approve(
                      item, _decision, _forceAnonymous,
                      _decision == _Decision.newVersion && !_catalogPathChanged
                          ? null : _catalogPath,
                      _decision == _Decision.newVersion && !_audienceChanged
                          ? null : _audienceType)),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.skyBlue,
                    foregroundColor: p.darkElegance,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: busy
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
                      : Text(_approveLabel()),
                ),
              ],
            ),
          ),
        ] else if (item['rejection_reason'] != null) ...<Widget>[
          Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SlKeyValue(label: 'Motivo del rifiuto', value: item['rejection_reason'].toString()),
          ),
        ],
      ]),
    );
  }

  Widget _leftColumn() {
    final p = context.palette;
    final children = <Widget>[];
    if (s._hasDuplicatePanel(item)) {
      children.add(_duplicatePanel());
      children.add(const SizedBox(height: 16));
    }
    final previewSize = int.tryParse((item['file_size'] ?? item['size'])?.toString() ?? '') ?? 0;
    children.add(Container(
      height: 165,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.picture_as_pdf_outlined, color: p.skyBlue, size: 34),
        const SizedBox(height: 8),
        Text(item['original_name']?.toString() ?? 'File proposto',
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: SlText.body(p)),
        const SizedBox(height: 8),
        Text('Dimensione: ${s._bytes(previewSize)}', style: SlText.muted(p)),
        TextButton.icon(onPressed: () => s._preview(item),
          icon: const Icon(Icons.visibility_outlined), label: const Text('Apri anteprima')),
      ]),
    ));
    children.add(const SizedBox(height: 16));
    final hash = (item['sha256'] ?? item['file_hash'])?.toString();
    final requestType = s._requestType(item) == 'update_candidate' ? 'Aggiornamento di un materiale' : 'Nuovo materiale';
    children.add(const SlOverline('Dettagli'));
    children.add(const SizedBox(height: 8));
    children.add(Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(12)),
      child: Column(children: <Widget>[
        SlKeyValue(label: 'Tipo di proposta', value: requestType),
        SlKeyValue(label: 'Tipo file', value: item['mime_type']?.toString() ?? '—', mono: true),
        if (hash != null && hash.isNotEmpty) SlKeyValue(label: 'SHA-256', value: hash, mono: true),
        SlKeyValue(label: 'Stato', value: item['status']?.toString() ?? '—'),
      ]),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _duplicatePanel() {
    final p = context.palette;
    final id = s._id(item);
    final dup = s._duplicateStatus(item);
    final confirmed = dup == 'confirmed';
    final options = s._decisions(item);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.adminAmber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.adminAmber.withValues(alpha: 0.34)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[
          Icon(Icons.content_copy_rounded, size: 18, color: p.adminAmber),
          const SizedBox(width: 8),
          Text(confirmed ? 'Duplicato confermato' : (s._requestType(item) == 'update_candidate' ? 'Proposta di aggiornamento' : 'Possibile duplicato'),
              style: TextStyle(color: p.adminAmber, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(confirmed ? 'Contenuto identico a un materiale già pubblicato.' : 'Contenuto simile a un materiale già pubblicato.',
                style: SlText.muted(p)),
          ),
        ]),
        const SizedBox(height: 12),
        if (id != null)
          FutureBuilder<Map<String, dynamic>>(
            future: s._duplicateFor(id),
            builder: (context, snapshot) {
              final existing = snapshot.data;
              final existingCard = _compareCard(
                label: 'Già pubblicato',
                title: existing?['title']?.toString() ?? (snapshot.hasError ? 'Non disponibile' : 'Caricamento…'),
                meta: existing == null ? '' : <String>[
                  s._bytes(existing['file_size'] ?? existing['size']),
                  if (existing['created_at'] != null) s._relative(existing['created_at']),
                ].join(' · '),
                highlight: false,
              );
              final proposedCard = _compareCard(
                label: 'Proposta',
                title: item['title']?.toString() ?? 'Materiale',
                meta: <String>[
                  s._bytes(item['file_size'] ?? item['size']),
                  if (s._proposerName(item) != null) s._proposerName(item)!,
                ].join(' · '),
                highlight: true,
                note: existing != null && (existing['file_hash'] ?? existing['sha256']) != null
                    ? ((existing['file_hash'] ?? existing['sha256']).toString().toLowerCase() ==
                            (item['file_hash'] ?? item['sha256'])?.toString().toLowerCase()
                        ? 'Stesso hash: file identico'
                        : 'Hash diverso: contenuto modificato')
                    : null,
              );
              return LayoutBuilder(builder: (context, c) => c.maxWidth >= 480
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Expanded(child: existingCard), const SizedBox(width: 10), Expanded(child: proposedCard)])
                  : Column(children: <Widget>[existingCard, const SizedBox(height: 10), proposedCard]));
            },
          ),
        const SizedBox(height: 12),
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SlChoiceTile(
              title: switch (option) {
                _Decision.newVersion => 'Sostituisci come nuova versione',
                _Decision.separate => 'Pubblica come materiale separato',
                _Decision.alreadyAvailable => 'Rifiuta: è già disponibile',
                _Decision.publishNew => 'Pubblica come nuovo materiale',
              },
              description: switch (option) {
                _Decision.newVersion => 'Chi ha il file offline riceve l’aggiornamento.',
                _Decision.separate => 'Restano entrambi nel catalogo.',
                _Decision.alreadyAvailable => 'La proposta si chiude collegata al materiale esistente.',
                _Decision.publishNew => null,
              },
              selected: _decision == option,
              onTap: _pending ? () => setState(() => _decision = option) : () {},
            ),
          ),
      ]),
    );
  }

  Widget _compareCard({required String label, required String title, required String meta, required bool highlight, String? note}) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? p.skyBlue.withValues(alpha: 0.24) : Colors.transparent),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        SlOverline(label),
        const SizedBox(height: 6),
        Text(title, style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
        if (meta.isNotEmpty) ...<Widget>[const SizedBox(height: 4), Text(meta, style: SlText.mono(p, size: 11))],
        if (note != null) ...<Widget>[const SizedBox(height: 4), Text(note, style: SlText.muted(p))],
      ]),
    );
  }

  Widget _rightColumn() {
    final p = context.palette;
    final proposer = s._proposerName(item);
    final path = _catalogPath.join(' / ');
    final placement = <(String, String)>[
      if ((item['university']?.toString() ?? '').isNotEmpty) ('Ateneo', item['university'].toString()),
      if ((item['department']?.toString() ?? '').isNotEmpty) ('Dipartimento', item['department'].toString()),
      if ((item['course_name'] ?? item['course']) != null) ('Corso', (item['course_name'] ?? item['course']).toString()),
      if ((item['subject_name']?.toString() ?? '').isNotEmpty) ('Materia', item['subject_name'].toString()),
      if ((item['topic_name'] ?? item['argument_name'] ?? item['argoment'])?.toString().trim().isNotEmpty == true)
        ('Argomento', (item['topic_name'] ?? item['argument_name'] ?? item['argoment']).toString()),
      if (path.isNotEmpty) ('Cartella', path),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      const SlOverline('Proposto da'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(12)),
        child: Row(children: <Widget>[
          CircleAvatar(
            radius: 17,
            backgroundColor: p.studentBlue,
            child: Text(_initials(proposer), style: TextStyle(color: p.pureWhite, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(proposer ?? 'Studente', style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(s._relative(item['created_at']), style: SlText.muted(p)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      const SlOverline('Posizione nel catalogo'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(12)),
        child: Column(children: <Widget>[
          if (placement.isEmpty) Text('Posizione non indicata.', style: SlText.muted(p)),
          for (final (label, value) in placement) SlKeyValue(label: label, value: value),
          if (_pending) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: _editCatalogPath,
              child: const Text('Cambia posizione'),
            )),
          ],
        ]),
      ),
      const SizedBox(height: 18),
      const SlOverline('Pubblicazione'),
      const SizedBox(height: 4),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: !_forceAnonymous,
        onChanged: !_pending || item['attribution_mode'] != 'named'
            ? null
            : (value) => setState(() => _forceAnonymous = !value),
        title: Text('Mostra il nome dell’autore', style: SlText.body(p)),
        subtitle: item['attribution_mode'] != 'named'
            ? Text('Lo studente ha chiesto di restare anonimo.', style: SlText.muted(p))
            : null,
      ),
      if (_pending) DropdownButtonFormField<String>(
        value: _audienceType,
        decoration: const InputDecoration(labelText: 'Destinatari'),
        items: const [
          DropdownMenuItem(value: 'course', child: Text('Studenti del corso')),
          DropdownMenuItem(value: 'subject', child: Text('Studenti della materia')),
          DropdownMenuItem(value: 'public', child: Text('Tutti, inclusi gli ospiti')),
        ],
        onChanged: (value) {
          if (value != null) setState(() { _audienceType = value; _audienceChanged = true; });
        },
      ) else SlKeyValue(label: 'Destinatari', value: _audienceType),
    ]);
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((v) => v.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((v) => v[0].toUpperCase()).join();
  }
}
