import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/vermietung.dart';
import 'package:papiertiger/logic/kontoauszug.dart';
import 'package:papiertiger/logic/vermietung.dart';

void main() {
  final o = Mietobjekt(id: 'o', adresse: 'Lindenweg 4, 12345 Ort', gesamtflaeche: 200, einheiten: 4);
  final j = Nebenkostenjahr(objektId: 'o', jahr: 2025, gesamtpersonen: 8, posten: [
    Kostenposten(art: 'Grundsteuer', betrag: 800, schluessel: 'flaeche'),
    Kostenposten(art: 'Müllabfuhr', betrag: 640, schluessel: 'personen'),
    Kostenposten(art: 'Allgemeinstrom', betrag: 200, schluessel: 'einheiten'),
  ]);

  test('Nebenkosten für ein ganzes Jahr', () {
    final m = Mieter(id: 'm', objektId: 'o', name: 'Erika Muster', flaeche: 50, personen: 2, nebenkosten: 40, einzug: DateTime(2020));
    final r = nebenkostenFuer(m, j, o);
    expect(r.zeilen.map((z) => z.anteil), [200, 160, 50]);
    expect(r.kosten, 410);
    expect(r.vorauszahlungen, 480);
    expect(r.saldo, -70);
    final t = abrechnungText(m, j, o, r, vermieter: 'Max Vermieter', adresse: 'Weg 1');
    expect(t, contains('Betriebskostenabrechnung 2025'));
    expect(t, contains('Guthaben: 70,00 €'));
    expect(abrechnungsfrist(2025), DateTime(2026, 12, 31));
  });

  test('Nebenkosten bei Einzug im Jahr (anteilig)', () {
    final m = Mieter(id: 'm', objektId: 'o', name: 'Neu', flaeche: 50, personen: 2, nebenkosten: 40, einzug: DateTime(2025, 7, 1));
    expect(bewohnteTage(m, 2025), 184);
    final r = nebenkostenFuer(m, j, o);
    expect(r.kosten, closeTo(410 * 184 / 365, 0.05));
    expect(r.vorauszahlungen, closeTo(480 * 184 / 365, 0.01));
    expect(bewohnteTage(Mieter(id: 'x', objektId: 'o', name: 'X', auszug: DateTime(2024, 12, 31)), 2025), 0);
  });

  test('Mieterhöhung frühestens nach einem Jahr, wirksam nach 15 Monaten', () {
    final m = Mieter(id: 'm', objektId: 'o', name: 'X', kaltmiete: 500, letzteErhoehung: DateTime(2025, 3, 1));
    final (verlangen, wirksam, hinweis) = mieterhoehungMoeglich(m);
    expect(verlangen, DateTime(2026, 3, 1));
    expect(wirksam, DateTime(2026, 6, 1));
    expect(hinweis, contains('600,00 €'));
  });

  test('Mieteingänge zuordnen', () {
    final a = Mieter(id: 'a', objektId: 'o', name: 'Erika Muster', kaltmiete: 500, nebenkosten: 100);
    final b = Mieter(id: 'b', objektId: 'o', name: 'Hans Huber', kaltmiete: 400, nebenkosten: 80);
    final g = [
      Gutschrift(von: 'MUSTER ERIKA', betrag: 600, datum: DateTime(2026, 11, 3), text: 'Miete November'),
      Gutschrift(von: 'Irgendwer', betrag: 480, datum: DateTime(2026, 10, 30), text: 'Miete'),
    ];
    final l = mieteingaenge([a, b], g, jahr: 2026, monat: 11);
    expect(l[0].$2?.betrag, 600);
    expect(l[1].$2, isNull); // Oktober zählt nicht für November
  });

  test('Schreiben an Mieter', () {
    final o = Mietobjekt(id: 'o', adresse: 'Lindenweg 3, 12345 Ort');
    final m = Mieter(id: 'm', objektId: 'o', name: 'Max Mieter', wohnung: '1. OG', einzug: DateTime(2024, 3, 1),
        kaltmiete: 600, nebenkosten: 150, flaeche: 62, personen: 2, kaution: 1800);
    final w = mieterSchreibenText('wohnungsgeber', m, o, vermieter: 'Vera Vermieter', adresse: 'Hof 1\n12345 Ort', heute: DateTime(2026, 10, 31));
    expect(w, contains('§ 19 Bundesmeldegesetz'));
    expect(w, contains('Einzug am 01.03.2024'));
    expect(w, contains('Lindenweg 3, 12345 Ort, 1. OG'));
    expect(w, contains('insgesamt 2 Personen'));
    final b = mieterSchreibenText('mietbescheinigung', m, o, vermieter: 'Vera Vermieter', adresse: '', heute: DateTime(2026, 10, 31));
    expect(b, contains('Gesamtmiete monatlich: 750,00 €'));
    expect(b, contains('Wohnfläche: 62 m²'));
    expect(mieterSchreibenText('erhoehung', m, o, vermieter: 'V', adresse: 'A', heute: DateTime(2026, 10, 31)), contains('ab dem 01.01.2027'));
    m.auszug = DateTime(2026, 11, 30);
    expect(mieterSchreibenText('wohnungsgeber', m, o, vermieter: 'V', adresse: 'A', heute: DateTime(2026, 10, 31)), contains('Auszug am 30.11.2026'));
    expect(mieterSchreibenText('kaution', m, null, vermieter: 'V', adresse: 'A'), contains('Kaution: 1.800,00 €'));
    expect(mieterSchreiben.length, 4);
  });
}
