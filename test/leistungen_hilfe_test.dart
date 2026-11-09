import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/behoerden.dart';
import 'package:papiertiger/logic/inhalte.dart';
import 'package:papiertiger/logic/leistungen_hilfe.dart';

void main() {
  final heute = DateTime(2026, 11, 9);

  test('Antragsschreiben nutzt das Profil und die Antworten', () {
    final p = Profil(name: 'Florian Bender', adresse: 'Lindenweg 5\n57072 Siegen', extra: {'geburtsdatum': '01.02.1990', 'iban': 'DE00 1234'});
    final wohngeld = leistungen.firstWhere((l) => l.titel == 'Wohngeld');
    final t = leistungsSchreiben(wohngeld, p, {'miete': true, 'kinder': true}, heute: heute);
    expect(t, contains('Antrag auf Wohngeld'));
    expect(t, contains('Florian Bender'));
    expect(t, contains('Lindenweg 5, 57072 Siegen'));
    expect(t, contains('Geburtsdatum: 01.02.1990'));
    expect(t, contains('Bankverbindung (IBAN): DE00 1234'));
    expect(t, contains('Kind unter 25 Jahren'));
    expect(t, contains('Datum: 09.11.2026'));
    expect(t, contains(wohngeld.stelle));
  });

  test('Fehlende Angaben werden markiert und gemeldet', () {
    final p = Profil(name: 'Mia Muster');
    final l = leistungen.first;
    final t = leistungsSchreiben(l, p, {}, heute: heute);
    expect(t, contains('[bitte ergänzen]'));
    expect(leistungsAngabenFehlen(p), ['Anschrift', 'Geburtsdatum']);
    expect(leistungsAngabenFehlen(Profil(name: 'A', adresse: 'B', extra: {'geburtsdatum': '1'})), isEmpty);
  });

  test('Neue Leistungen reagieren auf die neuen Fragen', () {
    Set<String> titel(Map<String, bool> a) => {for (final l in leistungen.where((l) => l.bedingung(a))) l.titel};
    expect(titel({'schwanger': true}), contains('Mutterschaftsgeld'));
    expect(titel({'krank': true, 'arbeitnehmer': true}), contains('Krankengeld'));
    expect(titel({'weiterbildung': true}), contains('Förderung für Weiterbildung'));
    expect(titel({}), isEmpty);
    expect(leistungsFragen.map((f) => f.key), containsAll(['schwanger', 'krank', 'selbststaendig', 'weiterbildung']));
  });

  test('Behördengänge: Direktlinks sind https und gehören zu echten Checklisten', () {
    final keys = behoerdenChecklisten.map((c) => c.key).toSet();
    expect(keys, containsAll(['arbeitslos', 'geburt', 'heirat']));
    for (final e in behoerdenLinks.entries) {
      expect(keys, contains(e.key));
      for (final (_, url) in e.value) {
        expect(url.startsWith('https://'), isTrue, reason: url);
      }
    }
    expect(behoerdenWarum.keys.every(keys.contains), isTrue);
  });
}
