import 'dart:async';

import 'package:flutter/material.dart';

import '../faq/faq_widgets.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../social/social_models.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'dictionary_api_service.dart';
import 'dictionary_entry_page.dart';
import 'dictionary_import_page.dart';
import 'dictionary_moderation_page.dart';
import 'dictionary_subject_page.dart';

/// Dizionario (canvas: Dizionario · home). Per ospiti e utenti.
///
/// Chip ateneo, dipartimento e corso come nelle Dispense (chi ha l'account
/// parte dal proprio percorso), ricerca su tutti i termini, visti di recente
/// e le materie con il numero di termini e argomenti.
class DictionaryHomePage extends StatefulWidget {
  const DictionaryHomePage({super.key});

  @override
  State<DictionaryHomePage> createState() => _DictionaryHomePageState();
}

class _DictionaryHomePageState extends State<DictionaryHomePage> {
  final DictionaryApiService _api = DictionaryApiService();
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _results = [];
  bool _canWrite = false;

  String? _university;
  String? _department;
  String? _course;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _subjects = await _api.subjects();
      _recent = await DictionaryLocalStore.recent();
      if (_api.isAuthenticated) {
        try {
          _canWrite = (await _api.editableSubjects()).isNotEmpty;
        } catch (_) {
          _canWrite = false;
        }
        if (_university == null && AuthSession.instance.currentUserId != null) {
          try {
            final paths = await ApiService().getUserAcademicPaths(AuthSession.instance.currentUserId!);
            final enrolled = paths.where((p) => p.status == AcademicPathStatus.enrolled).toList();
            final current = enrolled.where((p) => p.isCurrent);
            final SocialAcademicPath? path =
                current.isNotEmpty ? current.first : (enrolled.isNotEmpty ? enrolled.first : null);
            // Si parte dal proprio corso solo se nel dizionario c'è qualcosa.
            if (path != null && _subjects.any((s) => s['course'] == path.course)) {
              _university = path.university;
              _department = path.department;
              _course = path.course;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      _error = faqError(e, 'Dizionario non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final found = await _api.search(value);
        if (mounted) setState(() => _results = found);
      } catch (_) {}
    });
    setState(() {});
  }

  List<String> _distinct(String key, bool Function(Map<String, dynamic>) where) =>
      _subjects.where(where).map((s) => '${s[key] ?? ''}').where((v) => v.isNotEmpty).toSet().toList()..sort();

  List<Map<String, dynamic>> get _shown => _subjects
      .where((s) =>
          (_university == null || s['university'] == _university) &&
          (_department == null || s['department'] == _department) &&
          (_course == null || s['course'] == _course))
      .toList();

  Future<void> _openEntry(int id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DictionaryEntryPage(entryId: id)));
    final recent = await DictionaryLocalStore.recent();
    if (mounted) setState(() => _recent = recent);
  }

  Future<void> _openSubject(Map<String, dynamic> subject) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DictionarySubjectPage(subjectId: int.parse('${subject['id']}')),
    ));
    final recent = await DictionaryLocalStore.recent();
    if (mounted) setState(() => _recent = recent);
  }

  Widget _subjectCard(Map<String, dynamic> s) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.eleganceMidnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.skyBlue.withValues(alpha: 0.12)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSubject(s),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const SlIconTile(icon: Icons.menu_book_outlined, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['name']}', style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('${s['terms']} termini · ${s['topics']} argomenti · ${s['course'] ?? ''}',
                      style: SlText.muted(p).copyWith(fontSize: 12)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: p.pureWhite.withValues(alpha: 0.4)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final searching = _search.text.trim().length >= 2;
    final shown = _shown;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: const Text('Dizionario', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_canWrite)
            IconButton(
              tooltip: 'Importa un dizionario JSON',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DictionaryImportPage()));
                if (mounted) await _load();
              },
              icon: const Icon(Icons.upload_file_rounded),
            ),
          if (_canWrite)
            IconButton(
              tooltip: 'Modera i termini',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const DictionaryModerationPage(),
                ));
                if (mounted) await _load();
              },
              icon: const Icon(Icons.fact_check_outlined),
            ),
          IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    style: TextStyle(color: p.pureWhite),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Cerca un termine: “subnetting”, “Dijkstra”…',
                      filled: true,
                      fillColor: p.eleganceMidnight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Cancella',
                              onPressed: () {
                                _search.clear();
                                setState(() => _results = []);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    FaqFilterChip(
                      label: 'Ateneo',
                      selected: _university,
                      options: _distinct('university', (_) => true),
                      onChanged: (v) => setState(() {
                        _university = v;
                        _department = null;
                        _course = null;
                      }),
                    ),
                    FaqFilterChip(
                      label: 'Dipartimento',
                      selected: _department,
                      options: _distinct('department', (s) => _university == null || s['university'] == _university),
                      onChanged: (v) => setState(() {
                        _department = v;
                        _course = null;
                      }),
                    ),
                    FaqFilterChip(
                      label: 'Corso',
                      selected: _course,
                      options: _distinct('course', (s) =>
                          (_university == null || s['university'] == _university) &&
                          (_department == null || s['department'] == _department)),
                      onChanged: (v) => setState(() => _course = v),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (_loading)
                    Padding(padding: const EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: p.skyBlue)))
                  else if (_error != null)
                    SlErrorCard(title: 'Dizionario non disponibile', message: _error!, onRetry: _load)
                  else if (searching) ...[
                    Text('${_results.length} termini trovati',
                        style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    for (final r in _results)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const SlIconTile(icon: Icons.short_text_rounded, size: 36),
                        title: Text('${r['term']}', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
                        subtitle: Text('${r['subject_name']} · ${r['course'] ?? ''}', style: SlText.muted(p)),
                        onTap: () => _openEntry(int.parse('${r['id']}')),
                      ),
                  ] else ...[
                    if (_recent.isNotEmpty) ...[
                      const SlOverline('Visti di recente'),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final r in _recent)
                          ActionChip(label: Text('${r['term']}'), onPressed: () => _openEntry(int.parse('${r['id']}'))),
                      ]),
                      const SizedBox(height: 18),
                    ],
                    SlOverline(_course == null ? 'Materie' : 'Le materie del corso'),
                    const SizedBox(height: 10),
                    if (shown.isEmpty)
                      const SlEmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'Ancora nessun termine qui',
                        message: 'Il dizionario si riempie quando docenti o StudentLab caricano le definizioni. Prova a cambiare i filtri.',
                      ),
                    for (final s in shown) _subjectCard(s),
                    const SizedBox(height: 8),
                    Text(
                      _api.isAuthenticated
                          ? 'I termini salvati e quelli visti di recente restano su questo dispositivo.'
                          : 'Senza account puoi consultare tutto e scaricare i PDF degli argomenti.',
                      style: SlText.muted(p).copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
