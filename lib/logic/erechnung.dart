/// E-Rechnung im Format XRechnung 3.0 (UN/CEFACT CII, EN 16931). Seit 2025 müssen Unternehmen
/// E-Rechnungen empfangen können, ab 2027/2028 schrittweise auch verschicken (B2B).
/// Die Datei wird zusätzlich zum PDF erzeugt. Keine Steuerberatung.
library;

import '../data/geschaeft.dart';
import 'rechnungen.dart';

String _x(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _b(double v) => v.toStringAsFixed(2);
String _menge(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
String _datum(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
double _rund(double x) => (x * 100).round() / 100;

/// Anschrift aus freiem Text: (Straße, PLZ, Ort). Erkennt „12345 Ort“ in irgendeiner Zeile.
(String, String, String) anschriftTeilen(String adresse) {
  final zeilen = adresse.split(RegExp(r'[\n,]')).map((z) => z.trim()).where((z) => z.isNotEmpty).toList();
  var strasse = '', plz = '', ort = '';
  for (final z in zeilen) {
    final m = RegExp(r'^(?:D-)?(\d{5})\s+(.+)$').firstMatch(z);
    if (m != null) {
      plz = m.group(1)!;
      ort = m.group(2)!;
    } else if (strasse.isEmpty && RegExp(r'\d').hasMatch(z)) {
      strasse = z;
    }
  }
  final erste = zeilen.where((z) => !RegExp(r'^(?:D-)?\d{5}\s').hasMatch(z)).firstOrNull;
  if (strasse.isEmpty && erste != null) strasse = erste;
  return (strasse, plz, ort);
}

/// Einheit nach UN/ECE Recommendation 20.
String einheitCode(String einheit) {
  final e = einheit.toLowerCase().replaceAll('.', '').trim();
  return switch (e) {
    'std' || 'stunde' || 'stunden' || 'h' => 'HUR',
    'm²' || 'm2' || 'qm' => 'MTK',
    'm³' || 'm3' || 'cbm' => 'MTQ',
    'm' || 'lfm' || 'meter' => 'MTR',
    'kg' => 'KGM',
    't' || 'tonne' => 'TNE',
    'l' || 'liter' => 'LTR',
    'pauschal' || 'psch' || 'pausch' => 'LS',
    'tag' || 'tage' => 'DAY',
    'km' => 'KMT',
    'stück' || 'stk' || 'st' => 'H87',
    _ => 'C62',
  };
}

/// Pflichtangaben, die für eine gültige XRechnung fehlen.
List<String> eRechnungFehlt(Rechnung r, Firma f, Kunde? k) {
  final (_, fPlz, fOrt) = anschriftTeilen(f.adresse);
  final (_, kPlz, kOrt) = k == null ? ('', '', '') : anschriftTeilen(k.adresse);
  return [
    if (!r.istRechnung) 'Nur Rechnungen können als E-Rechnung verschickt werden',
    if (f.name.trim().isEmpty) 'Dein Firmenname',
    if (fPlz.isEmpty || fOrt.isEmpty) 'PLZ und Ort in deiner Anschrift (z. B. „12345 Musterstadt“)',
    if (f.email.trim().isEmpty) 'Deine E-Mail-Adresse (Firmendaten)',
    if (f.telefon.trim().isEmpty) 'Deine Telefonnummer (Firmendaten)',
    if (f.steuernummer.trim().isEmpty && f.ustId.trim().isEmpty) 'Steuernummer oder USt-IdNr.',
    if (f.iban.trim().isEmpty) 'Deine IBAN',
    if (k == null) 'Kunde',
    if (k != null && (kPlz.isEmpty || kOrt.isEmpty)) 'PLZ und Ort in der Anschrift des Kunden',
    if (k != null && k.email.trim().isEmpty) 'E-Mail-Adresse des Kunden',
    if (r.positionen.isEmpty) 'Mindestens eine Position',
  ];
}

String _steuerKategorie(int satz, bool kleinunternehmer) => kleinunternehmer || satz == 0 ? 'E' : 'S';

/// XRechnung (CII) als Text. Vorher [eRechnungFehlt] prüfen.
String xRechnung(Rechnung r, Firma f, Kunde k, {List<Rechnung> alle = const []}) {
  final ku = f.kleinunternehmer;
  final (fStr, fPlz, fOrt) = anschriftTeilen(f.adresse);
  final (kStr, kPlz, kOrt) = anschriftTeilen(k.adresse);
  final typ = r.art == 'abschlag' ? '326' : '380';
  final leistungVon = r.leistungVon ?? r.datum;

  // Summen je Steuersatz (wie im PDF)
  final roh = <int, double>{};
  for (final p in r.positionen) {
    final satz = ku ? 0 : p.ustSatz;
    roh[satz] = _rund((roh[satz] ?? 0) + p.netto);
  }
  final rabattJeSatz = <int, double>{};
  for (final e in rabattAufteilen(r).entries) {
    final satz = ku ? 0 : e.key;
    rabattJeSatz[satz] = _rund((rabattJeSatz[satz] ?? 0) + e.value);
  }
  final zeilenSumme = _rund(roh.values.fold(0.0, (a, b) => a + b));
  final rabatt = _rund(rabattJeSatz.values.fold(0.0, (a, b) => a + b));
  final basis = {for (final e in roh.entries) e.key: _rund(e.value - (rabattJeSatz[e.key] ?? 0))};
  final steuer = {for (final e in basis.entries) e.key: _rund(e.value * e.key / 100)};
  final basisGesamt = _rund(zeilenSumme - rabatt);
  final steuerGesamt = _rund(steuer.values.fold(0.0, (a, b) => a + b));
  final gesamt = _rund(basisGesamt + steuerGesamt);
  final vorausbezahlt = r.art == 'schluss'
      ? _rund(abschlaegeZu(r, alle).fold(0.0, (a, x) => a + summenVon(x, kleinunternehmer: ku).brutto))
      : 0.0;
  final faellig = _rund(gesamt - vorausbezahlt);

  final x = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n')
    ..write('<rsm:CrossIndustryInvoice xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" '
        'xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" '
        'xmlns:qdt="urn:un:unece:uncefact:data:standard:QualifiedDataType:100" '
        'xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">\n')
    ..write('<rsm:ExchangedDocumentContext>'
        '<ram:BusinessProcessSpecifiedDocumentContextParameter><ram:ID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</ram:ID></ram:BusinessProcessSpecifiedDocumentContextParameter>'
        '<ram:GuidelineSpecifiedDocumentContextParameter><ram:ID>urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0</ram:ID></ram:GuidelineSpecifiedDocumentContextParameter>'
        '</rsm:ExchangedDocumentContext>\n')
    ..write('<rsm:ExchangedDocument><ram:ID>${_x(r.nummer)}</ram:ID><ram:TypeCode>$typ</ram:TypeCode>'
        '<ram:IssueDateTime><udt:DateTimeString format="102">${_datum(r.datum)}</udt:DateTimeString></ram:IssueDateTime>');
  if (ku) x.write('<ram:IncludedNote><ram:Content>${_x(kleinunternehmerHinweis)}</ram:Content></ram:IncludedNote>');
  if (r.notiz.trim().isNotEmpty) x.write('<ram:IncludedNote><ram:Content>${_x(r.notiz.trim())}</ram:Content></ram:IncludedNote>');
  x.write('</rsm:ExchangedDocument>\n<rsm:SupplyChainTradeTransaction>\n');

  for (var i = 0; i < r.positionen.length; i++) {
    final p = r.positionen[i];
    final satz = ku ? 0 : p.ustSatz;
    x.write('<ram:IncludedSupplyChainTradeLineItem>'
        '<ram:AssociatedDocumentLineDocument><ram:LineID>${i + 1}</ram:LineID></ram:AssociatedDocumentLineDocument>'
        '<ram:SpecifiedTradeProduct><ram:Name>${_x(p.text.isEmpty ? 'Position ${i + 1}' : p.text)}</ram:Name></ram:SpecifiedTradeProduct>'
        '<ram:SpecifiedLineTradeAgreement><ram:NetPriceProductTradePrice><ram:ChargeAmount>${p.preis.toStringAsFixed(2)}</ram:ChargeAmount></ram:NetPriceProductTradePrice></ram:SpecifiedLineTradeAgreement>'
        '<ram:SpecifiedLineTradeDelivery><ram:BilledQuantity unitCode="${einheitCode(p.einheit)}">${_menge(p.menge)}</ram:BilledQuantity></ram:SpecifiedLineTradeDelivery>'
        '<ram:SpecifiedLineTradeSettlement>'
        '<ram:ApplicableTradeTax><ram:TypeCode>VAT</ram:TypeCode><ram:CategoryCode>${_steuerKategorie(satz, ku)}</ram:CategoryCode><ram:RateApplicablePercent>$satz</ram:RateApplicablePercent></ram:ApplicableTradeTax>'
        '<ram:SpecifiedTradeSettlementLineMonetarySummation><ram:LineTotalAmount>${_b(p.netto)}</ram:LineTotalAmount></ram:SpecifiedTradeSettlementLineMonetarySummation>'
        '</ram:SpecifiedLineTradeSettlement></ram:IncludedSupplyChainTradeLineItem>\n');
  }

  String adresse(String str, String plz, String ort) => '<ram:PostalTradeAddress><ram:PostcodeCode>$plz</ram:PostcodeCode>'
      '${str.isEmpty ? '' : '<ram:LineOne>${_x(str)}</ram:LineOne>'}<ram:CityName>${_x(ort)}</ram:CityName><ram:CountryID>DE</ram:CountryID></ram:PostalTradeAddress>';

  x.write('<ram:ApplicableHeaderTradeAgreement>'
      '<ram:BuyerReference>${_x(k.leitwegId.isNotEmpty ? k.leitwegId : r.nummer)}</ram:BuyerReference>'
      // BR-CO-26: ohne USt-IdNr. braucht es eine Verkäuferkennung (BT-29) – hier die Steuernummer
      '<ram:SellerTradeParty>${f.ustId.trim().isEmpty ? '<ram:ID>${_x(f.steuernummer.trim())}</ram:ID>' : ''}<ram:Name>${_x(f.name)}</ram:Name>'
      '<ram:DefinedTradeContact><ram:PersonName>${_x(f.name)}</ram:PersonName>'
      '<ram:TelephoneUniversalCommunication><ram:CompleteNumber>${_x(f.telefon)}</ram:CompleteNumber></ram:TelephoneUniversalCommunication>'
      '<ram:EmailURIUniversalCommunication><ram:URIID>${_x(f.email)}</ram:URIID></ram:EmailURIUniversalCommunication></ram:DefinedTradeContact>'
      '${adresse(fStr, fPlz, fOrt)}'
      '<ram:URIUniversalCommunication><ram:URIID schemeID="EM">${_x(f.email)}</ram:URIID></ram:URIUniversalCommunication>'
      '${f.steuernummer.trim().isEmpty ? '' : '<ram:SpecifiedTaxRegistration><ram:ID schemeID="FC">${_x(f.steuernummer.trim())}</ram:ID></ram:SpecifiedTaxRegistration>'}'
      '${f.ustId.trim().isEmpty ? '' : '<ram:SpecifiedTaxRegistration><ram:ID schemeID="VA">${_x(f.ustId.replaceAll(' ', ''))}</ram:ID></ram:SpecifiedTaxRegistration>'}'
      '</ram:SellerTradeParty>'
      '<ram:BuyerTradeParty><ram:Name>${_x(k.name)}</ram:Name>${adresse(kStr, kPlz, kOrt)}'
      '<ram:URIUniversalCommunication><ram:URIID schemeID="EM">${_x(k.email)}</ram:URIID></ram:URIUniversalCommunication>'
      '</ram:BuyerTradeParty></ram:ApplicableHeaderTradeAgreement>\n');

  x.write('<ram:ApplicableHeaderTradeDelivery><ram:ActualDeliverySupplyChainEvent><ram:OccurrenceDateTime>'
      '<udt:DateTimeString format="102">${_datum(r.leistungBis ?? leistungVon)}</udt:DateTimeString>'
      '</ram:OccurrenceDateTime></ram:ActualDeliverySupplyChainEvent></ram:ApplicableHeaderTradeDelivery>\n');

  x.write('<ram:ApplicableHeaderTradeSettlement>'
      '<ram:PaymentReference>${_x(r.nummer)}</ram:PaymentReference>'
      '<ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>'
      '<ram:SpecifiedTradeSettlementPaymentMeans><ram:TypeCode>58</ram:TypeCode>'
      '<ram:PayeePartyCreditorFinancialAccount><ram:IBANID>${f.iban.replaceAll(' ', '').toUpperCase()}</ram:IBANID></ram:PayeePartyCreditorFinancialAccount>'
      '${f.bic.isEmpty ? '' : '<ram:PayeeSpecifiedCreditorFinancialInstitution><ram:BICID>${_x(f.bic)}</ram:BICID></ram:PayeeSpecifiedCreditorFinancialInstitution>'}'
      '</ram:SpecifiedTradeSettlementPaymentMeans>');
  for (final satz in basis.keys) {
    final kat = _steuerKategorie(satz, ku);
    x.write('<ram:ApplicableTradeTax><ram:CalculatedAmount>${_b(steuer[satz]!)}</ram:CalculatedAmount><ram:TypeCode>VAT</ram:TypeCode>'
        '${kat == 'E' ? '<ram:ExemptionReason>${ku ? 'Kleinunternehmer gemäß § 19 UStG' : 'Steuerbefreit'}</ram:ExemptionReason>' : ''}'
        '<ram:BasisAmount>${_b(basis[satz]!)}</ram:BasisAmount><ram:CategoryCode>$kat</ram:CategoryCode>'
        '<ram:RateApplicablePercent>$satz</ram:RateApplicablePercent></ram:ApplicableTradeTax>');
  }
  if (r.leistungBis != null && r.leistungBis != leistungVon) {
    x.write('<ram:BillingSpecifiedPeriod>'
        '<ram:StartDateTime><udt:DateTimeString format="102">${_datum(leistungVon)}</udt:DateTimeString></ram:StartDateTime>'
        '<ram:EndDateTime><udt:DateTimeString format="102">${_datum(r.leistungBis!)}</udt:DateTimeString></ram:EndDateTime>'
        '</ram:BillingSpecifiedPeriod>');
  }
  for (final e in rabattJeSatz.entries) {
    if (e.value <= 0) continue;
    x.write('<ram:SpecifiedTradeAllowanceCharge><ram:ChargeIndicator><udt:Indicator>false</udt:Indicator></ram:ChargeIndicator>'
        '<ram:ActualAmount>${_b(e.value)}</ram:ActualAmount><ram:Reason>Rabatt</ram:Reason>'
        '<ram:CategoryTradeTax><ram:TypeCode>VAT</ram:TypeCode><ram:CategoryCode>${_steuerKategorie(e.key, ku)}</ram:CategoryCode>'
        '<ram:RateApplicablePercent>${e.key}</ram:RateApplicablePercent></ram:CategoryTradeTax></ram:SpecifiedTradeAllowanceCharge>');
  }
  final faelligAmTag = faelligAm(r);
  x.write('<ram:SpecifiedTradePaymentTerms><ram:Description>Zahlbar bis ${faelligAmTag.day.toString().padLeft(2, '0')}.'
      '${faelligAmTag.month.toString().padLeft(2, '0')}.${faelligAmTag.year} ohne Abzug.</ram:Description>'
      '<ram:DueDateDateTime><udt:DateTimeString format="102">${_datum(faelligAmTag)}</udt:DateTimeString></ram:DueDateDateTime>'
      '</ram:SpecifiedTradePaymentTerms>');
  x.write('<ram:SpecifiedTradeSettlementHeaderMonetarySummation>'
      '<ram:LineTotalAmount>${_b(zeilenSumme)}</ram:LineTotalAmount>'
      '<ram:ChargeTotalAmount>0.00</ram:ChargeTotalAmount>'
      '<ram:AllowanceTotalAmount>${_b(rabatt)}</ram:AllowanceTotalAmount>'
      '<ram:TaxBasisTotalAmount>${_b(basisGesamt)}</ram:TaxBasisTotalAmount>'
      '<ram:TaxTotalAmount currencyID="EUR">${_b(steuerGesamt)}</ram:TaxTotalAmount>'
      '<ram:GrandTotalAmount>${_b(gesamt)}</ram:GrandTotalAmount>'
      '<ram:TotalPrepaidAmount>${_b(vorausbezahlt)}</ram:TotalPrepaidAmount>'
      '<ram:DuePayableAmount>${_b(faellig)}</ram:DuePayableAmount>'
      '</ram:SpecifiedTradeSettlementHeaderMonetarySummation>');
  for (final a in r.art == 'schluss' ? abschlaegeZu(r, alle) : <Rechnung>[]) {
    x.write('<ram:InvoiceReferencedDocument><ram:IssuerAssignedID>${_x(a.nummer)}</ram:IssuerAssignedID>'
        '<ram:FormattedIssueDateTime><qdt:DateTimeString format="102">${_datum(a.datum)}</qdt:DateTimeString></ram:FormattedIssueDateTime>'
        '</ram:InvoiceReferencedDocument>');
  }
  x.write('</ram:ApplicableHeaderTradeSettlement>\n</rsm:SupplyChainTradeTransaction>\n</rsm:CrossIndustryInvoice>\n');
  return x.toString();
}
