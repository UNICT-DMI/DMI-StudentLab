import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'faq_api_service.dart';
import 'faq_widgets.dart';

const Map<String, String> _formats = {
  'scritto': 'Scritto',
  'orale': 'Orale',
  'scritto_orale': 'Scritto + orale',
  'progetto': 'Progetto',
};

/// "Com'è l'esame" (canvas: Domande degli studenti · 4).
class FaqExamPage extends StatefulWidget {
  final int subjectId;
  final String? subjectName;

  const FaqExamPage({super.key, required this.subjectId, this.subjectName});

  @override
  State<FaqExamPage> createState() => _FaqExamPageState();
}

class _FaqExamPageState extends State<FaqExamPage> {
  final FaqApiService _api = FaqApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _format = 'tutti';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.examSummary(widget.subjectId);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = faqError(e, 'Informazioni non disponibili.');
        });
      }
    }
  }

  Future<void> _tell() async {
    if (!_api.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accedi per raccontare il tuo esame.')));
      return;
    }
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _ExamReportFormPage(subjectId: widget.subjectId, subjectName: widget.subjectName),
    ));
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Grazie! Il racconto sarà visibile dopo il controllo di StudentLab.'),
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final data = _data;
    final subject = data?['subject'] is Map ? data!['subject'] as Map : null;
    final int count = int.tryParse('${data?['reports_count']}') ?? 0;
    final topics = (data?['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final reports = (data?['reports'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((r) => _format == 'tutti' || r['format'] == _format)
        .toList();
    final teachers = (data?['teachers'] as List? ?? []).map((e) => '$e').toList();
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: const Text('Com’è l’esame'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tell,
        backgroundColor: p.skyBlue,
        foregroundColor: p.darkElegance,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Racconta il tuo esame', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: p.skyBlue))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: SlErrorCard(title: 'Non disponibile', message: _error!, onRetry: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: p.eleganceDeepNavy,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: p.materialSky.withValues(alpha: 0.30)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text('${subject?['course'] ?? ''} › ${subject?['name'] ?? widget.subjectName ?? ''}',
                                  style: SlText.mono(p, size: 11, color: p.materialSky)),
                              const SizedBox(height: 6),
                              Text(
                                teachers.isEmpty
                                    ? '${subject?['name'] ?? widget.subjectName ?? 'Materia'}'
                                    : '${subject?['name'] ?? widget.subjectName ?? 'Materia'} · ${teachers.join(', ')}',
                                style: TextStyle(color: p.pureWhite, fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Row(children: [
                                _stat(p, 'Formato', _formats[data?['main_format']] ?? '—'),
                                const SizedBox(width: 8),
                                _stat(p, 'Durata', data?['average_duration'] == null ? '—' : '~${data!['average_duration']} min'),
                                const SizedBox(width: 8),
                                _stat(p, 'Racconti', '$count'),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                'Dai racconti degli studenti degli ultimi tre anni. Non sono informazioni ufficiali.',
                                style: SlText.muted(p).copyWith(fontSize: 11),
                              ),
                              if ((int.tryParse('${data?['mine_pending']}') ?? 0) > 0) ...[
                                const SizedBox(height: 8),
                                const SlStatusBadge(label: 'Il tuo racconto è in revisione', tone: SlTone.warning),
                              ],
                            ]),
                          ),
                          const SizedBox(height: 18),
                          if (count == 0)
                            const SlEmptyState(
                              icon: Icons.event_note_outlined,
                              title: 'Ancora nessun racconto',
                              message: 'Hai già sostenuto questo esame? Racconta com’è andato: aiuta chi lo prepara.',
                            )
                          else ...[
                            const SlOverline('Argomenti chiesti più spesso'),
                            const SizedBox(height: 10),
                            for (final t in topics) _topicBar(p, t, count),
                            const SizedBox(height: 18),
                            Row(children: [
                              Expanded(
                                child: Text('Racconti degli appelli',
                                    style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            SlFilterBar<String>(
                              selected: _format,
                              options: [
                                const SlFilterOption(value: 'tutti', label: 'Tutti'),
                                for (final e in _formats.entries) SlFilterOption(value: e.key, label: e.value),
                              ],
                              onSelected: (v) => setState(() => _format = v),
                            ),
                            const SizedBox(height: 10),
                            for (final r in reports) _report(p, r),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _stat(AppPalette p, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: SlText.muted(p).copyWith(fontSize: 11)),
            Text(value, style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _topicBar(AppPalette p, Map<String, dynamic> t, int total) {
    final int n = int.tryParse('${t['count']}') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${t['label']}', style: TextStyle(color: p.pureWhite, fontSize: 13))),
          Text('$n su $total', style: SlText.mono(p, size: 11)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : n / total,
            minHeight: 8,
            backgroundColor: p.pureWhite.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(p.skyBlue),
          ),
        ),
      ]),
    );
  }

  Widget _report(AppPalette p, Map<String, dynamic> r) {
    final author = r['author'] is Map ? r['author'] as Map : null;
    final date = DateTime.tryParse('${r['exam_date']}');
    const months = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];
    final when = date == null ? '' : 'Appello di ${months[date.month - 1]} ${date.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.eleganceMidnight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            faqAvatar(context, '${author?['name'] ?? 'Studente'}', size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$when · ${_formats[r['format']] ?? ''}',
                  style: SlText.body(p).copyWith(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 5, runSpacing: 5, children: [
            for (final t in (r['topics'] as List? ?? [])) SlStatusBadge(label: '$t', tone: SlTone.info),
            if (r['difficulty'] != null) SlStatusBadge(label: 'Difficoltà ${r['difficulty']}/5', tone: SlTone.warning),
            if (r['duration_minutes'] != null) SlStatusBadge(label: '${r['duration_minutes']} min'),
          ]),
          if ((r['body']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r['body'].toString(), style: SlText.body(p).copyWith(fontSize: 13, height: 1.5, color: p.pureWhite)),
          ],
        ]),
      ),
    );
  }
}

