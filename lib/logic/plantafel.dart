/// Plantafel: wer ist wann auf welcher Baustelle, wer ist abwesend, wo gibt es Doppelbelegungen.
library;

import '../data/geschaeft.dart';

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

bool _enthaelt(Einsatz e, DateTime tag) {
  final t = _tag(tag);
  return !t.isBefore(_tag(e.von)) && !t.isAfter(_tag(e.bis));
}

/// Montag der Woche von [d].
DateTime wochenAnfang(DateTime d) => _tag(d).subtract(Duration(days: d.weekday - 1));

/// Alle Einsätze an einem Tag (ohne Wochenende-Sonderbehandlung).
List<Einsatz> einsaetzeAm(List<Einsatz> l, DateTime tag) => l.where((e) => _enthaelt(e, tag)).toList();

/// Einsatz einer Person an einem Tag (Abwesenheit hat Vorrang).
Einsatz? einsatzVon(List<Einsatz> l, String person, DateTime tag) {
  final x = einsaetzeAm(l, tag).where((e) => e.personen.contains(person)).toList()
    ..sort((a, b) => (a.art == 'Projekt' ? 1 : 0).compareTo(b.art == 'Projekt' ? 1 : 0));
  return x.firstOrNull;
}

/// Doppelt verplant: Person an einem Tag in zwei Einsätzen (oder auf Baustelle trotz Abwesenheit).
List<(String, DateTime, Einsatz, Einsatz)> konflikte(List<Einsatz> l, {required DateTime von, required DateTime bis}) {
  final out = <(String, DateTime, Einsatz, Einsatz)>[];
  for (var t = _tag(von); !t.isAfter(_tag(bis)); t = DateTime(t.year, t.month, t.day + 1)) {
    if (t.weekday > 5) continue;
    final heute = einsaetzeAm(l, t);
    final personen = {for (final e in heute) ...e.personen};
    for (final p in personen) {
      final mit = heute.where((e) => e.personen.contains(p)).toList();
      if (mit.length > 1) out.add((p, t, mit[0], mit[1]));
    }
  }
  return out;
}

/// Wer an einem Werktag noch frei ist.
List<String> freiAm(List<String> mitarbeiter, List<Einsatz> l, DateTime tag) =>
    mitarbeiter.where((m) => einsatzVon(l, m, tag) == null).toList();

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

/// Wochenplan als Text, z. B. für die WhatsApp-Gruppe des Teams.
String wochenplanText(List<String> mitarbeiter, List<Einsatz> l, Map<String, String> projektNamen, DateTime woche) {
  final mo = wochenAnfang(woche);
  final z = StringBuffer('Wochenplan ${_d(mo)} – ${_d(mo.add(const Duration(days: 4)))}\n');
  for (var i = 0; i < 5; i++) {
    final t = mo.add(Duration(days: i));
    z.write('\n${_wochentage[i]} ${_d(t)}\n');
    final heute = einsaetzeAm(l, t);
    if (heute.isEmpty) z.write('  –\n');
    for (final e in heute) {
      final ziel = e.art == 'Projekt' ? (projektNamen[e.projektId] ?? 'Projekt') : e.art;
      z.write('  $ziel: ${e.personen.join(', ')}${e.notiz.isEmpty ? '' : ' (${e.notiz})'}\n');
    }
    final frei = freiAm(mitarbeiter, l, t);
    if (frei.isNotEmpty && heute.isNotEmpty) z.write('  frei: ${frei.join(', ')}\n');
  }
  return z.toString();
}
