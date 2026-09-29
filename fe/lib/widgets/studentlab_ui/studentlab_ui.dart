import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';

/// Componenti condivisi di StudentLab nello stile dell'area sviluppatori.
///
/// Leggono i colori da `context.palette`, quindi seguono il tema attivo.
/// Regole comuni:
/// - pannelli su `eleganceMidnight` / `eleganceDeepNavy` con bordo `skyBlue` a bassa opacità;
/// - riquadri icona su `brandNightBlue`;
/// - colori `admin*` usati con un significato fisso (vedi [SlTone]);
/// - testo secondario mai sotto alpha 0.56, target touch almeno 44 px.

/// Significato di un colore. Usa sempre lo stesso tono per lo stesso concetto.
enum SlTone { info, cyan, blue, success, warning, danger, violet, private, neutral }

extension SlToneColor on SlTone {
  Color resolve(AppPalette p) {
    switch (this) {
      case SlTone.info:
        return p.skyBlue;
      case SlTone.cyan:
        return p.adminCyan;
      case SlTone.blue:
        return p.adminBlue;
      case SlTone.success:
        return p.adminGreen;
      case SlTone.warning:
        return p.adminAmber;
      case SlTone.danger:
        return p.adminCoral;
      case SlTone.violet:
        return p.adminIndigo;
      case SlTone.private:
        return p.adminMagenta;
      case SlTone.neutral:
        return p.pureWhite.withValues(alpha: 0.72);
    }
  }
}

/// Stili di testo condivisi.
class SlText {
  const SlText._();

  static TextStyle title(AppPalette p) => TextStyle(
        color: p.pureWhite,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle body(AppPalette p) =>
      TextStyle(color: p.pureWhite.withValues(alpha: 0.86), fontSize: 13, height: 1.4);

  static TextStyle muted(AppPalette p) =>
      TextStyle(color: p.pureWhite.withValues(alpha: 0.58), fontSize: 12, height: 1.4);

  /// Etichette tecniche: numeri, codici, badge. Cifre a larghezza fissa.
  static TextStyle mono(AppPalette p, {double size = 12, Color? color, FontWeight? weight}) =>
      TextStyle(
        color: color ?? p.pureWhite.withValues(alpha: 0.72),
        fontSize: size,
        fontWeight: weight ?? FontWeight.w600,
        letterSpacing: 0.3,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
}

/// Pannello base. `elevated` usa la superficie più chiara per header e dettagli.
class SlPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final SlTone? accent;
  final bool elevated;
  final double radius;
  final double borderAlpha;

  const SlPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.elevated = false,
    this.radius = 18,
    this.borderAlpha = 0.14,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color border = accent?.resolve(p) ?? p.skyBlue;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: elevated ? p.eleganceDeepNavy : p.eleganceMidnight,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border.withValues(alpha: borderAlpha)),
      ),
      child: child,
    );
  }
}

/// Riquadro con icona colorata su `brandNightBlue`.
class SlIconTile extends StatelessWidget {
  final IconData icon;
  final SlTone tone;
  final double size;

  const SlIconTile({super.key, required this.icon, this.tone = SlTone.info, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.brandNightBlue,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: tone.resolve(p), size: size * 0.5),
    );
  }
}

/// Badge di stato (VISIBILE, IN REVISIONE, DRIVE…).
class SlStatusBadge extends StatelessWidget {
  final String label;
  final SlTone tone;
  final IconData? icon;
  final bool pill;

