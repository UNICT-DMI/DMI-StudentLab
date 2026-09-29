import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'faq_api_service.dart';
import 'faq_question_page.dart';
import 'faq_widgets.dart';

/// "Fai una domanda" (canvas: Domande · nuova).
///
/// Materia (dal filtro attivo o da scegliere), categoria, domanda in una riga
/// con "Forse ha già una risposta" mentre scrivi, dettagli, forma anonima e
/// "Chiedi anche al docente". La domanda viene controllata prima di essere
/// pubblicata.
class FaqNewQuestionPage extends StatefulWidget {
  final int? subjectId;
  final String? university;
  final String? department;
  final String? course;

  const FaqNewQuestionPage({super.key, this.subjectId, this.university, this.department, this.course});

  @override
  State<FaqNewQuestionPage> createState() => _FaqNewQuestionPageState();
}

class _FaqNewQuestionPageState extends State<FaqNewQuestionPage> {
  final FaqApiService _api = FaqApiService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _similar = [];
  int? _subjectId;
  String _category = 'exams';
  bool _anonymous = true;
  bool _askTeacher = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjectId;
    _api.filters().then((value) {
      if (mounted) setState(() => _subjects = value);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Materie del contesto scelto nella home (corso), altrimenti tutte.
  List<Map<String, dynamic>> get _subjectOptions {
    final inCourse = _subjects
        .where((s) =>
            (widget.university == null || s['university'] == widget.university) &&
            (widget.department == null || s['department'] == widget.department) &&
            (widget.course == null || s['course'] == widget.course))
        .toList();
    return inCourse.isEmpty ? _subjects : inCourse;
  }

  Map<String, dynamic>? get _subject => _subjects.where((s) => s['id'] == _subjectId).firstOrNull;

  void _onTitle(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final found = await _api.suggestions(_title.text, subjectId: _subjectId);
        if (mounted) setState(() => _similar = found);
      } catch (_) {}
    });
    setState(() {});
  }

  Future<void> _pickSubject() async {
    final p = context.palette;
    final options = _subjectOptions;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            ListTile(
              leading: const Icon(Icons.public_rounded),
              title: const Text('Nessuna materia (domanda generale)'),
              onTap: () => Navigator.pop(sheetContext, -1),
            ),
            for (final s in options)
              ListTile(
                title: Text('${s['name']}'),
                subtitle: Text('${s['course']} · ${s['department_code'] ?? s['department']}', style: SlText.muted(p)),
                onTap: () => Navigator.pop(sheetContext, s['id'] as int),
              ),
          ]),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _subjectId = picked == -1 ? null : picked;
        if (_subjectId == null) _askTeacher = false;
      });
    }
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.length < 8) {
      setState(() => _error = 'Scrivi la domanda in una riga (almeno 8 caratteri).');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _api.createQuestion(
        title: title,
        body: _body.text,
        category: _category,
        subjectId: _subjectId,
        university: _subjectId == null ? widget.university : null,
        department: _subjectId == null ? widget.department : null,
        course: _subjectId == null ? widget.course : null,
        anonymous: _anonymous,
        askTeacher: _askTeacher,
      );
      if (!mounted) return;
      final p = context.palette;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('Domanda inviata'),
          content: Text(
            'StudentLab la controlla prima di pubblicarla: riceverai una notifica. '
            'Intanto la trovi in “Le mie domande”.',
            style: SlText.body(p),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ok'))],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = faqError(e, 'Domanda non inviata.');
        });
      }
    }
  }

  Widget _switchRow(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) {
    final p = context.palette;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: SlText.muted(p)),
        ]),
      ),
      Switch(value: value, onChanged: onChanged),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final subject = _subject;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: const Text('Fai una domanda'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(backgroundColor: p.skyBlue, foregroundColor: p.darkElegance),
              child: _sending
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
                  : const Text('Invia', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (_error != null) ...[
                SlErrorCard(title: 'Attenzione', message: _error!),
                const SizedBox(height: 12),
              ],
              Text('Di cosa parla', style: SlText.muted(p)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ActionChip(
                  avatar: const Icon(Icons.menu_book_outlined, size: 16),
                  label: Text(subject == null ? 'Scegli la materia' : '${subject['name']}'),
                  onPressed: _pickSubject,
                ),
                for (final (id, label, _, _) in faqCategories)
                  ChoiceChip(
                    label: Text(label),
                    selected: _category == id,
                    onSelected: (_) => setState(() => _category = id),
                  ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                onChanged: _onTitle,
                maxLength: 200,
                style: TextStyle(color: p.pureWhite),
                decoration: InputDecoration(
                  labelText: 'La tua domanda in una riga',
                  hintText: 'Es. Come funziona l’orale di Reti?',
                  filled: true,
                  fillColor: p.eleganceMidnight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_similar.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.adminGreen.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.adminGreen.withValues(alpha: 0.28)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Forse ha già una risposta',
                        style: TextStyle(color: p.adminGreen, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final s in _similar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: p.eleganceMidnight,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => FaqQuestionPage(questionId: int.parse('${s['id']}')))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(children: [
                                Expanded(child: Text('${s['title']}', style: SlText.body(p).copyWith(color: p.pureWhite))),
                                Text(s['has_verified_answer'] == true ? 'verificata' : '${s['answers_count']} risp.',
                                    style: SlText.mono(p, size: 11, color: p.adminGreen)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    Text('Se è la stessa, aprila e premi “Ho lo stesso dubbio”: avvisiamo di più chi può rispondere.',
                        style: SlText.muted(p).copyWith(fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 10,
                maxLength: 5000,
                style: TextStyle(color: p.pureWhite, height: 1.45),
                decoration: InputDecoration(
                  labelText: 'Dettagli (facoltativi)',
                  hintText: 'Scrivi cosa hai già capito e cosa no: aiuta chi risponde.',
                  filled: true,
                  fillColor: p.eleganceMidnight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.eleganceMidnight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
                ),
                child: Column(children: [
                  _switchRow('Chiedi in forma anonima',
                      'Gli studenti vedono “Studente del N° anno”. I moderatori vedono il tuo nome.', _anonymous,
                      (v) => setState(() => _anonymous = v)),
                  const SizedBox(height: 10),
                  _switchRow(
                      'Chiedi anche al docente',
                      subject == null ? 'Scegli prima una materia' : 'I docenti di ${subject['name']} ricevono una notifica',
                      _askTeacher,
                      subject == null ? null : (v) => setState(() => _askTeacher = v)),
                ]),
              ),
              const SizedBox(height: 12),
              Text(
                'Ogni domanda viene controllata da StudentLab prima di essere pubblicata. Niente tracce d’esame in corso, '
                'dati personali o offese.',
                style: SlText.muted(p).copyWith(fontSize: 12, height: 1.45),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
