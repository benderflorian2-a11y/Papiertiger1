/// Überweisungen vorbereiten. Der Tiger überweist nie selbst: Jede Zahlung gibst du
/// in deiner Banking-App per pushTAN frei.
library;

import 'finanzen.dart';
import 'rechnungen.dart';

class Zahlauftrag {
  Zahlauftrag({this.empfaenger = '', this.iban = '', this.bic = '', this.betrag, this.zweck = ''});

  String empfaenger;
  String iban;
  String bic;
  double? betrag;
  String zweck;

  /// GiroCode-Inhalt (leer, wenn Angaben fehlen).
  String get giroCodeText => giroCode(name: empfaenger, iban: iban, bic: bic, betrag: betrag ?? 0, zweck: zweck);

  /// Alle Angaben als Text zum Einfügen.
  String alsText() => [
        'Empfänger: $empfaenger',
        'IBAN: ${ibanLesbar(iban)}',
        if (bic.isNotEmpty) 'BIC: $bic',
        'Betrag: ${(betrag ?? 0).toStringAsFixed(2).replaceAll('.', ',')} €',
        'Verwendungszweck: $zweck',
      ].join('\n');
}

/// Was vor der Freigabe noch fehlt oder falsch ist.
List<String> zahlauftragPruefen(Zahlauftrag z) => [
      if (z.empfaenger.trim().isEmpty) 'Empfänger fehlt',
      if (z.iban.trim().isEmpty) 'IBAN fehlt' else if (!ibanGueltig(z.iban)) 'IBAN ist ungültig (Prüfziffer stimmt nicht)',
      if (z.betrag == null || z.betrag! <= 0) 'Betrag fehlt',
      if (z.zweck.trim().isEmpty) 'Verwendungszweck fehlt – meist Rechnungs- oder Kundennummer',
      if (z.zweck.length > 140) 'Verwendungszweck ist länger als 140 Zeichen',
    ];

/// Eine direkte Bankverbindung (FinTS bzw. Zahlungsdienstleister) ist noch nicht eingerichtet.
/// Sobald es sie gibt, schickt „Zur Freigabe senden“ den Auftrag an die Bank und du gibst ihn
/// in der S-pushTAN-App frei. Bis dahin: Sparkassen-App öffnen und dort freigeben.
const bankDirektVerbunden = false;
