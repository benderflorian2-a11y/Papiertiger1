/// Finanzen ohne Bankzugang: Überweisungsdaten aus Briefen, offene Zahlungen,
/// Monatsüberblick und Ratenplan. Es wird nie etwas automatisch bezahlt.
library;

import '../data/models.dart';
import 'datum.dart';

// ---------------------------------------------------------------- IBAN

String ibanKompakt(String s) => s.replaceAll(RegExp(r'\s'), '').toUpperCase();

/// IBAN in Vierergruppen, wie auf Papier.
String ibanLesbar(String s) {
  final k = ibanKompakt(s);
  return [for (var i = 0; i < k.length; i += 4) k.substring(i, i + 4 > k.length ? k.length : i + 4)].join(' ');
}

/// Prüfziffer nach ISO 13616 (Modulo 97). Deutsche IBAN: 22 Zeichen.
bool ibanGueltig(String s) {
  final k = ibanKompakt(s);
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{10,30}$').hasMatch(k)) return false;
  if (k.startsWith('DE') && k.length != 22) return false;
  final umgestellt = k.substring(4) + k.substring(0, 4);
  var rest = 0;
  for (final c in umgestellt.codeUnits) {
    final wert = c >= 65 ? (c - 55).toString() : String.fromCharCode(c);
    for (final z in wert.codeUnits) {
      rest = (rest * 10 + (z - 48)) % 97;
    }
  }
  return rest == 1;
}

// ---------------------------------------------------------------- Überweisung

class Ueberweisung {
  Ueberweisung({this.empfaenger, this.iban, this.bic, this.betrag, this.zweck});

  final String? empfaenger;
  final String? iban;
  final String? bic;
  final double? betrag;
  final String? zweck;

  bool get vollstaendig => iban != null && betrag != null && zweck != null;
}

final _ibanRe = RegExp(r'\b([A-Z]{2}\d{2}(?:\s?[A-Z0-9]{4}){3,7}(?:\s?[A-Z0-9]{1,3})?)\b');
final _bicRe = RegExp(r'\b(?:BIC|SWIFT)\s*[:.]?\s*([A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?)\b');
final _zweckRe = RegExp(
    r'(?:verwendungszweck|zahlungsgrund|bitte\s+(?:immer\s+)?angeben)\s*[:.]?\s*([^\n]{3,80})',
    caseSensitive: false);
final _nummerRe = RegExp(
    r'(kassenzeichen|rechnungsnummer|rechnungs-nr\.?|rg\.-nr\.?|kundennummer|vertragsnummer|beitragsnummer|steuernummer|aktenzeichen)\s*[:.]?\s*([A-Za-z0-9][A-Za-z0-9/\-.]{3,30}(?: \d[\d/\-.]{1,10}){0,3})',
    caseSensitive: false);

/// Sucht IBAN (mit gültiger Prüfziffer), BIC und Verwendungszweck. Die eigene IBAN wird übersprungen.
Ueberweisung ueberweisungFinden(String text, {String? empfaenger, double? betrag, String? eigeneIban}) {
  final eigene = eigeneIban == null ? null : ibanKompakt(eigeneIban);
  String? iban;
  for (final m in _ibanRe.allMatches(text.toUpperCase())) {
    final k = ibanKompakt(m.group(1)!);
    // Am Ende können Zeichen eines folgenden Worts hängen: kürzen, bis die Prüfziffer passt.
    for (var l = k.length; l >= 15; l--) {
      final kandidat = k.substring(0, l);
      if (ibanGueltig(kandidat) && kandidat != eigene) {
        iban = kandidat;
        break;
      }
    }
    if (iban != null) break;
  }
  final bic = _bicRe.firstMatch(text.toUpperCase())?.group(1);
  var zweck = _zweckRe.firstMatch(text)?.group(1)?.trim();
  if (zweck != null) zweck = zweck.replaceAll(RegExp(r'[.;]\s*$'), '');
  if (zweck == null || zweck.isEmpty) {
    final n = _nummerRe.firstMatch(text);
    if (n != null) zweck = n.group(2)!.trim();
  }
  return Ueberweisung(empfaenger: empfaenger, iban: iban, bic: bic, betrag: betrag, zweck: zweck);
}

