import 'package:flutter/material.dart';

import '../faq/faq_widgets.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';

/// Un termine da moderare (canvas: Dizionario · fonti e moderazione, tavole 5 e 6).
///
/// Si modifica tutto prima della pubblicazione: testo, materia, argomento,
/// anno, docente a cui è affidato, esercizi, domande d'esame (passate o
/// possibili, collegate a un appello del Calendario) e domande del quiz.
/// Accanto: da dove viene (fonte + estratto), possibili doppioni e la versione
/// già pubblicata.
///
/// Nessuna logica di permesso qui: il server rifiuta ciò che l'utente non può
/// fare (profilo docente verificato + assegnazione corrente e verificata).
class DictionaryDraftEditor extends StatefulWidget {
  final int draftId;
  final List<Map<String, dynamic>> subjects;
  final bool wide;
  final VoidCallback onChanged;
  final VoidCallback? onDone;

  const DictionaryDraftEditor({
    super.key,
    required this.draftId,
    required this.subjects,
    required this.wide,
    required this.onChanged,
    this.onDone,
  });

  @override
  State<DictionaryDraftEditor> createState() => _DictionaryDraftEditorState();
}

class _DictionaryDraftEditorState extends State<DictionaryDraftEditor> {
  final DictionaryApiService _api = DictionaryApiService();
  final TextEditingController _term = TextEditingController();
  final TextEditingController _aliases = TextEditingController();
  final TextEditingController _formal = TextEditingController();
  final TextEditingController _informal = TextEditingController();
  final TextEditingController _year = TextEditingController();
  final TextEditingController _newTopic = TextEditingController();
  final TextEditingController _bankQuery = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  String? _error;
  Map<String, dynamic> _draft = {};
  String _tab = 'definitions';

  int? _subjectId;
  int? _topicId;
  int? _teacherId;
  int? _targetEntryId;
  String? _quizSource;
  List<Map<String, dynamic>> _examples = [];
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _resources = [];
  List<String> _related = [];
  List<dynamic> _quizIds = [];

