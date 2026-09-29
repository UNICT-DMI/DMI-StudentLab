import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../social/admin/admin_material_storage_api_service.dart';
import '../../theme/app_palette.dart';
import '../../widgets/studentlab_ui/studentlab_ui.dart';

/// "Carica materiale" (canvas: Gestione materiali admin).
///
/// Il file passa dallo stesso flusso delle proposte (verifica SHA-256 lato
/// server, controllo duplicati, copia su Drive), poi viene pubblicato subito
/// con posizione, destinatari e visibilità scelti qui.
class AdminMaterialUploadPage extends StatefulWidget {
  /// Materia già scelta (es. dal Catalogo Drive).
  final int? initialSubjectId;

  /// Richiesta degli studenti a StudentLab da chiudere con questo file.
  final Map<String, dynamic>? answerRequest;

  const AdminMaterialUploadPage({super.key, this.initialSubjectId, this.answerRequest});

  @override
  State<AdminMaterialUploadPage> createState() => _AdminMaterialUploadPageState();
}

enum _Destination { dispense, driveOnly, answer }

class _AdminMaterialUploadPageState extends State<AdminMaterialUploadPage> {
  static const double _wideBreakpoint = 1000;

  final ApiService _api = ApiService();
  final AdminMaterialStorageApiService _storage = AdminMaterialStorageApiService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _newFolder = TextEditingController();
  final TextEditingController _audienceId = TextEditingController();
  final TextEditingController _answerMessage = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _progress;
  Map<String, dynamic>? _done;

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _openRequests = [];

  Uint8List? _bytes;
  String? _fileName;
  _Destination _destination = _Destination.dispense;
  int? _subjectId;
  List<String> _folder = const <String>[];
  String _audience = 'course';
  int? _answerRequestId;

  @override
  void initState() {
    super.initState();
    if (widget.answerRequest != null) {
      _destination = _Destination.answer;
      _answerRequestId = int.tryParse('${widget.answerRequest!['id']}');
      _subjectId = int.tryParse('${widget.answerRequest!['subject_id']}');
    }
    _subjectId ??= widget.initialSubjectId;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _newFolder.dispose();
    _audienceId.dispose();
    _answerMessage.dispose();
    super.dispose();
  }

  int _int(Object? value) => int.tryParse('$value') ?? 0;
  List<String> _path(Object? value) => value is List ? value.map((e) => '$e').toList() : const [];

