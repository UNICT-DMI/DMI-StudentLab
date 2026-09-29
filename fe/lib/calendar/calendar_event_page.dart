import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dictionary/dictionary_subject_page.dart';
import '../faq/faq_exam_page.dart';
import '../faq/faq_home_page.dart';
import '../material/StudentMaterialPage.dart';
import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';
import 'calendar_api_service.dart';
import 'calendar_editor_page.dart';
import 'calendar_widgets.dart';

/// Appello o evento (canvas: Calendario · appello).
class CalendarEventPage extends StatefulWidget {
  final int eventId;

  const CalendarEventPage({super.key, required this.eventId});

  @override
  State<CalendarEventPage> createState() => _CalendarEventPageState();
}

class _CalendarEventPageState extends State<CalendarEventPage> {
  final CalendarApiService _api = CalendarApiService();
  Map<String, dynamic>? _event;
  bool _loading = true;
  bool _busy = false;
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
      _event = await _api.event(widget.eventId);
    } catch (e) {
      _error = calendarError(e, 'Evento non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<List<int>?> _chooseReminders(List<int> current) async {
    final p = context.palette;
    final chosen = Set<int>.of(current);
    return showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          backgroundColor: p.eleganceDeepNavy,
          title: const Text('Promemoria'),
          content: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final d in const [14, 7, 3, 2, 1, 0])
              FilterChip(
                label: Text(d == 0 ? 'Il giorno stesso' : (d == 1 ? '1 giorno prima' : '$d giorni prima')),
                selected: chosen.contains(d),
                onSelected: (v) => update(() => v ? chosen.add(d) : chosen.remove(d)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, chosen.toList()), child: const Text('Salva')),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final e = _event!;
    if (!_api.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accedi per seguire gli appelli.')));
      return;
    }
    setState(() => _busy = true);
    try {
      if (e['followed'] == true) {
        await _api.unfollow(widget.eventId);
      } else {
        await _api.follow(widget.eventId);
      }
      await _load();
    } catch (err) {
      if (mounted) setState(() => _error = calendarError(err, 'Operazione non riuscita.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _changeReminders() async {
    final current = ((_event!['remind_days'] as List?) ?? const [7, 1]).map((d) => int.tryParse('$d') ?? 0).toList();
    final days = await _chooseReminders(current);
    if (days == null) return;
    try {
      await _api.follow(widget.eventId, remindDays: days);
      await _load();
    } catch (err) {
      if (mounted) setState(() => _error = calendarError(err, 'Promemoria non salvati.'));
    }
  }

  Future<void> _addToPhone() async {
    final ok = await launchUrl(_api.icsUri(widget.eventId), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non è stato possibile aprire il file del calendario.')));
    }
  }

  Widget _row(String label, String value, {VoidCallback? onTap}) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: SlText.muted(p))),
          Expanded(
            child: Text(value,
                style: SlText.body(p).copyWith(color: onTap != null ? p.diamondDust : p.pureWhite, height: 1.4)),
          ),
        ]),
      ),
    );
  }

  Widget _prepLink(IconData icon, SlTone tone, String title, String subtitle, Widget page) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              SlIconTile(icon: icon, tone: tone, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: SlText.muted(p).copyWith(fontSize: 11)),
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
    final e = _event;
    if (_loading && e == null) {
      return Scaffold(backgroundColor: p.darkElegance, body: Center(child: CircularProgressIndicator(color: p.skyBlue)));
    }
    if (e == null) {
      return Scaffold(
        backgroundColor: p.darkElegance,
        appBar: AppBar(backgroundColor: p.eleganceMidnight, foregroundColor: p.pureWhite),
        body: Padding(padding: const EdgeInsets.all(16), child: SlErrorCard(title: 'Errore', message: _error ?? '', onRetry: _load)),
      );
    }
    final kind = calendarKinds[e['kind']] ?? calendarKinds['event']!;
    final start = calendarDate(e['starts_at']) ?? DateTime.now();
    final end = calendarDate(e['ends_at']);
    final bool followed = e['followed'] == true;
    final int? subjectId = int.tryParse('${e['subject_id']}');
    final String subjectName = '${e['subject_name'] ?? ''}';
    final reminders = ((e['remind_days'] as List?) ?? const []).map((d) => int.tryParse('$d') ?? 0).toList();
    final formats = {'scritto': 'scritto', 'orale': 'orale', 'scritto_orale': 'scritto e orale', 'progetto': 'progetto'};
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text(kind.$1),
        actions: [
          if (e['can_edit'] == true)
            IconButton(
              tooltip: 'Modifica',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CalendarEditorPage(event: e)));
                if (mounted) await _load();
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
            if (_error != null) ...[SlErrorCard(title: 'Attenzione', message: _error!), const SizedBox(height: 12)],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.eleganceDeepNavy,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kind.$3.resolve(p).withValues(alpha: 0.30)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  SlStatusBadge(label: kind.$1, tone: kind.$3),
                  SlStatusBadge(
                    label: {'confirmed': 'Confermato', 'provisional': 'Da confermare', 'cancelled': 'Annullato'}[e['status']] ?? '${e['status']}',
                    tone: e['status'] == 'confirmed' ? SlTone.success : (e['status'] == 'cancelled' ? SlTone.danger : SlTone.warning),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('${e['title']}', style: TextStyle(color: p.pureWhite, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '${calendarLong(start)[0].toUpperCase()}${calendarLong(start).substring(1)}'
                  '${e['all_day'] == true ? '' : ' · ${calendarTime(start)}'}'
                  '${end != null && end.day != start.day ? ' – ${calendarLong(end)}' : (end != null && e['all_day'] != true ? '–${calendarTime(end)}' : '')}'
                  '${e['exam_format'] != null ? ' · ${formats[e['exam_format']] ?? e['exam_format']}' : ''}',
                  style: SlText.body(p).copyWith(color: p.pureWhite.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 6),
                Text([e['university'], e['department'], e['course'], if (subjectName.isNotEmpty) subjectName]
                    .where((v) => '${v ?? ''}'.isNotEmpty).join(' › '),
                    style: SlText.mono(p, size: 11, color: p.materialSky)),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: p.eleganceMidnight, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                if ('${e['room'] ?? ''}'.isNotEmpty) _row('Aula', '${e['room']}'),
                if (e['curricula'] is List && (e['curricula'] as List).isNotEmpty)
                  _row('Curricula', (e['curricula'] as List).join(', ')),
                if ((e['teachers'] as List? ?? []).isNotEmpty) _row('Docenti', (e['teachers'] as List).join(', ')),
                if (e['booking_deadline'] != null || e['booking_url'] != null)
                  _row(
                    'Prenotazione',
                    [
                      if (e['booking_deadline'] != null) 'entro ${calendarDay(calendarDate(e['booking_deadline'])!)}',
                      if (e['booking_url'] != null) 'apri il link ↗',
                    ].join(' · '),
                    onTap: e['booking_url'] == null
                        ? null
                        : () => launchUrl(Uri.parse('${e['booking_url']}'), mode: LaunchMode.externalApplication),
                  ),
                if ('${e['notes'] ?? ''}'.isNotEmpty) _row('Note', '${e['notes']}'),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _toggleFollow,
                  style: FilledButton.styleFrom(
                    backgroundColor: followed ? p.eleganceDeepNavy : p.skyBlue,
                    foregroundColor: followed ? p.diamondDust : p.darkElegance,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(followed ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, size: 18),
                  label: Text(followed ? 'Non seguire più' : 'Segui l’appello', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addToPhone,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.pureWhite.withValues(alpha: 0.86),
                    minimumSize: const Size(0, 46),
                    side: BorderSide(color: p.pureWhite.withValues(alpha: 0.14)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: const Text('Aggiungi al telefono'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (followed)
              TextButton.icon(
                onPressed: _changeReminders,
                icon: const Icon(Icons.alarm_rounded, size: 18),
                label: Text('Promemoria: ${reminders.isEmpty ? 'nessuno' : reminders.map((d) => d == 0 ? 'il giorno stesso' : (d == 1 ? '1 giorno prima' : '$d giorni prima')).join(', ')}'),
              )
            else
              Text('Seguendolo ricevi i promemoria (standard 7 e 1 giorno prima) e un avviso se cambiano data, ora o aula.',
                  style: SlText.muted(p).copyWith(fontSize: 12)),
            if (subjectId != null) ...[
              const SizedBox(height: 16),
              const SlOverline('Per prepararti'),
              const SizedBox(height: 8),
              _prepLink(Icons.event_note_outlined, SlTone.warning, 'Com’è l’esame', 'Argomenti chiesti e racconti degli appelli',
                  FaqExamPage(subjectId: subjectId, subjectName: subjectName)),
              _prepLink(Icons.menu_book_outlined, SlTone.info, 'Dizionario', 'Definizioni, esercizi e domande d’esame',
                  DictionarySubjectPage(subjectId: subjectId)),
              _prepLink(Icons.forum_outlined, SlTone.cyan, 'Domande', 'Dubbi e risposte sulla materia',
                  FaqHomePage(subjectId: subjectId, subjectName: subjectName)),
              _prepLink(Icons.folder_outlined, SlTone.success, 'Dispense', 'Materiali della materia', const StudentMaterialPage()),
            ],
            const SizedBox(height: 14),
            Text(
              'Aggiornato da ${e['updated_by_name'] ?? 'StudentLab'}'
              '${e['source'] != null && e['source'] != 'manual' ? ' · importato (${e['source']})' : ''}',
              style: SlText.muted(p).copyWith(fontSize: 11),
            ),
          ]),
        ),
      ),
    );
  }
}
