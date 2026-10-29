import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/ki_auswertung.dart';
import 'package:papiertiger/logic/ordnung.dart';

Brief _b(String id,
        {String kategorie = 'finanzamt',
        String typ = 'bescheid',
        String text = 'Text',
        String? absender = 'Finanzamt Köln',
        String? az,
        DateTime? datum,
        DateTime? frist,
        double? betrag,
        bool guthaben = false}) =>
    Brief(
      id: id,
      erstellt: DateTime(2026, 10, 1),
      kategorie: kategorie,
      typ: typ,
      text: text,
      erklaerung: '',
      absenderName: absender,
      aktenzeichen: az,
      briefDatum: datum,
      frist: frist,
      betrag: betrag,
      guthaben: guthaben,
    );

void main() {
  final heute = DateTime(2026, 10, 28);

  test('Titel, Ordner und Aufbewahrung', () {
    final b = _b('1', datum: DateTime(2026, 10, 20));
    expect(autoTitel(b), 'Finanzamt Köln – Bescheid');
    expect(ordnerFuer(b).key, 'steuern');
    expect(aufbewahrung(b).bis, DateTime(2037, 1, 1));
    b.titel = 'Steuer 2025';
    expect(titelVon(b), 'Steuer 2025');
    expect(aufbewahrung(_b('2', kategorie: 'rente')).bis, isNull);
  });

  test('Dringlichkeit', () {
    expect(dringlichkeit(_b('1', typ: 'schreiben', kategorie: 'rente'), heute: heute), Dringlichkeit.niedrig);
    expect(dringlichkeit(_b('2', frist: DateTime(2026, 12, 1)), heute: heute), Dringlichkeit.mittel);
    expect(dringlichkeit(_b('3', frist: DateTime(2026, 11, 2)), heute: heute), Dringlichkeit.hoch);
    expect(dringlichkeit(_b('4', kategorie: 'inkasso', typ: 'schreiben'), heute: heute), Dringlichkeit.hoch);
    final ki = _b('5', typ: 'schreiben', kategorie: 'sonstiges')..kiDringlichkeit = 2;
    expect(dringlichkeit(ki, heute: heute), Dringlichkeit.hoch);
    final fertig = _b('6', kategorie: 'inkasso')..erledigt = true;
    expect(dringlichkeit(fertig, heute: heute), Dringlichkeit.niedrig);
  });

  test('Duplikate', () {
    final lang = List.generate(60, (i) => 'wort$i').join(' ');
    final a = _b('a', text: lang);
    final b = _b('b', text: '$lang extra');
    final c = _b('c', text: List.generate(60, (i) => 'anders$i').join(' '));
    expect(duplikatFinden(b, [a, c])?.id, 'a');
    expect(duplikatFinden(c, [a])?.id, isNull);

    final x = _b('x', az: 'Steuernummer: 123/456', datum: DateTime(2026, 1, 1), betrag: 10);
    final y = _b('y', az: 'Steuernummer: 123/456', datum: DateTime(2026, 1, 1), betrag: 10);
    expect(duplikatFinden(y, [x])?.id, 'x');
  });

  test('Vorgänge nach Aktenzeichen und Absender', () {
    final akten = aktenBilden([
      _b('1', az: 'Steuernummer: 214/5678/9012', datum: DateTime(2026, 1, 1)),
      _b('2', az: 'Steuernummer: 214 5678 9012', datum: DateTime(2026, 5, 1)),
      _b('3', kategorie: 'krankenkasse', absender: 'AOK Rheinland', datum: DateTime(2026, 3, 1)),
      _b('4', kategorie: 'krankenkasse', absender: 'AOK Rheinland', datum: DateTime(2026, 4, 1)),
    ]);
    expect(akten, hasLength(2));
    final steuer = akten.firstWhere((a) => a.schluessel.startsWith('az:'));
    expect(steuer.briefe.map((b) => b.id), ['2', '1']);
    expect(akten.firstWhere((a) => a.schluessel.startsWith('abs:')).briefe, hasLength(2));
  });

  test('Verlangte Unterlagen werden erkannt', () {
    const text = '''
Jobcenter Musterstadt
Bitte reichen Sie folgende Unterlagen bis zum 15.11.2026 ein:
- Kontoauszüge der letzten 3 Monate
- Mietbescheinigung
- Lohnabrechnung Oktober
Mit freundlichen Grüßen
''';
    expect(unterlagenFinden(text),
        ['Kontoauszüge der letzten 3 Monate', 'Mietbescheinigung', 'Lohnabrechnung Oktober']);
    expect(unterlagenFinden('Kein Hinweis auf irgendwas'), isEmpty);
  });

  test('KI liefert Dringlichkeit, Unterlagen und Empfänger', () {
    const antwort = '''
KURZFASSUNG: Das Jobcenter braucht noch Unterlagen von dir, damit es dein Bürgergeld weiter zahlen kann.
GELD: KEINS
FRIST: 15.11.2026
DRINGLICHKEIT: HOCH
UNTERLAGEN:
- Kontoauszüge
- Mietbescheinigung
FÜR: Max Mustermann
''';
    final k = kiAntwortLesen(antwort);
    expect(k.dringlichkeit, 2);
    expect(k.unterlagen, ['Kontoauszüge', 'Mietbescheinigung']);
    expect(k.fuer, 'Max Mustermann');

    final b = _b('j', kategorie: 'jobcenter', text: 'bis zum 15.11.2026 Kontoauszüge');
    b.unterlagen.add(Aufgabe('Mietbescheinigung'));
    kiUebernehmen(b, k);
    expect(b.kiDringlichkeit, 2);
    expect(b.person, 'Max Mustermann');
    expect(b.unterlagen.map((u) => u.text), ['Mietbescheinigung', 'Kontoauszüge']);
  });
}
