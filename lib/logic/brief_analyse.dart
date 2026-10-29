/// Versteht Briefe: erkennt Absender, Art, Frist, Betrag und Aktenzeichen
/// im erkannten Text und erklärt den Brief in einfachen Worten.
/// Läuft komplett auf dem Handy, ohne Internet.
library;

import 'datum.dart';
import 'rente.dart';

export 'rente.dart' show Fakt;

class Kategorie {
  const Kategorie(this.key, this.name, this.vonText, this.stichworte,
      {this.hinweis, this.stark = const []});

  final String key;
  final String name;

  /// z. B. „vom Finanzamt“ – für den Satz „Dieser Brief kommt …“
  final String vonText;
  final List<String> stichworte;
  final String? hinweis;

  /// Eindeutige Erkennungszeichen, zählen fünffach (z. B. „Deutsche Rentenversicherung“).
  final List<String> stark;
}

class BriefTyp {
  const BriefTyp(this.key, this.name, this.beschreibung, this.stichworte);

  final String key;
  final String name;
  final String beschreibung;
  final List<String> stichworte;
}

/// Reihenfolge = Vorrang bei Gleichstand.
const kategorien = <Kategorie>[
  Kategorie('finanzamt', 'Finanzamt', 'vom Finanzamt',
      ['finanzamt', 'steuerbescheid', 'einkommensteuer', 'steuernummer', 'umsatzsteuer'],
      stark: ['finanzamt'],
      hinweis:
          'Gegen einen Steuerbescheid kannst du innerhalb eines Monats Einspruch einlegen, wenn er dir falsch vorkommt.'),
  Kategorie('familienkasse', 'Familienkasse', 'von der Familienkasse',
      ['familienkasse', 'kindergeld', 'kinderzuschlag'],
      stark: ['familienkasse']),
  Kategorie('jobcenter', 'Jobcenter', 'vom Jobcenter',
      ['jobcenter', 'bürgergeld', 'grundsicherung für arbeitsuchende'],
      stark: ['jobcenter'],
      hinweis:
          'Bei Fragen zu Leistungen vom Jobcenter helfen dir kostenlose Sozialberatungsstellen, z. B. von Caritas oder Diakonie.'),
  Kategorie('arbeitsagentur', 'Agentur für Arbeit', 'von der Agentur für Arbeit',
      ['agentur für arbeit', 'arbeitsagentur', 'arbeitslosengeld']),
  Kategorie('rente', 'Rentenversicherung', 'von der Rentenversicherung',
      ['rentenversicherung', 'rentenbescheid', 'renteninformation', 'rentenauskunft',
       'rentenanpassung', 'versicherungsverlauf', 'regelaltersrente', 'rentenanwartschaft'],
      stark: ['deutsche rentenversicherung', 'renteninformation', 'rentenauskunft', 'rentenbescheid']),
  Kategorie('krankenkasse', 'Krankenkasse', 'von deiner Krankenkasse',
      ['krankenkasse', 'krankenversicherung', 'pflegekasse', 'aok', 'barmer', 'techniker', 'dak-gesundheit', 'ikk', 'bkk']),
  Kategorie('inkasso', 'Inkasso', 'von einem Inkassobüro',
      ['inkasso', 'forderungsmanagement', 'hauptforderung'],
      stark: ['inkasso'],
      hinweis:
          'Prüfe zuerst, ob die Forderung berechtigt ist und ob du den ursprünglichen Gläubiger kennst. Bei Zweifeln hilft die Verbraucherzentrale.'),
  Kategorie('gericht', 'Gericht', 'von einem Gericht',
      ['amtsgericht', 'landgericht', 'mahnbescheid', 'gerichtsvollzieher', 'mahngericht'],
      stark: ['amtsgericht', 'mahngericht'],
      hinweis: 'Post vom Gericht solltest du nie liegen lassen. Hol dir im Zweifel schnell Hilfe.'),
  Kategorie('bussgeld', 'Bußgeldstelle', 'von der Bußgeldstelle',
      ['bußgeld', 'bussgeld', 'verwarnungsgeld', 'ordnungswidrigkeit', 'anhörungsbogen', 'zentrale bußgeldstelle']),
  Kategorie('rundfunk', 'Rundfunkbeitrag', 'vom Beitragsservice (Rundfunkbeitrag)',
      ['rundfunkbeitrag', 'beitragsservice', 'beitragsnummer'],
      stark: ['beitragsservice']),
  Kategorie('vermieter', 'Vermieter', 'von deinem Vermieter oder der Hausverwaltung',
      ['hausverwaltung', 'vermieter', 'mietvertrag', 'nebenkostenabrechnung', 'betriebskostenabrechnung', 'mieterhöhung'],
      hinweis:
          'Eine Nebenkostenabrechnung kannst du prüfen lassen, z. B. beim örtlichen Mieterverein.'),
  Kategorie('energie', 'Energieversorger', 'von deinem Strom- oder Gasanbieter',
      ['stadtwerke', 'stromrechnung', 'jahresabrechnung strom', 'abschlag', 'strom', 'erdgas', 'gasversorgung', 'kilowattstunde', 'kwh']),
  Kategorie('telefon', 'Telefon & Internet', 'von deinem Telefon- oder Internetanbieter',
      ['telekom', 'vodafone', 'telefónica', 'telefonica', 'o2', '1&1', 'mobilfunk', 'dsl']),
  Kategorie('versicherung', 'Versicherung', 'von einer Versicherung',
      ['versicherung', 'versicherungsschein', 'police', 'haftpflicht', 'hausrat',
       'kfz-versicherung', 'lebensversicherung', 'unfallversicherung', 'versicherungsnehmer']),
  Kategorie('stadt', 'Stadt / Gemeinde', 'von deiner Stadt oder Gemeinde',
      ['stadtverwaltung', 'bürgeramt', 'einwohnermeldeamt', 'gemeinde', 'landratsamt', 'wohngeldstelle', 'grundsteuer', 'ordnungsamt', 'stadt ']),
  // Bewusst ohne „Bank“ oder „Sparkasse“: Die stehen in fast jeder Fußzeile.
  Kategorie('bank', 'Bank', 'von deiner Bank',
      ['kontoauszug', 'girokonto', 'kreditkartenabrechnung', 'dispositionskredit']),
];

