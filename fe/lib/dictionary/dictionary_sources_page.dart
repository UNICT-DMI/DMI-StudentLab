import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../faq/faq_widgets.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';
import 'dictionary_import_page.dart';
import 'dictionary_moderation_page.dart';

/// Registro delle fonti del Dizionario (canvas: Dizionario · fonti e
/// moderazione, tavole 2 e 4).
///
/// Ogni fonte mostra indirizzo o percorso, metadati, esito dell'ultima lettura
/// e l'estratto del testo letto. I PDF e le pagine web si leggono in locale con
/// `scripts/fonti_dizionario.py`: qui si registrano le pagine web da leggere e
/// si copia il comando per PDF e cartelle. Il server riceve solo i risultati.
class DictionarySourcesPage extends StatefulWidget {
  final int? subjectId;
  final bool teacherMode;

  const DictionarySourcesPage({super.key, this.subjectId, this.teacherMode = false});

  @override
  State<DictionarySourcesPage> createState() => _DictionarySourcesPageState();
}

const _kindLabels = <String, String>{
  'json': 'Dizionario JSON',
  'pdf': 'PDF',
  'web': 'Pagina web',
  'question_bank': 'Banca domande',
  'local': 'File locale',
  'text': 'Testo',
  'manual': 'Manuale',
};

const _recheckLabels = <String, String>{
  'none': 'Mai',
  'daily': 'Ogni giorno',
  'weekly': 'Ogni settimana',
  'monthly': 'Ogni mese',
};

IconData _kindIcon(String kind) => switch (kind) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'web' => Icons.public_rounded,
      'question_bank' => Icons.quiz_outlined,
      'text' || 'local' => Icons.description_outlined,
      'manual' => Icons.edit_note_rounded,
      _ => Icons.data_object_rounded,
    };

(String, SlTone) _statusBadge(String status) => switch (status) {
      'read' => ('Letta', SlTone.success),
      'unchanged' => ('Invariata', SlTone.info),
      'no_terms' => ('Nessun termine', SlTone.warning),
      'error' => ('Errore', SlTone.danger),
      _ => ('Da leggere', SlTone.warning),
    };

