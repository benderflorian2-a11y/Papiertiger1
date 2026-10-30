/// Rechnungen und Angebote für Selbstständige: Summen, Nummern, Pflichtangaben,
/// Einnahmen-Überschuss und Umsatzsteuer-Überblick. Keine Steuerberatung.
library;

import '../data/geschaeft.dart';
import '../data/models.dart';

class Summen {
  Summen(this.netto, this.ust, {this.rabatt = 0});

  /// Netto nach Rabatt.
  final double netto;

  /// Umsatzsteuer je Steuersatz.
  final Map<int, double> ust;

  /// Abgezogener Rabatt (netto).
  final double rabatt;

  double get zwischensumme => _rund(netto + rabatt);
  double get ustGesamt => ust.values.fold(0.0, (a, b) => a + b);
  double get brutto => _rund(netto + ustGesamt);
}

double _rund(double x) => (x * 100).round() / 100;

/// Netto je Steuersatz nach Rabatt (Rabatt anteilig auf alle Sätze verteilt).
Map<int, double> nettoProSatz(Rechnung r) {
  final roh = <int, double>{};
  for (final p in r.positionen) {
    roh[p.ustSatz] = (roh[p.ustSatz] ?? 0) + p.netto;
  }
  final summe = roh.values.fold(0.0, (a, b) => a + b);
  final rabatt = rabattVon(r);
  if (summe <= 0 || rabatt <= 0) return roh;
  final faktor = (summe - rabatt) / summe;
  return {for (final e in roh.entries) e.key: e.value * faktor};
}

/// Rabatt in Euro (netto), höchstens die Zwischensumme.
double rabattVon(Rechnung r) {
  final summe = r.positionen.fold(0.0, (a, p) => a + p.netto);
  final x = _rund(summe * r.rabattProzent / 100 + r.rabattBetrag);
  return x > summe ? summe : (x < 0 ? 0 : x);
}

Summen summenVon(Rechnung r, {required bool kleinunternehmer}) {
  final proSatz = nettoProSatz(r);
  final rabatt = rabattVon(r);
  final zwischen = r.positionen.fold(0.0, (a, p) => a + p.netto);
  return Summen(
    _rund(zwischen - rabatt),
    {
      if (!kleinunternehmer)
        for (final e in proSatz.entries)
          if (e.key > 0) e.key: _rund(e.value * e.key / 100),
    },
    rabatt: rabatt,
  );
}

/// Abschlagsrechnungen, die zu derselben Beauftragung gehören wie [r] (nicht storniert).
List<Rechnung> abschlaegeZu(Rechnung r, List<Rechnung> alle) => r.bezugId == null
    ? []
    : (alle.where((x) => x.art == 'abschlag' && x.bezugId == r.bezugId && x.id != r.id && !x.storniert).toList()
      ..sort((a, b) => a.datum.compareTo(b.datum)));

/// Was auf diesem Beleg tatsächlich zu zahlen ist: bei der Schlussrechnung abzüglich der Abschläge.
Summen zuZahlen(Rechnung r, List<Rechnung> alle, {required bool kleinunternehmer}) {
  final s = summenVon(r, kleinunternehmer: kleinunternehmer);
  if (r.art != 'schluss') return s;
  var netto = s.netto;
  final ust = {...s.ust};
  for (final a in abschlaegeZu(r, alle)) {
    final sa = summenVon(a, kleinunternehmer: kleinunternehmer);
    netto -= sa.netto;
    for (final e in sa.ust.entries) {
      ust[e.key] = _rund((ust[e.key] ?? 0) - e.value);
    }
  }
  return Summen(_rund(netto), ust);
}

