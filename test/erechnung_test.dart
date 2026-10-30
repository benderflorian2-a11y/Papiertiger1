import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/logic/erechnung.dart';
import 'package:papiertiger/logic/rechnungen.dart';

Firma _firma({bool ku = false}) => Firma(
      name: 'Malerbetrieb Max Muster',
      adresse: 'Farbweg 7\n12345 Musterstadt',
      steuernummer: '12/345/67890',
      ustId: ku ? '' : 'DE123456789',
      kleinunternehmer: ku,
      iban: 'DE89 3704 0044 0532 0130 00',
      email: 'info@maler-muster.de',
      telefon: '0123 456789',
    );

final _kunde = Kunde(id: 'k', name: 'Erika & Söhne GmbH', adresse: 'Hauptstraße 1, 54321 Beispielstadt', email: 'buchhaltung@erika.de');

Rechnung _rechnung() => Rechnung(
      id: 'r',
      art: 'rechnung',
      nummer: '2026-042',
      kundeId: 'k',
      datum: DateTime(2026, 10, 30),
      leistungVon: DateTime(2026, 10, 20),
      leistungBis: DateTime(2026, 10, 24),
      rabattProzent: 5,
      positionen: [
        Position(text: 'Wände streichen <Wohnzimmer>', menge: 42.5, einheit: 'm²', preis: 12.4),
        Position(text: 'Arbeitszeit', menge: 3, einheit: 'Std.', preis: 55),
        Position(text: 'Fachbuch', menge: 1, einheit: 'Stück', preis: 30, ustSatz: 7),
      ],
    );

void main() {
  test('Anschrift und Einheiten', () {
    expect(anschriftTeilen('Farbweg 7\n12345 Musterstadt'), ('Farbweg 7', '12345', 'Musterstadt'));
    expect(anschriftTeilen('Am Markt, D-01067 Dresden'), ('Am Markt', '01067', 'Dresden'));
    expect(einheitCode('m²'), 'MTK');
    expect(einheitCode('Std.'), 'HUR');
    expect(einheitCode('pauschal'), 'LS');
    expect(einheitCode('Sack'), 'C62');
  });

  test('Fehlende Pflichtangaben', () {
    expect(eRechnungFehlt(_rechnung(), _firma(), _kunde), isEmpty);
    final f = _firma()
      ..telefon = ''
      ..adresse = 'Farbweg 7';
    final fehlt = eRechnungFehlt(_rechnung(), f, Kunde(id: 'x', name: 'Ohne'));
    expect(fehlt, containsAll(['Deine Telefonnummer (Firmendaten)', 'E-Mail-Adresse des Kunden']));
    expect(fehlt.any((x) => x.contains('PLZ und Ort in deiner Anschrift')), isTrue);
  });

  test('XRechnung: Summen stimmen mit dem PDF überein', () {
    final r = _rechnung();
    final xml = xRechnung(r, _firma(), _kunde);
    final s = summenVon(r, kleinunternehmer: false);
    // 527,00 + 165,00 = 692,00 (19 %), 30,00 (7 %); 5 % Rabatt = 36,10
    expect(xml, contains('<ram:LineTotalAmount>722.00</ram:LineTotalAmount><ram:ChargeTotalAmount>'));
    expect(xml, contains('<ram:AllowanceTotalAmount>36.10</ram:AllowanceTotalAmount>'));
    expect(xml, contains('<ram:TaxBasisTotalAmount>${s.netto.toStringAsFixed(2)}</ram:TaxBasisTotalAmount>'));
    expect(xml, contains('<ram:TaxTotalAmount currencyID="EUR">${s.ustGesamt.toStringAsFixed(2)}</ram:TaxTotalAmount>'));
    expect(xml, contains('<ram:GrandTotalAmount>${s.brutto.toStringAsFixed(2)}</ram:GrandTotalAmount>'));
    expect(xml, contains('<ram:DuePayableAmount>${s.brutto.toStringAsFixed(2)}</ram:DuePayableAmount>'));
    expect(xml, contains('Wände streichen &lt;Wohnzimmer&gt;'));
    expect(xml, contains('Erika &amp; Söhne GmbH'));
    expect(xml, contains('<ram:BilledQuantity unitCode="MTK">42.5</ram:BilledQuantity>'));
    expect(xml, contains('<ram:IBANID>DE89370400440532013000</ram:IBANID>'));
    expect(xml, contains('<ram:ID schemeID="VA">DE123456789</ram:ID>'));
    expect(xml, contains('xrechnung_3.0'));
    Directory('build').createSync(recursive: true);
    File('build/erechnung_regulaer.xml').writeAsStringSync(xml);
  });

  test('XRechnung für Kleinunternehmer und Schlussrechnung', () {
    final ku = _rechnung()..rabattProzent = 0;
    final xmlKu = xRechnung(ku, _firma(ku: true), _kunde);
    expect(xmlKu, contains('<ram:CategoryCode>E</ram:CategoryCode>'));
    expect(xmlKu, contains('Kleinunternehmer gemäß § 19 UStG'));
    expect(xmlKu, contains('<ram:TaxTotalAmount currencyID="EUR">0.00</ram:TaxTotalAmount>'));
    expect(xmlKu, isNot(contains('schemeID="VA"')));
    File('build/erechnung_kleinunternehmer.xml').writeAsStringSync(xmlKu);

    final auftrag = _rechnung()
      ..art = 'auftragsbestaetigung'
      ..id = 'ab'
      ..rabattProzent = 0;
    final alle = <Rechnung>[auftrag];
    final abschlag = abschlagAus(auftrag, alle, id: 'a1', datum: DateTime(2026, 10, 10), prozent: 50, zahlungszielTage: 7);
    alle.add(abschlag);
    final schluss = schlussAus(auftrag, alle, id: 's', datum: DateTime(2026, 10, 30), zahlungszielTage: 14);
    alle.add(schluss);
    final xml = xRechnung(schluss, _firma(), _kunde, alle: alle);
    final rest = zuZahlen(schluss, alle, kleinunternehmer: false);
    expect(xml, contains('<ram:DuePayableAmount>${rest.brutto.toStringAsFixed(2)}</ram:DuePayableAmount>'));
    expect(xml, contains('<ram:InvoiceReferencedDocument><ram:IssuerAssignedID>${abschlag.nummer}</ram:IssuerAssignedID>'));
    expect(xRechnung(abschlag, _firma(), _kunde), contains('<ram:TypeCode>326</ram:TypeCode>'));
    File('build/erechnung_schluss.xml').writeAsStringSync(xml);
  });
}
