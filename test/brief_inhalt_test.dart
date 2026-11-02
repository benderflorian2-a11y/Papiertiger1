import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/brief_inhalt.dart';

const _stadtwerke = '''
Stadtwerke Musterstadt GmbH · Postfach 12 34 · 12345 Musterstadt

Herrn
Florian Bender
Hauptstraße 5
12345 Musterstadt

Kundennummer: 4711 0815
Vertragskonto 300 123 456
Zählernummer: 1ESY1160612345
Ihre Ansprechpartnerin: Frau Weber
Telefon: 0123 / 456 78-90
E-Mail: service@stadtwerke-musterstadt.de

Musterstadt, 14.10.2026

Jahresabrechnung Strom für den Zeitraum 01.10.2025 bis 30.09.2026

Sehr geehrter Herr Bender,

mit diesem Schreiben erhalten Sie Ihre Jahresabrechnung. Ihr Verbrauch lag
bei 2.450 kWh und damit unter dem Vorjahr.

Aus der Abrechnung ergibt sich ein Guthaben von 86,40 €. Wir erstatten den Betrag
bis zum 31.10.2026 auf Ihr Konto.

Ihr neuer monatlicher Abschlag beträgt ab dem 01.11.2026 64,00 €.

Bitte prüfen Sie die Angaben. Einwände können Sie innerhalb von vier Wochen erheben.

Bei Fragen stehen wir Ihnen gerne zur Verfügung.

Mit freundlichen Grüßen
Ihre Stadtwerke Musterstadt

Anlagen:
- Verbrauchsübersicht
- Preisblatt 2027

Bankverbindung: Sparkasse Musterstadt
IBAN: DE89 3704 0044 0532 0130 00
BIC: COBADEFFXXX
''';

const _termin = '''
Jobcenter Musterstadt
Aktenzeichen: 123D45678
BG-Nummer: 12345BG0012345

Einladung

Sehr geehrter Herr Bender,

bitte kommen Sie am 12.11.2026 um 09:30 Uhr in das Jobcenter, Zimmer 204.
Wir möchten mit Ihnen über Ihre berufliche Situation sprechen.
Bringen Sie bitte Ihren Personalausweis und Ihren Lebenslauf mit.
Wenn Sie ohne wichtigen Grund nicht kommen, kann Ihr Bürgergeld gemindert werden.

Mit freundlichen Grüßen
Im Auftrag
Schmidt
''';

void main() {
  test('IBAN-Prüfziffer', () {
    expect(ibanGueltig('DE89 3704 0044 0532 0130 00'), isTrue);
    expect(ibanGueltig('DE89 3704 0044 0532 0130 01'), isFalse);
  });

  group('Abrechnung der Stadtwerke', () {
    final i = inhaltLesen(_stadtwerke);
    String? wert(String label) => i.punkte.where((p) => p.label == label).map((p) => p.wert).firstOrNull;

    test('Betreff', () {
      expect(i.betreff, 'Jahresabrechnung Strom für den Zeitraum 01.10.2025 bis 30.09.2026');
    });

    test('wichtigste Aussagen aus dem Text', () {
      final alles = i.kernaussagen.join(' | ');
      expect(alles, contains('Guthaben von 86,40 €'));
      expect(alles, contains('Abschlag beträgt ab dem 01.11.2026 64,00 €'));
      expect(alles, contains('innerhalb von vier Wochen'));
      // Gruß und Floskeln nicht
      expect(alles, isNot(contains('Bei Fragen')));
      expect(alles, isNot(contains('Sehr geehrter')));
    });

    test('Nummern', () {
      expect(wert('Kundennummer'), '4711 0815');
      expect(wert('Vertragsnummer'), '300 123 456');
      expect(wert('Zählernummer'), '1ESY1160612345');
    });

    test('Bank und Kontakt', () {
      expect(wert('IBAN'), 'DE89 3704 0044 0532 0130 00');
      expect(wert('BIC'), 'COBADEFFXXX');
      expect(wert('Ansprechpartner'), 'Frau Weber');
      expect(wert('Telefon'), '0123 / 456 78-90');
      expect(wert('E-Mail'), 'service@stadtwerke-musterstadt.de');
    });

    test('Beträge und Daten mit Bedeutung', () {
      final betraege = i.punkte.where((p) => p.gruppe == 'Beträge').map((p) => '${p.label}=${p.wert}').toList();
      expect(betraege, contains('Erstattung=86,40 €'));
      expect(betraege.any((b) => b.endsWith('=64,00 €')), isTrue);
      final daten = i.punkte.where((p) => p.gruppe == 'Termine & Daten').map((p) => p.wert).toList();
      expect(daten, contains('01.10.2025 bis 30.09.2026'));
      expect(daten, contains('31.10.2026'));
      expect(daten, contains('01.11.2026'));
      // Ende des Zeitraums nicht doppelt
      expect(daten, isNot(contains('30.09.2026')));
    });

    test('Anlagen', () {
      expect(i.punkte.where((p) => p.gruppe == 'Anlagen').map((p) => p.wert), ['Verbrauchsübersicht', 'Preisblatt 2027']);
    });
  });

  group('Einladung vom Jobcenter', () {
    final i = inhaltLesen(_termin);

    test('Termin mit Uhrzeit', () {
      final t = i.punkte.firstWhere((p) => p.gruppe == 'Termine & Daten');
      expect(t.wert, '12.11.2026, 09:30 Uhr');
      expect(t.label, 'Termin');
    });

    test('Aktenzeichen, BG-Nummer und Aussagen', () {
      expect(i.punkte.map((p) => p.wert), containsAll(['123D45678', '12345BG0012345']));
      final alles = i.kernaussagen.join(' | ');
      expect(alles, contains('Personalausweis'));
      expect(alles, contains('gemindert'));
      expect(i.betreff, 'Einladung');
    });
  });

  test('leerer Text', () {
    expect(inhaltLesen('').leer, isTrue);
  });
}
