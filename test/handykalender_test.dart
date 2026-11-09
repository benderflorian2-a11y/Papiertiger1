import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/handykalender.dart';
import 'package:papiertiger/logic/zeitplan.dart';

void main() {
  final heute = DateTime(2026, 11, 9);

  test('Nur Zukünftiges kommt in den Kalender, mit Vorsatz und Uhrzeit-Erkennung', () {
    final f = [
      Faelligkeit(FaelligArt.brief, DateTime(2026, 11, 20), 'Otto', 'Rechnung zahlen', 'b1'),
      Faelligkeit(FaelligArt.brief, DateTime(2026, 11, 1), 'Alt', 'vorbei', 'b2'),
      Faelligkeit(FaelligArt.termin, DateTime(2026, 11, 12, 10, 30), 'Zahnarzt', 'Kontrolle', 't1'),
      Faelligkeit(FaelligArt.vertrag, DateTime(2030, 1, 1), 'Fernab', 'zu weit weg', 'v1'),
      Faelligkeit(FaelligArt.vertrag, DateTime(2026, 12, 1), 'Strom', 'Kündigen bis 01.12.', 'v2'),
    ];
    final e = kalenderEintraegeAus(f, heute: heute);
    expect(e.map((x) => x.titel), ['Frist: Otto', 'Zahnarzt', 'Kündigen: Strom']);
    expect(e[0].ganztags, isTrue);
    expect(e[1].ganztags, isFalse);
  });

  test('Plan: nur Neues eintragen, Erledigtes entfernen, Gelöschtes nicht wieder anlegen', () {
    final a = KalenderEintrag('a', 'A', DateTime(2026, 11, 20), true, '');
    final b = KalenderEintrag('b', 'B', DateTime(2026, 11, 21), true, '');
    final c = KalenderEintrag('c', 'C', DateTime(2026, 11, 22), true, '');
    final plan = kalenderPlan([a, b, c], {'a': 11, 'b': -2, 'alt': 7});
    expect(plan.neu.map((e) => e.key), ['c']);
    expect(plan.loeschen, ['alt']);
  });

  test('Verschobene Frist ergibt einen neuen Schlüssel (alter Eintrag wird ersetzt)', () {
    Faelligkeit mit(DateTime d) => Faelligkeit(FaelligArt.brief, d, 'Otto', 'zahlen', 'b1');
    final alt = kalenderEintraegeAus([mit(DateTime(2026, 11, 20))], heute: heute).single;
    final neu = kalenderEintraegeAus([mit(DateTime(2026, 11, 25))], heute: heute).single;
    expect(alt.key, isNot(neu.key));
    final plan = kalenderPlan([neu], {alt.key: 5});
    expect(plan.neu.single.key, neu.key);
    expect(plan.loeschen, [alt.key]);
  });

  test('Wochenmeldung nur, wenn etwas ansteht', () {
    expect(wochePassiert([], heute: heute), isFalse);
    expect(wochePassiert([Faelligkeit(FaelligArt.brief, DateTime(2026, 12, 20), 'X', '', 'b')], heute: heute), isFalse);
    expect(wochePassiert([Faelligkeit(FaelligArt.brief, DateTime(2026, 11, 12), 'X', '', 'b')], heute: heute), isTrue);
  });
}