String _date(dynamic value) {
  final d = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class _DictionarySourcesPageState extends State<DictionarySourcesPage> {
  final DictionaryApiService _api = DictionaryApiService();
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _subjects = [];
  int? _subjectId;
  String? _kind;
  String? _status;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjectId;
    _start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _start() async {
    try {
      final data = await _api.moderationSubjects();
      _isAdmin = data['is_admin'] == true;
      _subjects = _maps(data['subjects']);
    } catch (e) {
      _error = faqError(e, 'Fonti non disponibili.');
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await _api.sources(subjectId: _subjectId, kind: _kind, status: _status, query: _search.text);
    } catch (e) {
      _error = faqError(e, 'Fonti non disponibili.');
    }
    if (mounted) setState(() => _loading = false);
  }

  String? get _subjectName =>
      _subjects.where((s) => '${s['id']}' == '$_subjectId').map((s) => '${s['name']}').firstOrNull;

  // --- Aggiungere una fonte ---------------------------------------------------

  Future<void> _add() async {
    final p = context.palette;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(
              'I termini trovati diventano bozze da moderare: niente è pubblico finché non lo approvi.',
              style: SlText.muted(p),
            ),
          ),
          ListTile(
            leading: const SlIconTile(icon: Icons.data_object_rounded, tone: SlTone.warning, size: 38),
            title: const Text('File JSON del dizionario'),
            subtitle: const Text('Caricato dall’app: anteprima, materia e anno prima dell’import'),
            onTap: () => Navigator.pop(sheetContext, 'json'),
          ),
          ListTile(
            leading: const SlIconTile(icon: Icons.public_rounded, tone: SlTone.info, size: 38),
            title: const Text('Pagina web'),
            subtitle: const Text('La registri qui; lo script la legge in locale e rimanda i risultati'),
            onTap: () => Navigator.pop(sheetContext, 'web'),
          ),
          ListTile(
            leading: const SlIconTile(icon: Icons.picture_as_pdf_outlined, tone: SlTone.danger, size: 38),
            title: const Text('PDF, cartella o banca domande'),
            subtitle: const Text('Si leggono sul tuo computer: ti preparo il comando'),
            onTap: () => Navigator.pop(sheetContext, 'local'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'json':
        final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => DictionaryImportPage(subjectId: _subjectId),
        ));
        if (done == true) await _load();
      case 'web':
        await _webDialog();
      case 'local':
        await _commandDialog();
    }
  }

  Widget _subjectField(int? value, ValueChanged<int?> onChanged, {bool allowNone = false}) => DropdownButtonFormField<int?>(
        value: _subjects.any((s) => '${s['id']}' == '$value') ? value : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Materia', isDense: true),
        items: [
          if (allowNone) const DropdownMenuItem<int?>(value: null, child: Text('Da scegliere')),
          for (final s in _subjects)
            DropdownMenuItem<int?>(
              value: int.tryParse('${s['id']}'),
              child: Text('${s['name']}${s['course'] != null ? ' · ${s['course']}' : ''}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      );

  Future<void> _webDialog() async {
    final p = context.palette;
    final url = TextEditingController();
    final label = TextEditingController();
    final year = TextEditingController();
    final topic = TextEditingController();
    final selector = TextEditingController();
    int? subjectId = _subjectId ?? (_subjects.length == 1 ? int.tryParse('${_subjects.first['id']}') : null);
    String recheck = 'weekly';
    String? problem;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('Pagina web da leggere'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Indirizzo', hintText: 'https://…/glossario'),
                ),
                const SizedBox(height: 10),
                TextField(controller: label, decoration: const InputDecoration(labelText: 'Nome (facoltativo)')),
                const SizedBox(height: 10),
                _subjectField(subjectId, (v) => setLocal(() => subjectId = v)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(controller: year, decoration: const InputDecoration(labelText: 'Anno', hintText: '2025/2026')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: recheck,
                      decoration: const InputDecoration(labelText: 'Ricontrolla'),
                      items: [
                        for (final e in _recheckLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setLocal(() => recheck = v ?? 'none'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(controller: topic, decoration: const InputDecoration(labelText: 'Argomento proposto (facoltativo)')),
                const SizedBox(height: 10),
                TextField(
                  controller: selector,
                  decoration: const InputDecoration(
                    labelText: 'Parte della pagina (facoltativo)',
                    hintText: '#glossario oppure .definizioni',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Lo script rispetta robots.txt, aspetta tra una richiesta e l’altra e rilegge la pagina solo se è '
                  'cambiata. Al server arrivano i termini, i metadati e un estratto del testo.',
                  style: SlText.muted(p).copyWith(fontSize: 12),
                ),
                if (problem != null) ...[
                  const SizedBox(height: 8),
                  Text(problem!, style: TextStyle(color: p.adminCoral)),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
            FilledButton(
              onPressed: () {
                final u = Uri.tryParse(url.text.trim());
                if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) {
                  setLocal(() => problem = 'Serve un indirizzo che inizi con http:// o https://');
                  return;
                }
                if (subjectId == null) {
                  setLocal(() => problem = 'Scegli la materia.');
                  return;
                }
                if (year.text.trim().isNotEmpty && !RegExp(r'^\d{4}/\d{4}$').hasMatch(year.text.trim())) {
                  setLocal(() => problem = 'Anno nel formato 2025/2026.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Registra'),
            ),
          ],
        ),
      ),
    );
    final body = <String, dynamic>{
      'kind': 'web',
      'location': url.text.trim(),
      if (label.text.trim().isNotEmpty) 'label': label.text.trim(),
      'subject_id': subjectId,
      if (year.text.trim().isNotEmpty) 'academic_year': year.text.trim(),
      if (topic.text.trim().isNotEmpty) 'topic_title': topic.text.trim(),
      if (selector.text.trim().isNotEmpty) 'selector': selector.text.trim(),
      'recheck': recheck,
    };
    for (final c in [url, label, year, topic, selector]) {
      c.dispose();
    }
    if (ok != true) return;
    try {
      final created = await _api.createSource(body);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await _showSyncCommand(created);
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Fonte non salvata.'));
    }
  }

  String get _envPrefix => 'STUDENTLAB_API=${_api.uri('').toString().replaceAll(RegExp(r'/$'), '')} '
      'STUDENTLAB_TOKEN=<il tuo token>';

  Future<void> _showSyncCommand(Map<String, dynamic> source) => _showCommand(
        title: 'Pagina registrata',
        intro: 'È nel registro come “Da leggere”. Dalla cartella BE/ del progetto, sul tuo computer, lancia:',
        command: '$_envPrefix python3 scripts/fonti_dizionario.py --sincronizza',
        outro: 'Lo script chiede al server le pagine da leggere, le legge e rimanda termini, metadati ed estratto. '
            'I termini arrivano qui come bozze.',
      );

  Future<void> _commandDialog() async {
    final p = context.palette;
    final year = TextEditingController();
    final topic = TextEditingController();
    int? subjectId = _subjectId ?? (_subjects.length == 1 ? int.tryParse('${_subjects.first['id']}') : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('PDF, cartella o banca domande'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                'I file restano sul tuo computer. Lo script riconosce da solo il tipo (dizionario JSON, banca domande, '
                'PDF con testo, HTML, TXT/MD), salta quelli già letti e invariati e manda al server solo i risultati.',
                style: SlText.muted(p).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
              _subjectField(subjectId, (v) => setLocal(() => subjectId = v)),
              const SizedBox(height: 10),
              TextField(controller: year, decoration: const InputDecoration(labelText: 'Anno', hintText: '2025/2026')),
              const SizedBox(height: 10),
              TextField(controller: topic, decoration: const InputDecoration(labelText: 'Argomento proposto (facoltativo)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Prepara il comando')),
          ],
        ),
      ),
    );
    final y = year.text.trim();
    final t = topic.text.trim();
    year.dispose();
    topic.dispose();
    if (ok != true || !mounted) return;
    String quote(String v) => "'${v.replaceAll("'", "'\\''")}'";
    final args = [
      'python3 scripts/fonti_dizionario.py <file o cartella>',
      if (subjectId != null) '--materia-id $subjectId',
      if (y.isNotEmpty) '--anno ${quote(y)}',
      if (t.isNotEmpty) '--argomento ${quote(t)}',
      '--invia',
    ];
    await _showCommand(
      title: 'Leggi in locale',
      intro: 'Dalla cartella BE/ del progetto, sul tuo computer. Prova prima senza inviare con --prova.',
      command: '$_envPrefix ${args.join(' ')}',
      outro: 'PDF scansionati: lo script li segnala (“serve OCR”); passali prima da un OCR, es. ocrmypdf. '
          'Nel registro vedrai percorso, impronta, pagine, autore/titolo del PDF e l’estratto del testo.',
    );
  }

  Future<void> _showCommand({required String title, required String intro, required String command, String? outro}) async {
    final p = context.palette;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(intro, style: SlText.body(p)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.darkElegance, borderRadius: BorderRadius.circular(10)),
              child: SelectableText(command,
                  style: TextStyle(color: p.pureWhite, fontFamily: 'monospace', fontSize: 12, height: 1.4)),
            ),
            if (outro != null) ...[
              const SizedBox(height: 10),
              Text(outro, style: SlText.muted(p).copyWith(fontSize: 12)),
            ],
          ]),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: command));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comando copiato.')));
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copia'),
          ),
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fatto')),
        ],
      ),
    );
  }

  // --- Dettaglio --------------------------------------------------------------

  Future<void> _open(Map<String, dynamic> item) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _SourceDetailPage(
        sourceId: int.parse('${item['id']}'),
        teacherMode: widget.teacherMode,
        envPrefix: _envPrefix,
      ),
    ));
    if (changed == true && mounted) await _load();
  }

  // --- Interfaccia -------------------------------------------------------------

  Widget _filters() {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final subject = _subjects.isEmpty
        ? const SizedBox.shrink()
        : DropdownButtonFormField<int?>(
            value: _subjects.any((s) => '${s['id']}' == '$_subjectId') ? _subjectId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Materia', isDense: true),
            items: [
              if (_isAdmin || _subjects.length > 1) const DropdownMenuItem<int?>(value: null, child: Text('Tutte')),
              for (final s in _subjects)
                DropdownMenuItem<int?>(value: int.tryParse('${s['id']}'), child: Text('${s['name']}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              setState(() => _subjectId = v);
              _load();
            },
          );
    final search = TextField(
      controller: _search,
      onSubmitted: (_) => _load(),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Nome, indirizzo o percorso',
        suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)),
      ),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (wide)
        Row(children: [Expanded(child: subject), const SizedBox(width: 10), Expanded(child: search)])
      else ...[
        subject,
        const SizedBox(height: 8),
        search,
      ],
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final k in const ['pdf', 'web', 'json', 'question_bank'])
          FilterChip(
            avatar: Icon(_kindIcon(k), size: 16),
            label: Text(_kindLabels[k]!),
            selected: _kind == k,
            onSelected: (v) {
              setState(() => _kind = v ? k : null);
              _load();
            },
          ),
        for (final s in const ['new', 'error', 'no_terms'])
          FilterChip(
            label: Text(_statusBadge(s).$1),
            selected: _status == s,
            onSelected: (v) {
              setState(() => _status = v ? s : null);
              _load();
            },
          ),
      ]),
    ]);
  }

  Widget _tile(Map<String, dynamic> s) {
    final p = context.palette;
    final kind = '${s['kind']}';
    final status = _statusBadge('${s['status']}');
    final pending = (s['pending'] as num? ?? 0).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.eleganceMidnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: s['status'] == 'error' ? p.adminCoral.withValues(alpha: 0.4) : p.pureWhite.withValues(alpha: 0.07),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(s),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SlIconTile(icon: _kindIcon(kind), size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['label']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 14)),
                  if (s['location'] != null) ...[
                    const SizedBox(height: 2),
                    Text('${s['location']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: SlText.muted(p).copyWith(fontSize: 11)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      _kindLabels[kind] ?? kind,
                      if (s['subject_name'] != null) '${s['subject_name']}',
                      if (s['academic_year'] != null) 'A.A. ${s['academic_year']}',
                      'letta ${_date(s['last_read_at'])}',
                    ].join(' · '),
                    style: SlText.muted(p).copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    SlStatusBadge(label: status.$1, tone: status.$2),
                    SlStatusBadge(label: '${s['entries_found'] ?? 0} termini trovati'),
                    if (pending > 0) SlStatusBadge(label: '$pending da moderare', tone: SlTone.warning),
                    if ((s['approved'] as num? ?? 0) > 0)
                      SlStatusBadge(label: '${s['approved']} pubblicati', tone: SlTone.success),
                    if (kind == 'web' && s['recheck'] != 'none')
                      SlStatusBadge(label: _recheckLabels['${s['recheck']}'] ?? '${s['recheck']}', tone: SlTone.info),
                    if (s['recheck_due'] == true) const SlStatusBadge(label: 'Da rileggere', tone: SlTone.warning),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final due = _items.where((s) => s['recheck_due'] == true).length;
    final title = _subjectName == null ? 'Fonti del Dizionario' : 'Fonti · $_subjectName';
    final actions = <Widget>[
      IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
    ];
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: widget.teacherMode || !_isAdmin
          ? AppBar(backgroundColor: p.eleganceMidnight, foregroundColor: p.pureWhite, title: Text(title), actions: actions)
          : slAdminAppBar(context, title: title, actions: actions),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subjects.isEmpty && !_isAdmin ? null : _add,
        backgroundColor: p.skyBlue,
        foregroundColor: p.darkElegance,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Aggiungi fonte'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              if (_error != null) ...[
                SlErrorCard(title: 'Attenzione', message: _error!, onRetry: _load),
                const SizedBox(height: 12),
              ],
              _filters(),
              const SizedBox(height: 12),
              if (due > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.adminAmber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.adminAmber.withValues(alpha: 0.35)),
                  ),
                  child: Row(children: [
                    Icon(Icons.schedule_rounded, color: p.adminAmber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('$due pagine web da leggere o ricontrollare: le legge lo script con --sincronizza.',
                          style: SlText.body(p).copyWith(fontSize: 13)),
                    ),
                    TextButton(onPressed: () => _showSyncCommand(const {}), child: const Text('Comando')),
                  ]),
                ),
              if (_loading)
                Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: p.skyBlue)))
              else if (_items.isEmpty)
                const SlEmptyState(
                  icon: Icons.source_outlined,
                  title: 'Nessuna fonte',
                  message: 'Aggiungi un JSON, una pagina web o leggi PDF e cartelle con lo script: '
                      'compariranno qui con metadati ed estratto del testo.',
                )
              else
                for (final s in _items) _tile(s),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Dettaglio di una fonte: indirizzo, metadati, esito, estratto del testo.