// ---------------------------------------------------------------- Überblick

/// Offene Zahlungen: Betrag zu zahlen, nicht bezahlt, nicht erledigt. Früheste Frist zuerst.
List<Brief> offeneZahlungen(List<Brief> briefe) => briefe
    .where((b) => b.betrag != null && !b.guthaben && b.bezahltAm == null && !b.erledigt)
    .toList()
  ..sort((a, b) => (a.frist ?? DateTime(9999)).compareTo(b.frist ?? DateTime(9999)));

/// Geld, das du bekommen sollst (Erstattung, Guthaben, Rente …).
List<Brief> erwarteteGutschriften(List<Brief> briefe) =>
    briefe.where((b) => b.betrag != null && b.guthaben && !b.erledigt).toList();

double summe(Iterable<Brief> l) => l.fold(0.0, (s, b) => s + (b.betrag ?? 0));

class MonatsUeberblick {
  MonatsUeberblick({
    required this.fixkosten,
    required this.faellig,
    required this.bezahlt,
    required this.ausgaben,
  });

  /// Laufende Verträge, umgerechnet auf einen Monat.
  final double fixkosten;

  /// Offene Zahlungen mit Frist in diesem Monat (inkl. überfälliger).
  final double faellig;

  /// In diesem Monat als bezahlt markiert.
  final double bezahlt;

  /// Summe der Kassenbons / Belege in diesem Monat.
  final double ausgaben;

  double get gesamt => fixkosten + faellig + bezahlt + ausgaben;
}

MonatsUeberblick monatsUeberblick({
  required List<Brief> briefe,
  required List<Vertrag> vertraege,
  required List<Beleg> belege,
  required DateTime monat,
}) {
  bool imMonat(DateTime d) => d.year == monat.year && d.month == monat.month;
  final monatsEnde = DateTime(monat.year, monat.month + 1, 0);
  return MonatsUeberblick(
    fixkosten: vertraege.where((v) => !v.gekuendigt).fold(0.0, (s, v) => s + (v.kostenMonat ?? 0)),
    faellig: summe(offeneZahlungen(briefe).where((b) => b.frist != null && !nurTag(b.frist!).isAfter(monatsEnde))),
    bezahlt: summe(briefe.where((b) => !b.guthaben && b.bezahltAm != null && imMonat(b.bezahltAm!))),
    ausgaben: belege.where((b) => imMonat(b.datum)).fold(0.0, (s, b) => s + (b.betrag ?? 0)),
  );
}

// ---------------------------------------------------------------- Ratenplan

class Rate {
  Rate(this.nummer, this.datum, this.betrag, this.rest);

  final int nummer;
  final DateTime datum;
  final double betrag;

  /// Restschuld nach dieser Rate.
  final double rest;
}

/// Ratenplan ohne Zinsen: gleiche Raten, die letzte ist kleiner.
List<Rate> ratenplan(double gesamt, double rate, DateTime erste) {
  if (gesamt <= 0 || rate <= 0) return [];
  final out = <Rate>[];
  var rest = (gesamt * 100).round();
  final r = (rate * 100).round();
  var i = 0;
  while (rest > 0 && i < 240) {
    final b = rest < r ? rest : r;
    rest -= b;
    out.add(Rate(i + 1, plusMonate(erste, i), b / 100, rest / 100));
    i++;
  }
  return out;
}

final _zahlAufgabe = RegExp(r'zahl|überweis|begleich', caseSensitive: false);

/// Vermerkt die Zahlung. Zahlungs-Aufgaben werden abgehakt; sind dann alle
/// Aufgaben erledigt, gilt der Brief als erledigt.
void alsBezahltMarkieren(Brief b, DateTime am) {
  b.bezahltAm = am;
  for (final a in b.aufgaben) {
    if (_zahlAufgabe.hasMatch(a.text)) a.erledigt = true;
  }
  if (b.aufgaben.every((a) => a.erledigt)) b.erledigt = true;
}

void bezahltZuruecknehmen(Brief b) {
  b.bezahltAm = null;
  b.erledigt = false;
}
