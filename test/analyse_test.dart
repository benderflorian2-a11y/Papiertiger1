import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/brief_analyse.dart';
import 'package:papiertiger/logic/vertrag_logik.dart';

void main() {
  final heute = DateTime(2026, 10, 28);

  test('Steuerbescheid: Absender, Typ, Betrag, Frist, Steuernummer', () {
    const text = '''
Finanzamt Köln-Mitte
Datum: 20.10.2026
Steuernummer: 214/5678/9012
Bescheid für 2025 über Einkommensteuer
Festgesetzt werden 1.234,56 €.
Nachzahlung: 345,00 €
Bitte zahlen Sie den Betrag bis zum 23.11.2026.
Gegen diesen Bescheid ist der Einspruch zulässig. Er ist innerhalb eines Monats einzulegen.
Bankverbindung: Sparkasse KölnBonn
''';
    final a = analysiereBrief(text, heute: heute);
    expect(a.kategorie.key, 'finanzamt');
    expect(a.typ.key, 'bescheid');
    expect(a.frist, DateTime(2026, 11, 23));
    expect(a.fristUnsicher, isFalse);
    expect(a.betrag, 345.00);
    expect(a.aktenzeichen, 'Steuernummer: 214/5678/9012');
    expect(a.briefDatum, DateTime(2026, 10, 20));
    expect(a.erklaerung, contains('vom Finanzamt'));
    expect(a.aufgaben.any((t) => t.contains('345,00 €')), isTrue);
  });

  test('Mahnung mit Inkasso', () {
    const text = '''
Muster Inkasso GmbH
Forderungsmanagement
Kassenzeichen: AB-99881
Mahnung
Hauptforderung 89,90 EUR
Mahngebühr 5,00 EUR
Gesamtbetrag 94,90 EUR
zahlbar bis 05.11.2026
''';
    final a = analysiereBrief(text, heute: heute);
    expect(a.kategorie.key, 'inkasso');
    expect(a.typ.key, 'mahnung');
    expect(a.betrag, 94.90);
    expect(a.frist, DateTime(2026, 11, 5));
    expect(a.aufgaben.first, contains('Forderung prüfen'));
  });

  test('Relative Frist wird berechnet und als unsicher markiert', () {
    const text = '''
Jobcenter Musterstadt
12.10.2026
Bitte reichen Sie die fehlenden Unterlagen innerhalb von zwei Wochen ein.
''';
    final a = analysiereBrief(text, heute: heute);
    expect(a.kategorie.key, 'jobcenter');
    expect(a.typ.key, 'mitwirkung');
    expect(a.frist, DateTime(2026, 10, 26));
    expect(a.fristUnsicher, isTrue);
  });

  test('Alter Zeitraum ist keine Frist', () {
    const text = '''
Stadtwerke Musterstadt
Jahresabrechnung Strom
Datum 15.10.2026
Abrechnungszeitraum 01.01.2025 bis 31.12.2025
Ihr Guthaben: 42,10 €
''';
    final a = analysiereBrief(text, heute: heute);
    expect(a.kategorie.key, 'energie');
    expect(a.frist, isNull);
    expect(a.istGuthaben, isTrue);
  });

  test('Kassenbon: Summe, Datum, Händler', () {
    const text = 'ELEKTRO MARKT\nFiliale 12\n03.10.2026 14:22\nKopfhörer 79,99\nSUMME EUR 79,99\n';
    expect(summeFinden(text), 79.99);
    expect(erstesDatum(text), DateTime(2026, 10, 3));
    expect(ersteZeile(text), 'ELEKTRO MARKT');
  });

  test('Kündigung: vor Ende der Mindestlaufzeit', () {
    final v = Vertrag(
        id: '1', anbieter: 'Handy', art: 'Handy', beginn: DateTime(2025, 6, 1),
        laufzeitMonate: 24, fristWert: 1);
    final info = kuendigungsInfo(v, heute: heute);
    expect(info.endetAm, DateTime(2027, 6, 1));
    expect(info.kuendigenBis, DateTime(2027, 5, 1));
  });

  test('Kündigung: nach Mindestlaufzeit, neuer Vertrag monatlich', () {
    final v = Vertrag(
        id: '2', anbieter: 'Fitness', art: 'Fitnessstudio', beginn: DateTime(2023, 1, 15),
        laufzeitMonate: 12, fristWert: 3);
    final info = kuendigungsInfo(v, heute: heute);
    expect(info.kuendigenBis, heute);
    expect(info.endetAm, DateTime(2026, 11, 28));
  });

  test('Kündigung: alter Vertrag verlängert sich um 12 Monate', () {
    final v = Vertrag(
        id: '3', anbieter: 'Zeitung', art: 'Zeitschrift', beginn: DateTime(2020, 3, 1),
        laufzeitMonate: 24, fristWert: 3);
    final info = kuendigungsInfo(v, heute: heute);
    expect(info.endetAm, DateTime(2027, 3, 1));
    expect(info.kuendigenBis, DateTime(2026, 12, 1));
  });
}
