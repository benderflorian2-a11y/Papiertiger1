import 'package:flutter/material.dart';

import 'data/store.dart';
import 'logic/ki.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.oeffnen();
  // KI im Hintergrund vorbereiten; Fehler dürfen den Start nie verhindern.
  Ki.starten().catchError((Object _) {});
  runApp(PapiertigerApp(store: store));
}
