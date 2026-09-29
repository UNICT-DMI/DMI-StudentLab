import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_local_repository.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/exercise_session_page.dart';
import 'package:fe/quiz/assigned_quizzes_page.dart';
import 'package:fe/quiz/services/assigned_quiz_service.dart';

/// Scelta degli esercizi di una materia, in due passi.
///
/// 1. **Filtri**: argomenti, durata, solo nuovi / solo da rivedere. Accanto a ogni
///    scelta c'è quanti esercizi si otterrebbero. In cima, con l'account, i quiz
///    assegnati da fare in questa materia.
/// 2. **Schede dei tipi**: per ogni tipo quanti esercizi ci sono con quei filtri,
///    argomenti coperti, durata media, nuovi e com'è andata finora. Si scelgono
///    uno o più tipi, quanti esercizi fare e come: "Esercitati" (correzione subito)
///    oppure "Quiz" (correzione alla consegna, anche a tempo).
///
/// Niente filtro per difficoltà: le domande non hanno una categoria facile/media/difficile.
/// Le flashcard stanno nel Ripasso. Con l'account lo storico viene dal server; da ospite
/// dal telefono (mandato solo per il conteggio, il server non lo salva).
class ExerciseCatalogPage extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final String? subjectLabel;
  final List<String> initialArguments;

  const ExerciseCatalogPage({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    this.subjectLabel,
    this.initialArguments = const <String>[],
  });

  @override
  State<ExerciseCatalogPage> createState() => _ExerciseCatalogPageState();
}

class _ExerciseCatalogPageState extends State<ExerciseCatalogPage> {
  final ExerciseApiService _api = ExerciseApiService();
  final ExerciseLocalRepository _local = ExerciseLocalRepository();

  late ExerciseChoice _choice = ExerciseChoice(arguments: widget.initialArguments);
  Map<String, dynamic> _data = <String, dynamic>{};
  List<Map<String, dynamic>> _history = const <Map<String, dynamic>>[];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _step = 0;
  int _request = 0;
  Timer? _debounce;
  final Set<String> _selectedTypes = <String>{};
  bool _typesTouched = false;
  int _count = 10;

  /// false = Esercitati (correzione subito), true = Quiz (correzione alla consegna).
  bool _quizMode = false;
  bool _quizTimed = false;

  /// Quiz assegnati (docente o StudentLab) ancora da fare in questa materia.
  List<Map<String, dynamic>> _assigned = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init({bool first = true}) async {
    unawaited(_loadAssigned());
    if (!_api.isLoggedIn) {
      try {
        _history = await _local.guestHistory(widget.department, widget.course, widget.subject);
      } catch (_) {
        _history = const <Map<String, dynamic>>[];
      }
    }
    await _refresh(first: first);
  }

  Future<void> _refresh({bool first = false}) async {
    if (!mounted) return;
    final int request = ++_request;
    bool stale = false;
    setState(() {
      if (first) _loading = true;
      _refreshing = !first;
      _error = null;
    });
    try {
      final Map<String, dynamic> data = await _api.overview(
        department: widget.department,
        course: widget.course,
        subject: widget.subject,
        choice: _choice,
        history: _history,
      );
      if (request != _request || !mounted) return; // risposta superata da un filtro più recente
      _data = data;
      if (first) {
        // Argomenti passati dalla pagina precedente che la materia non ha più.
        // Il server confronta senza maiuscole: si tiene la sua grafia.
        final Map<String, String> known = <String, String>{
          for (final Map<String, dynamic> a in _argumentCounts) a['name'].toString().toLowerCase(): a['name'].toString(),
        };
        final List<String> kept = _choice.arguments
            .map((String a) => known[a.trim().toLowerCase()])
            .whereType<String>()
            .toSet()
            .toList();
        if (kept.join('\u0001') != _choice.arguments.join('\u0001')) {
          _choice = _choice.copyWith(arguments: kept);
          stale = true;
        }
      }
      _syncSelection();
    } catch (error) {
      if (request != _request || !mounted) return;
      _error = cleanError(error, 'Esercizi non disponibili.');
    }
    if (mounted && request == _request) {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      if (stale) unawaited(_refresh());
    }
  }

