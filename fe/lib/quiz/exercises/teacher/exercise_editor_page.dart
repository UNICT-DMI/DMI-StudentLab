import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:fe/services/blob_upload_service.dart';
import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/widgets/exercise_view.dart';
import 'package:fe/quiz/exercises/teacher/exercise_type_editors.dart';

/// Crea o modifica un esercizio della banca. Testo, argomento, allegati
/// (immagini, PDF, TXT, DOCX, PPTX) e i dati del tipo. La validazione vera è
/// quella del server: "Anteprima" la esegue senza salvare.
class ExerciseEditorPage extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final String type;
  final Map<String, dynamic>? record;
  final List<String> arguments;

  const ExerciseEditorPage({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    required this.type,
    this.record,
    this.arguments = const <String>[],
  });

  @override
  State<ExerciseEditorPage> createState() => _ExerciseEditorPageState();
}

const Map<String, List<(String, String)>> _generators = <String, List<(String, String)>>{
  'grafo': <(String, String)>[('dijkstra', 'Dijkstra'), ('bfs', 'BFS'), ('dfs', 'DFS')],
  'numerica': <(String, String)>[('subnet', 'Subnetting'), ('base_conversion', 'Cambio di base')],
  'traccia': <(String, String)>[('bubble', 'Bubble sort')],
};

