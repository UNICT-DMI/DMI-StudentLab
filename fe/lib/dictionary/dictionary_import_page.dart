import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../faq/faq_widgets.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';
import 'dictionary_moderation_page.dart';

/// Importa un dizionario JSON (canvas: Dizionario · importa JSON).
/// Anteprima dal server: materia riconosciuta o candidati, anno, conteggi.
///
/// Dalla v17 i termini importati diventano BOZZE da moderare e il file viene
/// registrato tra le fonti (nome, impronta sha256, dimensione, metadati).
/// PDF e pagine web non passano da qui: li legge in locale
/// scripts/fonti_dizionario.py, che manda al server solo i risultati.
class DictionaryImportPage extends StatefulWidget {
  final int? subjectId;

  const DictionaryImportPage({super.key, this.subjectId});

  @override
  State<DictionaryImportPage> createState() => _DictionaryImportPageState();
}

class _DictionaryImportPageState extends State<DictionaryImportPage> {
  final DictionaryApiService _api = DictionaryApiService();
  final TextEditingController _year = TextEditingController();
  Map<String, dynamic>? _dictionary;
  String? _fileName;
  Map<String, dynamic>? _sourceInfo;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _editable = [];
  int? _subjectId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjectId;
    _api.editableSubjects().then((v) {
      if (mounted) setState(() => _editable = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: const ['json']);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    try {
      final decoded = jsonDecode(utf8.decode(file!.bytes!));
      if (decoded is! Map) throw const FormatException();
      final meta = decoded['metadata'] is Map ? Map<String, dynamic>.from(decoded['metadata'] as Map) : <String, dynamic>{};
      setState(() {
        _dictionary = Map<String, dynamic>.from(decoded);
        _fileName = file.name;
        _sourceInfo = {
          'kind': 'json',
          'label': file.name,
          'sha256': sha256.convert(file.bytes!).toString(),
          'status': 'read',
          'metadata': {
            'file_name': file.name,
            'size_bytes': file.bytes!.length,
            'schema': '${decoded['schema'] ?? ''}',
            'generated_from': '${meta['source'] ?? ''}',
            'generated_at': '${meta['generated_at'] ?? ''}',
            'uploaded_from': 'app',
          },
        };
        _report = null;
        _error = null;
      });
      await _runPreview();
    } catch (_) {
      setState(() => _error = 'Il file non è un JSON valido.');
    }
  }

  Future<void> _runPreview() async {
    if (_dictionary == null) return;
    setState(() => _busy = true);
    try {
      final preview = await _api.importDictionary(_dictionary!, subjectId: _subjectId, preview: true,
          academicYear: _year.text.trim().isEmpty ? null : _year.text.trim());
      _preview = preview;
      if (_subjectId == null && preview['subject'] is Map) _subjectId = int.tryParse('${(preview['subject'] as Map)['id']}');
      if (_year.text.isEmpty) _year.text = '${preview['academic_year'] ?? ''}';
      _error = null;
    } catch (e) {
      _error = faqError(e, 'File non valido.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _import() async {
    if (_dictionary == null || _subjectId == null) return;
    setState(() => _busy = true);
    try {
      final result = await _api.importDictionary(_dictionary!, subjectId: _subjectId,
          academicYear: _year.text.trim().isEmpty ? null : _year.text.trim(), source: _sourceInfo);
      _report = result['report'] is Map ? Map<String, dynamic>.from(result['report'] as Map) : null;
      _error = null;
    } catch (e) {
      _error = faqError(e, 'Importazione non riuscita.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _panel(String title, List<Widget> children) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SlOverline(title),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final preview = _preview;
    final meta = preview?['metadata'] is Map ? Map<String, dynamic>.from(preview!['metadata'] as Map) : <String, dynamic>{};
    final candidates = (preview?['candidates'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final options = <int, String>{
      for (final c in candidates) int.parse('${c['id']}'): '${c['name']} · ${c['course'] ?? ''}',
      for (final s in _editable) int.parse('${s['id']}'): '${s['name']} · ${s['course'] ?? ''}',
    };
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: const Text('Importa un dizionario'),
        actions: [
          if (preview != null && _report == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _busy || _subjectId == null ? null : _import,
                style: FilledButton.styleFrom(backgroundColor: p.skyBlue, foregroundColor: p.darkElegance),
                child: Text('Importa ${preview['entries']} termini', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_error != null) ...[SlErrorCard(title: 'Attenzione', message: _error!), const SizedBox(height: 12)],
            _panel('File', [
              if (_fileName == null)
                Text('Formato studentlab.dictionary/1 (uno per materia). I file generati dalle domande sono in '
                    'BE/data/…/dictionary/.', style: SlText.muted(p))
              else
                Row(children: [
                  const SlIconTile(icon: Icons.data_object_rounded, tone: SlTone.warning, size: 40),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_fileName!, style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600))),
                  if (preview != null) const SlStatusBadge(label: 'Valido', tone: SlTone.success),
                ]),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_fileName == null ? 'Scegli il file JSON' : 'Cambia file'),
              ),
            ]),
            if (_busy) Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: p.skyBlue))),
            if (preview != null) ...[
              _panel('Dal file', [
                for (final k in const [('university', 'Ateneo'), ('department', 'Dipartimento'), ('course', 'Corso'),
                  ('subject', 'Materia nel file'), ('academic_year', 'Anno')])
                  SlKeyValue(label: k.$2, value: '${meta[k.$1] ?? '—'}'),
                SlKeyValue(label: 'Docenti', value: ((meta['teachers'] as List?) ?? []).join(', ')),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  SlStatusBadge(label: '${preview['entries']} termini', tone: SlTone.info),
                  SlStatusBadge(label: '${preview['topics']} argomenti', tone: SlTone.info),
                  SlStatusBadge(label: '${preview['with_examples']} con esempi'),
                  SlStatusBadge(label: '${preview['with_exercises']} con esercizi'),
                  SlStatusBadge(label: '${preview['with_exam_questions']} con domande d’esame'),
                ]),
              ]),
              _panel('Materia di StudentLab', [
                if (preview['subject'] is Map && _subjectId == int.tryParse('${(preview['subject'] as Map)['id']}'))
                  Text('Riconosciuta: ${(preview['subject'] as Map)['name']}', style: TextStyle(color: p.adminGreen, fontWeight: FontWeight.w600))
                else if (_subjectId == null)
                  Text('Materia non riconosciuta con sicurezza: sceglila.', style: TextStyle(color: p.adminAmber)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: options.containsKey(_subjectId) ? _subjectId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Materia'),
                  items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
              ]),
              _panel('Anno in cui importare', [
                TextField(controller: _year, decoration: const InputDecoration(labelText: 'Anno accademico', hintText: '2025/2026')),
                const SizedBox(height: 8),
                Text('Nessun termine diventa pubblico subito: finiscono tutti in moderazione, dove si possono '
                    'correggere, spostare di materia o argomento, affidare a un docente e arricchire con esercizi e '
                    'domande d’esame. Se un termine è identico a quello già pubblicato viene saltato.',
                    style: SlText.muted(p)),
              ]),
            ],
            if (_report != null)
              _panel('Fatto', [
                Text('${_report!['subject_name']} · A.A. ${_report!['academic_year']}',
                    style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${_report!['created'] ?? 0} bozze nuove, ${_report!['updated'] ?? 0} bozze aggiornate, '
                    '${_report!['already_published'] ?? 0} già pubblicati uguali, '
                    '${_report!['rejected_before'] ?? 0} scartati in passato, '
                    '${_report!['skipped'] ?? 0} saltati (senza termine o senza definizione).', style: SlText.body(p)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                      builder: (_) => DictionaryModerationPage(
                        subjectId: int.tryParse('${_report!['subject_id']}'),
                        sourceId: int.tryParse('${_report!['source_id']}'),
                      ),
                    )),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Modera i termini'),
                  ),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Fine')),
                ]),
              ]),
          ]),
        ),
      ),
    );
  }
}