  Future<void> _loadAssigned() async {
    if (!_api.isLoggedIn) return;
    String norm(dynamic value) => (value?.toString() ?? '').trim().toLowerCase();
    try {
      final List<Map<String, dynamic>> all = await AssignedQuizService().getAssignedQuizzes();
      final List<Map<String, dynamic>> mine = all
          .where((Map<String, dynamic> a) =>
              norm(a['department']) == norm(widget.department) &&
              norm(a['course']) == norm(widget.course) &&
              norm(a['subject']) == norm(widget.subject) &&
              a['is_completed'] != true &&
              a['is_expired'] != true &&
              (a['can_start'] == true || a['is_in_progress'] == true))
          .toList();
      if (mounted) setState(() => _assigned = mine);
    } catch (_) {
      // I quiz assegnati sono un'aggiunta: se non si caricano la pagina funziona lo stesso.
    }
  }

  Future<void> _openAssigned() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AssignedQuizzesPage()));
    if (mounted) unawaited(_loadAssigned());
  }

  /// Mentre i conteggi non corrispondono ai filtri appena scelti i pulsanti restano spenti.
  bool get _pending => _refreshing || (_debounce?.isActive ?? false);

  void _setChoice(ExerciseChoice choice) {
    setState(() {
      _choice = choice;
      _refreshing = true;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _refresh);
  }

  // ------------------------------------------------------------------ dati

  /// Tipi che l'app sa mostrare. I tipi fuori dall'area del corso (es. "Scrivi il codice" a
  /// Giurisprudenza) si nascondono se non hanno esercizi: se il docente ne carica, compaiono.
  List<Map<String, dynamic>> get _cards => asMapList(_data['types'])
      .where((Map<String, dynamic> t) =>
          t['type'] != 'flashcard' &&
          (t['type'] == kMultipleChoice || kExerciseTypes.contains(t['type']?.toString())) &&
          !(t['in_area'] == false && t['available'] != true))
      .toList();

  List<Map<String, dynamic>> get _practiceCards => _cards;

  Map<String, dynamic> get _filterCounts => asMap(_data['filters']);

  List<Map<String, dynamic>> get _argumentCounts => asMapList(_filterCounts['arguments']);

  int get _total => _int(_data['total']);

  static int _int(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;

  Map<String, dynamic>? _card(String type) =>
      _cards.where((Map<String, dynamic> t) => t['type'] == type).firstOrNull;

  /// Esercizi disponibili nei tipi scelti; null se un tipo genera varianti (nessun limite).
  int? get _selectedAvailable {
    int sum = 0;
    for (final String type in _selectedTypes) {
      final Map<String, dynamic>? card = _card(type);
      if (card == null) continue;
      if (card['variants'] == true) return null;
      sum += _int(card['count']);
    }
    return sum;
  }

  /// Dopo ogni aggiornamento: toglie i tipi rimasti senza esercizi; la prima volta li sceglie tutti.
  void _syncSelection() {
    final Set<String> available = _practiceCards
        .where((Map<String, dynamic> t) => t['available'] == true)
        .map((Map<String, dynamic> t) => t['type'].toString())
        .toSet();
    _selectedTypes.removeWhere((String t) => !available.contains(t));
    if (!_typesTouched && _selectedTypes.isEmpty) _selectedTypes.addAll(available);
    final int? max = _selectedAvailable;
    if (max != null && max > 0 && _count > max) _count = max.clamp(1, 30);
  }

  /// Durata media di un esercizio dei tipi scelti (per proporre il tempo del quiz).
  int get _selectedAvgSeconds {
    int seconds = 0;
    int weight = 0;
    for (final String type in _selectedTypes) {
      final Map<String, dynamic>? card = _card(type);
      final int avg = _int(card?['avg_seconds']);
      final int n = _int(card?['count']);
      if (avg <= 0 || n <= 0) continue;
      seconds += avg * n;
      weight += n;
    }
    return weight == 0 ? 60 : (seconds / weight).round();
  }

  /// Tempo del quiz: durata media × numero di esercizi, con un margine del 50%,
  /// arrotondato al minuto (almeno 2 minuti).
  int _quizSeconds(int count) {
    final int raw = (_selectedAvgSeconds * count * 1.5).round();
    final int minutes = (raw / 60).ceil();
    return (minutes < 2 ? 2 : minutes) * 60;
  }

  // ------------------------------------------------------------------ azioni

  void _start() {
    final int? max = _selectedAvailable;
    if (_pending || _selectedTypes.isEmpty || max == 0) return;
    final int count = _count.clamp(1, max == null ? 30 : max.clamp(1, 30));
    final String subject = widget.subjectLabel ?? 'Esercizi';
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ExerciseSessionPage.practice(
        department: widget.department,
        course: widget.course,
        subject: widget.subject,
        title: _quizMode ? 'Quiz · $subject' : subject,
        types: _selectedTypes.toList(),
        arguments: _choice.arguments,
        count: count,
        choice: _choice,
        quizMode: _quizMode,
        timeLimitSeconds: _quizMode && _quizTimed ? _quizSeconds(count) : null,
      ),
    )).then((_) {
      // Al ritorno "nuovi" e "da rivedere" sono cambiati.
      if (!mounted) return;
      _api.isLoggedIn ? _refresh() : _init(first: false);
    });
  }

  // ------------------------------------------------------------------ UI comune

  Widget _section(BuildContext context, String title, {String? hint, Widget? trailing, required Widget child}) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: SlOverline(title)),
          if (trailing != null) trailing,
        ]),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(hint, style: SlText.muted(p).copyWith(fontSize: 11.5)),
        ],
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _chip(BuildContext context,
      {required String label, required int? count, required bool selected, required ValueChanged<bool> onSelected}) {
    final p = context.palette;
    final bool empty = count == 0 && !selected;
    return FilterChip(
      label: Text.rich(TextSpan(children: <InlineSpan>[
        TextSpan(text: label),
        if (count != null)
          TextSpan(
            text: '  $count',
            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: p.pureWhite.withValues(alpha: 0.55)),
          ),
      ])),
      selected: selected,
      onSelected: empty ? null : onSelected,
      showCheckmark: false,
      selectedColor: p.skyBlue.withValues(alpha: 0.22),
      side: BorderSide(color: selected ? p.skyBlue.withValues(alpha: 0.7) : p.pureWhite.withValues(alpha: 0.12)),
    );
  }

  // ------------------------------------------------------------------ passo 1

  Widget _filtersStep(BuildContext context) {
    final Map<String, dynamic> counts = _filterCounts;
    final Map<String, dynamic> durations = asMap(counts['durations']);
    final int short = _int(durations['short']);
    final int medium = _int(durations['medium']);
    final int long = _int(durations['long']);
    final int seen = _int(counts['seen']);
    final int toReview = _int(counts['to_review']);
    final List<Map<String, dynamic>> arguments = _argumentCounts;
    final bool guest = !_api.isLoggedIn;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: <Widget>[
      _stepHeader(context, 1, 'Cosa vuoi esercitare?',
          'Scegli i filtri: accanto a ogni voce vedi quanti esercizi ottieni.'),
      if (_assigned.isNotEmpty) _assignedSection(context),
      if (arguments.isNotEmpty)
        _section(
          context,
          'ARGOMENTI',
          hint: _choice.arguments.isEmpty ? 'Nessuno scelto: vanno bene tutti.' : null,
          trailing: _choice.arguments.isEmpty
              ? null
              : TextButton(
                  onPressed: () => _setChoice(_choice.copyWith(arguments: const <String>[])),
                  child: const Text('Tutti'),
                ),
          child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            for (final Map<String, dynamic> a in arguments)
              _chip(
                context,
                label: a['name'].toString(),
                count: _int(a['count']),
                selected: _choice.arguments.contains(a['name'].toString()),
                onSelected: (bool on) {
                  final String name = a['name'].toString();
                  final List<String> next = List<String>.of(_choice.arguments)..remove(name);
                  if (on) next.add(name);
                  _setChoice(_choice.copyWith(arguments: next));
                },
              ),
          ]),
        ),
      _section(
        context,
        'DURATA DI UN ESERCIZIO',
        child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final (String label, int? seconds, int count) in <(String, int?, int)>[
            ('Brevi · fino a 1 min', 60, short),
            ('Fino a 3 min', 180, short + medium),
            ('Qualsiasi', null, short + medium + long),
          ])
            _chip(
              context,
              label: label,
              count: count,
              selected: _choice.maxSeconds == seconds,
              onSelected: (_) => _setChoice(seconds == null
                  ? _choice.copyWith(clearMaxSeconds: true)
                  : _choice.copyWith(maxSeconds: seconds)),
            ),
        ]),
      ),
      _section(
        context,
        'IL TUO PERCORSO',
        hint: guest
            ? 'Senza account si usa lo storico di questo telefono.'
            : 'Dallo storico del tuo account.',
        child: Column(children: <Widget>[
          _switchRow(
            context,
            icon: Icons.fiber_new_outlined,
            title: 'Solo esercizi nuovi',
            subtitle: seen == 0 ? 'Non hai ancora svolto esercizi di questa materia.' : '$seen già svolti verranno saltati.',
            value: _choice.onlyNew,
            enabled: seen > 0 || _choice.onlyNew,
            onChanged: (bool v) => _setChoice(_choice.copyWith(onlyNew: v, onlyMistakes: v ? false : null)),
          ),
          const SizedBox(height: 6),
          _switchRow(
            context,
            icon: Icons.replay_rounded,
            title: 'Solo da rivedere',
            subtitle: toReview == 0
                ? 'Nessun esercizio sbagliato da rifare.'
                : '$toReview con l’ultima risposta sbagliata o incompleta.',
            value: _choice.onlyMistakes,
            enabled: toReview > 0 || _choice.onlyMistakes,
            onChanged: (bool v) => _setChoice(_choice.copyWith(onlyMistakes: v, onlyNew: v ? false : null)),
          ),
        ]),
      ),
    ]);
  }

  Widget _assignedSection(BuildContext context) {
    final p = context.palette;
    final List<Map<String, dynamic>> shown = _assigned.take(3).toList();
    return _section(
      context,
      'ASSEGNATI A TE IN QUESTA MATERIA',
      hint: 'Quiz e compiti del docente o di StudentLab: contano come consegne.',
      trailing: TextButton(onPressed: _openAssigned, child: const Text('Tutti')),
      child: Column(children: <Widget>[
        for (final Map<String, dynamic> a in shown)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openAssigned,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.adminAmber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.assignment_outlined, color: p.adminAmber, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(
                      (a['title']?.toString().trim().isNotEmpty ?? false) ? a['title'].toString() : 'Quiz assegnato',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    Text(_assignedLine(a), style: SlText.muted(p).copyWith(fontSize: 11.5)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: p.pureWhite.withValues(alpha: 0.5)),
              ]),
            ),
          ),
        if (_assigned.length > shown.length)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('e altri ${_assigned.length - shown.length}', style: SlText.muted(p).copyWith(fontSize: 11.5)),
          ),
      ]),
    );
  }

  String _assignedLine(Map<String, dynamic> a) {
    final List<String> parts = <String>[
      if (a['is_in_progress'] == true) 'In corso',
      if (_int(a['question_count']) > 0) '${_int(a['question_count'])} domande',
      if (a['execution_mode']?.toString() == 'simulation') 'correzione alla consegna',
    ];
    final DateTime? due = DateTime.tryParse('${a['due_at'] ?? ''}')?.toLocal();
    if (due != null) {
      final int days = due.difference(DateTime.now()).inDays;
      parts.add(days <= 0
          ? 'scade oggi alle ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}'
          : days == 1
              ? 'scade domani'
              : 'scade il ${due.day}/${due.month}');
    }
    return parts.isEmpty ? 'Da fare' : parts.join(' · ');
  }

  Widget _stepHeader(BuildContext context, int step, String title, String subtitle) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.skyBlue.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Text('$step', style: TextStyle(color: p.skyBlue, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('Passo $step di 2 · $title',
                style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w700, fontSize: 16)),
            Text(subtitle, style: SlText.muted(p).copyWith(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _switchRow(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required bool enabled,
      required ValueChanged<bool> onChanged}) {
    final p = context.palette;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(children: <Widget>[
        Icon(icon, color: p.skyBlue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title, style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 13.5)),
            Text(subtitle, style: SlText.muted(p).copyWith(fontSize: 11.5)),
          ]),
        ),
        Switch(value: value, onChanged: enabled ? onChanged : null),
      ]),
    );
  }

  // ------------------------------------------------------------------ passo 2

  Widget _typesStep(BuildContext context) {
    final p = context.palette;
    final List<Map<String, dynamic>> cards = _practiceCards;
    final List<String> summary = _choice.summary;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: <Widget>[
      _stepHeader(context, 2, 'Scegli i tipi di esercizio',
          'Tocca le schede per sceglierne uno o più: gli esercizi si alternano.'),
      // Filtri scelti, modificabili.
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _step = 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: p.skyBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.skyBlue.withValues(alpha: 0.3)),
          ),
          child: Row(children: <Widget>[
            Icon(Icons.tune_rounded, color: p.skyBlue, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summary.isEmpty ? 'Tutti gli esercizi della materia' : summary.join(' · '),
                style: TextStyle(color: p.pureWhite, fontSize: 12.5),
              ),
            ),
            Text('Modifica', style: TextStyle(color: p.skyBlue, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ]),
        ),
      ),
      if (cards.every((Map<String, dynamic> t) => t['available'] != true))
        SlErrorCard(
          title: 'Nessun esercizio',
          message: 'Con questi filtri non c’è nessun esercizio. Prova ad allargarli.',
          onRetry: () => setState(() => _step = 0),
        ),
      LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
        final int columns = box.maxWidth >= 620 ? 2 : 1;
        final double width = (box.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
          for (final Map<String, dynamic> t in cards) SizedBox(width: width, child: _typeCard(context, t)),
        ]);
      }),
    ]);
  }

  Widget _typeCard(BuildContext context, Map<String, dynamic> card) {
    final p = context.palette;
    final String id = card['type'].toString();
    final ExerciseTypeInfo info = exerciseInfo(id);
    final bool available = card['available'] == true;
    final bool selected = _selectedTypes.contains(id);
    final Color color = categoryColor(context, info.category);
    final int count = _int(card['count']);
    final int templates = _int(card['templates']);
    final bool variants = card['variants'] == true;
    final int fresh = _int(card['new']);
    final int toReview = _int(card['to_review']);
    final int? avgSeconds = int.tryParse('${card['avg_seconds'] ?? ''}');
    final List<String> arguments = asStringList(card['arguments']);
    final Map<String, dynamic> stats = asMap(card['stats']);

    final String countText = variants
        ? (count == templates ? '$templates modelli · varianti sempre nuove' : '$count esercizi · anche varianti sempre nuove')
        : count == 1
            ? '1 esercizio'
            : '$count esercizi';

    final TextStyle muted = SlText.muted(p).copyWith(fontSize: 11.5);
    final List<Widget> facts = <Widget>[
      if (avgSeconds != null)
        _fact(context, Icons.schedule_rounded, '~ ${formatSeconds(avgSeconds)} l’uno'),
      if (available && fresh > 0 && fresh < count) _fact(context, Icons.fiber_new_outlined, '$fresh nuovi'),
      if (toReview > 0) _fact(context, Icons.replay_rounded, '$toReview da rivedere', color: p.adminAmber),
    ];

    return Opacity(
      opacity: available ? 1 : 0.5,
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : p.eleganceMidnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: selected ? color.withValues(alpha: 0.7) : p.pureWhite.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: !available
              ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(card['unavailable_reason']?.toString() ?? 'Nessun esercizio di questo tipo.')))
              : () => setState(() {
                    _typesTouched = true;
                    selected ? _selectedTypes.remove(id) : _selectedTypes.add(id);
                  }),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(info.icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(info.label, style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(info.purpose, maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
                  ]),
                ),
                Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: selected ? color : p.pureWhite.withValues(alpha: 0.3), size: 22),
              ]),
              const SizedBox(height: 10),
              Row(children: <Widget>[
                Text(categoryLabel(info.category),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    available ? countText : (card['unavailable_reason']?.toString() ?? 'Non disponibile'),
                    style: TextStyle(
                        color: available ? p.pureWhite : p.pureWhite.withValues(alpha: 0.7),
                        fontSize: 12.5,
                        fontWeight: available ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
              ]),
              if (available && facts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 6, children: facts),
              ],
              if (available && arguments.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  arguments.length <= 3
                      ? arguments.join(' · ')
                      : '${arguments.take(3).join(' · ')} e altri ${arguments.length - 3}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ],
              const SizedBox(height: 8),
              _statsLine(context, stats),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _fact(BuildContext context, IconData icon, String text, {Color? color}) {
    final p = context.palette;
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Icon(icon, size: 14, color: color ?? p.pureWhite.withValues(alpha: 0.55)),
      const SizedBox(width: 4),
      Text(text, style: SlText.muted(p).copyWith(fontSize: 11.5, color: color)),
    ]);
  }

  Widget _statsLine(BuildContext context, Map<String, dynamic> stats) {
    final p = context.palette;
    if (stats.isEmpty) {
      return Text('Non l’hai ancora provato', style: SlText.muted(p).copyWith(fontSize: 11, fontStyle: FontStyle.italic));
    }
    final double? avg = (stats['avg_score'] as num?)?.toDouble();
    final Color tone = avg == null
        ? p.pureWhite
        : avg >= 0.8
            ? p.adminGreen
            : avg >= 0.5
                ? p.adminAmber
                : const Color(0xFFFF8A80);
    return Row(children: <Widget>[
      Icon(Icons.insights_rounded, size: 14, color: tone),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          '${_int(stats['done'])} svolti'
          '${avg == null ? '' : ' · media ${(avg * 100).round()}%'}'
          '${_lastAt(stats['last_at'])}',
          style: SlText.muted(p).copyWith(fontSize: 11),
        ),
      ),
    ]);
  }

  String _lastAt(dynamic value) {
    final DateTime? when = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (when == null) return '';
    final int days = DateTime.now().difference(when).inDays;
    return switch (days) { <= 0 => ' · oggi', 1 => ' · ieri', < 30 => ' · $days giorni fa', _ => ' · più di un mese fa' };
  }

  // ------------------------------------------------------------------ barra in basso

  Widget _bottomBar(BuildContext context) {
    final p = context.palette;
    final Widget progress = _refreshing
        ? LinearProgressIndicator(minHeight: 2, color: p.skyBlue, backgroundColor: Colors.transparent)
        : const SizedBox(height: 2);
    if (_step == 0) {
      final int total = _total;
      return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        progress,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(children: <Widget>[
            if (!_choice.isEmpty)
              TextButton(
                onPressed: () => _setChoice(const ExerciseChoice()),
                child: const Text('Azzera'),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: total == 0 || _pending ? null : () => setState(() => _step = 1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(total == 0 ? 'Nessun esercizio con questi filtri' : 'Mostra esercizi ($total)'),
                ),
              ),
            ),
          ]),
        ),
      ]);
    }
    final int? max = _selectedAvailable;
    final int limit = max == null ? 30 : max.clamp(1, 30);
    final int count = _count.clamp(1, limit);
    final int quizMinutes = _quizSeconds(count) ~/ 60;
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      progress,
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.fitness_center_rounded, size: 18),
                    label: Text('Esercitati'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.assignment_turned_in_outlined, size: 18),
                    label: Text('Crea un quiz'),
                  ),
                ],
                selected: <bool>{_quizMode},
                showSelectedIcon: false,
                onSelectionChanged: (Set<bool> v) => setState(() => _quizMode = v.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 0, 0),
            child: _quizMode
                ? Row(children: <Widget>[
                    Expanded(
                      child: Text(
                        'Correzione alla consegna, un tentativo, niente suggerimenti.',
                        style: SlText.muted(p).copyWith(fontSize: 11.5),
                      ),
                    ),
                    Text('A tempo · $quizMinutes min', style: SlText.muted(p).copyWith(fontSize: 11.5)),
                    Switch(value: _quizTimed, onChanged: (bool v) => setState(() => _quizTimed = v)),
                  ])
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Correzione dopo ogni esercizio, con suggerimenti e due tentativi.',
                      style: SlText.muted(p).copyWith(fontSize: 11.5),
                    ),
                  ),
          ),
          Row(children: <Widget>[
            IconButton(
              tooltip: 'Meno',
              onPressed: count <= 1 ? null : () => setState(() => _count = count - 1),
              icon: const Icon(Icons.remove_rounded),
            ),
            Text('$count', style: TextStyle(color: p.pureWhite, fontSize: 20, fontWeight: FontWeight.w700)),
            IconButton(
              tooltip: 'Più',
              onPressed: count >= limit ? null : () => setState(() => _count = count + 1),
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _selectedTypes.isEmpty
                    ? 'Scegli almeno un tipo.'
                    : '${_selectedTypes.length == 1 ? '1 tipo' : '${_selectedTypes.length} tipi'} · '
                        '${max == null ? 'varianti illimitate' : '$max disponibili'}\n'
                        '${_api.isLoggedIn ? 'Salvati nello storico: gli errori vanno nel Ripasso.' : 'Senza account i risultati restano su questo telefono.'}',
                style: SlText.muted(p).copyWith(fontSize: 11.5),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedTypes.isEmpty || max == 0 || _pending ? null : _start,
              icon: Icon(_quizMode ? Icons.assignment_turned_in_outlined : Icons.play_arrow_rounded),
              label: Text(_selectedTypes.isEmpty
                  ? 'Scegli almeno un tipo'
                  : _quizMode
                      ? 'Inizia il quiz · ${count == 1 ? '1 esercizio' : '$count esercizi'}'
                      : count == 1
                          ? 'Inizia 1 esercizio'
                          : 'Inizia $count esercizi'),
            ),
          ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget body = _loading
        ? Center(child: CircularProgressIndicator(color: p.skyBlue))
        : _error != null && _data.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: SlErrorCard(title: 'Attenzione', message: _error!, onRetry: () => _init()),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(children: <Widget>[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: SlErrorCard(title: 'Conteggi non aggiornati', message: _error!, onRetry: _refresh),
                      ),
                    Expanded(child: _step == 0 ? _filtersStep(context) : _typesStep(context)),
                  ]),
                ),
              );
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _step == 1) setState(() => _step = 0);
      },
      child: Scaffold(
        backgroundColor: p.darkElegance,
        appBar: AppBar(
          backgroundColor: p.eleganceMidnight,
          foregroundColor: p.pureWhite,
          title: Text(widget.subjectLabel ?? 'Esercizi'),
        ),
        body: body,
        bottomNavigationBar: _loading || (_error != null && _data.isEmpty)
            ? null
            : Material(
                color: p.eleganceMidnight,
                child: SafeArea(
                  top: false,
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: _bottomBar(context),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
