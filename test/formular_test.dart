import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/formular.dart';

void main() {
  final p = Profil(
    name: 'Max Mustermann',
    adresse: 'Musterweg 1\n12345 Musterstadt',
    extra: {'geburtsdatum': '01.02.1980', 'iban': 'DE00 1234 5678 9000 0000 00'},
  );

  test('Felder ohne KI erkennen und aus dem Profil füllen', () {
    const text = '''
Antrag auf Wohngeld
Vorname: ____________
Nachname: ____________
Geburtsdatum: __________
Straße, Hausnummer: ___________
Telefon: ________
IBAN: ____________
Ort, Datum, Unterschrift
''';
    final h = formularErkennen(text, p);
    final werte = {for (final f in h.felder) f.label: f.wert};
    expect(werte['Vorname'], 'Max');
    expect(werte['Nachname'], 'Mustermann');
    expect(werte['Geburtsdatum'], '01.02.1980');
    expect(werte['Straße, Hausnummer'], 'Musterweg 1');
    expect(werte['Telefon'], isNull);
    expect(werte['IBAN'], 'DE00 1234 5678 9000 0000 00');
    expect(h.unterschriften, ['Ort, Datum, Unterschrift']);
    expect(h.fehlt, ['Telefon']);
  });

  test('KI-Antwort zur Ausfüllhilfe lesen', () {
    final h = formularAntwortLesen('''
FELD: Vorname | WERT: Max | HINWEIS:
FELD: Telefonnummer | WERT: FEHLT | HINWEIS: tagsüber erreichbar
UNTERSCHRIFT:
- Seite 2 unten
ANLAGEN:
- Mietvertrag
''');
    expect(h.felder.first.wert, 'Max');
    expect(h.felder[1].wert, isNull);
    expect(h.felder[1].hinweis, 'tagsüber erreichbar');
    expect(h.unterschriften, ['Seite 2 unten']);
    expect(h.fehlt, ['Telefonnummer', 'Anlage: Mietvertrag']);
  });
}