/// Abschlagsrechnung über [prozent] % eines Angebots bzw. einer Auftragsbestätigung.
Rechnung abschlagAus(Rechnung auftrag, List<Rechnung> alle,
    {required String id, required DateTime datum, required double prozent, required int zahlungszielTage}) {
  final bezug = auftrag.bezugId ?? auftrag.id;
  final nr = alle.where((x) => x.art == 'abschlag' && x.bezugId == bezug && !x.storniert).length + 1;
  String pz(double x) => x.toStringAsFixed(x == x.roundToDouble() ? 0 : 1).replaceAll('.', ',');
  return Rechnung(
    id: id,
    art: 'abschlag',
    nummer: naechsteNummer(alle, art: 'abschlag', jahr: datum.year),
    kundeId: auftrag.kundeId,
    datum: datum,
    leistungVon: datum,
    zahlungszielTage: zahlungszielTage,
    projektId: auftrag.projektId,
    bezugId: bezug,
    positionen: [
      for (final e in nettoProSatz(auftrag).entries)
        Position(
          text: '$nr. Abschlag: ${pz(prozent)} % aus ${auftrag.artName} ${auftrag.nummer}'
              '${nettoProSatz(auftrag).length > 1 ? ' (${e.key} %)' : ''}',
          preis: _rund(e.value * prozent / 100),
          einheit: 'pauschal',
          ustSatz: e.key,
        ),
    ],
  );
}

/// Schlussrechnung: alle Leistungen des Auftrags, die Abschläge werden abgezogen.
Rechnung schlussAus(Rechnung auftrag, List<Rechnung> alle,
    {required String id, required DateTime datum, required int zahlungszielTage}) {
  final kopie = Rechnung.fromJson(auftrag.toJson());
  return Rechnung(
    id: id,
    art: 'schluss',
    nummer: naechsteNummer(alle, art: 'schluss', jahr: datum.year),
    kundeId: auftrag.kundeId,
    datum: datum,
    leistungVon: auftrag.leistungVon ?? datum,
    leistungBis: auftrag.leistungBis,
    zahlungszielTage: zahlungszielTage,
    projektId: auftrag.projektId,
    bezugId: auftrag.bezugId ?? auftrag.id,
    positionen: kopie.positionen,
    rabattProzent: auftrag.rabattProzent,
    rabattBetrag: auftrag.rabattBetrag,
    notiz: auftrag.notiz,
  );
}

/// Beleg einer anderen Art aus einem bestehenden machen (z. B. Angebot → Auftragsbestätigung).
Rechnung umwandeln(Rechnung r, List<Rechnung> alle, {required String art, required String id, required DateTime datum, required int zahlungszielTage}) {
  final j = r.toJson()
    ..['id'] = id
    ..['art'] = art
    ..['nummer'] = naechsteNummer(alle, art: art, jahr: datum.year)
    ..['datum'] = datum.toIso8601String()
    ..['zahlungszielTage'] = zahlungszielTage
    ..['bezahltAm'] = null
    ..['gemahntAm'] = null
    ..['mahnstufe'] = 0
    ..['versendetAm'] = null
    ..['storniert'] = false
    ..['bezugId'] = r.bezugId ?? r.id;
  return Rechnung.fromJson(j);
}

/// Fortlaufende Nummer je Jahr und Art: 2026-001 (Rechnung, Abschlags- und Schlussrechnung
/// teilen sich einen Nummernkreis), A-2026-001 (Angebot), KV-, AB- und LS-.
String naechsteNummer(List<Rechnung> alle, {required String art, required int jahr}) {
  final praefix = switch (art) {
    'angebot' => 'A-$jahr-',
    'kostenvoranschlag' => 'KV-$jahr-',
    'auftragsbestaetigung' => 'AB-$jahr-',
    'lieferschein' => 'LS-$jahr-',
    _ => '$jahr-',
  };
  bool gleicherKreis(Rechnung r) => switch (art) {
        'rechnung' || 'abschlag' || 'schluss' => r.istRechnung,
        _ => r.art == art,
      };
  var max = 0;
  for (final r in alle) {
    if (!gleicherKreis(r) || !r.nummer.startsWith(praefix)) continue;
    final n = int.tryParse(r.nummer.substring(praefix.length)) ?? 0;
    if (n > max) max = n;
  }
  return '$praefix${(max + 1).toString().padLeft(3, '0')}';
}

DateTime faelligAm(Rechnung r) => DateTime(r.datum.year, r.datum.month, r.datum.day + r.zahlungszielTage);

