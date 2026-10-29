import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/antrag_logik.dart';
import 'package:papiertiger/logic/behoerden.dart';
import 'package:papiertiger/logic/inhalte.dart';

const _bescheid = 'Bescheid über Wohngeld\n\nRechtsbehelfsbelehrung:\n'
    'Gegen diesen Bescheid kann innerhalb eines Monats nach Bekanntgabe Widerspruch erhoben werden. '
    'Der Widerspruch ist bei der Stadt Köln einzulegen.';

void main() {
  test('Ostern und bundesweite Feiertage', () {
    expect(ostersonntag(2025), DateTime(2025, 4, 20));
    expect(ostersonntag(2026), DateTime(2026, 4, 5));
    expect(ostersonntag(2027), DateTime(2027, 3, 28));
    final f = feiertage(2026);
    expect(f, containsAll([DateTime(2026, 4, 3), DateTime(2026, 4, 6), DateTime(2026, 5, 14), DateTime(2026, 5, 25)]));
    expect(naechsterWerktag(DateTime(2027, 1, 1)), DateTime(2027, 1, 4));
    expect(naechsterWerktag(DateTime(2026, 11, 24)), DateTime(2026, 11, 24));
  });

  test('Widerspruchsfrist: Briefdatum + 4 Tage + 1 Monat', () {
    final r = rechtsbehelfFinden(_bescheid, briefDatum: DateTime(2026, 10, 20))!;
    expect(r.art, 'Widerspruch');
    expect(r.quelle, startsWith('Gegen diesen Bescheid kann innerhalb eines Monats'));
    expect(r.bekanntgabe, DateTime(2026, 10, 24));
    expect(r.fristEnde, DateTime(2026, 11, 24));
    expect(r.verschoben, isFalse);
  });

  test('Fristende am Feiertag wird auf den nächsten Werktag verschoben', () {
    final r = rechtsbehelfFinden(_bescheid, briefDatum: DateTime(2026, 11, 27))!;
    expect(r.bekanntgabe, DateTime(2026, 12, 1));
    expect(r.fristEnde, DateTime(2027, 1, 4));
    expect(r.verschoben, isTrue);
  });

  test('Späterer Zugang zählt, Einspruch beim Finanzamt, ohne Datum keine Rechnung', () {
    final r = rechtsbehelfFinden(_bescheid, briefDatum: DateTime(2026, 10, 20), zugang: DateTime(2026, 10, 28))!;
    expect(r.bekanntgabe, DateTime(2026, 10, 28));
    expect(r.fristEnde, DateTime(2026, 11, 30));
    final e = rechtsbehelfFinden('Sie können innerhalb eines Monats nach Bekanntgabe Einspruch einlegen.')!;
    expect(e.art, 'Einspruch');
    expect(e.fristEnde, isNull);
    expect(rechtsbehelfFinden('Bitte zahlen Sie innerhalb eines Monats.'), isNull);
  });

  test('Antrag: nur eigene Angaben aus dem Profil, Nachfrage-Termin', () {
    final p = Profil(name: 'Florian Bender', adresse: 'Lindenweg 5\n50667 Köln', extra: {'iban': 'DE00 1234'});
    final kg = antragMitKey('kindergeld')!;
    expect(antragVorbelegen('Dein Name', p), 'Florian Bender');
    expect(antragVorbelegen('Deine IBAN', p), 'DE00 1234');
    expect(antragVorbelegen('Vor- und Nachname des Kindes', p), isNull);
    final i = kg.fragen.indexOf('Vor- und Nachname des Kindes');
    expect(antragAntwort(kg, i, {}, p), '');
    expect(antragAntwort(kg, 0, {'antrag:kindergeld:0': 'Anders'}, p), 'Anders');
    expect(antragAlsText(kg, {}, p), contains('Deine Anschrift\nLindenweg 5, 50667 Köln'));
    final t = antragNachfragen(kg, DateTime(2026, 10, 29));
    expect(t.datum, DateTime(2026, 12, 10, 9));
    expect(t.art, 'Behörde');
    for (final l in leistungen) {
      if (l.antrag != null) expect(antragMitKey(l.antrag!), isNotNull, reason: l.titel);
    }
  });
}
