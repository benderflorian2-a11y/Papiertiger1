/// Fristen, Termine und Erinnerungen. Reines Dart, damit es testbar ist.
library;

import '../data/models.dart';
import 'brief_analyse.dart';
import 'datum.dart';
import 'ordnung.dart';
import 'vertrag_logik.dart';

enum FaelligArt { brief, vertrag, garantie, termin, nachfassen }

class Faelligkeit {
  Faelligkeit(this.art, this.datum, this.titel, this.text, this.refId, {this.unsicher = false});

  final FaelligArt art;
  final DateTime datum;
  final String titel;
  final String text;

  /// Id des Briefs, Vertrags, Belegs oder Termins.
  final String refId;
  final bool unsicher;
}

/// Nächstes Datum eines wiederkehrenden Termins ab heute.
DateTime naechstesTermindatum(Termin t, {DateTime? heute}) {
  final jetzt = nurTag(heute ?? DateTime.now());
  var d = t.datum;
  if (t.wiederholungMonate <= 0) return d;
  var schritte = 0;
  while (nurTag(d).isBefore(jetzt) && schritte < 1000) {
    final n = plusMonate(d, t.wiederholungMonate);
    d = DateTime(n.year, n.month, n.day, t.datum.hour, t.datum.minute);
    schritte++;
  }
  return d;
}

/// Alle offenen Fälligkeiten, nach Datum sortiert.
List<Faelligkeit> faelligkeiten({
  required List<Brief> briefe,
  required List<Vertrag> vertraege,
  required List<Beleg> belege,
  required List<Termin> termine,
  DateTime? heute,
}) {
  final jetzt = nurTag(heute ?? DateTime.now());
  final liste = <Faelligkeit>[];
  for (final b in briefe) {
    if (b.erledigt) continue;
    if (b.frist != null) {
      liste.add(Faelligkeit(FaelligArt.brief, b.frist!, titelVon(b),
          b.aufgaben.where((a) => !a.erledigt).map((a) => a.text).firstOrNull ?? typFuer(b.typ).name, b.id,
          unsicher: b.fristUnsicher));
    }
    if (b.nachfassenAm != null) {
      liste.add(Faelligkeit(FaelligArt.nachfassen, b.nachfassenAm!, titelVon(b),
          'Noch keine Antwort? Dann nachfassen.', b.id));
    }
  }
  for (final v in vertraege) {
    final pruefen = bestaetigungPruefenAb(v);
    if (pruefen != null) {
      liste.add(Faelligkeit(FaelligArt.vertrag, pruefen, v.anbieter,
          'Kündigungsbestätigung noch nicht da? Beim Anbieter nachhaken.', v.id));
    }
    if (v.gekuendigt) continue;
    final info = kuendigungsInfo(v, heute: jetzt);
    if (info.kuendigenBis.difference(jetzt).inDays > 120) continue;
    liste.add(Faelligkeit(FaelligArt.vertrag, info.kuendigenBis, v.anbieter,
        'Kündigen bis ${_d(info.kuendigenBis)}, sonst läuft der Vertrag weiter', v.id));
  }
  for (final b in belege) {
    if (b.garantieMonate <= 0) continue;
    final tage = nurTag(b.garantieEnde).difference(jetzt).inDays;
    if (tage < 0 || tage > 60) continue;
    liste.add(Faelligkeit(FaelligArt.garantie, b.garantieEnde, b.haendler.isEmpty ? 'Beleg' : b.haendler,
        'Garantie endet – Mängel jetzt noch melden', b.id));
  }
  for (final t in termine) {
    if (t.erledigt) continue;
    liste.add(Faelligkeit(FaelligArt.termin, naechstesTermindatum(t, heute: jetzt), t.titel,
        t.notiz.isEmpty ? t.art : t.notiz, t.id));
  }
  liste.sort((a, b) => a.datum.compareTo(b.datum));
  return liste;
}

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

// ---------------------------------------------------------------- Push-Erinnerungen

class Erinnerung {
  Erinnerung(this.id, this.zeit, this.titel, this.text, this.refId);

  final int id;
  final DateTime zeit;
  final String titel;
  final String text;
  final String refId;
}

/// Stabile Zahl aus einem Text (für Benachrichtigungs-Ids).
int stabileId(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h == 0 ? 1 : h;
}

