import 'package:flutter/material.dart';

import '../faq/faq_api_service.dart';
import '../faq/faq_widgets.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'calendar_api_service.dart';
import 'calendar_widgets.dart';

/// Nuovo evento o modifica (canvas: Admin · calendario accademico, pannello a destra).
/// Admin: qualsiasi evento e ambito. Docenti: appelli ed eventi delle loro materie.
class CalendarEditorPage extends StatefulWidget {
  final Map<String, dynamic>? event;
  final String? university;
  final String? department;
  final String? course;
  final int? subjectId;

  const CalendarEditorPage({super.key, this.event, this.university, this.department, this.course, this.subjectId});

  @override
  State<CalendarEditorPage> createState() => _CalendarEditorPageState();
}

class _CalendarEditorPageState extends State<CalendarEditorPage> {
  final CalendarApiService _api = CalendarApiService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _room = TextEditingController();
  final TextEditingController _teachers = TextEditingController();
  final TextEditingController _booking = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  bool _admin = false;
  List<Map<String, dynamic>> _allSubjects = [];
  List<Map<String, dynamic>> _mySubjects = [];
  String _kind = 'exam';
  String? _university;
  String? _department;
  String? _course;
  int? _subjectId;
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  DateTime? _end;
  bool _allDay = false;
  String? _format;
  DateTime? _deadline;
  String _status = 'confirmed';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _kind = '${e['kind']}';
      _title.text = '${e['title'] ?? ''}';
      _university = e['university'] as String?;
      _department = e['department'] as String?;
      _course = e['course'] as String?;
      _subjectId = int.tryParse('${e['subject_id']}');
      _start = calendarDate(e['starts_at']) ?? _start;
      _end = calendarDate(e['ends_at']);
      _allDay = e['all_day'] == true;
      _format = e['exam_format'] as String?;
      _room.text = '${e['room'] ?? ''}';
      _teachers.text = (e['teachers'] as List? ?? []).join(', ');
      _booking.text = '${e['booking_url'] ?? ''}';
      _deadline = calendarDate(e['booking_deadline']);
      _notes.text = '${e['notes'] ?? ''}';
      _status = '${e['status'] ?? 'confirmed'}';
    } else {
      _university = widget.university;
      _department = widget.department;
      _course = widget.course;
      _subjectId = widget.subjectId;
      _start = DateTime(_start.year, _start.month, _start.day, 9, 30);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _room, _teachers, _booking, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await _api.manageable();
      _admin = m['is_admin'] == true;
      _mySubjects = (m['subjects'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _allSubjects = _admin ? await FaqApiService().filters() : _mySubjects;
      if (!_admin && _subjectId == null && _mySubjects.isNotEmpty) _subjectId = int.tryParse('${_mySubjects.first['id']}');
    } catch (e) {
      _error = calendarError(e, 'Non è stato possibile verificare i permessi.');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> get _kinds => _admin ? calendarKinds.keys.toList() : const ['exam', 'extraordinary', 'event'];

  Future<DateTime?> _pickDateTime(DateTime initial, {bool withTime = true}) async {
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (day == null || !mounted) return null;
    if (!withTime) return day;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    return DateTime(day.year, day.month, day.day, time?.hour ?? initial.hour, time?.minute ?? initial.minute);
  }

  String _iso(DateTime d) => d.toIso8601String().substring(0, 19);

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Scrivi il titolo (per un appello, il nome della materia).');
      return;
    }
    if (!_admin && _subjectId == null) {
      setState(() => _error = 'Scegli la materia.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.saveEvent({
        'kind': _kind,
        'title': _title.text.trim(),
        if (_subjectId == null) 'university': _university,
        if (_subjectId == null) 'department': _department,
        if (_subjectId == null) 'course': _course,
        'subject_id': _subjectId,
        'starts_at': _iso(_allDay ? DateTime(_start.year, _start.month, _start.day) : _start),
        if (_end != null) 'ends_at': _iso(_allDay ? DateTime(_end!.year, _end!.month, _end!.day, 23, 59) : _end!),
        'all_day': _allDay,
        if ((_kind == 'exam' || _kind == 'extraordinary') && _format != null) 'exam_format': _format,
        'room': _room.text.trim(),
        'teachers': _teachers.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
        if (_booking.text.trim().isNotEmpty) 'booking_url': _booking.text.trim(),
        if (_deadline != null) 'booking_deadline': _iso(_deadline!).substring(0, 10),
        'notes': _notes.text.trim(),
        'status': _status,
        'source': widget.event?['source'] ?? 'manual',
      }, id: widget.event == null ? null : int.tryParse('${widget.event!['id']}'));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = calendarError(e, 'Evento non salvato.');
        });
      }
    }
  }

  Future<void> _delete() async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: const Text('Eliminare l’evento?'),
        content: Text('Se qualcuno lo segue, resta come “annullato” e riceve un avviso.', style: SlText.body(p)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteEvent(int.parse('${widget.event!['id']}'));
      if (mounted) Navigator.of(context)
        ..pop()
        ..pop();
    } catch (e) {
      if (mounted) setState(() => _error = calendarError(e, 'Evento non eliminato.'));
    }
  }

  List<String> _distinct(String key, bool Function(Map<String, dynamic>) where) =>
      _allSubjects.where(where).map((s) => '${s[key] ?? ''}').where((v) => v.isNotEmpty).toSet().toList()..sort();

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

  Widget _dateField(String label, DateTime? value, VoidCallback onTap, {bool withTime = true, VoidCallback? onClear}) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null && value != null
              ? IconButton(tooltip: 'Togli', onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 18))
              : const Icon(Icons.event_outlined, size: 18),
        ),
        child: Text(
          value == null ? '—' : (withTime ? '${calendarDay(value)}/${value.year} ${calendarTime(value)}' : '${calendarDay(value)}/${value.year}'),
          style: SlText.body(p).copyWith(color: p.pureWhite),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final subjectOptions = _admin
        ? _allSubjects.where((s) =>
            (_university == null || s['university'] == _university) &&
            (_department == null || s['department'] == _department) &&
            (_course == null || s['course'] == _course)).toList()
        : _mySubjects;
    final bool exam = _kind == 'exam' || _kind == 'extraordinary';
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text(widget.event == null ? 'Nuovo evento' : 'Modifica evento'),
        actions: [
          if (widget.event != null)
            IconButton(tooltip: 'Elimina', onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: p.adminCoral)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving || _loading ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: p.skyBlue, foregroundColor: p.darkElegance),
              child: const Text('Salva', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: p.skyBlue))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  if (_error != null) ...[SlErrorCard(title: 'Attenzione', message: _error!), const SizedBox(height: 12)],
                  _panel([
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final k in _kinds)
                        ChoiceChip(
                          label: Text(calendarKinds[k]!.$1),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _title,
                      decoration: InputDecoration(labelText: exam ? 'Titolo (es. Reti di calcolatori · scritto)' : 'Titolo'),
                    ),
                  ]),
                  _panel([
                    const SlOverline('Dove vale'),
                    const SizedBox(height: 10),
                    if (_admin) ...[
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        FaqFilterChip(
                          label: 'Ateneo',
                          selected: _university,
                          options: _distinct('university', (_) => true),
                          onChanged: (v) => setState(() {
                            _university = v;
                            _department = null;
                            _course = null;
                            _subjectId = null;
                          }),
                        ),
                        FaqFilterChip(
                          label: 'Dipartimento',
                          selected: _department,
                          options: _distinct('department', (s) => _university == null || s['university'] == _university),
                          onChanged: (v) => setState(() {
                            _department = v;
                            _course = null;
                            _subjectId = null;
                          }),
                        ),
                        FaqFilterChip(
                          label: 'Corso',
                          selected: _course,
                          options: _distinct('course', (s) =>
                              (_university == null || s['university'] == _university) &&
                              (_department == null || s['department'] == _department)),
                          onChanged: (v) => setState(() {
                            _course = v;
                            _subjectId = null;
                          }),
                        ),
                      ]),
                      const SizedBox(height: 10),
                    ],
                    DropdownButtonFormField<int?>(
                      value: subjectOptions.any((s) => s['id'] == _subjectId) ? _subjectId : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: _admin ? 'Materia (facoltativa per i periodi)' : 'Materia'),
                      items: [
                        if (_admin) const DropdownMenuItem<int?>(value: null, child: Text('Nessuna: vale per tutto l’ambito')),
                        for (final s in subjectOptions)
                          DropdownMenuItem<int?>(value: s['id'] as int?, child: Text('${s['name']} · ${s['course'] ?? ''}', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() {
                        _subjectId = v;
                        final s = subjectOptions.where((s) => s['id'] == v).firstOrNull;
                        if (s != null && _title.text.trim().isEmpty) _title.text = '${s['name']}';
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _admin
                          ? 'Un evento dell’ateneo o del dipartimento vale per tutti i corsi sotto.'
                          : 'Come docente puoi inserire appelli ed eventi delle materie che insegni.',
                      style: SlText.muted(p).copyWith(fontSize: 12),
                    ),
                  ]),
                  _panel([
                    const SlOverline('Quando'),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _allDay,
                      onChanged: (v) => setState(() => _allDay = v),
                      title: Text('Tutto il giorno (periodi, chiusure)', style: SlText.body(p).copyWith(color: p.pureWhite)),
                    ),
                    _dateField('Inizio', _start, () async {
                      final v = await _pickDateTime(_start, withTime: !_allDay);
                      if (v != null) setState(() => _start = v);
                    }, withTime: !_allDay),
                    const SizedBox(height: 10),
                    _dateField('Fine (facoltativa)', _end, () async {
                      final v = await _pickDateTime(_end ?? _start, withTime: !_allDay);
                      if (v != null) setState(() => _end = v);
                    }, withTime: !_allDay, onClear: () => setState(() => _end = null)),
                  ]),
                  if (exam)
                    _panel([
                      const SlOverline('Dettagli dell’appello'),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final f in const [('scritto', 'Scritto'), ('orale', 'Orale'), ('scritto_orale', 'Scritto + orale'), ('progetto', 'Progetto')])
                          ChoiceChip(
                            label: Text(f.$2),
                            selected: _format == f.$1,
                            onSelected: (_) => setState(() => _format = _format == f.$1 ? null : f.$1),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      TextField(controller: _teachers, decoration: const InputDecoration(labelText: 'Docenti (separati da virgola)')),
                      const SizedBox(height: 10),
                      TextField(controller: _booking, decoration: const InputDecoration(labelText: 'Link per la prenotazione (https://…)')),
                      const SizedBox(height: 10),
                      _dateField('Prenotazioni entro', _deadline, () async {
                        final v = await _pickDateTime(_deadline ?? _start.subtract(const Duration(days: 5)), withTime: false);
                        if (v != null) setState(() => _deadline = v);
                      }, withTime: false, onClear: () => setState(() => _deadline = null)),
                    ]),
                  _panel([
                    TextField(controller: _room, decoration: const InputDecoration(labelText: 'Aula o luogo')),
                    const SizedBox(height: 10),
                    TextField(controller: _notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Note')),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final s in const [('confirmed', 'Confermato'), ('provisional', 'Da confermare'), ('cancelled', 'Annullato')])
                        ChoiceChip(label: Text(s.$2), selected: _status == s.$1, onSelected: (_) => setState(() => _status = s.$1)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Se cambi data, ora, aula o stato, chi segue l’evento riceve un avviso.',
                        style: SlText.muted(p).copyWith(fontSize: 12)),
                  ]),
                ]),
              ),
            ),
    );
  }
}
