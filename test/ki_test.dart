import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/ki_auswertung.dart';

Brief _brief(String text) => Brief(
      id: '1',
      erstellt: DateTime(2026, 10, 28),
      kategorie: 'versicherung',
      typ: 'rechnung',
      text: text,
      erklaerung: 'alt',
      betrag: 1587.90,
      aufgaben: [Aufgabe('1.587,90 € überweisen')],
    );

void main() {
  test('Anfrage enthält den Brieftext und das Antwortformat', () {
    final a = kiAnfrage('Hallo Welt Brief');
    expect(a, contains('Hallo Welt Brief'));
    expect(a, contains('KURZFASSUNG:'));
    expect(a, contains('GELD:'));
  });

  test('Antwort mit Markdown wird gelesen', () {
    const antwort = '''
**ABSENDER:** Deutsche Rentenversicherung Bund
**ART:** Renteninformation
**KURZFASSUNG:** Das ist deine jährliche Renteninformation. Wenn du so weiter arbeitest, bekommst du später etwa 1.587,90 Euro Rente im Monat.
**BEDEUTUNG:**
- Du musst nichts bezahlen.
- Die Beträge sind vor Abzügen.
**ZU TUN:**
- Nichts
**GELD:** KEINS
**FRIST:** KEINE
''';
    final k = kiAntwortLesen(antwort);
    expect(k.absender, 'Deutsche Rentenversicherung Bund');
    expect(k.art, 'Renteninformation');
    expect(k.kurzfassung, startsWith('Das ist deine jährliche'));
    expect(k.bedeutung, hasLength(2));
    expect(k.zuTun, isEmpty);
    expect(k.geld, Geldrichtung.keins);
    expect(k.keineFrist, isTrue);
  });

  test('KEINS entfernt falschen Zahlbetrag und Überweisungs-Aufgabe', () {
    final b = _brief('Renteninformation ... 1.587,90 EUR');
    kiUebernehmen(
        b,
        KiErgebnis(
          kurzfassung: 'Das ist nur eine Information über deine spätere Rente.',
          geld: Geldrichtung.keins,
          bedeutung: ['Du musst nichts bezahlen.'],
        ));
    expect(b.betrag, isNull);
    expect(b.aufgaben.map((a) => a.text), ['Brief aufbewahren']);
    expect(b.kiFertig, isTrue);
    expect(b.bedeutung, ['Du musst nichts bezahlen.']);
  });

  test('Erfundene Zahlen und Daten werden nicht übernommen', () {
    final b = _brief('Rechnung über 49,99 EUR, zahlbar bis 15.11.2026');
    b.betrag = 49.99;
    kiUebernehmen(
        b,
        KiErgebnis(
          kurzfassung: 'Du sollst eine Rechnung bezahlen, das steht im Brief.',
          geld: Geldrichtung.zahlen,
          betrag: 4999.0,
          frist: DateTime(2026, 12, 24),
          zuTun: ['49,99 € überweisen'],
        ));
    expect(b.betrag, 49.99);
    expect(b.frist, isNull);
    expect(b.aufgaben.single.text, '49,99 € überweisen');
  });

  test('Belegte Frist und Betrag werden übernommen', () {
    final b = _brief('Rechnung über 49,99 EUR, zahlbar bis 15.11.2026');
    kiUebernehmen(
        b,
        KiErgebnis(
          kurzfassung: 'Du sollst eine Rechnung über 49,99 Euro bezahlen.',
          geld: Geldrichtung.zahlen,
          betrag: 49.99,
          frist: DateTime(2026, 11, 15),
        ));
    expect(b.betrag, 49.99);
    expect(b.guthaben, isFalse);
    expect(b.frist, DateTime(2026, 11, 15));
  });
}
