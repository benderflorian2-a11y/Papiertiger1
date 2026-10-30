/// Stempeluhr, Pausen nach Arbeitszeitgesetz und Stundenliste für die Lohnabrechnung.
/// Allgemeine Hinweise, keine Rechtsberatung.
library;

import '../data/geschaeft.dart';

double _rund(double x) => (x * 100).round() / 100;
String _zwei(int x) => x.toString().padLeft(2, '0');
String _uhr(DateTime d) => '${_zwei(d.hour)}:${_zwei(d.minute)}';
String _d(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.${d.year}';
String _h(double h) => h.toStringAsFixed(2).replaceAll('.', ',');

/// Pause starten bzw. beenden.
void pauseUmschalten(Stempel s, DateTime jetzt) {
  if (s.pauseSeit == null) {
    s.pauseSeit = jetzt;
  } else {
    s.pauseMinuten += jetzt.difference(s.pauseSeit!).inMinutes;
    s.pauseSeit = null;
  }
}

/// Bisherige Arbeitszeit in Minuten (ohne Pausen).
int laufendeMinuten(Stempel s, DateTime jetzt) {
  final pause = s.pauseMinuten + (s.pauseSeit == null ? 0 : jetzt.difference(s.pauseSeit!).inMinutes);
  final m = jetzt.difference(s.start).inMinutes - pause;
  return m < 0 ? 0 : m;
}

/// Stempeluhr anhalten: ergibt einen Zeiteintrag für das Projekt.
Zeiteintrag stempelBeenden(Stempel s, DateTime ende, {String text = ''}) {
  if (s.pauseSeit != null) pauseUmschalten(s, ende);
  return Zeiteintrag(
    datum: DateTime(s.start.year, s.start.month, s.start.day),
    stunden: _rund(laufendeMinuten(s, ende) / 60),
    person: s.person,
    text: text.isNotEmpty ? text : (s.fahrt ? 'Fahrtzeit' : ''),
    beginn: s.start,
    ende: ende,
    pauseMinuten: s.pauseMinuten,
    fahrt: s.fahrt,
  );
}

/// Arbeitsstunden und Pausenminuten einer Person an einem Tag, über alle Projekte.
(double, int) tagesZeit(List<Projekt> projekte, String person, DateTime tag) {
  var h = 0.0, pause = 0;
  for (final p in projekte) {
    for (final z in p.zeiten) {
      if (z.person != person || z.datum.year != tag.year || z.datum.month != tag.month || z.datum.day != tag.day) continue;
      h += z.stunden;
      pause += z.pauseMinuten;
    }
  }
  return (_rund(h), pause);
}

/// Hinweise nach §§ 3, 4 Arbeitszeitgesetz (für Angestellte).
List<String> arbeitszeitHinweise(double stunden, int pauseMinuten) => [
      if (stunden > 10) 'Mehr als 10 Stunden Arbeit am Tag sind nicht erlaubt (§ 3 ArbZG).',
      if (stunden > 9 && pauseMinuten < 45)
        'Bei mehr als 9 Stunden Arbeit sind 45 Minuten Pause vorgeschrieben (§ 4 ArbZG).'
      else if (stunden > 6 && pauseMinuten < 30)
        'Bei mehr als 6 Stunden Arbeit sind 30 Minuten Pause vorgeschrieben (§ 4 ArbZG).',
    ];

/// Stundenliste eines Monats als Tabelle (CSV) mit Summen je Person – für die Lohnabrechnung.
String stundenliste(List<Projekt> projekte, {required int jahr, required int monat}) {
  final zeilen = <(String, Zeiteintrag, String)>[];
  for (final p in projekte) {
    for (final z in p.zeiten) {
      if (z.datum.year == jahr && z.datum.month == monat) zeilen.add((z.person.isEmpty ? 'ohne Namen' : z.person, z, p.name));
    }
  }
  zeilen.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.datum.compareTo(b.$2.datum));
  final b = StringBuffer('﻿Person;Datum;Projekt;Beginn;Ende;Pause (Min.);Stunden;Art;Tätigkeit\n');
  final summen = <String, (double, double)>{};
  for (final (person, z, projekt) in zeilen) {
    b.writeln('$person;${_d(z.datum)};"${projekt.replaceAll('"', "'")}";${z.beginn == null ? '' : _uhr(z.beginn!)};'
        '${z.ende == null ? '' : _uhr(z.ende!)};${z.pauseMinuten == 0 ? '' : z.pauseMinuten};${_h(z.stunden)};'
        '${z.fahrt ? 'Fahrt' : 'Arbeit'};"${z.text.replaceAll('"', "'")}"');
    final s = summen[person] ?? (0.0, 0.0);
    summen[person] = z.fahrt ? (s.$1, s.$2 + z.stunden) : (s.$1 + z.stunden, s.$2);
  }
  b.writeln();
  b.writeln('Summe;;;;;;Arbeit;Fahrt;');
  for (final e in summen.entries) {
    b.writeln('${e.key};;;;;;${_h(e.value.$1)};${_h(e.value.$2)};');
  }
  return b.toString();
}

/// Erinnerungen für laufende Stempeluhren: nach 6 Stunden ohne Pause, nach 10 Stunden „noch eingestempelt?“.
List<(int, DateTime, String, String)> stempelErinnerungen(List<Stempel> laufend, DateTime jetzt) {
  final out = <(int, DateTime, String, String)>[];
  for (var i = 0; i < laufend.length; i++) {
    final s = laufend[i];
    final sechs = s.start.add(Duration(hours: 6, minutes: s.pauseMinuten));
    if (s.pauseMinuten < 30 && sechs.isAfter(jetzt)) {
      out.add((900000 + i * 2, sechs, 'Pause für ${s.person}?', 'Nach 6 Stunden Arbeit sind 30 Minuten Pause vorgeschrieben.'));
    }
    final zehn = s.start.add(Duration(hours: 10, minutes: s.pauseMinuten));
    if (zehn.isAfter(jetzt)) {
      out.add((900001 + i * 2, zehn, '${s.person} noch eingestempelt?', 'Die Stempeluhr läuft seit 10 Stunden – Feierabend vergessen?'));
    }
  }
  return out;
}
