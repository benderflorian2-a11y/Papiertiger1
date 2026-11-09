/// Steuer-Hilfe für Privatleute und Selbstständige: Einkommensteuer-Schätzung, Ersparnis und Spartipps.
/// Allgemeine Werte, Stand 2026, immer ohne Gewähr und keine Steuerberatung.
library;

import 'steuer.dart';

/// Liest eine Zahl aus einer Eingabe: „12,5“, „1.200“ und „1 200 €“ werden verstanden.
double? zahlAusText(String eingabe) {
  var t = eingabe.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    // Deutsches Format: Punkte sind Tausender, das Komma ist die Dezimalstelle
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\-?\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', ''); // „1.200“ = tausendzweihundert
  }
  return double.tryParse(t);
}

/// Einkommensteuer (Grundtarif, ohne Soli und Kirchensteuer) für ein zu versteuerndes Einkommen.
/// Formel des Einkommensteuertarifs 2026 (§ 32a EStG), auf volle Euro abgerundet.
double einkommensteuer(double zvE) {
  final x = zvE.floorToDouble();
  if (x <= 12348) return 0;
  double st;
  if (x <= 17799) {
    final y = (x - 12348) / 10000;
    st = (914.51 * y + 1400) * y;
  } else if (x <= 69878) {
    final z = (x - 17799) / 10000;
    st = (173.1 * z + 2397) * z + 1034.87;
  } else if (x <= 277825) {
    st = 0.42 * x - 11135.63;
  } else {
    st = 0.45 * x - 19470.38;
  }
  return st.floorToDouble();
}

/// Grob: zu versteuerndes Einkommen eines Angestellten aus dem Jahresbrutto
/// (nach Vorsorgeaufwendungen und Pauschalen).
double zveAusBrutto(double brutto) => (brutto * 0.80 - 1266).clamp(0, double.infinity);

/// Wie viel Steuer spart ein Betrag, der das zu versteuernde Einkommen mindert?
double steuerErsparnis(double zvE, double absetzbar) {
  if (absetzbar <= 0 || zvE <= 0) return 0;
  return einkommensteuer(zvE) - einkommensteuer((zvE - absetzbar).clamp(0, double.infinity));
}

/// Steuersatz auf den nächsten verdienten Euro (Grenzsteuersatz) in Prozent.
double grenzsteuersatz(double zvE) => ((einkommensteuer(zvE + 1000) - einkommensteuer(zvE)) / 10).clamp(0, 45);

/// Handwerkerleistungen: 20 % der Arbeitskosten (nicht Material), höchstens 1.200 € Steuerersparnis.
/// [rechnung] ist der Rechnungsbetrag; ohne Angabe der Arbeitskosten wird ein Lohnanteil von [lohnAnteil] angenommen.
double handwerkerErmaessigung(double rechnung, {double lohnAnteil = 0.6}) =>
    (rechnung * lohnAnteil * 0.20).clamp(0, 1200);

/// Haushaltsnahe Dienstleistungen: 20 % der Kosten, höchstens 4.000 € Steuerersparnis.
double haushaltsnaheErmaessigung(double kosten) => (kosten * 0.20).clamp(0, 4000);

/// Spenden: abziehbar bis 20 % des Gesamtbetrags der Einkünfte.
double spendenAbziehbar(double spenden, double einkuenfte) => spenden.clamp(0, einkuenfte * 0.20);

class SteuerTipp {
  SteuerTipp(this.titel, this.text, {this.ersparnis, this.wichtig = false});

  final String titel;
  final String text;

  /// Geschätzte Steuerersparnis in Euro, wenn berechenbar.
  final double? ersparnis;
  final bool wichtig;
}

