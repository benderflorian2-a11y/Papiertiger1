import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/logic/arbeitszeit.dart';

void main() {
  test('Stempeluhr mit Pause', () {
    final s = Stempel(person: 'Anna', projektId: 'p', start: DateTime(2026, 11, 2, 7, 0));
    pauseUmschalten(s, DateTime(2026, 11, 2, 12, 0));
    expect(laufendeMinuten(s, DateTime(2026, 11, 2, 12, 20)), 300);
    pauseUmschalten(s, DateTime(2026, 11, 2, 12, 30));
    expect(s.pauseMinuten, 30);
    final z = stempelBeenden(s, DateTime(2026, 11, 2, 16, 15), text: 'Fliesen');
    expect(z.stunden, 8.75);
    expect(z.pauseMinuten, 30);
    expect(z.datum, DateTime(2026, 11, 2));
    expect(z.beginn, DateTime(2026, 11, 2, 7));
    expect(Zeiteintrag.fromJson(z.toJson()).ende, DateTime(2026, 11, 2, 16, 15));
    // Ende während einer Pause: Pause wird abgeschlossen
    final f = Stempel(person: 'Ben', projektId: 'p', start: DateTime(2026, 11, 2, 8), fahrt: true);
    pauseUmschalten(f, DateTime(2026, 11, 2, 9));
    final zf = stempelBeenden(f, DateTime(2026, 11, 2, 9, 30));
    expect(zf.stunden, 1);
    expect(zf.fahrt, isTrue);
    expect(zf.text, 'Fahrtzeit');
  });

  test('Pausen nach Arbeitszeitgesetz', () {
    expect(arbeitszeitHinweise(6, 0), isEmpty);
    expect(arbeitszeitHinweise(6.5, 15).single, contains('30 Minuten'));
    expect(arbeitszeitHinweise(6.5, 30), isEmpty);
    expect(arbeitszeitHinweise(9.5, 30).single, contains('45 Minuten'));
    expect(arbeitszeitHinweise(10.5, 60).single, contains('10 Stunden'));
  });

  test('Tageszeit und Stundenliste', () {
    final tag = DateTime(2026, 11, 2);
    final projekte = [
      Projekt(id: 'a', name: 'Bad "Meier"', zeiten: [
        Zeiteintrag(datum: tag, stunden: 4, person: 'Anna', beginn: DateTime(2026, 11, 2, 7), ende: DateTime(2026, 11, 2, 11, 15), pauseMinuten: 15),
        Zeiteintrag(datum: tag, stunden: 0.5, person: 'Anna', fahrt: true),
      ]),
      Projekt(id: 'b', name: 'Dach', zeiten: [
        Zeiteintrag(datum: tag, stunden: 3, person: 'Anna', pauseMinuten: 15),
        Zeiteintrag(datum: DateTime(2026, 10, 30), stunden: 8, person: 'Ben'),
      ]),
    ];
    expect(tagesZeit(projekte, 'Anna', tag), (7.5, 30));
    final csv = stundenliste(projekte, jahr: 2026, monat: 11);
    expect(csv, contains('Anna;02.11.2026;"Bad \'Meier\'";07:00;11:15;15;4,00;Arbeit;""'));
    expect(csv, contains('Anna;;;;;;7,00;0,50;'));
    expect(csv, isNot(contains('Ben')));
  });
}
