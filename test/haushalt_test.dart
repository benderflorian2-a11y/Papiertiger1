import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/haushalt.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/haushalt.dart';

void main() {
  test('Verbrauch hochrechnen und Abschlag prüfen', () {
    final z = Zaehler(id: 'z', art: 'Strom', preis: 0.35, grundpreisMonat: 12, abschlagMonat: 80, ablesungen: [
      Ablesung(DateTime(2026, 7, 2), 2500),
      Ablesung(DateTime(2026, 1, 1), 1000),
    ]);
    expect(z.einheit, 'kWh');
    final v = verbrauchVon(z)!;
    expect(v.tage, 182);
    expect(v.menge, 1500);
    expect(v.proJahr, closeTo(3008.2, 0.001));
    final c = abschlagPruefen(z)!;
    expect(c.kostenJahr, closeTo(1196.87, 0.001));
    expect(c.abschlaegeJahr, 960);
    expect(c.differenz, closeTo(236.87, 0.001));
    expect(ablesungPruefen(z, 2400, DateTime(2026, 8, 1)), isNotNull);
    expect(ablesungPruefen(z, 2600, DateTime(2026, 8, 1)), isNull);
    expect(verbrauchVon(Zaehler(id: 'y', art: 'Gas', ablesungen: [Ablesung(DateTime(2026, 1, 1), 1)])), isNull);
    expect(Zaehler.fromJson(z.toJson()).ablesungen.length, 2);
  });

  test('Inventar', () {
    final l = [
      Gegenstand(id: '1', name: 'TV', raum: 'Wohnzimmer', preis: 800),
      Gegenstand(id: '2', name: 'Sofa', raum: 'Wohnzimmer', preis: 1200),
      Gegenstand(id: '3', name: 'Fahrrad', preis: 600),
    ];
    expect(inventarWert(l), 2600);
    expect(wertNachRaum(l), {'Wohnzimmer': 2000.0, 'Ohne Raum': 600.0});
    final g = gegenstandAusBeleg(Beleg(id: 'b', haendler: 'Elektromarkt', datum: DateTime(2026, 5, 1), betrag: 499), 'g');
    expect(g.belegId, 'b');
    expect(g.preis, 499);
  });

  test('Wiederkehrende Aufgabe aus Vorlage', () {
    final t = terminAusVorlage(haushaltsTermine.first, id: 't', start: DateTime(2026, 11, 1));
    expect(t.titel, 'Rauchmelder prüfen');
    expect(t.wiederholungMonate, 12);
    expect(t.datum, DateTime(2026, 11, 1, 10));
  });
}