  String _reason(Object error, String fallback) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty || text.length > 220 || text.contains('<') || text.startsWith('Bad state')) {
      return slErrorMessage(error, fallback: fallback);
    }
    return text.contains('"detail"') ? slErrorMessage(error, fallback: fallback) : text;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _storage.getDriveImportOptions(),
        _storage.getItems(source: 'public'),
        _api.getStudentLabMaterialRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _subjects = (results[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _materials = (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _openRequests = (results[2] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((r) => (r['status']?.toString() ?? 'pending') == 'pending')
            .toList();
        if (_subjectId == null && _subjects.isNotEmpty) _subjectId = _int(_subjects.first['id']);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _reason(e, 'Non è stato possibile caricare materie e cartelle. Riprova.');
        });
      }
    }
  }

  Map<String, dynamic>? get _subject {
    final match = _subjects.where((s) => _int(s['id']) == _subjectId);
    return match.isEmpty ? null : match.first;
  }

  /// Cartelle già usate nella materia (per la scelta della posizione).
  List<List<String>> get _folders {
    final seen = <String>{};
    final result = <List<String>>[];
    for (final m in _materials.where((m) => _int(m['subject_id']) == _subjectId && m['status'] != 'removed')) {
      final path = _path(m['path_segments']);
      for (var i = 1; i <= path.length; i++) {
        final prefix = path.take(i).toList();
        if (seen.add(prefix.join('\u0000'))) result.add(prefix);
      }
    }
    result.sort((a, b) => a.join(' / ').toLowerCase().compareTo(b.join(' / ').toLowerCase()));
    return result;
  }

  List<String> get _targetPath => [
        ..._folder,
        if (_newFolder.text.trim().isNotEmpty) _newFolder.text.trim(),
      ];

  List<Map<String, dynamic>> get _requestsForSubject =>
      _openRequests.where((r) => _int(r['subject_id']) == _subjectId).toList();

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'md', 'zip', 'docx', 'pptx', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) {
      setState(() => _error = 'Il contenuto del file non è disponibile. Riprova a sceglierlo.');
      return;
    }
    setState(() {
      _bytes = file.bytes;
      _fileName = file.name;
      _error = null;
      if (_title.text.trim().isEmpty) {
        final dot = file.name.lastIndexOf('.');
        _title.text = (dot > 0 ? file.name.substring(0, dot) : file.name).replaceAll('_', ' ');
      }
    });
  }

  Future<Map<String, dynamic>> _duplicateDecision(Map<String, dynamic> duplicate) async {
    final bool exact = duplicate['exact'] == true;
    final p = context.palette;
    final String? choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: Text(exact ? 'File già su StudentLab' : 'Esiste un materiale simile'),
        content: Text(
          '${duplicate['title'] ?? 'Materiale esistente'}'
          '${duplicate['path_segments'] is List && (duplicate['path_segments'] as List).isNotEmpty ? '\n${(duplicate['path_segments'] as List).join(' › ')}' : ''}'
          '\n\n${exact ? 'Il contenuto è identico: non serve caricarlo di nuovo.' : 'Controlla che non sia lo stesso file prima di continuare.'}',
          style: SlText.body(p),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'cancel'), child: const Text('Annulla')),
          if (!exact)
            FilledButton(onPressed: () => Navigator.pop(dialogContext, 'separate'), child: const Text('Carica comunque')),
        ],
      ),
    );
    return <String, dynamic>{'decision': choice ?? 'cancel'};
  }

  /// Carica, pubblica e (se richiesto) mette in bozza o chiude la richiesta.
  Future<void> _submit({required bool asDraft}) async {
    final subject = _subject;
    final bytes = _bytes;
    final name = _fileName;
    if (subject == null || bytes == null || name == null) {
      setState(() => _error = 'Scegli il file e la materia.');
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Scrivi il titolo che vedranno gli studenti.');
      return;
    }
    final int? audienceId = (_audience == 'group' || _audience == 'user') ? int.tryParse(_audienceId.text.trim()) : null;
    if ((_audience == 'group' || _audience == 'user') && (audienceId == null || audienceId <= 0)) {
      setState(() => _error = _audience == 'group' ? 'Indica l’ID del gruppo.' : 'Indica l’ID dello studente.');
      return;
    }
    if (_destination == _Destination.answer && _answerRequestId == null) {
      setState(() => _error = 'Scegli la richiesta da chiudere.');
      return;
    }
    final path = _targetPath;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 'Caricamento e verifica del file…';
    });
    int? proposalId;
    try {
      final upload = await _api.uploadMaterialPublicationBytes(
        subjectId: _int(subject['id']),
        title: _title.text.trim(),
        description: 'Caricato da StudentLab',
        bytes: bytes,
        originalName: name,
        attributionMode: 'anonymous',
        onDuplicateDecision: _duplicateDecision,
      );
      if (upload['cancelled'] == true) {
        setState(() {
          _busy = false;
          _progress = null;
        });
        return;
      }
      proposalId = _int(upload['id']);
      if (!mounted) return;
      setState(() => _progress = 'Pubblicazione e copia su Drive…');
      final bool hidden = _destination == _Destination.driveOnly || asDraft;
      final result = await _storage.publishAdminUpload(
        requestId: proposalId,
        destination: hidden ? 'drive_only' : 'dispense',
        pathSegments: path,
        audienceType: _audience,
        audienceId: audienceId,
        title: _title.text.trim(),
        answerRequestId: _destination == _Destination.answer ? _answerRequestId : null,
        answerMessage: _destination == _Destination.answer ? _answerMessage.text : null,
      );
      String? draftNote;
      if (asDraft && _destination != _Destination.driveOnly) {
        try {
          await _storage.stageCatalogFile(
            materialId: _int(result['material_id']),
            subjectId: _int(subject['id']),
            pathSegments: path,
            visibilityState: 'visible',
            audienceType: _audience,
            audienceId: audienceId,
          );
        } catch (e) {
          draftNote = _reason(e, 'Non è stato possibile metterlo in bozza: rendilo visibile dal Catalogo Drive.');
        }
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _done = {...result, 'draft': asDraft, 'draft_note': draftNote};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _error = proposalId == null
            ? _reason(e, 'Caricamento non riuscito. Riprova.')
            : '${_reason(e, 'Pubblicazione non riuscita.')} Il file è stato caricato: lo trovi in Esamina proposte.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _panel(List<Widget> children, {bool elevated = false}) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: elevated ? p.eleganceDeepNavy : p.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: elevated ? 0.18 : 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _step(int n, String label, {required bool active, required bool done}) {
    final p = context.palette;
    final Color c = active ? p.skyBlue : (done ? p.adminGreen : p.pureWhite.withValues(alpha: 0.4));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active || done ? c : Colors.transparent,
          border: active || done ? null : Border.all(color: c, width: 1.5),
        ),
        child: done
            ? Icon(Icons.check_rounded, size: 14, color: p.darkElegance)
            : Text('$n', style: SlText.mono(p, size: 11, color: active ? p.darkElegance : c, weight: FontWeight.w700)),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              color: active || done ? p.pureWhite : p.pureWhite.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
    ]);
  }

  Widget _stepper() {
    final bool file = _bytes != null;
    final bool where = file && _subject != null;
    final bool who = where;
    final List<(String, bool, bool)> steps = [
      ('File', !file, file),
      ('Dove va', file && !where, where),
      ('Chi lo vede', where && !who, who),
      ('Conferma', who, false),
    ];
    final p = context.palette;
    return Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0) Container(width: 36, height: 1, color: p.pureWhite.withValues(alpha: 0.14)),
        _step(i + 1, steps[i].$1, active: steps[i].$2, done: steps[i].$3),
      ],
    ]);
  }

  Widget _fileSection() {
    final p = context.palette;
    if (_bytes == null) {
      return _panel([
        const SlOverline('File'),
        const SizedBox(height: 10),
        InkWell(
          onTap: _busy ? null : _pickFile,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.skyBlue.withValues(alpha: 0.35)),
              color: p.skyBlue.withValues(alpha: 0.04),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.upload_file_rounded, color: p.skyBlue, size: 28),
              const SizedBox(height: 8),
              Text('Scegli il file da caricare', style: TextStyle(color: p.diamondDust, fontWeight: FontWeight.w600)),
              Text('PDF, documenti, presentazioni, immagini o ZIP', style: SlText.muted(p)),
            ]),
          ),
        ),
      ]);
    }
    return _panel([
      Row(children: [
        SlFileTile(kind: slFileKind(null, _fileName), size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fileName!, style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w600)),
            Text('${_size(_bytes!.length)} · verifica SHA-256 e duplicati al caricamento',
                style: SlText.mono(p, size: 11)),
          ]),
        ),
        const SlStatusBadge(label: 'Pronto', tone: SlTone.success),
        const SizedBox(width: 8),
        SlActionButton(icon: Icons.swap_horiz_rounded, label: 'Cambia file', onPressed: _busy ? null : _pickFile),
      ]),
    ]);
  }

  Widget _destinationSection() {
    final requests = _requestsForSubject;
    return _panel([
      const SlOverline('Destinazione'),
      const SizedBox(height: 10),
      SlChoiceTile(
        title: 'Nelle Dispense degli studenti',
        description: 'Pubblicato nel catalogo, con copia su Google Drive',
        selected: _destination == _Destination.dispense,
        onTap: () => setState(() => _destination = _Destination.dispense),
      ),
      const SizedBox(height: 6),
      SlChoiceTile(
        title: 'Solo su Google Drive',
        description: 'Caricato su Drive e registrato come nascosto: non arriva agli studenti finché non lo mostri dal Catalogo Drive',
        selected: _destination == _Destination.driveOnly,
        onTap: () => setState(() => _destination = _Destination.driveOnly),
      ),
      const SizedBox(height: 6),
      SlChoiceTile(
        title: 'Rispondi a una richiesta',
        description: 'Come la prima, e in più chiude la richiesta avvisando chi l’ha fatta',
        selected: _destination == _Destination.answer,
        onTap: () => setState(() => _destination = _Destination.answer),
      ),
      if (_destination == _Destination.answer) ...[
        const SizedBox(height: 10),
        if (requests.isEmpty)
          Text('Nessuna richiesta aperta per questa materia.', style: SlText.muted(context.palette))
        else
          DropdownButtonFormField<int>(
            value: requests.any((r) => _int(r['id']) == _answerRequestId) ? _answerRequestId : null,
            decoration: const InputDecoration(labelText: 'Richiesta da chiudere'),
            items: [
              for (final r in requests)
                DropdownMenuItem<int>(
                  value: _int(r['id']),
                  child: Text(
                    '${(r['topic']?.toString().trim().isNotEmpty ?? false) ? r['topic'] : 'Materiale richiesto'} · ${r['student_name'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _answerRequestId = value),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _answerMessage,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Messaggio per chi l’ha chiesto (facoltativo)',
            hintText: 'Abbiamo pubblicato il materiale richiesto nelle Dispense.',
          ),
        ),
      ],
    ]);
  }

  Widget _placeSection() {
    final p = context.palette;
    final folders = _folders;
    Widget folderRow(List<String> path, {required bool root}) {
      final bool selected = _folder.join('\u0000') == path.join('\u0000');
      return Padding(
        padding: EdgeInsets.only(left: root ? 0 : 16.0 * path.length, bottom: 2),
        child: Material(
          color: selected ? p.skyBlue.withValues(alpha: 0.12) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(color: selected ? p.skyBlue.withValues(alpha: 0.36) : Colors.transparent),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => _folder = path),
            child: SizedBox(
              height: 38,
              child: Row(children: [
                const SizedBox(width: 10),
                Icon(root ? Icons.school_outlined : Icons.folder_outlined, size: 16, color: root ? p.adminIndigo : p.skyBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(root ? '${_subject?['name'] ?? 'Materia'} (senza cartella)' : path.last,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: selected ? p.diamondDust : p.pureWhite,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                ),
                if (selected) Icon(Icons.check_rounded, size: 16, color: p.skyBlue),
                const SizedBox(width: 10),
              ]),
            ),
          ),
        ),
      );
    }

    return _panel([
      const SlOverline('Posizione nelle Dispense'),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, c) {
        final subjectField = DropdownButtonFormField<int>(
          value: _subjectId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Materia'),
          items: [
            for (final s in _subjects)
              DropdownMenuItem<int>(
                value: _int(s['id']),
                child: Text('${s['name']} · ${s['course']}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _destination == _Destination.answer && widget.answerRequest != null
              ? null
              : (value) => setState(() {
                    _subjectId = value;
                    _folder = const <String>[];
                    _answerRequestId = null;
                  }),
        );
        final titleField = TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Titolo per gli studenti'),
          onChanged: (_) => setState(() {}),
        );
        return c.maxWidth >= 560
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: subjectField),
                const SizedBox(width: 12),
                Expanded(child: titleField),
              ])
            : Column(children: [subjectField, const SizedBox(height: 10), titleField]);
      }),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: p.darkElegance,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
        ),
        child: Column(children: [
          folderRow(const <String>[], root: true),
          for (final path in folders) folderRow(path, root: false),
        ]),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _newFolder,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.create_new_folder_outlined),
          labelText: 'Nuova sottocartella qui (facoltativa)',
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Icon(Icons.shield_outlined, size: 15, color: p.adminCyan),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Su Drive va nella cartella della materia. Nelle Dispense: '
            '${[_subject?['name'] ?? 'Materia', ..._targetPath].join(' / ')}',
            style: SlText.muted(p),
          ),
        ),
      ]),
    ]);
  }

  Widget _audienceSection() {
    final p = context.palette;
    const options = <(String, String)>[
      ('public', 'Tutti, anche ospiti'),
      ('course', 'Studenti del corso'),
      ('subject', 'Studenti della materia'),
      ('group', 'Un gruppo…'),
      ('user', 'Uno studente…'),
    ];
    return _panel([
      const SlOverline('Chi lo vede'),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: _audience == value,
            onSelected: (_) => setState(() => _audience = value),
          ),
      ]),
      if (_audience == 'group' || _audience == 'user') ...[
        const SizedBox(height: 10),
        TextField(
          controller: _audienceId,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: _audience == 'group' ? 'ID del gruppo' : 'ID dello studente'),
        ),
      ],
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('Autore mostrato', style: SlText.muted(p))),
        Text('StudentLab', style: SlText.body(p)),
      ]),
    ], elevated: true);
  }

  Widget _previewSection() {
    final p = context.palette;
    final bool hidden = _destination == _Destination.driveOnly;
    return _panel([
      const SlOverline('Come lo vedranno'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.darkElegance, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([_subject?['course'] ?? '', _subject?['name'] ?? '', ..._targetPath].where((e) => '$e'.isNotEmpty).join(' › '),
              style: SlText.mono(p, size: 11, color: p.materialSky)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              SlFileTile(kind: slFileKind(null, _fileName), size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_title.text.trim().isEmpty ? 'Titolo del materiale' : _title.text.trim(),
                      style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('StudentLab${_bytes == null ? '' : ' · ${_size(_bytes!.length)}'}',
                      style: SlText.muted(p).copyWith(fontSize: 11)),
                ]),
              ),
              SlStatusBadge(label: hidden ? 'Nascosto' : 'Nuovo', tone: hidden ? SlTone.neutral : SlTone.success),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Text(
        hidden
            ? 'Resta nascosto agli studenti: lo mostri dal Catalogo Drive quando è pronto.'
            : 'Arriva nelle Dispense di chi può vederlo alla prossima sincronizzazione.',
        style: SlText.muted(p),
      ),
    ]);
  }

  Widget _actions() {
    final p = context.palette;
    final bool ready = _bytes != null && _subject != null && !_busy;
    return _panel([
      if (_progress != null) ...[
        Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.skyBlue)),
          const SizedBox(width: 10),
          Expanded(child: Text(_progress!, style: SlText.body(p))),
        ]),
        const SizedBox(height: 12),
      ],
      FilledButton(
        onPressed: ready ? () => _submit(asDraft: false) : null,
        style: FilledButton.styleFrom(
          backgroundColor: p.skyBlue,
          foregroundColor: p.darkElegance,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(_destination == _Destination.driveOnly ? 'Carica su Drive' : 'Pubblica ora'),
      ),
      if (_destination != _Destination.driveOnly) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: ready ? () => _submit(asDraft: true) : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: p.pureWhite.withValues(alpha: 0.86),
            minimumSize: const Size(0, 46),
            side: BorderSide(color: p.pureWhite.withValues(alpha: 0.14)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Aggiungi alla bozza del catalogo'),
        ),
        const SizedBox(height: 8),
        Text('Con la bozza lo pubblichi insieme alle altre modifiche del Catalogo Drive.', style: SlText.muted(p)),
      ],
    ]);
  }

  Widget _doneView() {
    final p = context.palette;
    final done = _done!;
    final bool drivePending = done['drive_pending'] == true;
    final bool draft = done['draft'] == true;
    final String? draftNote = done['draft_note'] as String?;
    final String title;
    if (drivePending) {
      title = 'Caricato: la copia su Drive è in corso';
    } else if (_destination == _Destination.driveOnly) {
      title = 'Caricato su Drive, nascosto agli studenti';
    } else if (draft) {
      title = 'Caricato e aggiunto alla bozza';
    } else {
      title = 'Pubblicato nelle Dispense';
    }
    final messages = <String>[
      if (drivePending) 'Resta nascosto finché la copia su Drive non termina; il sistema riprova da solo.',
      if (draftNote != null) draftNote,
      if (draft && draftNote == null) 'Diventa visibile con “Pubblica struttura” nel Catalogo Drive.',
      if (done['answered_request_id'] != null) 'La richiesta è stata chiusa e chi l’ha fatta riceve una notifica.',
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SlEmptyState(
          icon: drivePending ? Icons.cloud_sync_outlined : Icons.check_circle_outline_rounded,
          title: title,
          message: messages.isEmpty ? 'Il materiale è disponibile per i destinatari scelti.' : messages.join(' '),
          actions: [
            SlActionButton(
              icon: Icons.upload_file_rounded,
              label: 'Carica un altro file',
              onPressed: () => setState(() {
                _done = null;
                _bytes = null;
                _fileName = null;
                _title.clear();
                _newFolder.clear();
              }),
            ),
            SlActionButton(
              icon: Icons.check_rounded,
              label: 'Fine',
              primary: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: slAdminAppBar(context, title: 'Carica materiale'),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: p.skyBlue))
            : _done != null
                ? _doneView()
                : LayoutBuilder(builder: (context, box) {
                    final bool wide = box.maxWidth >= _wideBreakpoint;
                    final left = <Widget>[
                      _fileSection(),
                      const SizedBox(height: 16),
                      _destinationSection(),
                      const SizedBox(height: 16),
                      _placeSection(),
                    ];
                    final right = <Widget>[
                      _audienceSection(),
                      const SizedBox(height: 16),
                      _previewSection(),
                      const SizedBox(height: 16),
                      _actions(),
                    ];
                    return ListView(
                      padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 18, wide ? 24 : 16, 32),
                      children: [
                        _stepper(),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          SlErrorCard(title: 'Operazione non completata', message: _error!),
                          const SizedBox(height: 16),
                        ],
                        if (wide)
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
                            const SizedBox(width: 16),
                            SizedBox(width: 400, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
                          ])
                        else
                          ...[...left, const SizedBox(height: 16), ...right],
                      ],
                    );
                  }),
      ),
    );
  }
}