  const SlStatusBadge({
    super.key,
    required this.label,
    this.tone = SlTone.neutral,
    this.icon,
    this.pill = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color color = tone.resolve(p);
    final bool neutral = tone == SlTone.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: neutral ? p.pureWhite.withValues(alpha: 0.05) : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(pill ? 999 : 7),
        border: Border.all(
          color: neutral ? p.pureWhite.withValues(alpha: 0.16) : color.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label.toUpperCase(),
              style: SlText.mono(p, size: 11, color: color, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Titolo di sezione con sottotitolo e azione facoltativa a destra.
class SlSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SlSectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: SlText.title(p)),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(subtitle!, style: SlText.muted(p)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Header di pagina: icona, titolo, descrizione e badge di stato.
class SlPageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> badges;

  const SlPageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badges = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SlPanel(
      elevated: true,
      padding: const EdgeInsets.all(20),
      radius: 20,
      borderAlpha: 0.22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SlIconTile(icon: icon, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: TextStyle(
                        color: p.pureWhite, fontSize: 21, fontWeight: FontWeight.w700)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: SlText.body(p).copyWith(color: p.pureWhite.withValues(alpha: 0.64))),
                ],
                if (badges.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: badges),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card metrica: etichetta, valore grande, riga che spiega il numero.
class SlMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final SlTone tone;
  final SlTone? captionTone;

  const SlMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.tone = SlTone.info,
    this.captionTone,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SlPanel(
      accent: tone,
      radius: 16,
      borderAlpha: 0.18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: p.pureWhite.withValues(alpha: 0.66),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
              SlIconTile(icon: icon, tone: tone, size: 32),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: SlText.mono(p, size: 26, color: p.pureWhite, weight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(caption!,
                style: SlText.muted(p).copyWith(color: captionTone?.resolve(p))),
          ],
        ],
      ),
    );
  }
}

/// Card di navigazione verso una coda di lavoro, con contatore facoltativo.
class SlNavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final SlTone tone;
  final String? badge;
  final SlTone badgeTone;
  final VoidCallback onTap;

  const SlNavCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.tone = SlTone.info,
    this.badge,
    this.badgeTone = SlTone.warning,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: SlPanel(
          accent: tone,
          radius: 17,
          borderAlpha: 0.18,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SlIconTile(icon: icon, tone: tone),
                  const Spacer(),
                  if (badge != null) SlStatusBadge(label: badge!, tone: badgeTone, pill: true),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: p.pureWhite.withValues(alpha: 0.4)),
                ],
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: TextStyle(
                      color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description, style: SlText.muted(p)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra di utilizzo (es. spazio Drive).
class SlUsageBar extends StatelessWidget {
  final double fraction;
  final SlTone tone;

  const SlUsageBar({super.key, required this.fraction, this.tone = SlTone.info});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: p.pureWhite.withValues(alpha: 0.08),
        valueColor: AlwaysStoppedAnimation<Color>(tone.resolve(p)),
      ),
    );
  }
}

class SlFilterOption<T> {
  final T value;
  final String label;
  final int? count;

  const SlFilterOption({required this.value, required this.label, this.count});
}

