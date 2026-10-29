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

// ---------------------------------------------------------------- Wiederkehrende Rechnungen

/// Wann die nächste Rechnung einer wiederkehrenden Rechnung fällig ist (null = einmalig
/// oder die Folgerechnung gibt es schon).
DateTime? naechsteWiederholung(Rechnung r, List<Rechnung> alle) {
  if (r.wiederholungMonate <= 0 || r.storniert || r.istAngebot) return null;
  final naechste = DateTime(r.datum.year, r.datum.month + r.wiederholungMonate, r.datum.day);
  final schonDa = alle.any((x) =>
      x.id != r.id && !x.istAngebot && x.kundeId == r.kundeId && x.wiederholungMonate == r.wiederholungMonate && x.datum.isAfter(r.datum));
  return schonDa ? null : naechste;
}

/// Erstellt die Folgerechnung: gleiche Positionen, neue Nummer, neues Datum und Leistungszeitraum.
Rechnung folgeRechnung(Rechnung r, List<Rechnung> alle, {required String id, required DateTime datum}) {
  DateTime? plus(DateTime? d) => d == null ? null : DateTime(d.year, d.month + r.wiederholungMonate, d.day);
  return Rechnung(
    id: id,
    art: 'rechnung',
    nummer: naechsteNummer(alle, art: 'rechnung', jahr: datum.year),
    kundeId: r.kundeId,
    datum: datum,
    leistungVon: plus(r.leistungVon),
    leistungBis: plus(r.leistungBis),
    positionen: [for (final p in r.positionen) Position.fromJson(p.toJson())],
    zahlungszielTage: r.zahlungszielTage,
    notiz: r.notiz,
    wiederholungMonate: r.wiederholungMonate,
    projektId: r.projektId,
  );
}

// ---------------------------------------------------------------- Rücklagen und Lücken

class Ruecklage {
  Ruecklage({required this.umsatzsteuer, required this.einkommensteuer});

  /// Eingenommene Umsatzsteuer, die ans Finanzamt geht.
  final double umsatzsteuer;

  /// Grobe Rücklage für Einkommensteuer (Anteil vom Überschuss).
  final double einkommensteuer;

  double get gesamt => umsatzsteuer + einkommensteuer;
}

/// Grobe Rücklage: Umsatzsteuer komplett plus [anteil] (Standard 30 %) vom Überschuss.
/// Nur eine Faustregel, keine Steuerberechnung.
Ruecklage ruecklageVorschlag(Ueberschuss u, {double anteil = 0.30}) => Ruecklage(
      umsatzsteuer: u.ustEingenommen,
      einkommensteuer: u.gewinnVorSteuer <= 0 ? 0 : ((u.gewinnVorSteuer * anteil) * 100).round() / 100,
    );

/// Was für die Buchhaltung noch fehlt: Belege ohne Foto, Ausgaben ohne Kategorie,
/// Rechnungen ohne Kunde, lange offene Rechnungen.
List<String> buchhaltungsLuecken({
  required Zeitraum z,
  required List<Beleg> belege,
  required List<Rechnung> rechnungen,
  required DateTime heute,
}) {
  final out = <String>[];
  final ausgaben = belege.where((b) => b.geschaeftlich && z.enthaelt(b.datum));
  final ohneFoto = ausgaben.where((b) => b.bild == null).length;
  if (ohneFoto > 0) out.add('$ohneFoto geschäftliche ${ohneFoto == 1 ? 'Ausgabe hat' : 'Ausgaben haben'} kein Belegfoto.');
  final ohneKat = ausgaben.where((b) => b.kategorie == null || !betriebsKategorien.contains(b.kategorie)).length;
  if (ohneKat > 0) out.add('$ohneKat geschäftliche ${ohneKat == 1 ? 'Ausgabe hat' : 'Ausgaben haben'} keine Betriebsausgaben-Kategorie.');
  final ohneBetrag = ausgaben.where((b) => b.betrag == null).length;
  if (ohneBetrag > 0) out.add('$ohneBetrag ${ohneBetrag == 1 ? 'Beleg' : 'Belege'} ohne Betrag.');
  for (final r in rechnungen.where((r) => !r.istAngebot && !r.storniert && z.enthaelt(r.datum))) {
    if (r.kundeId.isEmpty) out.add('Rechnung ${r.nummer} hat keinen Kunden.');
    if (r.positionen.isEmpty) out.add('Rechnung ${r.nummer} hat keine Positionen.');
    if (istOffen(r) && heute.difference(faelligAm(r)).inDays > 30) {
      out.add('Rechnung ${r.nummer} ist seit über 30 Tagen überfällig – Zahlung prüfen oder mahnen.');
    }
  }
  return out;
}
