import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/alltag.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/data/karriere.dart';
import 'package:papiertiger/logic/heute.dart';
import 'package:papiertiger/logic/lebenslage.dart';

void main() {
  final jetzt = DateTime(2026, 11, 2, 18);

  test('Heute erledigen: Hinweise aus allen Bereichen', () {
    final alltag = Alltag(
      vorraete: [Vorrat(name: 'Milch', ablauf: DateTime(2026, 11, 3)), Vorrat(name: 'Reis', ablauf: DateTime(2027))],
      hausaufgaben: [Hausaufgabe(text: 'Müll', personen: ['Mia', 'Tom'], alleTage: 7, zuletzt: DateTime(2026, 10, 26))],
    );
    final karriere = Karriere(bewerbungen: [
      Bewerbung(id: 'a', firma: 'Alpha', stelle: 'S', status: 'Beworben', beworbenAm: DateTime(2026, 10, 1)),
      Bewerbung(id: 'b', firma: 'Beta', stelle: 'S', frist: DateTime(2026, 11, 4)),
      Bewerbung(id: 'c', firma: 'Gamma', stelle: 'S', frist: DateTime(2026, 12, 1)),
    ], weiterbildungen: [
      Weiterbildung(id: 'w', titel: 'Excel-Kurs', anmeldungBis: DateTime(2026, 11, 3)),
    ]);
    final h = heuteHinweise(
      alltag: alltag,
      karriere: karriere,
      stempel: [Stempel(person: 'Anna', projektId: 'p', start: DateTime(2026, 11, 2, 7))],
      letzteSicherung: null,
      hatDaten: true,
      jetzt: jetzt,
    );
    expect(h.map((x) => x.art), ['stempel', 'vorrat', 'hausaufgabe', 'bewerbung', 'bewerbungsfrist', 'weiterbildung', 'sicherung']);
    expect(h[1].titel, 'Verbrauchen: Milch');
    expect(h[2].text, 'Tom ist dran');
    expect(h[3].ref, 'a');
    expect(h[4].ref, 'b');
  });

  test('Ohne Daten und mit frischer Sicherung keine Hinweise', () {
    expect(
        heuteHinweise(alltag: Alltag(), karriere: Karriere(), stempel: [], letzteSicherung: null, hatDaten: false, jetzt: jetzt),
        isEmpty);
    expect(
        heuteHinweise(
            alltag: Alltag(), karriere: Karriere(), stempel: [], letzteSicherung: DateTime(2026, 10, 20), hatDaten: true, jetzt: jetzt),
        isEmpty);
  });

  test('Lebenslagen steuern, was sichtbar ist', () {
    expect(modulSichtbar('karriere', {}), isTrue);
    expect(modulSichtbar('karriere', {'senior'}), isFalse);
    expect(modulSichtbar('karriere', {'senior', 'jobsuche'}), isTrue);
    expect(modulSichtbar('finanzen', {'handwerk'}), isTrue);
    expect(handwerkSichtbar({'selbststaendig'}), isFalse);
    expect(handwerkSichtbar({'selbststaendig', 'handwerk'}), isTrue);
    expect(handwerkSichtbar({}), isTrue);
    expect(grossschriftVorschlagen({'senior'}), isTrue);
    expect(lebenslagen.map((l) => l.key).toSet().length, lebenslagen.length);
  });
}
