import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Datei im Browser speichern. Läuft die Seite in Claude, fragt dessen Download-Dialog
/// (sonst blockiert); sonst ganz normal als Download.
Future<void> browserHerunterladen(Uint8List daten, String name, String mime) async {
  final blob = web.Blob([daten.toJS].toJS, web.BlobPropertyBag(type: mime));
  final claude = globalContext.getProperty<JSObject?>('claude'.toJS);
  if (claude != null && claude.has('use')) {
    try {
      final ns = await claude.callMethod<JSPromise<JSObject?>>('use'.toJS, 'downloads'.toJS).toDart;
      if (ns != null) {
        final anfrage = JSObject()
          ..setProperty('filename'.toJS, name.toJS)
          ..setProperty('data'.toJS, blob);
        await ns.callMethod<JSPromise<JSAny?>>('save'.toJS, anfrage).toDart;
        return;
      }
    } catch (_) {
      // abgelehnt oder nicht möglich: nicht noch einmal fragen
      return;
    }
  }
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
