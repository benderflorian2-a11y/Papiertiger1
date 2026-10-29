/// Versteht Briefe der Deutschen Rentenversicherung:
/// Renteninformation, Rentenauskunft, Rentenbescheid und Rentenanpassung.
/// Allgemeine Erklärungen ohne Gewähr, keine Rentenberatung.
library;

/// Eine Angabe aus dem Brief, z. B. „Bisher erreichte Rente: 612,40 €“.
class Fakt {
  const Fakt(this.label, this.wert, [this.hinweis = '']);

  final String label;
  final String wert;
  final String hinweis;

  Map<String, dynamic> toJson() => {'label': label, 'wert': wert, 'hinweis': hinweis};

  factory Fakt.fromJson(Map<String, dynamic> j) => Fakt(
        j['label'] as String? ?? '',
        j['wert'] as String? ?? '',
        j['hinweis'] as String? ?? '',
      );
}

/// Ergebnis einer Spezial-Erklärung, ersetzt die allgemeine Auswertung.
class SpezialErklaerung {
  SpezialErklaerung({
    required this.typKey,
    required this.erklaerung,
    required this.fakten,
    required this.bedeutung,
    required this.aufgaben,
    this.betrag,
    this.istGuthaben = false,
    this.keineFrist = false,
    this.aktenzeichen,
  });

  final String typKey;
  final String erklaerung;
  final List<Fakt> fakten;
  final List<String> bedeutung;
  final List<String> aufgaben;
  final double? betrag;
  final bool istGuthaben;
  final bool keineFrist;
  final String? aktenzeichen;
}

String _e(double b) {
  final s = b.toStringAsFixed(2).replaceAll('.', ',');
  final teile = s.split(',');
  final ganz = teile[0];
  final buf = StringBuffer();
  for (var i = 0; i < ganz.length; i++) {
    if (i > 0 && (ganz.length - i) % 3 == 0) buf.write('.');
    buf.write(ganz[i]);
  }
  return teile[1] == '00' && b >= 1000 ? '$buf €' : '$buf,${teile[1]} €';
}

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Beträge mit oder ohne Cent: „1.234,56 EUR“, „2.150 EUR“, „€ 612,40“.
final _betragRe = RegExp(
    r'(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{2}))?\s?(?:€|eur(?![a-z])|euro)',
    caseSensitive: false);

double _zahl(Match m) {
  final ganz = m.group(1)!.replaceAll('.', '');
  final cent = m.group(2) ?? '00';
  return double.parse('$ganz.$cent');
}

/// Erster Betrag nach einer der Formulierungen, höchstens [abstand] Zeichen danach.
double? _betragNach(String lower, List<String> formulierungen, {int abstand = 350}) {
  for (final f in formulierungen) {
    var start = lower.indexOf(f);
    while (start >= 0) {
      final ab = start + f.length;
      final ende = ab + abstand > lower.length ? lower.length : ab + abstand;
      final m = _betragRe.firstMatch(lower.substring(ab, ende));
      if (m != null) {
        final wert = _zahl(m);
        // Kleine Zahlen wie „1 Prozent“ oder Jahreszahlen ignorieren.
        if (wert >= 1) return wert;
      }
      start = lower.indexOf(f, start + 1);
    }
  }
  return null;
}

DateTime? _datumNach(String lower, List<String> formulierungen, {int abstand = 120}) {
  final re = RegExp(r'(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{4})');
  for (final f in formulierungen) {
    final start = lower.indexOf(f);
    if (start < 0) continue;
    final ab = start + f.length;
    final ende = ab + abstand > lower.length ? lower.length : ab + abstand;
    final m = re.firstMatch(lower.substring(ab, ende));
    if (m != null) {
      final d = DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
      if (d.month == int.parse(m.group(2)!)) return d;
    }
  }
  return null;
}

String? _versicherungsnummer(String text) {
  final m = RegExp(r'\b(\d{2}\s?\d{6}\s?[A-Za-z]\s?\d{3})\b').firstMatch(text);
  return m?.group(1)?.replaceAll(RegExp(r'\s+'), ' ');
}

