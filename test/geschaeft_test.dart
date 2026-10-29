import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/marketing.dart';
import 'package:papiertiger/logic/rechnungen.dart';
import 'package:papiertiger/logic/zeitplan.dart';

Rechnung _r(String id, String nummer,
        {String art = 'rechnung', String kunde = 'k1', DateTime? datum, DateTime? bezahlt, List<Position>? pos}) =>
    Rechnung(
      id: id,
      art: art,
      nummer: nummer,
      kundeId: kunde,
      datum: datum ?? DateTime(2026, 10, 20),
      bezahltAm: bezahlt,
      positionen: pos ?? [Position(text: 'Leistung', preis: 100)],
    );

void main() {
  test('Summen mit 19 und 7 Prozent, Kleinunternehmer ohne USt', () {
    final r = _r('1', '2026-001', pos: [
      Position(text: 'Beratung', menge: 2, einheit: 'Std.', preis: 100),
      Position(text: 'Buch', preis: 20, ustSatz: 7),
    ]);
    final s = summenVon(r, kleinunternehmer: false);
    expect(s.netto, 220);
    expect(s.ust, {19: 38.0, 7: 1.4});
    expect(s.brutto, closeTo(259.4, 0.001));
    final k = summenVon(r, kleinunternehmer: true);
    expect(k.ust, isEmpty);
    expect(k.brutto, 220);
  });

  test('Fortlaufende Nummern je Jahr und Art', () {
    final alle = [
      _r('a', '2026-001'),
      _r('b', '2026-007'),
      _r('c', 'A-2026-002', art: 'angebot'),
      _r('d', '2025-010'),
    ];
    expect(naechsteNummer(alle, art: 'rechnung', jahr: 2026), '2026-008');
    expect(naechsteNummer(alle, art: 'angebot', jahr: 2026), 'A-2026-003');
    expect(naechsteNummer(alle, art: 'rechnung', jahr: 2027), '2027-001');
  });

  test('Fälligkeit, überfällig, fehlende Angaben', () {
    final r = _r('1', '2026-001');
    expect(faelligAm(r), DateTime(2026, 11, 3));
    expect(ueberfaellig(r, heute: DateTime(2026, 11, 4)), isTrue);
    expect(ueberfaellig(r, heute: DateTime(2026, 11, 3)), isFalse);
    r.bezahltAm = DateTime(2026, 11, 1);
    expect(ueberfaellig(r, heute: DateTime(2026, 11, 4)), isFalse);
    final fehlt = fehlendeAngaben(_r('2', '2026-002'), Firma(), Kunde(id: 'k1', name: 'Meier'));
    expect(fehlt, containsAll(['Dein Name oder Firmenname', 'Steuernummer oder USt-IdNr.', 'Anschrift des Kunden']));
    expect(fehlt, contains('Leistungsdatum oder -zeitraum'));
  });

  test('Einnahmen und Ausgaben nach Zahlungseingang', () {
    final rechnungen = [
      _r('1', '2026-001', bezahlt: DateTime(2026, 11, 10), pos: [
        Position(text: 'A', menge: 2, preis: 100),
        Position(text: 'B', preis: 20, ustSatz: 7),
      ]),
      _r('2', '2026-002'),
      _r('3', 'A-2026-001', art: 'angebot'),
      _r('4', '2026-003', bezahlt: DateTime(2026, 9, 30)),
    ];
    final belege = [
      Beleg(id: 'x', haendler: 'Bürobedarf', datum: DateTime(2026, 10, 5), betrag: 50, geschaeftlich: true),
      Beleg(id: 'y', haendler: 'Supermarkt', datum: DateTime(2026, 10, 6), betrag: 30),
    ];
    final q4 = Zeitraum.quartal(2026, 4);
    expect(q4.von, DateTime(2026, 10, 1));
    expect(q4.bis, DateTime(2026, 12, 31));
    final u = ueberschuss(z: q4, rechnungen: rechnungen, belege: belege, kleinunternehmer: false);
    expect(u.einnahmenNetto, 220);
    expect(u.ustEingenommen, closeTo(39.4, 0.001));
    expect(u.ausgaben, 50);
    expect(u.offen, 119);
    expect(u.gewinnVorSteuer, 170);
    expect(ustVoranmeldungBis(q4), DateTime(2027, 1, 10));

    final f = faelligkeiten(
        briefe: const [], vertraege: const [], belege: const [], termine: const [], rechnungen: rechnungen);
    expect(f.single.art, FaelligArt.rechnung);
    expect(f.single.titel, 'Rechnung 2026-002');
  });

  test('Speichern und Laden', () {
    final r = _r('1', '2026-001', pos: [Position(text: 'Fenster putzen', menge: 1.5, einheit: 'Std.', preis: 40, ustSatz: 7)]);
    final k = Rechnung.fromJson(r.toJson());
    expect(k.positionen.single.menge, 1.5);
    expect(k.positionen.single.ustSatz, 7);
    final f = Firma.fromJson(Firma(name: 'X', kleinunternehmer: true, zahlungszielTage: 30).toJson());
    expect(f.kleinunternehmer, isTrue);
    expect(f.zahlungszielTage, 30);
  });

  test('Marketing: Anfrage, Kunden wieder ansprechen, Angebote nachfassen', () {
    final f = Firma(name: 'Glanz Fensterreinigung', telefon: '0221 123');
    final a = marketingAnfrage(marketingArten.first, f, thema: 'Neue Termine im Dezember', zielgruppe: 'Familien');
    expect(a, contains('Glanz Fensterreinigung'));
    expect(a, contains('Neue Termine im Dezember'));
    expect(a, contains('Zielgruppe: Familien'));
    expect(a, contains('Keine erfundenen Preise'));

    final kunden = [Kunde(id: 'k1', name: 'Meier'), Kunde(id: 'k2', name: 'Schulz'), Kunde(id: 'k3', name: 'Neu')];
    final rs = [
      _r('1', '2026-001', kunde: 'k1', datum: DateTime(2026, 3, 1)),
      _r('2', '2026-002', kunde: 'k2', datum: DateTime(2026, 10, 1)),
      _r('3', 'A-2026-001', art: 'angebot', kunde: 'k3', datum: DateTime(2026, 10, 10)),
      _r('4', 'A-2026-002', art: 'angebot', kunde: 'k2', datum: DateTime(2026, 9, 20)),
    ];
    final heute = DateTime(2026, 10, 29);
    final w = wiederAnsprechen(kunden, rs, heute: heute);
    expect(w.map((x) => x.$1.name), ['Meier']);
    expect(angeboteNachfassen(rs, heute: heute).map((r) => r.nummer), ['A-2026-001']);
  });
}