const sonstigeKategorie =
    Kategorie('sonstiges', 'Sonstiges', 'von einem Absender, den der Tiger nicht kennt', []);

Kategorie kategorieFuer(String key) => kategorien.firstWhere((k) => k.key == key,
    orElse: () => sonstigeKategorie);

/// Reihenfolge = Vorrang.
const briefTypen = <BriefTyp>[
  BriefTyp('renteninformation', 'Renteninformation',
      'eine Renteninformation: eine jährliche Übersicht über deine spätere Rente.',
      ['renteninformation']),
  BriefTyp('rentenauskunft', 'Rentenauskunft',
      'eine Rentenauskunft: eine ausführliche Übersicht über deine spätere Rente.',
      ['rentenauskunft']),
  BriefTyp('rentenbescheid', 'Rentenbescheid',
      'ein Rentenbescheid: Deine Rente wurde festgesetzt.', ['rentenbescheid']),
  BriefTyp('rentenanpassung', 'Rentenanpassung',
      'eine Mitteilung über die Rentenanpassung.', ['rentenanpassung']),
  BriefTyp('mahnbescheid', 'Mahnbescheid',
      'ein gerichtlicher Mahnbescheid. Dagegen kannst du innerhalb von zwei Wochen Widerspruch einlegen. Hol dir dafür unbedingt schnell Hilfe.',
      ['mahnbescheid']),
  BriefTyp('mahnung', 'Mahnung',
      'eine Mahnung: Eine Zahlung ist offen und wurde nicht rechtzeitig bezahlt.',
      ['mahnung', 'zahlungserinnerung', 'letzte erinnerung', 'mahngebühr', 'zahlungsverzug']),
  BriefTyp('anhoerung', 'Anhörung',
      'eine Anhörung: Du darfst dich zu einem Vorwurf äußern, bevor entschieden wird.',
      ['anhörung', 'anhörungsbogen']),
  BriefTyp('mitwirkung', 'Unterlagen anfordern',
      'eine Aufforderung, Unterlagen oder Nachweise einzureichen.',
      ['mitwirkung', 'fehlende unterlagen', 'reichen sie bitte', 'bitte reichen sie', 'bitte senden sie', 'benötigen wir noch', 'nachweise ein']),
  BriefTyp('erhoehung', 'Preiserhöhung',
      'eine Preis- oder Beitragserhöhung. Oft hast du in so einem Fall ein Sonderkündigungsrecht.',
      ['preiserhöhung', 'preisanpassung', 'beitragserhöhung', 'beitragsanpassung', 'mieterhöhung']),
  BriefTyp('kuendigung', 'Kündigung',
      'eine Kündigung oder eine Kündigungsbestätigung.',
      ['kündigung', 'kündigungsbestätigung']),
  BriefTyp('abrechnung', 'Abrechnung',
      'eine Abrechnung: Hier wird abgerechnet, was du verbraucht oder bezahlt hast. Das kann eine Nachzahlung oder ein Guthaben ergeben.',
      ['abrechnung', 'jahresabrechnung']),
  BriefTyp('bescheid', 'Bescheid',
      'ein Bescheid: Die Behörde teilt dir eine Entscheidung mit, zum Beispiel wie viel du zahlen musst oder bekommst.',
      ['bescheid']),
  BriefTyp('rechnung', 'Rechnung', 'eine Rechnung: Du sollst einen Betrag bezahlen.',
      ['rechnung', 'rechnungsbetrag', 'zahlbar bis', 'bitte überweisen']),
];

