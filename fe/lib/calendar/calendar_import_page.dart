import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'calendar_api_service.dart';
import 'calendar_widgets.dart';

/// Importa un calendario: file PDF (tabelle), CSV, iCal, JSON o una pagina web.
/// Anteprima riga per riga: si sceglie cosa importare, il tipo e la materia.
class CalendarImportPage extends StatefulWidget {
  final String? university;
  final String? department;
  final String? course;

  const CalendarImportPage({super.key, this.university, this.department, this.course});

  @override
  State<CalendarImportPage> createState() => _CalendarImportPageState();
}

class _CalendarImportPageState extends State<CalendarImportPage> {
  final CalendarApiService _api = CalendarApiService();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _year = TextEditingController(text: '${DateTime.now().year}');
  String _source = 'file';
  String? _fileName;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _subjects = [];
  final Set<int> _selected = <int>{};
  String _status = 'provisional';
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void dispose() {
    _url.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _preview({Uint8List? bytes, String? name}) async {
    setState(() {
      _busy = true;
      _error = null;
      _report = null;
    });
    try {
      final data = await _api.importPreview(
        bytes: bytes,
        fileName: name,
        url: _source == 'web' ? _url.text : null,
        university: widget.university,
        department: widget.department,
        course: widget.course,
        defaultYear: int.tryParse(_year.text.trim()),
      );
      _rows = (data['events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _subjects = (data['subjects'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _selected
        ..clear()
        ..addAll([for (var i = 0; i < _rows.length; i++) if ((_rows[i]['warnings'] as List? ?? []).isEmpty) i]);
      if (_rows.isEmpty) _error = 'Non ho trovato eventi: controlla che il file abbia una colonna con le date.';
    } catch (e) {
      _error = calendarError(e, 'Non è stato possibile leggere il calendario.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'csv', 'ics', 'ical', 'json', 'html', 'htm', 'txt'],
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    setState(() => _fileName = file!.name);
    await _preview(bytes: file!.bytes, name: file.name);
  }

  Future<void> _commit() async {
    final events = <Map<String, dynamic>>[];
    for (final i in _selected.toList()..sort()) {
      final r = _rows[i];
      events.add({
        'kind': r['kind'],
        'title': r['title'],
        'subject_id': r['subject_id'],
        if (r['subject_id'] == null) 'university': widget.university,
        if (r['subject_id'] == null) 'department': widget.department,
        if (r['subject_id'] == null) 'course': widget.course,
        'starts_at': r['starts_at'],
        if (r['ends_at'] != null) 'ends_at': r['ends_at'],
        'all_day': r['all_day'] == true,
        if (r['exam_format'] != null) 'exam_format': r['exam_format'],
        if (r['room'] != null) 'room': r['room'],
        'teachers': r['teachers'] ?? [],
        if (r['booking_url'] != null) 'booking_url': r['booking_url'],
        if (r['booking_deadline'] != null) 'booking_deadline': r['booking_deadline'],
        if (r['notes'] != null) 'notes': r['notes'],
        'status': _status,
        'source': r['source'] == 'web' ? 'web' : r['source'],
        if (r['source_ref'] != null) 'source_ref': '${r['source_ref']}'.length > 500 ? '${r['source_ref']}'.substring(0, 500) : r['source_ref'],
      });
    }
    if (events.isEmpty) return;
    setState(() => _busy = true);
    try {
      _report = await _api.importCommit(events);
      _error = null;
    } catch (e) {
      _error = calendarError(e, 'Importazione non riuscita.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _rowCard(int i) {
    final p = context.palette;
    final r = _rows[i];
    final warnings = (r['warnings'] as List? ?? []).map((w) => '$w').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.eleganceMidnight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: warnings.isEmpty ? p.pureWhite.withValues(alpha: 0.08) : p.adminAmber.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: _selected.contains(i),
            onChanged: (v) => setState(() => v == true ? _selected.add(i) : _selected.remove(i)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${r['title']}', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
              Text(
                [calendarWhen(r), if (r['room'] != null) '${r['room']}', if ((r['teachers'] as List? ?? []).isNotEmpty) (r['teachers'] as List).join(', ')]
                    .join(' · '),
                style: SlText.muted(p).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                DropdownButton<String>(
                  value: '${r['kind']}',
                  isDense: true,
                  dropdownColor: p.eleganceDeepNavy,
                  items: [for (final k in calendarKinds.entries) DropdownMenuItem(value: k.key, child: Text(k.value.$1))],
                  onChanged: (v) => setState(() => r['kind'] = v),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: DropdownButton<int?>(
                    value: _subjects.any((s) => s['id'] == r['subject_id']) ? r['subject_id'] as int? : null,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: p.eleganceDeepNavy,
                    hint: const Text('Materia'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Nessuna materia')),
                      for (final s in _subjects)
                        DropdownMenuItem<int?>(value: s['id'] as int?, child: Text('${s['name']}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() {
                      r['subject_id'] = v;
                      r['warnings'] = (r['warnings'] as List? ?? []).where((w) => !'$w'.startsWith('Materia')).toList();
                    }),
                  ),
                ),
              ]),
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('⚠ $w', style: TextStyle(color: p.adminAmber, fontSize: 11)),
                ),
              if (r['source_ref'] != null)
                Text('${r['source']} · ${r['source_ref']}', style: SlText.mono(p, size: 10, color: p.pureWhite.withValues(alpha: 0.45))),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: const Text('Importa un calendario'),
        actions: [
          if (_rows.isNotEmpty && _report == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _busy || _selected.isEmpty ? null : _commit,
                style: FilledButton.styleFrom(backgroundColor: p.skyBlue, foregroundColor: p.darkElegance),
                child: Text('Importa ${_selected.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_error != null) ...[SlErrorCard(title: 'Attenzione', message: _error!), const SizedBox(height: 12)],
            SlFilterBar<String>(
              selected: _source,
              options: const [
                SlFilterOption(value: 'file', label: 'File (PDF, CSV, iCal, JSON)'),
                SlFilterOption(value: 'web', label: 'Pagina web'),
              ],
              onSelected: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (_source == 'file')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(_fileName ?? 'Scegli il file'),
                  ),
                )
              else ...[
                Expanded(
                  child: TextField(
                    controller: _url,
                    decoration: const InputDecoration(labelText: 'Indirizzo della pagina o del file (https://…)'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : () => _preview(), child: const Text('Leggi')),
              ],
              const SizedBox(width: 10),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Anno se manca'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Dai PDF leggo le tabelle con una colonna “Data” (e se ci sono Ora, Insegnamento, Aula, Docenti). '
              'Dalle pagine web leggo le tabelle HTML. Gli eventi importati arrivano come “da confermare”, a meno che tu non scelga altrimenti.',
              style: SlText.muted(p).copyWith(fontSize: 12, height: 1.4),
            ),
            if (_busy) Padding(padding: const EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: p.skyBlue))),
            if (_report != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${_report!['created']} eventi importati', style: TextStyle(color: p.adminGreen, fontSize: 16, fontWeight: FontWeight.w700)),
                  if ((_report!['skipped'] as List? ?? []).isNotEmpty)
                    Text('${(_report!['skipped'] as List).length} saltati (già presenti o non autorizzati).', style: SlText.muted(p)),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Fine')),
                ]),
              ),
            ] else if (_rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text('${_rows.length} eventi trovati · ${_selected.length} selezionati', style: SlText.body(p))),
                TextButton(
                  onPressed: () => setState(() => _selected.length == _rows.length
                      ? _selected.clear()
                      : _selected.addAll(List.generate(_rows.length, (i) => i))),
                  child: Text(_selected.length == _rows.length ? 'Deseleziona tutti' : 'Seleziona tutti'),
                ),
              ]),
              Wrap(spacing: 6, children: [
                for (final s in const [('provisional', 'Da confermare'), ('confirmed', 'Confermati')])
                  ChoiceChip(label: Text(s.$2), selected: _status == s.$1, onSelected: (_) => setState(() => _status = s.$1)),
              ]),
              const SizedBox(height: 10),
              for (var i = 0; i < _rows.length; i++) _rowCard(i),
            ],
          ]),
        ),
      ),
    );
  }
}
