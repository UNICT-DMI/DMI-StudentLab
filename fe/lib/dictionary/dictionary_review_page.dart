import 'package:flutter/material.dart';

import '../faq/faq_widgets.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';

/// Revisione del Dizionario tra anni accademici (canvas: Dizionario ·
/// revisione anni). L'admin confronta il contenuto di un anno con quello
/// dell'anno prima e decide: uguale, diverso (va bene così), usa il testo
/// dell'anno prima, affida a un docente. "Porta al nuovo anno" copia i
/// termini di un anno nel successivo, da rivedere.
class DictionaryReviewPage extends StatefulWidget {
  final int? subjectId;

  const DictionaryReviewPage({super.key, this.subjectId});

  @override
  State<DictionaryReviewPage> createState() => _DictionaryReviewPageState();
}

class _DictionaryReviewPageState extends State<DictionaryReviewPage> {
  final DictionaryApiService _api = DictionaryApiService();
  List<Map<String, dynamic>> _subjects = [];
  int? _subjectId;
  String _state = 'to_review';
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _counts = {};
  bool _loading = true;
  String? _error;
  int? _busy;
  final Set<int> _expanded = <int>{};

  static const Map<String, String> _stateLabels = {
    'to_review': 'Da rivedere',
    'same_as_previous': 'Uguali all’anno prima',
    'changed': 'Diversi, confermati',
    'confirmed': 'Senza anno precedente',
  };

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjectId;
    _api.subjects().then((v) {
      if (mounted) setState(() => _subjects = v);
    }).catchError((_) {});
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.reviewQueue(subjectId: _subjectId, state: _state);
      _items = (data['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _counts = Map<String, dynamic>.from(data['counts'] as Map? ?? {});
      if (_items.isNotEmpty && _expanded.isEmpty) _expanded.add(int.parse('${_items.first['version_id']}'));
    } catch (e) {
      _error = faqError(e, 'Revisione non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _act(Map<String, dynamic> item, String action, {int? teacherId}) async {
    final id = int.parse('${item['version_id']}');
    setState(() => _busy = id);
    try {
      await _api.review(id, action, teacherUserId: teacherId);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Operazione non riuscita.'));
    }
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _assign(Map<String, dynamic> item) async {
    final p = context.palette;
    List<Map<String, dynamic>> teachers = [];
    try {
      teachers = await _api.subjectTeachers(int.parse('${item['subject_id']}'));
    } catch (_) {}
    if (!mounted) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            for (final t in teachers)
              ListTile(
                title: Text('${t['name']}'),
                subtitle: Text(t['other_subject'] == true ? 'Docente di altre materie' : 'Docente della materia',
                    style: SlText.muted(p)),
                onTap: () => Navigator.pop(sheetContext, int.parse('${t['id']}')),
              ),
          ]),
        ),
      ),
    );
    if (picked != null) await _act(item, 'assign_teacher', teacherId: picked);
  }

  Future<void> _rollover() async {
    final p = context.palette;
    if (_subjectId == null) {
      setState(() => _error = 'Scegli prima una materia.');
      return;
    }
    final from = TextEditingController();
    final to = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: const Text('Porta al nuovo anno'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: from, decoration: const InputDecoration(labelText: 'Dall’anno', hintText: '2025/2026')),
            const SizedBox(height: 10),
            TextField(controller: to, decoration: const InputDecoration(labelText: 'All’anno', hintText: '2026/2027')),
            const SizedBox(height: 10),
            Text('Copia i termini con autore e data originali; nel nuovo anno risultano “da rivedere”.',
                style: SlText.muted(p)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Copia')),
        ],
      ),
    );
    final fromYear = from.text.trim();
    final toYear = to.text.trim();
    from.dispose();
    to.dispose();
    if (ok != true) return;
    try {
      final result = await _api.rollover(_subjectId!, fromYear, toYear);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result['copied']} termini copiati nel ${result['to_year']}.')));
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = faqError(e, 'Copia non riuscita.'));
    }
  }

  Widget _column(String title, String author, String text, {bool highlight = false}) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.darkElegance,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? p.adminAmber.withValues(alpha: 0.4) : p.pureWhite.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: SlText.mono(p, size: 11, color: highlight ? p.adminAmber : null))),
          Text(author, style: SlText.muted(p).copyWith(fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        SelectableText(text.isEmpty ? '—' : text, style: SlText.body(p).copyWith(color: p.pureWhite, height: 1.5)),
      ]),
    );
  }

  Widget _item(Map<String, dynamic> item) {
    final p = context.palette;
    final id = int.parse('${item['version_id']}');
    final open = _expanded.contains(id);
    final current = Map<String, dynamic>.from(item['current'] as Map);
    final previous = item['previous'] is Map ? Map<String, dynamic>.from(item['previous'] as Map) : null;
    int count(Map<String, dynamic>? m, String k) => (m?[k] as List? ?? []).length;
    final changes = <String>[
      if (previous != null && count(current, 'exercises') != count(previous, 'exercises'))
        'Esercizi ${count(current, 'exercises') - count(previous, 'exercises') >= 0 ? '+' : ''}${count(current, 'exercises') - count(previous, 'exercises')}',
      if (previous != null && count(current, 'exam_questions') != count(previous, 'exam_questions'))
        'Domande d’esame ${count(current, 'exam_questions') - count(previous, 'exam_questions') >= 0 ? '+' : ''}${count(current, 'exam_questions') - count(previous, 'exam_questions')}',
      if (previous != null && count(current, 'examples') != count(previous, 'examples'))
        'Esempi ${count(current, 'examples') - count(previous, 'examples') >= 0 ? '+' : ''}${count(current, 'examples') - count(previous, 'examples')}',
    ];
    final busy = _busy == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.eleganceMidnight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: item['review_state'] == 'to_review' ? p.adminAmber.withValues(alpha: 0.24) : p.pureWhite.withValues(alpha: 0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => setState(() => open ? _expanded.remove(id) : _expanded.add(id)),
            child: Row(children: [
              Expanded(
                child: Text('${item['term']}', style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if ('${item['assigned_teacher_name'] ?? ''}'.isNotEmpty) ...[
                SlStatusBadge(label: 'Affidato a ${item['assigned_teacher_name']}', tone: SlTone.violet),
                const SizedBox(width: 6),
              ],
              SlStatusBadge(label: _stateLabels[item['review_state']] ?? '${item['review_state']}',
                  tone: item['review_state'] == 'to_review' ? SlTone.warning : SlTone.neutral),
              const SizedBox(width: 6),
              SlStatusBadge(label: '${item['subject_name'] ?? ''}', tone: SlTone.info),
              Icon(open ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, color: p.pureWhite.withValues(alpha: 0.5)),
            ]),
          ),
          if (open) ...[
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final left = previous == null
                  ? _column('Nessun anno precedente', '', '')
                  : _column('A.A. ${previous['academic_year']}', '${previous['author_name'] ?? ''}',
                      '${previous['formal_definition'] ?? previous['informal_definition'] ?? ''}');
              final right = _column('A.A. ${item['academic_year']}', '${item['author_name'] ?? ''}',
                  '${current['formal_definition'] ?? current['informal_definition'] ?? ''}', highlight: true);
              return c.maxWidth >= 700
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: left),
                      const SizedBox(width: 10),
                      Expanded(child: right),
                    ])
                  : Column(children: [left, const SizedBox(height: 8), right]);
            }),
            if (changes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Text('Cambia anche:', style: SlText.muted(p)),
                for (final ch in changes) SlStatusBadge(label: ch, tone: SlTone.warning),
              ]),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                onPressed: busy ? null : () => _act(item, 'same_as_previous'),
                child: const Text('Uguale all’anno prima'),
              ),
              if (previous != null)
                OutlinedButton(
                  onPressed: busy ? null : () => _act(item, 'copy_previous'),
                  child: const Text('Usa il testo dell’anno prima'),
                ),
              OutlinedButton(onPressed: busy ? null : () => _assign(item), child: const Text('Affida a un docente')),
              FilledButton(
                onPressed: busy ? null : () => _act(item, previous == null ? 'confirm' : 'changed'),
                child: Text(previous == null ? 'Conferma' : 'Diverso: va bene così'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: slAdminAppBar(context, title: 'Revisione del dizionario', actions: [
        TextButton.icon(
          onPressed: _rollover,
          icon: const Icon(Icons.forward_rounded),
          label: const Text('Porta al nuovo anno'),
        ),
        IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_error != null) ...[SlErrorCard(title: 'Attenzione', message: _error!), const SizedBox(height: 12)],
            DropdownButtonFormField<int?>(
              value: _subjects.any((s) => s['id'] == _subjectId) ? _subjectId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Materia'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Tutte le materie')),
                for (final s in _subjects)
                  DropdownMenuItem<int?>(value: s['id'] as int?, child: Text('${s['name']} · ${s['course'] ?? ''}')),
              ],
              onChanged: (v) {
                setState(() => _subjectId = v);
                _load();
              },
            ),
            const SizedBox(height: 12),
            SlFilterBar<String>(
              selected: _state,
              options: [
                for (final e in _stateLabels.entries)
                  SlFilterOption(value: e.key, label: e.value, count: int.tryParse('${_counts[e.key] ?? 0}')),
              ],
              onSelected: (v) {
                setState(() => _state = v);
                _load();
              },
            ),
            const SizedBox(height: 14),
            if (_loading)
              Padding(padding: const EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: p.skyBlue)))
            else if (_items.isEmpty)
              const SlEmptyState(icon: Icons.task_alt_rounded, title: 'Niente da rivedere', message: 'Qui compaiono i termini di questo stato.')
            else
              for (final item in _items) _item(item),
          ]),
        ),
      ),
    );
  }
}
