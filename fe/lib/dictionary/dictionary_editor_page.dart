import 'package:flutter/material.dart';

import '../faq/faq_widgets.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';
import 'dictionary_moderation_page.dart';

/// Editor di un termine per un anno accademico (canvas: Dizionario · editor).
/// Admin e docenti verificati della materia. Nome e data di chi scrive
/// restano sul contenuto.
///
/// Dalla v17 ci sono due salvataggi:
///  - "Salva bozza": la modifica va in moderazione, il testo pubblicato resta
///    quello di prima finché non viene approvata;
///  - "Salva e pubblica": diventa subito la versione pubblicata (confermata).
class DictionaryEditorPage extends StatefulWidget {
  final int subjectId;
  final int? entryId;
  final String? year;

  const DictionaryEditorPage({super.key, required this.subjectId, this.entryId, this.year});

  @override
  State<DictionaryEditorPage> createState() => _DictionaryEditorPageState();
}

class _DictionaryEditorPageState extends State<DictionaryEditorPage> {
  final DictionaryApiService _api = DictionaryApiService();
  final TextEditingController _term = TextEditingController();
  final TextEditingController _aliases = TextEditingController();
  final TextEditingController _formal = TextEditingController();
  final TextEditingController _informal = TextEditingController();
  final TextEditingController _newTopic = TextEditingController();
  final TextEditingController _year = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _terms = [];
  int? _topicId;
  String _tab = 'examples';

