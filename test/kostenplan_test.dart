import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/kostenplan.dart';

void main() {
  test('Kostenplan in festen Gruppen', () {
    final heute = DateTime(2026, 10, 31);
    Brief b(String id, double betrag, DateTime? frist, {String? von}) => Brief(
        id: id,
        erstellt: DateTime(2026, 10, 1),
        kategorie: 'finanzamt',
        typ: 'bescheid',
        text: '',
        erklaerung: '',
        betrag: betrag,
        frist: frist,
        absenderName: von);
    final p = kostenplan(
      briefe: [
        b('1', 1234.56, DateTime(2026, 11, 15), von: 'Finanzamt'),
        b('2', 80, DateTime(2026, 10, 20), von: 'Stadtwerke'),
        b('3', 50, null),
      ],
      vertraege: [
        Vertrag(id: 'v1', anbieter: 'Stadtwerke', art: 'Strom', beginn: DateTime(2025), kostenMonat: 85),
        Vertrag(id: 'v2', anbieter: 'Haftpflicht AG', art: 'Versicherung', beginn: DateTime(2025), kostenMonat: 6.5),
        Vertrag(id: 'v3', anbieter: 'Netflix', art: 'Streaming', beginn: DateTime(2025), kostenMonat: 13.99, gekuendigt: true),
      ],
      belege: [
        Beleg(id: 'x', haendler: 'REWE Markt', datum: DateTime(2026, 10, 3), betrag: 42.1),
        Beleg(id: 'y', haendler: 'Aral', datum: DateTime(2026, 10, 9), betrag: 60),
        Beleg(id: 'z', haendler: 'REWE', datum: DateTime(2026, 9, 3), betrag: 99),
      ],
      monat: DateTime(2026, 10),
      heute: heute,
    );
    expect(p.gruppen.map((g) => g.name), ['Wohnen & Energie', 'Rechnungen & Bescheide', 'Versicherungen', 'Einkauf & Haushalt', 'Weitere']);
    expect(p.gruppen.map((g) => g.index), [0, 1, 2, 3, 5]);
    expect(p.gruppen[1].betrag, 80); // nur die Zahlung mit Frist im Oktober
    expect(p.gesamt, closeTo(85 + 80 + 6.5 + 42.1 + 60, 0.001));
    expect(p.demnaechst.map((x) => x.id), ['2', '1']);

    final nov = kostenplan(briefe: [b('1', 1234.56, DateTime(2026, 11, 15))], vertraege: [], belege: [], monat: DateTime(2026, 11), heute: heute);
    expect(nov.gruppen.single.betrag, 1234.56);
    expect(kostenplan(briefe: [], vertraege: [], belege: [], monat: DateTime(2026, 10), heute: heute).gruppen, isEmpty);
  });
}
