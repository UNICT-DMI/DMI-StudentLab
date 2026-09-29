import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../faq/faq_widgets.dart';
import '../material/StudentMaterialPage.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';
import 'dictionary_editor_page.dart';

/// Termine del Dizionario (canvas: Dizionario · termine).
class DictionaryEntryPage extends StatefulWidget {
  final int entryId;
  final String? year;

  const DictionaryEntryPage({super.key, required this.entryId, this.year});

  @override
  State<DictionaryEntryPage> createState() => _DictionaryEntryPageState();
}

class _DictionaryEntryPageState extends State<DictionaryEntryPage> {
  final DictionaryApiService _api = DictionaryApiService();
  Map<String, dynamic>? _data;
  String? _year;
  bool _loading = true;
  String? _error;
  bool _formal = true;
  bool _saved = false;
  final Set<int> _solutions = <int>{};

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await _api.entry(widget.entryId, year: _year);
      _year = _data?['year']?.toString();
      final entry = Map<String, dynamic>.from(_data!['entry'] as Map);
      final summary = {'id': entry['id'], 'term': entry['term'], 'subject_name': entry['subject_name']};
      await DictionaryLocalStore.addRecent(summary);
      _saved = await DictionaryLocalStore.isSaved(widget.entryId);
      final version = Map<String, dynamic>.from(_data!['version'] as Map);
      if ('${version['formal_definition'] ?? ''}'.isEmpty) _formal = false;
    } catch (e) {
      _error = faqError(e, 'Termine non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleSaved() async {
    final entry = Map<String, dynamic>.from(_data!['entry'] as Map);
    final saved = await DictionaryLocalStore.toggleSaved(
        {'id': entry['id'], 'term': entry['term'], 'subject_name': entry['subject_name']});
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _openResource(Map<String, dynamic> resource) async {
    final url = '${resource['url'] ?? ''}';
    if (url.startsWith('http')) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StudentMaterialPage()));
    }
  }

  Future<void> _quiz() async {
    List<Map<String, dynamic>> questions = [];
    try {
      questions = await _api.quiz(widget.entryId, year: _year);
    } catch (_) {}
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Domande non disponibili per questo termine.')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _QuizSheet(term: '${(_data!['entry'] as Map)['term']}', questions: questions),
    );
  }

  Widget _section(String title, List<Widget> children, {int? count}) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(title, style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700))),
          if (count != null) Text('$count', style: SlText.mono(p, size: 11)),
        ]),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _box(List<Widget> children) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final data = _data;
    if (_loading && data == null) {
      return Scaffold(backgroundColor: p.darkElegance, body: Center(child: CircularProgressIndicator(color: p.skyBlue)));
    }
    if (_error != null || data == null) {
      return Scaffold(
        backgroundColor: p.darkElegance,
        appBar: AppBar(backgroundColor: p.eleganceMidnight, foregroundColor: p.pureWhite),
        body: Padding(padding: const EdgeInsets.all(16), child: SlErrorCard(title: 'Errore', message: _error ?? '', onRetry: _load)),
      );
    }
    final entry = Map<String, dynamic>.from(data['entry'] as Map);
    final v = Map<String, dynamic>.from(data['version'] as Map);
    List<Map<String, dynamic>> list(String key) =>
        (v[key] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final examples = list('examples');
    final exercises = list('exercises');
    final exams = list('exam_questions');
    final resources = list('resources');
    final related = (data['related'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final years = (data['years'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final teachers = (v['teachers'] as List? ?? []).map((e) => '$e').toList();
    final aliases = (entry['aliases'] as List? ?? []).map((e) => '$e').toList();
    final bool older = v['academic_year'] != _year;
    final String definition = '${(_formal ? v['formal_definition'] : v['informal_definition']) ?? ''}';
    final updated = DateTime.tryParse('${v['updated_at']}')?.toLocal();
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: const Text('Termine'),
        actions: [
          IconButton(
            tooltip: _saved ? 'Togli dai salvati' : 'Salva il termine',
            onPressed: _toggleSaved,
            icon: Icon(_saved ? Icons.star_rounded : Icons.star_outline_rounded, color: _saved ? p.adminAmber : null),
          ),
          if (data['can_edit'] == true)
            IconButton(
              tooltip: 'Modifica',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => DictionaryEditorPage(
                      subjectId: int.parse('${entry['subject_id']}'), entryId: widget.entryId, year: _year),
                ));
                if (mounted) await _load();
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
              Text('${entry['subject_name']}${entry['topic'] != null ? ' › ${entry['topic']}' : ''}',
                  style: SlText.mono(p, size: 11, color: p.materialSky)),
              const SizedBox(height: 6),
              Text('${entry['term']}', style: TextStyle(color: p.pureWhite, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (entry['topic'] != null) SlStatusBadge(label: '${entry['topic']}', tone: SlTone.info),
                if (exams.isNotEmpty) const SlStatusBadge(label: 'Chiesto all’esame', tone: SlTone.warning),
                if (years.length > 1)
                  ActionChip(
                    label: Text('A.A. ${v['academic_year']} ▾'),
                    onPressed: () async {
                      final picked = await showModalBottomSheet<String>(
                        context: context,
                        backgroundColor: p.eleganceDeepNavy,
                        builder: (sheetContext) => SafeArea(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            for (final y in years)
                              ListTile(
                                title: Text('A.A. ${y['year']}'),
                                subtitle: Text('${y['author_name'] ?? ''}', style: SlText.muted(p)),
                                onTap: () => Navigator.pop(sheetContext, '${y['year']}'),
                              ),
                          ]),
                        ),
                      );
                      if (picked != null) {
                        _year = picked;
                        await _load();
                      }
                    },
                  )
                else
                  SlStatusBadge(label: 'A.A. ${v['academic_year']}'),
              ]),
              const SizedBox(height: 6),
              Text(
                [
                  if (teachers.isNotEmpty) 'Docenti ${v['academic_year']}: ${teachers.join(', ')}',
                  if (aliases.isNotEmpty) 'anche detto “${aliases.join('”, “')}”',
                ].join(' · '),
                style: SlText.muted(p).copyWith(fontSize: 12),
              ),
              if (older) ...[
                const SizedBox(height: 6),
                Text('Per l’A.A. $_year non c’è una versione nuova: vedi quella del ${v['academic_year']}.',
                    style: SlText.muted(p).copyWith(color: p.adminAmber, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.eleganceDeepNavy,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.materialSky.withValues(alpha: 0.30)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SlFilterBar<bool>(
                    selected: _formal,
                    options: const [
                      SlFilterOption(value: true, label: 'Formale'),
                      SlFilterOption(value: false, label: 'Informale'),
                    ],
                    onSelected: (value) => setState(() => _formal = value),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    definition.isEmpty ? 'Definizione non ancora disponibile.' : definition,
                    style: SlText.body(p).copyWith(color: p.pureWhite, fontSize: 15, height: 1.6),
                  ),
                ]),
              ),
              if (examples.isNotEmpty)
                _section('Esempi', [
                  for (final e in examples)
                    _box([
                      if ('${e['title'] ?? ''}'.isNotEmpty)
                        Text('${e['title']}', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
                      SelectableText('${e['body'] ?? ''}', style: SlText.body(p).copyWith(height: 1.5)),
                    ]),
                ], count: examples.length),
              if (exercises.isNotEmpty)
                _section('Esercizi', [
                  for (var i = 0; i < exercises.length; i++)
                    _box([
                      if (exercises[i]['difficulty'] != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SlStatusBadge(label: 'Difficoltà ${exercises[i]['difficulty']}/5', tone: SlTone.warning),
                        ),
                        const SizedBox(height: 6),
                      ],
                      SelectableText('${exercises[i]['text'] ?? ''}', style: SlText.body(p).copyWith(color: p.pureWhite, height: 1.5)),
                      if ('${exercises[i]['solution'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        if (_solutions.contains(i))
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: p.adminGreen.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SelectableText('${exercises[i]['solution']}', style: SlText.body(p).copyWith(height: 1.5)),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => setState(() => _solutions.add(i)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.adminGreen,
                              side: BorderSide(color: p.adminGreen.withValues(alpha: 0.36)),
                            ),
                            child: const Text('Mostra la soluzione'),
                          ),
                      ],
                    ]),
                ], count: exercises.length),
              if (exams.isNotEmpty)
                _section('Domande d’esame possibili', [
                  for (final q in exams)
                    _box([
                      SelectableText('${q['text'] ?? ''}', style: SlText.body(p).copyWith(color: p.pureWhite, height: 1.45)),
                      if ('${q['kind'] ?? ''}${q['source'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SlStatusBadge(
                              label: [q['kind'], q['source']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '),
                              tone: SlTone.warning),
                        ),
                      ],
                    ]),
                ], count: exams.length),
              if (resources.isNotEmpty)
                _section('Lezioni e file', [
                  for (final r in resources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: p.eleganceMidnight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: p.adminCyan.withValues(alpha: 0.20)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openResource(r),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(children: [
                              SlIconTile(
                                  icon: '${r['url'] ?? ''}'.startsWith('http') ? Icons.link_rounded : Icons.description_outlined,
                                  tone: SlTone.cyan,
                                  size: 36),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${r['title'] ?? r['url'] ?? 'Materiale'}',
                                      style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
                                  Text(
                                    '${r['url'] ?? ''}'.startsWith('http')
                                        ? '${r['url']}'
                                        : 'Dispense${r['catalog_path'] is List ? ' › ${(r['catalog_path'] as List).join(' › ')}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SlText.muted(p).copyWith(fontSize: 11),
                                  ),
                                ]),
                              ),
                              Text('Apri', style: TextStyle(color: p.adminCyan, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ], count: resources.length),
              if ((int.tryParse('${v['quiz_count']}') ?? 0) > 0) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _quiz,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.skyBlue,
                    foregroundColor: p.darkElegance,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Text('Mettiti alla prova · ${v['quiz_count']} ${v['quiz_count'] == 1 ? 'domanda' : 'domande'}'),
                ),
              ],
              if (related.isNotEmpty)
                _section('Termini collegati', [
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final r in related)
                      ActionChip(
                        label: Text('${r['term']}'),
                        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                          builder: (_) => DictionaryEntryPage(entryId: int.parse('${r['id']}'), year: _year),
                        )),
                      ),
                  ]),
                ]),
              const SizedBox(height: 18),
              Text(
                'Scritto da ${v['author_name'] ?? 'StudentLab'}'
                '${updated != null ? ' · ${updated.day.toString().padLeft(2, '0')}/${updated.month.toString().padLeft(2, '0')}/${updated.year}' : ''}'
                '${'${v['assigned_teacher_name'] ?? ''}'.isNotEmpty ? ' · affidato a ${v['assigned_teacher_name']}' : ''}',
                style: SlText.muted(p).copyWith(fontSize: 12),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Mettiti alla prova": le domande del quiz collegate al termine.
class _QuizSheet extends StatefulWidget {
  final String term;
  final List<Map<String, dynamic>> questions;

  const _QuizSheet({required this.term, required this.questions});

  @override
  State<_QuizSheet> createState() => _QuizSheetState();
}

class _QuizSheetState extends State<_QuizSheet> {
  int _index = 0;
  String? _chosen;
  int _correct = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = _index >= widget.questions.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: done
              ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Risultato', style: TextStyle(color: p.pureWhite, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('$_correct su ${widget.questions.length} risposte giuste.', style: SlText.body(p)),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
                ])
              : _question(p, widget.questions[_index]),
        ),
      ),
    );
  }

  Widget _question(AppPalette p, Map<String, dynamic> q) {
    final options = (q['options'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final correct = '${q['correct']}';
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text('Mettiti alla prova · ${widget.term}',
              style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Text('${_index + 1} / ${widget.questions.length}', style: SlText.mono(p, size: 12)),
      ]),
      const SizedBox(height: 10),
      LinearProgressIndicator(
        value: (_index + 1) / widget.questions.length,
        minHeight: 4,
        backgroundColor: p.pureWhite.withValues(alpha: 0.08),
        valueColor: AlwaysStoppedAnimation(p.skyBlue),
      ),
      const SizedBox(height: 12),
      Text('${q['text']}', style: SlText.body(p).copyWith(color: p.pureWhite, fontSize: 15, height: 1.45)),
      const SizedBox(height: 12),
      for (final o in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: _chosen == null
                ? Colors.transparent
                : ('${o['id']}' == correct
                    ? p.adminGreen.withValues(alpha: 0.10)
                    : ('${o['id']}' == _chosen ? p.adminCoral.withValues(alpha: 0.08) : Colors.transparent)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _chosen == null
                    ? p.pureWhite.withValues(alpha: 0.12)
                    : ('${o['id']}' == correct
                        ? p.adminGreen.withValues(alpha: 0.5)
                        : ('${o['id']}' == _chosen ? p.adminCoral.withValues(alpha: 0.5) : p.pureWhite.withValues(alpha: 0.12))),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _chosen != null
                  ? null
                  : () => setState(() {
                        _chosen = '${o['id']}';
                        if (_chosen == correct) _correct++;
                      }),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o['id']}', style: SlText.mono(p, size: 12, weight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${o['text']}', style: SlText.body(p).copyWith(color: p.pureWhite))),
                ]),
              ),
            ),
          ),
        ),
      if (_chosen != null) ...[
        if ('${q['explanation'] ?? ''}'.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.adminGreen.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
            child: Text('${q['explanation']}', style: SlText.body(p).copyWith(height: 1.45)),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() {
            _index++;
            _chosen = null;
          }),
          child: Text(_index + 1 >= widget.questions.length ? 'Vedi il risultato' : 'Prossima domanda'),
        ),
      ],
    ]);
  }
}
