import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_palette.dart';

/// Tema scelto dall'utente, salvato su questo dispositivo.
///
/// Non tocca il database locale né il backend: usa lo stesso archivio sicuro
/// già usato dall'app per la sessione, con una chiave dedicata.
///
/// Cambiare tema aggiorna [AppPalette.current], che è la fonte sia di
/// `AppColors.x` sia di `context.palette.x`, e poi ridisegna tutta l'app
/// mantenendo pagine aperte, testo inserito e posizione di scorrimento.
class StudentLabThemeController extends ChangeNotifier {
  StudentLabThemeController._({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final StudentLabThemeController instance = StudentLabThemeController._();

  static const String _storageKey = 'studentlab.theme';

  final FlutterSecureStorage _storage;
  StudentLabTheme _theme = StudentLabTheme.kiwi;

  StudentLabTheme get theme => _theme;
  AppPalette get palette => _theme.palette;

  /// Legge il tema salvato; Kiwi è il valore iniziale per le nuove installazioni.
  Future<void> load() async {
    try {
      _theme = StudentLabTheme.fromId(await _storage.read(key: _storageKey));
    } catch (_) {
      _theme = StudentLabTheme.kiwi;
    }
    _apply(_theme);
    notifyListeners();
  }

  /// Applica subito il tema e lo salva. Restituisce `false` se il salvataggio
  /// non riesce: il tema resta comunque applicato fino alla chiusura dell'app.
  Future<bool> setTheme(StudentLabTheme theme) async {
    if (theme == _theme) return true;
    _theme = theme;
    _apply(theme);
    notifyListeners();
    _rebuildEverything();
    try {
      await _storage.write(key: _storageKey, value: theme.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _apply(StudentLabTheme theme) {
    AppPalette.current = theme.palette;
    AppPalette.currentIsLight = theme.isLight;
  }

  /// Segna da ridisegnare ogni elemento dell'albero: anche i widget che non
  /// dipendono dal Theme rileggono `AppColors.x` e prendono i nuovi colori.
  /// Lo stato dei widget (pagine aperte, campi di testo, scroll) resta.
  void _rebuildEverything() {
    final Element? root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }
    root.visitChildren(mark);
  }

  /// ThemeData dell'app costruito dalla palette corrente.
  ThemeData buildTheme() {
    final AppPalette p = palette;
    final bool light = _theme.isLight;
    // I temi chiari partono dal tema chiaro di Material: i testi senza un
    // colore esplicito diventano scuri.
    final ThemeData base = light ? ThemeData.light() : ThemeData.dark();
    return base.copyWith(
      // Con Notte il risultato è identico al tema che l'app usava prima.
      colorScheme: light
          ? ColorScheme.fromSeed(seedColor: p.skyBlue, brightness: Brightness.light)
              .copyWith(surface: p.eleganceDeepNavy, onSurface: p.pureWhite)
          : ColorScheme.fromSeed(
              seedColor: p.brandNightBlue,
              brightness: Brightness.dark,
            ),
      scaffoldBackgroundColor: p.darkElegance,
      appBarTheme: AppBarTheme(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.pearlWhite,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: p.pureWhite, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.surfaceBorder),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.eleganceMidnight,
        selectedItemColor: p.diamondDust,
        unselectedItemColor: p.steelBlue,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      extensions: <ThemeExtension<dynamic>>[p],
    );
  }
}
