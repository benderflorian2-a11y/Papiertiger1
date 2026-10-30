/// Kinder (Vorsorgeuntersuchungen, Kindergeld) und Vorsorgemappe. Allgemeine Hinweise, keine Beratung.
library;

import '../data/familie.dart';
import '../data/models.dart';

DateTime _plusMonate(DateTime d, int m) => DateTime(d.year, d.month + m, d.day);
String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

class Untersuchung {
  const Untersuchung(this.name, this.zeitraum, this.von, this.bis);

  final String name;

  /// So wie im gelben Kinder-Untersuchungsheft.
  final String zeitraum;

  /// Fenster ab Geburt.
  final Duration Function(DateTime geburt) von;
  final Duration Function(DateTime geburt) bis;
}

Duration Function(DateTime) _tage(int t) => (_) => Duration(days: t);
Duration Function(DateTime) _monate(int m) => (g) => _plusMonate(g, m).difference(g);

/// Vorsorgeuntersuchungen für Kinder (Kinder-Richtlinie des G-BA).
final uUntersuchungen = <Untersuchung>[
  Untersuchung('U2', '3.–10. Lebenstag', _tage(2), _tage(10)),
  Untersuchung('U3', '4.–5. Lebenswoche', _tage(21), _tage(35)),
  Untersuchung('U4', '3.–4. Lebensmonat', _monate(2), _monate(4)),
  Untersuchung('U5', '6.–7. Lebensmonat', _monate(5), _monate(7)),
  Untersuchung('U6', '10.–12. Lebensmonat', _monate(9), _monate(12)),
  Untersuchung('U7', '21.–24. Lebensmonat', _monate(20), _monate(24)),
  Untersuchung('U7a', '34.–36. Lebensmonat', _monate(33), _monate(36)),
  Untersuchung('U8', '46.–48. Lebensmonat', _monate(45), _monate(48)),
  Untersuchung('U9', '60.–64. Lebensmonat', _monate(59), _monate(64)),
  Untersuchung('J1', '12–14 Jahre', _monate(144), _monate(180)),
];

/// Nächste offene Untersuchung (Name, ab, bis) – verpasste werden übersprungen.
(String, DateTime, DateTime)? naechsteUntersuchung(Kind k, {required DateTime heute}) {
  if (k.geburt == null) return null;
  final g = k.geburt!;
  for (final u in uUntersuchungen) {
    if (k.erledigt.contains(u.name)) continue;
    final bis = g.add(u.bis(g));
    if (bis.isBefore(heute)) continue;
    return (u.name, g.add(u.von(g)), bis);
  }
  return null;
}

int alterInJahren(DateTime geburt, DateTime heute) {
  var a = heute.year - geburt.year;
  if (heute.month < geburt.month || (heute.month == geburt.month && heute.day < geburt.day)) a--;
  return a;
}

/// Hinweise je Kind (Kindergeld ab 18, Untersuchung fällig).
List<String> kindHinweise(Kind k, {required DateTime heute}) {
  final out = <String>[];
  if (k.geburt == null) return out;
  final achtzehn = DateTime(k.geburt!.year + 18, k.geburt!.month, k.geburt!.day);
  if (!achtzehn.isBefore(heute) && achtzehn.difference(heute).inDays <= 90) {
    out.add('${k.name} wird am ${_d(achtzehn)} 18: Kindergeld gibt es danach nur bei Ausbildung, Studium oder '
        'Freiwilligendienst (meist bis 25) – Nachweis an die Familienkasse schicken.');
  }
  final u = naechsteUntersuchung(k, heute: heute);
  if (u != null && !u.$2.isAfter(heute.add(const Duration(days: 30)))) {
    out.add('${u.$1} für ${k.name}: zwischen ${_d(u.$2)} und ${_d(u.$3)} beim Kinderarzt.');
  }
  return out;
}

// ---------------------------------------------------------------- Vorsorgemappe

const vorsorgeDokumente = [
  'Patientenverfügung',
  'Vorsorgevollmacht',
  'Betreuungsverfügung',
  'Bankvollmacht',
  'Testament',
  'Organspendeausweis',
  'Rentenunterlagen',
  'Versicherungen',
  'Mietvertrag bzw. Grundbuch',
];

/// Wie vollständig die Mappe ist (0 … 1).
double vorsorgeStand(Vorsorge v) {
  final teile = [
    v.kontakte.isNotEmpty,
    v.hausarzt.isNotEmpty,
    for (final d in vorsorgeDokumente.take(3)) (v.ablage[d] ?? '').isNotEmpty,
  ];
  return teile.where((x) => x).length / teile.length;
}

/// Notfallblatt für Angehörige als Text (auch als PDF).
String notfallblattText(Vorsorge v, Profil p) {
  final z = StringBuffer('Notfallblatt ${p.name}\n${p.adresse.replaceAll('\n', ', ')}\n');
  if (v.kontakte.isNotEmpty) {
    z.write('\nIm Notfall bitte benachrichtigen:\n');
    for (final k in v.kontakte) {
      z.write('- ${k.name}${k.beziehung.isEmpty ? '' : ' (${k.beziehung})'}${k.telefon.isEmpty ? '' : ': ${k.telefon}'}\n');
    }
  }
  if (v.hausarzt.isNotEmpty) z.write('\nHausarzt: ${v.hausarzt}\n');
  if (v.medikamente.isNotEmpty) z.write('\nMedikamente: ${v.medikamente}\n');
  if (v.allergien.isNotEmpty) z.write('Allergien: ${v.allergien}\n');
  final da = vorsorgeDokumente.where((d) => (v.ablage[d] ?? '').isNotEmpty).toList();
  if (da.isNotEmpty) {
    z.write('\nWichtige Dokumente:\n');
    for (final d in da) {
      z.write('- $d: ${v.ablage[d]}\n');
    }
  }
  if (v.hinweise.isNotEmpty) z.write('\nWeitere Hinweise:\n${v.hinweise}\n');
  return z.toString();
}
