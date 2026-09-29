import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../social/admin/admin_material_storage_api_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/studentlab_ui/studentlab_ui.dart';
import 'admin_material_upload_page.dart';
import 'drive_file_preview.dart';

/// La struttura StudentLab è indipendente dai percorsi fisici su Drive.
class AdminDriveCatalogPage extends StatefulWidget {
  const AdminDriveCatalogPage({super.key});

  @override
  State<AdminDriveCatalogPage> createState() => _AdminDriveCatalogPageState();
}

class _AdminDriveCatalogPageState extends State<AdminDriveCatalogPage> {
  final _api = AdminMaterialStorageApiService();
  final _trail = <(String?, String)>[(null, 'StudentLab')];
  final _search = TextEditingController();
  List<Map<String, dynamic>> _drive = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _draft = [];
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _imports = [];
  String? _nextPage;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _previewMode = false;
  int? _viewerId;
  Map<String, dynamic>? _preview;
  int? _subjectId;
  int? _selectedId;
  int _compactPane = 0;

  /// Cartelle Drive aperte nell'albero: id -> figli (caricati quando si aprono).
  final Map<String, List<Map<String, dynamic>>> _driveChildren = {};
  final Set<String> _driveOpen = <String>{};
  final Set<String> _driveLoading = <String>{};

  /// Mostra anche i file nascosti, in revisione o archiviati nella struttura.
  bool _showHidden = true;

  /// Cartella della struttura sotto il cursore durante il trascinamento.
  String? _dropTarget;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _integer(Object? value) => int.tryParse('$value') ?? 0;
  int get _draftCount => _draft.length + _imports.length +
    _folders.where((folder) => folder['draft'] == true).length;
  String _string(Object? value) => value?.toString() ?? '';
  double _dialogWidth(BuildContext context, double preferred) {
    final available = MediaQuery.sizeOf(context).width - 80;
    return available < preferred ? available.clamp(160.0, preferred) : preferred;
  }
  List<String> _path(Object? value) => value is List ? value.map((e) => '$e').toList() : [];

