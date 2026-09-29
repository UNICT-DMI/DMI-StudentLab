import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Cambia l'icona della scheda del browser (link rel="icon").
void setBrowserFavicon(String url) {
  final JSObject document = globalContext['document'] as JSObject;
  final JSAny? link = document.callMethod('querySelector'.toJS, 'link[rel="icon"]'.toJS);
  if (link != null) {
    (link as JSObject)['href'] = url.toJS;
  }
}