const sonstigerTyp = BriefTyp('schreiben', 'Schreiben', 'ein Informationsschreiben.', []);

BriefTyp typFuer(String key) =>
    briefTypen.firstWhere((t) => t.key == key, orElse: () => sonstigerTyp);

class Analyse {
  Analyse({
    required this.kategorie,
    required this.typ,
    required this.erklaerung,
    required this.aufgaben,
    this.absenderName,
    this.frist,
    this.fristUnsicher = false,
    this.betrag,
    this.istGuthaben = false,
    this.aktenzeichen,
    this.briefDatum,
    this.fakten = const [],
    this.bedeutung = const [],
  });

  final Kategorie kategorie;
  final BriefTyp typ;
  final String erklaerung;
  final List<String> aufgaben;
  final String? absenderName;
  final DateTime? frist;
  final bool fristUnsicher;
  final double? betrag;
  final bool istGuthaben;
  final String? aktenzeichen;
  final DateTime? briefDatum;
  final List<Fakt> fakten;
  final List<String> bedeutung;
}

class _Fund<T> {
  _Fund(this.wert, this.start);

  final T wert;
  final int start;
}

const _monate = {
  'januar': 1, 'jänner': 1, 'februar': 2, 'märz': 3, 'maerz': 3, 'april': 4,
  'mai': 5, 'juni': 6, 'juli': 7, 'august': 8, 'september': 9, 'oktober': 10,
  'november': 11, 'dezember': 12,
};

DateTime? _gueltig(int tag, int monat, int jahr) {
  if (jahr < 100) jahr += 2000;
  if (monat < 1 || monat > 12 || tag < 1 || tag > 31) return null;
  if (jahr < 1990 || jahr > 2100) return null;
  final d = DateTime(jahr, monat, tag);
  if (d.month != monat) return null; // z. B. 31.02.
  return d;
}

List<_Fund<DateTime>> datumsFunde(String text) {
  final funde = <_Fund<DateTime>>[];
  final zahl = RegExp(r'(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4}|\d{2})(?!\d)');
  for (final m in zahl.allMatches(text)) {
    final d = _gueltig(int.parse(m.group(1)!), int.parse(m.group(2)!),
        int.parse(m.group(3)!));
    if (d != null) funde.add(_Fund(d, m.start));
  }
  final wort = RegExp(
      r'(\d{1,2})\.?\s+(januar|jänner|februar|märz|maerz|april|mai|juni|juli|august|september|oktober|november|dezember)\s+(\d{4})',
      caseSensitive: false);
  for (final m in wort.allMatches(text)) {
    final monat = _monate[m.group(2)!.toLowerCase()];
    if (monat == null) continue;
    final d = _gueltig(int.parse(m.group(1)!), monat, int.parse(m.group(3)!));
    if (d != null) funde.add(_Fund(d, m.start));
  }
  funde.sort((a, b) => a.start.compareTo(b.start));
  return funde;
}

double _parseBetrag(String s) =>
    double.parse(s.replaceAll('.', '').replaceAll(' ', '').replaceAll(',', '.'));

List<_Fund<double>> betragsFunde(String text) {
  final funde = <_Fund<double>>[];
  final nach = RegExp(r'(\d{1,3}(?:\.\d{3})*,\d{2})\s?(?:€|eur(?![a-z])|euro)',
      caseSensitive: false);
  final vor = RegExp(r'(?:€|eur(?![a-z]))\s?(\d{1,3}(?:\.\d{3})*,\d{2})',
      caseSensitive: false);
  for (final m in nach.allMatches(text)) {
    funde.add(_Fund(_parseBetrag(m.group(1)!), m.start));
  }
  for (final m in vor.allMatches(text)) {
    funde.add(_Fund(_parseBetrag(m.group(1)!), m.start));
  }
  funde.sort((a, b) => a.start.compareTo(b.start));
  return funde;
}