  List<Map<String, dynamic>> _examples = [];
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _resources = [];
  List<String> _related = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_term, _aliases, _formal, _informal, _newTopic, _year]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _load() async {
    try {
      final subject = await _api.subject(widget.subjectId, year: widget.year);
      final topics = _maps(subject['topics']);
      _topics = topics.where((t) => t['id'] != null).toList();
      _terms = [for (final t in topics) ..._maps(t['entries'])];
      _year.text = widget.year ?? '${subject['year']}';
      if (widget.entryId != null) {
        final data = await _api.entry(widget.entryId!, year: widget.year);
        final entry = Map<String, dynamic>.from(data['entry'] as Map);
        final v = Map<String, dynamic>.from(data['version'] as Map);
        _term.text = '${entry['term']}';
        _aliases.text = (entry['aliases'] as List? ?? []).join(', ');
        _topicId = int.tryParse('${entry['topic_id']}');
        _formal.text = '${v['formal_definition'] ?? ''}';
        _informal.text = '${v['informal_definition'] ?? ''}';
        _examples = _maps(v['examples']);
        _exercises = _maps(v['exercises']);
        _exams = _maps(v['exam_questions']);
        _resources = _maps(v['resources']);
        _related = [for (final r in _maps(data['related'])) '${r['term']}'];
      }
    } catch (e) {
      _error = faqError(e, 'Editor non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _slug(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâä]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _save({required bool publish}) async {
    if (_term.text.trim().isEmpty) {
      setState(() => _error = 'Scrivi il termine.');
      return;
    }
    if (_formal.text.trim().isEmpty && _informal.text.trim().isEmpty) {
      setState(() => _error = 'Scrivi almeno una definizione.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await _api.saveEntry(
        entryId: widget.entryId,
        subjectId: widget.subjectId,
        body: {
          'term': _term.text.trim(),
          'aliases': _aliases.text.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
          'topic_id': _newTopic.text.trim().isEmpty ? _topicId : null,
          if (_newTopic.text.trim().isNotEmpty) 'new_topic_title': _newTopic.text.trim(),
          'academic_year': _year.text.trim(),
          'formal_definition': _formal.text.trim(),
          'informal_definition': _informal.text.trim(),
          'examples': _examples,
          'exercises': _exercises,
          'exam_questions': _exams,
          'resources': _resources,
          'related': _related.map(_slug).toList(),
          'publish': publish,
        },
      );
      if (!mounted) return;
      final bool published = result['published'] != false;
      final navigator = Navigator.of(context);   // resta valido dopo la chiusura dell'editor
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(published
            ? 'Termine pubblicato.'
            : 'Bozza salvata: la trovi in moderazione. Il testo pubblicato non cambia finché non la approvi.'),
        action: published || result['draft_id'] == null
            ? null
            : SnackBarAction(
                label: 'Apri',
                onPressed: () => navigator.push(MaterialPageRoute<void>(
                  builder: (_) => DictionaryModerationPage(subjectId: widget.subjectId),
                )),
              ),
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = faqError(e, 'Termine non salvato.');
        });
      }
    }
  }

  /// Finestra per aggiungere o modificare un elemento di una lista.
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
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final f in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[f.$1],
                    minLines: f.$3,
                    maxLines: f.$3 == 1 ? 1 : 10,
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
    final result = <String, dynamic>{};
    for (final f in fields) {
      final value = controllers[f.$1]!.text.trim();
      if (value.isNotEmpty) result[f.$1] = f.$1 == 'difficulty' ? _difficulty(value) : value;
      controllers[f.$1]!.dispose();
    }
    return ok == true && result.isNotEmpty ? result : null;
  }

  int _difficulty(String value) {
    final int n = int.tryParse(value) ?? 1;
    return n < 1 ? 1 : (n > 5 ? 5 : n);
  }

  List<(String, String, int)> get _fieldsForTab => switch (_tab) {
        'examples' => const [('title', 'Titolo (facoltativo)', 1), ('body', 'Esempio', 4)],
        'exercises' => const [('text', 'Testo dell’esercizio', 4), ('solution', 'Soluzione', 4), ('difficulty', 'Difficoltà 1–5', 1)],
        _ => const [('text', 'Domanda', 3), ('kind', 'Tipo (scritto, orale…)', 1), ('source', 'Fonte (es. orale luglio 2025)', 1)],
      };

  List<Map<String, dynamic>> get _currentList => switch (_tab) {
        'examples' => _examples,
        'exercises' => _exercises,
        _ => _exams,
      };

  Future<void> _addResource() async {
    final p = context.palette;
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Dalle Dispense'),
            onTap: () => Navigator.pop(sheetContext, 'material'),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Link'),
            onTap: () => Navigator.pop(sheetContext, 'url'),
          ),
        ]),
      ),
    );
    if (kind == 'url') {
      final item = await _itemDialog('Link', const [('title', 'Titolo', 1), ('url', 'Indirizzo (https://…)', 1)]);
      if (item != null && '${item['url'] ?? ''}'.startsWith('http')) setState(() => _resources.add({...item, 'type': 'url'}));
    } else if (kind == 'material') {
      List<Map<String, dynamic>> found = [];
      try {
        found = await ApiService().getMaterialRequestSuggestions(subjectId: widget.subjectId, query: _term.text);
        if (found.isEmpty) found = await ApiService().getMaterialRequestSuggestions(subjectId: widget.subjectId);
      } catch (_) {}
      if (!mounted) return;
      if (found.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nessun materiale pubblicato per la materia.')));
        return;
      }
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: p.eleganceDeepNavy,
        builder: (sheetContext) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            for (final m in found)
              ListTile(
                title: Text('${m['title'] ?? m['original_name']}'),
                subtitle: Text(((m['path_segments'] as List?) ?? []).join(' › ')),
                onTap: () => Navigator.pop(sheetContext, m),
              ),
          ]),
        ),
      );
      if (picked != null) {
        setState(() => _resources.add({
              'type': 'material',
              'title': '${picked['title'] ?? picked['original_name']}',
              'material_id': picked['id'],
              'catalog_path': picked['path_segments'] ?? [],
            }));
      }
    }
  }

  Widget _panel(List<Widget> children) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _itemTile(String title, String subtitle, VoidCallback onEdit, VoidCallback onDelete) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: p.darkElegance,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: SlText.muted(p)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Modifica', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
          IconButton(tooltip: 'Elimina', onPressed: onDelete, icon: Icon(Icons.delete_outline_rounded, size: 18, color: p.adminCoral)),
        ]),
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) =>
      InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final list = _currentList;
    final bool wide = MediaQuery.sizeOf(context).width >= 1100;

    final main = <Widget>[
      _panel([
        TextField(controller: _term, decoration: _decoration('Termine')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _topics.any((t) => t['id'] == _topicId) ? _topicId : null,
              isExpanded: true,
              decoration: _decoration('Argomento'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Nessuno')),
                for (final t in _topics) DropdownMenuItem<int?>(value: t['id'] as int?, child: Text('${t['title']}')),
              ],
              onChanged: (v) => setState(() => _topicId = v),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 150, child: TextField(controller: _year, decoration: _decoration('Anno', hint: '2025/2026'))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _newTopic, decoration: _decoration('Oppure nuovo argomento')),
        const SizedBox(height: 10),
        TextField(controller: _aliases, decoration: _decoration('Sinonimi (separati da virgola)')),
      ]),
      _panel([
        TextField(controller: _formal, minLines: 4, maxLines: 12, decoration: _decoration('Definizione formale')),
        const SizedBox(height: 10),
        TextField(controller: _informal, minLines: 3, maxLines: 10, decoration: _decoration('Definizione informale (parole semplici)')),
      ]),
      _panel([
        Text('Esempi · Esercizi · Domande d’esame', style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SlFilterBar<String>(
          selected: _tab,
          options: [
            SlFilterOption(value: 'examples', label: 'Esempi', count: _examples.length),
            SlFilterOption(value: 'exercises', label: 'Esercizi', count: _exercises.length),
            SlFilterOption(value: 'exams', label: 'Domande d’esame', count: _exams.length),
          ],
          onSelected: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < list.length; i++)
          _itemTile(
            '${list[i]['title'] ?? list[i]['text'] ?? list[i]['body'] ?? ''}',
            '${list[i]['body'] ?? list[i]['solution'] ?? list[i]['source'] ?? ''}',
            () async {
              final item = await _itemDialog('Modifica', _fieldsForTab, list[i]);
              if (item != null) setState(() => list[i] = item);
            },
            () => setState(() => list.removeAt(i)),
          ),
        OutlinedButton.icon(
          onPressed: () async {
            final item = await _itemDialog('Aggiungi', _fieldsForTab);
            if (item != null) setState(() => list.add(item));
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(switch (_tab) { 'examples' => 'Aggiungi esempio', 'exercises' => 'Aggiungi esercizio', _ => 'Aggiungi domanda' }),
        ),
      ]),
    ];
    final side = <Widget>[
      _panel([
        Text('Lezioni e file', style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < _resources.length; i++)
          _itemTile('${_resources[i]['title'] ?? _resources[i]['url']}',
              _resources[i]['type'] == 'url' ? '${_resources[i]['url']}' : 'Dispense', () {}, () => setState(() => _resources.removeAt(i))),
        OutlinedButton.icon(onPressed: _addResource, icon: const Icon(Icons.add_rounded), label: const Text('Aggiungi')),
      ]),
      _panel([
        Text('Termini collegati', style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in _related) InputChip(label: Text(r), onDeleted: () => setState(() => _related.remove(r))),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 16),
            label: const Text('termine'),
            onPressed: () async {
              final options = _terms.map((t) => '${t['term']}').where((t) => t != _term.text && !_related.contains(t)).toList()
                ..sort();
              final picked = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: p.eleganceDeepNavy,
                isScrollControlled: true,
                builder: (sheetContext) => SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
                    child: ListView(shrinkWrap: true, children: [
                      for (final o in options) ListTile(title: Text(o), onTap: () => Navigator.pop(sheetContext, o)),
                    ]),
                  ),
                ),
              );
              if (picked != null) setState(() => _related.add(picked));
            },
          ),
        ]),
      ]),
      _panel([
        Text('Chi lo firma', style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Il contenuto viene salvato con il tuo nome e la data. Restano anche quando non insegnerai più la materia; '
          'StudentLab può affidarlo a un altro docente. “Salva bozza” lo manda in moderazione senza cambiare '
          'quello che vedono gli studenti.',
          style: SlText.muted(p).copyWith(height: 1.45),
        ),
      ]),
    ];
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text(widget.entryId == null ? 'Nuovo termine' : 'Modifica termine'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: OutlinedButton(
              onPressed: _saving || _loading ? null : () => _save(publish: false),
              style: OutlinedButton.styleFrom(foregroundColor: p.pureWhite),
              child: const Text('Salva bozza'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving || _loading ? null : () => _save(publish: true),
              style: FilledButton.styleFrom(backgroundColor: p.skyBlue, foregroundColor: p.darkElegance),
              child: _saving
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.darkElegance))
                  : const Text('Salva e pubblica', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: p.skyBlue))
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_error != null) ...[SlErrorCard(title: 'Attenzione', message: _error!), const SizedBox(height: 12)],
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(children: main)),
                  const SizedBox(width: 16),
                  SizedBox(width: 420, child: Column(children: side)),
                ])
              else
                ...[...main, ...side],
            ]),
    );
  }
}
