import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/logic/kalkulation.dart';
import 'package:papiertiger/logic/rechnungen.dart';

var _n = 0;
String _id() => 'id${_n++}';

void main() {
  test('Verkaufspreis aus Einkauf, Aufschlag und Arbeitszeit', () {
    final a = Artikel(id: 'a', text: 'Fliesen verlegen', einheit: 'm²', einkauf: 20, aufschlagProzent: 25, minuten: 30);
    expect(vkPreis(a, stundensatz: 60), 55); // 25 Material + 30 Lohn
    a.festpreis = 49.9;
    expect(vkPreis(a, stundensatz: 60), 49.9);
    final p = positionAusArtikel(a, stundensatz: 60, menge: 3, kleinunternehmer: true);
    expect(p.preis, 49.9);
    expect(p.ustSatz, 0);
    expect(p.einkauf, 20);
  });

  test('Aufmaß mit Abzug', () {
    final l = [
      AufmassZeile(text: 'Wand Nord', laenge: 4.2, hoehe: 2.5),
      AufmassZeile(text: 'Wand Süd', anzahl: 2, laenge: 3, hoehe: 2.5),
      AufmassZeile(text: 'Fenster', laenge: 1.2, hoehe: 1.4, abzug: true),
    ];
    expect(aufmassMenge(l), 23.82); // 10,5 + 15 − 1,68
    expect(aufmassText(l), 'Wand Nord 4,20 × 2,50 · Wand Süd 2 × 3 × 2,50 · − Fenster 1,20 × 1,40');
    expect(aufmassMenge([AufmassZeile(laenge: 1, abzug: true)]), 0);
  });

  test('Aufmaß und Kalkulationswerte überstehen Speichern', () {
    final p = Position(text: 'Boden', aufmass: [AufmassZeile(laenge: 2, breite: 3)], einkauf: 5, minuten: 10);
    final q = Position.fromJson(p.toJson());
    expect(q.aufmass.single.breite, 3);
    expect(q.einkauf, 5);
    expect(q.minuten, 10);
    expect(Position(text: 'x').toJson().containsKey('aufmass'), isFalse);
  });

  test('Kalkulation eines Angebots', () {
    final r = Rechnung(id: 'r', art: 'angebot', nummer: 'A', kundeId: 'k', datum: DateTime(2026), positionen: [
      Position(text: 'Fliesen', menge: 10, preis: 55, einkauf: 20, minuten: 30),
      Position(text: 'Anfahrt', preis: 40),
    ]);
    final s = summenVon(r, kleinunternehmer: false);
    final k = kalkulationVon(r, stundensatz: 60, netto: s.netto);
    expect(k.material, 200);
    expect(k.stunden, 5);
    expect(k.lohn, 300);
    expect(k.rohertrag, 90); // 590 − 200 − 300
    expect(k.rohertragProzent, 15.25);
  });

  test('Katalog aus CSV mit Überschrift', () {
    const csv = 'Artikelnr;Bezeichnung;ME;EK-Preis;VK\n'
        '4711;Fliesenkleber 25 kg;Sack;12,50;\n'
        '4712;"Silikon weiß";Kartusche;4,20;9,90\n'
        ';;;;\n';
    final l = katalogAusCsv(csv, neueId: _id, aufschlag: 20);
    expect(l.length, 2);
    expect(l[0].nummer, '4711');
    expect(l[0].text, 'Fliesenkleber 25 kg');
    expect(l[0].einheit, 'Sack');
    expect(l[0].einkauf, 12.5);
    expect(l[0].festpreis, isNull);
    expect(vkPreis(l[0], stundensatz: 0), 15);
    expect(l[1].text, 'Silikon weiß');
    expect(l[1].festpreis, 9.9);
  });

  test('Katalog ohne Überschrift und Suche', () {
    final l = katalogAusCsv('1\tSchraube 4x40\tStück\t0.05\n2\tDübel 6 mm\tStück\t0.03', neueId: _id);
    expect(l.map((a) => a.einkauf), [0.05, 0.03]);
    expect(katalogSuchen(l, 'dübel').single.nummer, '2');
    expect(katalogSuchen(l, '').length, 2);
  });

  test('Angebot per KI: Positionen lesen, Katalogpreise übernehmen', () {
    final katalog = [Artikel(id: 'a', text: 'Bodenfliesen verlegen', einheit: 'm²', festpreis: 45)];
    const antwort = 'Hier der Entwurf:\n'
        'POS: Bodenfliesen verlegen | 7,5 | m²\n'
        '**POS: Alte Fliesen entfernen | 1 | pauschal**\n'
        'POS: Silikonfugen erneuern [Menge prüfen] | 1 | m';
    final p = angebotLesen(antwort, katalog, stundensatz: 60);
    expect(p.length, 3);
    expect(p[0].menge, 7.5);
    expect(p[0].preis, 45);
    expect(p[1].text, 'Alte Fliesen entfernen');
    expect(p[1].preis, 0);
    expect(p[2].text, contains('[Menge prüfen]'));
    final a = angebotAnfrage('Bad 2,5 x 3 m', katalog, stundensatz: 60);
    expect(a, contains('- Bodenfliesen verlegen (m²)'));
    expect(a, contains('Bad 2,5 x 3 m'));
  });
}