class _ExerciseEditorPageState extends State<ExerciseEditorPage> {
  final ExerciseApiService _api = ExerciseApiService();
  final StudentLabUploadService _upload = StudentLabUploadService();
  late final TextEditingController _text;
  late final TextEditingController _hint;
  late final TextEditingController _explanation;
  late final TextEditingController _argument;
  late final TextEditingController _seconds;
  int _difficulty = 2;
  List<Map<String, dynamic>> _attachments = <Map<String, dynamic>>[];
  Map<String, dynamic> _data = <String, dynamic>{};
  Map<String, dynamic>? _generator;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  bool get _editing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> record = widget.record ?? const <String, dynamic>{};
    final Map<String, dynamic> metadata = asMap(record['metadata']);
    _text = TextEditingController(text: record['text']?.toString() ?? '');
    _hint = TextEditingController(text: record['hint']?.toString() ?? '');
    _explanation = TextEditingController(text: record['explanation']?.toString() ?? '');
    _argument = TextEditingController(text: metadata['argoment']?.toString() ?? '');
    _seconds = TextEditingController(text: '${record['estimed_time'] ?? 60}');
    _difficulty = int.tryParse('${metadata['difficulty'] ?? 2}') ?? 2;
    _attachments = asMapList(record['attachments']);
    _data = asMap(record['data']);
    _generator = record['generator'] is Map ? asMap(record['generator']) : null;
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_text, _hint, _explanation, _argument, _seconds]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _payload => <String, dynamic>{
        'type': widget.type,
        'text': _text.text.trim(),
        'hint': _hint.text.trim(),
        'explanation': _explanation.text.trim(),
        'estimed_time': int.tryParse(_seconds.text.trim()) ?? 60,
        'metadata': <String, dynamic>{
          ...asMap(widget.record?['metadata']),
          'argoment': _argument.text.trim(),
          'difficulty': _difficulty,
        },
        'attachments': _attachments,
        // Sempre entrambe le chiavi: passando da "generato" a "scritto a mano" (e viceversa) il server
        // non deve tenere quella vecchia.
        'generator': _generator,
        'data': _generator == null ? _data : null,
      };

  Future<void> _pickAttachment() async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'pdf', 'txt', 'docx', 'pptx'],
    );
    final PlatformFile? file = picked?.files.single;
    if (file?.bytes == null) return;
    if (file!.size > 50 * 1024 * 1024) {
      setState(() => _error = '${file.name} supera 50 MB.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> uploaded = await _upload.uploadQuestionAttachmentBytes(
        department: widget.department,
        course: widget.course,
        subject: widget.subject,
        bytes: file.bytes!,
        originalName: file.name,
      );
      final bool image = (uploaded['mime_type']?.toString() ?? '').startsWith('image/');
      setState(() => _attachments.add(<String, dynamic>{
            ...uploaded,
            'role': widget.type == 'diagramma' && image ? 'diagram' : 'statement',
            'caption': '',
          }));
    } catch (error) {
      setState(() => _error = cleanError(error, 'Caricamento non riuscito.'));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _preview() async {
    setState(() => _error = null);
    try {
      final Map<String, dynamic> response =
          await _api.managePreview(widget.department, widget.course, widget.subject, _payload);
      if (!mounted) return;
      final ExerciseItem item = ExerciseItem.fromJson(asMap(response['item']));
      final p = context.palette;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => Dialog(
          backgroundColor: p.darkElegance,
          insetPadding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
            child: Column(children: <Widget>[
              ListTile(
                title: const Text('Anteprima come studente'),
                subtitle: const Text('Valida per il server. Le immagini appaiono dopo il salvataggio.'),
                trailing: IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
                  Text(item.text, style: TextStyle(color: p.pureWhite, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ExerciseView(
                    item: item,
                    scope: ExerciseScope(department: widget.department, course: widget.course, subject: widget.subject),
                    onChanged: (Map<String, dynamic> _, bool __) {},
                    onGrade: (int _) {},
                  ),
                  const SizedBox(height: 16),
                  SlOverline('SOLUZIONE'),
                  const SizedBox(height: 6),
                  SelectableText('${response['solution'] ?? ''}', style: SlText.body(p).copyWith(fontSize: 13)),
                ]),
              ),
            ]),
          ),
        ),
      );
    } catch (error) {
      setState(() => _error = cleanError(error, 'Esercizio non valido.'));
    }
  }

  Future<void> _save() async {
    if (_argument.text.trim().isEmpty) {
      setState(() => _error = 'Indica l’argomento.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        await _api.manageUpdate(widget.department, widget.course, widget.subject,
            '${widget.record!['id_exercise']}', _payload);
      } else {
        await _api.manageCreate(widget.department, widget.course, widget.subject, _payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = cleanError(error, 'Esercizio non salvato.'));
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _panel(BuildContext context, String title, List<Widget> children, {String? help}) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        SlOverline(title),
        if (help != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(help, style: SlText.muted(p).copyWith(fontSize: 12)),
        ],
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _attachmentsPanel(BuildContext context) {
    final p = context.palette;
    return _panel(context, 'ALLEGATI', help: 'Immagini (PNG, JPEG, WebP) e file che lo studente può aprire (PDF, TXT, DOCX, PPTX), fino a 50 MB.', <Widget>[
      for (int i = 0; i < _attachments.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: <Widget>[
            Icon((_attachments[i]['mime_type']?.toString() ?? '').startsWith('image/')
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined, color: p.skyBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text('${_attachments[i]['original_name']}', overflow: TextOverflow.ellipsis, style: TextStyle(color: p.pureWhite)),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: _attachments[i]['caption']?.toString() ?? '',
                  decoration: const InputDecoration(isDense: true, hintText: 'Didascalia (facoltativa)'),
                  onChanged: (String v) => _attachments[i]['caption'] = v,
                ),
              ]),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: const <String>['statement', 'option', 'diagram', 'solution'].contains(_attachments[i]['role'])
                  ? _attachments[i]['role'].toString()
                  : 'statement',
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'statement', child: Text('Nella domanda')),
                DropdownMenuItem<String>(value: 'option', child: Text('In una risposta')),
                DropdownMenuItem<String>(value: 'diagram', child: Text('Diagramma')),
              ],
              onChanged: (String? v) => setState(() => _attachments[i]['role'] = v ?? 'statement'),
            ),
            IconButton(
              tooltip: 'Togli',
              onPressed: () => setState(() => _attachments.removeAt(i)),
              icon: Icon(Icons.delete_outline_rounded, color: p.adminCoral),
            ),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _uploading || _attachments.length >= 12 ? null : _pickAttachment,
          icon: _uploading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.attach_file_rounded),
          label: Text(_uploading ? 'Caricamento…' : 'Aggiungi allegato'),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ExerciseTypeInfo info = exerciseInfo(widget.type);
    final List<(String, String)> generators = _generators[widget.type] ?? const <(String, String)>[];
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text('${_editing ? 'Modifica' : 'Nuovo'} · ${info.label}'),
        actions: <Widget>[
          TextButton(onPressed: _saving ? null : _preview, child: const Text('Anteprima')),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving || _uploading ? null : _save,
              child: Text(_saving ? 'Salvataggio…' : 'Salva'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
            if (_error != null) ...<Widget>[
              SlErrorCard(title: 'Da correggere', message: _error!),
              const SizedBox(height: 12),
            ],
            _panel(context, 'CONSEGNA', <Widget>[
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: generators.isNotEmpty && _generator != null ? 'Consegna (facoltativa: il testo è generato)' : 'Consegna',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _argument,
                decoration: const InputDecoration(labelText: 'Argomento', border: OutlineInputBorder()),
              ),
              if (widget.arguments.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                  for (final String a in widget.arguments.take(24))
                    ActionChip(
                      label: Text(a, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(() => _argument.text = a),
                    ),
                ]),
              ],
              const SizedBox(height: 10),
              Row(children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _difficulty,
                    decoration: const InputDecoration(labelText: 'Difficoltà', border: OutlineInputBorder(), isDense: true),
                    items: <DropdownMenuItem<int>>[
                      for (int d = 1; d <= 5; d++) DropdownMenuItem<int>(value: d, child: Text('$d')),
                    ],
                    onChanged: (int? v) => setState(() => _difficulty = v ?? 2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _seconds,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tempo stimato (secondi)', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ]),
            ]),
            if (generators.isNotEmpty)
              _panel(context, 'VARIANTI GENERATE', help: 'Ogni studente riceve un esercizio diverso, sempre corretto dal server.', <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _generator != null,
                  title: const Text('Genera varianti automaticamente'),
                  onChanged: (bool v) => setState(() => _generator =
                      v ? <String, dynamic>{'name': generators.first.$1, 'difficulty': 2} : null),
                ),
                if (_generator != null)
                  Row(children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: generators.any(((String, String) g) => g.$1 == _generator!['name'])
                            ? _generator!['name'].toString()
                            : generators.first.$1,
                        decoration: const InputDecoration(labelText: 'Generatore', border: OutlineInputBorder(), isDense: true),
                        items: <DropdownMenuItem<String>>[
                          for (final (String id, String label) in generators) DropdownMenuItem<String>(value: id, child: Text(label)),
                        ],
                        onChanged: (String? v) => setState(() => _generator!['name'] = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: int.tryParse('${_generator!['difficulty']}') ?? 2,
                        decoration: const InputDecoration(labelText: 'Difficoltà delle varianti', border: OutlineInputBorder(), isDense: true),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem<int>(value: 1, child: Text('Facile')),
                          DropdownMenuItem<int>(value: 2, child: Text('Media')),
                          DropdownMenuItem<int>(value: 3, child: Text('Difficile')),
                        ],
                        onChanged: (int? v) => setState(() => _generator!['difficulty'] = v ?? 2),
                      ),
                    ),
                  ]),
              ]),
            if (_generator == null)
              typeEditor(
                type: widget.type,
                initial: _data,
                attachments: _attachments,
                onChanged: (Map<String, dynamic> data) => _data = data,
              ),
            _attachmentsPanel(context),
            _panel(context, 'DOPO LA RISPOSTA', <Widget>[
              TextField(controller: _hint, decoration: const InputDecoration(labelText: 'Suggerimento (prima di rispondere)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: _explanation,
                minLines: 2,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Spiegazione (dopo la risposta)', border: OutlineInputBorder()),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
