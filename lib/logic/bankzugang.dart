/// Online-Banking verbinden (FinTS, nur lesen): Kontostand und Umsätze holen, damit der Tiger Abos,
/// Verträge, doppelte Abbuchungen und Zahlungseingänge erkennt. Überweisen kann dieser Zugang nicht –
/// Zahlungen gibst du immer selbst in deiner Banking-App frei.
library;

import 'package:fints/fints.dart';

/// Registrierungsnummer der Deutschen Kreditwirtschaft (kostenlos, fints.org).
/// Ohne sie lassen deutsche Banken die App nicht herein. Wird nach der Registrierung eingetragen.
const fintsProduktId = 'BD5D1A3CC525F07F2FECB58EA';

bool get bankzugangFreigeschaltet => fintsProduktId.isNotEmpty;

class BankVorlage {
  const BankVorlage(this.name, this.url, {this.hinweis = ''});

  final String name;

  /// FinTS-Adresse der Bank; leer = selbst eintragen.
  final String url;
  final String hinweis;
}

/// Bekannte FinTS-Adressen. Die vollständige Liste gibt es mit der Registrierung.
const bankVorlagen = <BankVorlage>[
  BankVorlage('Sparkasse', '',
      hinweis: 'Die FinTS-Adresse steht auf der Internetseite deiner Sparkasse (Suche nach „FinTS“). '
          'Sie sieht etwa so aus: https://banking-….s-fints-pt-….de/fints30'),
  BankVorlage('Volksbank / Raiffeisenbank', 'https://fints1.atruvia.de/cgi-bin/hbciservlet'),
  BankVorlage('DKB', 'https://fints.dkb.de/fints'),
  BankVorlage('ING', 'https://fints.ing.de/fints/'),
  BankVorlage('comdirect', 'https://fints.comdirect.de/fints'),
  BankVorlage('Postbank', 'https://hbci.postbank.de/banking/hbci.do'),
  BankVorlage('Andere Bank', '', hinweis: 'Die FinTS-Adresse findest du auf der Internetseite deiner Bank.'),
];

/// Bankleitzahl aus einer deutschen IBAN (Stellen 5 bis 12).
String? blzAusIban(String iban) {
  final s = iban.replaceAll(' ', '').toUpperCase();
  if (!RegExp(r'^DE\d{20}$').hasMatch(s)) return null;
  return s.substring(4, 12);
}

class Umsatz {
  Umsatz({required this.datum, required this.betrag, required this.name, this.zweck = ''});

  final DateTime datum;

  /// Negativ = Abbuchung, positiv = Eingang.
  final double betrag;
  final String name;
  final String zweck;
}

/// Buchungen der Bank in Papiertiger-Umsätze. Vorgemerkte und stornierte Buchungen fallen weg.
List<Umsatz> umsaetzeAus(List<Transaction> liste) => [
      for (final t in liste)
        if (!t.isPending && !t.isReversal)
          Umsatz(
            datum: t.bookingDate ?? t.valueDate,
            betrag: t.amount.value,
            name: _name(t),
            zweck: (t.purpose ?? '').replaceAll(RegExp(r'\s+'), ' ').trim(),
          ),
    ];

String _name(Transaction t) {
  final n = (t.counterpartyName ?? t.ultimateCreditor ?? '').trim();
  if (n.isNotEmpty) return n;
  final z = (t.purpose ?? t.bookingText ?? 'Buchung').trim();
  return z.split(RegExp(r'\s+')).take(4).join(' ');
}

String _zwei(int z) => z.toString().padLeft(2, '0');

String _betrag(double b) {
  final s = b.abs().toStringAsFixed(2).split('.');
  final ganz = s[0];
  final buf = StringBuffer();
  for (var i = 0; i < ganz.length; i++) {
    if (i > 0 && (ganz.length - i) % 3 == 0) buf.write('.');
    buf.write(ganz[i]);
  }
  return '${b < 0 ? '-' : ''}$buf,${s[1]}';
}