/// "Racconta il tuo esame": pubblicato dopo il controllo di StudentLab.
class _ExamReportFormPage extends StatefulWidget {
  final int subjectId;
  final String? subjectName;

  const _ExamReportFormPage({required this.subjectId, this.subjectName});

  @override
  State<_ExamReportFormPage> createState() => _ExamReportFormPageState();
}

class _ExamReportFormPageState extends State<_ExamReportFormPage> {
  final FaqApiService _api = FaqApiService();
  final TextEditingController _topic = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final List<String> _topics = [];
  DateTime? _date;
  String _format = 'orale';
  int? _difficulty;
  bool _anonymous = true;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _topic.dispose();
    _duration.dispose();
    _body.dispose();
    super.dispose();
  }

  void _addTopic() {
    final t = _topic.text.trim();
    if (t.isEmpty || _topics.length >= 10 || _topics.any((e) => e.toLowerCase() == t.toLowerCase())) return;
    setState(() {
      _topics.add(t.length > 60 ? t.substring(0, 60) : t);
      _topic.clear();
    });
  }

  Future<void> _send() async {
    if (_date == null) {
      setState(() => _error = 'Indica la data dell’appello.');
      return;
    }
    if (_difficulty == null) {
      setState(() => _error = 'Seleziona la difficoltà dell’esame.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _api.createExamReport(
        subjectId: widget.subjectId,
        examDate: _date!,
        format: _format,
        durationMinutes: int.tryParse(_duration.text.trim()),
        difficulty: _difficulty!,
        topics: _topics,
        body: _body.text,
        anonymous: _anonymous,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = faqError(e, 'Racconto non inviato.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text('Racconta: ${widget.subjectName ?? 'esame'}'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_error != null) ...[
              SlErrorCard(title: 'Racconto non inviato', message: _error!),
              const SizedBox(height: 12),
            ],
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now,
                  firstDate: now.subtract(const Duration(days: 3 * 365)),
                  lastDate: now,
                  helpText: 'Data dell’appello (già svolto)',
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data dell’appello'),
                child: Text(
                  _date == null
                      ? 'Scegli la data'
                      : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
                  style: SlText.body(p).copyWith(color: p.pureWhite),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Formato', style: SlText.muted(p)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _formats.entries)
                ChoiceChip(label: Text(e.value), selected: _format == e.key, onSelected: (_) => setState(() => _format = e.key)),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Durata in minuti (facoltativa)'),
            ),
            const SizedBox(height: 14),
            Text('Difficoltà', style: SlText.muted(p)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (var i = 1; i <= 5; i++)
                ChoiceChip(label: Text('$i'), selected: _difficulty == i, onSelected: (_) => setState(() => _difficulty = i)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _topic,
                  onSubmitted: (_) => _addTopic(),
                  decoration: const InputDecoration(labelText: 'Argomento chiesto (es. Dijkstra)'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(tooltip: 'Aggiungi argomento', onPressed: _addTopic, icon: const Icon(Icons.add_rounded)),
            ]),
            if (_topics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in _topics) InputChip(label: Text(t), onDeleted: () => setState(() => _topics.remove(t))),
              ]),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 8,
              maxLength: 3000,
              decoration: const InputDecoration(
                labelText: 'Com’è andata (facoltativo)',
                hintText: 'Cosa ha chiesto, come si è svolto, un consiglio per chi lo prepara.',
                alignLabelWithHint: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
              title: Text('Racconta in forma anonima', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
              subtitle: Text('Gli studenti vedono “Studente del N° anno”.', style: SlText.muted(p)),
            ),
            const SizedBox(height: 8),
            Text(
              'Racconta solo appelli già conclusi. Niente testi completi delle prove e niente giudizi personali sui docenti: StudentLab controlla ogni racconto prima di pubblicarlo.',
              style: SlText.muted(p).copyWith(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: p.skyBlue,
                foregroundColor: p.darkElegance,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: _sending
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
                  : const Text('Invia racconto'),
            ),
          ]),
        ),
      ),
    );
  }
}
