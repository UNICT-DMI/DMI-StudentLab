import 'package:flutter/material.dart';

import 'package:fe/theme/app_icon_service.dart';
import 'package:fe/theme/app_palette.dart';
import 'package:fe/theme/studentlab_brand.dart';
import 'package:fe/theme/theme_controller.dart';

import 'app_icon_section.dart';
import 'studentlab_ui.dart';

/// Temi divisi in scuri e chiari, con anteprima dei colori e del logo nel
/// colore del tema. Il tema si applica subito a tutta l'app (colori,
/// mascotte, logo, titolo iniziale) e resta salvato su questo dispositivo.
class StudentLabThemePicker extends StatefulWidget {
  const StudentLabThemePicker({super.key});

  @override
  State<StudentLabThemePicker> createState() => _StudentLabThemePickerState();
}

class _StudentLabThemePickerState extends State<StudentLabThemePicker> {
  bool _saveFailed = false;

  Future<void> _select(StudentLabTheme theme) async {
    final bool saved = await StudentLabThemeController.instance.setTheme(theme);
    if (mounted) setState(() => _saveFailed = !saved);
  }

  @override
  Widget build(BuildContext context) {
    final controller = StudentLabThemeController.instance;
    // Material garantisce il font e lo stile del testo anche quando il
    // selettore è inserito in un contenitore senza Material (es. un pannello).
    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final p = context.palette;
          Widget group(String title, String subtitle, Iterable<StudentLabTheme> themes) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(title, style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Expanded(child: Text(subtitle, style: SlText.muted(p).copyWith(fontSize: 11))),
              ]),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                final int columns = constraints.maxWidth >= 620 ? 4 : (constraints.maxWidth >= 300 ? 3 : 2);
                const double gap = 8;
                final double width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(spacing: gap, runSpacing: gap, children: [
                  for (final theme in themes)
                    SizedBox(
                      width: width,
                      child: _ThemeCard(
                        theme: theme,
                        selected: controller.theme == theme,
                        onTap: () => _select(theme),
                      ),
                    ),
                ]);
              }),
            ]);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              group('Scuri', 'Riposanti di sera', StudentLabTheme.values.where((t) => !t.isLight)),
              const SizedBox(height: 16),
              group('Chiari', 'In anteprima: alcune schermate potrebbero non essere ancora adattate',
                  StudentLabTheme.values.where((t) => t.isLight)),
              const SizedBox(height: 12),
              Text(
                _saveFailed
                    ? 'Tema applicato, ma non è stato possibile salvarlo: alla prossima apertura tornerà quello precedente.'
                    : 'Si applica subito, anche a mascotte e logo, ed è salvato su questo dispositivo. Non serve premere Salva.',
                style: SlText.muted(p).copyWith(color: _saveFailed ? p.adminAmber : null),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final StudentLabTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({required this.theme, required this.selected, required this.onTap});

  static String _logoFor(StudentLabTheme theme) => theme == StudentLabTheme.notte
      ? 'assets/icons/favicon.png'
      : 'assets/mascot/themes/${theme.id}_favicon.webp';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final AppPalette preview = theme.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tema ${theme.label}. ${theme.description}',
      excludeSemantics: true,
      child: Material(
        color: p.darkElegance,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? p.skyBlue : p.pureWhite.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(children: <Widget>[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                // Anteprima: fondo, pannelli, colore principale e logo del tema.
                Container(
                  height: 64,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: preview.darkElegance,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: preview.pureWhite.withValues(alpha: 0.08)),
                  ),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(_logoFor(theme), width: 30, height: 30, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 30, height: 30, color: preview.skyBlue)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _bar(preview.brandNightBlue, height: 10),
                        const SizedBox(height: 5),
                        _bar(preview.eleganceDeepNavy, height: 12),
                        const Spacer(),
                        _bar(preview.skyBlue, width: 34, height: 7),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text(theme.label, style: TextStyle(color: p.pureWhite, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(theme.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SlText.muted(p).copyWith(fontSize: 11)),
              ]),
              if (selected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: p.skyBlue, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 15, color: p.darkElegance),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bar(Color color, {double? width, required double height}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      );
}

/// Sezione "Tema dell'app" pronta da inserire in una pagina (profilo,
/// modifica profilo). Ha il suo pannello e il suo titolo.
class StudentLabThemeSection extends StatelessWidget {
  const StudentLabThemeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StudentLabThemeController.instance,
      builder: (context, _) {
        final p = context.palette;
        return Material(
          color: p.eleganceMidnight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: p.skyBlue.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(StudentLabBrand.logo, width: 36, height: 36, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SlIconTile(icon: Icons.palette_outlined, size: 36)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tema dell’app',
                        style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Attivo: ${StudentLabThemeController.instance.theme.label}', style: SlText.muted(p)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              const StudentLabThemePicker(),
              if (StudentLabAppIcon.instance.isSupported) ...[
                const SizedBox(height: 14),
                const StudentLabAppIconSection(),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// Pannello dal basso con il selettore (menu account, profilo).
Future<void> showStudentLabThemeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.eleganceDeepNavy,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => ListenableBuilder(
      listenable: StudentLabThemeController.instance,
      builder: (context, _) {
        final p = context.palette;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.pureWhite.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Tema dell’app', style: TextStyle(color: p.pureWhite, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const StudentLabThemePicker(),
                if (StudentLabAppIcon.instance.isSupported) ...[
                  const SizedBox(height: 16),
                  const StudentLabAppIconSection(),
                ],
              ]),
            ),
          ),
        );
      },
    ),
  );
}