  List<Map<String, dynamic>> _bankResults = [];
  bool _bankLoading = false;
  bool _bankSearched = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_term, _aliases, _formal, _informal, _year, _newTopic]) {
      c.addListener(_markDirty);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_term, _aliases, _formal, _informal, _year, _newTopic, _bankQuery]) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_loading && !_dirty && mounted) setState(() => _dirty = true);
  }

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  int? _int(dynamic value) => value == null ? null : int.tryParse('$value');

  bool get _editable => _draft['status'] == 'pending' && _draft['can_moderate'] == true;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _api.draft(widget.draftId);
      final content = Map<String, dynamic>.from(d['content'] as Map? ?? {});
      _draft = d;
      _term.text = '${d['term'] ?? ''}';
      _aliases.text = (d['aliases'] as List? ?? []).join(', ');
      _formal.text = '${content['formal_definition'] ?? ''}';
      _informal.text = '${content['informal_definition'] ?? ''}';
      _year.text = '${d['academic_year'] ?? ''}';
      _newTopic.text = d['topic_id'] == null ? '${d['topic_title'] ?? ''}' : '';
      _subjectId = _int(d['subject_id']);
      _topicId = _int(d['topic_id']);
      _teacherId = _int(d['assigned_teacher_user_id']);
      _targetEntryId = _int(d['target_entry_id']);
      _quizSource = (content['quiz_source'] ?? d['quiz_source'])?.toString();
      _examples = _maps(content['examples']);
      _exercises = _maps(content['exercises']);
      _exams = _maps(content['exam_questions']);
      _resources = _maps(content['resources']);
      _related = [for (final r in (content['related'] as List? ?? [])) '$r'];
      _quizIds = List<dynamic>.from(content['quiz_question_ids'] as List? ?? []);
      if (_bankQuery.text.isEmpty) _bankQuery.text = _term.text;
    } catch (e) {
      _error = faqError(e, 'Termine non disponibile.');
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _dirty = false;
      });
    }
  }

  Map<String, dynamic> _body() => {
        'term': _term.text.trim(),
        'aliases': _aliases.text.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
        'academic_year': _year.text.trim(),
        if (_newTopic.text.trim().isNotEmpty) ...{'topic_id': null, 'topic_title': _newTopic.text.trim()}
        else 'topic_id': _topicId,
        'target_entry_id': _targetEntryId,
        'assigned_teacher_user_id': _teacherId,
        'content': {
          'formal_definition': _formal.text.trim(),
          'informal_definition': _informal.text.trim(),
          'examples': _examples,
          'exercises': _exercises,
          'exam_questions': _exams,
          'resources': _resources,
          'related': _related,
          'quiz_question_ids': _quizIds,
          if (_quizSource != null) 'quiz_source': _quizSource,
        },
      };

  String? _validate() {
    if (_term.text.trim().isEmpty) return 'Scrivi il termine.';
    if (_formal.text.trim().isEmpty && _informal.text.trim().isEmpty) return 'Scrivi almeno una definizione.';
    if (_year.text.trim().isNotEmpty && !RegExp(r'^\d{4}/\d{4}$').hasMatch(_year.text.trim())) {
      return 'Anno accademico nel formato 2025/2026.';
    }
    return null;
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _save({bool quiet = false}) async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.updateDraft(widget.draftId, _body());
      if (!quiet) _snack('Bozza salvata. Non è ancora visibile agli studenti.');
      widget.onChanged();
      await _load();
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Bozza non salvata.'));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeSubject(int? subjectId) async {
    if (subjectId == null || subjectId == _subjectId) return;
    setState(() => _busy = true);
    try {
      // Cambiando materia argomento e termine da aggiornare si azzerano (lo fa il server).
      await _api.updateDraft(widget.draftId, {..._body(), 'subject_id': subjectId, 'topic_id': null, 'target_entry_id': null});
      widget.onChanged();
      await _load();
      _snack('Spostato in un’altra materia: scegli l’argomento.');
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Materia non cambiata.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _approve({int? mergeInto}) async {
    if (_dirty || mergeInto != null) {
      if (!await _save(quiet: true)) return;
    }
    setState(() => _busy = true);
    try {
      await _api.approveDraft(widget.draftId, mergeIntoEntryId: mergeInto);
      _snack(mergeInto != null ? 'Unito al termine esistente e pubblicato.' : 'Pubblicato nel Dizionario.');
      widget.onChanged();
      if (widget.onDone != null) {
        widget.onDone!();
        return;
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Pubblicazione non riuscita.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reject() async {
    final p = context.palette;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: Text('Scartare “${_term.text}”?'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Se la stessa bozza torna da un nuovo import verrà riconosciuta e non riproposta.',
                style: SlText.muted(p)),
            const SizedBox(height: 10),
            TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Motivo (facoltativo)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: p.adminCoral),
            child: const Text('Scarta'),
          ),
        ],
      ),
    );
    final note = controller.text;
    controller.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.rejectDraft(widget.draftId, note: note);
      _snack('Termine scartato.');
      widget.onChanged();
      if (widget.onDone != null) {
        widget.onDone!();
        return;
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Operazione non riuscita.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  // --- Finestre di modifica ---------------------------------------------------

  Future<Map<String, dynamic>?> _itemDialog(String title, List<(String, String, int)> fields,
      [Map<String, dynamic>? initial]) async {
    final p = context.palette;
    final controllers = {for (final f in fields) f.$1: TextEditingController(text: '${initial?[f.$1] ?? ''}')};
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: Text(title),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final f in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[f.$1],
                    minLines: f.$3,
                    maxLines: f.$3 == 1 ? 1 : 12,
                    keyboardType: f.$1 == 'difficulty' ? TextInputType.number : null,
                    decoration: InputDecoration(labelText: f.$2),
                  ),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salva')),
        ],
      ),
    );
    final result = <String, dynamic>{...?initial};
    for (final f in fields) {
      final value = controllers[f.$1]!.text.trim();
      result.remove(f.$1);
      if (value.isNotEmpty) {
        result[f.$1] = f.$1 == 'difficulty' ? ((int.tryParse(value) ?? 1).clamp(1, 5)) : value;
      }
      controllers[f.$1]!.dispose();
    }
    return ok == true && result.isNotEmpty ? result : null;
  }

  static const _examKinds = [
    ('past', 'Uscita a un esame', Icons.history_rounded),
    ('possible', 'Possibile domanda', Icons.lightbulb_outline_rounded),
    ('reports', 'Dai racconti degli studenti', Icons.forum_outlined),
  ];

  /// Domanda d'esame: passata (collegabile a un appello già svolto del
  /// Calendario), possibile, o riportata dagli studenti.
  Future<Map<String, dynamic>?> _examDialog([Map<String, dynamic>? initial]) async {
    final p = context.palette;
    final pastExams = _maps(_draft['past_exams']);
    final text = TextEditingController(text: '${initial?['text'] ?? ''}');
    final solution = TextEditingController(text: '${initial?['solution'] ?? ''}');
    final source = TextEditingController(text: '${initial?['source'] ?? ''}');
    String kind = '${initial?['kind'] ?? 'possible'}';
    if (!_examKinds.any((k) => k.$1 == kind)) kind = 'possible';
    String? date = initial?['exam_date']?.toString();
    String? format = initial?['format']?.toString();
    int? eventId = _int(initial?['calendar_event_id']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: Text(initial == null ? 'Domanda d’esame' : 'Modifica domanda'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final k in _examKinds)
                    ChoiceChip(
                      avatar: Icon(k.$3, size: 16),
                      label: Text(k.$2),
                      selected: kind == k.$1,
                      onSelected: (_) => setLocal(() => kind = k.$1),
                    ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: text, minLines: 3, maxLines: 10, decoration: const InputDecoration(labelText: 'Domanda')),
                const SizedBox(height: 10),
                TextField(controller: solution, minLines: 2, maxLines: 10,
                    decoration: const InputDecoration(labelText: 'Soluzione o traccia di risposta (facoltativa)')),
                if (kind == 'past') ...[
                  const SizedBox(height: 12),
                  if (pastExams.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      value: pastExams.any((e) => _int(e['id']) == eventId) ? eventId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Appello del Calendario'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Nessun collegamento')),
                        for (final e in pastExams)
                          DropdownMenuItem<int?>(
                            value: _int(e['id']),
                            child: Text('${e['date'] ?? ''} · ${e['title'] ?? 'Appello'}', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setLocal(() {
                        eventId = v;
                        final picked = pastExams.where((e) => _int(e['id']) == v).firstOrNull;
                        if (picked != null) {
                          date = picked['date']?.toString();
                          format = picked['format']?.toString();
                        }
                      }),
                    )
                  else
                    Text('Nessun appello passato nel Calendario per questa materia: indica la data a mano.',
                        style: SlText.muted(p)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(date == null ? 'Data non indicata' : 'Data: $date${format != null ? ' · $format' : ''}',
                          style: SlText.body(p)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.tryParse(date ?? '') ?? now,
                          firstDate: DateTime(2000),
                          lastDate: now,
                        );
                        if (picked != null) {
                          setLocal(() {
                            date = picked.toIso8601String().substring(0, 10);
                            eventId = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: const Text('Scegli data'),
                    ),
                  ]),
                ],
                const SizedBox(height: 10),
                TextField(controller: source,
                    decoration: const InputDecoration(labelText: 'Fonte (es. scritto luglio 2025, prof. …)')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salva')),
          ],
        ),
      ),
    );
    final result = <String, dynamic>{
      'text': text.text.trim(),
      'kind': kind,
      if (solution.text.trim().isNotEmpty) 'solution': solution.text.trim(),
      if (source.text.trim().isNotEmpty) 'source': source.text.trim(),
      if (kind == 'past' && date != null) 'exam_date': date,
      if (kind == 'past' && format != null) 'format': format,
      if (kind == 'past' && eventId != null) 'calendar_event_id': eventId,
    };
    for (final c in [text, solution, source]) {
      c.dispose();
    }
    return ok == true && '${result['text']}'.isNotEmpty ? result : null;
  }

  Future<void> _searchBank() async {
    if (_subjectId == null) return;
    setState(() {
      _bankLoading = true;
      _bankSearched = true;
    });
    try {
      _bankResults = await _api.questionBank(_subjectId!, _bankQuery.text.trim());
    } catch (e) {
      _bankResults = [];
      _snack(faqError(e, 'Banca domande non disponibile.'));
    }
    if (mounted) setState(() => _bankLoading = false);
  }

  Future<void> _addLink() async {
    final item = await _itemDialog('Link', const [('title', 'Titolo', 1), ('url', 'Indirizzo (https://…)', 1)]);
    if (item == null) return;
    if (!'${item['url'] ?? ''}'.startsWith(RegExp(r'https?://'))) {
      _snack('L’indirizzo deve iniziare con http:// o https://');
      return;
    }
    setState(() {
      _resources.add({...item, 'type': 'url'});
      _dirty = true;
    });
  }

  // --- Pezzi di interfaccia ---------------------------------------------------

  Widget _panel(String? title, List<Widget> children, {Widget? trailing, Color? border}) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? p.pureWhite.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null) ...[
          Row(children: [Expanded(child: SlOverline(title)), if (trailing != null) trailing]),
          const SizedBox(height: 8),
        ],
        ...children,
      ]),
    );
  }

  Widget _itemTile(String title, String subtitle, {VoidCallback? onEdit, VoidCallback? onDelete, List<Widget> badges = const []}) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: p.darkElegance,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (badges.isNotEmpty) ...[Wrap(spacing: 5, runSpacing: 4, children: badges), const SizedBox(height: 5)],
            Text(title, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 13)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: SlText.muted(p).copyWith(fontSize: 12)),
            ],
          ]),
        ),
        if (_editable && onEdit != null)
          IconButton(tooltip: 'Modifica', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
        if (_editable && onDelete != null)
          IconButton(
            tooltip: 'Elimina',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: p.adminCoral),
          ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, {int minLines = 1, int maxLines = 1, String? hint}) => TextField(
        controller: c,
        readOnly: !_editable,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
      );

  Widget _header() {
    final p = context.palette;
    final update = _targetEntryId != null;
    final status = '${_draft['status']}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.07)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_term.text.isEmpty ? 'Senza termine' : _term.text,
                  style: TextStyle(color: p.pureWhite, fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Wrap(spacing: 5, runSpacing: 4, children: [
                SlStatusBadge(label: update ? 'Aggiorna un termine esistente' : 'Nuovo termine',
                    tone: update ? SlTone.warning : SlTone.info),
                if (status == 'approved') const SlStatusBadge(label: 'Pubblicato', tone: SlTone.success),
                if (status == 'rejected') const SlStatusBadge(label: 'Scartato', tone: SlTone.danger),
                if (_dirty) const SlStatusBadge(label: 'Modifiche non salvate', tone: SlTone.warning),
                if (_draft['author_name'] != null) SlStatusBadge(label: 'Da ${_draft['author_name']}'),
              ]),
              if (status != 'pending' && _draft['reviewed_by_name'] != null) ...[
                const SizedBox(height: 5),
                Text(
                  '${status == 'approved' ? 'Pubblicato' : 'Scartato'} da ${_draft['reviewed_by_name']}'
                  '${_draft['review_note'] != null ? ' · ${_draft['review_note']}' : ''}',
                  style: SlText.muted(p),
                ),
              ],
            ]),
          ),
          if (_editable && widget.wide) _actions(),
        ],
      ),
    );
  }

  Widget _actions() {
    final p = context.palette;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton.icon(
        onPressed: _busy ? null : _reject,
        style: OutlinedButton.styleFrom(foregroundColor: p.adminCoral),
        icon: const Icon(Icons.close_rounded, size: 18),
        label: const Text('Scarta'),
      ),
      OutlinedButton.icon(
        onPressed: _busy || !_dirty ? null : () => _save(),
        icon: const Icon(Icons.save_outlined, size: 18),
        label: const Text('Salva bozza'),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : () => _approve(),
        style: FilledButton.styleFrom(backgroundColor: p.adminGreen, foregroundColor: p.darkElegance),
        icon: _busy
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
            : const Icon(Icons.check_rounded, size: 18),
        label: Text(_targetEntryId != null ? 'Approva e aggiorna' : 'Approva e pubblica',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  /// Dove va il termine: materia, argomento, anno, docente.
  Widget _placement() {
    final p = context.palette;
    final topics = _maps(_draft['topics']);
    final teachers = _maps(_draft['teachers_available']);
    final subjectItems = <int, String>{
      for (final s in widget.subjects)
        if (_int(s['id']) != null) _int(s['id'])!: '${s['name']}${s['course'] != null ? ' · ${s['course']}' : ''}',
    };
    final current = _draft['subject'] is Map ? Map<String, dynamic>.from(_draft['subject'] as Map) : null;
    if (_subjectId != null && !subjectItems.containsKey(_subjectId)) {
      subjectItems[_subjectId!] = '${current?['name'] ?? 'Materia'}';
    }
    final wide = MediaQuery.sizeOf(context).width >= 700;
    Widget pair(Widget a, Widget b) => wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ])
        : Column(children: [a, const SizedBox(height: 10), b]);

    return _panel('Dove va', [
      pair(
        DropdownButtonFormField<int>(
          value: _subjectId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Materia', isDense: true),
          items: [
            for (final e in subjectItems.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _editable && !_busy ? _changeSubject : null,
        ),
        _field(_year, 'Anno accademico', hint: '2025/2026'),
      ),
      if (current != null) ...[
        const SizedBox(height: 6),
        Text(
          [current['department'], current['course'], current['university']].where((v) => v != null).join(' · '),
          style: SlText.muted(p).copyWith(fontSize: 11),
        ),
      ],
      const SizedBox(height: 10),
      pair(
        DropdownButtonFormField<int?>(
          value: topics.any((t) => _int(t['id']) == _topicId) && _newTopic.text.trim().isEmpty ? _topicId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Argomento', isDense: true),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Nessuno / nuovo')),
            for (final t in topics)
              DropdownMenuItem<int?>(value: _int(t['id']), child: Text('${t['title']}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _editable
              ? (v) => setState(() {
                    _topicId = v;
                    if (v != null) _newTopic.clear();
                    _dirty = true;
                  })
              : null,
        ),
        _field(_newTopic, 'Oppure nuovo argomento', hint: 'Creato quando approvi'),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<int?>(
        value: teachers.any((t) => _int(t['id']) == _teacherId) ? _teacherId : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Affidato al docente', isDense: true),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Nessuno')),
          for (final t in teachers)
            DropdownMenuItem<int?>(
              value: _int(t['id']),
              child: Text('${t['name']}${t['other_subject'] == true ? ' · altra materia' : ''}',
                  overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _editable
            ? (v) => setState(() {
                  _teacherId = v;
                  _dirty = true;
                })
            : null,
      ),
      const SizedBox(height: 4),
      Text('Il docente riceve una notifica alla pubblicazione e può curare il termine dalla sua area.',
          style: SlText.muted(p).copyWith(fontSize: 11)),
    ]);
  }

  Widget _definitions() => _panel('Termine e definizioni', [
        _field(_term, 'Termine'),
        const SizedBox(height: 10),
        _field(_aliases, 'Sinonimi (separati da virgola)'),
        const SizedBox(height: 10),
        _field(_formal, 'Definizione formale', minLines: 4, maxLines: 14),
        const SizedBox(height: 10),
        _field(_informal, 'Definizione informale (parole semplici)', minLines: 3, maxLines: 10),
      ]);

  Widget _practice() {
    final p = context.palette;
    return _panel('Esempi ed esercizi', [
      for (var i = 0; i < _examples.length; i++)
        _itemTile(
          '${_examples[i]['title'] ?? _examples[i]['body'] ?? ''}',
          _examples[i]['title'] != null ? '${_examples[i]['body'] ?? ''}' : '',
          badges: const [SlStatusBadge(label: 'Esempio', tone: SlTone.info)],
          onEdit: () async {
            final item = await _itemDialog('Esempio', const [('title', 'Titolo (facoltativo)', 1), ('body', 'Esempio', 4)], _examples[i]);
            if (item != null) setState(() {
              _examples[i] = item;
              _dirty = true;
            });
          },
          onDelete: () => setState(() {
            _examples.removeAt(i);
            _dirty = true;
          }),
        ),
      for (var i = 0; i < _exercises.length; i++)
        _itemTile(
          '${_exercises[i]['text'] ?? ''}',
          _exercises[i]['solution'] != null ? 'Soluzione: ${_exercises[i]['solution']}' : 'Senza soluzione',
          badges: [
            const SlStatusBadge(label: 'Esercizio', tone: SlTone.success),
            if (_exercises[i]['difficulty'] != null)
              SlStatusBadge(label: 'Difficoltà ${_exercises[i]['difficulty']}/5', tone: SlTone.warning),
          ],
          onEdit: () async {
            final item = await _itemDialog('Esercizio', _exerciseFields, _exercises[i]);
            if (item != null) setState(() {
              _exercises[i] = item;
              _dirty = true;
            });
          },
          onDelete: () => setState(() {
            _exercises.removeAt(i);
            _dirty = true;
          }),
        ),
      if (_examples.isEmpty && _exercises.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Nessun esempio o esercizio. Aggiungine uno per aiutare chi studia.', style: SlText.muted(p)),
        ),
      if (_editable)
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () async {
              final item = await _itemDialog('Esempio', const [('title', 'Titolo (facoltativo)', 1), ('body', 'Esempio', 4)]);
              if (item != null) setState(() {
                _examples.add(item);
                _dirty = true;
              });
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Esempio'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final item = await _itemDialog('Esercizio', _exerciseFields);
              if (item != null) setState(() {
                _exercises.add(item);
                _dirty = true;
              });
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Esercizio'),
          ),
        ]),
    ]);
  }

  static const _exerciseFields = [
    ('text', 'Testo dell’esercizio', 4),
    ('solution', 'Soluzione', 4),
    ('difficulty', 'Difficoltà 1–5', 1),
  ];

  Widget _examsPanel() {
    final p = context.palette;
    return _panel('Domande d’esame', [
      Text('Segna se è già uscita a un appello (collegala al Calendario), se è una domanda possibile o se viene dai '
          'racconti degli studenti.', style: SlText.muted(p).copyWith(fontSize: 12)),
      const SizedBox(height: 10),
      for (var i = 0; i < _exams.length; i++)
        _itemTile(
          '${_exams[i]['text'] ?? ''}',
          [
            if (_exams[i]['exam_date'] != null) 'Appello del ${_exams[i]['exam_date']}',
            if (_exams[i]['format'] != null) '${_exams[i]['format']}',
            if (_exams[i]['source'] != null) '${_exams[i]['source']}',
            if (_exams[i]['solution'] != null) 'con soluzione',
          ].join(' · '),
          badges: [
            switch ('${_exams[i]['kind']}') {
              'past' => const SlStatusBadge(label: 'Uscita all’esame', tone: SlTone.warning),
              'reports' => const SlStatusBadge(label: 'Dai racconti', tone: SlTone.info),
              _ => const SlStatusBadge(label: 'Possibile', tone: SlTone.success),
            },
            if (_exams[i]['calendar_event_id'] != null) const SlStatusBadge(label: 'Collegata al Calendario'),
          ],
          onEdit: () async {
            final item = await _examDialog(_exams[i]);
            if (item != null) setState(() {
              _exams[i] = item;
              _dirty = true;
            });
          },
          onDelete: () => setState(() {
            _exams.removeAt(i);
            _dirty = true;
          }),
        ),
      if (_editable)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final item = await _examDialog();
              if (item != null) setState(() {
                _exams.add(item);
                _dirty = true;
              });
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Domanda d’esame'),
          ),
        ),
    ]);
  }

  Widget _links() {
    final p = context.palette;
    final visibleResources = [
      for (var i = 0; i < _resources.length; i++) (i, _resources[i]),
    ];
    return Column(children: [
      _panel('Domande del quiz collegate', [
        if (_quizIds.isEmpty)
          Text('Nessuna. Cerca nella banca domande della materia (i file JSON del quiz).', style: SlText.muted(p))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in _quizIds)
              InputChip(
                label: Text('Domanda $id'),
                onDeleted: _editable ? () => setState(() {
                  _quizIds.remove(id);
                  _dirty = true;
                }) : null,
              ),
          ]),
        if (_quizSource != null) ...[
          const SizedBox(height: 6),
          Text('File: $_quizSource', style: SlText.muted(p).copyWith(fontSize: 11)),
        ],
        if (_editable) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _bankQuery,
            onSubmitted: (_) => _searchBank(),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Cerca nella banca domande',
              suffixIcon: IconButton(onPressed: _searchBank, icon: const Icon(Icons.search_rounded)),
            ),
          ),
          const SizedBox(height: 8),
          if (_bankLoading)
            Center(child: Padding(padding: const EdgeInsets.all(8), child: CircularProgressIndicator(color: p.skyBlue)))
          else if (_bankSearched && _bankResults.isEmpty)
            Text('Nessuna domanda trovata per questa materia.', style: SlText.muted(p))
          else
            for (final q in _bankResults)
              _bankTile(q),
        ],
      ]),
      _panel('Risorse', [
        for (final (i, r) in visibleResources)
          _itemTile(
            '${r['title'] ?? r['url'] ?? 'Risorsa'}',
            switch ('${r['type']}') {
              'url' => '${r['url'] ?? ''}',
              'material' => 'Dispense · ${((r['catalog_path'] as List?) ?? []).join(' › ')}',
              'source' => 'Fonte interna: non visibile agli studenti',
              _ => '',
            },
            badges: [if (r['type'] == 'source') const SlStatusBadge(label: 'Solo moderatori')],
            onDelete: () => setState(() {
              _resources.removeAt(i);
              _dirty = true;
            }),
          ),
        if (_editable)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(onPressed: _addLink, icon: const Icon(Icons.link_rounded, size: 18), label: const Text('Link')),
          ),
      ]),
      _panel('Termini collegati', [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in _related)
            InputChip(label: Text(r), onDeleted: _editable ? () => setState(() {
              _related.remove(r);
              _dirty = true;
            }) : null),
          if (_related.isEmpty) Text('Nessuno.', style: SlText.muted(p)),
        ]),
      ]),
    ]);
  }

  Widget _bankTile(Map<String, dynamic> q) {
    final p = context.palette;
    final id = q['id'];
    final linked = _quizIds.any((x) => '$x' == '$id');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: p.darkElegance,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${q['text']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: SlText.body(p).copyWith(fontSize: 13)),
            const SizedBox(height: 3),
            Text(['#$id', if (q['argument'] != null) '${q['argument']}'].join(' · '),
                style: SlText.muted(p).copyWith(fontSize: 11)),
          ]),
        ),
        TextButton(
          onPressed: id == null
              ? null
              : () => setState(() {
                    if (linked) {
                      _quizIds.removeWhere((x) => '$x' == '$id');
                    } else {
                      _quizIds.add(id);
                      _quizSource ??= q['quiz_source']?.toString();
                    }
                    _dirty = true;
                  }),
          child: Text(linked ? 'Scollega' : 'Collega'),
        ),
      ]),
    );
  }

  /// Da dove viene: fonte, riferimento, estratto del testo originale.
  Widget _provenance() {
    final p = context.palette;
    final source = _draft['source'] is Map ? Map<String, dynamic>.from(_draft['source'] as Map) : null;
    final excerpt = '${_draft['source_excerpt'] ?? ''}'.trim();
    return _panel('Provenienza', [
      if (source == null)
        Text(_draft['author_role'] == 'import' ? 'Import senza fonte registrata.' : 'Scritto nell’editor.',
            style: SlText.muted(p))
      else ...[
        Row(children: [
          SlIconTile(
            icon: switch ('${source['kind']}') {
              'pdf' => Icons.picture_as_pdf_outlined,
              'web' => Icons.public_rounded,
              'question_bank' => Icons.quiz_outlined,
              _ => Icons.data_object_rounded,
            },
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${source['label']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 13)),
              if (source['location'] != null)
                SelectableText('${source['location']}', maxLines: 2, style: SlText.muted(p).copyWith(fontSize: 11)),
            ]),
          ),
        ]),
      ],
      if (_draft['source_ref'] != null) ...[
        const SizedBox(height: 8),
        SlKeyValue(label: 'Punto', value: '${_draft['source_ref']}'),
      ],
      if (excerpt.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.darkElegance,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.adminAmber.withValues(alpha: 0.45)),
          ),
          child: SelectableText(excerpt, style: SlText.body(p).copyWith(fontSize: 12, height: 1.45)),
        ),
        const SizedBox(height: 4),
        Text('Testo originale da cui è stato estratto: confrontalo con la definizione.',
            style: SlText.muted(p).copyWith(fontSize: 11)),
      ],
    ]);
  }

  Widget _duplicates() {
    final p = context.palette;
    final dups = _maps(_draft['duplicates']);
    if (dups.isEmpty && _targetEntryId == null) return const SizedBox.shrink();
    return _panel('Forse esiste già', border: p.adminAmber.withValues(alpha: 0.35), [
      if (_targetEntryId != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
              child: Text('Questa bozza aggiorna un termine già pubblicato (nuova versione per l’anno scelto).',
                  style: SlText.body(p).copyWith(fontSize: 12)),
            ),
            if (_editable)
              TextButton(
                onPressed: () => setState(() {
                  _targetEntryId = null;
                  _dirty = true;
                }),
                child: const Text('Rendi nuovo'),
              ),
          ]),
        ),
      for (final d in dups)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.darkElegance,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text('${d['term']}', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              SlStatusBadge(
                label: '${((d['score'] as num? ?? 0) * 100).round()}% simile',
                tone: (d['score'] as num? ?? 0) >= 1 ? SlTone.danger : SlTone.warning,
              ),
            ]),
            if ('${d['preview'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${d['preview']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: SlText.muted(p).copyWith(fontSize: 12)),
            ],
            if (d['published_year'] != null)
              Text('A.A. ${d['published_year']}${d['author_name'] != null ? ' · ${d['author_name']}' : ''}',
                  style: SlText.muted(p).copyWith(fontSize: 11)),
            if (_editable) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() {
                    _targetEntryId = _int(d['entry_id']);
                    _dirty = true;
                  }),
                  child: const Text('Aggiorna questo termine'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _confirmMerge(d),
                  child: const Text('Unisci come sinonimo'),
                ),
              ]),
            ],
          ]),
        ),
    ]);
  }

  Future<void> _confirmMerge(Map<String, dynamic> d) async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: Text('Unire a “${d['term']}”?'),
        content: Text('“${_term.text}” diventa un sinonimo di “${d['term']}” e il contenuto di questa bozza diventa la '
            'versione pubblicata per l’anno ${_year.text}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Unisci e pubblica')),
        ],
      ),
    );
    if (ok == true) await _approve(mergeInto: _int(d['entry_id']));
  }

  Widget _published() {
    final p = context.palette;
    final published = _draft['published'] is Map ? Map<String, dynamic>.from(_draft['published'] as Map) : null;
    if (published == null) return const SizedBox.shrink();
    final before = '${published['formal_definition'] ?? published['informal_definition'] ?? ''}';
    return _panel('Ora pubblicato', [
      Text('A.A. ${published['academic_year']}${published['author_name'] != null ? ' · ${published['author_name']}' : ''}',
          style: SlText.muted(p).copyWith(fontSize: 11)),
      const SizedBox(height: 6),
      Text(before, maxLines: 8, overflow: TextOverflow.ellipsis, style: SlText.body(p).copyWith(fontSize: 12, height: 1.45)),
      const SizedBox(height: 6),
      Wrap(spacing: 5, runSpacing: 4, children: [
        SlStatusBadge(label: '${(published['examples'] as List? ?? []).length} esempi'),
        SlStatusBadge(label: '${(published['exercises'] as List? ?? []).length} esercizi'),
        SlStatusBadge(label: '${(published['exam_questions'] as List? ?? []).length} domande d’esame'),
      ]),
      const SizedBox(height: 4),
      Text('Resta visibile agli studenti finché non approvi questa bozza.', style: SlText.muted(p).copyWith(fontSize: 11)),
    ]);
  }

  Widget _tabs() => SlFilterBar<String>(
        selected: _tab,
        options: [
          SlFilterOption(value: 'definitions', label: 'Definizioni'),
          SlFilterOption(value: 'practice', label: 'Esempi ed esercizi', count: _examples.length + _exercises.length),
          SlFilterOption(value: 'exams', label: 'Domande d’esame', count: _exams.length),
          SlFilterOption(value: 'links', label: 'Collegamenti', count: _quizIds.length + _resources.length),
        ],
        onSelected: (v) => setState(() => _tab = v),
      );

  Widget _tabBody() => switch (_tab) {
        'practice' => _practice(),
        'exams' => _examsPanel(),
        'links' => _links(),
        _ => Column(children: [_definitions(), _placement()]),
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_loading && _draft.isEmpty) return Center(child: CircularProgressIndicator(color: p.skyBlue));
    if (_draft.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SlErrorCard(title: 'Attenzione', message: _error ?? 'Termine non disponibile.', onRetry: _load),
      );
    }
    final errorCard = _error == null
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.only(bottom: 12), child: SlErrorCard(title: 'Attenzione', message: _error!));
    final readOnlyNote = !_editable && _draft['status'] == 'pending'
        ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Solo lettura: non modera questa materia.', style: TextStyle(color: p.adminAmber)),
          )
        : const SizedBox.shrink();
    final side = [_provenance(), _duplicates(), _published()];

    if (widget.wide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(),
        const SizedBox(height: 12),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: ListView(children: [errorCard, readOnlyNote, _tabs(), const SizedBox(height: 10), _tabBody()]),
            ),
            const SizedBox(width: 14),
            SizedBox(width: 340, child: ListView(children: side)),
          ]),
        ),
      ]);
    }
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          _header(),
          const SizedBox(height: 12),
          errorCard,
          readOnlyNote,
          _provenance(),
          _duplicates(),
          _tabs(),
          const SizedBox(height: 10),
          _tabBody(),
          _published(),
        ]),
      ),
      if (_editable)
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: p.eleganceMidnight,
              border: Border(top: BorderSide(color: p.pureWhite.withValues(alpha: 0.08))),
            ),
            child: Row(children: [
              IconButton(
                tooltip: 'Scarta',
                onPressed: _busy ? null : _reject,
                icon: Icon(Icons.close_rounded, color: p.adminCoral),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || !_dirty ? null : () => _save(),
                  child: const Text('Salva bozza'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : () => _approve(),
                  style: FilledButton.styleFrom(backgroundColor: p.adminGreen, foregroundColor: p.darkElegance),
                  child: Text(_targetEntryId != null ? 'Approva e aggiorna' : 'Approva e pubblica',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}