/// Persönliche Tipps aus den gesammelten Zahlen. [zvE] ist das (geschätzte) zu versteuernde Einkommen.
List<SteuerTipp> steuerTipps({
  required double zvE,
  required Werbungskosten werbung,
  required Map<String, double> summen,
  required bool selbststaendig,
}) {
  final tipps = <SteuerTipp>[];
  final handwerker = summen['Handwerkerleistungen'] ?? 0;
  final haushalt = summen['Haushaltsnahe Dienstleistungen'] ?? 0;
  final spenden = summen['Spenden'] ?? 0;
  final krank = summen['Krankheitskosten'] ?? 0;

  if (!selbststaendig) {
    if (werbung.summe == 0) {
      tipps.add(SteuerTipp('Werbungskosten ausrechnen',
          'Trag Entfernung zur Arbeit und Homeoffice-Tage im Werbungskosten-Rechner ein. Das Finanzamt zieht automatisch '
          '${euroGlatt(arbeitnehmerPauschbetrag)} ab. Alles darüber senkt deine Steuer zusätzlich.'));
    } else if (werbung.ueberPauschale) {
      tipps.add(SteuerTipp('Einzeln angeben lohnt sich',
          'Deine Werbungskosten liegen ${euroGlatt(werbung.mehrAlsPauschale)} über dem Pauschbetrag. '
          'Gib sie in der Steuererklärung einzeln an.',
          ersparnis: steuerErsparnis(zvE, werbung.mehrAlsPauschale), wichtig: true));
    } else {
      tipps.add(SteuerTipp('Pauschbetrag reicht',
          'Mit ${euroGlatt(werbung.summe)} bleibst du unter dem Pauschbetrag von ${euroGlatt(arbeitnehmerPauschbetrag)}. '
          'Sammle noch Belege für Arbeitsmittel und Fortbildung – erst darüber bringt es etwas.'));
    }
  }
  if (handwerker > 0) {
    final e = handwerkerErmaessigung(handwerker);
    tipps.add(SteuerTipp('Handwerkerleistungen',
        'Du hast ${euroGlatt(handwerker)} gesammelt. 20 % der Arbeitskosten (ohne Material) werden direkt von der Steuer abgezogen, '
        'höchstens 1.200 € im Jahr. Wichtig: Überweisen, nicht bar zahlen, und die Rechnung muss Arbeitskosten getrennt ausweisen.',
        ersparnis: e, wichtig: true));
  }
  if (haushalt > 0) {
    tipps.add(SteuerTipp('Haushaltsnahe Dienstleistungen',
        'Putzhilfe, Gartenpflege, Hausmeister, Winterdienst: 20 % der Kosten, höchstens 4.000 € Ersparnis im Jahr. '
        'Auch die Nebenkostenabrechnung enthält oft einen absetzbaren Anteil.',
        ersparnis: haushaltsnaheErmaessigung(haushalt), wichtig: true));
  }
  if (spenden > 0) {
    tipps.add(SteuerTipp('Spenden',
        'Spenden an anerkannte Organisationen mindern das Einkommen. Bis 300 € genügt der Kontoauszug, darüber brauchst du die Spendenquittung.',
        ersparnis: steuerErsparnis(zvE, spenden)));
  }
  if (krank > 0) {
    tipps.add(SteuerTipp('Krankheitskosten',
        'Du hast ${euroGlatt(krank)} gesammelt. Absetzbar ist nur, was deine „zumutbare Belastung“ übersteigt '
        '(je nach Einkommen und Familie 1 bis 7 % der Einkünfte). Erst bei hohen Kosten lohnt es sich.'));
  }
  tipps.add(SteuerTipp('Belege aufheben',
      'Heb Rechnungen und Überweisungsbelege mindestens bis zum Steuerbescheid auf, Handwerkerrechnungen am besten zwei Jahre länger. '
      'Fotografiere sie im Papiertiger und markiere sie „Für die Steuer“.'));
  if (selbststaendig) {
    tipps.add(SteuerTipp('Steuern zurücklegen',
        'Lege laufend einen Teil vom Gewinn für Einkommensteuer und Vorauszahlungen beiseite. Wie viel, siehst du oben beim Gewinn-Schätzer.',
        wichtig: true));
  }
  return tipps;
}

/// Kleiner Text für Beträge ohne Cent.
String euroGlatt(double b) {
  final s = b.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') out.write('.');
    out.write(s[i]);
  }
  return '$out €';
}

// ---------------------------------------------------------------- Katalog: Was kann ich absetzen?

class AbsetzPunkt {
  const AbsetzPunkt(this.titel, this.kurz, this.details, {this.kategorie, this.wo = ''});

  final String titel;

  /// Ein Satz in einfachen Worten.
  final String kurz;
  final String details;

  /// Passende Steuer-Kategorie im Papiertiger (zum Markieren von Belegen).
  final String? kategorie;

  /// Wo es in der Steuererklärung steht (Anlage).
  final String wo;
}

