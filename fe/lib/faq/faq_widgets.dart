import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../widgets/studentlab_ui/studentlab_ui.dart';

/// Categorie delle domande (stessi id del backend).
const List<(String, String, IconData, SlTone)> faqCategories = <(String, String, IconData, SlTone)>[
  ('exams', 'Esami e appelli', Icons.event_note_outlined, SlTone.warning),
  ('topics', 'Argomenti e lezioni', Icons.edit_note_rounded, SlTone.info),
  ('materials', 'Materiali', Icons.menu_book_outlined, SlTone.cyan),
  ('study_plan', 'Piano di studi', Icons.view_list_rounded, SlTone.violet),
  ('thesis', 'Tirocinio e tesi', Icons.workspace_premium_outlined, SlTone.success),
  ('campus_life', 'Vita universitaria', Icons.emoji_people_outlined, SlTone.private),
];

String faqCategoryLabel(String? id) =>
    faqCategories.where((c) => c.$1 == id).map((c) => c.$2).firstOrNull ?? 'Altro';

SlTone faqCategoryTone(String? id) =>
    faqCategories.where((c) => c.$1 == id).map((c) => c.$4).firstOrNull ?? SlTone.neutral;

String faqRelative(dynamic value) {
  final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return '${diff.inMinutes < 1 ? 1 : diff.inMinutes} min fa';
  if (diff.inHours < 24) return '${diff.inHours} h fa';
  if (diff.inDays == 1) return 'ieri';
  if (diff.inDays < 7) return '${diff.inDays} gg fa';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7} sett. fa';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String faqError(Object error, String fallback) {
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty || text.length > 200 ? fallback : text;
}

/// Badge di chi risponde.
Widget? faqRoleBadge(String? role) => switch (role) {
      'teacher' => const SlStatusBadge(label: 'Docente verificato', tone: SlTone.violet, icon: Icons.verified_rounded),
      'studentlab' => const SlStatusBadge(label: 'StudentLab', tone: SlTone.cyan, icon: Icons.verified_rounded),
      'guest' => const SlStatusBadge(label: 'Ospite'),
      _ => null,
    };

/// Stato di moderazione, per i propri contenuti non ancora pubblicati.
Widget? faqStatusBadge(String? status) => switch (status) {
      'pending' => const SlStatusBadge(label: 'In attesa di controllo', tone: SlTone.warning),
      'rejected' => const SlStatusBadge(label: 'Non pubblicata', tone: SlTone.danger),
      _ => null,
    };

/// Pulsante "Utile" con conteggio.
class FaqVoteButton extends StatelessWidget {
  final int count;
  final bool active;
  final VoidCallback? onPressed;

  const FaqVoteButton({super.key, required this.count, required this.active, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color color = active ? p.skyBlue : p.pureWhite.withValues(alpha: 0.72);
    return Semantics(
      button: true,
      selected: active,
      label: 'Utile, $count voti',
      excludeSemantics: true,
      child: Material(
        color: active ? p.skyBlue.withValues(alpha: 0.12) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: active ? p.skyBlue.withValues(alpha: 0.40) : p.pureWhite.withValues(alpha: 0.12)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 44,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.arrow_upward_rounded, size: 15, color: color),
              Text('$count', style: SlText.mono(p, size: 11, color: color, weight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Riga di una domanda negli elenchi.
class FaqQuestionCard extends StatelessWidget {
  final Map<String, dynamic> question;
  final VoidCallback onTap;

  const FaqQuestionCard({super.key, required this.question, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final int answers = int.tryParse('${question['answers_count']}') ?? 0;
    final bool verified = question['has_verified_answer'] == true;
    final bool accepted = question['accepted_answer_id'] != null;
    final String answersText = answers == 0
        ? 'Nessuna risposta'
        : '$answers ${answers == 1 ? 'risposta' : 'risposte'}'
            '${verified ? ' · verificata' : (accepted ? ' · risolta' : '')}';
    final Color answersColor = verified ? p.adminIndigo : (accepted ? p.adminGreen : p.pureWhite.withValues(alpha: 0.6));
    final status = faqStatusBadge(question['status']?.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.eleganceMidnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.skyBlue.withValues(alpha: 0.10)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 36,
                child: Column(children: [
                  Icon(Icons.arrow_upward_rounded, size: 15, color: p.pureWhite.withValues(alpha: 0.72)),
                  Text('${question['useful_count'] ?? 0}',
                      style: SlText.mono(p, size: 12, color: p.pureWhite.withValues(alpha: 0.72), weight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${question['title'] ?? ''}',
                      style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 5, runSpacing: 5, children: [
                    if (status != null) status,
                    if ((question['subject_name'] ?? '').toString().isNotEmpty)
                      SlStatusBadge(label: '${question['subject_name']}', tone: SlTone.info),
                    SlStatusBadge(label: faqCategoryLabel(question['category']?.toString()),
                        tone: faqCategoryTone(question['category']?.toString())),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: Text(answersText,
                          style: TextStyle(color: answersColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    Text(faqRelative(question['created_at']), style: SlText.muted(p).copyWith(fontSize: 11)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Avatar con iniziali (o "?" per gli anonimi).
Widget faqAvatar(BuildContext context, String name, {String? role, double size = 32}) {
  final p = context.palette;
  final bool anonymous = name.startsWith('Studente') || name == 'Ospite' || name.isEmpty;
  final String initials = anonymous
      ? '?'
      : name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
  final Color ring = switch (role) {
    'teacher' => p.teacherIndigo,
    'studentlab' => p.adminCyan,
    'guest' => p.pureWhite.withValues(alpha: 0.4),
    _ => p.studentBlue,
  };
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: p.brandNightBlue,
      border: Border.all(color: ring, width: 2),
    ),
    child: role == 'studentlab'
        ? Icon(Icons.support_agent_rounded, size: size * 0.5, color: p.adminCyan)
        : Text(initials, style: TextStyle(color: p.pureWhite, fontSize: size * 0.34, fontWeight: FontWeight.w700)),
  );
}

/// Chip con menu, come i filtri delle Dispense (ateneo, dipartimento, corso, materia).
class FaqFilterChip extends StatelessWidget {
  final String label;
  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const FaqFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool active = selected != null;
    return PopupMenuButton<String>(
      tooltip: label,
      color: p.eleganceDeepNavy,
      enabled: options.isNotEmpty,
      onSelected: (value) => onChanged(value.isEmpty ? null : value),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: '', child: Text('Tutti · $label')),
        ...options.map((o) => PopupMenuItem<String>(value: o, child: Text(o))),
      ],
      child: Container(
        height: 38,
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? p.skyBlue.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? p.skyBlue.withValues(alpha: 0.40) : p.pureWhite.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(selected ?? label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: active ? p.diamondDust : p.pureWhite.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: active ? p.diamondDust : p.pureWhite.withValues(alpha: 0.72)),
        ]),
      ),
    );
  }
}
