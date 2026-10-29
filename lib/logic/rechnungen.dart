/// Rechnungen und Angebote für Selbstständige: Summen, Nummern, Pflichtangaben,
/// Einnahmen-Überschuss und Umsatzsteuer-Überblick. Keine Steuerberatung.
library;

import '../data/geschaeft.dart';
import '../data/models.dart';

class Summen {
  Summen(this.netto, this.ust);

  final double netto;

  /// Umsatzsteuer je Steuersatz.
  final Map<int, double> ust;

  double get ustGesamt => ust.values.fold(0.0, (a, b) => a + b);
  double get brutto => netto + ustGesamt;
}

double _rund(double x) => (x * 100).round() / 100;

Summen summenVon(Rechnung r, {required bool kleinunternehmer}) {
  var netto = 0.0;
  final proSatz = <int, double>{};
  for (final p in r.positionen) {
    netto += p.netto;
    if (!kleinunternehmer && p.ustSatz > 0) proSatz[p.ustSatz] = (proSatz[p.ustSatz] ?? 0) + p.netto;
  }
  return Summen(_rund(netto), {for (final e in proSatz.entries) e.key: _rund(e.value * e.key / 100)});
}

/// Fortlaufende Nummer je Jahr und Art: 2026-001 (Rechnung), A-2026-001 (Angebot), KV-2026-001.
String naechsteNummer(List<Rechnung> alle, {required String art, required int jahr}) {
  final praefix = switch (art) { 'angebot' => 'A-$jahr-', 'kostenvoranschlag' => 'KV-$jahr-', _ => '$jahr-' };
  var max = 0;
  for (final r in alle) {
    if (r.art != art || !r.nummer.startsWith(praefix)) continue;
    final n = int.tryParse(r.nummer.substring(praefix.length)) ?? 0;
    if (n > max) max = n;
  }
  return '$praefix${(max + 1).toString().padLeft(3, '0')}';
}

DateTime faelligAm(Rechnung r) => DateTime(r.datum.year, r.datum.month, r.datum.day + r.zahlungszielTage);

bool istOffen(Rechnung r) => !r.istAngebot && !r.storniert && r.bezahltAm == null;

bool ueberfaellig(Rechnung r, {DateTime? heute}) {
  final h = heute ?? DateTime.now();
  return istOffen(r) && faelligAm(r).isBefore(DateTime(h.year, h.month, h.day));
}

/// Was auf einer Rechnung noch fehlt (Pflichtangaben nach § 14 UStG, vereinfacht).
List<String> fehlendeAngaben(Rechnung r, Firma f, Kunde? k) => [
      if (f.name.trim().isEmpty) 'Dein Name oder Firmenname',
      if (f.adresse.trim().isEmpty) 'Deine Anschrift',
      if (f.steuernummer.trim().isEmpty && f.ustId.trim().isEmpty) 'Steuernummer oder USt-IdNr.',
      if (k == null || k.name.trim().isEmpty) 'Name des Kunden',
      if (k != null && k.adresse.trim().isEmpty) 'Anschrift des Kunden',
      if (r.positionen.isEmpty) 'Mindestens eine Position',
      if (r.positionen.any((p) => p.text.trim().isEmpty)) 'Beschreibung jeder Position',
      if (!r.istAngebot && r.leistungVon == null) 'Leistungsdatum oder -zeitraum',
    ];

const kleinunternehmerHinweis = 'Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.';

// ---------------------------------------------------------------- Einnahmen und Ausgaben

class Zeitraum {
  Zeitraum(this.von, this.bis, this.name);

  final DateTime von;

  /// Einschließlich.
  final DateTime bis;
  final String name;

  bool enthaelt(DateTime d) => !d.isBefore(von) && !d.isAfter(DateTime(bis.year, bis.month, bis.day, 23, 59));

  static Zeitraum jahr(int j) => Zeitraum(DateTime(j, 1, 1), DateTime(j, 12, 31), '$j');
  static Zeitraum quartal(int j, int q) =>
      Zeitraum(DateTime(j, 3 * q - 2, 1), DateTime(j, 3 * q + 1, 0), '$q. Quartal $j');
  static Zeitraum monat(int j, int m) => Zeitraum(DateTime(j, m, 1), DateTime(j, m + 1, 0), '$m/$j');
}

class Ueberschuss {
  Ueberschuss({
    required this.einnahmenNetto,
    required this.ustEingenommen,
    required this.ausgaben,
    required this.offen,
  });

  /// Bezahlte Rechnungen im Zeitraum (Zufluss), netto.
  final double einnahmenNetto;

  /// Darin enthaltene Umsatzsteuer – muss ans Finanzamt.
  final double ustEingenommen;

  /// Geschäftliche Belege im Zeitraum (brutto).
  final double ausgaben;

  /// Noch nicht bezahlte Rechnungen (brutto), unabhängig vom Zeitraum.
  final double offen;

  double get gewinnVorSteuer => einnahmenNetto - ausgaben;
}

/// Einnahmen-Überschuss nach Zufluss (wann bezahlt wurde), vereinfacht.
Ueberschuss ueberschuss({
  required Zeitraum z,
  required List<Rechnung> rechnungen,
  required List<Beleg> belege,
  required bool kleinunternehmer,
}) {
  var netto = 0.0, ust = 0.0, offen = 0.0;
  for (final r in rechnungen) {
    if (r.istAngebot || r.storniert) continue;
    final s = summenVon(r, kleinunternehmer: kleinunternehmer);
    if (r.bezahltAm == null) {
      offen += s.brutto;
    } else if (z.enthaelt(r.bezahltAm!)) {
      netto += s.netto;
      ust += s.ustGesamt;
    }
  }
  final ausgaben = belege.where((b) => b.geschaeftlich && z.enthaelt(b.datum)).fold(0.0, (s, b) => s + (b.betrag ?? 0));
  return Ueberschuss(einnahmenNetto: _rund(netto), ustEingenommen: _rund(ust), ausgaben: _rund(ausgaben), offen: _rund(offen));
}

/// Abgabe der Umsatzsteuer-Voranmeldung: 10. Tag nach Ende des Zeitraums
/// (ohne Dauerfristverlängerung).
DateTime ustVoranmeldungBis(Zeitraum z) => DateTime(z.bis.year, z.bis.month + 1, 10);

/// Zahlungserinnerung als Brieftext.
String zahlungserinnerungText(Rechnung r, Firma f, Kunde k, Summen s) {
  String d(DateTime x) => '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
  String e(double b) => '${b.toStringAsFixed(2).replaceAll('.', ',')} €';
  final heute = DateTime.now();
  final neu = DateTime(heute.year, heute.month, heute.day + 10);
  return '${f.name}\n${f.adresse}\n\n${k.name}\n${k.adresse}\n\n${d(heute)}\n\n'
      'Betreff: Zahlungserinnerung zur Rechnung ${r.nummer} vom ${d(r.datum)}\n\n'
      'Sehr geehrte Damen und Herren,\n\n'
      'sicher ist es Ihrer Aufmerksamkeit entgangen: Die Rechnung ${r.nummer} über ${e(s.brutto)} '
      'war am ${d(faelligAm(r))} fällig. Bis heute konnte ich keinen Zahlungseingang feststellen.\n\n'
      'Bitte überweisen Sie den Betrag bis zum ${d(neu)}${f.iban.isEmpty ? '' : ' auf das Konto ${f.iban}'}. '
      'Sollte sich Ihre Zahlung mit diesem Schreiben überschnitten haben, betrachten Sie es bitte als gegenstandslos.\n\n'
      'Mit freundlichen Grüßen\n\n${f.name}';
}
