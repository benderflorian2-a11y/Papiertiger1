import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/zeitplan.dart';

void main() {
  final heute = DateTime(2026, 10, 28);

  Brief brief(String id, {DateTime? frist, DateTime? nachfassen}) => Brief(
        id: id,
        erstellt: heute,
        kategorie: 'finanzamt',
        typ: 'bescheid',
        text: '',
        erklaerung: '',
        absenderName: 'Finanzamt',
        frist: frist,
        nachfassenAm: nachfassen,
      );

  test('Wiederkehrender Termin rollt auf das nächste Datum', () {
    final tuev = Termin(id: 't', titel: 'TÜV', datum: DateTime(2024, 3, 15, 10, 30), wiederholungMonate: 24);
    expect(naechstesTermindatum(tuev, heute: heute), DateTime(2028, 3, 15, 10, 30));
    final einmal = Termin(id: 'e', titel: 'Arzt', datum: DateTime(2026, 11, 2));
    expect(naechstesTermindatum(einmal, heute: heute), DateTime(2026, 11, 2));
  });

  test('Fälligkeiten aus Briefen, Nachfassen und Terminen, nach Datum', () {
    final f = faelligkeiten(
      briefe: [
        brief('a', frist: DateTime(2026, 11, 20)),
        brief('b', nachfassen: DateTime(2026, 11, 5)),
        brief('c')..erledigt = true,
      ],
      vertraege: const [],
      belege: const [],
      termine: [Termin(id: 't', titel: 'Wartung', datum: DateTime(2026, 11, 1))],
      heute: heute,
    );
    expect(f.map((x) => x.art), [FaelligArt.termin, FaelligArt.nachfassen, FaelligArt.brief]);
  });

  test('Erinnerungen: mehrfach vorher, nur Zukunft, stabile Ids', () {
    final f = faelligkeiten(
        briefe: [brief('a', frist: DateTime(2026, 11, 2))],
        vertraege: const [],
        belege: const [],
        termine: const [],
        heute: heute);
    final e = ErinnerungsEinstellungen(tageVorher: [7, 3, 1, 0], stunde: 9);
    final plan = erinnerungenPlanen(f, e, jetzt: DateTime(2026, 10, 28, 12));
    // 7 Tage vorher (26.10.) liegt in der Vergangenheit.
    expect(plan.map((x) => x.zeit), [
      DateTime(2026, 10, 30, 9),
      DateTime(2026, 11, 1, 9),
      DateTime(2026, 11, 2, 9),
    ]);
    expect(plan.last.titel, startsWith('Heute fällig'));
    expect(plan.first.titel, startsWith('In 3 Tagen'));
    final nochmal = erinnerungenPlanen(f, e, jetzt: DateTime(2026, 10, 28, 12));
    expect(nochmal.map((x) => x.id), plan.map((x) => x.id));
    expect(erinnerungenPlanen(f, ErinnerungsEinstellungen(aktiv: false), jetzt: heute), isEmpty);
  });

  test('Termin mit Uhrzeit im Brief erkennen', () {
    final t = termineFinden('Wir laden Sie zu einem persönlichen Termin am 12.11.2026 um 10:30 Uhr ein.');
    expect(t.single.zeit, DateTime(2026, 11, 12, 10, 30));
    expect(termineFinden('Zahlbar bis 12.11.2026, 10:30 Uhr Kassenschluss'), isEmpty);
  });

  test('Kalendereintrag (ICS)', () {
    final ics = icsErstellen('Frist: Steuer', DateTime(2026, 11, 2), beschreibung: 'Zahlen; bitte', jetzt: heute);
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('DTSTART;VALUE=DATE:20261102'));
    expect(ics, contains('DTEND;VALUE=DATE:20261103'));
    expect(ics, contains('DESCRIPTION:Zahlen\; bitte'));
    final mitZeit = icsErstellen('Termin', DateTime(2026, 11, 12, 10, 30), ganztags: false, jetzt: heute);
    expect(mitZeit, contains('DTSTART:20261112T103000'));
  });

  test('Wochenüberblick-Text', () {
    expect(wochenText(const [], heute: heute), startsWith('Diese Woche ist nichts fällig'));
  });
}