class _SourceDetailPage extends StatefulWidget {
  final int sourceId;
  final bool teacherMode;
  final String envPrefix;

  const _SourceDetailPage({required this.sourceId, required this.teacherMode, required this.envPrefix});

  @override
  State<_SourceDetailPage> createState() => _SourceDetailPageState();
}

class _SourceDetailPageState extends State<_SourceDetailPage> {
  final DictionaryApiService _api = DictionaryApiService();
  Map<String, dynamic>? _source;
  String? _error;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _source = await _api.source(widget.sourceId);
      _error = null;
    } catch (e) {
      _error = faqError(e, 'Fonte non disponibile.');
    }
    if (mounted) setState(() {});
  }

  Future<void> _patch(Map<String, dynamic> body, String done) async {
    setState(() => _busy = true);
    try {
      _source = await _api.updateSource(widget.sourceId, {'kind': _source!['kind'], ...body});
      _changed = true;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Fonte non salvata.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: const Text('Togliere la fonte dal registro?'),
        content: const Text('Le bozze già create restano da moderare (senza fonte). I termini pubblicati non cambiano.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: p.adminCoral),
            child: const Text('Togli'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.deleteSource(widget.sourceId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = faqError(e, 'Fonte non eliminata.');
        });
      }
    }
  }

  Widget _panel(String title, List<Widget> children, {Widget? trailing}) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: SlOverline(title)), if (trailing != null) trailing]),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = _source;
    final appBar = AppBar(
      backgroundColor: p.eleganceMidnight,
      foregroundColor: p.pureWhite,
      title: Text(s == null ? 'Fonte' : '${s['label']}', overflow: TextOverflow.ellipsis),
      leading: BackButton(onPressed: () => Navigator.of(context).pop(_changed)),
      actions: [
        if (s != null)
          IconButton(
            tooltip: 'Togli dal registro',
            onPressed: _busy ? null : _delete,
            icon: Icon(Icons.delete_outline_rounded, color: p.adminCoral),
          ),
      ],
    );
    if (s == null) {
      return Scaffold(
        backgroundColor: p.darkElegance,
        appBar: appBar,
        body: _error != null
            ? Padding(padding: const EdgeInsets.all(16), child: SlErrorCard(title: 'Attenzione', message: _error!, onRetry: _load))
            : Center(child: CircularProgressIndicator(color: p.skyBlue)),
      );
    }
    final kind = '${s['kind']}';
    final status = _statusBadge('${s['status']}');
    final metadata = Map<String, dynamic>.from(s['metadata'] as Map? ?? {});
    final location = '${s['location'] ?? ''}';
    final excerpt = '${s['text_excerpt'] ?? ''}';
    final total = (s['pending'] as num? ?? 0) + (s['approved'] as num? ?? 0) + (s['rejected'] as num? ?? 0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: p.darkElegance,
        appBar: appBar,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (_error != null) ...[SlErrorCard(title: 'Attenzione', message: _error!), const SizedBox(height: 12)],
              _panel('Fonte', [
                Row(children: [
                  SlIconTile(icon: _kindIcon(kind), size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['label']}', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 5, runSpacing: 4, children: [
                        SlStatusBadge(label: _kindLabels[kind] ?? kind, tone: SlTone.info),
                        SlStatusBadge(label: status.$1, tone: status.$2),
                        if (s['recheck_due'] == true) const SlStatusBadge(label: 'Da rileggere', tone: SlTone.warning),
                      ]),
                    ]),
                  ),
                ]),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: SelectableText(location, style: SlText.body(p).copyWith(fontSize: 13))),
                    IconButton(
                      tooltip: 'Copia',
                      onPressed: () => Clipboard.setData(ClipboardData(text: location)),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ]),
                ],
                const SizedBox(height: 8),
                SlKeyValue(label: 'Materia', value: '${s['subject_name'] ?? '—'}'),
                SlKeyValue(label: 'Anno', value: '${s['academic_year'] ?? '—'}'),
                if (s['topic_title'] != null) SlKeyValue(label: 'Argomento', value: '${s['topic_title']}'),
                SlKeyValue(label: 'Ultima lettura', value: _date(s['last_read_at'])),
                SlKeyValue(label: 'Registrata da', value: '${s['created_by_name'] ?? '—'} · ${_date(s['created_at'])}'),
                if (s['sha256'] != null) SlKeyValue(label: 'Impronta', value: '${'${s['sha256']}'.substring(0, 16)}…'),
                if (s['selector'] != null) SlKeyValue(label: 'Parte della pagina', value: '${s['selector']}'),
              ]),
              if (s['error'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SlErrorCard(title: 'Ultima lettura non riuscita', message: '${s['error']}'),
                ),
              _panel('Termini', [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  SlStatusBadge(label: '${s['entries_found'] ?? 0} trovati nell’ultima lettura'),
                  SlStatusBadge(label: '${s['pending']} da moderare', tone: SlTone.warning),
                  SlStatusBadge(label: '${s['approved']} pubblicati', tone: SlTone.success),
                  SlStatusBadge(label: '${s['rejected']} scartati', tone: SlTone.danger),
                ]),
                if (total > 0) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => DictionaryModerationPage(
                          subjectId: int.tryParse('${s['subject_id']}'),
                          sourceId: widget.sourceId,
                          teacherMode: widget.teacherMode,
                        ),
                      )),
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Modera i termini di questa fonte'),
                    ),
                  ),
                ],
              ]),
              if (kind == 'web')
                _panel('Lettura della pagina', [
                  DropdownButtonFormField<String>(
                    value: _recheckLabels.containsKey(s['recheck']) ? '${s['recheck']}' : 'none',
                    decoration: const InputDecoration(labelText: 'Ricontrolla', isDense: true),
                    items: [for (final e in _recheckLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: _busy ? null : (v) => _patch({'recheck': v}, 'Frequenza aggiornata.'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _patch({'reread': true}, 'Sarà riletta al prossimo --sincronizza.'),
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Rileggi al prossimo giro'),
                    ),
                    TextButton.icon(
                      onPressed: () => Clipboard.setData(ClipboardData(
                          text: '${widget.envPrefix} python3 scripts/fonti_dizionario.py --sincronizza')),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copia il comando'),
                    ),
                  ]),
                ]),
              if (metadata.isNotEmpty)
                _panel('Metadati', [
                  for (final e in metadata.entries) SlKeyValue(label: e.key, value: '${e.value ?? '—'}'),
                ]),
              _panel(
                'Testo letto',
                trailing: excerpt.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Copia',
                        onPressed: () => Clipboard.setData(ClipboardData(text: excerpt)),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                [
                  if (excerpt.isEmpty)
                    Text('Nessun estratto: la fonte non è ancora stata letta o era un JSON già strutturato.',
                        style: SlText.muted(p))
                  else ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 520),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: p.darkElegance, borderRadius: BorderRadius.circular(10)),
                      child: SingleChildScrollView(
                        child: SelectableText(excerpt,
                            style: TextStyle(color: p.pureWhite, fontFamily: 'monospace', fontSize: 12, height: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Primi ${excerpt.length} caratteri del testo estratto (massimo 20.000).',
                        style: SlText.muted(p).copyWith(fontSize: 11)),
                  ],
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
