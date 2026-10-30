import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/datev.dart';
import 'package:papiertiger/logic/plantafel.dart';
import 'package:papiertiger/logic/projekte.dart';
import 'package:papiertiger/logic/rechnungen.dart';

void main() {
  final mo = DateTime(2026, 11, 2); // Montag
  List<Einsatz> plan() => [
        Einsatz(id: '1', von: mo, bis: DateTime(2026, 11, 4), personen: ['Anna', 'Ben'], projektId: 'p1'),
        Einsatz(id: '2', von: DateTime(2026, 11, 4), bis: DateTime(2026, 11, 6), personen: ['Ben'], art: 'Urlaub'),
        Einsatz(id: '3', von: DateTime(2026, 11, 5), bis: DateTime(2026, 11, 5), personen: ['Anna'], projektId: 'p2', notiz: '7 Uhr'),
      ];

  test('Wochenanfang und Belegung', () {
    expect(wochenAnfang(DateTime(2026, 11, 5, 14)), mo);
    expect(einsaetzeAm(plan(), DateTime(2026, 11, 3)).single.id, '1');
    // Abwesenheit hat Vorrang vor dem Projekt
    expect(einsatzVon(plan(), 'Ben', DateTime(2026, 11, 4))!.art, 'Urlaub');
    expect(einsatzVon(plan(), 'Anna', DateTime(2026, 11, 6)), isNull);
    expect(freiAm(['Anna', 'Ben', 'Cem'], plan(), DateTime(2026, 11, 5)), ['Cem']);
  });

  test('Doppelt verplant wird erkannt', () {
    final k = konflikte(plan(), von: mo, bis: DateTime(2026, 11, 6));
    expect(k.length, 1);
    expect(k.single.$1, 'Ben');
    expect(k.single.$2, DateTime(2026, 11, 4));
  });

  test('Wochenplan als Text', () {
    final t = wochenplanText(['Anna', 'Ben', 'Cem'], plan(), {'p1': 'Bad Meier', 'p2': 'Dach Huber'}, mo);
    expect(t, startsWith('Wochenplan 02.11. – 06.11.'));
    expect(t, contains('Mo 02.11.\n  Bad Meier: Anna, Ben\n  frei: Cem'));
    expect(t, contains('Dach Huber: Anna (7 Uhr)'));
    expect(t, contains('Urlaub: Ben'));
    expect(Einsatz.fromJson(plan()[2].toJson()).notiz, '7 Uhr');
  });

  test('Eingangsrechnungen fließen in die Nachkalkulation', () {
    final p = Projekt(id: 'p1', name: 'Bad', stundensatz: 50, zeiten: [Zeiteintrag(datum: mo, stunden: 2)]);
    final belege = [
      Beleg(id: 'b', haendler: 'Großhandel', datum: mo, betrag: 119, geschaeftlich: true, projektId: 'p1'),
      Beleg(id: 'c', haendler: 'Anderes', datum: mo, betrag: 50, geschaeftlich: true),
    ];
    final nk = nachkalkulation(p, const [], belege: belege, kleinunternehmer: false);
    expect(nk.eingang, 100);
    expect(nk.kosten, 200);
    expect(nachkalkulation(p, const [], belege: belege).eingang, 119);
  });

  test('DATEV-Buchungsliste mit SKR03-Konten', () {
    final r = Rechnung(id: 'r', art: 'rechnung', nummer: '2026-001', kundeId: 'k', datum: DateTime(2026, 3, 1),
        bezahltAm: DateTime(2026, 3, 10), positionen: [Position(text: 'Arbeit', preis: 100), Position(text: 'Buch', preis: 100, ustSatz: 7)]);
    final offen = Rechnung(id: 'o', art: 'rechnung', nummer: '2026-002', kundeId: 'k', datum: DateTime(2026, 3, 1),
        positionen: [Position(text: 'X', preis: 10)]);
    final b = Beleg(id: 'b', haendler: 'Baumarkt; Filiale "Nord"', datum: DateTime(2026, 3, 5), betrag: 59.5,
        geschaeftlich: true, kategorie: 'Wareneinkauf und Material');
    final csv = datevBuchungsliste(z: Zeitraum.jahr(2026), rechnungen: [r, offen], belege: [b], kleinunternehmer: false);
    final zeilen = csv.trim().split('\n');
    expect(zeilen.first, startsWith('Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen'));
    expect(zeilen, contains('119,00;S;EUR;1200;8400;1003;2026-001;"Rechnung 2026-001"'));
    expect(zeilen, contains('107,00;S;EUR;1200;8300;1003;2026-001;"Rechnung 2026-001"'));
    expect(zeilen, contains('59,50;S;EUR;3400;1200;0503;;"Baumarkt, Filiale \'Nord\'"'));
    expect(csv, isNot(contains('2026-002')));
    expect(erloesKonto(19, kleinunternehmer: true), 8195);
  });
}
