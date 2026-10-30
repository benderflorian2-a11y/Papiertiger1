/// Buchungsliste für den Steuerberater mit DATEV-Spaltennamen und Kontenvorschlag nach SKR03.
/// Nur ein Vorschlag: Konten und Steuerschlüssel prüft der Steuerberater. Keine Steuerberatung.
library;

import '../data/geschaeft.dart';
import '../data/models.dart';
import 'rechnungen.dart';

/// SKR03-Vorschläge für die Betriebsausgaben-Kategorien.
const skr03Ausgaben = <String, int>{
  'Wareneinkauf und Material': 3400,
  'Büro und Software': 4930,
  'Telefon und Internet': 4920,
  'Fahrzeug und Fahrten': 4530,
  'Reisekosten': 4660,
  'Werbung': 4600,
  'Fortbildung': 4945,
  'Versicherungen und Beiträge': 4360,
  'Miete und Raumkosten': 4210,
  'Fremdleistungen': 3100,
  'Sonstige Betriebsausgaben': 4900,
};

const skr03Bank = 1200;

/// Erlöskonto je Steuersatz (SKR03): 19 % → 8400, 7 % → 8300, Kleinunternehmer → 8195.
int erloesKonto(int ustSatz, {required bool kleinunternehmer}) =>
    kleinunternehmer ? 8195 : (ustSatz == 7 ? 8300 : (ustSatz == 0 ? 8100 : 8400));

String _betrag(double x) => x.toStringAsFixed(2).replaceAll('.', ',');
String _ddmm(DateTime d) => '${d.day.toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}';
/// Buchungstext: höchstens 60 Zeichen, in Anführungszeichen.
String _text(String s) {
  final t = s.replaceAll('"', "'").replaceAll(';', ',').trim();
  return '"${t.length > 60 ? t.substring(0, 60) : t}"';
}

/// Buchungen im Zeitraum (Zufluss/Abfluss): bezahlte Rechnungen als Erlöse, geschäftliche Belege als Ausgaben.
String datevBuchungsliste({
  required Zeitraum z,
  required List<Rechnung> rechnungen,
  required List<Beleg> belege,
  required bool kleinunternehmer,
}) {
  final b = StringBuffer('Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;WKZ Umsatz;Konto;Gegenkonto (ohne BU-Schlüssel);'
      'Belegdatum;Belegfeld 1;Buchungstext\n');
  final bezahlt = rechnungen
      .where((r) => r.istRechnung && !r.storniert && r.bezahltAm != null && z.enthaelt(r.bezahltAm!))
      .toList()
    ..sort((a, c) => a.bezahltAm!.compareTo(c.bezahltAm!));
  for (final r in bezahlt) {
    final gesamt = summenVon(r, kleinunternehmer: kleinunternehmer).brutto;
    // Schlussrechnung: nur der Rest nach den Abschlägen fließt zu
    final faktor = gesamt == 0 ? 0 : zuZahlen(r, rechnungen, kleinunternehmer: kleinunternehmer).brutto / gesamt;
    for (final e in nettoProSatz(r).entries) {
      final brutto = ((kleinunternehmer ? e.value : e.value * (1 + e.key / 100)) * faktor * 100).round() / 100;
      if (brutto.abs() < 0.005) continue;
      b.writeln('${_betrag(brutto)};S;EUR;$skr03Bank;${erloesKonto(e.key, kleinunternehmer: kleinunternehmer)};'
          '${_ddmm(r.bezahltAm!)};${r.nummer};${_text('${r.artName} ${r.nummer}')}');
    }
  }
  final ausgaben = belege.where((x) => x.geschaeftlich && x.betrag != null && z.enthaelt(x.datum)).toList()
    ..sort((a, c) => a.datum.compareTo(c.datum));
  for (final x in ausgaben) {
    final konto = skr03Ausgaben[x.kategorie] ?? 4900;
    b.writeln('${_betrag(x.betrag!)};S;EUR;$konto;$skr03Bank;${_ddmm(x.datum)};;${_text(x.haendler)}');
  }
  return b.toString();
}
