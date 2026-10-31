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

/// Spracheingabe über das Android-System (Google oder Samsung). Liefert den erkannten Text,
/// null bei Abbruch. Wirft [StateError], wenn das Gerät keine Spracheingabe hat.
Future<String?> diktieren() async {
  try {
    return await const MethodChannel('papiertiger/android').invokeMethod<String>('diktieren');
  } on PlatformException catch (e) {
    if (e.code == 'keine_spracheingabe') throw StateError('Keine Spracheingabe auf diesem Gerät gefunden.');
    return null;
  } on MissingPluginException {
    throw StateError('Spracheingabe gibt es nur in der Android-App.');
  }
}

/// E-Mail mit PDF-Anhängen in der E-Mail-App vorbereiten. Senden musst du dort selbst.
Future<bool> mailMitAnhang({required String an, required String betreff, required String text, List<String> pfade = const []}) async {
  try {
    return await const MethodChannel('papiertiger/android')
            .invokeMethod<bool>('mailSenden', {'an': an, 'betreff': betreff, 'text': text, 'pfade': pfade}) ??
        false;
  } catch (_) {
    return false;
  }
}

/// Sparkassen-App (bzw. S-pushTAN) öffnen, falls installiert.
Future<bool> bankingAppOeffnen() async {
  try {
    return await const MethodChannel('papiertiger/android').invokeMethod<bool>('appOeffnen', {
          'pakete': ['com.starfinanz.smob.android.sfinanzstatus', 'com.starfinanz.mobile.android.pushtan'],
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// Startbildschirm-Widget neu zeichnen (Text steht in den Einstellungen „widget_titel“/„widget_text“).
Future<void> widgetAktualisieren() async {
  try {
    await const MethodChannel('papiertiger/android').invokeMethod<int>('widget');
  } catch (_) {}
}

const _sicherKanal = MethodChannel('papiertiger/android');

/// In Widget-Tests abschalten: Aufrufe an Android würden dort nie beantwortet.
bool sicherheitNativAus = false;

/// Schlüssel für die Datenverschlüsselung aus dem Android-Keystore (32 Byte, Base64).
/// null, wenn es keinen gibt (z. B. in Tests). Wirft bei einem echten Fehler.
Future<String?> datenschluesselHolen() async {
  if (sicherheitNativAus) return null;
  try {
    return await _sicherKanal.invokeMethod<String>('datenschluessel');
  } on MissingPluginException {
    return null;
  }
}

/// Bildschirmfotos und Vorschau im App-Wechsler verhindern.
Future<void> bildschirmschutz(bool an) async {
  if (sicherheitNativAus) return;
  try {
    await _sicherKanal.invokeMethod<bool>('bildschirmschutz', {'an': an});
  } catch (_) {}
}

/// Hat das Handy eine Displaysperre (PIN, Muster, Fingerabdruck)?
Future<bool> geraetGesichert() async {
  if (sicherheitNativAus) return false;
  try {
    return await _sicherKanal.invokeMethod<bool>('geraetGesichert') ?? false;
  } catch (_) {
    return false;
  }
}

/// Mit der Displaysperre des Handys bestätigen. true = erfolgreich.
Future<bool> geraetEntsperren() async {
  if (sicherheitNativAus) return false;
  try {
    return await _sicherKanal.invokeMethod<bool>('geraetEntsperren') ?? false;
  } catch (_) {
    return false;
  }
}
