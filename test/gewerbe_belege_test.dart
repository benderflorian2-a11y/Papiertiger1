import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/logic/rechnungen.dart';
import 'package:papiertiger/logic/zahlung.dart';

Rechnung _angebot() => Rechnung(
      id: 'a1',
      art: 'angebot',
      nummer: 'A-2026-001',
      kundeId: 'k',
      datum: DateTime(2026, 10, 1),
      positionen: [
        Position(text: 'Fliesen verlegen', menge: 10, einheit: 'm²', preis: 50),
        Position(text: 'Material', preis: 500),
      ],
    );

void main() {
  test('Rabatt wird vor der Umsatzsteuer abgezogen', () {
    final r = _angebot()..rabattProzent = 10;
    final s = summenVon(r, kleinunternehmer: false);
    expect(s.zwischensumme, 1000);
    expect(s.rabatt, 100);
    expect(s.netto, 900);
    expect(s.ust[19], 171);
    expect(s.brutto, 1071);
    r
      ..rabattProzent = 0
      ..rabattBetrag = 50;
    expect(summenVon(r, kleinunternehmer: true).brutto, 950);
    r.rabattBetrag = 5000; // nie mehr als die Summe
    expect(summenVon(r, kleinunternehmer: false).brutto, 0);
  });

  test('Rabatt verteilt sich anteilig auf verschiedene Steuersätze', () {
    final r = Rechnung(id: 'x', art: 'rechnung', nummer: '1', kundeId: 'k', datum: DateTime(2026), rabattProzent: 50, positionen: [
      Position(text: 'A', preis: 100, ustSatz: 19),
      Position(text: 'B', preis: 100, ustSatz: 7),
    ]);
    final s = summenVon(r, kleinunternehmer: false);
    expect(s.netto, 100);
    expect(s.ust, {19: 9.5, 7: 3.5});
  });

  test('Nummernkreise: Abschlag und Schluss zählen bei den Rechnungen mit', () {
    final alle = [
      Rechnung(id: '1', art: 'rechnung', nummer: '2026-004', kundeId: 'k', datum: DateTime(2026)),
      Rechnung(id: '2', art: 'abschlag', nummer: '2026-005', kundeId: 'k', datum: DateTime(2026)),
      Rechnung(id: '3', art: 'auftragsbestaetigung', nummer: 'AB-2026-002', kundeId: 'k', datum: DateTime(2026)),
    ];
    expect(naechsteNummer(alle, art: 'rechnung', jahr: 2026), '2026-006');
    expect(naechsteNummer(alle, art: 'schluss', jahr: 2026), '2026-006');
    expect(naechsteNummer(alle, art: 'auftragsbestaetigung', jahr: 2026), 'AB-2026-003');
    expect(naechsteNummer(alle, art: 'lieferschein', jahr: 2026), 'LS-2026-001');
  });

  test('Angebot → Auftragsbestätigung → Abschlag → Schlussrechnung', () {
    final angebot = _angebot();
    final alle = <Rechnung>[angebot];
    final ab = umwandeln(angebot, alle, art: 'auftragsbestaetigung', id: 'ab', datum: DateTime(2026, 10, 2), zahlungszielTage: 14);
    expect(ab.nummer, 'AB-2026-001');
    expect(ab.bezugId, 'a1');
    expect(ab.istRechnung, isFalse);
    alle.add(ab);
    final a1 = abschlagAus(ab, alle, id: 'ar1', datum: DateTime(2026, 10, 5), prozent: 30, zahlungszielTage: 14);
    expect(a1.art, 'abschlag');
    expect(a1.bezugId, 'a1');
    expect(a1.positionen.single.preis, 300);
    expect(a1.positionen.single.text, contains('1. Abschlag: 30 %'));
    alle.add(a1..bezahltAm = DateTime(2026, 10, 10));
    final schluss = schlussAus(ab, alle, id: 's', datum: DateTime(2026, 11, 1), zahlungszielTage: 14);
    alle.add(schluss);
    expect(schluss.nummer, '2026-002');
    expect(abschlaegeZu(schluss, alle).map((x) => x.id), ['ar1']);
    expect(summenVon(schluss, kleinunternehmer: false).brutto, 1190);
    final rest = zuZahlen(schluss, alle, kleinunternehmer: false);
    expect(rest.netto, 700);
    expect(rest.brutto, 833);
    // Abschlag und Schluss zusammen = Auftragssumme, nichts doppelt
    expect(summenVon(a1, kleinunternehmer: false).brutto + rest.brutto, 1190);
  });

  test('Mahnstufen', () {
    final r = Rechnung(id: 'r', art: 'rechnung', nummer: '2026-001', kundeId: 'k', datum: DateTime(2026, 9, 1),
        zahlungszielTage: 14, positionen: [Position(text: 'X', preis: 100)]);
    expect(naechsteMahnstufe(r, heute: DateTime(2026, 9, 10)), isNull);
    expect(naechsteMahnstufe(r, heute: DateTime(2026, 9, 20)), 1);
    r
      ..mahnstufe = 1
      ..gemahntAm = DateTime(2026, 9, 20);
    expect(naechsteMahnstufe(r, heute: DateTime(2026, 9, 25)), isNull);
    expect(naechsteMahnstufe(r, heute: DateTime(2026, 10, 1)), 2);
    final f = Firma(name: 'Maler Max', adresse: 'Weg 1', iban: 'DE89370400440532013000');
    final k = Kunde(id: 'k', name: 'Erika', adresse: 'Straße 2');
    final s = summenVon(r, kleinunternehmer: false);
    final t2 = mahnText(r, f, k, s, stufe: 2, gebuehr: 5, heute: DateTime(2026, 10, 1));
    expect(t2, contains('1. Mahnung zur Rechnung 2026-001'));
    expect(t2, contains('Mahngebühr: 5,00 €'));
    expect(t2, contains('Gesamt: 124,00 €'));
    expect(t2, contains('bis spätestens 11.10.2026'));
    final t3 = mahnText(r, f, k, s, stufe: 3, heute: DateTime(2026, 10, 15));
    expect(t3, contains('Letzte Mahnung'));
    expect(t3, isNot(contains('Mahngebühr')));
    expect(mahnText(r, f, k, s, stufe: 1, gebuehr: 5), isNot(contains('Mahngebühr')));
  });

  test('GiroCode nach EPC-Standard', () {
    final g = giroCode(name: 'Maler Max', iban: 'DE89 3704 0044 0532 0130 00', betrag: 123.4, zweck: 'Rechnung 2026-001');
    expect(g.split('\n'), ['BCD', '002', '1', 'SCT', '', 'Maler Max', 'DE89370400440532013000', 'EUR123.40', '', '', 'Rechnung 2026-001']);
    expect(giroCode(name: '', iban: 'DE89370400440532013000', betrag: 1, zweck: 'x'), isEmpty);
    expect(giroCode(name: 'A', iban: 'DE89', betrag: 1, zweck: 'x'), isEmpty);
  });

  test('Überweisung wird vor der Freigabe geprüft', () {
    final z = Zahlauftrag(empfaenger: 'Stadtwerke', iban: 'DE89370400440532013000', betrag: 80, zweck: 'Kd 123');
    expect(zahlauftragPruefen(z), isEmpty);
    expect(z.giroCodeText, startsWith('BCD'));
    expect(z.alsText(), contains('IBAN: DE89 3704 0044 0532 0130 00'));
    z.iban = 'DE89370400440532013001';
    expect(zahlauftragPruefen(z).single, contains('ungültig'));
    expect(zahlauftragPruefen(Zahlauftrag()).length, 4);
  });

  test('Begleittext je Belegart', () {
    final f = Firma(name: 'Maler Max', iban: 'DE89370400440532013000');
    final k = Kunde(id: 'k', name: 'Erika Muster');
    final r = Rechnung(id: 'r', art: 'rechnung', nummer: '2026-001', kundeId: 'k', datum: DateTime(2026, 10, 1),
        positionen: [Position(text: 'X', preis: 100)]);
    final t = begleitText(r, f, k, summenVon(r, kleinunternehmer: false));
    expect(t, startsWith('Guten Tag Erika Muster'));
    expect(t, contains('119,00 €'));
    expect(t, contains('15.10.2026'));
    expect(t, contains('GiroCode'));
    r.art = 'angebot';
    expect(begleitText(r, f, k, summenVon(r, kleinunternehmer: false)), contains('mein Angebot 2026-001'));
  });

  test('Alte gespeicherte Rechnungen laden weiter', () {
    final alt = {'id': 'x', 'art': 'rechnung', 'nummer': '1', 'kundeId': 'k', 'datum': '2026-01-01T00:00:00.000', 'gemahntAm': '2026-02-01T00:00:00.000'};
    final r = Rechnung.fromJson(alt);
    expect(r.mahnstufe, 1);
    expect(r.rabattProzent, 0);
    expect(r.bezugId, isNull);
    expect(Rechnung.fromJson(r.toJson()).mahnstufe, 1);
  });
}