bool _istBuchstabe(String c) =>
    RegExp(r'[a-zäöüß]').hasMatch(c);

/// Zählt Treffer, die am Wortanfang stehen. So zählt „versicherung“
/// nicht in „Rentenversicherung“ oder „Krankenversicherung“.
int wortanfangTreffer(String lower, String wort) {
  var n = 0;
  var i = lower.indexOf(wort);
  while (i >= 0) {
    if (i == 0 || !_istBuchstabe(lower[i - 1])) n++;
    i = lower.indexOf(wort, i + 1);
  }
  return n;
}

String _davor(String lower, int start, int laenge) {
  final von = start - laenge < 0 ? 0 : start - laenge;
  return lower.substring(von, start);
}

const _fristWoerter = [
  'bis zum', 'bis spätestens', 'spätestens', 'zahlbar bis', 'fällig am',
  'fällig bis', 'fälligkeit', 'frist', 'einzureichen bis', 'bis '
];

const _betragWoerter = [
  'gesamtbetrag', 'zu zahlen', 'zahlbetrag', 'offener betrag', 'offen',
  'nachzahlung', 'betrag', 'summe', 'gesamt', 'überweisen', 'forderung',
  'erstattung', 'guthaben'
];

Analyse analysiereBrief(String text, {DateTime? heute}) {
  final jetzt = nurTag(heute ?? DateTime.now());
  final lower = text.toLowerCase();

  // Absender
  var kategorie = sonstigeKategorie;
  var bester = 0;
  for (final k in kategorien) {
    var punkte = 0;
    for (final w in k.stichworte) {
      punkte += wortanfangTreffer(lower, w);
    }
    for (final w in k.stark) {
      punkte += 5 * wortanfangTreffer(lower, w);
    }
    if (punkte > bester) {
      bester = punkte;
      kategorie = k;
    }
  }

  // Art des Briefs
  var typ = sonstigerTyp;
  for (final t in briefTypen) {
    if (t.stichworte.any(lower.contains)) {
      typ = t;
      break;
    }
  }

  // Daten: Briefdatum und Frist
  final daten = datumsFunde(text);
  DateTime? briefDatum;
  final fristKandidaten = <DateTime>[];
  for (final f in daten) {
    final davor = _davor(lower, f.start, 40);
    if (_fristWoerter.any(davor.contains)) {
      fristKandidaten.add(f.wert);
    } else if (briefDatum == null &&
        (_davor(lower, f.start, 20).contains('datum') ||
            f.start < text.length * 0.35)) {
      briefDatum = f.wert;
    }
  }

  DateTime? frist;
  var fristUnsicher = false;
  final zukunft = fristKandidaten.where((d) => !d.isBefore(jetzt)).toList()..sort();
  if (zukunft.isNotEmpty) {
    frist = zukunft.first;
  } else if (fristKandidaten.isNotEmpty) {
    // Nur eine kürzlich abgelaufene Frist zählen, keine alten Zeiträume
    // wie „01.01.2025 bis 31.12.2025“.
    fristKandidaten.sort();
    final letzte = fristKandidaten.last;
    final grenze = briefDatum ?? jetzt.subtract(const Duration(days: 60));
    if (!letzte.isBefore(grenze)) frist = letzte;
  }

  if (frist == null) {
    final relativ = RegExp(
        r'(innerhalb|binnen)\s+(von\s+)?(einer|eines|einem|zwei|drei|vier|sechs|\d+)\s+(woche|wochen|monat|monats|monaten|tag|tage|tagen)',
        caseSensitive: false);
    final m = relativ.firstMatch(text);
    if (m != null) {
      const zahlwoerter = {
        'einer': 1, 'eines': 1, 'einem': 1, 'zwei': 2, 'drei': 3, 'vier': 4, 'sechs': 6
      };
      final anzahlText = m.group(3)!.toLowerCase();
      final anzahl = zahlwoerter[anzahlText] ?? int.tryParse(anzahlText) ?? 1;
      final einheit = m.group(4)!.toLowerCase();
      final basis = briefDatum ?? jetzt;
      if (einheit.startsWith('monat')) {
        frist = plusMonate(basis, anzahl);
      } else if (einheit.startsWith('woche')) {
        frist = basis.add(Duration(days: 7 * anzahl));
      } else {
        frist = basis.add(Duration(days: anzahl));
      }
      fristUnsicher = true;
    } else if (typ.key == 'mahnbescheid') {
      frist = (briefDatum ?? jetzt).add(const Duration(days: 14));
      fristUnsicher = true;
    }
  }

  // Betrag
  final betraege = betragsFunde(text);
  double? betrag;
  var istGuthaben = false;
  for (final f in betraege) {
    final davor = _davor(lower, f.start, 50);
    if (_betragWoerter.any(davor.contains)) {
      betrag = f.wert;
      istGuthaben = davor.contains('erstattung') || davor.contains('guthaben');
    }
  }
  if (betrag == null && betraege.isNotEmpty) {
    betrag = betraege.map((f) => f.wert).reduce((a, b) => a > b ? a : b);
  }
  if (betrag != null && !istGuthaben) {
    istGuthaben = lower.contains('erstatten wir') ||
        lower.contains('wird ihnen erstattet') ||
        lower.contains('ihr guthaben');
  }

  // Aktenzeichen
  String? aktenzeichen;
  final az = RegExp(
      r'(aktenzeichen|az\.|geschäftszeichen|steuernummer|kundennummer|vertragsnummer|versicherungsnummer|rechnungsnummer|mitgliedsnummer|kassenzeichen|beitragsnummer|bg-nummer)\s*[:.]?\s*([a-z0-9][a-z0-9/\-.]*(?: [0-9][0-9/\-.]*)*)',
      caseSensitive: false);
  final azTreffer = az.firstMatch(text);
  if (azTreffer != null) {
    final label = azTreffer.group(1)!;
    final wert = azTreffer.group(2)!.trim().replaceAll(RegExp(r'[.\-]+$'), '');
    if (wert.length >= 3) {
      final schoen = label.toLowerCase() == 'az.'
          ? 'Aktenzeichen'
          : label[0].toUpperCase() + label.substring(1).toLowerCase();
      aktenzeichen = '$schoen: $wert';
    }
  }

  // Absendername: erste Zeile, die zum Absender passt
  String? absenderName;
  for (final zeile in text.split('\n')) {
    final z = zeile.trim();
    if (z.length < 3 || z.length > 70) continue;
    if (kategorie.stichworte.any(z.toLowerCase().contains)) {
      absenderName = z;
      break;
    }
  }

  final spezial = renteErklaeren(text);
  if (spezial != null) {
    return Analyse(
      kategorie: kategorieFuer('rente'),
      typ: typFuer(spezial.typKey),
      erklaerung: spezial.erklaerung,
      aufgaben: spezial.aufgaben,
      absenderName: 'Deutsche Rentenversicherung',
      frist: spezial.keineFrist ? null : frist,
      fristUnsicher: spezial.keineFrist ? false : fristUnsicher,
      betrag: spezial.betrag,
      istGuthaben: spezial.istGuthaben,
      aktenzeichen: spezial.aktenzeichen ?? aktenzeichen,
      briefDatum: briefDatum,
      fakten: spezial.fakten,
      bedeutung: spezial.bedeutung,
    );
  }

  final erklaerung = _erklaerung(kategorie, typ, betrag, istGuthaben, frist, fristUnsicher);
  final aufgaben = _aufgaben(kategorie, typ, betrag, istGuthaben, frist, fristUnsicher, aktenzeichen);

  return Analyse(
    kategorie: kategorie,
    typ: typ,
    erklaerung: erklaerung,
    aufgaben: aufgaben,
    absenderName: absenderName,
    frist: frist,
    fristUnsicher: fristUnsicher,
    betrag: betrag,
    istGuthaben: istGuthaben,
    aktenzeichen: aktenzeichen,
    briefDatum: briefDatum,
  );
}

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _e(double b) {
  final s = b.toStringAsFixed(2).replaceAll('.', ',');
  final teile = s.split(',');
  final ganz = teile[0];
  final buf = StringBuffer();
  for (var i = 0; i < ganz.length; i++) {
    if (i > 0 && (ganz.length - i) % 3 == 0) buf.write('.');
    buf.write(ganz[i]);
  }
  return '$buf,${teile[1]} €';
}

