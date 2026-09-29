import 'package:flutter/material.dart';

import '../faq/faq_widgets.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';
import 'dictionary_draft_editor.dart';
import 'dictionary_review_page.dart';
import 'dictionary_sources_page.dart';

/// Moderazione dei termini del Dizionario (canvas: Dizionario · fonti e
/// moderazione, tavole 3, 5 e 6).
///
/// Admin: tutte le materie. Docente: solo le materie con profilo docente
/// verificato e assegnazione corrente e verificata (lo decide il server).
/// Su schermo largo: coda | termine | provenienza. Su telefono: coda e poi il
/// termine a tutto schermo.
class DictionaryModerationPage extends StatefulWidget {
  final int? subjectId;
  final int? sourceId;
  final bool teacherMode;

  const DictionaryModerationPage({super.key, this.subjectId, this.sourceId, this.teacherMode = false});

  @override
  State<DictionaryModerationPage> createState() => _DictionaryModerationPageState();
}

class _DictionaryModerationPageState extends State<DictionaryModerationPage> {
  final DictionaryApiService _api = DictionaryApiService();
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _subjects = [];
  int? _subjectId;
  int? _sourceId;
  String _status = 'pending';
  String? _kind;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _counts = {};
  int? _selectedId;
  final Set<int> _checked = <int>{};
  bool _multi = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjectId;
    _sourceId = widget.sourceId;
    _start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final data = await _api.moderationSubjects();
      _isAdmin = data['is_admin'] == true;
      _subjects = (data['subjects'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!_isAdmin && _subjectId == null && _subjects.isNotEmpty) {
        _subjectId = int.tryParse('${_subjects.first['id']}');
      }
    } catch (e) {
      _error = faqError(e, 'Moderazione non disponibile.');
    }
    await _load();
  }

  Future<void> _load() async {
    if (!_isAdmin && _subjects.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.drafts(
        subjectId: _subjectId,
        status: _status,
        sourceId: _sourceId,
        kind: _kind,
        query: _search.text,
      );
      _items = (data['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _counts = Map<String, dynamic>.from(data['counts'] as Map? ?? {});
      _checked.removeWhere((id) => !_items.any((i) => i['id'] == id));
      if (_selectedId == null || !_items.any((i) => i['id'] == _selectedId)) {
        _selectedId = _items.isEmpty ? null : int.tryParse('${_items.first['id']}');
      }
    } catch (e) {
      _error = faqError(e, 'Bozze non disponibili.');
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _wide => MediaQuery.sizeOf(context).width >= 1100;

  Future<void> _openDraft(int id) async {
    if (_wide) {
      setState(() => _selectedId = id);
      return;
    }
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _DraftPage(draftId: id, subjects: _subjects),
    ));
    if (mounted) await _load();   // anche un semplice "Salva bozza" cambia la coda
  }

  Future<void> _bulk(String action) async {
    if (_checked.isEmpty) return;
    final p = context.palette;
    String? note;
    if (action == 'reject') {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: Text('Scartare ${_checked.length} termini?'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Motivo (facoltativo)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Scarta')),
          ],
        ),
      );
      note = controller.text;
      controller.dispose();
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final result = await _api.bulkDrafts(_checked.toList(), action, note: note);
      final failed = (result['failed'] as List? ?? []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${(result['done'] as List? ?? []).length} termini '
              '${action == 'approve' ? 'pubblicati' : 'scartati'}'
              '${failed.isEmpty ? '' : ' · ${failed.length} non riusciti (es. senza definizione)'}'),
        ));
      }
      _checked.clear();
      _multi = false;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Operazione non riuscita.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  // --- UI --------------------------------------------------------------------

  Widget _filters() {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_subjects.isNotEmpty)
        DropdownButtonFormField<int?>(
          value: _subjects.any((s) => s['id'] == _subjectId) ? _subjectId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Materia', isDense: true),
          items: [
            if (_isAdmin) const DropdownMenuItem<int?>(value: null, child: Text('Tutte le materie')),
            for (final s in _subjects)
              DropdownMenuItem<int?>(
                value: s['id'] as int?,
                child: Text(
                  '${s['name']}${(s['pending'] ?? 0) > 0 ? ' · ${s['pending']}' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            setState(() => _subjectId = v);
            _load();
          },
        ),
      const SizedBox(height: 8),
      TextField(
        controller: _search,
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Cerca un termine',
          suffixIcon: IconButton(tooltip: 'Cerca', onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in const [('pending', 'Da moderare'), ('approved', 'Pubblicati'), ('rejected', 'Scartati')])
          ChoiceChip(
            label: Text('${s.$2}${_counts[s.$1] != null ? ' · ${_counts[s.$1]}' : ''}'),
            selected: _status == s.$1,
            onSelected: (_) {
              setState(() => _status = s.$1);
              _load();
            },
          ),
        for (final k in const [('new', 'Nuovi'), ('update', 'Aggiornamenti')])
          FilterChip(
            label: Text(k.$2),
            selected: _kind == k.$1,
            onSelected: (v) {
              setState(() => _kind = v ? k.$1 : null);
              _load();
            },
          ),
        if (_sourceId != null)
          InputChip(
            label: const Text('Da una fonte'),
            onDeleted: () {
              setState(() => _sourceId = null);
              _load();
            },
          ),
      ]),
      if (_status == 'pending' && _items.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(children: [
          Checkbox(
            value: _multi,
            onChanged: (v) => setState(() {
              _multi = v == true;
              if (!_multi) _checked.clear();
            }),
          ),
          Text('Seleziona più termini', style: SlText.muted(p)),
        ]),
      ],
    ]);
  }

  Widget _queueItem(Map<String, dynamic> item) {
    final p = context.palette;
    final id = int.parse('${item['id']}');
    final bool active = _wide && id == _selectedId;
    final bool update = item['kind'] == 'update';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? p.skyBlue.withValues(alpha: 0.10) : p.darkElegance,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: active ? p.skyBlue.withValues(alpha: 0.5) : p.pureWhite.withValues(alpha: 0.07)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _multi
              ? () => setState(() => _checked.contains(id) ? _checked.remove(id) : _checked.add(id))
              : () => _openDraft(id),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_multi)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Checkbox(
                    value: _checked.contains(id),
                    onChanged: (v) => setState(() => v == true ? _checked.add(id) : _checked.remove(id)),
                  ),
                ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${item['term']}', style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (item['source_label'] != null) '${item['source_label']}',
                      if (item['source_ref'] != null) '${item['source_ref']}',
                      if (_subjectId == null && item['subject_name'] != null) '${item['subject_name']}',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SlText.muted(p).copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    SlStatusBadge(label: update ? 'Aggiornamento' : 'Nuovo', tone: update ? SlTone.warning : SlTone.info),
                    if (item['topic_id'] == null && item['topic_title'] == null)
                      const SlStatusBadge(label: 'Senza argomento', tone: SlTone.danger),
                    SlStatusBadge(label: 'A.A. ${item['academic_year']}'),
                    if (item['status'] == 'approved') const SlStatusBadge(label: 'Pubblicato', tone: SlTone.success),
                    if (item['status'] == 'rejected') const SlStatusBadge(label: 'Scartato', tone: SlTone.danger),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _queue() {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _filters(),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: p.skyBlue))
              : _items.isEmpty
                  ? SingleChildScrollView(
                      child: SlEmptyState(
                        icon: Icons.task_alt_rounded,
                        title: _status == 'pending' ? 'Niente da moderare' : 'Nessun termine',
                        message: _status == 'pending'
                            ? 'I termini letti dalle fonti compaiono qui prima di diventare pubblici.'
                            : 'Cambia i filtri per vedere altri termini.',
                      ),
                    )
                  : ListView(children: [for (final i in _items) _queueItem(i)]),
        ),
        if (_multi && _checked.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _bulk('reject'),
                child: Text('Scarta ${_checked.length}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _bulk('approve'),
                style: FilledButton.styleFrom(backgroundColor: p.adminGreen, foregroundColor: p.darkElegance),
                child: Text('Pubblica ${_checked.length}'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title = widget.teacherMode || !_isAdmin ? 'Dizionario delle mie materie' : 'Moderazione del Dizionario';
    final appBarActions = <Widget>[
      IconButton(
        tooltip: 'Fonti',
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => DictionarySourcesPage(subjectId: _subjectId, teacherMode: widget.teacherMode || !_isAdmin),
          ));
          if (mounted) await _load();
        },
        icon: const Icon(Icons.source_outlined),
      ),
      if (_isAdmin)
        IconButton(
          tooltip: 'Revisione tra anni',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => DictionaryReviewPage(subjectId: _subjectId),
          )),
          icon: const Icon(Icons.history_edu_outlined),
        ),
      IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
    ];
    Widget body;
    if (!_loading && !_isAdmin && _subjects.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: SlEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Nessuna materia da moderare',
          message: 'Serve il profilo docente verificato e un’assegnazione verificata per quest’anno.',
        ),
      );
    } else if (_wide) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 320, child: _queue()),
          const SizedBox(width: 16),
          Expanded(
            child: _selectedId == null
                ? const Center(
                    child: SlEmptyState(
                      icon: Icons.touch_app_outlined,
                      title: 'Scegli un termine',
                      message: 'Modificalo, collegalo e pubblicalo.',
                    ),
                  )
                : DictionaryDraftEditor(
                    key: ValueKey(_selectedId),
                    draftId: _selectedId!,
                    subjects: _subjects,
                    wide: true,
                    onChanged: _load,
                  ),
          ),
        ]),
      );
    } else {
      body = Padding(padding: const EdgeInsets.all(12), child: _queue());
    }
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: widget.teacherMode || !_isAdmin
          ? AppBar(
              backgroundColor: p.eleganceMidnight,
              foregroundColor: p.pureWhite,
              title: Text(title),
              actions: appBarActions,
            )
          : slAdminAppBar(context, title: title, actions: appBarActions),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SlErrorCard(title: 'Attenzione', message: _error!, onRetry: _load),
          ),
        Expanded(child: body),
      ]),
    );
  }
}

/// Termine a tutto schermo (telefono).
class _DraftPage extends StatelessWidget {
  final int draftId;
  final List<Map<String, dynamic>> subjects;

  const _DraftPage({required this.draftId, required this.subjects});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(backgroundColor: p.eleganceMidnight, foregroundColor: p.pureWhite, title: const Text('Modera il termine')),
      body: DictionaryDraftEditor(
        draftId: draftId,
        subjects: subjects,
        wide: false,
        onChanged: () {},
        onDone: () => Navigator.of(context).pop(true),
      ),
    );
  }
}
