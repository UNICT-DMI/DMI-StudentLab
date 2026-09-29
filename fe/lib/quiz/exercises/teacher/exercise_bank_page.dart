import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/exercise_session_page.dart';
import 'package:fe/quiz/exercises/teacher/exercise_editor_page.dart';

/// Banca esercizi di una materia (docente verificato della materia o admin).
/// Il server controlla i permessi: questa pagina mostra solo quello che risponde.
class ExerciseBankPage extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final String? subjectLabel;

  const ExerciseBankPage({super.key, required this.department, required this.course, required this.subject,
      this.subjectLabel});

  @override
  State<ExerciseBankPage> createState() => _ExerciseBankPageState();
}

class _ExerciseBankPageState extends State<ExerciseBankPage> {
  final ExerciseApiService _api = ExerciseApiService();
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<String> _arguments = <String>[];
  bool _codeRunner = false;
  Map<String, dynamic> _area = <String, dynamic>{};
  String? _type;
  String? _argument;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> data = await _api.manageList(widget.department, widget.course, widget.subject,
          type: _type, argument: _argument, query: _search.text);
      _items = asMapList(data['items']);
      _arguments = asStringList(data['arguments']);
      _codeRunner = data['code_runner'] == true;
      _area = asMap(data['area']);
    } catch (error) {
      _error = cleanError(error, 'Banca esercizi non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _new() async {
    final p = context.palette;
    final Set<String> areaTypes = asStringList(_area['types']).toSet();
    // Le flashcard si gestiscono nel Ripasso, non nella creazione degli esercizi.
    final List<String> exerciseTypes = kExerciseTypes.where((t) => t != 'flashcard').toList();
    final List<String> recommended = exerciseTypes.where(areaTypes.contains).toList();
    final List<String> others = exerciseTypes.where((String t) => !areaTypes.contains(t)).toList();
    Widget tile(String t) => Builder(
          builder: (BuildContext tileContext) => ListTile(
            leading: Icon(exerciseInfo(t).icon, color: categoryColor(tileContext, exerciseInfo(t).category)),
            title: Text(exerciseInfo(t).label),
            subtitle: Text(
              t == 'codice' && !_codeRunner
                  ? 'Serve il servizio di esecuzione (CODE_RUNNER_URL): puoi prepararlo, sarà visibile quando è attivo.'
                  : exerciseInfo(t).purpose,
            ),
            onTap: () => Navigator.pop(tileContext, t),
          ),
        );
    final String? type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
          child: ListView(shrinkWrap: true, children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Che tipo di esercizio?', style: TextStyle(color: p.pureWhite, fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            // prima i tipi consigliati per l'area del corso (v24), poi tutti gli altri
            if (recommended.isNotEmpty) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: SlOverline('CONSIGLIATI · ${(_area['label'] ?? '').toString().toUpperCase()}'),
              ),
              for (final String t in recommended) tile(t),
              if (others.isNotEmpty)
                Theme(
                  data: Theme.of(sheetContext).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text('Altri tipi (${others.length})', style: TextStyle(color: p.pureWhite, fontSize: 14)),
                    subtitle: const Text('Poco usati in questo corso, ma puoi crearli'),
                    children: <Widget>[for (final String t in others) tile(t)],
                  ),
                ),
            ] else
              for (final String t in exerciseTypes) tile(t),
          ]),
        ),
      ),
    );
    if (type == null || !mounted) return;
    await _openEditor(type: type);
  }

  Future<void> _openEditor({String? type, Map<String, dynamic>? record}) async {
    final bool? saved = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => ExerciseEditorPage(
        department: widget.department,
        course: widget.course,
        subject: widget.subject,
        type: type ?? record?['type']?.toString() ?? 'ordina',
        record: record,
        arguments: _arguments,
      ),
    ));
    if (saved == true && mounted) await _load();
  }

  Future<void> _import() async {
    final FilePickerResult? picked =
        await FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: const <String>['json']);
    final PlatformFile? file = picked?.files.single;
    if (file?.bytes == null) return;
    dynamic payload;
    try {
      payload = jsonDecode(utf8.decode(file!.bytes!));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Il file non è un JSON valido.')));
      return;
    }
    try {
      final Map<String, dynamic> preview =
          await _api.manageImport(widget.department, widget.course, widget.subject, payload, dryRun: true);
      if (!mounted) return;
      final List<Map<String, dynamic>> errors = asMapList(preview['errors']);
      final p = context.palette;
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('Importa esercizi'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('${preview['created']} nuovi, ${preview['skipped_duplicates']} già presenti, ${errors.length} con errori.'),
              if (errors.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView(shrinkWrap: true, children: <Widget>[
                    for (final Map<String, dynamic> e in errors.take(30))
                      Text('#${e['index']}: ${e['message']}', style: TextStyle(color: p.adminCoral, fontSize: 12)),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              Text('Gli allegati non si importano: aggiungili poi dall’editor.', style: SlText.muted(p).copyWith(fontSize: 12)),
            ]),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
            FilledButton(
              onPressed: (preview['created'] ?? 0) == 0 ? null : () => Navigator.pop(dialogContext, true),
              child: Text('Importa ${preview['created']}'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final Map<String, dynamic> report = await _api.manageImport(widget.department, widget.course, widget.subject, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importati ${report['created']} esercizi.')));
      }
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
  }

  Future<void> _setStatus(Map<String, dynamic> record, {bool? hidden, bool? active}) async {
    try {
      await _api.manageStatus(widget.department, widget.course, widget.subject, '${record['id_exercise']}',
          isHidden: hidden, isActive: active);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    final p = context.palette;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: const Text('Eliminare l’esercizio?'),
        content: const Text('I tentativi già svolti restano nello storico. Se vuoi solo toglierlo agli studenti, nascondilo.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.adminCoral),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.manageDelete(widget.department, widget.course, widget.subject, '${record['id_exercise']}');
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
  }

  void _try(Map<String, dynamic> record) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ExerciseSessionPage.practice(
        department: widget.department,
        course: widget.course,
        subject: widget.subject,
        title: 'Prova come studente',
        itemIds: <String>['ex:${record['id_exercise']}'],
      ),
    ));
  }

  Widget _row(BuildContext context, Map<String, dynamic> record) {
    final p = context.palette;
    final String type = record['type']?.toString() ?? '';
    final ExerciseTypeInfo info = exerciseInfo(type);
    final bool hidden = record['is_hidden'] == true;
    final bool inactive = record['is_active'] == false;
    final Map<String, dynamic> metadata = asMap(record['metadata']);
    final int attachments = asMapList(record['attachments']).length;
    final Map<String, dynamic>? generator = record['generator'] is Map ? asMap(record['generator']) : null;
    return Card(
      color: p.eleganceMidnight,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEditor(record: record),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Icon(info.icon, color: categoryColor(context, info.category)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(
                  (record['text']?.toString() ?? '').isEmpty ? info.label : record['text'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text('#${record['id_exercise']} · ${metadata['argoment'] ?? 'Senza argomento'}',
                    style: SlText.muted(p).copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(spacing: 5, runSpacing: 4, children: <Widget>[
                  SlStatusBadge(label: info.label),
                  if (generator != null) SlStatusBadge(label: 'Generato · ${generator['name']}', tone: SlTone.info),
                  if (attachments > 0) SlStatusBadge(label: '$attachments allegati'),
                  if (hidden) const SlStatusBadge(label: 'Nascosto', tone: SlTone.warning),
                  if (inactive) const SlStatusBadge(label: 'Disattivato', tone: SlTone.danger),
                  if (type == 'codice' && !_codeRunner) const SlStatusBadge(label: 'Esecuzione non attiva', tone: SlTone.warning),
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: 'Azioni',
              color: p.eleganceDeepNavy,
              onSelected: (String action) {
                switch (action) {
                  case 'edit':
                    _openEditor(record: record);
                  case 'try':
                    _try(record);
                  case 'hide':
                    _setStatus(record, hidden: !hidden);
                  case 'active':
                    _setStatus(record, active: inactive);
                  case 'delete':
                    _delete(record);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'edit', child: Text('Modifica')),
                if (!hidden && !inactive) const PopupMenuItem<String>(value: 'try', child: Text('Prova come studente')),
                PopupMenuItem<String>(value: 'hide', child: Text(hidden ? 'Rendi visibile' : 'Nascondi agli studenti')),
                PopupMenuItem<String>(value: 'active', child: Text(inactive ? 'Riattiva' : 'Disattiva')),
                const PopupMenuItem<String>(value: 'delete', child: Text('Elimina')),
              ],
            ),
          ]),
        ),
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
        title: Text('Banca esercizi${widget.subjectLabel != null ? ' · ${widget.subjectLabel}' : ''}'),
        actions: <Widget>[
          IconButton(tooltip: 'Importa JSON', onPressed: _import, icon: const Icon(Icons.upload_file_rounded)),
          IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo esercizio'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: <Widget>[
              TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Cerca nella consegna',
                  suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: <Widget>[
                  ChoiceChip(
                    label: const Text('Tutti'),
                    selected: _type == null,
                    onSelected: (_) {
                      setState(() => _type = null);
                      _load();
                    },
                  ),
                  for (final String t in kExerciseTypes.where((String type) => type != 'flashcard'))
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        avatar: Icon(exerciseInfo(t).icon, size: 16),
                        label: Text(exerciseInfo(t).label),
                        selected: _type == t,
                        onSelected: (_) {
                          setState(() => _type = t);
                          _load();
                        },
                      ),
                    ),
                ]),
              ),
              if (_arguments.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _arguments.contains(_argument) ? _argument : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Argomento', isDense: true),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Tutti gli argomenti')),
                    for (final String a in _arguments) DropdownMenuItem<String?>(value: a, child: Text(a, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (String? v) {
                    setState(() => _argument = v);
                    _load();
                  },
                ),
              ],
              const SizedBox(height: 12),
              if (_error != null)
                SlErrorCard(title: 'Attenzione', message: _error!, onRetry: _load)
              else if (_loading)
                Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: p.skyBlue)))
              else if (_items.isEmpty)
                const SlEmptyState(
                  icon: Icons.extension_outlined,
                  title: 'Nessun esercizio',
                  message: 'Crea il primo esercizio o importa un file JSON (studentlab.exercise/1).',
                )
              else
                for (final Map<String, dynamic> record in _items) _row(context, record),
            ]),
          ),
        ),
      ),
    );
  }
}
