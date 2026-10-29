/// Verbindung zur Android-Seite der App: Geteiltes empfangen und
/// E-Mail-, Telefon- und Web-Links öffnen.
library;

import 'package:flutter/services.dart';

class Geteilt {
  Geteilt({this.text, this.betreff, this.pfad, this.mime, this.name});

  final String? text;
  final String? betreff;
  final String? pfad;
  final String? mime;
  final String? name;

  bool get istText => pfad == null;

  factory Geteilt.ausMap(Map<Object?, Object?> m) => Geteilt(
        text: m['text'] as String?,
        betreff: m['betreff'] as String?,
        pfad: m['pfad'] as String?,
        mime: m['mime'] as String?,
        name: m['name'] as String?,
      );
}

class AndroidKanal {
  static const _kanal = MethodChannel('papiertiger/android');

  /// Was andere Apps mit „Teilen → Papiertiger“ geschickt haben. Wird nur einmal geliefert.
  static Future<List<Geteilt>> abholen() async {
    try {
      final l = await _kanal.invokeMethod<List<Object?>>('geteilt');
      return [for (final m in l ?? const []) if (m is Map) Geteilt.ausMap(m)];
    } catch (_) {
      return [];
    }
  }

  /// Ruft [neu] auf, wenn während die App läuft etwas geteilt wird.
  static void beiNeuem(void Function() neu) {
    _kanal.setMethodCallHandler((call) async {
      if (call.method == 'neu') neu();
    });
  }

  /// Öffnet E-Mail-App (mailto:), Telefon (tel:) oder Browser (https:).
  /// Es wird nichts verschickt oder gewählt, ohne dass du es dort bestätigst.
  static Future<bool> oeffnen(Uri uri) async {
    try {
      return await _kanal.invokeMethod<bool>('oeffnen', {'uri': uri.toString()}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