String _erklaerung(Kategorie k, BriefTyp t, double? betrag, bool guthaben,
    DateTime? frist, bool unsicher) {
  final saetze = <String>[
    'Dieser Brief kommt ${k.vonText}.',
    'Es ist ${t.beschreibung}',
  ];
  if (betrag != null) {
    saetze.add(guthaben
        ? 'Gute Nachricht: Es geht um ein Guthaben oder eine Erstattung von ${_e(betrag)}.'
        : 'Es geht um einen Betrag von ${_e(betrag)}.');
  }
  if (frist != null) {
    saetze.add(unsicher
        ? 'Es gibt eine Frist, die ungefähr am ${_d(frist)} endet. Bitte prüfe das genaue Datum im Brief.'
        : 'Wichtig: Du musst bis zum ${_d(frist)} reagieren.');
  } else {
    saetze.add(
        'Der Tiger hat keine Frist gefunden. Lies den Brief zur Sicherheit trotzdem einmal durch.');
  }
  if (k.hinweis != null && (t.key == 'bescheid' || k.key != 'finanzamt')) {
    saetze.add(k.hinweis!);
  }
  return saetze.join(' ');
}

List<String> _aufgaben(Kategorie k, BriefTyp t, double? betrag, bool guthaben,
    DateTime? frist, bool unsicher, String? az) {
  final bis = frist != null ? ' bis ${_d(frist)}' : '';
  final liste = <String>[];
  switch (t.key) {
    case 'mahnbescheid':
      liste.add('Prüfen, ob die Forderung stimmt');
      liste.add('Sofort beraten lassen, z. B. Verbraucherzentrale oder Anwalt (Widerspruch nur 2 Wochen möglich)');
    case 'anhoerung':
      liste.add('Anhörungsbogen ausfüllen und zurückschicken$bis');
      liste.add('Zur Sache musst du dich nicht äußern – im Zweifel beraten lassen');
    case 'mitwirkung':
      liste.add('Angeforderte Unterlagen zusammensuchen');
      liste.add('Unterlagen einreichen$bis');
    case 'bescheid':
      liste.add('Bescheid prüfen: Stimmen alle Angaben?');
      liste.add('Falls etwas falsch ist: Einspruch oder Widerspruch innerhalb der Frist – im Zweifel beraten lassen');
    case 'erhoehung':
      liste.add('Prüfen, ob sich ein Wechsel lohnt (Sonderkündigungsrecht)');
  }
  if (k.key == 'inkasso') {
    liste.insert(0, 'Forderung prüfen: Kennst du den ursprünglichen Gläubiger?');
  }
  if (betrag != null && t.key != 'mahnbescheid') {
    if (guthaben) {
      liste.add('Prüfen, ob ${_e(betrag)} auf deinem Konto ankommen');
    } else if (t.key != 'erhoehung' && t.key != 'kuendigung') {
      final zweck = az != null ? ' – Verwendungszweck: ${az.split(': ').last}' : '';
      liste.add('${_e(betrag)} überweisen$bis$zweck');
    }
  }
  if (unsicher) liste.add('Genaue Frist im Brief nachlesen');
  if (liste.isEmpty) liste.add('Brief lesen und aufbewahren');
  return liste;
}