/// Plant Erinnerungen vor jeder Fälligkeit. Nur Zeitpunkte in der Zukunft,
/// höchstens [max] Stück, die frühesten zuerst.
List<Erinnerung> erinnerungenPlanen(List<Faelligkeit> f, ErinnerungsEinstellungen e,
    {required DateTime jetzt, int max = 60}) {
  if (!e.aktiv) return [];
  final out = <Erinnerung>[];
  for (final x in f) {
    final tage = x.art == FaelligArt.nachfassen ? [0] : e.tageVorher;
    for (final t in tage) {
      final tag = nurTag(x.datum).subtract(Duration(days: t));
      final zeit = DateTime(tag.year, tag.month, tag.day, e.stunde);
      if (!zeit.isAfter(jetzt)) continue;
      final wann = switch (t) { 0 => 'Heute', 1 => 'Morgen', _ => 'In $t Tagen' };
      final titel = switch (x.art) {
        FaelligArt.nachfassen => 'Nachfassen: ${x.titel}',
        FaelligArt.vertrag => '$wann letzte Chance zum Kündigen: ${x.titel}',
        FaelligArt.garantie => '$wann endet die Garantie: ${x.titel}',
        FaelligArt.termin => '$wann Termin: ${x.titel}',
        FaelligArt.brief => '$wann fällig: ${x.titel}',
      };
      out.add(Erinnerung(stabileId('${x.art.name}:${x.refId}:$t'), zeit, titel,
          x.unsicher ? '${x.text} (Frist bitte im Brief prüfen)' : x.text, x.refId));
    }
  }
  out.sort((a, b) => a.zeit.compareTo(b.zeit));
  return out.take(max).toList();
}

/// Kurzer Text für den Wochenüberblick.
String wochenText(List<Faelligkeit> f, {required DateTime heute}) {
  final ende = nurTag(heute).add(const Duration(days: 7));
  final woche = f.where((x) => !x.datum.isAfter(ende)).toList();
  if (woche.isEmpty) return 'Diese Woche ist nichts fällig. Der Tiger passt weiter auf.';
  final ueber = woche.where((x) => nurTag(x.datum).isBefore(nurTag(heute))).length;
  return '${woche.length} ${woche.length == 1 ? 'Sache' : 'Sachen'} in den nächsten 7 Tagen'
      '${ueber > 0 ? ', davon $ueber überfällig' : ''}. Tippe für den Überblick.';
}

// ---------------------------------------------------------------- Termine in Briefen

class GefundenerTermin {
  GefundenerTermin(this.zeit, this.ausschnitt);

  final DateTime zeit;
  final String ausschnitt;
}

final _terminRe = RegExp(
    r'(\d{1,2})\.(\d{1,2})\.(\d{4})\s*,?\s*(?:um\s*)?(\d{1,2})[:.](\d{2})\s*uhr',
    caseSensitive: false);
const _terminWoerter = ['termin', 'einladung', 'eingeladen', 'vorsprache', 'erscheinen', 'gespräch', 'besuch'];

/// Findet Termine mit Uhrzeit, z. B. „Termin am 12.11.2026 um 10:00 Uhr“.
List<GefundenerTermin> termineFinden(String text) {
  final lower = text.toLowerCase();
  final out = <GefundenerTermin>[];
  for (final m in _terminRe.allMatches(text)) {
    final von = m.start - 120 < 0 ? 0 : m.start - 120;
    if (!_terminWoerter.any(lower.substring(von, m.start).contains)) continue;
    final tag = int.parse(m.group(1)!), monat = int.parse(m.group(2)!), jahr = int.parse(m.group(3)!);
    final std = int.parse(m.group(4)!), min = int.parse(m.group(5)!);
    if (monat < 1 || monat > 12 || tag < 1 || tag > 31 || std > 23 || min > 59) continue;
    final ende = m.end + 60 > text.length ? text.length : m.end + 60;
    out.add(GefundenerTermin(DateTime(jahr, monat, tag, std, min),
        text.substring(von, ende).replaceAll('\n', ' ').trim()));
  }
  return out;
}

// ---------------------------------------------------------------- Kalender (ICS)

String _ics(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

String _icsZeit(DateTime d) =>
    '${_ics(d)}T${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}00';

String _escape(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\n', '\\n');

/// Kalendereintrag zum Teilen in jede Kalender-App. Ohne Uhrzeit = ganztägig.
String icsErstellen(String titel, DateTime start,
    {bool ganztags = true, String beschreibung = '', int erinnerungTage = 1, DateTime? jetzt}) {
  final stempel = (jetzt ?? DateTime.now()).toUtc();
  final z = StringBuffer()
    ..write('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Papiertiger//DE\r\nBEGIN:VEVENT\r\n')
    ..write('UID:${stabileId('$titel${start.toIso8601String()}')}@papiertiger\r\n')
    ..write('DTSTAMP:${_icsZeit(stempel)}Z\r\n');
  if (ganztags) {
    z
      ..write('DTSTART;VALUE=DATE:${_ics(start)}\r\n')
      ..write('DTEND;VALUE=DATE:${_ics(start.add(const Duration(days: 1)))}\r\n');
  } else {
    z
      ..write('DTSTART:${_icsZeit(start)}\r\n')
      ..write('DTEND:${_icsZeit(start.add(const Duration(hours: 1)))}\r\n');
  }
  z
    ..write('SUMMARY:${_escape(titel)}\r\n')
    ..write('DESCRIPTION:${_escape(beschreibung)}\r\n')
    ..write('BEGIN:VALARM\r\nACTION:DISPLAY\r\nDESCRIPTION:${_escape(titel)}\r\n')
    ..write('TRIGGER:-P${erinnerungTage}D\r\nEND:VALARM\r\n')
    ..write('END:VEVENT\r\nEND:VCALENDAR\r\n');
  return z.toString();
}