  Map<String, dynamic> _effective(Map<String, dynamic> item) {
    final id = _integer(item['id']);
    final change = _draft.where((d) => _integer(d['material_id']) == id);
    if (change.isEmpty) return item;
    final d = change.first;
    return {...item, 'subject_id': d['subject_id'], 'path_segments': d['path_segments'],
      'visibility_state': d['visibility_state'], 'audience_type': d['audience_type'],
      'audience_id': d['audience_id'], 'draft': true};
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await Future.wait<dynamic>([
        _api.getDriveTree(_trail.last.$1),
        _api.getItems(source: 'public'),
        _api.getDriveImportOptions(),
        _api.getCatalogSnapshot(),
      ]);
      if (!mounted) return;
      final drive = Map<String, dynamic>.from(data[0] as Map);
      final subjects = (data[2] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final catalog = Map<String, dynamic>.from(data[3] as Map);
      setState(() {
        _drive = (drive['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _nextPage = drive['next_page_token']?.toString();
        _materials = (data[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _subjects = subjects;
        _draft = (catalog['changes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _folders = (catalog['folders'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _imports = (catalog['imports'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (_subjectId == null && subjects.isNotEmpty) _subjectId = _integer(subjects.first['id']);
        _loading = false;
      });
      // Le cartelle Drive aperte vengono ricaricate: lo stato "nel catalogo"
      // cambia dopo importazioni e pubblicazioni.
      final openFolders = _driveOpen.toList();
      _driveChildren.clear();
      for (final id in openFolders) {
        try {
          final value = await _api.getDriveTree(id);
          _driveChildren[id] = (value['items'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } catch (_) {
          _driveOpen.remove(id);
        }
      }
      if (mounted) setState(() {});
      if (_previewMode) await _loadPreview();
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Il catalogo non è disponibile. Verifica la connessione e riprova.';
      });
    }
  }

  Future<void> _loadDrive() async {
    try {
      final value = await _api.getDriveTree(_trail.last.$1);
      if (!mounted) return;
      setState(() {
        _drive = (value['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _nextPage = value['next_page_token']?.toString();
        _search.clear();
      });
    } catch (e) { _showError(_reason(e, 'Impossibile aprire questa cartella Drive.')); }
  }

  Future<void> _more() async {
    if (_nextPage == null) return;
    final token = _nextPage;
    setState(() => _busy = true);
    try {
      final value = await _api.getDriveTree(_trail.last.$1, token);
      if (mounted) setState(() {
        _drive.addAll((value['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _nextPage = value['next_page_token']?.toString();
      });
    } catch (e) { _showError(_reason(e, 'Non è stato possibile caricare gli altri file.')); }
    if (mounted) setState(() => _busy = false);
  }

  /// Motivo leggibile restituito dal server (es. "Completa prima il
  /// caricamento su Drive."); se manca o è tecnico, il testo di riserva.
  String _reason(Object error, String fallback) {
    final String text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty || text.length > 220 || text.contains('<') ||
        RegExp(r'^\d{3}\b').hasMatch(text) || text.startsWith('Bad state')) {
      return fallback;
    }
    return text;
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  Future<void> _loadPreview() async {
    setState(() => _busy = true);
    try {
      final value = await _api.previewCatalog(userId: _viewerId);
      if (mounted) setState(() => _preview = value);
    } catch (e) { _showError(_reason(e, 'Anteprima non disponibile. Riprova tra poco.')); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _setViewer() async {
    final controller = TextEditingController(text: _viewerId?.toString() ?? '');
    final chosen = await showDialog<int?>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Anteprima come studente'),
      content: TextField(controller: controller, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'ID studente', hintText: 'Lascia vuoto per guest')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0),
          child: const Text('Mostra'))],
    ));
    controller.dispose();
    if (chosen == null || !mounted) return;
    setState(() => _viewerId = chosen == 0 ? null : chosen);
    await _loadPreview();
  }

  Future<void> _stage(Map<String, dynamic> item) async {
    final current = _effective(item);
    int subjectId = _integer(current['subject_id']);
    String state = _string(current['visibility_state']);
    if (!{'visible', 'hidden', 'in_review', 'archived'}.contains(state)) state = 'visible';
    String audience = _string(current['audience_type']);
    if (!{'public', 'course', 'subject', 'group', 'user'}.contains(audience)) audience = 'public';
    final path = TextEditingController(text: _path(current['path_segments']).join(' / '));
    final recipient = TextEditingController(text: current['audience_id']?.toString() ?? '');
    final choice = await showDialog<(int, List<String>, String, String, int?)>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text('Gestisci: ${_string(item['title'])}'),
        content: SizedBox(width: _dialogWidth(ctx, 460), child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Le modifiche resteranno in bozza fino a «Pubblica struttura».'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(value: _subjects.any((e) => _integer(e['id']) == subjectId)
              ? subjectId : null, decoration: const InputDecoration(labelText: 'Materia'),
              items: [for (final s in _subjects) DropdownMenuItem(value: _integer(s['id']),
                child: Text('${s['name']} · ${s['course']}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) { if (v != null) update(() => subjectId = v); }),
            TextField(controller: path, decoration: const InputDecoration(
              labelText: 'Percorso nelle Dispense', hintText: 'Cartella / Sottocartella',
              helperText: 'Il percorso Drive non cambia')),
            DropdownButtonFormField<String>(value: state, decoration: const InputDecoration(labelText: 'Visibilità'),
              items: const [DropdownMenuItem(value: 'visible', child: Text('Visibile')),
                DropdownMenuItem(value: 'hidden', child: Text('Nascosto')),
                DropdownMenuItem(value: 'in_review', child: Text('In revisione')),
                DropdownMenuItem(value: 'archived', child: Text('Archiviato'))],
              onChanged: (v) { if (v != null) update(() => state = v); }),
            DropdownButtonFormField<String>(value: audience, decoration: const InputDecoration(labelText: 'Destinatari'),
              items: const [DropdownMenuItem(value: 'public', child: Text('Tutti, anche guest')),
                DropdownMenuItem(value: 'course', child: Text('Studenti del corso')),
                DropdownMenuItem(value: 'subject', child: Text('Studenti della materia')),
                DropdownMenuItem(value: 'group', child: Text('Un gruppo')),
                DropdownMenuItem(value: 'user', child: Text('Uno studente'))],
              onChanged: (v) { if (v != null) update(() => audience = v); }),
            if (audience == 'group' || audience == 'user') TextField(controller: recipient,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: audience == 'group' ? 'ID gruppo' : 'ID studente')),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(onPressed: () {
            final parts = path.text.split('/').map((s) => s.trim()).toList();
            final cleaned = path.text.trim().isEmpty ? <String>[] : parts;
            final id = int.tryParse(recipient.text.trim());
            if (subjectId <= 0 || cleaned.any((s) => s.isEmpty) ||
                ((audience == 'group' || audience == 'user') && (id == null || id <= 0))) return;
            Navigator.pop(ctx, (subjectId, cleaned, state, audience,
              audience == 'group' || audience == 'user' ? id : null));
          }, child: const Text('Salva in bozza'))],
      )));
    path.dispose(); recipient.dispose();
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.stageCatalogFile(materialId: _integer(item['id']),
        subjectId: choice.$1, pathSegments: choice.$2,
        visibilityState: choice.$3, audienceType: choice.$4, audienceId: choice.$5);
      await _reload();
    } catch (e) { _showError(_reason(e, 'Modifica non salvata. Controlla materia, destinatari e percorso.')); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _editFolder(String folder, List<Map<String, dynamic>> children) async {
    if (folder.isEmpty || children.isEmpty) return;
    final parts = folder.split(' / ');
    final controller = TextEditingController(text: parts.last);
    String action = 'rename';
    final choice = await showDialog<(String, String)>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text('Cartella ${parts.last}'),
        content: SizedBox(width: _dialogWidth(ctx, 400), child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            const Text('L’operazione interessa tutti i file di questa cartella. La bozza si pubblica dalla barra in alto.'),
            DropdownButtonFormField<String>(value: action,
              items: const [DropdownMenuItem(value: 'rename', child: Text('Rinomina cartella')),
                DropdownMenuItem(value: 'move', child: Text('Sposta in un altro percorso')),
                DropdownMenuItem(value: 'hide', child: Text('Nascondi tutti i file')),
                DropdownMenuItem(value: 'show', child: Text('Mostra tutti i file'))],
              onChanged: (v) { if (v != null) update(() => action = v); }),
            if (action == 'rename' || action == 'move') TextField(controller: controller,
              decoration: InputDecoration(labelText: action == 'rename'
                ? 'Nuovo nome cartella' : 'Nuovo percorso completo',
                hintText: action == 'move' ? 'Cartella / Sottocartella' : null)),
          ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(onPressed: () {
            if ((action == 'rename' || action == 'move') && controller.text.trim().isEmpty) return;
            Navigator.pop(ctx, (action, controller.text.trim()));
          }, child: const Text('Salva in bozza'))],
      )));
    controller.dispose();
    if (choice == null || !mounted) return;
    final oldPath = parts;
    final target = choice.$1 == 'rename'
      ? [...oldPath.take(oldPath.length - 1), choice.$2]
      : choice.$2.split('/').map((s) => s.trim()).toList();
    setState(() => _busy = true);
    try {
      for (final row in children) {
        final effective = _effective(row);
        final path = _path(effective['path_segments']);
        if (path.length < oldPath.length ||
            path.take(oldPath.length).join('/') != oldPath.join('/')) continue;
        final next = choice.$1 == 'hide' || choice.$1 == 'show'
          ? path : [...target, ...path.skip(oldPath.length)];
        await _api.stageCatalogFile(materialId: _integer(row['id']),
          subjectId: _integer(effective['subject_id']), pathSegments: next,
          visibilityState: choice.$1 == 'hide' ? 'hidden'
            : choice.$1 == 'show' ? 'visible' : _string(effective['visibility_state']),
          audienceType: _string(effective['audience_type']),
          audienceId: effective['audience_id'] == null ? null : _integer(effective['audience_id']));
      }
      await _reload();
    } catch (e) {
      _showError(_reason(e, 'Operazione sulla cartella incompleta. Controlla le modifiche in bozza prima di pubblicare.'));
      await _reload();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _import(Map<String, dynamic> file, {List<String>? initialPath}) async {
    if (_subjects.isEmpty) { _showError('Nessuna materia disponibile per classificare il file.'); return; }
    int subjectId = _subjectId ?? _integer(_subjects.first['id']);
    String audience = 'public';
    final recipient = TextEditingController();
    final pathController = TextEditingController(text: (initialPath ?? const <String>[]).join(' / '));
    final selected = await showDialog<(int, String, int?, List<String>)>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Aggiungi dal Drive'),
        content: SizedBox(width: _dialogWidth(ctx, 420), child: SingleChildScrollView(child:
          Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_string(file['name']), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          const Text('Il file resta sul Drive. Sarà visibile solo dopo «Pubblica struttura».'),
          DropdownButtonFormField<int>(value: subjectId,
            items: [for (final s in _subjects) DropdownMenuItem(value: _integer(s['id']),
              child: Text('${s['name']} · ${s['course']}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) { if (v != null) update(() => subjectId = v); }),
          DropdownButtonFormField<String>(value: audience,
            items: const [DropdownMenuItem(value: 'public', child: Text('Tutti, anche guest')),
              DropdownMenuItem(value: 'course', child: Text('Studenti del corso')),
              DropdownMenuItem(value: 'subject', child: Text('Studenti della materia')),
              DropdownMenuItem(value: 'group', child: Text('Un gruppo')),
              DropdownMenuItem(value: 'user', child: Text('Uno studente'))],
            onChanged: (v) { if (v != null) update(() => audience = v); }),
          TextField(controller: pathController,
            decoration: const InputDecoration(labelText: 'Percorso nelle Dispense',
              hintText: 'Cartella / Sottocartella')),
          if (audience == 'group' || audience == 'user') TextField(controller: recipient,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: audience == 'group' ? 'ID gruppo' : 'ID studente')),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(onPressed: () {
            final id = int.tryParse(recipient.text.trim());
            if ((audience == 'group' || audience == 'user') && (id == null || id <= 0)) return;
            final path = pathController.text.trim().isEmpty ? <String>[] :
              pathController.text.split('/').map((e) => e.trim()).toList();
            if (path.any((e) => e.isEmpty)) return;
            Navigator.pop(ctx, (subjectId, audience, id, path));
          }, child: const Text('Aggiungi alla bozza'))],
      )));
    recipient.dispose(); pathController.dispose();
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      var path = selected.$4;
      var allowDuplicate = false;
      for (var attempt = 0; attempt < 3; attempt++) {
        final result = await _api.stageDriveImport(fileId: _string(file['id']),
          subjectId: selected.$1, pathSegments: path,
          audienceType: selected.$2, audienceId: selected.$3,
          allowDuplicate: allowDuplicate);
        if (result['staged'] == true || !mounted) break;
        final matches = (result['conflicts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (matches.isEmpty) break;
        final candidate = TextEditingController(text: path.join(' / '));
        final decision = await showDialog<(List<String>, bool)>(context: context,
          builder: (ctx) => AlertDialog(title: const Text('Possibile duplicato'),
            content: SizedBox(width: _dialogWidth(ctx, 460), child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Da aggiungere: ${_string(file['name'])}\nPercorso: ${path.join(' / ')}\nDimensione: ${_string(file['size'])} byte'),
                const SizedBox(height: 12),
                for (final match in matches) ListTile(
                  title: Text(_string(match['name'])),
                  subtitle: Text('Già in: ${_path(match['path_segments']).join(' / ')} · ${_string(match['size'])} byte'),
                  trailing: IconButton(tooltip: 'Vedi file trovato',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => showDriveFilePreview(context,
                      load: () => _api.downloadPublicMaterialPreview(_integer(match['id'])),
                      name: _string(match['name']), mimeType: _string(file['mime_type'])))),
                TextField(controller: candidate, decoration: const InputDecoration(
                  labelText: 'Nuovo percorso nelle Dispense')),
              ]))),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
              TextButton(onPressed: () => Navigator.pop(ctx, (path, true)),
                child: const Text('Conserva anche questo file')),
              FilledButton(onPressed: () {
                final next = candidate.text.trim().isEmpty ? <String>[] :
                  candidate.text.split('/').map((s) => s.trim()).toList();
                if (next.any((s) => s.isEmpty)) return;
                Navigator.pop(ctx, (next, true));
              }, child: const Text('Cambia percorso'))],
          ));
        candidate.dispose();
        if (decision == null) break;
        path = decision.$1;
        allowDuplicate = decision.$2;
      }
      await _reload();
    } catch (e) { _showError(_reason(e, 'File non aggiunto alla bozza. Verifica permessi e dimensione (massimo 20 MB).')); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _publish() async {
    if (_draftCount == 0 || _busy) return;
    setState(() => _busy = true);
    try { await _api.publishCatalogDraft(); await _reload(); }
    catch (e) { _showError(_reason(e, 'La pubblicazione non è riuscita. Aggiorna il catalogo e controlla la bozza.')); }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _discard() async {
    if (_draftCount == 0 || _busy) return;
    final confirm = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(title: const Text('Scartare la bozza?'),
        content: const Text('Le modifiche non pubblicate verranno eliminate.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Scarta'))]));
    if (confirm != true) return;
    try { await _api.discardCatalogDraft(); await _reload(); }
    catch (e) { _showError(_reason(e, 'Non è stato possibile scartare la bozza.')); }
  }

  Future<void> _addFolder() async {
    final subject = _subjectId;
    if (subject == null) return;
    final path = TextEditingController();
    final proposed = await showDialog<List<String>>(context: context,
      builder: (ctx) => AlertDialog(title: const Text('Nuova cartella'),
        content: TextField(controller: path, autofocus: true,
          decoration: const InputDecoration(labelText: 'Percorso completo',
            hintText: 'Esercitazioni / 2025-26',
            helperText: 'Verrà creata nel catalogo, non su Drive')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(onPressed: () {
            final segments = path.text.split('/').map((e) => e.trim()).toList();
            if (segments.any((e) => e.isEmpty)) return;
            Navigator.pop(ctx, segments);
          }, child: const Text('Aggiungi alla bozza'))]));
    path.dispose();
    if (proposed == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.stageCatalogFolder(subjectId: subject, pathSegments: proposed);
      await _reload();
    } catch (e) { _showError(_reason(e, 'Cartella non aggiunta. Controlla il percorso.')); }
    if (mounted) setState(() => _busy = false);
  }

  // ===========================================================================
  // UI (canvas "Catalogo Drive · struttura per gli studenti")
  // Le funzioni sopra (bozza, importazione, pubblicazione, anteprima) sono
  // quelle di prima; qui cambia la presentazione.
  // ===========================================================================

  static const String _folderMime = 'application/vnd.google-apps.folder';

  String _bytes(Object? value) {
    final int size = _integer(value);
    if (size <= 0) return '—';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _date(Object? value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _short(Object? value) {
    final text = value?.toString() ?? '';
    return text.length <= 12 ? text : '${text.substring(0, 4)}…${text.substring(text.length - 4)}';
  }

  Map<String, dynamic>? get _currentSubject {
    final matches = _subjects.where((s) => _integer(s['id']) == _subjectId);
    return matches.isEmpty ? null : matches.first;
  }

  (String, SlTone) _visibilityBadge(String state) => switch (state) {
        'visible' => ('Visibile', SlTone.success),
        'hidden' => ('Nascosto', SlTone.neutral),
        'in_review' => ('In revisione', SlTone.warning),
        'archived' => ('Archiviato', SlTone.neutral),
        _ => (state.isEmpty ? '—' : state, SlTone.neutral),
      };

  String _audienceLabel(String audience) => switch (audience) {
        'public' => 'Tutti, anche guest',
        'course' => 'Studenti del corso',
        'subject' => 'Studenti della materia',
        'group' => 'Un gruppo',
        'user' => 'Uno studente',
        _ => audience,
      };

  (String, SlTone) _audienceBadge(String audience) => switch (audience) {
        'public' => ('Guest', SlTone.cyan),
        'course' => ('Corso', SlTone.info),
        'subject' => ('Materia', SlTone.info),
        'group' => ('Gruppo', SlTone.violet),
        'user' => ('Studente', SlTone.private),
        _ => (audience, SlTone.neutral),
      };

  /// Cartelle conosciute della materia corrente (file, cartelle vuote, bozze).
  List<List<String>> _knownFolders() {
    final seen = <String>{};
    final result = <List<String>>[];
    void add(List<String> path) {
      for (var i = 1; i <= path.length; i++) {
        final prefix = path.take(i).toList();
        if (seen.add(prefix.join('\u0000'))) result.add(prefix);
      }
    }

    for (final m in _materials.map(_effective)) {
      if (_integer(m['subject_id']) == _subjectId && _string(m['status']) != 'removed') {
        add(_path(m['path_segments']));
      }
    }
    for (final f in _folders.where((f) => _integer(f['subject_id']) == _subjectId)) {
      add(_path(f['path_segments']));
    }
    for (final f in _imports.where((f) => _integer(f['subject_id']) == _subjectId)) {
      add(_path(f['path_segments']));
    }
    result.sort((a, b) => a.join(' / ').toLowerCase().compareTo(b.join(' / ').toLowerCase()));
    return result;
  }

  /// Scelta della cartella di destinazione (dialog "Sposta").
  Future<List<String>?> _pickFolder({required String title, required List<String> current}) async {
    final p = context.palette;
    final folders = _knownFolders();
    List<String> selected = List<String>.of(current);
    final newFolder = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, update) {
        final List<String> target = [
          ...selected,
          if (newFolder.text.trim().isNotEmpty) newFolder.text.trim(),
        ];
        Widget row(List<String> path, {required bool isRoot}) {
          final bool active = selected.join('\u0000') == path.join('\u0000');
          return Padding(
            padding: EdgeInsets.only(left: isRoot ? 0 : 14.0 * path.length, bottom: 2),
            child: Material(
              color: active ? p.skyBlue.withValues(alpha: 0.12) : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
                side: BorderSide(color: active ? p.skyBlue.withValues(alpha: 0.36) : Colors.transparent),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => update(() => selected = path),
                child: SizedBox(
                  height: 40,
                  child: Row(children: [
                    const SizedBox(width: 10),
                    Icon(isRoot ? Icons.school_outlined : Icons.folder_outlined,
                        size: 17, color: isRoot ? p.adminIndigo : p.skyBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRoot ? _string(_currentSubject?['name']) : path.last,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? p.diamondDust : p.pureWhite,
                          fontWeight: active || isRoot ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (active) Icon(Icons.check_rounded, size: 17, color: p.skyBlue),
                    const SizedBox(width: 10),
                  ]),
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.adminCyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: p.adminCyan.withValues(alpha: 0.24)),
                    ),
                    child: Row(children: [
                      Icon(Icons.shield_outlined, size: 16, color: p.adminCyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Cambia solo la posizione per gli studenti. Su Drive i file restano dove sono.',
                            style: SlText.muted(p).copyWith(color: p.pureWhite.withValues(alpha: 0.80))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: p.eleganceMidnight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
                    ),
                    child: Column(children: [
                      row(const <String>[], isRoot: true),
                      for (final path in folders) row(path, isRoot: false),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newFolder,
                    onChanged: (_) => update(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.create_new_folder_outlined),
                      labelText: 'Nuova sottocartella qui (facoltativa)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: p.eleganceSoftNight, borderRadius: BorderRadius.circular(11)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Nuovo percorso per gli studenti', style: SlText.muted(p)),
                      const SizedBox(height: 3),
                      Text(
                        [_string(_currentSubject?['name']), ...target].join(' / '),
                        style: SlText.mono(p, size: 12, color: p.diamondDust),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: p.adminAmber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Chi ha i file offline li vedrà nella nuova posizione alla prossima sincronizzazione.',
                          style: SlText.muted(p).copyWith(color: p.adminAmber)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
            FilledButton(
              onPressed: target.any((s) => s.isEmpty || s.contains('/'))
                  ? null
                  : () => Navigator.pop(dialogContext, target),
              child: const Text('Aggiungi alla bozza'),
            ),
          ],
        );
      }),
    );
    newFolder.dispose();
    return result;
  }

  Future<void> _stageChange(Map<String, dynamic> item,
      {List<String>? path, String? visibility}) async {
    final current = _effective(item);
    setState(() => _busy = true);
    try {
      await _api.stageCatalogFile(
        materialId: _integer(item['id']),
        subjectId: _integer(current['subject_id']),
        pathSegments: path ?? _path(current['path_segments']),
        visibilityState: visibility ?? _string(current['visibility_state']),
        audienceType: _string(current['audience_type']).isEmpty ? 'public' : _string(current['audience_type']),
        audienceId: current['audience_id'] == null ? null : _integer(current['audience_id']),
      );
      await _reload();
    } catch (e) {
      _showError(_reason(e, 'Modifica non salvata in bozza. Controlla materia, destinatari e percorso.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _moveFile(Map<String, dynamic> item) async {
    final current = _effective(item);
    final target = await _pickFolder(
      title: 'Sposta “${_string(item['title'])}”',
      current: _path(current['path_segments']),
    );
    if (target == null || !mounted) return;
    await _stageChange(item, path: target);
  }

  /// Nome mostrato agli studenti. Su Drive il file mantiene il suo nome.
  /// Si applica subito (non passa dalla bozza), come la rinomina esistente.
  Future<void> _renameFile(Map<String, dynamic> item) async {
    final p = context.palette;
    final controller = TextEditingController(text: _string(item['title']));
    final String? name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: const Text('Rinomina per gli studenti'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 250,
              decoration: const InputDecoration(labelText: 'Nome nelle Dispense'),
            ),
            Text('Su Google Drive il file mantiene il nome ${_string(item['original_name'])}. '
                'Il nuovo nome si applica subito, senza passare dalla bozza.',
                style: SlText.muted(p)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Rinomina'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name == _string(item['title']) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.rename(source: 'public', materialId: _integer(item['id']), displayName: name);
      await _reload();
    } catch (e) {
      _showError(_reason(e, 'Nome non aggiornato. Riprova.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openInDrive(String fileId) async {
    final uri = Uri.parse('https://drive.google.com/file/d/$fileId/view');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Non è stato possibile aprire Google Drive.');
    }
  }

  // ---------------------------------------------------------------------------
  // Colonne
  // ---------------------------------------------------------------------------

  Widget _column({required Widget header, required Widget body, Widget? footer, bool elevated = false}) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: elevated ? p.eleganceDeepNavy : p.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: elevated ? 0.18 : 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
        Expanded(child: body),
        if (footer != null) ...[
          Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
          footer,
        ],
      ]),
    );
  }

  Widget _columnHeader({required IconData icon, required SlTone tone, required String title,
      required String subtitle, List<Widget> trailing = const []}) {
    final p = context.palette;
    return LayoutBuilder(builder: (context, bounds) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SlIconTile(icon: icon, tone: tone, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(subtitle, style: SlText.muted(p).copyWith(fontSize: 11)),
          ])),
          if (bounds.maxWidth >= 620) ...trailing,
        ]),
        if (bounds.maxWidth < 620 && trailing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: trailing),
        ],
      ]),
    ));
  }

  Future<void> _toggleDriveFolder(String id) async {
    if (_driveOpen.contains(id)) {
      setState(() => _driveOpen.remove(id));
      return;
    }
    setState(() => _driveOpen.add(id));
    if (_driveChildren.containsKey(id)) return;
    setState(() => _driveLoading.add(id));
    try {
      final value = await _api.getDriveTree(id);
      if (!mounted) return;
      setState(() => _driveChildren[id] = (value['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList());
    } catch (e) {
      _showError(_reason(e, 'Impossibile aprire questa cartella Drive.'));
      if (mounted) setState(() => _driveOpen.remove(id));
    }
    if (mounted) setState(() => _driveLoading.remove(id));
  }

  /// Righe dell'albero Drive, con le cartelle aperte espanse sul posto.
  List<Widget> _driveTreeRows(List<Map<String, dynamic>> items, int depth, String query, Set<String> draftImports) {
    final p = context.palette;
    final rows = <Widget>[];
    for (final file in items) {
      final String id = _string(file['id']);
      final bool isFolder = file['mime_type'] == _folderMime;
      final bool matches = query.isEmpty || _string(file['name']).toLowerCase().contains(query);
      if (isFolder) {
        final bool open = _driveOpen.contains(id);
        final children = _driveChildren[id] ?? const <Map<String, dynamic>>[];
        final childRows = open ? _driveTreeRows(children, depth + 1, query, draftImports) : const <Widget>[];
        if (!matches && childRows.isEmpty && query.isNotEmpty) continue;
        rows.add(_driveRow(
          depth: depth,
          icon: open ? Icons.folder_open_outlined : Icons.folder_outlined,
          iconColor: p.skyBlue,
          leadingChevron: open ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
          title: _string(file['name']),
          subtitle: file['modified_at'] == null ? null : 'Modificata ${_date(file['modified_at'])}',
          onTap: () => _toggleDriveFolder(id),
          trailing: _driveLoading.contains(id)
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.skyBlue))
              : null,
        ));
        rows.addAll(childRows);
        if (open && children.isEmpty && !_driveLoading.contains(id)) {
          rows.add(Padding(
            padding: EdgeInsets.only(
                left: (30.0 + 16 * (depth + 1)).clamp(30.0, MediaQuery.sizeOf(context).width * 0.25).toDouble(),
                bottom: 6),
            child: Text('Cartella vuota', style: SlText.muted(p).copyWith(fontSize: 11)),
          ));
        }
        continue;
      }
      if (!matches) continue;
      final bool indexed = file['indexed'] == true;
      final bool drafted = draftImports.contains(id);
      final row = _driveRow(
        depth: depth,
        icon: Icons.insert_drive_file_outlined,
        iconColor: indexed ? p.diamondDust : p.pureWhite.withValues(alpha: 0.72),
        title: _string(file['name']),
        subtitle: <String>[
          _bytes(file['size']),
          if (file['modified_at'] != null) _date(file['modified_at']),
          if (_string(file['last_modified_by']).isNotEmpty) _string(file['last_modified_by']),
        ].join(' · '),
        dot: indexed ? _DriveDot.catalog : (drafted ? _DriveDot.draft : _DriveDot.driveOnly),
        onTap: () => showDriveFilePreview(context,
            load: () => _api.downloadDriveFilePreview(id),
            name: _string(file['name']),
            mimeType: _string(file['mime_type'])),
        trailing: !indexed && !drafted
            ? IconButton(
                tooltip: 'Aggiungi alla struttura per gli studenti',
                onPressed: _busy ? null : () => _import(file),
                icon: Icon(Icons.add_circle_outline_rounded, color: p.skyBlue, size: 20),
              )
            : null,
      );
      // I file solo su Drive si possono trascinare in una cartella della struttura.
      rows.add(!indexed && !drafted
          ? Draggable<_DragPayload>(
              data: _DragPayload.drive(file),
              feedback: _dragGhost(_string(file['name']), 'DA DRIVE'),
              childWhenDragging: Opacity(opacity: 0.4, child: row),
              child: row,
            )
          : row);
    }
    return rows;
  }

  Widget _drivePane() {
    final p = context.palette;
    final query = _search.text.trim().toLowerCase();
    final draftImports = _imports.map((e) => _string(e['drive_file_id'])).toSet();
    final rows = _driveTreeRows(_drive, 0, query, draftImports);
    return _column(
      header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _columnHeader(
          icon: Icons.cloud_outlined,
          tone: SlTone.info,
          title: 'Google Drive',
          subtitle: 'Struttura reale, come sul Drive',
          trailing: const [SlStatusBadge(label: 'Sola lettura')],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: p.pureWhite, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              hintText: 'Cerca nelle cartelle aperte',
              fillColor: p.darkElegance,
            ),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        _driveRow(
          depth: 0,
          icon: Icons.folder_open_outlined,
          iconColor: p.skyBlue,
          title: _trail.last.$2,
          subtitle: _trail.length > 1 ? 'Tocca per risalire' : 'Cartella principale di StudentLab',
          bold: true,
          onTap: _trail.length > 1
              ? () {
                  _trail.removeLast();
                  _driveOpen.clear();
                  _loadDrive();
                }
              : () {},
          leadingChevron: _trail.length > 1 ? Icons.arrow_upward_rounded : Icons.keyboard_arrow_down_rounded,
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(query.isEmpty ? 'Cartella vuota.' : 'Nessun file corrisponde alla ricerca.',
                style: SlText.muted(p)),
          ),
        ...rows,
        if (_nextPage != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: SlActionButton(
              icon: Icons.expand_more_rounded,
              label: 'Carica altri file',
              onPressed: _busy ? null : _more,
            ),
          ),
      ]),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _legend(_DriveDot.catalog, 'Nel catalogo e visibile agli studenti'),
          const SizedBox(height: 5),
          _legend(_DriveDot.draft, 'Aggiunto alla bozza, non ancora pubblicato'),
          const SizedBox(height: 5),
          _legend(_DriveDot.driveOnly, 'Solo su Drive · trascinalo nella struttura o usa +'),
        ]),
      ),
    );
  }

  Widget _dot(_DriveDot kind) {
    final p = context.palette;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (kind) {
          _DriveDot.catalog => p.adminGreen,
          _DriveDot.draft => p.adminAmber,
          _DriveDot.driveOnly => Colors.transparent,
        },
        border: kind == _DriveDot.driveOnly
            ? Border.all(color: p.pureWhite.withValues(alpha: 0.45), width: 1.5)
            : null,
      ),
    );
  }

  Widget _legend(_DriveDot kind, String label) {
    final p = context.palette;
    return Row(children: [
      _dot(kind),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: SlText.muted(p).copyWith(fontSize: 11))),
    ]);
  }

  Widget _driveRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    _DriveDot? dot,
    IconData? leadingChevron,
    Widget? trailing,
    bool bold = false,
    int depth = 0,
    required VoidCallback onTap,
  }) {
    final p = context.palette;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              (6.0 + 16 * depth).clamp(6.0, MediaQuery.sizeOf(context).width * 0.25).toDouble(),
              5, 6, 5),
          child: Row(children: [
            SizedBox(
              width: 18,
              child: leadingChevron == null
                  ? null
                  : Icon(leadingChevron, size: 16, color: p.pureWhite.withValues(alpha: 0.56)),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: p.pureWhite, fontSize: 13, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: SlText.mono(p, size: 10, color: p.pureWhite.withValues(alpha: 0.56))),
              ]),
            ),
            if (dot != null) ...[const SizedBox(width: 6), _dot(dot)],
            if (trailing != null) trailing,
          ]),
        ),
      ),
    );
  }

  /// Anteprima che segue il puntatore durante il trascinamento.
  Widget _dragGhost(String title, String tag) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: -0.025,
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: p.brandNightBlue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.adminCyan.withValues(alpha: 0.55)),
          ),
          child: Row(children: [
            Icon(Icons.insert_drive_file_outlined, size: 16, color: p.adminCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Text(tag, style: SlText.mono(p, size: 10, color: p.adminCyan)),
          ]),
        ),
      ),
    );
  }

  /// Rilascio su una cartella della struttura (o sulla materia, path vuoto).
  Future<void> _dropInto(_DragPayload payload, List<String> path) async {
    setState(() => _dropTarget = null);
    if (payload.material != null) {
      final current = _path(_effective(payload.material!)['path_segments']);
      if (current.join('\u0000') == path.join('\u0000')) return;
      await _stageChange(payload.material!, path: path);
    } else if (payload.driveFile != null) {
      await _import(payload.driveFile!, initialPath: path);
    }
  }

  Widget _dropZone({required List<String> path, required Widget child}) {
    final p = context.palette;
    final key = path.join('\u0000');
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (_) {
        if (_dropTarget != key) setState(() => _dropTarget = key);
        return !_busy;
      },
      onLeave: (_) {
        if (_dropTarget == key) setState(() => _dropTarget = null);
      },
      onAcceptWithDetails: (details) => _dropInto(details.data, path),
      builder: (context, candidates, _) {
        final bool active = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: active ? p.adminCyan.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? p.adminCyan.withValues(alpha: 0.55) : Colors.transparent,
            ),
          ),
          child: Stack(children: [
            child,
            if (active)
              Positioned(
                right: 44,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text('Rilascia qui',
                      style: TextStyle(color: p.adminCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _catalogPane() {
    final p = context.palette;
    final subset = _materials
        .where((m) => _integer(_effective(m)['subject_id']) == _subjectId && _string(m['status']) != 'removed')
        .map(_effective)
        .toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final m in subset.where((m) => _showHidden || _string(m['visibility_state']) == 'visible')) {
      groups.putIfAbsent(_path(m['path_segments']).join(' / '), () => []).add(m);
    }
    final keys = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final folderRows = _folders.where((f) => _integer(f['subject_id']) == _subjectId).toList();
    final importRows = _imports.where((f) => _integer(f['subject_id']) == _subjectId).toList();
    final subject = _currentSubject;

    return _column(
      header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _columnHeader(
          icon: Icons.layers_outlined,
          tone: SlTone.violet,
          title: 'Struttura per gli studenti',
          subtitle: 'Come apparirà nelle Dispense, anche offline',
          trailing: [
            SlActionButton(
              icon: Icons.upload_file_rounded,
              label: 'Carica file',
              primary: true,
              onPressed: _busy
                  ? null
                  : () async {
                      final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
                          builder: (_) => AdminMaterialUploadPage(initialSubjectId: _subjectId)));
                      if (done == true && mounted) await _reload();
                    },
            ),
            const SizedBox(width: 8),
            SlActionButton(
              icon: Icons.create_new_folder_outlined,
              label: 'Nuova cartella',
              onPressed: _busy || _subjectId == null ? null : _addFolder,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: LayoutBuilder(builder: (context, bounds) {
            final hint = Text('Trascina un file su una cartella per spostarlo, o usa + per aggiungerlo da Drive.',
                style: SlText.muted(p).copyWith(fontSize: 11));
            final toggle = Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Mostra nascosti', style: SlText.muted(p)),
              Switch(value: _showHidden, onChanged: (value) => setState(() => _showHidden = value)),
            ]);
            return bounds.maxWidth < 450
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [hint, toggle])
                : Row(children: [Expanded(child: hint), toggle]);
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: PopupMenuButton<int>(
            tooltip: 'Materia',
            color: p.eleganceDeepNavy,
            onSelected: (value) => setState(() {
              _subjectId = value;
              _selectedId = null;
            }),
            itemBuilder: (_) => [
              for (final s in _subjects)
                PopupMenuItem<int>(
                  value: _integer(s['id']),
                  child: Text('${s['name']} · ${s['course']}', overflow: TextOverflow.ellipsis),
                ),
            ],
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.darkElegance,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.pureWhite.withValues(alpha: 0.12)),
              ),
              child: Row(children: [
                Text('Materia', style: SlText.muted(p)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject == null ? 'Scegli una materia' : '${subject['name']} · ${subject['course']}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ]),
            ),
          ),
        ),
      ]),
      body: subset.isEmpty && folderRows.isEmpty && importRows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: SlEmptyState(
                icon: Icons.folder_open_outlined,
                title: 'Nessun materiale in questa materia',
                message: 'Aggiungi file dal Drive con il pulsante + oppure crea una cartella.',
                actions: [
                  SlActionButton(
                    icon: Icons.create_new_folder_outlined,
                    label: 'Nuova cartella',
                    onPressed: _busy || _subjectId == null ? null : _addFolder,
                  ),
                ],
              ),
            )
          : ListView(padding: const EdgeInsets.all(10), children: [
              if (subject != null)
                _dropZone(path: const <String>[], child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  child: Row(children: [
                    const SlIconTile(icon: Icons.school_outlined, tone: SlTone.violet, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_string(subject['name']),
                          style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    Text('${subject['course']} · ${subset.length} file',
                        style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56))),
                  ]),
                )),
              for (final key in keys) ...[
                if (key.isNotEmpty) _folderRow(key, groups[key]!, subset),
                for (final material in groups[key]!) _fileRow(material, indent: key.isEmpty ? 1 : 2),
              ],
              for (final folder in folderRows.where(
                  (f) => !groups.containsKey(_path(f['path_segments']).join(' / '))))
                _dropZone(
                  path: _path(folder['path_segments']),
                  child: _simpleRow(
                    icon: Icons.folder_outlined,
                    title: _path(folder['path_segments']).join(' / '),
                    badge: SlStatusBadge(
                      label: folder['draft'] == true ? 'Solo catalogo · in bozza' : 'Solo catalogo · vuota',
                      tone: folder['draft'] == true ? SlTone.warning : SlTone.violet,
                    ),
                  ),
                ),
              for (final file in importRows)
                _simpleRow(
                  icon: Icons.insert_drive_file_outlined,
                  title: _string(file['name']),
                  subtitle: '${_path(file['path_segments']).join(' / ')} · ${_bytes(file['size'])} · da Drive',
                  badge: const SlStatusBadge(label: 'Nuovo', tone: SlTone.warning),
                  onTap: () => showDriveFilePreview(context,
                      load: () => _api.downloadDriveFilePreview(_string(file['drive_file_id'])),
                      name: _string(file['name']),
                      mimeType: _string(file['mime_type'])),
                ),
            ]),
      footer: _draftCount == 0 ? null : _changeLog(),
    );
  }

  Widget _folderRow(String key, List<Map<String, dynamic>> files, List<Map<String, dynamic>> subset) {
    final p = context.palette;
    final parts = key.split(' / ');
    final hidden = files.where((f) => _string(f['visibility_state']) != 'visible').length;
    final allHidden = hidden == files.length;
    final drafted = files.any((f) => f['draft'] == true);
    final bool renamedOrMoved = files.any((f) {
      if (f['draft'] != true) return false;
      final original = _materials.where((m) => _integer(m['id']) == _integer(f['id']));
      return original.isNotEmpty &&
          _path(original.first['path_segments']).join('/') != _path(f['path_segments']).join('/');
    });
    return Padding(
      padding: EdgeInsets.only(left: 14.0 * (parts.length - 1), top: 4, bottom: 2),
      child: _dropZone(
        path: parts,
        child: Opacity(
          opacity: allHidden ? 0.62 : 1,
          child: SizedBox(
            height: 44,
            child: Row(children: [
              const SizedBox(width: 8),
              Icon(allHidden ? Icons.folder_off_outlined : Icons.folder_outlined,
                  size: 18, color: allHidden ? p.pureWhite.withValues(alpha: 0.7) : p.skyBlue),
              const SizedBox(width: 8),
              Flexible(
                child: Text(parts.last,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.pureWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: allHidden ? TextDecoration.lineThrough : null,
                      decorationColor: p.pureWhite.withValues(alpha: 0.4),
                    )),
              ),
              const SizedBox(width: 8),
              if (allHidden)
                SlStatusBadge(label: 'Nascosta · ${files.length} file')
              else if (hidden > 0)
                SlStatusBadge(label: '$hidden nascosti'),
              if (renamedOrMoved) ...[
                const SizedBox(width: 6),
                const SlStatusBadge(label: 'Modificata', tone: SlTone.warning),
              ] else if (drafted) ...[
                const SizedBox(width: 6),
                const SlStatusBadge(label: 'In bozza', tone: SlTone.warning),
              ],
              const Spacer(),
              IconButton(
                tooltip: allHidden ? 'Mostra la cartella agli studenti' : 'Nascondi la cartella agli studenti',
                onPressed: _busy ? null : () => _setFolderVisibility(key, subset, allHidden),
                icon: Icon(allHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18, color: p.pureWhite.withValues(alpha: 0.72)),
              ),
              IconButton(
                tooltip: 'Rinomina o sposta la cartella',
                onPressed: _busy ? null : () => _editFolder(key, subset),
                icon: Icon(Icons.more_horiz_rounded, color: p.pureWhite.withValues(alpha: 0.66)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Nasconde o mostra tutti i file di una cartella (in bozza).
  Future<void> _setFolderVisibility(String key, List<Map<String, dynamic>> subset, bool visible) async {
    final prefix = key.split(' / ');
    setState(() => _busy = true);
    try {
      for (final row in subset) {
        final path = _path(row['path_segments']);
        if (path.length < prefix.length || path.take(prefix.length).join('/') != prefix.join('/')) continue;
        final original = _materials.where((m) => _integer(m['id']) == _integer(row['id']));
        if (original.isEmpty) continue;
        await _api.stageCatalogFile(
          materialId: _integer(row['id']),
          subjectId: _integer(row['subject_id']),
          pathSegments: path,
          visibilityState: visible ? 'visible' : 'hidden',
          audienceType: _string(row['audience_type']).isEmpty ? 'public' : _string(row['audience_type']),
          audienceId: row['audience_id'] == null ? null : _integer(row['audience_id']),
        );
      }
      await _reload();
    } catch (e) {
      _showError(_reason(e, 'Non tutti i file della cartella sono stati aggiornati. Controlla la bozza.'));
      await _reload();
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Cosa cambia per questo file rispetto al catalogo pubblicato.
  List<(String, SlTone)> _changeBadges(Map<String, dynamic> effective) {
    if (effective['draft'] != true) return const [];
    final original = _materials.where((m) => _integer(m['id']) == _integer(effective['id']));
    if (original.isEmpty) return const [('Bozza', SlTone.warning)];
    final before = original.first;
    final badges = <(String, SlTone)>[];
    if (_path(before['path_segments']).join('/') != _path(effective['path_segments']).join('/') ||
        _integer(before['subject_id']) != _integer(effective['subject_id'])) {
      badges.add(('Spostato', SlTone.warning));
    }
    if (_string(before['visibility_state']) != _string(effective['visibility_state'])) {
      badges.add((_string(effective['visibility_state']) == 'visible' ? 'Da mostrare' : 'Da nascondere', SlTone.warning));
    }
    if (_string(before['audience_type']) != _string(effective['audience_type'])) {
      badges.add(('Destinatari', SlTone.warning));
    }
    return badges.isEmpty ? const [('Bozza', SlTone.warning)] : badges;
  }

  Widget _fileRow(Map<String, dynamic> material, {required int indent}) {
    final p = context.palette;
    final id = _integer(material['id']);
    final bool selected = id == _selectedId;
    final state = _string(material['visibility_state']);
    final (visLabel, visTone) = _visibilityBadge(state);
    final (audLabel, audTone) = _audienceBadge(_string(material['audience_type']));
    final bool hidden = state != 'visible';
    final drivePath = _path(material['drive_path_segments']);
    final original = _materials.where((m) => _integer(m['id']) == id);
    final row = Padding(
      padding: EdgeInsets.only(left: 14.0 * indent, bottom: 4),
      child: Material(
        color: selected ? p.skyBlue.withValues(alpha: 0.10) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? p.skyBlue.withValues(alpha: 0.34) : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _selectedId = id;
            _compactPane = 2;
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(children: [
              Icon(Icons.drag_indicator_rounded, size: 16, color: p.pureWhite.withValues(alpha: 0.40)),
              const SizedBox(width: 4),
              SlFileTile(kind: slFileKind(_string(material['mime_type']), _string(material['original_name'])), size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: hidden ? 0.7 : 1,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_string(material['title']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      <String>[
                        _string(material['original_name']),
                        _bytes(material['size']),
                        if (_string(material['uploader_name']).isNotEmpty) _string(material['uploader_name']),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SlText.mono(p, size: 10, color: p.pureWhite.withValues(alpha: 0.56)),
                    ),
                    if (drivePath.isNotEmpty)
                      Text('↳ su Drive: ${drivePath.join(' / ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SlText.mono(p, size: 10, color: p.pureWhite.withValues(alpha: 0.50))),
                    const SizedBox(height: 4),
                    Wrap(spacing: 5, runSpacing: 4, children: [
                      SlStatusBadge(label: visLabel, tone: visTone),
                      SlStatusBadge(label: audLabel, tone: audTone),
                      for (final (label, tone) in _changeBadges(material)) SlStatusBadge(label: label, tone: tone),
                    ]),
                  ]),
                ),
              ),
              IconButton(
                tooltip: hidden ? 'Mostra agli studenti' : 'Nascondi agli studenti',
                onPressed: _busy || original.isEmpty
                    ? null
                    : () => _stageChange(original.first, visibility: hidden ? 'visible' : 'hidden'),
                icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18, color: p.pureWhite.withValues(alpha: 0.72)),
              ),
            ]),
          ),
        ),
      ),
    );
    if (original.isEmpty) return row;
    return Draggable<_DragPayload>(
      data: _DragPayload.material(original.first),
      feedback: _dragGhost(_string(material['title']), 'SPOSTA'),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );
  }

  Widget _simpleRow({required IconData icon, required String title, String? subtitle,
      required Widget badge, VoidCallback? onTap}) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 8, 8),
        child: Row(children: [
          Icon(icon, size: 17, color: p.adminAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
              if (subtitle != null) Text(subtitle, style: SlText.muted(p).copyWith(fontSize: 11)),
            ]),
          ),
          badge,
        ]),
      ),
    );
  }

  /// Registro della bozza: cosa cambierà alla pubblicazione.
  Widget _changeLog() {
    final p = context.palette;
    final lines = <(String, String)>[];
    for (final d in _draft) {
      final matches = _materials.where((m) => _integer(m['id']) == _integer(d['material_id']));
      final before = matches.isEmpty ? null : matches.first;
      final name = before == null ? 'File ${d['material_id']}' : _string(before['title']);
      final pathBefore = before == null ? '' : _path(before['path_segments']).join(' / ');
      final pathAfter = _path(d['path_segments']).join(' / ');
      if (before != null && pathBefore != pathAfter) {
        lines.add(('SPOSTA', '“$name” → ${pathAfter.isEmpty ? 'materia' : pathAfter}'));
      }
      if (before != null && _string(before['visibility_state']) != _string(d['visibility_state'])) {
        lines.add((_string(d['visibility_state']) == 'visible' ? 'MOSTRA' : 'NASCONDI', '“$name”'));
      }
      if (before != null && _string(before['audience_type']) != _string(d['audience_type'])) {
        lines.add(('DESTINATARI', '“$name”: ${_audienceLabel(_string(d['audience_type']))}'));
      }
      if (before != null && _integer(before['subject_id']) != _integer(d['subject_id'])) {
        lines.add(('MATERIA', '“$name” cambia materia'));
      }
    }
    for (final i in _imports) {
      lines.add(('AGGIUNGI', '“${_string(i['name'])}” in ${_path(i['path_segments']).join(' / ').isEmpty ? 'materia' : _path(i['path_segments']).join(' / ')}'));
    }
    for (final f in _folders.where((f) => f['draft'] == true)) {
      lines.add(('CARTELLA', _path(f['path_segments']).join(' / ')));
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      color: p.eleganceSoftNight,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        children: [
          Text('BOZZA · $_draftCount MODIFICHE',
              style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56))),
          const SizedBox(height: 6),
          for (final (kind, text) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 92, child: Text(kind, style: SlText.mono(p, size: 11, color: p.adminAmber))),
                Expanded(child: Text(text, style: SlText.body(p).copyWith(fontSize: 12))),
              ]),
            ),
          Text('Per annullare usa “Scarta bozza”.', style: SlText.muted(p).copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _detailsPane() {
    final p = context.palette;
    final matches = _materials.where((m) => _integer(m['id']) == _selectedId);
    if (matches.isEmpty) {
      return _column(
        elevated: true,
        header: _columnHeader(
            icon: Icons.description_outlined, tone: SlTone.info, title: 'Dettaglio', subtitle: 'File selezionato'),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SlEmptyState(
            icon: Icons.touch_app_outlined,
            title: 'Nessun file selezionato',
            message: 'Scegli un file nella struttura per vederne provenienza, posizione e visibilità.',
          ),
        ),
      );
    }
    final original = matches.first;
    final row = _effective(original);
    final id = _integer(row['id']);
    final state = _string(row['visibility_state']);
    final (visLabel, visTone) = _visibilityBadge(state);
    final drivePath = _path(row['drive_path_segments']);
    final catalogPath = _path(row['path_segments']);
    final driveId = _string(row['drive_file_id']).isNotEmpty
        ? _string(row['drive_file_id'])
        : (_string(row['stored_name']).startsWith('drive-import/')
            ? _string(row['stored_name']).substring('drive-import/'.length)
            : '');

    Widget section(String label, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SlOverline(label),
            const SizedBox(height: 6),
            ...children,
          ]),
        );

    return _column(
      elevated: true,
      header: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SlFileTile(kind: slFileKind(_string(row['mime_type']), _string(row['original_name'])), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_string(row['title']),
                  style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(_string(row['original_name']), style: SlText.mono(p, size: 11)),
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 4, children: [
                SlStatusBadge(label: visLabel, tone: visTone),
                SlStatusBadge(
                  label: row['draft'] == true ? 'In bozza' : 'Nel catalogo',
                  tone: row['draft'] == true ? SlTone.warning : SlTone.cyan,
                ),
              ]),
            ]),
          ),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          SlActionButton(
            icon: Icons.visibility_outlined,
            label: 'Anteprima',
            primary: true,
            onPressed: () => showDriveFilePreview(context,
                load: () => _api.downloadPublicMaterialPreview(id),
                name: _string(row['original_name']),
                mimeType: _string(row['mime_type'])),
          ),
          if (driveId.isNotEmpty)
            SlActionButton(
              icon: Icons.open_in_new_rounded,
              label: 'Apri su Drive',
              onPressed: () => _openInDrive(driveId),
            ),
        ]),
        const SizedBox(height: 16),
        section('Provenienza', [
          SlKeyValue(
            label: 'Caricato da',
            value: _string(row['uploader_name']).isNotEmpty
                ? _string(row['uploader_name'])
                : (driveId.isNotEmpty ? 'Importato da Google Drive' : '—'),
          ),
          if (_string(row['contributor_mode']) == 'anonymous' && _string(row['uploader_name']).isNotEmpty)
            const SlKeyValue(label: 'Pubblicazione', value: 'Anonima per gli studenti'),
          SlKeyValue(
            label: 'Approvato',
            value: [
              if (_string(row['approver_name']).isNotEmpty) _string(row['approver_name']),
              if (row['approved_at'] != null) _date(row['approved_at']),
            ].join(' · ').isEmpty
                ? '—'
                : [
                    if (_string(row['approver_name']).isNotEmpty) _string(row['approver_name']),
                    if (row['approved_at'] != null) _date(row['approved_at']),
                  ].join(' · '),
          ),
          SlKeyValue(label: 'Ultima modifica', value: _date(row['updated_at'])),
        ]),
        section('File', [
          SlKeyValue(label: 'Tipo', value: _string(row['mime_type']).isEmpty ? '—' : _string(row['mime_type']), mono: true),
          SlKeyValue(label: 'Dimensione', value: _bytes(row['size']), mono: true),
          if (driveId.isNotEmpty)
            Row(children: [
              Expanded(child: SlKeyValue(label: 'ID Drive', value: _short(driveId), mono: true)),
              IconButton(
                tooltip: 'Copia ID Drive',
                onPressed: () => Clipboard.setData(ClipboardData(text: driveId)),
                icon: Icon(Icons.copy_rounded, size: 16, color: p.skyBlue),
              ),
            ]),
          if (_string(row['file_hash']).isNotEmpty)
            SlKeyValue(label: 'SHA-256', value: _short(row['file_hash']), mono: true),
        ]),
        section('Posizione', [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Su Google Drive · invariata', style: SlText.muted(p).copyWith(fontSize: 11)),
              Text(drivePath.isEmpty ? 'Posizione originaria del file' : drivePath.join(' / '),
                  style: SlText.mono(p, size: 12, color: p.pureWhite)),
              const SizedBox(height: 8),
              Divider(height: 1, color: p.pureWhite.withValues(alpha: 0.07)),
              const SizedBox(height: 8),
              Text('Per gli studenti', style: SlText.muted(p).copyWith(fontSize: 11, color: p.diamondDust)),
              Text(
                [_string(_currentSubject?['name']), ...catalogPath].where((s) => s.isNotEmpty).join(' / '),
                style: SlText.mono(p, size: 12, color: p.diamondDust),
              ),
            ]),
          ),
        ]),
        section('Visibilità', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state == 'visible',
            onChanged: _busy ? null : (value) => _stageChange(original, visibility: value ? 'visible' : 'hidden'),
            title: Text('Visibile agli studenti', style: SlText.body(p)),
            subtitle: state == 'visible' || state == 'hidden'
                ? null
                : Text('Stato attuale: $visLabel', style: SlText.muted(p)),
          ),
          SlKeyValue(label: 'Destinatari', value: _audienceLabel(_string(row['audience_type']))),
          SlKeyValue(
            label: 'Offline',
            value: state == 'visible'
                ? 'Sì, per chi può vederlo'
                : 'No: non arriva nelle Dispense finché è ${visLabel.toLowerCase()}',
          ),
          const SizedBox(height: 6),
          SlActionButton(
            icon: Icons.tune_rounded,
            label: 'Materia, destinatari e stato',
            onPressed: _busy ? null : () => _stage(original),
          ),
        ]),
      ]),
      footer: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, bounds) {
          final actions = <Widget>[
            SlActionButton(
              icon: Icons.drive_file_move_outline,
              label: 'Sposta in…',
              onPressed: _busy ? null : () => _moveFile(original),
            ),
            SlActionButton(
              icon: Icons.edit_outlined,
              label: 'Rinomina',
              onPressed: _busy ? null : () => _renameFile(original),
            ),
            SlActionButton(
              icon: state == 'visible' ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              label: state == 'visible' ? 'Nascondi' : 'Mostra',
              onPressed: _busy
                  ? null
                  : () => _stageChange(original, visibility: state == 'visible' ? 'hidden' : 'visible'),
            ),
          ];
          return bounds.maxWidth < 570
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8), actions[i],
                  ],
                ])
              : Row(children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8), Expanded(child: actions[i]),
                  ],
                ]);
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Anteprima "Visualizza come"
  // ---------------------------------------------------------------------------

  Widget _viewAsPane() {
    final p = context.palette;
    final items = (_preview?['files'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final visible = items.where((e) => e['allowed'] == true).length;
    final driveFiles = _drive.where((e) => e['mime_type'] != _folderMime).length;
    Widget option({required bool selected, required String title, String? subtitle, required VoidCallback onTap}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SlChoiceTile(title: title, description: subtitle, selected: selected, onTap: onTap),
      );
    }

    Widget stat(String label, String value, {bool accent = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.eleganceSoftNight, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: SlText.muted(p).copyWith(fontSize: 11, color: accent ? p.diamondDust : null)),
              const SizedBox(height: 4),
              Text(value,
                  style: SlText.mono(p, size: 20, color: accent ? p.diamondDust : p.pureWhite, weight: FontWeight.w700)),
            ]),
          ),
        );

    return _column(
      header: _columnHeader(
        icon: Icons.person_search_outlined,
        tone: SlTone.info,
        title: 'Visualizza come',
        subtitle: 'Permessi calcolati dal server, incluse le bozze',
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        option(
          selected: _viewerId == null,
          title: 'Ospite non registrato',
          subtitle: 'Vede solo i file per “Tutti, anche guest”',
          onTap: () {
            setState(() => _viewerId = null);
            _loadPreview();
          },
        ),
        option(
          selected: _viewerId != null,
          title: _viewerId == null ? 'Studente specifico…' : 'Studente $_viewerId',
          subtitle: 'Indica l’ID di uno studente per vedere esattamente cosa vede lui',
          onTap: _setViewer,
        ),
        const SizedBox(height: 14),
        const SlOverline('Drive e studenti a confronto'),
        const SizedBox(height: 8),
        Row(children: [
          stat('File in questa cartella Drive', '$driveFiles'),
          const SizedBox(width: 8),
          stat('File visibili', '$visible', accent: true),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          stat('File nel catalogo', '${items.length}'),
          const SizedBox(width: 8),
          stat('Esclusi per questo profilo', '${items.length - visible}'),
        ]),
      ]),
    );
  }

  Widget _phonePane() {
    final p = context.palette;
    final items = (_preview?['files'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => e['allowed'] == true && _integer(e['subject_id']) == _subjectId)
        .toList();
    final folders = <String, int>{};
    final rootFiles = <Map<String, dynamic>>[];
    for (final file in items) {
      final path = _path(file['path_segments']);
      if (path.isEmpty) {
        rootFiles.add(file);
      } else {
        folders[path.first] = (folders[path.first] ?? 0) + 1;
      }
    }
    final subject = _currentSubject;
    return Column(children: [
      Text('SEZIONE MATERIALE · COME LA VEDE ${_viewerId == null ? 'UN OSPITE' : 'LO STUDENTE $_viewerId'}',
          style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56))),
      const SizedBox(height: 10),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 390 / 780,
            child: Container(
              decoration: BoxDecoration(
                color: p.darkElegance,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: p.skyBlue.withValues(alpha: 0.26)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 16),
                Container(
                  height: 50,
                  color: p.eleganceMidnight,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  child: Text('Dispense',
                      style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (_draftCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    color: p.adminAmber.withValues(alpha: 0.14),
                    alignment: Alignment.center,
                    child: Text('ANTEPRIMA · INCLUDE LA BOZZA NON PUBBLICATA',
                        style: SlText.mono(p, size: 9, color: p.adminAmber, weight: FontWeight.w700)),
                  ),
                Expanded(
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.eleganceDeepNavy,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.skyBlue.withValues(alpha: 0.14)),
                      ),
                      child: Row(children: [
                        const SlIconTile(icon: Icons.school_outlined, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_string(subject?['name']),
                                style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
                            Text('${_string(subject?['course'])} · ${items.length} file',
                                style: SlText.muted(p).copyWith(fontSize: 11)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Nessun file di questa materia è visibile a questo profilo.',
                            textAlign: TextAlign.center, style: SlText.muted(p)),
                      ),
                    for (final entry in folders.entries)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const SlIconTile(icon: Icons.folder_outlined, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(entry.key,
                                  style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${entry.value} file', style: SlText.muted(p).copyWith(fontSize: 11)),
                            ]),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 18, color: p.pureWhite.withValues(alpha: 0.4)),
                        ]),
                      ),
                    for (final file in rootFiles)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const SlFileTile(kind: 'FILE', size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_string(file['title']),
                                style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          if (file['draft'] == true) const SlStatusBadge(label: 'Bozza', tone: SlTone.warning),
                        ]),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _excludedPane() {
    final p = context.palette;
    final items = (_preview?['files'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => e['allowed'] != true && _integer(e['subject_id']) == _subjectId)
        .toList();
    return _column(
      header: _columnHeader(
        icon: Icons.visibility_off_outlined,
        tone: SlTone.neutral,
        title: 'Non visibile a questo profilo',
        subtitle: 'Nella materia selezionata',
      ),
      body: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Tutti i file della materia sono visibili a questo profilo.', style: SlText.muted(p)),
            )
          : ListView(padding: const EdgeInsets.all(10), children: [
              for (final file in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(
                      _string(file['visibility_state']) == 'visible'
                          ? Icons.lock_outline_rounded
                          : Icons.visibility_off_outlined,
                      size: 16,
                      color: p.pureWhite.withValues(alpha: 0.66),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_string(file['title']), style: SlText.body(p).copyWith(color: p.pureWhite)),
                        Text(_path(file['path_segments']).join(' / '), style: SlText.muted(p).copyWith(fontSize: 11)),
                      ]),
                    ),
                    SlStatusBadge(
                      label: _string(file['visibility_state']) == 'visible'
                          ? _audienceBadge(_string(file['audience_type'])).$1
                          : _visibilityBadge(_string(file['visibility_state'])).$1,
                      tone: _string(file['visibility_state']) == 'visible' ? SlTone.private : SlTone.neutral,
                    ),
                  ]),
                ),
            ]),
      footer: Padding(
        padding: const EdgeInsets.all(12),
        child: SlActionButton(
          icon: Icons.layers_outlined,
          label: 'Torna alla struttura',
          primary: true,
          onPressed: () => setState(() => _previewMode = false),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pagina
  // ---------------------------------------------------------------------------

  Widget _draftBar(bool wide) {
    final p = context.palette;
    final notice = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.shield_outlined, size: 18, color: p.adminCyan),
      const SizedBox(width: 10),
      Flexible(
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Le modifiche riguardano solo il catalogo StudentLab. ',
              style: TextStyle(color: p.pureWhite.withValues(alpha: 0.80))),
          TextSpan(text: 'Cartelle e file su Google Drive restano invariati.',
              style: TextStyle(color: p.adminCyan, fontWeight: FontWeight.w600)),
        ]), style: const TextStyle(fontSize: 13)),
      ),
    ]);
    final actions = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (_draftCount > 0) SlStatusBadge(label: '$_draftCount modifiche in bozza', tone: SlTone.warning),
      OutlinedButton(
        onPressed: _draftCount == 0 || _busy ? null : _discard,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.pureWhite.withValues(alpha: 0.86),
          minimumSize: const Size(0, 40),
          side: BorderSide(color: p.pureWhite.withValues(alpha: 0.14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Scarta bozza'),
      ),
      FilledButton(
        onPressed: _draftCount == 0 || _busy ? null : _publish,
        style: FilledButton.styleFrom(
          backgroundColor: p.skyBlue,
          foregroundColor: p.darkElegance,
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: _busy
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
            : const Text('Pubblica struttura'),
      ),
    ]);
    return Container(
      margin: EdgeInsets.fromLTRB(wide ? 24 : 12, 14, wide ? 24 : 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: p.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.adminCyan.withValues(alpha: 0.24)),
      ),
      child: wide
          ? Row(children: [Expanded(child: notice), const SizedBox(width: 12), actions])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [notice, const SizedBox(height: 10), actions]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: slAdminAppBar(context, title: 'Catalogo Drive', actions: [
        IconButton(
          onPressed: _busy ? null : _reload,
          tooltip: 'Aggiorna da Drive',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ]),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: p.skyBlue))
          : LayoutBuilder(builder: (context, box) {
              final bool wide = box.maxWidth >= 1100;
              final modeBar = SlFilterBar<bool>(
                selected: _previewMode,
                options: const [
                  SlFilterOption(value: false, label: 'Struttura'),
                  SlFilterOption(value: true, label: 'Anteprima studente'),
                ],
                onSelected: (value) {
                  setState(() { _previewMode = value; _compactPane = 0; });
                  if (value) _loadPreview();
                },
              );
              final Widget content;
              if (wide) {
                content = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: _previewMode
                    ? [
                        SizedBox(width: 340, child: _viewAsPane()),
                        const SizedBox(width: 16),
                        Expanded(child: _phonePane()),
                        const SizedBox(width: 16),
                        SizedBox(width: 360, child: _excludedPane()),
                      ]
                    : [
                        SizedBox(width: 340, child: _drivePane()),
                        const SizedBox(width: 16),
                        Expanded(child: _catalogPane()),
                        const SizedBox(width: 16),
                        SizedBox(width: 380, child: _detailsPane()),
                      ]);
              } else {
                final panes = _previewMode
                    ? [_viewAsPane(), _phonePane(), _excludedPane()]
                    : [_drivePane(), _catalogPane(), _detailsPane()];
                final labels = _previewMode
                    ? const ['Profilo', 'Anteprima', 'Esclusi']
                    : const ['Drive', 'Struttura', 'Dettaglio'];
                content = Column(children: [
                  SlFilterBar<int>(
                    selected: _compactPane,
                    options: [
                      for (var i = 0; i < 3; i++) SlFilterOption(value: i, label: labels[i]),
                    ],
                    onSelected: (value) => setState(() => _compactPane = value),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: panes[_compactPane < 0 ? 0 : (_compactPane > 2 ? 2 : _compactPane)]),
                ]);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 12, wide ? 24 : 12, 0),
                  child: Align(alignment: Alignment.centerRight, child: modeBar),
                ),
                _draftBar(wide),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 12, wide ? 24 : 12, 0),
                    child: Stack(children: [
                      SlErrorCard(title: 'Operazione non completata', message: _error!),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          tooltip: 'Chiudi',
                          onPressed: () => setState(() => _error = null),
                          icon: Icon(Icons.close_rounded, size: 18, color: p.pureWhite.withValues(alpha: 0.66)),
                        ),
                      ),
                    ]),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 14, wide ? 24 : 12, wide ? 24 : 12),
                    child: content,
                  ),
                ),
              ]);
            }),
    );
  }
}

enum _DriveDot { catalog, draft, driveOnly }

/// Elemento trascinato: un file del catalogo oppure un file di Drive.
class _DragPayload {
  final Map<String, dynamic>? material;
  final Map<String, dynamic>? driveFile;

  const _DragPayload.material(Map<String, dynamic> value)
      : material = value,
        driveFile = null;

  const _DragPayload.drive(Map<String, dynamic> value)
      : material = null,
        driveFile = value;
}