/// Filtro segmentato scorrevole con conteggi.
class SlFilterBar<T> extends StatelessWidget {
  final List<SlFilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const SlFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.darkElegance,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final SlFilterOption<T> option in options)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _FilterButton(
                  label: option.label,
                  count: option.count,
                  selected: option.value == selected,
                  onTap: () => onSelected(option.value),
                  palette: p,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  const _FilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.skyBlue.withValues(alpha: 0.14) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
              color: selected ? p.skyBlue.withValues(alpha: 0.40) : Colors.transparent),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label,
                      style: TextStyle(
                        color: selected ? p.diamondDust : p.pureWhite.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      )),
                  if (count != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Text('$count',
                        style: SlText.mono(p,
                            size: 11,
                            color: selected ? p.skyBlue : p.pureWhite.withValues(alpha: 0.50))),
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

/// Stato vuoto con azioni concrete.
class SlEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  const SlEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: p.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.skyBlue.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: <Widget>[
          SlIconTile(icon: icon, size: 56),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: SlText.muted(p)),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Card di errore con "Riprova".
class SlErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const SlErrorCard({super.key, required this.title, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SlPanel(
      accent: SlTone.danger,
      borderAlpha: 0.30,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.adminCoral.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_amber_rounded, color: p.adminCoral),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(message, style: SlText.muted(p)),
              ],
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.adminCoral,
                minimumSize: const Size(0, 44),
                side: BorderSide(color: p.adminCoral.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Riprova'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottone secondario (bordo azzurro tenue) usato nelle toolbar.
class SlActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  const SlActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: primary ? p.diamondDust : p.pureWhite.withValues(alpha: 0.86),
        backgroundColor: primary ? p.skyBlue.withValues(alpha: 0.08) : Colors.transparent,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(
            color: primary ? p.skyBlue.withValues(alpha: 0.32) : p.pureWhite.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Estrae un messaggio leggibile dagli errori di [ApiService]
/// ("Errore …: 400 - {"detail":"…"}") senza mostrare il corpo grezzo.
String slErrorMessage(Object error, {String fallback = 'Operazione non riuscita. Riprova.'}) {
  final String text = error.toString();
  final RegExpMatch? match = RegExp(r'"detail"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(text);
  if (match != null) {
    final String detail = match.group(1)!.replaceAll(r'\"', '"').trim();
    if (detail.isNotEmpty) return detail;
  }
  return fallback;
}

/// Etichetta breve del tipo di file (PDF, DOC, PPT…) per i riquadri icona.
String slFileKind(String? mimeType, [String? fileName]) {
  final String mime = (mimeType ?? '').toLowerCase();
  final String name = (fileName ?? '').toLowerCase();
  if (mime.contains('pdf') || name.endsWith('.pdf')) return 'PDF';
  if (mime.contains('word') || name.endsWith('.doc') || name.endsWith('.docx')) return 'DOC';
  if (mime.contains('presentation') || mime.contains('powerpoint') ||
      name.endsWith('.ppt') || name.endsWith('.pptx')) return 'PPT';
  if (mime.startsWith('text/') || name.endsWith('.txt') || name.endsWith('.md')) return 'TXT';
  if (mime.startsWith('image/')) return 'IMG';
  return 'FILE';
}

/// Riquadro con la sigla del tipo di file.
class SlFileTile extends StatelessWidget {
  final String kind;
  final double size;

  const SlFileTile({super.key, required this.kind, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color color = kind == 'PDF'
        ? p.adminCoral
        : kind == 'PPT'
            ? p.adminAmber
            : kind == 'DOC'
                ? p.adminBlue
                : p.skyBlue;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.brandNightBlue, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text(kind, style: SlText.mono(p, size: size * 0.24, color: color, weight: FontWeight.w700)),
    );
  }
}

/// Riga "etichetta → valore" per i pannelli di dettaglio.
class SlKeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const SlKeyValue({super.key, required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 118, child: Text(label, style: SlText.muted(p))),
          Expanded(
            child: Text(value,
                style: mono ? SlText.mono(p, color: p.pureWhite) : SlText.body(p).copyWith(color: p.pureWhite)),
          ),
        ],
      ),
    );
  }
}

/// Etichetta di gruppo in maiuscolo (PROVENIENZA, FILE, POSIZIONE…).
class SlOverline extends StatelessWidget {
  final String text;
  const SlOverline(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text(text.toUpperCase(),
        style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56)));
  }
}

/// Opzione selezionabile con titolo e descrizione (radio a card).
class SlChoiceTile extends StatelessWidget {
  final String title;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  const SlChoiceTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? p.skyBlue.withValues(alpha: 0.10) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(
              color: selected ? p.skyBlue.withValues(alpha: 0.40) : p.pureWhite.withValues(alpha: 0.10)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: <Widget>[
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18, color: selected ? p.skyBlue : p.pureWhite.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(title,
                        style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                    if (description != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(description!, style: SlText.muted(p)),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// AppBar coerente per le pagine admin: percorso in piccolo + titolo.
PreferredSizeWidget slAdminAppBar(
  BuildContext context, {
  required String title,
  String breadcrumb = 'ADMIN / MATERIALI E STORAGE',
  List<Widget> actions = const <Widget>[],
}) {
  final p = context.palette;
  return AppBar(
    backgroundColor: p.brandNightBlue,
    foregroundColor: p.pureWhite,
    titleSpacing: 4,
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(breadcrumb, style: SlText.mono(p, size: 11, color: p.pureWhite.withValues(alpha: 0.56))),
        Text(title),
      ],
    ),
    actions: <Widget>[...actions, const SizedBox(width: 8)],
  );
}