bool istOffen(Rechnung r) => r.istRechnung && !r.storniert && r.bezahltAm == null;

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
      if (r.istRechnung && r.leistungVon == null) 'Leistungsdatum oder -zeitraum',
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
    if (!r.istRechnung || r.storniert) continue;
    final s = zuZahlen(r, rechnungen, kleinunternehmer: kleinunternehmer);
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

// ---------------------------------------------------------------- Mahnwesen

const mahnstufenNamen = ['', 'Zahlungserinnerung', '1. Mahnung', 'Letzte Mahnung'];

/// Welche Mahnstufe als Nächstes dran ist (null = nichts zu tun). Zwischen zwei Stufen
/// liegen mindestens [abstandTage] Tage.
int? naechsteMahnstufe(Rechnung r, {required DateTime heute, int abstandTage = 10}) {
  if (!ueberfaellig(r, heute: heute) || r.mahnstufe >= 3) return null;
  if (r.gemahntAm != null && heute.difference(r.gemahntAm!).inDays < abstandTage) return null;
  return r.mahnstufe + 1;
}

/// Brieftext für Zahlungserinnerung (Stufe 1), 1. Mahnung (2) und letzte Mahnung (3).
/// [gebuehr] wird nur ab Stufe 2 aufgeführt. Keine Rechtsberatung.
String mahnText(Rechnung r, Firma f, Kunde k, Summen s, {required int stufe, double gebuehr = 0, DateTime? heute}) {
  String d(DateTime x) => '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
  String e(double b) => '${b.toStringAsFixed(2).replaceAll('.', ',')} €';
  final h = heute ?? DateTime.now();
  final neu = DateTime(h.year, h.month, h.day + (stufe >= 3 ? 7 : 10));
  final mitGebuehr = stufe >= 2 && gebuehr > 0;
  final gesamt = s.brutto + (mitGebuehr ? gebuehr : 0);
  final konto = f.iban.isEmpty ? '' : ' auf das Konto ${f.iban}';
  final betreff = 'Betreff: ${mahnstufenNamen[stufe.clamp(1, 3)]} zur ${r.artName} ${r.nummer} vom ${d(r.datum)}';
  final text = switch (stufe) {
    1 => 'sicher ist es Ihrer Aufmerksamkeit entgangen: Die ${r.artName} ${r.nummer} über ${e(s.brutto)} '
        'war am ${d(faelligAm(r))} fällig. Bis heute konnte ich keinen Zahlungseingang feststellen.\n\n'
        'Bitte überweisen Sie den Betrag bis zum ${d(neu)}$konto. '
        'Sollte sich Ihre Zahlung mit diesem Schreiben überschnitten haben, betrachten Sie es bitte als gegenstandslos.',
    2 => 'leider ist die ${r.artName} ${r.nummer} über ${e(s.brutto)}, fällig am ${d(faelligAm(r))}, '
        'trotz meiner Zahlungserinnerung noch nicht bezahlt.\n\n'
        '${mitGebuehr ? 'Offener Betrag: ${e(s.brutto)}\nMahngebühr: ${e(gebuehr)}\nGesamt: ${e(gesamt)}\n\n' : ''}'
        'Bitte überweisen Sie ${mitGebuehr ? 'den Gesamtbetrag' : 'den Betrag'} bis spätestens ${d(neu)}$konto '
        'unter Angabe der Rechnungsnummer ${r.nummer}.',
    _ => 'trotz Erinnerung und Mahnung ist die ${r.artName} ${r.nummer} vom ${d(r.datum)} weiterhin offen.\n\n'
        '${mitGebuehr ? 'Offener Betrag: ${e(s.brutto)}\nMahngebühr: ${e(gebuehr)}\nGesamt: ${e(gesamt)}\n\n' : 'Offener Betrag: ${e(s.brutto)}\n\n'}'
        'Ich fordere Sie letztmalig auf, den Betrag bis zum ${d(neu)}$konto zu überweisen. '
        'Sollte bis dahin keine Zahlung eingehen, werde ich ohne weitere Ankündigung weitere Schritte einleiten, '
        'z. B. ein gerichtliches Mahnverfahren. Die dadurch entstehenden Kosten gehen zu Ihren Lasten.',
  };
  return '${f.name}\n${f.adresse}\n\n${k.name}\n${k.adresse}\n\n${d(h)}\n\n$betreff\n\n'
      'Sehr geehrte Damen und Herren,\n\n$text\n\nMit freundlichen Grüßen\n\n${f.name}';
}

