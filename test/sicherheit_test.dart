import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/data/store.dart';
import 'package:papiertiger/logic/protokoll.dart';
import 'package:papiertiger/logic/tresor.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> _k(int x) => List<int>.filled(32, x);

Rechnung _r(String id, {String nummer = '2026-001'}) => Rechnung(
      id: id,
      art: 'rechnung',
      nummer: nummer,
      kundeId: 'k',
      datum: DateTime(2026, 10, 1),
      positionen: [Position(text: 'Arbeit', menge: 2, einheit: 'Std.', preis: 50)],
    );

void main() {
  test('Tresor ver- und entschlüsselt, erkennt Manipulation', () {
    final t = Tresor(_k(7));
    final g = t.verschluesseln('Hallo Tiger äöü');
    expect(istVerschluesselt(g), isTrue);
    expect(g.contains('Hallo'), isFalse);
    expect(t.entschluesseln(g), 'Hallo Tiger äöü');
    expect(t.verschluesseln('x'), isNot(t.verschluesseln('x'))); // neue Nonce je Mal
    expect(t.entschluesseln('alter Klartext'), 'alter Klartext');
    expect(() => Tresor(_k(8)).entschluesseln(g), throwsA(anything));
    final kaputt = '${g.substring(0, g.length - 6)}AAAAAA';
    expect(() => t.entschluesseln(kaputt), throwsA(anything));
  });

  test('PIN wird nur abgeleitet gespeichert', () async {
    final s = await pinSpeicherform('482915');
    expect(s.contains('482915'), isFalse);
    expect(await pinPruefen('482915', s), isTrue);
    expect(await pinPruefen('482916', s), isFalse);
    expect(await pinPruefen('482915', 'kaputt'), isFalse);
    expect(pinSchwach('1234'), isNotNull);
    expect(pinSchwach('111111'), isNotNull);
    expect(pinSchwach('123456'), isNotNull);
    expect(pinSchwach('654321'), isNotNull);
    expect(pinSchwach('482915'), isNull);
    expect(pinWartezeit(4), Duration.zero);
    expect(pinWartezeit(5), const Duration(seconds: 30));
    expect(pinWartezeit(6), const Duration(seconds: 60));
    expect(pinWartezeit(20), const Duration(hours: 1));
  });

  test('Protokoll ist verkettet', () {
    final l = <ProtokollEintrag>[];
    protokollieren(l, art: 'erstellt', objekt: 'Rechnung 1', text: 'angelegt', zeit: DateTime(2026, 10, 1));
    protokollieren(l, art: 'geaendert', objekt: 'Rechnung 1', text: 'bezahlt', zeit: DateTime(2026, 10, 2));
    protokollieren(l, art: 'storniert', objekt: 'Rechnung 1', text: 'storniert', zeit: DateTime(2026, 10, 3));
    expect(protokollBruch(l), isNull);
    final rund = [for (final e in l) ProtokollEintrag.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>)];
    expect(protokollBruch(rund), isNull);
    rund[1] = ProtokollEintrag(zeit: rund[1].zeit, art: rund[1].art, objekt: rund[1].objekt, text: 'anders', hash: rund[1].hash);
    expect(protokollBruch(rund), 1);
    expect(protokollBruch([l[0], l[2]]), 1); // gelöschter Eintrag
    expect(protokollCsv(l).split('\n').length, 4);
  });

  test('Rechnungsänderungen und Festschreibung', () {
    final r = _r('a');
    expect(r.festgeschrieben, isFalse);
    var stand = <String, String>{};
    var e = rechnungsAenderungen(stand, [r]);
    expect(e.single, ('erstellt', 'Rechnung 2026-001', 'angelegt'));
    stand = {r.id: jsonEncode(r.toJson())};
    r.positionen.first.preis = 60;
    expect(rechnungsAenderungen(stand, [r]).single.$3, 'Positionen geändert');
    r.festAm = DateTime(2026, 10, 2);
    expect(r.festgeschrieben, isTrue);
    expect(rechnungsAenderungen(stand, [r]).single.$3, contains('Festschreibung'));
    stand = {r.id: jsonEncode(r.toJson())};
    r.bezahltAm = DateTime(2026, 10, 5);
    expect(rechnungsAenderungen(stand, [r]).single.$3, 'als bezahlt vermerkt');
    stand = {r.id: jsonEncode(r.toJson())};
    r.datum = DateTime(2026, 9, 1);
    expect(rechnungsAenderungen(stand, [r]).single.$1, 'warnung');
    expect(rechnungsAenderungen(stand, []).single, ('warnung', 'Rechnung 2026-001', 'festgeschriebene Rechnung gelöscht'));
    final angebot = Rechnung(id: 'b', art: 'angebot', nummer: 'A-1', kundeId: 'k', datum: DateTime(2026), festAm: DateTime(2026));
    expect(angebot.festgeschrieben, isFalse);
    expect(Rechnung.fromJson(r.toJson()).festAm, DateTime(2026, 10, 2));
  });

  test('Store speichert verschlüsselt, stellt alte Daten um und überschreibt nie bei falschem Schlüssel', () async {
    SharedPreferences.setMockInitialValues({
      'profil': jsonEncode({'name': 'Erika Muster', 'adresse': 'Weg 1'}),
      'widget_text': 'Heute nichts',
    });
    final prefs = await SharedPreferences.getInstance();
    final s = AppStore(prefs, tresor: Tresor(_k(1)));
    expect(s.profil.name, 'Erika Muster');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(istVerschluesselt(prefs.getString('profil')!), isTrue);
    expect(prefs.getString('widget_text'), 'Heute nichts');

    s.rechnungen.add(_r('r1'));
    await s.geaendert();
    expect(s.protokoll.single.text, 'angelegt');
    expect(prefs.getString('rechnungen')!.contains('2026-001'), isFalse);
    expect(s.alleWerte()['profil'], contains('Erika Muster'));

    final s2 = AppStore(prefs, tresor: Tresor(_k(1)));
    expect(s2.rechnungen.single.nummer, '2026-001');
    expect(s2.lesefehler, isFalse);

    final vorher = prefs.getString('profil');
    final falsch = AppStore(prefs, tresor: Tresor(_k(2)));
    expect(falsch.lesefehler, isTrue);
    falsch.profil.name = 'Überschrieben';
    await falsch.geaendert();
    expect(prefs.getString('profil'), vorher);

    final ohne = AppStore(prefs);
    expect(ohne.lesefehler, isTrue);

    s2.rechnungen.single.versendetAm = DateTime(2026, 10, 3);
    await s2.geaendert();
    expect(() => s2.rechnungLoeschen(s2.rechnungen.single), throwsStateError);
  });
}
