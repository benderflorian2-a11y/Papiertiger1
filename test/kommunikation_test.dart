import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/kommunikation.dart';
import 'package:papiertiger/logic/vorlagen.dart';

const _brief = '''
Stadtwerke Musterstadt GmbH · Hafenstraße 12 · 45127 Essen
Herrn
Florian Bender
Lindenweg 5
50667 Köln

Telefon: 0201 123-4567
Telefax: 0201 123-4599
E-Mail: kundenservice@stadtwerke-muster.de

Jahresabrechnung Strom
Kundennummer: 4711
''';

Brief _b() => Brief(
      id: 'b1',
      erstellt: DateTime(2026, 10, 1),
      kategorie: 'energie',
      typ: 'rechnung',
      text: _brief,
      erklaerung: '',
      absenderName: 'Stadtwerke Musterstadt',
      aktenzeichen: 'Kundennummer: 4711',
    );

void main() {
  test('Kontaktdaten aus dem Brief, eigene Adresse wird übersprungen', () {
    final k = kontaktFinden(_brief, name: 'Stadtwerke Musterstadt', eigeneAdresse: 'Lindenweg 5\n50667 Köln');
    expect(k.emails, ['kundenservice@stadtwerke-muster.de']);
    expect(k.telefon, ['0201 123-4567']);
    expect(k.fax, ['0201 123-4599']);
    expect(k.adresse, 'Stadtwerke Musterstadt\nHafenstraße 12\n45127 Essen');
    expect(nummerWaehlbar('+49 (0)201 / 123-45'), '+49020112345');
  });

  test('Vorlage hat Empfänger mit Anschrift und lässt sich als Brief zerlegen', () {
    final p = Profil(name: 'Florian Bender', adresse: 'Lindenweg 5\n50667 Köln');
    final text = vorlageText('rueckfrage', _b(), p);
    final t = briefTeile(text)!;
    expect(t.absender, 'Florian Bender\nLindenweg 5\n50667 Köln');
    expect(t.empfaenger, 'Stadtwerke Musterstadt\nHafenstraße 12\n45127 Essen');
    expect(t.datum, matches(RegExp(r'^\d{2}\.\d{2}\.\d{4}$')));
    expect(t.betreff, 'Kundennummer: 4711 – Rückfrage zu Ihrem Schreiben');
    expect(t.inhalt, startsWith('Sehr geehrte Damen und Herren,'));
    expect(t.inhalt, endsWith('Florian Bender'));
    expect(mailInhalt(text), t.inhalt);
    expect(briefTeile('Hallo, nur ein kurzer Text ohne Briefkopf.'), isNull);
  });

  test('KI-Brief mit Ort und Datum', () {
    final t = briefTeile('Max Muster\nWeg 1\n12345 Ort\n\nFirma X\nStraße 2\n54321 Stadt\n\n'
        'Ort, 29.10.2026\n\nBetreff: Widerspruch\n\nSehr geehrte Damen und Herren,\n\ntext\n\nGrüße')!;
    expect(t.datum, 'Ort, 29.10.2026');
    expect(t.betreff, 'Widerspruch');
    expect(t.empfaenger, 'Firma X\nStraße 2\n54321 Stadt');
  });

  test('E-Mail-Link', () {
    final u = mailtoLink(an: 'a@b.de', betreff: 'Ihr Schreiben', text: 'Zeile 1\nZeile 2').toString();
    expect(u, startsWith('mailto:a@b.de?subject=Ihr%20Schreiben&body='));
    expect(u, contains('Zeile%201%0D%0AZeile%202'));
  });

  test('Versand vermerken, Nachfassen, Antwort erhalten, speichern', () {
    final b = _b();
    antwortVermerken(b, weg: 'Einschreiben', am: DateTime(2026, 10, 20, 15), sendungsnummer: ' RT123 ');
    expect(b.antwortGesendet, DateTime(2026, 10, 20, 15));
    expect(b.nachfassenAm, DateTime(2026, 11, 17));
    expect(wartetAufAntwort([b]), [b]);
    expect(verlaufAlsText(b), contains('20.10.2026  Verschickt per Einschreiben (Sendungsnummer RT123)'));

    final kopie = Brief.fromJson(b.toJson());
    expect(kopie.verlauf.single.weg, 'Einschreiben');
    expect(kopie.verlauf.single.sendungsnummer, 'RT123');

    antwortErhalten(b);
    expect(b.nachfassenAm, isNull);
    expect(wartetAufAntwort([b]), isEmpty);
    expect(verlaufVon(b).map((e) => e.art), ['erhalten', 'gesendet']);
    expect(gesamtVerlauf([b]).length, 2);
  });

  test('Alte Antwort ohne Verlauf erscheint trotzdem', () {
    final b = _b()..antwortGesendet = DateTime(2026, 9, 1);
    expect(verlaufVon(b).single.art, 'gesendet');
  });

  test('Sprache des Briefs erkennen', () {
    expect(spracheErkennen('Sehr geehrte Damen und Herren, wir bitten Sie, die Unterlagen nicht zu vergessen.'), 'Deutsch');
    expect(spracheErkennen('Dear customer, please find attached your invoice and the terms of the contract.'), 'Englisch');
    expect(spracheErkennen('Sayın müşterimiz, bu fatura için lütfen ödeme yapın ve bir kopya saklayın.'), 'Türkisch');
  });

  test('Quelle der Frist im Brief', () {
    const t = 'Ihre Steuererklärung ist eingegangen. Bitte reichen Sie die Belege bis zum 15.11.2026 nach. Vielen Dank.';
    expect(fristQuelle(t, DateTime(2026, 11, 15)), 'Bitte reichen Sie die Belege bis zum 15.11.2026 nach.');
    expect(fristQuelle('Zahlbar bis 5. Dezember 2026 auf das Konto.', DateTime(2026, 12, 5)), 'Zahlbar bis 5. Dezember 2026 auf das Konto.');
    expect(fristQuelle(t, DateTime(2026, 11, 16)), isNull);
    expect(fristQuelle(t, DateTime(2026, 11, 5)), isNull);
  });

  test('Vorlagen für Mahnungen', () {
    final b = _b()
      ..betrag = 49.9
      ..bezahltAm = DateTime(2026, 10, 2);
    final p = Profil(name: 'Florian Bender', adresse: 'Lindenweg 5\n50667 Köln');
    final bezahlt = vorlageText('bezahlt', b, p);
    expect(bezahlt, contains('über 49,90 €'));
    expect(bezahlt, contains('bereits am 02.10.2026'));
    expect(bezahlt, endsWith('Anlage: Zahlungsnachweis'));
    expect(vorlageText('bestreiten', b, p), contains('bestreite'));
    expect(briefVorlagen.map((v) => v.key), containsAll(['bezahlt', 'bestreiten']));
  });
}
