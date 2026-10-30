import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/eingang.dart';

Brief _b(String id, String typ, {String text = '', double? betrag, DateTime? frist, DateTime? erstellt, bool erledigt = false}) =>
    Brief(
      id: id,
      erstellt: erstellt ?? DateTime(2026, 10, 30),
      kategorie: 'sonstiges',
      typ: typ,
      text: text,
      erklaerung: '',
      betrag: betrag,
      frist: frist,
      erledigt: erledigt,
    );

void main() {
  final heute = DateTime(2026, 11, 2);

  test('Nächster Schritt je Brief', () {
    expect(naechsterSchritt(_b('1', 'rechnung', betrag: 49.9, frist: DateTime(2026, 11, 10)), heute: heute).art, 'bezahlen');
    expect(naechsterSchritt(_b('1', 'rechnung', betrag: 49.9, frist: DateTime(2026, 11, 10)), heute: heute).text, '49,90 € bis 10.11.');
    expect(naechsterSchritt(_b('2', 'mahnbescheid'), heute: heute).art, 'widerspruch');
    expect(naechsterSchritt(_b('3', 'mitwirkung', frist: DateTime(2026, 11, 20)), heute: heute).label, 'Unterlagen schicken');
    expect(naechsterSchritt(_b('4', 'anhoerung'), heute: heute).art, 'antworten');
    expect(
        naechsterSchritt(_b('5', 'schreiben', text: 'Wir laden Sie zu einem Termin am 12.11.2026 um 10:30 Uhr ein.'), heute: heute)
            .text,
        'Am 12.11. um 10:30 Uhr');
    expect(naechsterSchritt(_b('6', 'erhoehung'), heute: heute).art, 'pruefen');
    expect(naechsterSchritt(_b('7', 'renteninformation'), heute: heute).art, 'ablegen');
  });

  test('Posteingang: nur neue, offene Post, Dringendes zuerst', () {
    final l = posteingang([
      _b('alt', 'rechnung', erstellt: DateTime(2026, 8, 1)),
      _b('fertig', 'rechnung', erledigt: true),
      _b('info', 'renteninformation'),
      _b('mahn', 'mahnung', betrag: 20),
    ], heute: heute);
    expect(l.map((b) => b.id), ['mahn', 'info']);
  });
}
