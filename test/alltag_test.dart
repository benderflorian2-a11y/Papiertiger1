import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/alltag.dart';
import 'package:papiertiger/logic/alltag.dart';

void main() {
  test('Einkauf wird nach Abteilungen einsortiert', () {
    expect(einkaufKategorie(Einkauf(text: 'Milch')), 'Kühlregal');
    expect(einkaufKategorie(Einkauf(text: '1 kg Kartoffeln')), 'Obst & Gemüse');
    expect(einkaufKategorie(Einkauf(text: 'Reis')), 'Vorrat');
    expect(einkaufKategorie(Einkauf(text: 'Brot', kategorie: 'Backwaren')), 'Brot & Backwaren');
    expect(einkaufNachKategorie([Einkauf(text: 'Etwas', kategorie: 'Gibt es nicht')]).single.$2.single.text, 'Etwas');
    expect(einkaufKategorie(Einkauf(text: 'Klopapier')), 'Drogerie');
    expect(einkaufKategorie(Einkauf(text: 'Irgendwas')), 'Sonstiges');
    expect(einkaufKategorie(Einkauf(text: 'Milch', kategorie: 'Getränke')), 'Getränke');
  });

  test('Einkauf aus Rezepttext: Überschriften, Anleitung und Doppelte fallen weg', () {
    const rezept = 'Zutaten:\n- 500 g Spaghetti\n- 2 Zwiebeln\n1. Tomaten\n'
        'Die Zwiebeln schälen und in kleine Würfel schneiden, dann anbraten.\nMilch, Eier';
    final l = einkaufAusText(rezept, vorhanden: [Einkauf(text: 'Milch')]);
    expect(l.map((e) => e.text), ['500 g Spaghetti', '2 Zwiebeln', 'Tomaten', 'Eier']);
  });

  test('Einkauf abschließen behält wiederkehrende', () {
    final l = [
      Einkauf(text: 'Brot', erledigt: true),
      Einkauf(text: 'Milch', erledigt: true, immer: true),
      Einkauf(text: 'Käse'),
    ];
    einkaufAbschliessen(l);
    expect(l.map((e) => e.text), ['Milch', 'Käse']);
    expect(l.every((e) => !e.erledigt), isTrue);
  });

  test('Vorräte: bald ablaufend, früheste zuerst', () {
    final heute = DateTime(2026, 10, 29);
    final l = [
      Vorrat(name: 'Joghurt', ablauf: DateTime(2026, 11, 1)),
      Vorrat(name: 'Reis'),
      Vorrat(name: 'Milch', ablauf: DateTime(2026, 10, 30)),
      Vorrat(name: 'Käse', ablauf: DateTime(2026, 11, 20)),
    ];
    expect(laeuftBaldAb(l, heute: heute).map((v) => v.name), ['Milch', 'Joghurt']);
  });

  test('Essensplan und Einkaufsliste aus KI-Antwort', () {
    const antwort = '**Montag:** Spaghetti Bolognese\nDIENSTAG – Gemüsesuppe\nSonntag: Pfannkuchen\n\n'
        'EINKAUFSLISTE:\n- 500 g Hackfleisch\n- 1 Packung Spaghetti\n- 2 Möhren';
    expect(essensplanLesen(antwort), {'1': 'Spaghetti Bolognese', '2': 'Gemüsesuppe', '7': 'Pfannkuchen'});
    expect(einkaufAusEssensplan(antwort).map((e) => e.text), ['500 g Hackfleisch', '1 Packung Spaghetti', '2 Möhren']);
    expect(einkaufAusEssensplan('nichts'), isEmpty);
  });

  test('Haushaltsaufgaben wechseln reihum', () {
    final a = Hausaufgabe(text: 'Bad putzen', personen: ['Mia', 'Tom', 'Papa'], alleTage: 7);
    expect(werIstDran(a), 'Mia');
    expect(hausaufgabeFaellig(a, heute: DateTime(2026, 10, 29)), isTrue);
    hausaufgabeErledigt(a, DateTime(2026, 10, 29)); // Mia
    expect(werIstDran(a), 'Tom');
    expect(naechstesMal(a), DateTime(2026, 11, 5));
    expect(hausaufgabeFaellig(a, heute: DateTime(2026, 11, 4)), isFalse);
    expect(hausaufgabeFaellig(a, heute: DateTime(2026, 11, 5)), isTrue);
    hausaufgabeErledigt(a, DateTime(2026, 11, 5)); // Tom
    hausaufgabeErledigt(a, DateTime(2026, 11, 12)); // Papa
    expect(werIstDran(a), 'Mia');
  });

  test('Packliste je nach Reiseart', () {
    final s = packliste('Sommer').map((p) => p.text);
    expect(s, contains('Sonnencreme'));
    expect(s, isNot(contains('Reiseadapter')));
    final w = packliste('Winter', kinder: true, ausland: true).map((p) => p.text);
    expect(w, containsAll(['Warme Jacke', 'Reiseadapter', 'Kinderreisepass']));
  });

  test('Alltag übersteht Speichern und Laden', () {
    final a = Alltag(
      einkauf: [Einkauf(text: 'Milch', immer: true)],
      vorraete: [Vorrat(name: 'Reis', ablauf: DateTime(2027, 1, 1))],
      essensplan: {'1': 'Suppe'},
      hausaufgaben: [Hausaufgabe(text: 'Müll', personen: ['A', 'B'], zuletzt: DateTime(2026, 10, 1), zuletztVon: 1)],
      geschenke: [Geschenk(idee: 'Buch', preis: 15.5)],
      reisen: [Reise(id: 'r1', ziel: 'Rom', packliste: [PackStueck('Pass', eingepackt: true)], briefIds: ['b1'])],
    );
    final b = Alltag.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
    expect(b.einkauf.single.immer, isTrue);
    expect(b.vorraete.single.ablauf, DateTime(2027, 1, 1));
    expect(b.essensplan['1'], 'Suppe');
    expect(werIstDran(b.hausaufgaben.single), 'A');
    expect(b.geschenke.single.preis, 15.5);
    expect(b.reisen.single.packliste.single.eingepackt, isTrue);
    expect(b.reisen.single.briefIds, ['b1']);
  });
}
