import 'package:flutter/material.dart';

import '../faq/faq_api_service.dart';
import '../faq/faq_widgets.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../social/social_models.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'calendar_api_service.dart';
import 'calendar_editor_page.dart';
import 'calendar_event_page.dart';
import 'calendar_import_page.dart';
import 'calendar_widgets.dart';
import 'academic_year_2026_27.dart';

/// Calendario accademico (canvas: Calendario · prossimi / mese).
/// Per ospiti e utenti; chi ha l'account parte dal proprio percorso.
class CalendarHomePage extends StatefulWidget {
  final int? subjectId;
  final String? subjectName;
  final bool embedded;

  const CalendarHomePage({super.key, this.subjectId, this.subjectName, this.embedded = false});

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage> {
  final CalendarApiService _api = CalendarApiService();
  final FaqApiService _filtersApi = FaqApiService();

  List<Map<String, dynamic>> _subjects = [];
  String? _university;
  String? _department;
  String? _course;
  int? _subjectId;
  String _view = 'next';
  String? _kind;
  String? _curriculum;
  String _section = 'events';
  DateTime _week = _monday(DateTime.now());
  List<Map<String, dynamic>> _lessons = [];

  static DateTime _monday(DateTime day) =>
      DateTime(day.year, day.month, day.day).subtract(Duration(days: day.weekday - 1));
  static const _lm18Curricula = <String>[
    'ARTIFICIAL INTELLIGENCE AND MACHINE LEARNING',
    'COMPUTER VISION AND MULTIMEDIA TECHNOLOGIES',
    'DISTRIBUTED ARCHITECTURES AND CYBERSECURITY',
    'HEALTH INFORMATICS',
    'QUANTUM PROGRAMMING AND HPC',
    'THEORETICAL COMPUTER SCIENCE',
  ];
  static const _l31Channels = <String>[
    '1° A-E', '1° F-N', '1° O-Z', '2° A-L', '2° M-Z',
    '3° A-L (AI AND ROBOTICS)', '3° A-L (COMP. TH. AND Q. ALG.)',
    '3° A-L (COMP. GR. AND GAMES)', '3° A-L (CYBERSECURITY AND D. F.)',
    '3° A-L (DATA SCIENCE)', '3° A-L (PROG. WEB, MOBILE AND V.E.)',
    '3° M-Z (AI AND ROBOTICS)', '3° M-Z (COMP. TH. AND Q. ALG.)',
    '3° M-Z (COMP. GR. AND GAMES)', '3° M-Z (CYBERSECURITY AND D. F.)',
    '3° M-Z (DATA SCIENCE)', '3° M-Z (PROG. WEB, MOBILE AND V.E.)',
  ];
  bool get _isLm18 => (_course ?? '').toLowerCase().contains('lm-18') ||
      (_course ?? '').toLowerCase().contains('informatica magistrale');
  bool get _isL31 => (_course ?? '').toLowerCase().contains('l-31') ||
      ((_course ?? '').toLowerCase().contains('informatica') && !_isLm18);
  bool _showAcademicFilters = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _periods = [];
  List<Map<String, dynamic>> _followed = [];
  bool _loading = true;
  String? _error;
  bool _canWrite = false;
  List<int> _reminders = const [7, 1];

  String _pathKey(String key, String value) {
    final text = value.trim().toLowerCase();
    if (key == 'university' && (text == 'unict' || text.contains('università di catania') ||
        text.contains('università degli studi di catania'))) return 'unict';
    if (key == 'department') {
      if (text == 'dmi' || text.contains('matematica e informatica')) return 'dmi';
      if (text == 'dsbga' || text.contains('scienze biologiche, geologiche')) return 'dsbga';
    }
    if (key == 'course') {
      if (RegExp(r'\blm[ -]?18\b').hasMatch(text) || text.contains('informatica magistrale')) return 'lm-18';
      if (RegExp(r'\blm[ -]?40\b').hasMatch(text) || text.contains('matematica magistrale')) return 'lm-40';
      if (RegExp(r'\bl[ -]?31\b').hasMatch(text) || text == 'informatica' ||
          text == 'scienze e tecnologie informatiche') return 'l-31';
      if (RegExp(r'\bl[ -]?35\b').hasMatch(text) || text == 'matematica') return 'l-35';
      if (RegExp(r'\bl[ -]?13\b').hasMatch(text) || text == 'scienze biologiche') return 'l-13';
    }
    return text;
  }

  String _displayPath(String key, String value) {
    const names = <String, String>{'unict': 'Università di Catania',
      'dmi': 'Dipartimento di Matematica e Informatica',
      'dsbga': 'Dipartimento di Scienze Biologiche, Geologiche e Ambientali',
      'l-31': 'Informatica L-31', 'lm-18': 'Informatica magistrale (LM-18)',
      'l-35': 'Matematica L-35', 'lm-40': 'Matematica magistrale (LM-40)',
      'l-13': 'Scienze Biologiche L-13'};
    return names[_pathKey(key, value)] ?? value.trim();
  }

  bool _samePath(String key, Object? first, Object? second) =>
      _pathKey(key, '$first') == _pathKey(key, '$second');

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjectId;
    _start();
  }

