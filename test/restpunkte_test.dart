import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/behoerden.dart';
import 'package:papiertiger/logic/ki_anfragen.dart';
import 'package:papiertiger/logic/kommunikation.dart';
import 'package:papiertiger/logic/kontoauszug.dart';
import 'package:papiertiger/logic/marketing.dart';

const _auszug = '''
Kontoauszug Nr. 9/2026
Buchungstag Wert Vorgang Betrag
01.08.2026 01.08.2026 Lastschrift VODAFONE GMBH Kd-Nr 123 -39,99
03.08.2026 03.08.2026 Kartenzahlung REWE Markt -54,12
15.08.2026 15.08.2026 Gehalt Muster AG 2.450,00
01.09.2026 01.09.2026 Lastschrift VODAFONE GMBH Kd-Nr 123 -39,99
02.09.2026 02.09.2026 Folgelastschrift
NETFLIX INTERNATIONAL B.V. 13,99-
05.09.2026 05.09.2026 Kartenzahlung REWE Markt -12,30
01.10.2026 01.10.2026 Lastschrift VODAFONE GMBH Kd-Nr 123 -44,99
02.10.2026 02.10.2026 Folgelastschrift
NETFLIX INTERNATIONAL B.V. 13,99-
03.10.2026 03.10.2026 Lastschrift STADTWERKE -80,00
04.10.2026 04.10.2026 Lastschrift STADTWERKE -80,00
''';

void main() {
  test('Kontoauszug: Abbuchungen lesen, Gutschriften überspringen', () {
    final l = abbuchungenLesen(_auszug);
    expect(l.length, 9);
    expect(l.first.empfaenger, startsWith('VODAFONE'));
    expect(l.first.betrag, 39.99);
    expect(l.any((a) => a.empfaenger.contains('Gehalt')), isFalse);
    expect(l.where((a) => a.empfaenger.startsWith('NETFLIX')).length, 2);
  });

  test('Wiederkehrende und doppelte Abbuchungen', () {
    final l = abbuchungenLesen(_auszug);
    final v = Vertrag(id: 'v', anbieter: 'Netflix', art: 'Streaming', beginn: DateTime(2024, 1, 1));
    final w = wiederkehrendeAbbuchungen(l, vertraege: [v]);
    final namen = w.map((x) => x.empfaenger.split(' ').first).toList();
    expect(namen, containsAll(['VODAFONE', 'NETFLIX']));
    expect(namen, isNot(contains('REWE'))); // Beträge schwanken zu stark
    final voda = w.firstWhere((x) => x.empfaenger.startsWith('VODAFONE'));
    expect(voda.rhythmus, 'monatlich');
    expect(voda.preisGeaendert, isTrue);
    expect(voda.letzterBetrag, 44.99);
    expect(voda.vertrag, isNull);
    expect(w.firstWhere((x) => x.empfaenger.startsWith('NETFLIX')).vertrag, v);
    final d = doppelteAbbuchungen(l);
    expect(d.length, 1);
    expect(d.single.$1.empfaenger, 'STADTWERKE');
  });

  test('Anlagen werden im Brief vermerkt', () {
    var t = 'Sehr geehrte Damen und Herren,\n\nanbei die Unterlagen.\n\nMit freundlichen Grüßen\nMax';
    t = anlagenVermerk(t, 'Mietvertrag');
    expect(t, endsWith('Max\n\nAnlagen:\n- Mietvertrag'));
    t = anlagenVermerk(t, 'Gehaltsnachweis');
    expect(t, endsWith('Anlagen:\n- Mietvertrag\n- Gehaltsnachweis'));
    expect(anlagenVermerk(t, 'Mietvertrag'), t);
    expect(anlagenVermerk('Text\n\nAnlage\n- A\n\nGruß', 'B'), 'Text\n\nAnlagen:\n- A\n- B\n\nGruß');
  });

  test('Diktat-Anfrage enthält Diktat, Absender und Regeln', () {
    final a = diktatAnfrage('äh also die Heizung ist kaputt', Profil(name: 'Max Muster', adresse: 'Weg 1, 12345 Ort'));
    expect(a, contains('die Heizung ist kaputt'));
    expect(a, contains('Max Muster, Weg 1, 12345 Ort'));
    expect(a, contains('Erfinde keine Fakten'));
    expect(diktatAnfrage('x', Profil(), art: 'E-Mail'), contains('eine fertige E-Mail'));
  });

  test('Umfrage wird ausgezählt', () {
    const csv = 'Zeitstempel;Wie zufrieden?;Wieder buchen?\n'
        '1.1.;sehr;ja\n2.1.;sehr;ja\n3.1.;mittel;nein\n4.1.;sehr;ja';
    final z = umfrageZaehlen(csv);
    expect(z, contains('4 Antworten'));
    expect(z, contains('- sehr: 3 (75 %)'));
    expect(z, contains('- nein: 1 (25 %)'));
    expect(z, isNot(contains('Zeitstempel')));
    expect(umfrageZaehlen('nur Text ohne Tabelle'), isEmpty);
  });

  test('Behörden-Checklisten haben Punkte und bei Fristen eine Quelle', () {
    expect(behoerdenChecklisten.map((c) => c.key).toSet().length, behoerdenChecklisten.length);
    for (final c in behoerdenChecklisten) {
      expect(c.punkte, isNotEmpty);
      if (c.frist.isNotEmpty && c.key != 'auto') expect(c.quelle, isNotEmpty, reason: c.key);
    }
    expect(behoerdenChecklisten.firstWhere((c) => c.key == 'ummelden').quelle, contains('Bundesmeldegesetz'));
  });

  test('Zahlungseingänge werden offenen Rechnungen zugeordnet', () {
    const auszug = '''
Alter Kontostand 01.10.2026 1.000,00
05.10.2026 05.10.2026 Gutschrift Familie Meier 238,00
RE 2026-007 Bad
06.10.2026 06.10.2026 Gutschrift Hans Huber 59,50
07.10.2026 07.10.2026 Lastschrift VODAFONE -39,99
''';
    final g = gutschriftenLesen(auszug);
    expect(g.map((x) => x.betrag), [238.0, 59.5]);
    Rechnung r(String id, String nr, double preis) => Rechnung(
        id: id, art: 'rechnung', nummer: nr, kundeId: 'k', datum: DateTime(2026, 10, 1),
        positionen: [Position(text: 'Arbeit', preis: preis)]);
    final rechnungen = [r('a', '2026-007', 200), r('b', '2026-008', 50), r('c', '2026-009', 70)..bezahltAm = DateTime(2026, 10, 2)];
    final t = zahlungenZuordnen(rechnungen, g, kleinunternehmer: false);
    expect(t.length, 2);
    expect(t[0].$1.id, 'a');
    expect(t[0].$3, contains('Rechnungsnummer'));
    expect(t[1].$1.id, 'b'); // 50 + 19 % = 59,50
    expect(t[1].$2.von, contains('Huber'));
  });

  test('Folgeaufgaben nach erledigten Aufgaben', () {
    expect(folgeaufgabe('Antrag beim Jobcenter einreichen'), ('Auf Antwort warten – nachfassen, falls nichts kommt', 28));
    expect(folgeaufgabe('Vertrag unterschreiben')?.$1, 'Unterschriebenes Dokument zurückschicken');
    expect(folgeaufgabe('Gehaltsnachweise heraussuchen')?.$1, 'Unterlagen einreichen');
    expect(folgeaufgabe('Kündigung abschicken')?.$2, 14);
    expect(folgeaufgabe('Betrag überweisen'), isNull);
  });
}
