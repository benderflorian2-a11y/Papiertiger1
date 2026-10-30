import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/logic/projekte.dart';

void main() {
  Projekt p() => Projekt(id: 'p', name: 'Bad Meier', adresse: 'Gartenweg 3, 12345 Ort', berichte: [
        Baubericht(id: 'r1', art: 'regie', datum: DateTime(2026, 10, 20), text: 'Zusätzliche Steckdose gesetzt\nmit Schlitz', stunden: 1.5, material: 'Steckdose, Kabel'),
        Baubericht(id: 'r2', art: 'regie', datum: DateTime(2026, 10, 18), text: 'Rohr verlegt', stunden: 2, abgerechnet: true),
        Baubericht(id: 'a1', art: 'abnahme', datum: DateTime(2026, 10, 25), text: 'Bad komplett'),
      ], tagebuch: [
        Tagesbericht(datum: DateTime(2026, 10, 21), wetter: 'Regen', personen: 'Anna, Ben', arbeiten: 'Fliesen Boden'),
        Tagesbericht(datum: DateTime(2026, 10, 20), arbeiten: 'Abbruch'),
      ]);

  test('Offene Regieberichte werden zu Rechnungspositionen', () {
    final offen = offeneRegieberichte(p());
    expect(offen.map((b) => b.id), ['r1']);
    final pos = regiePositionen(offen, stundensatz: 55);
    expect(pos.length, 2);
    expect(pos[0].text, 'Regiearbeiten 20.10.2026: Zusätzliche Steckdose gesetzt');
    expect(pos[0].menge, 1.5);
    expect(pos[0].preis, 55);
    expect(pos[1].text, contains('Steckdose, Kabel'));
    expect(pos[1].preis, 0);
  });

  test('Bautagebuch als Text, nach Datum sortiert', () {
    final t = bautagebuchText(p());
    expect(t, startsWith('Bautagebuch Bad Meier – Gartenweg 3, 12345 Ort'));
    expect(t.indexOf('20.10.2026'), lessThan(t.indexOf('21.10.2026')));
    expect(t, contains('21.10.2026 · Wetter: Regen\nAnwesend: Anna, Ben\nArbeiten: Fliesen Boden'));
    expect(bautagebuchText(p(), von: DateTime(2026, 10, 21)), isNot(contains('Abbruch')));
  });

  test('Fotos, Tagebuch und Berichte überstehen Speichern', () {
    final x = p()
      ..fotos.add(Baufoto(pfad: '/a.jpg', datum: DateTime(2026, 10, 20), text: 'vorher'))
      ..berichte.first.unterschrift = '/u.png'
      ..berichte.first.unterschriftName = 'Erika';
    final y = Projekt.fromJson(x.toJson());
    expect(y.adresse, 'Gartenweg 3, 12345 Ort');
    expect(y.fotos.single.text, 'vorher');
    expect(y.tagebuch.first.wetter, 'Regen');
    expect(y.berichte.first.unterschriftName, 'Erika');
    expect(y.berichte[1].abgerechnet, isTrue);
    expect(y.berichte.last.titel, 'Abnahmeprotokoll');
    // alte Projekte ohne die neuen Felder
    final alt = Projekt.fromJson({'id': 'q', 'name': 'Alt'});
    expect(alt.fotos, isEmpty);
    expect(alt.adresse, '');
  });
}