/// Zahlungserinnerung (Mahnstufe 1).
String zahlungserinnerungText(Rechnung r, Firma f, Kunde k, Summen s) => mahnText(r, f, k, s, stufe: 1);

// ---------------------------------------------------------------- GiroCode

/// Inhalt eines GiroCodes (EPC-QR-Code, Version 002): Banking-Apps lesen daraus Empfänger,
/// IBAN, Betrag und Verwendungszweck. Leer, wenn Name oder IBAN fehlen.
String giroCode({required String name, required String iban, String bic = '', required double betrag, required String zweck}) {
  final ib = iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (name.trim().isEmpty || ib.length < 15) return '';
  String kurz(String t, int n) => t.length > n ? t.substring(0, n) : t;
  final b = betrag <= 0 ? '' : 'EUR${betrag.toStringAsFixed(2)}';
  return ['BCD', '002', '1', 'SCT', bic.replaceAll(' ', '').toUpperCase(), kurz(name.trim(), 70), ib, b, '', '', kurz(zweck.trim(), 140)]
      .join('\n');
}

// ---------------------------------------------------------------- Wiederkehrende Rechnungen

/// Wann die nächste Rechnung einer wiederkehrenden Rechnung fällig ist (null = einmalig
/// oder die Folgerechnung gibt es schon).
DateTime? naechsteWiederholung(Rechnung r, List<Rechnung> alle) {
  if (r.wiederholungMonate <= 0 || r.storniert || !r.istRechnung) return null;
  final naechste = DateTime(r.datum.year, r.datum.month + r.wiederholungMonate, r.datum.day);
  final schonDa = alle.any((x) =>
      x.id != r.id && x.istRechnung && x.kundeId == r.kundeId && x.wiederholungMonate == r.wiederholungMonate && x.datum.isAfter(r.datum));
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
  for (final r in rechnungen.where((r) => r.istRechnung && !r.storniert && z.enthaelt(r.datum))) {
    if (r.kundeId.isEmpty) out.add('Rechnung ${r.nummer} hat keinen Kunden.');
    if (r.positionen.isEmpty) out.add('Rechnung ${r.nummer} hat keine Positionen.');
    if (istOffen(r) && heute.difference(faelligAm(r)).inDays > 30) {
      out.add('Rechnung ${r.nummer} ist seit über 30 Tagen überfällig – Zahlung prüfen oder mahnen.');
    }
  }
  return out;
}

/// Kurzer E-Mail-Text zum Beleg.
String begleitText(Rechnung r, Firma f, Kunde? k, Summen zahlen) {
  String e(double b) => '${b.toStringAsFixed(2).replaceAll('.', ',')} €';
  String d(DateTime x) => '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
  final anrede = k == null || k.name.trim().isEmpty ? 'Guten Tag' : 'Guten Tag ${k.name.trim()}';
  final kern = switch (r.art) {
    'angebot' => 'anbei erhalten Sie mein Angebot ${r.nummer}. Bei Fragen melden Sie sich gern – ich freue mich auf Ihren Auftrag.',
    'kostenvoranschlag' => 'anbei erhalten Sie den Kostenvoranschlag ${r.nummer}.',
    'auftragsbestaetigung' => 'vielen Dank für Ihren Auftrag! Anbei die Auftragsbestätigung ${r.nummer}.',
    'lieferschein' => 'anbei der Lieferschein ${r.nummer}.',
    _ => 'anbei erhalten Sie die ${r.artName} ${r.nummer} über ${e(zahlen.brutto)}, zahlbar bis ${d(faelligAm(r))}'
        '${f.iban.isEmpty ? '' : ' auf das Konto ${f.iban}'}. Am einfachsten scannen Sie den GiroCode auf der Rechnung mit Ihrer Banking-App.',
  };
  return '$anrede,\n\n$kern\n\nMit freundlichen Grüßen\n${f.name}${f.telefon.isEmpty ? '' : '\n${f.telefon}'}';
}
