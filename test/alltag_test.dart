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

  test('Rezept aus KI-Antwort lesen', () {
    final r = rezeptLesen('''
**NAME:** Cremige Tomatenpasta
PORTIONEN: 2
ZEIT: 20
ZUTATEN:
- 250 g Spaghetti
- 400 g passierte Tomaten
- 1 Zwiebel (kaufen)
- Salz
ZUBEREITUNG:
1. Nudeln kochen.
2. Sauce mit Zwiebel köcheln lassen.
''', quelle: 'Screenshot')!;
    expect(r.name, 'Cremige Tomatenpasta');
    expect(r.portionen, '2');
    expect(r.zeit, '20');
    expect(r.zutaten, ['250 g Spaghetti', '400 g passierte Tomaten', '1 Zwiebel', 'Salz']);
    expect(r.zubereitung, '1. Nudeln kochen.\n2. Sauce mit Zwiebel köcheln lassen.');
    expect(r.quelle, 'Screenshot');
  });

  test('Kein Rezept im Screenshot', () {
    expect(rezeptLesen('KEIN REZEPT'), isNull);
    expect(rezeptLesen(''), isNull);
  });

  test('Zutaten auf die Einkaufsliste ohne Doppelte, Grundzutaten erkennen', () {
    final liste = [Einkauf(text: '1 Zwiebel')];
    final neu = zutatenAufEinkaufsliste(['1 zwiebel', '250 g Spaghetti', '250 g Spaghetti'], liste);
    expect(neu.map((e) => e.text), ['250 g Spaghetti']);
    expect(liste.length, 2);
    expect(istGrundzutat('Salz'), isTrue);
    expect(istGrundzutat('2 EL Olivenöl'), isTrue);
    expect(istGrundzutat('Öl'), isTrue);
    expect(istGrundzutat('250 g Spaghetti'), isFalse);
  });

  test('Rezepte überstehen Speichern und Laden', () {
    final a = Alltag(rezepte: [Rezept(id: '1', name: 'Pasta', zutaten: ['Nudeln'], zubereitung: '1. Kochen.', zeit: '15')]);
    final b = Alltag.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
    expect(b.rezepte.single.name, 'Pasta');
    expect(b.rezepte.single.zutaten, ['Nudeln']);
    expect(Alltag.fromJson({}).rezepte, isEmpty);
  });

  test('Aufgabe als Kalender-Einladung: Reihenfolge, Wiederholung, Erinnerung', () {
    final heute = DateTime(2026, 11, 9);
    final a = Hausaufgabe(text: 'Bad putzen', personen: ['Mia', 'Tom'], alleTage: 7);
    // Noch nie gemacht: Mia ist heute dran, Tom eine Woche später
    expect(aufgabeStartFuer(a, 0, heute: heute), DateTime(2026, 11, 9));
    expect(aufgabeStartFuer(a, 1, heute: heute), DateTime(2026, 11, 16));
    final ics = aufgabeAlsIcs(a, 1, heute: heute);
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('DTSTART;VALUE=DATE:20261116'));
    expect(ics, contains('RRULE:FREQ=DAILY;INTERVAL=14')); // jede Person alle 2 Wochen
    expect(ics, contains('TRIGGER:PT9H'));
    expect(ics, contains('SUMMARY:Haushalt: Bad putzen (Tom)'));
    final nachricht = aufgabeNachricht(a, 1, heute: heute);
    expect(nachricht, contains('Hallo Tom'));
    expect(nachricht, contains('16.11.2026'));
    // Ohne Namen: einfach wöchentlich wiederholt
    final solo = Hausaufgabe(text: 'Müll', alleTage: 3);
    expect(aufgabeAlsIcs(solo, 0, heute: heute), contains('RRULE:FREQ=DAILY;INTERVAL=3'));
  });
}