  Future<void> _start() async {
    try {
      _subjects = await _filtersApi.filters();
    } catch (_) {}
    if (_subjectId != null) {
      final s = _subjects.where((s) => s['id'] == _subjectId).firstOrNull;
      if (s != null) {
        _university = _displayPath('university', '${s['university']}');
        _department = _displayPath('department', '${s['department']}');
        _course = _displayPath('course', '${s['course']}');
      }
    } else if (AuthSession.instance.isAuthenticated && AuthSession.instance.currentUserId != null) {
      try {
        final paths = await ApiService().getUserAcademicPaths(AuthSession.instance.currentUserId!);
        final enrolled = paths.where((p) => p.status == AcademicPathStatus.enrolled).toList();
        final current = enrolled.where((p) => p.isCurrent);
        final SocialAcademicPath? path = current.isNotEmpty ? current.first : enrolled.firstOrNull;
        if (path != null) {
          _university = _displayPath('university', path.university);
          _department = _displayPath('department', path.department);
          _course = _displayPath('course', path.course);
        } else {
          final user = AuthSession.instance.currentUser;
          _university = user?.university.trim().isEmpty == true ? null : _displayPath('university', user!.university);
          _department = user?.department.trim().isEmpty == true ? null : _displayPath('department', user!.department);
          _course = user?.course.trim().isEmpty == true ? null : _displayPath('course', user!.course);
        }
      } catch (_) {
        final user = AuthSession.instance.currentUser;
        _university = user?.university.trim().isEmpty == true ? null : _displayPath('university', user!.university);
        _department = user?.department.trim().isEmpty == true ? null : _displayPath('department', user!.department);
        _course = user?.course.trim().isEmpty == true ? null : _displayPath('course', user!.course);
      }
    } else {
      // Il guest apre il calendario didattico generale dell'ateneo.
      _university = 'Università di Catania';
    }
    if (_api.isAuthenticated) {
      try {
        _canWrite = (await _api.manageable())['can_write'] == true;
        _reminders = await _api.reminderSettings();
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _view == 'month' ? DateTime(_month.year, _month.month, 1) : DateTime.now().subtract(const Duration(days: 1));
      final to = _view == 'month' ? DateTime(_month.year, _month.month + 1, 0) : DateTime.now().add(const Duration(days: 500));
      final bool hasWeeklyCourse = _api.isAuthenticated && (_course != null || _subjectId != null);
      final results = await Future.wait<dynamic>([
        _api.events(
            university: _subjectId == null ? _university : null,
            department: _subjectId == null ? _department : null,
            course: _subjectId == null ? _course : null,
            subjectId: _subjectId,
            curriculum: _isLm18 || _isL31 ? _curriculum : null,
            excludeTimetable: true,
            from: from,
            to: to),
        _api.currentPeriods(university: _university, department: _department, course: _course),
        if (hasWeeklyCourse) _api.events(
            university: _subjectId == null ? _university : null,
            department: _subjectId == null ? _department : null,
            course: _subjectId == null ? _course : null,
            subjectId: _subjectId,
            curriculum: _isLm18 || _isL31 ? _curriculum : null,
            timetableOnly: true, from: _week,
            to: _week.add(const Duration(days: 6))),
        if (_api.isAuthenticated) _api.followed(),
      ]);
      _events = results[0] as List<Map<String, dynamic>>;
      _periods = results[1] as List<Map<String, dynamic>>;
      _lessons = hasWeeklyCourse ? results[2] as List<Map<String, dynamic>> : [];
      _followed = _api.isAuthenticated ? results[hasWeeklyCourse ? 3 : 2] as List<Map<String, dynamic>> : [];
    } catch (e) {
      _error = calendarError(e, 'Calendario non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Map<String, dynamic> e) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CalendarEventPage(eventId: int.parse('${e['id']}'))));
    if (mounted) await _load();
  }

  List<String> _distinct(String key, bool Function(Map<String, dynamic>) where) {
    final values = <String, String>{};
    for (final subject in _subjects.where(where)) {
      final value = '${subject[key] ?? ''}'.trim();
      if (value.isNotEmpty) values[_pathKey(key, value)] = _displayPath(key, value);
    }
    return values.values.toList()..sort();
  }

  Future<void> _editReminders() async {
    final p = context.palette;
    final chosen = Set<int>.of(_reminders);
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('Promemoria predefiniti'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quando segui un appello ricevi un avviso:', style: SlText.body(p)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in const [14, 7, 3, 2, 1, 0])
                FilterChip(
                  label: Text(d == 0 ? 'Il giorno stesso' : (d == 1 ? '1 giorno prima' : '$d giorni prima')),
                  selected: chosen.contains(d),
                  onSelected: (v) => update(() => v ? chosen.add(d) : chosen.remove(d)),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, chosen), child: const Text('Salva')),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      final saved = await _api.saveReminderSettings(result.toList());
      if (mounted) setState(() => _reminders = saved);
    } catch (e) {
      if (mounted) setState(() => _error = calendarError(e, 'Impostazioni non salvate.'));
    }
  }

  // --- UI --------------------------------------------------------------------

  Widget _periodBanner() {
    if (_periods.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    final e = _periods.first;
    final kind = calendarKinds[e['kind']] ?? calendarKinds['event']!;
    final color = kind.$3.resolve(p);
    final followedCount = _followed.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(children: [
          SlIconTile(icon: kind.$2, tone: kind.$3, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e['title']}', style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('${calendarWhen(e)}${(e['room']?.toString() ?? '').isEmpty ? '' : ' · ${e['room']}'}'
                  '${followedCount > 0 ? ' · $followedCount eventi seguiti' : ''}',
                  style: SlText.muted(p).copyWith(fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _weeklyTimetable() {
    final p = context.palette;
    final days = List<DateTime>.generate(7, (index) => _week.add(Duration(days: index)));
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final lesson in _lessons) {
      final start = calendarDate(lesson['starts_at']);
      if (start != null) byDay.putIfAbsent(start.weekday, () => []).add(lesson);
    }
    for (final lessons in byDay.values) {
      lessons.sort((a, b) => '${a['starts_at']}'.compareTo('${b['starts_at']}'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(tooltip: 'Settimana precedente',
          onPressed: () { setState(() => _week = _week.subtract(const Duration(days: 7))); _load(); },
          icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(child: Text('Settimana del ${calendarLong(_week)}',
          style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700))),
        IconButton(tooltip: 'Settimana successiva',
          onPressed: () { setState(() => _week = _week.add(const Duration(days: 7))); _load(); },
          icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      if (_course == null && _subjectId == null)
        const SlEmptyState(icon: Icons.school_outlined, title: 'Scegli un corso',
          message: 'Seleziona il corso nei filtri per vedere il suo orario settimanale.')
      else if (_lessons.isEmpty)
        const SlEmptyState(icon: Icons.schedule_outlined, title: 'Nessuna lezione questa settimana',
          message: 'Verifica il periodo didattico oppure passa a un’altra settimana.')
      else LayoutBuilder(builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final columns = viewport >= 1120 ? 7 : viewport >= 700 ? 3 : 2;
        final dayWidth = (viewport / columns).clamp(148.0, 220.0);
        return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final day in days) SizedBox(
            width: dayWidth,
            child: Padding(padding: const EdgeInsets.only(right: 8), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: p.skyBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(calendarLong(day), maxLines: 2,
                    style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const SizedBox(height: 7),
                for (final lesson in byDay[day.weekday] ?? const <Map<String, dynamic>>[])
                  Padding(padding: const EdgeInsets.only(bottom: 7), child: Material(
                    color: p.skyBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                    child: InkWell(onTap: () => _open(lesson),
                      borderRadius: BorderRadius.circular(11),
                      child: Padding(padding: const EdgeInsets.all(10), child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_lessonClock(lesson), style: TextStyle(color: p.skyBlue,
                            fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 5),
                          Text('${lesson['subject_name'] ?? lesson['title'] ?? ''}',
                            style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w700, fontSize: 12)),
                          if ('${lesson['room'] ?? ''}'.trim().isNotEmpty)
                            Text('${lesson['room']}', style: SlText.muted(p).copyWith(fontSize: 11)),
                          if (lesson['teachers'] is List && (lesson['teachers'] as List).isNotEmpty)
                            Text((lesson['teachers'] as List).join(', '),
                              style: SlText.muted(p).copyWith(fontSize: 11)),
                          if (lesson['curricula'] is List && (lesson['curricula'] as List).isNotEmpty)
                            Text((lesson['curricula'] as List).join(', '),
                              style: SlText.muted(p).copyWith(fontSize: 10)),
                        ]))),
                    ),
                  ),
              ],
            ))),
        ]),
      );
      }),
    ]);
  }

  String _lessonClock(Map<String, dynamic> lesson) {
    String time(Object? value) {
      final date = calendarDate(value);
      return date == null ? '--:--' :
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${time(lesson['starts_at'])}–${time(lesson['ends_at'])}';
  }

  Future<void> _openCalendarDay(DateTime day, List<Map<String, dynamic>> events) async {
    setState(() => _selectedDay = day);
    final p = context.palette;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.78,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 18, 8, 12),
            child: Row(children: [
              Expanded(child: Text(calendarLong(day), style: TextStyle(
                color: p.pureWhite, fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Chiudi', icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(sheetContext)),
            ])),
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16),
            children: events.isEmpty
              ? [const SlEmptyState(icon: Icons.event_busy_outlined,
                  title: 'Nessun evento', message: 'Non ci sono eventi per questo giorno.')]
              : [for (final event in events)
                  CalendarEventCard(event: event, onTap: () {
                    Navigator.pop(sheetContext);
                    _open(event);
                  })])),
        ]),
      )),
    );
  }

  Widget _monthGrid() {
    final p = context.palette;
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = first.weekday - 1;
    Map<int, List<Map<String, dynamic>>> byDay = {};
    for (final e in _events) {
      final start = calendarDate(e['starts_at']);
      final end = calendarDate(e['ends_at']) ?? start;
      if (start == null || end == null) continue;
      for (var d = 1; d <= days; d++) {
        final day = DateTime(_month.year, _month.month, d);
        if (!day.isBefore(DateTime(start.year, start.month, start.day)) && !day.isAfter(DateTime(end.year, end.month, end.day))) {
          byDay.putIfAbsent(d, () => []).add(e);
        }
      }
    }
    final selected = _selectedDay;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text('${calendarMonths[_month.month - 1][0].toUpperCase()}${calendarMonths[_month.month - 1].substring(1)} ${_month.year}',
              style: TextStyle(color: p.pureWhite, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'Mese precedente',
          onPressed: () {
            setState(() {
              _month = DateTime(_month.year, _month.month - 1);
              _selectedDay = null;
            });
            _load();
          },
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Mese successivo',
          onPressed: () {
            setState(() {
              _month = DateTime(_month.year, _month.month + 1);
              _selectedDay = null;
            });
            _load();
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (final w in const ['L', 'M', 'M', 'G', 'V', 'S', 'D'])
          Expanded(child: Center(child: Text(w, style: SlText.mono(p, size: 11)))),
      ]),
      const SizedBox(height: 4),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 0.95,
        children: [
          for (var i = 0; i < offset; i++) const SizedBox.shrink(),
          for (var d = 1; d <= days; d++)
            Material(
              color: selected?.day == d ? p.skyBlue.withValues(alpha: 0.16) : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: selected?.day == d ? p.skyBlue.withValues(alpha: 0.5) : Colors.transparent),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openCalendarDay(DateTime(_month.year, _month.month, d),
                    byDay[d] ?? const <Map<String, dynamic>>[]),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$d',
                      style: TextStyle(
                          color: p.pureWhite,
                          fontSize: 13,
                          fontWeight: DateTime.now().day == d && DateTime.now().month == _month.month && DateTime.now().year == _month.year
                              ? FontWeight.w800
                              : FontWeight.w400)),
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (final k in (byDay[d] ?? const []).map((e) => '${e['kind']}').toSet().take(4))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: (calendarKinds[k]?.$3 ?? SlTone.neutral).resolve(p),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ]),
                ]),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 6, children: [
        for (final k in calendarKinds.entries)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: k.value.$3.resolve(p), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(k.value.$1, style: SlText.muted(p).copyWith(fontSize: 11)),
          ]),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final filtered = _events.where((e) => _kind == null || e['kind'] == _kind).toList();
    final now = DateTime.now();
    final weekEnd = now.add(Duration(days: 7 - now.weekday + 1));
    final thisWeek = filtered.where((e) => (calendarDate(e['starts_at']) ?? now).isBefore(weekEnd)).toList();
    final later = filtered.where((e) => !(calendarDate(e['starts_at']) ?? now).isBefore(weekEnd)).toList();
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: widget.embedded ? null : AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text(widget.subjectName == null ? 'Calendario' : 'Calendario · ${widget.subjectName}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_api.isAuthenticated)
            IconButton(tooltip: 'Promemoria', onPressed: _editReminders, icon: const Icon(Icons.notifications_outlined)),
          if (_canWrite)
            PopupMenuButton<String>(
              tooltip: 'Gestisci',
              color: p.eleganceDeepNavy,
              onSelected: (v) async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => v == 'new'
                      ? CalendarEditorPage(university: _university, department: _department, course: _course, subjectId: _subjectId)
                      : CalendarImportPage(university: _university, department: _department, course: _course),
                ));
                if (mounted) await _load();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'new', child: Text('Nuovo evento')),
                PopupMenuItem(value: 'import', child: Text('Importa (PDF, CSV, iCal, web)')),
              ],
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _section == 'lessons' ? 1450 : 820),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                children: [
                  Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
                    icon: const Icon(Icons.filter_list),
                    label: Text(_showAcademicFilters ? 'Chiudi filtri' : 'Filtri percorso'),
                    onPressed: () => setState(() => _showAcademicFilters = !_showAcademicFilters),
                  )),
                  if (_showAcademicFilters) Wrap(spacing: 6, runSpacing: 6, children: [
                    FaqFilterChip(
                      label: 'Ateneo',
                      selected: _university,
                      options: _distinct('university', (_) => true),
                      onChanged: (v) {
                        setState(() {
                          _university = v;
                          _department = null;
                          _course = null;
                          _subjectId = null;
                          _curriculum = null;
                        });
                        _load();
                      },
                    ),
                    if (_api.isAuthenticated) FaqFilterChip(
                      label: 'Dipartimento',
                      selected: _department,
                      options: _distinct('department', (s) => _university == null || _samePath('university', s['university'], _university)),
                      onChanged: (v) {
                        setState(() {
                          _department = v;
                          _course = null;
                          _subjectId = null;
                          _curriculum = null;
                        });
                        _load();
                      },
                    ),
                    if (_api.isAuthenticated) FaqFilterChip(
                      label: 'Corso',
                      selected: _course,
                      options: _distinct('course', (s) =>
                          (_university == null || _samePath('university', s['university'], _university)) &&
                          (_department == null || _samePath('department', s['department'], _department))),
                      onChanged: (v) {
                        setState(() {
                          _course = v;
                          _subjectId = null;
                          _curriculum = null;
                        });
                        _load();
                      },
                    ),
                    if (_api.isAuthenticated && (_isLm18 || _isL31)) FaqFilterChip(
                      label: _isLm18 ? 'Curriculum' : 'Canale / percorso',
                      selected: _curriculum,
                      options: _isLm18 ? _lm18Curricula : _l31Channels,
                      onChanged: (v) {
                        setState(() => _curriculum = v);
                        _load();
                      },
                    ),
                    if (_api.isAuthenticated && _course != null) FaqFilterChip(
                      label: 'Materia',
                      selected: _subjectId == null ? null :
                          _subjects.where((s) => s['id'] == _subjectId).firstOrNull?['name']?.toString(),
                      options: _distinct('name', (s) =>
                          (_university == null || _samePath('university', s['university'], _university)) &&
                          (_department == null || _samePath('department', s['department'], _department)) &&
                          _samePath('course', s['course'], _course)),
                      onChanged: (v) {
                        setState(() => _subjectId = _subjects.where((s) =>
                            s['name'] == v && _samePath('course', s['course'], _course) &&
                            (_department == null || _samePath('department', s['department'], _department)) &&
                            (_university == null || _samePath('university', s['university'], _university))).firstOrNull?['id'] as int?);
                        _load();
                      },
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SlFilterBar<String>(
                    selected: _section,
                    options: [
                      const SlFilterOption(value: 'events', label: 'Calendario accademico'),
                      if (_api.isAuthenticated)
                        const SlFilterOption(value: 'lessons', label: 'Orario lezioni'),
                    ],
                    onSelected: (value) => setState(() => _section = value),
                  ),
                  const SizedBox(height: 12),
                  if (_section == 'events') ...[
                  if (_university == null || (_university ?? '').toLowerCase().contains('catania') ||
                      (_university ?? '').toLowerCase() == 'unict') ...[
                    const AcademicYear2026Card(),
                    const SizedBox(height: 12),
                  ],
                  _periodBanner(),
                  SlFilterBar<String>(
                    selected: _view,
                    options: [
                      const SlFilterOption(value: 'next', label: 'Prossimi'),
                      const SlFilterOption(value: 'month', label: 'Mese'),
                      if (_api.isAuthenticated) SlFilterOption(value: 'followed', label: 'Seguiti', count: _followed.length),
                    ],
                    onSelected: (v) {
                      setState(() => _view = v);
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_view != 'followed')
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      ChoiceChip(label: const Text('Tutti'), selected: _kind == null, onSelected: (_) => setState(() => _kind = null)),
                      for (final k in _api.isAuthenticated
                          ? const ['exam', 'session', 'closure', 'event']
                          : const ['session', 'closure'])
                        ChoiceChip(
                          label: Text(calendarKinds[k]!.$1),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = _kind == k ? null : k),
                        ),
                    ]),
                  const SizedBox(height: 14),
                  if (_loading)
                    Padding(padding: const EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: p.skyBlue)))
                  else if (_error != null)
                    SlErrorCard(title: 'Calendario non disponibile', message: _error!, onRetry: _load)
                  else if (_view == 'month')
                    _monthGrid()
                  else if (_view == 'followed') ...[
                    if (_followed.isEmpty)
                      const SlEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Non segui ancora nessun evento',
                        message: 'Apri un appello e premi “Segui”: ricevi i promemoria e gli avvisi se cambia qualcosa.',
                      ),
                    for (final e in _followed) CalendarEventCard(event: e, onTap: () => _open(e)),
                  ] else ...[
                    if (filtered.isEmpty)
                      const SlEmptyState(
                        icon: Icons.event_busy_outlined,
                        title: 'Nessun evento in programma',
                        message: 'Prova a cambiare i filtri o il tipo di evento.',
                      ),
                    if (thisWeek.isNotEmpty) ...[
                      const SlOverline('Questa settimana'),
                      const SizedBox(height: 8),
                      for (final e in thisWeek) CalendarEventCard(event: e, onTap: () => _open(e)),
                      const SizedBox(height: 8),
                    ],
                    if (later.isNotEmpty) ...[
                      const SlOverline('Più avanti'),
                      const SizedBox(height: 8),
                      for (final e in later) CalendarEventCard(event: e, onTap: () => _open(e)),
                    ],
                  ],
                  ] else if (_loading)
                    Padding(padding: const EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator(color: p.skyBlue)))
                  else if (_error != null)
                    SlErrorCard(title: 'Orario lezioni non disponibile', message: _error!, onRetry: _load)
                  else
                    _weeklyTimetable(),
                  if (!_api.isAuthenticated) ...[
                    const SizedBox(height: 10),
                    Text('Accedi per seguire gli appelli e ricevere i promemoria.', style: SlText.muted(p).copyWith(fontSize: 12)),
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