const absetzenPrivat = <AbsetzPunkt>[
  AbsetzPunkt(
    'Weg zur Arbeit',
    '38 Cent für jeden Kilometer einfache Strecke, pro Arbeitstag.',
    'Ab 2026 zählt jeder Kilometer 38 Cent (2022–2025: 30 Cent bis 20 km, danach 38 Cent). Gezählt wird nur die einfache Strecke, '
        'egal ob Auto, Bahn oder Rad. Nur Tage, an denen du wirklich zur Arbeit gefahren bist. Mit Bus und Bahn, die mehr kosten, '
        'kannst du die tatsächlichen Kosten ansetzen. Mit dem eigenen Auto gibt es keine Obergrenze, bei Bahn, Bus oder Rad gelten höchstens 4.500 € im Jahr.',
    kategorie: 'Fahrtkosten',
    wo: 'Anlage N',
  ),
  AbsetzPunkt(
    'Homeoffice',
    '6 € pro Tag zu Hause, höchstens 210 Tage (1.260 €).',
    'Gilt für Tage, an denen du überwiegend zu Hause arbeitest und nicht zur Arbeit fährst. Am selben Tag zählt entweder der Weg zur Arbeit '
        'oder das Homeoffice. Ein eigenes Arbeitszimmer ist dafür nicht nötig.',
    wo: 'Anlage N',
  ),
  AbsetzPunkt(
    'Arbeitsmittel',
    'Laptop, Bürostuhl, Fachbuch, Werkzeug, Arbeitskleidung – soweit beruflich genutzt.',
    'Computer und Software sind sofort in voller Höhe absetzbar. Andere Dinge bis 800 € netto (Rechnung ohne Mehrwertsteuer) ebenfalls sofort; '
        'teurere Sachen werden über die Nutzungsdauer verteilt. Bei gemischter Nutzung (privat und beruflich) zählt nur der berufliche Anteil. '
        'Normale Kleidung gehört nicht dazu, nur Berufskleidung wie Uniform oder Schutzkleidung.',
    kategorie: 'Arbeitsmittel',
    wo: 'Anlage N',
  ),
  AbsetzPunkt(
    'Fortbildung',
    'Kurse, Seminare, Fachliteratur und Prüfungsgebühren für den Beruf.',
    'Auch Fahrtkosten zum Seminar und Übernachtungen zählen. Eine Erstausbildung gilt nur als Sonderausgabe (bis 6.000 € im Jahr), '
        'Weiterbildung im Beruf dagegen als Werbungskosten ohne Obergrenze.',
    kategorie: 'Fortbildung',
    wo: 'Anlage N',
  ),
  AbsetzPunkt(
    'Handwerker im Haus',
    '20 % der Arbeitskosten bekommst du direkt von der Steuer zurück, bis zu 1.200 € im Jahr.',
    'Gilt für Renovieren, Reparieren und Modernisieren in deiner Wohnung oder deinem Haus: Maler, Elektriker, Installateur, Schornsteinfeger. '
        'Nur die Arbeitskosten zählen, nicht das Material. Du musst die Rechnung überweisen (nicht bar) und die Arbeitskosten müssen auf der Rechnung getrennt stehen. '
        'Das gilt auch für Mieter über die Nebenkostenabrechnung.',
    kategorie: 'Handwerkerleistungen',
    wo: 'Anlage Haushaltsnahe Aufwendungen',
  ),
  AbsetzPunkt(
    'Haushaltsnahe Dienstleistungen',
    '20 % der Kosten, bis zu 4.000 € Ersparnis im Jahr.',
    'Putzhilfe, Gartenpflege, Winterdienst, Hausmeister, Pflege- und Betreuungsleistungen, Umzugsfirma. Ein Minijob im Haushalt zählt ebenfalls. '
        'Auch hier: per Überweisung bezahlen und eine Rechnung haben.',
    kategorie: 'Haushaltsnahe Dienstleistungen',
    wo: 'Anlage Haushaltsnahe Aufwendungen',
  ),
  AbsetzPunkt(
    'Spenden und Mitgliedsbeiträge',
    'Spenden an anerkannte Vereine und Organisationen mindern dein Einkommen.',
    'Bis 300 € genügt der Kontoauszug, darüber brauchst du die Spendenquittung. Abziehbar sind bis zu 20 % deiner Einkünfte. '
        'Beiträge an Parteien werden teilweise direkt von der Steuer abgezogen.',
    kategorie: 'Spenden',
    wo: 'Mantelbogen, Sonderausgaben',
  ),
  AbsetzPunkt(
    'Krankheitskosten',
    'Zuzahlungen, Brille, Zahnersatz, Medikamente – erst ab einer Grenze.',
    'Absetzbar ist nur der Teil über deiner zumutbaren Belastung (je nach Einkommen und Familie 1 bis 7 % der Einkünfte). '
        'Für viele lohnt es sich nur in Jahren mit hohen Kosten. Sammle trotzdem die Belege.',
    kategorie: 'Krankheitskosten',
    wo: 'Mantelbogen, außergewöhnliche Belastungen',
  ),
  AbsetzPunkt(
    'Versicherungen und Altersvorsorge',
    'Kranken- und Pflegeversicherung voll, weitere Versicherungen begrenzt.',
    'Beiträge zur Basis-Kranken- und Pflegeversicherung sowie die Rentenversicherung sind absetzbar, meist schon über die Lohnsteuerbescheinigung. '
        'Haftpflicht, Berufsunfähigkeit und Unfallversicherung zählen bis zu einem Höchstbetrag. Riester und Rürup senken die Steuer zusätzlich.',
    kategorie: 'Versicherungen',
    wo: 'Anlage Vorsorgeaufwand',
  ),
  AbsetzPunkt(
    'Kinderbetreuung',
    'Kita, Tagesmutter, Hort: bis zu 4.000 € pro Kind absetzbar.',
    'Zwei Drittel der Kosten, höchstens 4.000 € je Kind unter 14 Jahren. Nicht absetzbar sind Verpflegung und Nachhilfe. Bezahlen per Überweisung.',
    wo: 'Anlage Kind',
  ),
  AbsetzPunkt(
    'Steuerberater und Software',
    'Kosten für die Steuererklärung selbst.',
    'Beiträge zum Lohnsteuerhilfeverein, Steuerberater oder Steuersoftware können als Werbungskosten angesetzt werden, soweit sie die Einkünfte aus Arbeit betreffen.',
    wo: 'Anlage N',
  ),
];