/// Prüft, ob es ein Rentenbrief ist, und erklärt ihn. Sonst null.
SpezialErklaerung? renteErklaeren(String text) {
  final lower = text.toLowerCase();
  final vonRente = lower.contains('rentenversicherung') ||
      lower.contains('renteninformation') ||
      lower.contains('rentenauskunft') ||
      lower.contains('rentenbescheid');
  if (!vonRente) return null;

  final vnr = _versicherungsnummer(text);
  final az = vnr != null ? 'Versicherungsnummer: $vnr' : null;

  if (lower.contains('rentenbescheid') ||
      (lower.contains('bescheid') && (lower.contains('rente wegen') || lower.contains('altersrente')))) {
    return _bescheid(lower, az);
  }
  if (lower.contains('rentenanpassung') &&
      !lower.contains('renteninformation') &&
      !lower.contains('rentenauskunft')) {
    return _anpassung(lower, az);
  }
  if (lower.contains('renteninformation') || lower.contains('rentenauskunft')) {
    return _information(lower, az, auskunft: lower.contains('rentenauskunft'));
  }
  return null;
}

SpezialErklaerung _information(String lower, String? az, {required bool auskunft}) {
  final name = auskunft ? 'Rentenauskunft' : 'Renteninformation';

  final em = _betragNach(lower, [
    'voll erwerbsgemindert',
    'voller erwerbsminderung',
    'rente wegen voller erwerbsminderung',
  ]);
  final erreicht = _betragNach(lower, [
    'bereits erreichte rentenanwartschaft',
    'bisher erreichte rentenanwartschaft',
    'erreichte rentenanwartschaft',
    'bisher erworbenen',
  ]);
  final hochrechnung = _betragNach(lower, [
    'durchschnitt der letzten fünf kalenderjahre',
    'durchschnitt der letzten 5 kalenderjahre',
    'ohne berücksichtigung künftiger rentenanpassungen',
  ]);
  final mitAnpassung = <double>[];
  final anp = lower.indexOf('anpassungssatz');
  if (anp >= 0) {
    final abschnitt = lower.substring(anp, anp + 800 > lower.length ? lower.length : anp + 800);
    for (final m in _betragRe.allMatches(abschnitt)) {
      final w = _zahl(m);
      if (w >= 100 && !mitAnpassung.contains(w)) mitAnpassung.add(w);
      if (mitAnpassung.length == 2) break;
    }
  }
  final beginn = _datumNach(lower, [
    'regelaltersrente beginnt am',
    'regelaltersgrenze am',
    'regelaltersgrenze erreichen sie am',
    'rentenbeginn',
  ]);

  final fakten = <Fakt>[
    if (hochrechnung != null)
      Fakt('Voraussichtliche Rente', '${_e(hochrechnung)} im Monat',
          'Wenn du bis zur Rente weiter so verdienst wie in den letzten 5 Jahren – ohne künftige Rentenerhöhungen.'),
    if (mitAnpassung.length == 2)
      Fakt('Mit Rentenerhöhungen', 'ca. ${_e(mitAnpassung[0])} bis ${_e(mitAnpassung[1])}',
          'Falls die Renten jedes Jahr um 1 % bzw. 2 % steigen. Durch die Inflation ist dieses Geld später aber auch weniger wert.'),
    if (erreicht != null)
      Fakt('Bisher erreichte Rente', '${_e(erreicht)} im Monat',
          'So viel Rente hast du mit deinen bisherigen Beiträgen schon sicher, auch wenn du ab heute nichts mehr einzahlst.'),
    if (em != null)
      Fakt('Bei voller Erwerbsminderung', '${_e(em)} im Monat',
          'So viel bekämst du jetzt, wenn du aus Gesundheitsgründen gar nicht mehr arbeiten könntest.'),
    if (beginn != null)
      Fakt('Regulärer Rentenbeginn', _d(beginn),
          'Ab diesem Tag kannst du ohne Abzüge in Rente gehen.'),
  ];

  final basis = hochrechnung ?? erreicht;
  final bedeutung = <String>[
    'Du musst nichts tun und nichts bezahlen. Der Brief ist nur eine Information über deine spätere Rente.',
    if (basis != null)
      'Die Beträge sind brutto. Davon gehen noch Kranken- und Pflegeversicherung ab (zusammen grob 11 bis 12 %) und eventuell Steuern. '
          'Von ${_e(basis)} blieben grob geschätzt etwa ${_e((basis * 0.885).roundToDouble())} vor Steuern.'
    else
      'Die Beträge in dem Brief sind brutto. Davon gehen noch Kranken- und Pflegeversicherung und eventuell Steuern ab.',
    'Vergleiche den Betrag mit dem, was du heute zum Leben brauchst. Ist er deutlich niedriger, lohnt sich ein Blick auf zusätzliche Vorsorge, zum Beispiel über deinen Arbeitgeber.',
    'Die Deutsche Rentenversicherung berät kostenlos – telefonisch oder in einer Beratungsstelle in deiner Nähe.',
  ];

  final erklaerung = StringBuffer(
      'Das ist deine $name von der Deutschen Rentenversicherung. '
      '${auskunft ? 'Sie zeigt dir, wie viel Rente du voraussichtlich bekommst, und enthält deinen Versicherungsverlauf.' : 'Sie kommt einmal im Jahr und zeigt dir, wie viel Rente du voraussichtlich bekommst.'} ');
  if (hochrechnung != null) {
    erklaerung.write(
        'Wenn alles so weiterläuft wie bisher, bekommst du später etwa ${_e(hochrechnung)} Rente im Monat (brutto). ');
  } else if (erreicht != null) {
    erklaerung.write('Bis heute hast du dir eine Rente von ${_e(erreicht)} im Monat (brutto) erarbeitet. ');
  }
  erklaerung.write('Du musst nichts bezahlen und auch nichts zurückschicken.');

  return SpezialErklaerung(
    typKey: auskunft ? 'rentenauskunft' : 'renteninformation',
    erklaerung: erklaerung.toString(),
    fakten: fakten,
    bedeutung: bedeutung,
    aufgaben: [
      'Brief gut aufbewahren',
      auskunft
          ? 'Versicherungsverlauf prüfen: Fehlen Zeiten wie Ausbildung, Kindererziehung oder Arbeitslosigkeit?'
          : 'Prüfen, ob Zeiten fehlen (Ausbildung, Kindererziehung, Arbeitslosigkeit) – dann Kontenklärung beantragen',
    ],
    keineFrist: true,
    aktenzeichen: az,
  );
}

