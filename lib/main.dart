import 'package:flutter/material.dart';

import 'data/store.dart';
import 'logic/benachrichtigungen.dart';
import 'logic/ki.dart';
import 'logic/pdf_import.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.oeffnen();
  // KI im Hintergrund vorbereiten; Fehler dürfen den Start nie verhindern.
  Ki.starten().catchError((Object _) {});
  PdfImport.starten();
  // Erinnerungen neu planen, wann immer sich etwas ändert.
  Benachrichtigungen.planen(store);
  store.addListener(() => Benachrichtigungen.spaeterPlanen(store));
  runApp(PapiertigerApp(store: store));
}
