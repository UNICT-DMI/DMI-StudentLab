import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_icon_web_stub.dart' if (dart.library.js_interop) 'app_icon_web.dart';
import 'app_palette.dart';
import 'theme_controller.dart';

/// Stato dell'icona sul telefono (sezione "Icona sul telefono").
enum AppIconState { off, pending, applied }

/// Icona dell'app che segue il tema.
///
/// - Android: un activity-alias per tema nel manifest; il cambio avviene
///   quando l'utente esce dall'app, per non farla chiudere dal sistema.
/// - Web: cambia subito l'icona della scheda del browser.
/// - iPhone e desktop: non disponibile.
///
/// La scelta (attiva o no) è salvata su questo dispositivo.
class StudentLabAppIcon extends ChangeNotifier with WidgetsBindingObserver {
  StudentLabAppIcon._();

  static final StudentLabAppIcon instance = StudentLabAppIcon._();

  static const String _storageKey = 'studentlab.app_icon.follow_theme';
  static const MethodChannel _channel = MethodChannel('studentlab/app_icon');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  bool _enabled = false;
  String _applied = 'notte';
  bool _started = false;

  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isSupported => kIsWeb || isAndroid;
  bool get enabled => _enabled;

  /// Icona attualmente sul telefono (id del tema).
  String get applied => _applied;

  /// Icona che si vuole (tema attivo se l'opzione è accesa, altrimenti Notte).
  String get wanted => _enabled ? StudentLabThemeController.instance.theme.id : 'notte';

  AppIconState get state {
    if (!_enabled && _applied == 'notte') return AppIconState.off;
    if (_applied != wanted) return AppIconState.pending;
    return _enabled ? AppIconState.applied : AppIconState.off;
  }

  /// Da chiamare una volta all'avvio, dopo il caricamento del tema.
  Future<void> start() async {
    if (_started || !isSupported) return;
    _started = true;
    try {
      _enabled = (await _storage.read(key: _storageKey)) == 'true';
    } catch (_) {
      _enabled = false;
    }
    if (isAndroid) {
      try {
        _applied = (await _channel.invokeMethod<String>('current')) ?? 'notte';
      } catch (_) {
        _applied = 'notte';
      }
    } else {
      _applyWeb();
    }
    StudentLabThemeController.instance.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      await _storage.write(key: _storageKey, value: value ? 'true' : 'false');
    } catch (_) {
      // Resta attiva per questa sessione anche se non si salva.
    }
    if (kIsWeb) _applyWeb();
    notifyListeners();
  }

  /// Rimette l'icona originale (Notte) e spegne l'opzione.
  Future<void> restoreOriginal() => setEnabled(false);

  void _onThemeChanged() {
    if (kIsWeb) _applyWeb();
    notifyListeners();
  }

  void _applyWeb() {
    if (!kIsWeb) return;
    final String id = wanted;
    final String url = id == 'notte'
        ? 'favicon.png'
        : 'assets/assets/mascot/themes/${id}_favicon.webp';
    try {
      setBrowserFavicon(url);
      _applied = id;
    } catch (_) {
      // L'icona della scheda è solo estetica.
    }
  }

  /// Android: il cambio avviene quando l'app va in secondo piano.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (!isAndroid) return;
    if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.hidden) {
      _applyAndroid();
    } else if (lifecycle == AppLifecycleState.resumed) {
      _refreshAndroid();
    }
  }

  Future<void> _applyAndroid() async {
    final String target = wanted;
    if (target == _applied) return;
    try {
      _applied = (await _channel.invokeMethod<String>('set', {'id': target})) ?? target;
    } catch (_) {
      // Riproverà alla prossima uscita dall'app.
    }
    notifyListeners();
  }

  Future<void> _refreshAndroid() async {
    try {
      final String? current = await _channel.invokeMethod<String>('current');
      if (current != null && current != _applied) {
        _applied = current;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Anteprima dell'icona di un tema (le stesse immagini del logo nell'app).
  static String previewAsset(String themeId) => themeId == 'notte'
      ? 'assets/icons/favicon.png'
      : 'assets/mascot/themes/${themeId}_favicon.webp';

  static String labelOf(String themeId) => StudentLabTheme.fromId(themeId).label;
}
