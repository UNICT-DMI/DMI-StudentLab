import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:fe/theme/app_icon_service.dart';
import 'package:fe/theme/app_palette.dart';
import 'package:fe/theme/theme_controller.dart';

import 'studentlab_ui.dart';

/// "Icona sul telefono" (canvas: Icona sul telefono · proposta).
///
/// Stati: spenta (anteprima prima/dopo e avvisi), conferma all'attivazione,
/// in attesa (si applica uscendo dall'app), applicata. Nel browser cambia
/// subito l'icona della scheda. Su iPhone e desktop la sezione non compare.
class StudentLabAppIconSection extends StatelessWidget {
  const StudentLabAppIconSection({super.key});

  @override
  Widget build(BuildContext context) {
    final icon = StudentLabAppIcon.instance;
    if (!icon.isSupported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([icon, StudentLabThemeController.instance]),
      builder: (context, _) {
        final p = context.palette;
        final AppIconState state = icon.state;
        final String themeId = StudentLabThemeController.instance.theme.id;
        final String themeLabel = StudentLabThemeController.instance.theme.label;
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
                const SlIconTile(icon: Icons.app_shortcut_outlined, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(kIsWeb ? 'Icona della scheda' : 'Icona sul telefono',
                        style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(kIsWeb ? 'Usa l’icona del tema nella scheda del browser' : 'Usa l’icona del tema nella schermata home',
                        style: SlText.muted(p)),
                  ]),
                ),
                Switch(
                  value: icon.enabled,
                  onChanged: (value) async {
                    if (!value) {
                      await icon.setEnabled(false);
                      return;
                    }
                    if (kIsWeb || await _confirm(context, themeId, themeLabel)) {
                      await icon.setEnabled(true);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              if (kIsWeb)
                Text('Si applica subito alla scheda del browser.', style: SlText.muted(p))
              else if (state == AppIconState.off)
                ..._offBody(p, icon.applied, themeId, themeLabel)
              else if (state == AppIconState.pending)
                ..._pendingBody(p, icon)
              else
                ..._appliedBody(p, icon),
              const SizedBox(height: 10),
              Text(
                kIsWeb
                    ? 'Nell’app per Android cambia l’icona sul telefono; su iPhone non è disponibile.'
                    : 'Solo Android. Nel browser cambia l’icona della scheda; su iPhone non è disponibile.',
                style: SlText.muted(p).copyWith(fontSize: 11),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _icon(String themeId, double size, {bool dim = false, Color? ring}) {
    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: Container(
        decoration: ring == null
            ? null
            : BoxDecoration(borderRadius: BorderRadius.circular(size * 0.27), border: Border.all(color: ring, width: 2)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: Image.asset(StudentLabAppIcon.previewAsset(themeId), width: size, height: size, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _home(AppPalette p, String themeId, String caption, Color captionColor) {
    Widget app(Color color, String name) => Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9))),
          const SizedBox(height: 3),
          Text(name, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 8)),
        ]);
    return Column(children: [
      Text(caption, style: SlText.mono(p, size: 10, color: captionColor)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [Color(0xFF2A2F3A), Color(0xFF1A1D24)]),
        ),
        child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
          app(const Color(0xFF3B4A5C), 'Foto'),
          app(const Color(0xFF35503E), 'Mappe'),
          app(const Color(0xFF4A3B5C), 'Posta'),
          Column(mainAxisSize: MainAxisSize.min, children: [
            _icon(themeId, 34),
            const SizedBox(height: 3),
            const Text('StudentLab', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 8, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    ]);
  }

  List<Widget> _offBody(AppPalette p, String appliedId, String themeId, String themeLabel) {
    return [
      Row(children: [
        Expanded(child: _home(p, appliedId, 'ADESSO', p.pureWhite.withValues(alpha: 0.56))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: p.pureWhite.withValues(alpha: 0.5)),
        ),
        Expanded(child: _home(p, themeId, 'CON ${themeLabel.toUpperCase()}', p.diamondDust)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.adminAmber.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.adminAmber.withValues(alpha: 0.28)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Prima di attivarla', style: TextStyle(color: p.adminAmber, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final line in const [
            'L’icona cambia quando esci dall’app, non mentre la usi.',
            'Su alcuni telefoni l’icona viene tolta dalla schermata home: la ritrovi tra tutte le app.',
            'Se era in una cartella, potrebbe uscirne.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('• $line', style: SlText.body(p).copyWith(fontSize: 12)),
            ),
        ]),
      ),
    ];
  }

  List<Widget> _status(AppPalette p, String themeId, String title, String detail, Color dot, String dotText) {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.eleganceDeepNavy, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          _icon(themeId, 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(detail, style: SlText.muted(p)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(dotText, style: SlText.body(p).copyWith(fontSize: 12, color: dot))),
      ]),
    ];
  }

  List<Widget> _pendingBody(AppPalette p, StudentLabAppIcon icon) {
    final String target = icon.wanted;
    final bool restoring = !icon.enabled;
    return _status(
      p,
      target,
      restoring ? 'Icona originale pronta' : 'Icona ${StudentLabAppIcon.labelOf(target)} pronta',
      'Si applica quando esci da StudentLab.',
      p.adminAmber,
      'In attesa: esci dall’app per vederla nella home',
    );
  }

  List<Widget> _appliedBody(AppPalette p, StudentLabAppIcon icon) {
    return [
      ..._status(
        p,
        icon.applied,
        'L’icona segue il tema',
        'Ora sul telefono: ${StudentLabAppIcon.labelOf(icon.applied)}',
        p.adminGreen,
        'Applicata',
      ),
      const SizedBox(height: 10),
      SlActionButton(
        icon: Icons.restore_rounded,
        label: 'Rimetti l’icona originale',
        onPressed: icon.restoreOriginal,
      ),
    ];
  }

  Future<bool> _confirm(BuildContext context, String themeId, String themeLabel) async {
    final p = context.palette;
    final bool? ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: p.pureWhite.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _icon(StudentLabAppIcon.instance.applied, 60, dim: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.arrow_forward_rounded, color: p.pureWhite.withValues(alpha: 0.5)),
              ),
              _icon(themeId, 70, ring: p.skyBlue),
            ]),
            const SizedBox(height: 16),
            Text('Cambiare l’icona sul telefono?',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.pureWhite, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'L’icona diventa quella di $themeLabel quando esci da StudentLab. Su alcuni telefoni sparisce dalla home per qualche secondo o va rimessa dall’elenco delle app. Se poi cambi tema, l’icona lo segue.',
              textAlign: TextAlign.center,
              style: SlText.body(p).copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: p.skyBlue,
                foregroundColor: p.darkElegance,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Cambia icona'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.pureWhite.withValues(alpha: 0.86),
                minimumSize: const Size(0, 44),
                side: BorderSide(color: p.pureWhite.withValues(alpha: 0.14)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Non ora'),
            ),
          ]),
        ),
      ),
    );
    return ok == true;
  }
}
