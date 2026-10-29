import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/logic/projekte.dart';

Projekt _p() => Projekt(id: 'p', name: 'Bad Meier', kundeId: 'k', stundensatz: 50, angebotId: 'a', zeiten: [
      Zeiteintrag(datum: DateTime(2026, 10, 26), stunden: 4, person: 'Anna', text: 'Fliesen abschlagen'),
      Zeiteintrag(datum: DateTime(2026, 10, 27), stunden: 3.5, person: 'Ben'),
      Zeiteintrag(datum: DateTime(2026, 11, 3), stunden: 2),
    ], material: [
      Materialposten(text: 'Fliesenkleber', menge: 4, einheit: 'Sack', preis: 12.5),
      Materialposten(text: 'Silikon', menge: 2, preis: 6, bestellt: true),
    ]);

void main() {
  test('Nachkalkulation gegen Angebot', () {
    final angebot = Rechnung(id: 'a', art: 'angebot', nummer: 'A-2026-001', kundeId: 'k', datum: DateTime(2026, 10, 1),
        positionen: [Position(text: 'Bad', preis: 500)]);
    final n = nachkalkulation(_p(), [angebot]);
    expect(n.zeit, 475);
    expect(n.material, 62);
    expect(n.kosten, 537);
    expect(n.angebot, 500);
    expect(n.abweichung, 37);
    expect(n.abweichungProzent, 7.4);
  });

  test('Rechnung aus Projekt', () {
    final r = rechnungAusProjekt(_p(), const [], id: 'r', datum: DateTime(2026, 11, 5), zahlungszielTage: 14);
    expect(r.nummer, '2026-001');
    expect(r.projektId, 'p');
    expect(r.positionen.first.menge, 9.5);
    expect(r.positionen.first.preis, 50);
    expect(r.positionen.length, 3);
    expect(r.leistungVon, DateTime(2026, 10, 26));
    expect(r.leistungBis, DateTime(2026, 11, 3));
  });

  test('Tätigkeitsnachweis und Bestellliste', () {
    final t = taetigkeitsnachweis([_p()], {'k': 'Familie Meier'}, von: DateTime(2026, 10, 26), bis: DateTime(2026, 11, 1));
    expect(t, contains('Bad Meier (Familie Meier) – 7,5 Std.'));
    expect(t, contains('26.10.2026  4 Std.  Anna  Fliesen abschlagen'));
    expect(t, contains('Gesamt: 7,5 Stunden'));
    final nurBen = taetigkeitsnachweis([_p()], {}, von: DateTime(2026, 10, 1), bis: DateTime(2026, 11, 30), person: 'Ben');
    expect(nurBen, contains('Gesamt: 3,5 Stunden'));
    final b = bestellliste([_p()]);
    expect(b, contains('- 4 Sack Fliesenkleber'));
    expect(b, isNot(contains('Silikon')));
    expect(bestellliste([_p()..status = 'Fertig']), isEmpty);
  });

  test('Aufgaben aus Besprechung, Vorlagen, Speichern', () {
    final a = aufgabenAusProtokoll('Besprechung mit Kunde\n- @Anna Fliesen bestellen\n- Kunde: Farbe aussuchen\nTODO: Termin bestätigen\nAufgaben verteilt.');
    expect(a.map((x) => x.text), ['Fliesen bestellen', 'Farbe aussuchen', 'Termin bestätigen']);
    expect(a.map((x) => x.person), ['Anna', 'Kunde', '']);
    expect(ablaufVorlagen({'vorlage:Wartung': 'Gerät prüfen\n\nProtokoll schreiben', 'x': 'y'}), {'Wartung': ['Gerät prüfen', 'Protokoll schreiben']});
    final k = Projekt.fromJson(_p().toJson());
    expect(k.zeiten.length, 3);
    expect(k.material.last.bestellt, isTrue);
  });
}
