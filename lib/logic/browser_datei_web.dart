import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Datei im Browser herunterladen (es gibt dort kein Dateisystem).
void browserHerunterladen(Uint8List daten, String name, String mime) {
  final blob = web.Blob([daten.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
