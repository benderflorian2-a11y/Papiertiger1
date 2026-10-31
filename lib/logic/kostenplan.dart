/// Kostenplan eines Monats für den Finanz-Kreis: was ansteht, in festen Gruppen.
library;

import '../data/models.dart';
import 'finanzen.dart';
import 'datum.dart';

/// Feste Gruppen in fester Reihenfolge – jede Gruppe behält immer ihre Farbe.
const kostenGruppen = <(String, List<String>)>[
  ('Wohnen & Energie', ['Wohnen']),
  ('Rechnungen & Bescheide', ['Rechnungen & Bescheide']),
  ('Versicherungen', ['Versicherungen']),
  ('Einkauf & Haushalt', ['Lebensmittel', 'Drogerie', 'Haushalt']),
  ('Freizeit & Abos', ['Freizeit', 'Elektronik', 'Kleidung']),
  ('Weitere', ['Mobilität', 'Gesundheit', 'Sonstiges']),
];

class KostenGruppe {
  KostenGruppe(this.index, this.name, this.betrag, this.teile);

  /// Position in [kostenGruppen] – bestimmt die Farbe.
  final int index;
  final String name;
  final double betrag;

  /// Einzelposten: (Bezeichnung, Betrag), größte zuerst.
  final List<(String, double)> teile;
}

class Kostenplan {
  Kostenplan(this.gruppen, this.demnaechst);

  /// Nur Gruppen mit Betrag > 0, in fester Reihenfolge.
  final List<KostenGruppe> gruppen;

  /// Offene Zahlungen mit Frist, die bald anstehen (auch überfällige), nach Datum.
  final List<Brief> demnaechst;

  double get gesamt => gruppen.fold(0.0, (s, g) => s + g.betrag);
}

String _gruppeVon(String kategorie) {
  for (final (name, kats) in kostenGruppen) {
    if (kats.contains(kategorie)) return name;
  }
  return 'Weitere';
}

double _r(double x) => (x * 100).round() / 100;

/// Kosten im Monat: Verträge (pro Monat), Belege des Monats und offene Zahlungen mit Frist bis Monatsende.
Kostenplan kostenplan({
  required List<Brief> briefe,
  required List<Vertrag> vertraege,
  required List<Beleg> belege,
  required DateTime monat,
  DateTime? heute,
}) {
  final h = nurTag(heute ?? DateTime.now());
  final monatsEnde = DateTime(monat.year, monat.month + 1, 0);
  final teile = <String, Map<String, double>>{};
  void dazu(String gruppe, String posten, double betrag) {
    final m = teile.putIfAbsent(gruppe, () => {});
    m[posten] = (m[posten] ?? 0) + betrag;
  }

  for (final v in vertraege) {
    if (v.gekuendigt || v.kostenMonat == null || v.kostenMonat! <= 0) continue;
    dazu(_gruppeVon(vertragKategorie(v)), v.anbieter, v.kostenMonat!);
  }
  for (final b in belege) {
    if (b.datum.year != monat.year || b.datum.month != monat.month || b.betrag == null) continue;
    dazu(_gruppeVon(belegKategorie(b)), b.haendler, b.betrag!);
  }
  // Offene Zahlungen: im aktuellen Monat inklusive überfälliger, in anderen Monaten nur die mit Frist dort
  final aktuell = monat.year == h.year && monat.month == h.month;
  for (final b in offeneZahlungen(briefe)) {
    final f = b.frist;
    if (f == null) continue;
    final imMonat = f.year == monat.year && f.month == monat.month;
    if (imMonat || (aktuell && !nurTag(f).isAfter(monatsEnde))) {
      dazu('Rechnungen & Bescheide', b.absenderName ?? b.titel ?? 'Zahlung', b.betrag!);
    }
  }

  final gruppen = <KostenGruppe>[];
  for (var i = 0; i < kostenGruppen.length; i++) {
    final name = kostenGruppen[i].$1;
    final m = teile[name];
    if (m == null) continue;
    final liste = [for (final e in m.entries) (e.key, _r(e.value))]..sort((a, b) => b.$2.compareTo(a.$2));
    final summe = _r(liste.fold(0.0, (s, e) => s + e.$2));
    if (summe > 0) gruppen.add(KostenGruppe(i, name, summe, liste));
  }

  final bald = h.add(const Duration(days: 30));
  final demnaechst = offeneZahlungen(briefe).where((b) => b.frist != null && !nurTag(b.frist!).isAfter(bald)).toList()
    ..sort((a, b) => a.frist!.compareTo(b.frist!));
  return Kostenplan(gruppen, demnaechst);
}
