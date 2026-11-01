/// Verbindet Postfach-Prüfung, gespeicherte Daten, Benachrichtigung und Hintergrund-Plan.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../data/postfach.dart';
import '../data/store.dart';
import 'android_kanal.dart';
import 'benachrichtigungen.dart';
import 'postfach_pruefung.dart';

class PostfachDienst {
  static bool _laeuft = false;

  /// E-Mail-Postfach geht nur in der App (der Browser kann keine Mail-Server erreichen).
  static bool get verfuegbar => !kIsWeb;

  /// Jetzt nachsehen. [melden] = Benachrichtigung zeigen (im Hintergrund).
  static Future<List<MailHinweis>> jetzt(AppStore store, {bool melden = false}) async {
    if (!verfuegbar || _laeuft || store.postfach.konto == null) return [];
    _laeuft = true;
    try {
      await store.postfachNeuLaden();
      final neu = await postfachPruefen(store.postfach);
      await store.geaendert();
      if (melden) await Benachrichtigungen.mailMelden(neu);
      return neu;
    } finally {
      _laeuft = false;
    }
  }

  /// Beim Öffnen der App: nachsehen, wenn das letzte Mal über 10 Minuten her ist.
  static Future<void> wennFaellig(AppStore store) async {
    final k = store.postfach.konto;
    if (!verfuegbar || k == null) return;
    await store.postfachNeuLaden();
    final z = store.postfach.konto?.zuletzt;
    if (z != null && DateTime.now().difference(z) < const Duration(minutes: 10)) return;
    try {
      await jetzt(store);
    } catch (_) {}
  }

  /// Hintergrund-Prüfung passend zum Konto ein- oder ausschalten.
  static Future<void> planen(AppStore store) async {
    if (!verfuegbar || !Platform.isAndroid) return;
    final k = store.postfach.konto;
    await mailPruefungPlanen(k != null && k.automatisch);
  }

  /// Verknüpfung lösen: Zugangsdaten und Hinweise löschen.
  static Future<void> trennen(AppStore store) async {
    store.postfach = Postfach();
    await store.geaendert();
    await planen(store);
  }
}
