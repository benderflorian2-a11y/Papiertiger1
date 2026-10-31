import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/angebotsvergleich.dart';
import 'package:papiertiger/logic/dokument_frage.dart';
import 'package:papiertiger/logic/formular_eintrag.dart';
import 'package:papiertiger/logic/ki_anfragen.dart';

Brief _b(String id, String text, {String? absender, DateTime? datum}) => Brief(
    id: id,
    erstellt: datum ?? DateTime(2026, 10, 1),
    briefDatum: datum ?? DateTime(2026, 10, 1),
    kategorie: 'sonstiges',
    typ: 'schreiben',
    text: text,
    erklaerung: '',
    absenderName: absender);

void main() {
  test('Formulareinträge speichern und Vorschläge aus dem Profil', () {
    final notizen = <String, String>{};
    formularSpeichern(notizen, 'b1', [
      FormularEintrag(seite: 0, x: 0.1, y: 0.2, text: 'Erika Muster'),
      FormularEintrag(seite: 1, x: 0.5, y: 0.9, bild: '/u.png', groesse: 0.03),
    ]);
    final l = formularLaden(notizen, 'b1');
    expect(l.length, 2);
    expect(l.first.text, 'Erika Muster');
    expect(l.last.bild, '/u.png');
    expect(l.last.groesse, 0.03);
    formularSpeichern(notizen, 'b1', []);
    expect(notizen, isEmpty);
    expect(formularLaden({'formular:x': 'kaputt'}, 'x'), isEmpty);

    final p = Profil(name: 'Erika Muster', adresse: 'Hauptstr. 5\n12345 Musterstadt', extra: {'iban': 'DE00 1234'});
    final v = Map.fromEntries(formularVorschlaege(p, heute: DateTime(2026, 10, 31)).map((e) => MapEntry(e.$1, e.$2)));
    expect(v['Vorname'], 'Erika');
    expect(v['Nachname'], 'Muster');
    expect(v['Straße'], 'Hauptstr. 5');
    expect(v['PLZ'], '12345');
    expect(v['Ort'], 'Musterstadt');
    expect(v['IBAN'], 'DE00 1234');
    expect(v['Ort, Datum'], 'Musterstadt, 31.10.2026');
  });

  test('Angebote vergleichen', () {
    final a = _b('a', '''Angebot Nr. 17
Malerarbeiten Wohnzimmer
Zwischensumme netto 2.000,00 €
MwSt. 19 % 380,00 €
Gesamtbetrag 2.380,00 €
Das Angebot ist gültig bis 05.11.2026. Zahlbar innerhalb 14 Tagen, 2 % Skonto.''', absender: 'Maler Huber');
    final b = _b('b', '''Kostenvoranschlag
Malerarbeiten inkl. Material
Summe netto 2.900,00 €
Gesamtbetrag 3.451,00 €
Bindefrist 4 Wochen''', absender: 'Farbe & Co');
    final c = _b('c', 'Angebot ohne Preis, Details folgen.', absender: 'Dritter');
    final l = angeboteVergleichen([b, c, a]);
    expect(l.map((x) => x.brief.id), ['a', 'b', 'c']);
    expect(l[0].summe, 2380);
    expect(l[0].gueltigBis, DateTime(2026, 11, 5));
    expect(l[0].skonto, 2);
    expect(l[0].zahlungsziel, 14);
    expect(l[1].summe, 3451);
    expect(l[1].gueltigBis, DateTime(2026, 10, 29));
    final h = vergleichHinweise(l, heute: DateTime(2026, 10, 31));
    expect(h.first, contains('1.071,00 €'));
    expect(h, contains('Dritter: Endbetrag nicht erkannt – bitte im Angebot nachsehen.'));
    expect(h, contains('Maler Huber: gilt nur noch bis 05.11.2026.'));
    expect(h.any((x) => x.startsWith('Farbe & Co: Angebot ist seit 29.10.2026 abgelaufen')), isTrue);
    expect(h.any((x) => x.contains('2.332,40 €')), isTrue);
    expect(istAngebot(a), isTrue);
    expect(istAngebot(_b('x', 'Ihre Stromrechnung')), isFalse);
    expect(angebotsvergleichAnfrage([a, b]), contains('Angebot 2'));
  });

  test('Frag das Dokument', () {
    const anleitung = '''Kaffeemaschine KM 300

Inbetriebnahme
Wassertank füllen und Gerät einschalten.

Entkalkung
Wenn die Lampe rot blinkt, Entkalker in den Wassertank geben und die Taste 5 Sekunden halten.

Garantie
Die Garantie beträgt 24 Monate ab Kaufdatum.''';
    final s = textstellenFinden(anleitung, 'Wie entkalke ich die Maschine?');
    expect(s.first, startsWith('Entkalkung'));
    expect(textstellenFinden(anleitung, 'Wie lange gilt die Garantie?').first, startsWith('Garantie'));
    expect(textstellenFinden(anleitung, 'und die'), isEmpty);
    final b = _b('d', anleitung);
    expect(dokumentFrageAnfrage(b, 'Wie entkalke ich?'), contains('Frage: Wie entkalke ich?'));
  });
}
