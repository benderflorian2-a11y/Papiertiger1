import 'package:flutter/material.dart';

import 'data/store.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.oeffnen();
  runApp(PapiertigerApp(store: store));
}
