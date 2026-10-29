import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/ki_anfragen.dart';
import 'package:papiertiger/logic/ki_auswertung.dart';
import 'package:papiertiger/logic/ordnung.dart';

Brief _b(String id, String text, DateTime datum) => Brief(
      id: id,
      erstellt: datum,
      kategorie: 'telefon',
      typ: 'erhoehung',
      text: text,
      erklaerung: 'Erklärung $id',
      absenderName: 'Vodafone',
      briefDatum: datum,
      aktenzeichen: 'Kundennummer: 4711',
    );

void main() {
  test('Antwort-Anfrage enthält Ziel, Ton, Sprache, Profil und Brieftext', () {
    final a = antwortAnfrage(_b('1', 'Ihr Preis steigt auf 39,99 EUR.', DateTime(2026, 10, 1)),
        Profil(name: 'Max Muster', adresse: 'Weg 1, 12345 Ort'),
        ziel: 'Kündigen', ton: 'bestimmt', inhalt: 'Ich will zum Monatsende raus.', sprache: 'Englisch');
    expect(a, contains('Ziel des Briefs: Kündigen'));
    expect(a, contains('Ton: bestimmt'));
    expect(a, contains('Sprache des Briefs: Englisch'));
    expect(a, contains('Max Muster, Weg 1, 12345 Ort'));
    expect(a, contains('Ich will zum Monatsende raus.'));
    expect(a, contains('Ihr Preis steigt auf 39,99 EUR.'));
    expect(a, contains('Bezug: Kundennummer: 4711'));
  });

  test('Vergleich und Vorgang enthalten beide Dokumente in zeitlicher Reihenfolge', () {
    final alt = _b('alt', 'Preis 29,99 EUR', DateTime(2025, 10, 1));
    final neu = _b('neu', 'Preis 39,99 EUR', DateTime(2026, 10, 1));
    final v = vergleichAnfrage(alt, neu);
    expect(v.indexOf('29,99'), lessThan(v.indexOf('39,99')));
    final akte = aktenBilden([alt, neu]).single;
    final s = akteAnfrage(akte);
    expect(s.indexOf('Erklärung alt'), lessThan(s.indexOf('Erklärung neu')));
    expect(s, contains('Vodafone'));
  });

  test('PRÜFEN-Hinweise werden gelesen und übernommen', () {
    final k = kiAntwortLesen('''
KURZFASSUNG: Deine Stromrechnung ist da, du sollst 120 Euro nachzahlen.
PRÜFEN:
- Der Zählerstand vom Vorjahr fehlt.
- Die Summe passt nicht zu den Einzelposten.
''');
    expect(k.pruefen, hasLength(2));
    final b = _b('x', 'Text', DateTime(2026, 1, 1));
    kiUebernehmen(b, k);
    expect(b.hinweise.first, 'Der Zählerstand vom Vorjahr fehlt.');

    final ok = kiAntwortLesen('KURZFASSUNG: Alles in Ordnung, das ist nur eine Information.\nPRÜFEN:\n- Nichts');
    expect(ok.pruefen, isEmpty);
  });
}
