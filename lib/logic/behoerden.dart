/// Behörden: Widerspruchs- und Einspruchsfristen aus Bescheiden.
/// Reines Dart, damit es testbar ist. Ergebnisse sind immer „bitte prüfen“.
library;

import 'datum.dart';

/// Ostersonntag (Gaußsche Osterformel, gregorianisch).
DateTime ostersonntag(int jahr) {
  final a = jahr % 19, b = jahr ~/ 100, c = jahr % 100;
  final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final monat = (h + l - 7 * m + 114) ~/ 31;
  final tag = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(jahr, monat, tag);
}

/// Bundesweite gesetzliche Feiertage. Landesfeiertage sind nicht enthalten.
Set<DateTime> feiertage(int jahr) {
  final o = ostersonntag(jahr);
  DateTime plus(int t) => DateTime(o.year, o.month, o.day + t);
  return {
    DateTime(jahr, 1, 1),
    plus(-2), // Karfreitag
    plus(1), // Ostermontag
    DateTime(jahr, 5, 1),
    plus(39), // Christi Himmelfahrt
    plus(50), // Pfingstmontag
    DateTime(jahr, 10, 3),
    DateTime(jahr, 12, 25),
    DateTime(jahr, 12, 26),
  };
}

bool istWerktag(DateTime d) {
  final t = nurTag(d);
  return t.weekday != DateTime.saturday && t.weekday != DateTime.sunday && !feiertage(t.year).contains(t);
}

/// Fällt eine Frist auf Samstag, Sonntag oder Feiertag, endet sie am nächsten Werktag.
DateTime naechsterWerktag(DateTime d) {
  var t = nurTag(d);
  while (!istWerktag(t)) {
    t = DateTime(t.year, t.month, t.day + 1);
  }
  return t;
}

/// Tage, nach denen ein per Post verschickter Bescheid als bekannt gegeben gilt
/// (seit 2025 vier Tage nach Aufgabe zur Post, vorher drei).
int bekanntgabeTage(DateTime briefDatum) => briefDatum.isBefore(DateTime(2025, 1, 1)) ? 3 : 4;

class Rechtsbehelf {
  Rechtsbehelf({required this.art, required this.quelle, this.bekanntgabe, this.fristEnde, this.verschoben = false});

  /// Widerspruch, Einspruch oder Klage.
  final String art;

  /// Der Satz aus dem Brief, auf dem die Frist beruht.
  final String quelle;

  /// Angenommene Bekanntgabe (Briefdatum + 4 Tage), null ohne Briefdatum.
  final DateTime? bekanntgabe;
  final DateTime? fristEnde;

  /// Wurde das Ende auf den nächsten Werktag verschoben?
  final bool verschoben;
}

final _monatsfrist = RegExp(
    r'[^.\n]*(?:innerhalb|binnen)\s+(?:eines|einem|1)\s+monats?\b[^.]*\.?',
    caseSensitive: false);

/// Sucht die Rechtsbehelfsbelehrung („innerhalb eines Monats nach Bekanntgabe …
/// Widerspruch/Einspruch/Klage“) und rechnet das Fristende ungefähr aus.
Rechtsbehelf? rechtsbehelfFinden(String text, {DateTime? briefDatum, DateTime? zugang}) {
  for (final m in _monatsfrist.allMatches(text)) {
    final satz = m.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = satz.toLowerCase();
    final art = lower.contains('einspruch')
        ? 'Einspruch'
        : lower.contains('widerspruch')
            ? 'Widerspruch'
            : lower.contains('klage')
                ? 'Klage'
                : null;
    if (art == null) continue;
    // Bekanntgabe: Briefdatum + 4 Tage; kam der Brief nachweislich später an, zählt der Zugang.
    DateTime? bekanntgabe;
    if (briefDatum != null) {
      final d = nurTag(briefDatum);
      bekanntgabe = DateTime(d.year, d.month, d.day + bekanntgabeTage(d));
    }
    if (zugang != null && (bekanntgabe == null || nurTag(zugang).isAfter(bekanntgabe))) {
      bekanntgabe = nurTag(zugang);
    }
    if (bekanntgabe == null) return Rechtsbehelf(art: art, quelle: satz);
    final roh = plusMonate(bekanntgabe, 1);
    final ende = naechsterWerktag(roh);
    return Rechtsbehelf(
        art: art, quelle: satz, bekanntgabe: bekanntgabe, fristEnde: ende, verschoben: ende != roh);
  }
  return null;
}
