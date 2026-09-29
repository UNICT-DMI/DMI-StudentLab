import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../faq/faq_widgets.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';
import 'dictionary_editor_page.dart';
import 'dictionary_entry_page.dart';
import 'dictionary_import_page.dart';
import 'dictionary_moderation_page.dart';
import 'dictionary_review_page.dart';
import 'dictionary_sources_page.dart';

/// Materia del Dizionario (canvas: Dizionario · materia).
///
/// Anno accademico con i docenti di quell'anno, viste Per argomento / A–Z /
/// Salvati, PDF di ogni argomento. Chi può scrivere vede "Nuovo termine",
/// "Importa JSON", "Modera i termini", "Fonti" e (admin) "Revisione anni".
class DictionarySubjectPage extends StatefulWidget {
  final int subjectId;

  const DictionarySubjectPage({super.key, required this.subjectId});

  @override
  State<DictionarySubjectPage> createState() => _DictionarySubjectPageState();
}

class _DictionarySubjectPageState extends State<DictionarySubjectPage> {
  final DictionaryApiService _api = DictionaryApiService();
  Map<String, dynamic>? _data;
  String? _year;
  bool _loading = true;
  String? _error;
  String _view = 'topics';
  final Set<Object?> _open = <Object?>{};
  Set<int> _saved = <int>{};

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
      _data = await _api.subject(widget.subjectId, year: _year);
      _year = _data?['year']?.toString();
      _saved = (await DictionaryLocalStore.saved()).map((e) => int.tryParse('${e['id']}') ?? -1).toSet();
      final topics = (_data?['topics'] as List? ?? []);
      if (_open.isEmpty && topics.isNotEmpty) _open.add((topics.first as Map)['id']);
    } catch (e) {
      _error = faqError(e, 'Materia non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _topics =>
      (_data?['topics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  List<Map<String, dynamic>> get _allEntries {
    final list = <Map<String, dynamic>>[];
    for (final t in _topics) {
      for (final e in (t['entries'] as List? ?? [])) {
        list.add({...Map<String, dynamic>.from(e as Map), 'topic': t['title']});
      }
    }
    list.sort((a, b) => '${a['term']}'.toLowerCase().compareTo('${b['term']}'.toLowerCase()));
    return list;
  }

  Future<void> _openEntry(Map<String, dynamic> e) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DictionaryEntryPage(entryId: int.parse('${e['id']}'), year: _year),
    ));
    if (mounted) await _load();
  }

  Future<void> _downloadPdf(Map<String, dynamic> topic) async {
    final id = int.tryParse('${topic['id']}');
    if (id == null || _year == null) return;
    final ok = await launchUrl(_api.topicPdfUri(id, _year!), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non è stato possibile aprire il PDF.')));
    }
  }

  Widget _entryRow(Map<String, dynamic> e) {
    final p = context.palette;
    final bool older = e['from_year'] != null && e['from_year'] != _year;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openEntry(e),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${e['term']}', style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                if (_saved.contains(e['id'])) Icon(Icons.star_rounded, size: 16, color: p.adminAmber),
                if (e['has_exam'] == true) ...[
                  const SizedBox(width: 6),
                  const SlStatusBadge(label: 'Esame', tone: SlTone.warning),
                ],
              ]),
              if ('${e['informal'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('${e['informal']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: SlText.muted(p).copyWith(fontSize: 12)),
              ],
              if (older) ...[
                const SizedBox(height: 3),
                Text('dall’A.A. ${e['from_year']}', style: SlText.mono(p, size: 10, color: p.pureWhite.withValues(alpha: 0.5))),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _topicSection(Map<String, dynamic> t) {
    final p = context.palette;
    final entries = (t['entries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final bool open = _open.contains(t['id']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.eleganceSoftNight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => open ? _open.remove(t['id']) : _open.add(t['id'])),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const SlIconTile(icon: Icons.folder_outlined, size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${t['title']}', style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('${entries.length} termini', style: SlText.mono(p, size: 11)),
                      ]),
                    ),
                    Icon(open ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                        color: p.pureWhite.withValues(alpha: 0.5)),
                  ]),
                ),
              ),
            ),
            if (t['id'] != null)
              TextButton.icon(
                onPressed: () => _downloadPdf(t),
                icon: Icon(Icons.picture_as_pdf_outlined, size: 17, color: p.adminCyan),
                label: Text('PDF', style: TextStyle(color: p.adminCyan, fontWeight: FontWeight.w600)),
              ),
          ]),
          if (open) ...[const SizedBox(height: 8), for (final e in entries) _entryRow(e)],
        ]),
      ),
    );
  }

  Future<void> _pickYear() async {
    final p = context.palette;
    final years = (_data?['years'] as List? ?? []).map((e) => '$e').toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final y in years)
            ListTile(
              title: Text('A.A. $y'),
              trailing: y == _year ? Icon(Icons.check_rounded, color: p.skyBlue) : null,
              onTap: () => Navigator.pop(sheetContext, y),
            ),
        ]),
      ),
    );
    if (picked != null && picked != _year) {
      _year = picked;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final subject = _data?['subject'] is Map ? Map<String, dynamic>.from(_data!['subject'] as Map) : null;
    final bool canEdit = _data?['can_edit'] == true;
    final bool isAdmin = _data?['is_admin'] == true;
    final teachers = (_data?['teachers'] as List? ?? []).map((e) => '$e').toList();
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text('${subject?['name'] ?? 'Dizionario'}'),
        actions: [
          if (canEdit)
            PopupMenuButton<String>(
              tooltip: 'Scrivi',
              color: p.eleganceDeepNavy,
              onSelected: (value) async {
                if (value == 'new') {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DictionaryEditorPage(subjectId: widget.subjectId, year: _year),
                  ));
                } else if (value == 'import') {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DictionaryImportPage(subjectId: widget.subjectId),
                  ));
                } else if (value == 'moderate') {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DictionaryModerationPage(subjectId: widget.subjectId, teacherMode: !isAdmin),
                  ));
                } else if (value == 'sources') {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DictionarySourcesPage(subjectId: widget.subjectId, teacherMode: !isAdmin),
                  ));
                } else if (value == 'review') {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DictionaryReviewPage(subjectId: widget.subjectId),
                  ));
                }
                if (mounted) await _load();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'new', child: Text('Nuovo termine')),
                const PopupMenuItem(value: 'import', child: Text('Importa JSON')),
                const PopupMenuItem(value: 'moderate', child: Text('Modera i termini')),
                const PopupMenuItem(value: 'sources', child: Text('Fonti')),
                if (isAdmin) const PopupMenuItem(value: 'review', child: Text('Revisione tra anni')),
              ],
              icon: const Icon(Icons.edit_note_rounded),
            ),
        ],
      ),
      body: _loading && _data == null
          ? Center(child: CircularProgressIndicator(color: p.skyBlue))
          : _error != null
              ? Padding(padding: const EdgeInsets.all(16), child: SlErrorCard(title: 'Errore', message: _error!, onRetry: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: p.eleganceDeepNavy,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: p.materialSky.withValues(alpha: 0.30)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${subject?['course'] ?? ''} › ${subject?['name'] ?? ''}',
                                style: SlText.mono(p, size: 11, color: p.materialSky)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Text('Anno accademico', style: SlText.muted(p)),
                              const SizedBox(width: 8),
                              ActionChip(label: Text('${_year ?? ''} ▾'), onPressed: _pickYear),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              '${teachers.isEmpty ? 'Docenti non indicati' : 'Docenti: ${teachers.join(', ')}'} · ${_allEntries.length} termini',
                              style: SlText.muted(p).copyWith(fontSize: 12),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        SlFilterBar<String>(
                          selected: _view,
                          options: const [
                            SlFilterOption(value: 'topics', label: 'Per argomento'),
                            SlFilterOption(value: 'az', label: 'A–Z'),
                            SlFilterOption(value: 'saved', label: 'Salvati'),
                          ],
                          onSelected: (v) => setState(() => _view = v),
                        ),
                        const SizedBox(height: 14),
                        if (_topics.isEmpty)
                          const SlEmptyState(
                            icon: Icons.menu_book_outlined,
                            title: 'Nessun termine per quest’anno',
                            message: 'Prova un altro anno accademico.',
                          )
                        else if (_view == 'topics')
                          for (final t in _topics) _topicSection(t)
                        else ...[
                          for (final e in _allEntries.where((e) => _view == 'az' || _saved.contains(e['id']))) _entryRow(e),
                          if (_view == 'saved' && !_allEntries.any((e) => _saved.contains(e['id'])))
                            Text('Salva un termine con la stella: lo ritrovi qui.', style: SlText.muted(p)),
                        ],
                      ]),
                    ),
                  ),
                ),
    );
  }
}