const absetzenGewerbe = <AbsetzPunkt>[
  AbsetzPunkt(
    'Alles, was der Betrieb braucht',
    'Betriebsausgaben mindern deinen Gewinn und damit die Steuer.',
    'Absetzbar ist, was beruflich veranlasst ist: Material, Waren, Miete, Telefon und Internet (beruflicher Anteil), Software, Werbung, Versicherungen für den Betrieb, '
        'Fahrtkosten für Kundentermine, Fortbildung, Kontoführung, Steuerberater. Private Ausgaben gehören nicht dazu. Heb jeden Beleg auf und gib den Betrieb im Verwendungszweck an.',
    kategorie: 'Arbeitsmittel',
    wo: 'Anlage EÜR',
  ),
  AbsetzPunkt(
    'Geräte und Anschaffungen',
    'Bis 800 € netto sofort absetzen, Computer und Software immer sofort.',
    'Geringwertige Wirtschaftsgüter bis 800 € netto zählen im Jahr des Kaufs voll. Computer, Notebook und Software sind sofort absetzbar. '
        'Teurere Anschaffungen verteilst du über die Nutzungsdauer. Mit dem Investitionsabzugsbetrag kannst du bis zu 50 % einer geplanten Anschaffung schon vorab abziehen.',
    wo: 'Anlage EÜR, Anlagenverzeichnis',
  ),
  AbsetzPunkt(
    'Auto und Fahrten',
    'Betrieblich genutztes Auto: Fahrtenbuch oder 1-%-Regel.',
    'Mit Fahrtenbuch setzt du die tatsächlichen Kosten für betriebliche Fahrten an. Ohne Fahrtenbuch gilt bei privater Nutzung die 1-%-Regel. '
        'Nutzt du ein privates Auto gelegentlich, kannst du 30 Cent pro gefahrenem Kilometer ansetzen.',
    kategorie: 'Fahrtkosten',
    wo: 'Anlage EÜR',
  ),
  AbsetzPunkt(
    'Arbeitszimmer und Homeoffice',
    'Jahrespauschale 1.260 € oder tatsächliche Kosten, wenn es dein Mittelpunkt ist.',
    'Ist dein häuslicher Arbeitsplatz der Mittelpunkt deiner Tätigkeit, kannst du die Jahrespauschale von 1.260 € ansetzen. '
        'Sonst gilt die Tagespauschale von 6 € für Homeoffice-Tage, bis 210 Tage.',
    wo: 'Anlage EÜR',
  ),
  AbsetzPunkt(
    'Bewirtung und Geschenke',
    'Geschäftsessen zu 70 %, Geschenke an Kunden bis 50 € netto.',
    'Bewirtungskosten sind zu 70 % absetzbar, mit Bewirtungsbeleg (Anlass und Teilnehmer). Geschenke an Geschäftspartner nur bis 50 € netto pro Person und Jahr.',
    wo: 'Anlage EÜR',
  ),
  AbsetzPunkt(
    'Kleinunternehmer-Regelung',
    'Keine Umsatzsteuer, wenn der Umsatz klein bleibt.',
    'Ab 2025 gilt: Vorjahresumsatz bis 25.000 € und laufendes Jahr bis 100.000 €. Du weist dann keine Umsatzsteuer aus und kannst auch keine Vorsteuer abziehen. '
        'Lohnt sich vor allem, wenn deine Kunden Privatleute sind.',
    wo: 'Gewerbeanmeldung, Fragebogen zur steuerlichen Erfassung',
  ),
  AbsetzPunkt(
    'Vorauszahlungen und Rücklagen',
    'Das Finanzamt verlangt Steuern im Voraus – leg laufend etwas zurück.',
    'Nach dem ersten Steuerbescheid setzt das Finanzamt Vorauszahlungen fest. Leg zusätzlich einen festen Teil deiner Einnahmen zurück, damit die Nachzahlung dich nicht überrascht.',
    wo: 'Steuerbescheid',
  ),
];
