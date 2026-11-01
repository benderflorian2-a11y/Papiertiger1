import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'data/store.dart';
import 'logic/android_kanal.dart';
import 'logic/benachrichtigungen.dart';
import 'logic/ki.dart';
import 'logic/pdf_import.dart';
import 'logic/postfach_dienst.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Browser-Version: keine KI auf dem Gerät, keine geplanten Benachrichtigungen
  if (kIsWeb) {
    Ki.deaktiviert = true;
    Benachrichtigungen.deaktiviert = true;
  }
  final store = await AppStore.oeffnen();
  // KI im Hintergrund vorbereiten; Fehler dürfen den Start nie verhindern.
  Ki.starten().catchError((Object _) {});
  PdfImport.starten();
  // Erinnerungen neu planen, wann immer sich etwas ändert.
  Benachrichtigungen.planen(store);
  store.addListener(() => Benachrichtigungen.spaeterPlanen(store));
  PostfachDienst.planen(store).catchError((Object _) {});
  runApp(PapiertigerApp(store: store));
}

/// Start ohne Bildschirm: Android ruft das etwa alle 30 Minuten auf, wenn ein Postfach verknüpft ist.
/// Sieht nach neuen wichtigen E-Mails und meldet sie. Liest nur, verschickt nie.
@pragma('vm:entry-point')
Future<void> mailHintergrund() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    final store = await AppStore.oeffnen();
    if (!store.lesefehler && store.postfach.konto?.automatisch == true) {
      await PostfachDienst.jetzt(store, melden: true).timeout(const Duration(minutes: 3));
    }
  } catch (_) {}
  await mailFertig();
}
