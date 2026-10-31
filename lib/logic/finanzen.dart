/// Finanzen ohne Bankzugang: Überweisungsdaten aus Briefen, offene Zahlungen,
/// Monatsüberblick und Ratenplan. Es wird nie etwas automatisch bezahlt.
library;

import '../data/models.dart';
import 'datum.dart';
import 'format.dart';

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

// ---------------------------------------------------------------- Kategorien und Budgets

const _haendlerKategorien = <String, List<String>>{
  'Lebensmittel': ['rewe', 'edeka', 'aldi', 'lidl', 'penny', 'netto', 'kaufland', 'norma', 'real', 'tegut', 'globus', 'bäckerei', 'metzgerei'],
  'Drogerie': ['dm ', 'dm-', 'rossmann', 'müller', 'budni'],
  'Haushalt': ['ikea', 'obi', 'bauhaus', 'hornbach', 'toom', 'hagebau', 'action', 'tedi', 'depot'],
  'Kleidung': ['h&m', 'zara', 'c&a', 'primark', 'kik', 'deichmann', 'zalando', 'peek'],
  'Mobilität': ['aral', 'shell', 'esso', 'jet ', 'total', 'tankstelle', 'deutsche bahn', 'db ', 'bvg', 'kvb', 'parkhaus'],
  'Gesundheit': ['apotheke', 'optiker', 'fielmann', 'arzt', 'praxis'],
  'Elektronik': ['media markt', 'mediamarkt', 'saturn', 'cyberport', 'apple', 'expert'],
  'Freizeit': ['kino', 'restaurant', 'café', 'cafe', 'thalia', 'hugendubel', 'mcdonald', 'burger king', 'lieferando'],
};

/// Kategorie eines Belegs: selbst gewählt, sonst aus dem Händlernamen.
String belegKategorie(Beleg b) {
  if (b.kategorie != null) return b.kategorie!;
  final h = ' ${b.haendler.toLowerCase()} ';
  for (final e in _haendlerKategorien.entries) {
    if (e.value.any(h.contains)) return e.key;
  }
  return 'Sonstiges';
}

String vertragKategorie(Vertrag v) => switch (v.art) {
      'Strom' || 'Gas' => 'Wohnen',
      'Handy' || 'Internet' || 'Streaming' || 'Zeitschrift' || 'Fitnessstudio' => 'Freizeit',
      'Versicherung' => 'Versicherungen',
      _ => 'Sonstiges',
    };