const _rentenarten = [
  'regelaltersrente',
  'altersrente für besonders langjährig versicherte',
  'altersrente für langjährig versicherte',
  'altersrente für schwerbehinderte menschen',
  'rente wegen voller erwerbsminderung',
  'rente wegen teilweiser erwerbsminderung',
  'große witwenrente',
  'kleine witwenrente',
  'große witwerrente',
  'kleine witwerrente',
  'witwenrente',
  'witwerrente',
  'halbwaisenrente',
  'vollwaisenrente',
  'waisenrente',
  'altersrente',
];

String _gross(String s) => s.split(' ').map((w) {
      const klein = {'für', 'wegen'};
      if (klein.contains(w) || w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');

SpezialErklaerung _bescheid(String lower, String? az) {
  String? art;
  for (final a in _rentenarten) {
    if (lower.contains(a)) {
      art = _gross(a);
      break;
    }
  }
  final beginn = _datumNach(lower, ['rente beginnt am', 'beginnt am', 'rentenbeginn', 'ab dem', 'ab '], abstand: 40);
  final brutto = _betragNach(lower, [
    'monatliche rente beträgt',
    'die rente beträgt',
    'monatliche rente',
    'rentenhöhe',
  ]);
  final zahlbetrag = _betragNach(lower, [
    'zahlbetrag',
    'auszahlungsbetrag',
    'ausgezahlt',
    'monatlich überwiesen',
  ]);
  final nachzahlung = _betragNach(lower, ['nachzahlung', 'nachzuzahlen'], abstand: 200);

  final fakten = <Fakt>[
    if (art != null) Fakt('Art der Rente', art),
    if (beginn != null) Fakt('Rentenbeginn', _d(beginn)),
    if (brutto != null)
      Fakt('Rente brutto', '${_e(brutto)} im Monat', 'Vor Abzug von Kranken- und Pflegeversicherung.'),
    if (zahlbetrag != null)
      Fakt('Auszahlung', '${_e(zahlbetrag)} im Monat', 'So viel kommt jeden Monat auf deinem Konto an.'),
    if (nachzahlung != null)
      Fakt('Nachzahlung', _e(nachzahlung), 'Geld für zurückliegende Monate, das du einmalig bekommst.'),
  ];

  final erklaerung = StringBuffer(
      'Das ist dein Rentenbescheid von der Deutschen Rentenversicherung. Gute Nachricht: Deine ${art ?? 'Rente'} wurde bewilligt. ');
  if (zahlbetrag != null) {
    erklaerung.write('Du bekommst jeden Monat ${_e(zahlbetrag)} überwiesen');
    erklaerung.write(beginn != null ? ', beginnend ab ${_d(beginn)}. ' : '. ');
  } else if (brutto != null) {
    erklaerung.write('Deine Rente beträgt ${_e(brutto)} im Monat (brutto). ');
  }
  erklaerung.write('Du musst nichts bezahlen.');

  return SpezialErklaerung(
    typKey: 'rentenbescheid',
    erklaerung: erklaerung.toString(),
    fakten: fakten,
    bedeutung: [
      'Die Rente wird automatisch auf dein Konto überwiesen. Du musst dafür nichts weiter tun.',
      'Prüfe den Versicherungsverlauf in der Anlage: Sind alle Zeiten drin (Ausbildung, Kinder, Arbeitslosigkeit)? Fehlende Zeiten können die Rente erhöhen.',
      'Hältst du etwas für falsch, kannst du innerhalb eines Monats Widerspruch einlegen. Kostenlose Hilfe gibt es bei der Rentenversicherung oder Sozialverbänden wie VdK und SoVD.',
      'Je nach Höhe deiner Einkünfte musst du für die Rente eine Steuererklärung abgeben.',
    ],
    aufgaben: [
      'Versicherungsverlauf in der Anlage prüfen',
      'Prüfen, ob die erste Zahlung auf dem Konto ankommt',
      'Bescheid gut aufbewahren',
    ],
    betrag: zahlbetrag ?? brutto,
    istGuthaben: true,
    aktenzeichen: az,
  );
}

SpezialErklaerung _anpassung(String lower, String? az) {
  final neu = _betragNach(lower, ['neuer zahlbetrag', 'zahlbetrag', 'neue rente', 'ab 1. juli']);
  return SpezialErklaerung(
    typKey: 'rentenanpassung',
    erklaerung:
        'Das ist die Mitteilung über die jährliche Rentenanpassung. Deine Rente steigt'
        '${neu != null ? ' und beträgt jetzt ${_e(neu)} im Monat' : ''}. Du musst nichts tun.',
    fakten: [
      if (neu != null) Fakt('Neuer Auszahlungsbetrag', '${_e(neu)} im Monat'),
    ],
    bedeutung: [
      'Die Renten werden jedes Jahr zum 1. Juli angepasst. Das passiert automatisch.',
      'Durch die Erhöhung kann es sein, dass du eine Steuererklärung abgeben musst.',
    ],
    aufgaben: ['Prüfen, ob der neue Betrag auf dem Konto ankommt'],
    betrag: neu,
    istGuthaben: true,
    keineFrist: true,
    aktenzeichen: az,
  );
}
