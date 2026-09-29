import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';

/// Tipi di evento: etichetta, icona e tono.
const Map<String, (String, IconData, SlTone)> calendarKinds = {
  'lessons': ('Lezioni', Icons.school_outlined, SlTone.info),
  'session': ('Sessione', Icons.event_note_outlined, SlTone.warning),
  'exam': ('Appello', Icons.edit_calendar_outlined, SlTone.danger),
  'extraordinary': ('Straordinaria', Icons.bolt_outlined, SlTone.cyan),
  'closure': ('Chiusura', Icons.do_not_disturb_on_outlined, SlTone.violet),
  'event': ('Evento', Icons.celebration_outlined, SlTone.success),
};

const List<String> calendarMonths = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];
const List<String> calendarWeekdays = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];

DateTime? calendarDate(dynamic value) => DateTime.tryParse('${value ?? ''}');

String calendarDay(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String calendarLong(DateTime d) => '${calendarWeekdays[d.weekday - 1]} ${d.day} ${calendarMonths[d.month - 1]} ${d.year}';

String calendarTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String calendarWhen(Map<String, dynamic> e) {
  final start = calendarDate(e['starts_at']);
  final end = calendarDate(e['ends_at']);
  if (start == null) return '';
  final bool allDay = e['all_day'] == true;
  if (end != null && (end.year != start.year || end.month != start.month || end.day != start.day)) {
    return '${calendarDay(start)} – ${calendarDay(end)}';
  }
  if (allDay) return calendarDay(start);
  return '${calendarDay(start)} · ${calendarTime(start)}${end != null ? '–${calendarTime(end)}' : ''}';
}

String calendarError(Object error, String fallback) {
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty || text.length > 200 ? fallback : text;
}

/// Card di un evento (canvas: Calendario · prossimi).
class CalendarEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const CalendarEventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final kind = calendarKinds[event['kind']] ?? calendarKinds['event']!;
    final Color color = kind.$3.resolve(p);
    final start = calendarDate(event['starts_at']) ?? DateTime.now();
    final bool cancelled = event['status'] == 'cancelled';
    final subtitle = <String>[
      if (event['all_day'] != true) calendarTime(start),
      if ('${event['room'] ?? ''}'.isNotEmpty) '${event['room']}',
      if ((event['teachers'] as List? ?? []).isNotEmpty) (event['teachers'] as List).join(', '),
      if (event['all_day'] == true && event['ends_at'] != null) calendarWhen(event),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.eleganceMidnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.24)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Text(calendarMonths[start.month - 1].substring(0, 3).toUpperCase(),
                      style: SlText.mono(p, size: 10, color: color, weight: FontWeight.w700)),
                  Text('${start.day}', style: TextStyle(color: p.pureWhite, fontSize: 20, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    SlStatusBadge(label: kind.$1, tone: kind.$3),
                    if (cancelled) const SlStatusBadge(label: 'Annullato', tone: SlTone.danger),
                    if (event['status'] == 'provisional') const SlStatusBadge(label: 'Da confermare', tone: SlTone.warning),
                    if (event['followed'] == true) const SlStatusBadge(label: 'Seguito', tone: SlTone.success),
                  ]),
                  const SizedBox(height: 4),
                  Text('${event['title']}',
                      style: TextStyle(
                        color: p.pureWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: cancelled ? TextDecoration.lineThrough : null,
                      )),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: SlText.muted(p).copyWith(fontSize: 12)),
                  ],
                  if (event['booking_deadline'] != null) ...[
                    const SizedBox(height: 2),
                    Text('Prenotazioni entro il ${calendarDay(calendarDate(event['booking_deadline'])!)}',
                        style: TextStyle(color: p.adminAmber, fontSize: 11)),
                  ],
                ]),
              ),
              Icon(event['followed'] == true ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  size: 20, color: event['followed'] == true ? p.skyBlue : p.pureWhite.withValues(alpha: 0.45)),
            ]),
          ),
        ),
      ),
    );
  }
}