/// Ausgaben eines Monats je Kategorie: Belege plus laufende Verträge. Größte zuerst.
List<(String, double)> ausgabenNachKategorie({
  required List<Beleg> belege,
  required List<Vertrag> vertraege,
  required DateTime monat,
}) {
  final m = <String, double>{};
  for (final b in belege) {
    if (b.datum.year != monat.year || b.datum.month != monat.month || b.betrag == null) continue;
    final k = belegKategorie(b);
    m[k] = (m[k] ?? 0) + b.betrag!;
  }
  for (final v in vertraege) {
    if (v.gekuendigt || v.kostenMonat == null) continue;
    final k = vertragKategorie(v);
    m[k] = (m[k] ?? 0) + v.kostenMonat!;
  }
  final l = m.entries.map((e) => (e.key, (e.value * 100).round() / 100)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  return l;
}

class BudgetStand {
  BudgetStand(this.kategorie, this.budget, this.ausgegeben);

  final String kategorie;
  final double budget;
  final double ausgegeben;

  double get anteil => budget <= 0 ? 0 : ausgegeben / budget;
  bool get ueberschritten => ausgegeben > budget;
}

/// Budgets aus den Notizen ('budget:<Kategorie>') gegen die Ausgaben des Monats.
List<BudgetStand> budgets(Map<String, String> notizen, List<(String, double)> ausgaben) {
  final aus = {for (final (k, v) in ausgaben) k: v};
  return [
    for (final e in notizen.entries)
      if (e.key.startsWith('budget:') && (double.tryParse(e.value) ?? 0) > 0)
        BudgetStand(e.key.substring(7), double.parse(e.value), aus[e.key.substring(7)] ?? 0),
  ]..sort((a, b) => b.anteil.compareTo(a.anteil));
}

// ---------------------------------------------------------------- Prognose und Sparziele

/// Erwartete Ausgaben für den nächsten Monat: Fixkosten, Durchschnitt der Belege
/// der letzten drei Monate und offene Zahlungen mit Frist im nächsten Monat.
double prognoseNaechsterMonat({
  required List<Brief> briefe,
  required List<Vertrag> vertraege,
  required List<Beleg> belege,
  required DateTime heute,
}) {
  final fix = vertraege.where((v) => !v.gekuendigt).fold(0.0, (s, v) => s + (v.kostenMonat ?? 0));
  var belegSumme = 0.0;
  for (var i = 1; i <= 3; i++) {
    final m = DateTime(heute.year, heute.month - i);
    belegSumme += belege.where((b) => b.datum.year == m.year && b.datum.month == m.month).fold(0.0, (s, b) => s + (b.betrag ?? 0));
  }
  final naechster = DateTime(heute.year, heute.month + 1);
  final faellig = summe(offeneZahlungen(briefe)
      .where((b) => b.frist != null && b.frist!.year == naechster.year && b.frist!.month == naechster.month));
  return ((fix + belegSumme / 3 + faellig) * 100).round() / 100;
}

/// Wie viel pro Monat noch zurückgelegt werden muss, um das Ziel rechtzeitig zu erreichen.
double? sparrateProMonat(Sparziel z, {required DateTime heute}) {
  final rest = z.ziel - z.gespart;
  if (rest <= 0) return 0;
  if (z.bis == null) return null;
  final monate = (z.bis!.year - heute.year) * 12 + z.bis!.month - heute.month;
  return ((rest / (monate < 1 ? 1 : monate)) * 100).round() / 100;
}

// ---------------------------------------------------------------- Auffälligkeiten und Sparpotenziale

class Auffaelligkeit {
  Auffaelligkeit(this.text, this.briefIds);

  final String text;
  final List<String> briefIds;
}

String _norm(String? s) => (s ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]'), '');

/// Mögliche Doppelrechnungen (gleicher Absender, gleicher Betrag innerhalb von 60 Tagen)
/// und auffällig hohe Rechnungen (mehr als doppelt so hoch wie sonst beim selben Absender).
List<Auffaelligkeit> auffaelligeRechnungen(List<Brief> briefe) {
  final out = <Auffaelligkeit>[];
  final zahlungen = briefe.where((b) => b.betrag != null && !b.guthaben && b.duplikatVon == null).toList()
    ..sort((a, b) => (a.briefDatum ?? a.erstellt).compareTo(b.briefDatum ?? b.erstellt));
  for (var i = 0; i < zahlungen.length; i++) {
    for (var j = i + 1; j < zahlungen.length; j++) {
      final a = zahlungen[i], b = zahlungen[j];
      if (_norm(a.absenderName).isEmpty || _norm(a.absenderName) != _norm(b.absenderName)) continue;
      if ((a.betrag! - b.betrag!).abs() > 0.009) continue;
      final tage = (b.briefDatum ?? b.erstellt).difference(a.briefDatum ?? a.erstellt).inDays.abs();
      if (tage > 60) continue;
      // Eine Mahnung zur selben Rechnung ist keine doppelte Rechnung.
      if (a.typ == 'mahnung' || b.typ == 'mahnung') continue;
      out.add(Auffaelligkeit(
          'Gleicher Betrag ${euroBetrag(a.betrag!)} von ${a.absenderName} zweimal innerhalb von $tage Tagen – doppelt berechnet?',
          [a.id, b.id]));
    }
  }
  final proAbsender = <String, List<Brief>>{};
  for (final b in zahlungen) {
    final k = _norm(b.absenderName);
    if (k.isEmpty || b.typ == 'mahnung') continue;
    proAbsender.putIfAbsent(k, () => []).add(b);
  }
  for (final l in proAbsender.values) {
    if (l.length < 3) continue;
    for (final b in l) {
      final andere = l.where((x) => x.id != b.id).map((x) => x.betrag!).toList();
      final schnitt = andere.reduce((x, y) => x + y) / andere.length;
      if (schnitt > 0 && b.betrag! > schnitt * 2) {
        out.add(Auffaelligkeit(
            '${b.absenderName}: ${euroBetrag(b.betrag!)} ist mehr als doppelt so viel wie sonst (Ø ${euroBetrag(schnitt)}).',
            [b.id]));
      }
    }
  }
  return out;
}

/// Hinweise, wo sich Geld sparen lässt. Allgemeine Hinweise, keine Finanzberatung.
List<String> sparpotenziale({
  required List<Vertrag> vertraege,
  required List<Brief> briefe,
  required List<BudgetStand> budgets,
}) {
  final out = <String>[];
  final aktiv = vertraege.where((v) => !v.gekuendigt).toList();
  final proArt = <String, List<Vertrag>>{};
  for (final v in aktiv) {
    final k = v.art == 'Versicherung' ? 'Versicherung: ${v.versicherungsArt ?? 'Sonstige'}' : v.art;
    proArt.putIfAbsent(k, () => []).add(v);
  }
  proArt.forEach((art, l) {
    if (l.length > 1 && !art.endsWith('Sonstige') && art != 'Sonstiges') {
      final kosten = l.fold(0.0, (s, v) => s + (v.kostenMonat ?? 0));
      out.add('${l.length}× $art (${l.map((v) => v.anbieter).join(', ')})'
          '${kosten > 0 ? ' – zusammen ${euroBetrag(kosten)} im Monat' : ''}. Brauchst du alle?');
    }
  });
  final mahnungen = briefe.where((b) => b.typ == 'mahnung').length;
  if (mahnungen > 0) {
    out.add('$mahnungen ${mahnungen == 1 ? 'Mahnung' : 'Mahnungen'} im Archiv. Mit Erinnerungen vor der Frist sparst du Mahngebühren.');
  }
  for (final b in budgets.where((b) => b.ueberschritten)) {
    out.add('Budget „${b.kategorie}“ überschritten: ${euroBetrag(b.ausgegeben)} von ${euroBetrag(b.budget)}.');
  }
  final teuer = aktiv.where((v) => v.zahlweiseMonate == 1 && (v.kostenMonat ?? 0) >= 20 && v.art == 'Versicherung');
  for (final v in teuer) {
    out.add('${v.anbieter}: Bei jährlicher statt monatlicher Zahlung gibt es oft Rabatt – beim Anbieter nachfragen.');
  }
  return out;
}