/// Umsätze als Text, wie ihn die Kontoauszug-Auswertung liest:
/// „01.10.2026 Telekom Deutschland GmbH -39,95“ und darunter der Verwendungszweck.
String umsaetzeAlsText(List<Umsatz> liste) {
  final z = StringBuffer();
  for (final u in liste) {
    final name = u.name.replaceAll(RegExp(r'\d{1,2}\.\d{1,2}\.(\d{2,4})?'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    z.writeln('${_zwei(u.datum.day)}.${_zwei(u.datum.month)}.${u.datum.year} ${name.isEmpty ? 'Buchung' : name} ${_betrag(u.betrag)}');
    // Zweck ohne Daten und Beträge, damit er nicht als eigene Buchung gelesen wird
    final zweck = u.zweck
        .replaceAll(RegExp(r'\d{1,2}\.\d{1,2}\.(\d{2,4})?'), '')
        .replaceAll(RegExp(r'\d+,\d{2}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (zweck.isNotEmpty) z.writeln(zweck);
  }
  return z.toString();
}

class BankAbruf {
  BankAbruf({required this.umsaetze, required this.state, this.kontostand, this.iban, this.kontoName});

  final List<Umsatz> umsaetze;
  final double? kontostand;
  final String? iban;
  final String? kontoName;

  /// Sitzungsdaten der Bank (ohne PIN) – verschlüsselt speichern, spart beim nächsten Mal Rückfragen.
  final String state;
}

typedef TanFrage = Future<TanAnswer> Function(TanChallenge c);
typedef TanWahl = Future<TanMethod?> Function(List<TanMethod> m);

/// Holt Kontostand und Umsätze der letzten [tage] Tage. Die PIN wird nicht gespeichert.
Future<BankAbruf> bankAbrufen({
  required String url,
  required String blz,
  required String benutzer,
  required String pin,
  required TanFrage tan,
  required TanWahl wahl,
  String? state,
  String? iban,
  int tage = 365,
  FinTsTransport? transport,
}) async {
  final client = FinTs3Client(
    config: FinTsConfig(
      url: Uri.parse(url.trim()),
      bankCode: blz.trim(),
      userId: benutzer.trim(),
      productId: fintsProduktId,
      productVersion: '1',
    ),
    pin: pin,
    options: FinTsClientOptions(
      tanCallback: tan,
      tanMethodSelector: wahl,
      state: state,
      transport: transport,
    ),
  );
  List<Umsatz> umsaetze;
  double? stand;
  Account konto;
  try {
    final konten = await client.getAccounts();
    if (konten.isEmpty) throw StateError('Die Bank hat kein Konto geliefert.');
    final gesucht = iban?.replaceAll(' ', '').toUpperCase();
    konto = konten.firstWhere((k) => gesucht != null && k.iban?.replaceAll(' ', '').toUpperCase() == gesucht,
        orElse: () => konten.firstWhere((k) => k.iban != null, orElse: () => konten.first));
    try {
      stand = (await client.getBalance(konto)).booked.value;
    } catch (_) {
      stand = null;
    }
    final jetzt = DateTime.now();
    umsaetze = umsaetzeAus(
        await client.getTransactions(konto, from: jetzt.subtract(Duration(days: tage)), to: jetzt));
  } finally {
    await client.close();
  }
  return BankAbruf(
    umsaetze: umsaetze,
    kontostand: stand,
    iban: konto.iban,
    kontoName: konto.productName,
    state: client.state,
  );
}

/// Verständliche Fehlermeldung.
String bankFehlerText(Object e) => switch (e) {
      FinTsPinException() => 'Die PIN wurde nicht angenommen. Bitte prüfe sie (Achtung: nach mehreren Fehlversuchen sperrt die Bank).',
      FinTsLoginRefusedException(:final message) => 'Die Bank hat die Anmeldung abgelehnt: $message',
      FinTsTanCancelledException() => 'Abgebrochen – es wurde nichts abgerufen.',
      FinTsDecoupledTimeoutException() => 'Die Freigabe in der Banking-App kam nicht rechtzeitig. Bitte noch einmal versuchen.',
      FinTsTanException(:final message) => 'Die TAN wurde nicht angenommen: $message',
      FinTsTransportException() => 'Die Bank ist nicht erreichbar. Bist du online, und stimmt die FinTS-Adresse?',
      FinTsBankException(:final message) => 'Die Bank meldet: $message',
      FinTsException(:final message) => message,
      ArgumentError(:final message) => 'Eingabe prüfen: $message',
      _ => '$e',
    };
