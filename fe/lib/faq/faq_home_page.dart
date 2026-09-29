import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../social/auth/login_page.dart';
import '../social/social_models.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'faq_api_service.dart';
import 'faq_new_question_page.dart';
import 'faq_question_page.dart';
import 'faq_widgets.dart';

/// Home "Domande" (canvas: Domande · home).
///
/// Filtri a chip come nelle Dispense: ateneo, dipartimento, corso, materia.
/// Chi ha l'account parte dal proprio percorso; l'ospite vede tutto e può
/// scegliere. Si vedono solo domande approvate.
class FaqHomePage extends StatefulWidget {
  final int? subjectId;
  final String? subjectName;

  const FaqHomePage({super.key, this.subjectId, this.subjectName});

  @override
  State<FaqHomePage> createState() => _FaqHomePageState();
}

class _FaqHomePageState extends State<FaqHomePage> {
  final FaqApiService _api = FaqApiService();
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _subjects = [];

  String? _university;
  String? _department;
  String? _course;
  int? _subjectId;
  String? _category;

  List<Map<String, dynamic>> _verified = [];
  List<Map<String, dynamic>> _unanswered = [];
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _results = [];
  int _resultsTotal = 0;

  bool get _searching => _search.text.trim().isNotEmpty || _category != null;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjectId;
    _start();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _subjects = await _api.filters();
    } catch (_) {
      _subjects = [];
    }
    if (_subjectId != null) {
      final match = _subjects.where((s) => s['id'] == _subjectId);
      if (match.isNotEmpty) {
        _university = '${match.first['university']}';
        _department = '${match.first['department']}';
        _course = '${match.first['course']}';
      }
    } else if (AuthSession.instance.isAuthenticated && AuthSession.instance.currentUserId != null) {
      // Chi ha l'account parte dal proprio percorso corrente.
      try {
        final paths = await ApiService().getUserAcademicPaths(AuthSession.instance.currentUserId!);
        final enrolled = paths.where((p) => p.status == AcademicPathStatus.enrolled).toList();
        final current = enrolled.where((p) => p.isCurrent);
        final SocialAcademicPath? path =
            current.isNotEmpty ? current.first : (enrolled.isNotEmpty ? enrolled.first : null);
        if (path != null) {
          _university = path.university;
          _department = path.department;
          _course = faqCourseLabel(path.course);
        }
      } catch (_) {}
    }
    await _load();
  }

  Map<String, dynamic> _context() => {
        'university': _subjectId == null ? _university : null,
        'department': _subjectId == null ? _department : null,
        'course': _subjectId == null ? _course : null,
        'subjectId': _subjectId,
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final c = _context();
    try {
      if (_searching) {
        final result = await _api.questions(
            university: c['university'], department: c['department'], course: c['course'],
            subjectId: c['subjectId'], category: _category, query: _search.text, sort: 'useful', limit: 50);
        _results = (result['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _resultsTotal = int.tryParse('${result['total']}') ?? _results.length;
      } else {
        final all = await Future.wait([
          _api.questions(university: c['university'], department: c['department'], course: c['course'],
              subjectId: c['subjectId'], view: 'verified', limit: 3),
          _api.questions(university: c['university'], department: c['department'], course: c['course'],
              subjectId: c['subjectId'], view: 'unanswered', sort: 'recent', limit: 5),
          _api.questions(university: c['university'], department: c['department'], course: c['course'],
              subjectId: c['subjectId'], sort: 'recent', limit: 10),
        ]);
        List<Map<String, dynamic>> items(Map<String, dynamic> r) =>
            (r['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _verified = items(all[0]);
        _unanswered = items(all[1]);
        _recent = items(all[2]);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = faqError(e, 'Non è stato possibile caricare le domande.');
        });
      }
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
    setState(() {});
  }

  Future<void> _open(Map<String, dynamic> question) async {
    final id = int.tryParse('${question['id']}');
    if (id == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FaqQuestionPage(questionId: id)));
    if (mounted) await _load();
  }

  Future<void> _ask() async {
    if (!_api.isAuthenticated) {
      final p = context.palette;
      final login = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('Serve un account'),
          content: Text('Per fare una domanda serve un account. Da ospite puoi leggere e rispondere.',
              style: SlText.body(p)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Non ora')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Accedi')),
          ],
        ),
      );
      if (login == true && mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
        if (mounted) setState(() {});
      }
      return;
    }
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FaqNewQuestionPage(
        subjectId: _subjectId,
        university: _university,
        department: _department,
        course: _course,
      ),
    ));
    if (sent == true && mounted) await _load();
  }

  Future<void> _openMine() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _FaqMinePage()));
    if (mounted) await _load();
  }

  // --- filtri ----------------------------------------------------------------

  List<String> _distinct(String key, bool Function(Map<String, dynamic>) where) {
    final values = _subjects.where(where).map((s) => '${s[key] ?? ''}').where((v) => v.isNotEmpty).toSet().toList()
      ..sort();
    return values;
  }

  Widget _filters() {
    final universities = _distinct('university', (_) => true);
    final departments = _distinct('department', (s) => _university == null || s['university'] == _university);
    final courses = _distinct('course', (s) =>
        (_university == null || s['university'] == _university) && (_department == null || s['department'] == _department));
    final subjects = _subjects
        .where((s) =>
            (_university == null || s['university'] == _university) &&
            (_department == null || s['department'] == _department) &&
            (_course == null || s['course'] == _course))
        .toList();
    final selectedSubject = subjects.where((s) => s['id'] == _subjectId).map((s) => '${s['name']}').firstOrNull;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      FaqFilterChip(
        label: 'Ateneo',
        selected: _university,
        options: universities,
        onChanged: (v) {
          setState(() {
            _university = v;
            _department = null;
            _course = null;
            _subjectId = null;
          });
          _load();
        },
      ),
      FaqFilterChip(
        label: 'Dipartimento',
        selected: _department,
        options: departments,
        onChanged: (v) {
          setState(() {
            _department = v;
            _course = null;
            _subjectId = null;
          });
          _load();
        },
      ),
      FaqFilterChip(
        label: 'Corso',
        selected: _course,
        options: courses,
        onChanged: (v) {
          setState(() {
            _course = v;
            _subjectId = null;
          });
          _load();
        },
      ),
      FaqFilterChip(
        label: 'Materia',
        selected: selectedSubject,
        options: subjects.map((s) => '${s['name']}').toSet().toList()..sort(),
        onChanged: (v) {
          setState(() => _subjectId = v == null ? null : subjects.firstWhere((s) => s['name'] == v)['id'] as int?);
          _load();
        },
      ),
    ]);
  }

  String get _contextLabel {
    final subject = _subjects.where((s) => s['id'] == _subjectId).map((s) => '${s['name']}').firstOrNull;
    return subject ?? _course ?? _department ?? _university ?? 'Tutti gli atenei';
  }

  // --- UI --------------------------------------------------------------------

  Widget _section(String title, {String? action, VoidCallback? onAction}) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action)),
      ]),
    );
  }

  Widget _verifiedPanel() {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.materialSky.withValues(alpha: 0.30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const SlStatusBadge(label: 'Risposte verificate', tone: SlTone.success),
          const SizedBox(width: 8),
          Expanded(child: Text(_contextLabel, overflow: TextOverflow.ellipsis, style: SlText.muted(p))),
        ]),
        const SizedBox(height: 8),
        Text('Le domande più utili', style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final q in _verified)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.eleganceMidnight,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(q),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.check_rounded, size: 16, color: p.adminGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${q['title']}',
                            style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('${q['answers_count']} risposte · ${q['useful_count']} utili',
                            style: SlText.muted(p).copyWith(fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _categories() {
    final p = context.palette;
    return LayoutBuilder(builder: (context, constraints) {
      final int columns = constraints.maxWidth >= 560 ? 6 : 3;
      const double gap = 8;
      final double width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final (id, label, icon, tone) in faqCategories)
          SizedBox(
            width: width,
            child: Material(
              color: _category == id ? tone.resolve(p).withValues(alpha: 0.12) : p.eleganceMidnight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: _category == id ? tone.resolve(p) : p.pureWhite.withValues(alpha: 0.08)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() => _category = _category == id ? null : id);
                  _load();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SlIconTile(icon: icon, tone: tone, size: 32),
                    const SizedBox(height: 6),
                    Text(label, style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final signedIn = _api.isAuthenticated;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text(widget.subjectName == null ? 'Domande' : 'Domande · ${widget.subjectName}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (signedIn)
            IconButton(tooltip: 'Le mie domande', onPressed: _openMine, icon: const Icon(Icons.person_outline_rounded)),
          IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ask,
        backgroundColor: p.skyBlue,
        foregroundColor: p.darkElegance,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Fai una domanda', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                children: [
                  TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    style: TextStyle(color: p.pureWhite),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Cerca: “appello Reti”, “propedeuticità”…',
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Cancella',
                              onPressed: () {
                                _search.clear();
                                _load();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: p.eleganceMidnight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _filters(),
                  if (!signedIn) ...[
                    const SizedBox(height: 12),
                    Text('Da ospite puoi leggere e rispondere; per fare una domanda serve un account.',
                        style: SlText.muted(p)),
                  ],
                  const SizedBox(height: 16),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator(color: p.skyBlue)),
                    )
                  else if (_error != null)
                    SlErrorCard(title: 'Domande non disponibili', message: _error!, onRetry: _load)
                  else if (_searching) ...[
                    _section('$_resultsTotal risultati'
                        '${_category != null ? ' · ${faqCategoryLabel(_category)}' : ''}',
                        action: 'Azzera', onAction: () {
                      _search.clear();
                      setState(() => _category = null);
                      _load();
                    }),
                    if (_results.isEmpty)
                      const SlEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nessuna domanda trovata',
                        message: 'Prova con altre parole o allarga i filtri. Se nessuno l’ha ancora chiesto, fai tu la domanda.',
                      ),
                    for (final q in _results) FaqQuestionCard(question: q, onTap: () => _open(q)),
                  ] else ...[
                    if (_verified.isNotEmpty) ...[_verifiedPanel(), const SizedBox(height: 18)],
                    const SlOverline('Per argomento'),
                    const SizedBox(height: 10),
                    _categories(),
                    const SizedBox(height: 20),
                    _section('Aspettano una risposta'),
                    if (_unanswered.isEmpty)
                      Text('Nessuna domanda senza risposta qui.', style: SlText.muted(p))
                    else
                      for (final q in _unanswered) FaqQuestionCard(question: q, onTap: () => _open(q)),
                    const SizedBox(height: 14),
                    _section('Ultime domande'),
                    if (_recent.isEmpty)
                      const SlEmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Ancora nessuna domanda',
                        message: 'Sii il primo: le domande approvate compaiono qui per tutti gli studenti.',
                      )
                    else
                      for (final q in _recent) FaqQuestionCard(question: q, onTap: () => _open(q)),
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

/// Le mie domande (anche quelle in attesa di controllo).
class _FaqMinePage extends StatefulWidget {
  const _FaqMinePage();

  @override
  State<_FaqMinePage> createState() => _FaqMinePageState();
}

class _FaqMinePageState extends State<_FaqMinePage> {
  final FaqApiService _api = FaqApiService();
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _answers = [];
  bool _loading = true;
  String? _error;

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
      final data = await _api.mine();
      _questions = (data['questions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _answers = (data['answers'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _error = faqError(e, 'Contenuti non disponibili.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openQuestion(int? id) async {
    if (id == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FaqQuestionPage(questionId: id)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: const Text('Le mie domande e risposte'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: p.skyBlue))
          : _error != null
              ? Padding(padding: const EdgeInsets.all(16), child: SlErrorCard(title: 'Errore', message: _error!, onRetry: _load))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const SlOverline('Domande'),
                  const SizedBox(height: 8),
                  if (_questions.isEmpty) Text('Non hai ancora fatto domande.', style: SlText.muted(p)),
                  for (final q in _questions)
                    FaqQuestionCard(question: q, onTap: () => _openQuestion(int.tryParse('${q['id']}'))),
                  const SizedBox(height: 16),
                  const SlOverline('Risposte'),
                  const SizedBox(height: 8),
                  if (_answers.isEmpty) Text('Non hai ancora risposto.', style: SlText.muted(p)),
                  for (final a in _answers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: p.eleganceMidnight,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openQuestion(int.tryParse('${a['question_id']}')),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (faqStatusBadge(a['status']?.toString()) != null) ...[
                                faqStatusBadge(a['status']?.toString())!,
                                const SizedBox(height: 6),
                              ],
                              Text('${a['body']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: SlText.body(p)),
                              const SizedBox(height: 4),
                              Text(faqRelative(a['created_at']), style: SlText.muted(p).copyWith(fontSize: 11)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ]),
    );
  }
}
