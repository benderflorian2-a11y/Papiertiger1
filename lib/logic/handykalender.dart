/// Trägt Fristen, Kündigungstermine und Termine automatisch in den Kalender des Handys ein.
/// Die Planung ist reines Dart (testbar), nur [Handykalender] spricht mit Android.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/store.dart';
import 'datum.dart';
import 'zeitplan.dart';

class KalenderEintrag {
  KalenderEintrag(this.key, this.titel, this.datum, this.ganztags, this.text);

  /// Ändert sich, wenn Titel, Datum oder Text sich ändern – dann wird der alte Eintrag ersetzt.
  final String key;
  final String titel;
  final DateTime datum;
  final bool ganztags;
  final String text;
}

String _vorsatz(FaelligArt a) => switch (a) {
      FaelligArt.brief => 'Frist: ',
      FaelligArt.vertrag => 'Kündigen: ',
      FaelligArt.garantie => 'Garantie: ',
      FaelligArt.nachfassen => 'Nachfassen: ',
      FaelligArt.rechnung => 'Rechnung: ',
      FaelligArt.termin => '',
    };

/// Welche Fälligkeiten in den Kalender gehören: ab heute, höchstens [tageVoraus] Tage im Voraus.
List<KalenderEintrag> kalenderEintraegeAus(List<Faelligkeit> f, {required DateTime heute, int tageVoraus = 400}) {
  final ab = nurTag(heute);
  final bis = ab.add(Duration(days: tageVoraus));
  final out = <KalenderEintrag>[];
  final gesehen = <String>{};
  for (final x in f) {
    final tag = nurTag(x.datum);
    if (tag.isBefore(ab) || tag.isAfter(bis)) continue;
    final ganztags = x.datum.hour == 0 && x.datum.minute == 0;
    final titel = '${_vorsatz(x.art)}${x.titel}';
    final text = x.unsicher ? '${x.text} (Frist bitte im Brief prüfen)' : x.text;
    final key = stabileId('${x.art.name}|${x.refId}|$titel|${x.datum.toIso8601String()}').toString();
    if (!gesehen.add(key)) continue;
    out.add(KalenderEintrag(key, titel, x.datum, ganztags, text));
  }
  return out;
}

class KalenderPlan {
  KalenderPlan(this.neu, this.loeschen);

  /// Einträge, die noch nicht im Kalender stehen.
  final List<KalenderEintrag> neu;

  /// Schlüssel von Einträgen, die nicht mehr gebraucht werden (erledigt oder verschoben).
  final List<String> loeschen;
}

/// Vergleicht den Soll-Stand mit dem, was schon eingetragen wurde.
/// [ist]: Schlüssel → Termin-Nummer; -2 heißt „vom Nutzer gelöscht, nicht wieder anlegen“.
KalenderPlan kalenderPlan(List<KalenderEintrag> soll, Map<String, int> ist) {
  final sollKeys = {for (final e in soll) e.key};
  return KalenderPlan(
    [for (final e in soll) if (!ist.containsKey(e.key)) e],
    [for (final k in ist.keys) if (!sollKeys.contains(k)) k],
  );
}

class Handykalender {
  static const _kanal = MethodChannel('papiertiger/android');
  static const _speicher = 'kalender_ids';
  static bool deaktiviert = false;
  static bool _laeuft = false;

  static bool get verfuegbar => !kIsWeb && !deaktiviert;

  /// Fragt (einmal) nach der Erlaubnis, in den Kalender zu schreiben.
  static Future<bool> erlaubnis() async {
    if (!verfuegbar) return false;
    try {
      return await _kanal.invokeMethod<bool>('kalenderErlaubnis') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ein einzelner Eintrag (z. B. aus „In Kalender“). Gibt die Termin-Nummer zurück, < 0 bei Fehler.
  static Future<int> eintragen(String titel, DateTime datum,
      {String text = '', bool ganztags = true, List<int> erinnerung = const [], int id = 0}) async {
    if (!verfuegbar) return -1;
    final start = ganztags
        ? DateTime.utc(datum.year, datum.month, datum.day).millisecondsSinceEpoch
        : datum.millisecondsSinceEpoch;
    try {
      final r = await _kanal.invokeMethod<Object>('kalenderEintragen', {
        'titel': titel,
        'text': '$text\n\nErstellt mit Papiertiger.'.trim(),
        'start': start,
        'ganztags': ganztags,
        'erinnerung': erinnerung,
        'id': id,
      });
      return (r as num?)?.toInt() ?? -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<void> _loeschen(int id) async {
    try {
      await _kanal.invokeMethod<bool>('kalenderLoeschen', {'id': id});
    } catch (_) {}
  }

  /// Gleicht alle Fälligkeiten mit dem Handykalender ab. Läuft still im Hintergrund.
  /// Gibt die Zahl der neu eingetragenen Termine zurück.
  static Future<int> abgleichen(AppStore store, {DateTime? heute}) async {
    if (!verfuegbar || _laeuft || !store.erinnerungen.kalenderSync) return 0;
    _laeuft = true;
    try {
      final p = await SharedPreferences.getInstance();
      final ist = <String, int>{
        for (final e in (jsonDecode(p.getString(_speicher) ?? '{}') as Map<String, dynamic>).entries)
          e.key: (e.value as num).toInt()
      };
      final jetzt = heute ?? DateTime.now();
      final soll = kalenderEintraegeAus(
        faelligkeiten(
          briefe: store.briefe,
          vertraege: store.vertraege,
          belege: store.belege,
          termine: store.termine,
          rechnungen: store.bereichAktiv('selbststaendig') ? store.rechnungen : const [],
        ),
        heute: jetzt,
      );
      final plan = kalenderPlan(soll, ist);
      var neu = 0;
      for (final k in plan.loeschen) {
        final id = ist.remove(k);
        if (id != null && id > 0) await _loeschen(id);
      }
      for (final e in plan.neu) {
        final id = await eintragen(e.titel, e.datum, text: e.text, ganztags: e.ganztags, erinnerung: const []);
        if (id == -3 || id == -1) break; // keine Erlaubnis oder kein Kalender: später noch einmal
        ist[e.key] = id; // -2 (gelöscht) wird ebenfalls gemerkt
        if (id > 0) neu++;
      }
      await p.setString(_speicher, jsonEncode(ist));
      return neu;
    } catch (_) {
      return 0;
    } finally {
      _laeuft = false;
    }
  }

  /// Alle von Papiertiger angelegten Einträge wieder aus dem Kalender entfernen.
  static Future<void> alleEntfernen() async {
    if (!verfuegbar) return;
    final p = await SharedPreferences.getInstance();
    final ist = (jsonDecode(p.getString(_speicher) ?? '{}') as Map<String, dynamic>);
    for (final id in ist.values) {
      if ((id as num) > 0) await _loeschen(id.toInt());
    }
    await p.remove(_speicher);
  }
}