/// Erstes gültiges Datum im Text (z. B. für Kassenbons).
DateTime? erstesDatum(String text) {
  final funde = datumsFunde(text);
  return funde.isEmpty ? null : funde.first.wert;
}

/// Summe auf einem Kassenbon: Betrag nach „Summe“, „Gesamt“ oder „zu zahlen“,
/// sonst der größte Betrag.
double? summeFinden(String text) {
  final lower = text.toLowerCase();
  final funde = betragsFunde(text);
  if (funde.isEmpty) {
    // Kassenbons schreiben oft keine Währung: „SUMME 12,99“
    final m = RegExp(r'(summe|gesamt|total|zu zahlen)[^0-9\n]{0,20}(\d{1,3}(?:\.\d{3})*,\d{2})',
            caseSensitive: false)
        .firstMatch(text);
    return m == null ? null : _parseBetrag(m.group(2)!);
  }
  for (final f in funde) {
    final davor = _davor(lower, f.start, 25);
    if (davor.contains('summe') || davor.contains('gesamt') || davor.contains('zu zahlen')) {
      return f.wert;
    }
  }
  return funde.map((f) => f.wert).reduce((a, b) => a > b ? a : b);
}

/// Erste sinnvolle Zeile als Händlername.
String ersteZeile(String text) {
  for (final zeile in text.split('\n')) {
    final z = zeile.trim();
    if (z.length >= 3 && RegExp(r'[A-Za-zÄÖÜäöü]{3}').hasMatch(z)) {
      return z.length > 40 ? z.substring(0, 40) : z;
    }
  }
  return '';
}
