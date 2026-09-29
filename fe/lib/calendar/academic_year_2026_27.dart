import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Date del calendario didattico 2026/27 fornite per UNICT; estremi compresi.
class AcademicYear2026Card extends StatelessWidget {
  const AcademicYear2026Card({super.key});

  static const periods = <(String, String, String)>[
    ('Immatricolazioni primo anno', '15/06/2026', '30/09/2026'),
    ('Iscrizioni anni successivi', '27/06/2026', '30/09/2026'),
    ('Piani di studio · prima finestra', '01/07/2026', '31/10/2026'),
    ('Piani di studio · seconda finestra', '01/03/2027', '31/03/2027'),
    ('Primo periodo di attività formativa', '01/10/2026', '15/01/2027'),
    ('Pausa invernale delle lezioni', '24/12/2026', '06/01/2027'),
    ('Secondo periodo di attività formativa', '01/03/2027', '11/06/2027'),
    ('Pausa primaverile delle lezioni', '26/03/2027', '30/03/2027'),
    ('Appelli straordinari e prove in itinere', '17/12/2026', '23/12/2026'),
    ('Prima sessione d’esami', '18/01/2027', '26/02/2027'),
    ('Appelli straordinari e prove in itinere', '19/04/2027', '23/04/2027'),
    ('Seconda sessione d’esami', '14/06/2027', '30/07/2027'),
    ('Terza sessione d’esami', '30/08/2027', '30/09/2027'),
  ];

  static bool _notFinished(String end) {
    final parts = end.split('/');
    final last = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    final now = DateTime.now();
    return !last.isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(child: ExpansionTile(
      leading: Icon(Icons.event_note_outlined, color: p.skyBlue),
      title: const Text('Calendario didattico 2026/27'),
      subtitle: const Text('Università di Catania · date comprese'),
      children: [
        for (final (title, start, end) in periods.where((p) => _notFinished(p.$3)))
          ListTile(
            dense: true,
            title: Text(title),
            subtitle: Text('$start – $end'),
          ),
      ],
    ));
  }
}
