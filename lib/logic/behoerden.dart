/// Behörden: Widerspruchs- und Einspruchsfristen aus Bescheiden.
/// Reines Dart, damit es testbar ist. Ergebnisse sind immer „bitte prüfen“.
library;

import 'datum.dart';

/// Ostersonntag (Gaußsche Osterformel, gregorianisch).
DateTime ostersonntag(int jahr) {
  final a = jahr % 19, b = jahr ~/ 100, c = jahr % 100;
  final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final monat = (h + l - 7 * m + 114) ~/ 31;
  final tag = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(jahr, monat, tag);
}

/// Bundesweite gesetzliche Feiertage. Landesfeiertage sind nicht enthalten.
Set<DateTime> feiertage(int jahr) {
  final o = ostersonntag(jahr);
  DateTime plus(int t) => DateTime(o.year, o.month, o.day + t);
  return {
    DateTime(jahr, 1, 1),
    plus(-2), // Karfreitag
    plus(1), // Ostermontag
    DateTime(jahr, 5, 1),
    plus(39), // Christi Himmelfahrt
    plus(50), // Pfingstmontag
    DateTime(jahr, 10, 3),
    DateTime(jahr, 12, 25),
    DateTime(jahr, 12, 26),
  };
}

bool istWerktag(DateTime d) {
  final t = nurTag(d);
  return t.weekday != DateTime.saturday && t.weekday != DateTime.sunday && !feiertage(t.year).contains(t);
}

/// Fällt eine Frist auf Samstag, Sonntag oder Feiertag, endet sie am nächsten Werktag.
DateTime naechsterWerktag(DateTime d) {
  var t = nurTag(d);
  while (!istWerktag(t)) {
    t = DateTime(t.year, t.month, t.day + 1);
  }
  return t;
}

/// Tage, nach denen ein per Post verschickter Bescheid als bekannt gegeben gilt
/// (seit 2025 vier Tage nach Aufgabe zur Post, vorher drei).
int bekanntgabeTage(DateTime briefDatum) => briefDatum.isBefore(DateTime(2025, 1, 1)) ? 3 : 4;

class Rechtsbehelf {
  Rechtsbehelf({required this.art, required this.quelle, this.bekanntgabe, this.fristEnde, this.verschoben = false});

  /// Widerspruch, Einspruch oder Klage.
  final String art;

  /// Der Satz aus dem Brief, auf dem die Frist beruht.
  final String quelle;

  /// Angenommene Bekanntgabe (Briefdatum + 4 Tage), null ohne Briefdatum.
  final DateTime? bekanntgabe;
  final DateTime? fristEnde;

  /// Wurde das Ende auf den nächsten Werktag verschoben?
  final bool verschoben;
}

final _monatsfrist = RegExp(
    r'[^.\n]*(?:innerhalb|binnen)\s+(?:eines|einem|1)\s+monats?\b[^.]*\.?',
    caseSensitive: false);

/// Sucht die Rechtsbehelfsbelehrung („innerhalb eines Monats nach Bekanntgabe …
/// Widerspruch/Einspruch/Klage“) und rechnet das Fristende ungefähr aus.
Rechtsbehelf? rechtsbehelfFinden(String text, {DateTime? briefDatum, DateTime? zugang}) {
  for (final m in _monatsfrist.allMatches(text)) {
    final satz = m.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = satz.toLowerCase();
    final art = lower.contains('einspruch')
        ? 'Einspruch'
        : lower.contains('widerspruch')
            ? 'Widerspruch'
            : lower.contains('klage')
                ? 'Klage'
                : null;
    if (art == null) continue;
    // Bekanntgabe: Briefdatum + 4 Tage; kam der Brief nachweislich später an, zählt der Zugang.
    DateTime? bekanntgabe;
    if (briefDatum != null) {
      final d = nurTag(briefDatum);
      bekanntgabe = DateTime(d.year, d.month, d.day + bekanntgabeTage(d));
    }
    if (zugang != null && (bekanntgabe == null || nurTag(zugang).isAfter(bekanntgabe))) {
      bekanntgabe = nurTag(zugang);
    }
    if (bekanntgabe == null) return Rechtsbehelf(art: art, quelle: satz);
    final roh = plusMonate(bekanntgabe, 1);
    final ende = naechsterWerktag(roh);
    return Rechtsbehelf(
        art: art, quelle: satz, bekanntgabe: bekanntgabe, fristEnde: ende, verschoben: ende != roh);
  }
  return null;
}

// ---------------------------------------------------------------- Checklisten für Behördengänge

class BehoerdenCheckliste {
  const BehoerdenCheckliste(this.key, this.titel, this.kurz,
      {required this.frist, required this.unterlagen, required this.schritte, this.quelle = ''});

  final String key;
  final String titel;
  final String kurz;

  /// Frist in Worten; leer, wenn es keine feste gibt.
  final String frist;

  /// Gesetz bzw. Fundstelle der Frist.
  final String quelle;
  final List<String> unterlagen;
  final List<String> schritte;

  List<String> get punkte => [...unterlagen, ...schritte];
}

/// Allgemeine Checklisten. Anforderungen und Gebühren unterscheiden sich je nach Stadt –
/// die App zeigt deshalb immer den Hinweis, sie bei der zuständigen Behörde zu prüfen.
const behoerdenChecklisten = [
  BehoerdenCheckliste('ummelden', 'Wohnsitz anmelden oder ummelden', 'Nach einem Umzug innerhalb Deutschlands',
      frist: 'Innerhalb von zwei Wochen nach dem Einzug',
      quelle: '§ 17 Abs. 1 Bundesmeldegesetz',
      unterlagen: [
        'Personalausweis oder Reisepass (für alle Personen, die umziehen)',
        'Wohnungsgeberbestätigung vom Vermieter (§ 19 Bundesmeldegesetz)',
        'Ausgefülltes Anmeldeformular (oft online vorab möglich)',
        'Bei Kindern: Geburtsurkunde, bei getrennten Eltern ggf. Zustimmung des anderen Elternteils',
      ],
      schritte: [
        'Termin beim Bürgeramt buchen',
        'Neue Adresse auf dem Ausweis eintragen lassen (passiert bei der Anmeldung)',
        'Nachsendeauftrag bei der Post einrichten',
        'Neue Adresse mitteilen: Bank, Arbeitgeber, Krankenkasse, Versicherungen, Rundfunkbeitrag',
        'Auto: Adresse bei der Zulassungsstelle ändern lassen',
        'Verträge für Strom, Gas, Internet ummelden oder kündigen',
      ]),
  BehoerdenCheckliste('abmelden', 'Abmelden bei Umzug ins Ausland', 'Wenn du keine Wohnung in Deutschland behältst',
      frist: 'Innerhalb von zwei Wochen nach dem Auszug',
      quelle: '§ 17 Abs. 2 Bundesmeldegesetz',
      unterlagen: ['Personalausweis oder Reisepass', 'Neue Adresse im Ausland, falls bekannt'],
      schritte: [
        'Abmeldung beim Bürgeramt (teilweise auch schriftlich oder online)',
        'Abmeldebestätigung aufbewahren – brauchen Krankenkasse, Rundfunkbeitrag, Banken',
        'Krankenversicherung, Rundfunkbeitrag und Verträge kündigen oder anpassen',
        'Finanzamt informieren, wenn du noch Einkünfte in Deutschland hast',
      ]),
  BehoerdenCheckliste('gewerbe', 'Gewerbe anmelden', 'Wenn du dich mit einem Gewerbe selbstständig machst',
      frist: 'Gleichzeitig mit dem Beginn der Tätigkeit',
      quelle: '§ 14 Gewerbeordnung',
      unterlagen: [
        'Personalausweis oder Reisepass',
        'Erlaubnisse, falls nötig (z. B. Meisterbrief bzw. Eintrag in die Handwerksrolle, Gaststättenerlaubnis)',
        'Bei GmbH, UG oder OHG: Handelsregisterauszug bzw. Gesellschaftsvertrag',
        'Gebühr – je nach Gemeinde unterschiedlich',
      ],
      schritte: [
        'Gewerbeanmeldung beim Gewerbeamt (oft online)',
        'Fragebogen zur steuerlichen Erfassung über ELSTER ans Finanzamt – innerhalb eines Monats (§ 138 Abgabenordnung)',
        'Kleinunternehmerregelung ja oder nein entscheiden (im Fragebogen)',
        'Berufsgenossenschaft: Anmeldung innerhalb einer Woche (§ 192 SGB VII)',
        'IHK bzw. Handwerkskammer meldet sich von selbst – Beitrag prüfen',
        'Geschäftskonto und Buchhaltung einrichten (in Papiertiger: Selbstständige)',
        'Freiberufler (z. B. Beratung, Kunst, Heilberufe) brauchen keine Gewerbeanmeldung, aber den Fragebogen ans Finanzamt',
      ]),
  BehoerdenCheckliste('aufenthalt', 'Aufenthaltstitel verlängern', 'Bei der Ausländerbehörde',
      frist: 'Antrag unbedingt vor Ablauf des Titels stellen – Termin am besten 6 bis 8 Wochen vorher anfragen',
      quelle: '§ 81 Abs. 4 Aufenthaltsgesetz (Antrag vor Ablauf: der Aufenthalt gilt bis zur Entscheidung als erlaubt)',
      unterlagen: [
        'Reisepass (gültig) und bisheriger Aufenthaltstitel',
        'Aktuelles biometrisches Passfoto',
        'Antragsformular deiner Ausländerbehörde',
        'Nachweis Lebensunterhalt: Arbeitsvertrag, letzte Gehaltsabrechnungen oder Bescheide',
        'Mietvertrag bzw. Wohnungsnachweis und Meldebescheinigung',
        'Nachweis Krankenversicherung',
        'Je nach Titel: Sprachzertifikat, Nachweis Integrationskurs, Studienbescheinigung',
      ],
      schritte: [
        'Ablaufdatum als Frist im Papiertiger eintragen',
        'Termin bei der Ausländerbehörde anfragen – schriftlich, damit du einen Nachweis hast',
        'Wenn kein Termin vor Ablauf frei ist: Antrag trotzdem vorher schriftlich stellen und Kopie aufheben',
        'Fiktionsbescheinigung mitnehmen bzw. anfordern, falls die Entscheidung dauert',
        'Bei Unsicherheit: kostenlose Migrationsberatung fragen',
      ]),
  BehoerdenCheckliste('ausweis', 'Personalausweis oder Reisepass beantragen', 'Neu oder Verlängerung',
      frist: '',
      unterlagen: [
        'Alter Ausweis bzw. Pass',
        'Biometrisches Passfoto (vielerorts digital – vorher bei der Behörde nachfragen)',
        'Beim ersten Antrag: Geburts- oder Heiratsurkunde',
        'Gebühr',
      ],
      schritte: [
        'Ablaufdatum prüfen und als Termin eintragen',
        'Termin beim Bürgeramt buchen',
        'Abholung: alter Ausweis mitbringen, PIN-Brief aufheben',
      ]),
  BehoerdenCheckliste('auto', 'Auto ummelden', 'Nach einem Umzug oder beim Halterwechsel',
      frist: 'Unverzüglich nach dem Umzug bzw. Kauf',
      quelle: 'Fahrzeug-Zulassungsverordnung',
      unterlagen: [
        'Personalausweis bzw. Reisepass mit neuer Adresse',
        'Zulassungsbescheinigung Teil I (Fahrzeugschein), bei Halterwechsel auch Teil II',
        'eVB-Nummer der Kfz-Versicherung (bei Halterwechsel)',
        'Nachweis der Hauptuntersuchung',
        'SEPA-Mandat für die Kfz-Steuer',
      ],
      schritte: [
        'Termin bei der Zulassungsstelle oder online (i-Kfz)',
        'Kennzeichen behalten oder neue nehmen (je nach Ort möglich)',
        'Versicherung über neue Adresse informieren',
      ]),
  BehoerdenCheckliste('arbeitslos', 'Arbeitslos oder arbeitsuchend melden', 'Bei Kündigung oder Ende des Arbeitsvertrags',
      frist: 'Arbeitsuchend melden: spätestens 3 Monate vor dem Ende des Jobs, bei kurzfristiger Kündigung innerhalb von 3 Tagen nach Kenntnis. '
          'Arbeitslos melden: am ersten Tag ohne Arbeit',
      quelle: '§ 38 SGB III',
      unterlagen: [
        'Personalausweis oder Reisepass',
        'Kündigung bzw. Aufhebungsvertrag und Arbeitsvertrag',
        'Arbeitsbescheinigung vom Arbeitgeber (bekommst du am Ende des Jobs)',
        'Lebenslauf und Zeugnisse',
        'Bankverbindung und Steuer-Identifikationsnummer',
        'Nachweis der Krankenversicherung',
      ],
      schritte: [
        'Sofort online oder telefonisch bei der Agentur für Arbeit arbeitsuchend melden',
        'Persönlichen Termin vereinbaren',
        'Arbeitslosengeld beantragen (online mit eServices oder per Formular)',
        'Eigene Bewerbungen sammeln und nachweisen',
        'Krankenkasse über die Änderung informieren',
        'Fristen für Anträge im Papiertiger eintragen und Bescheide scannen',
      ]),
  BehoerdenCheckliste('geburt', 'Geburt des Kindes anmelden', 'Standesamt, Krankenkasse, Kindergeld und Elterngeld',
      frist: 'Die Geburt wird innerhalb einer Woche dem Standesamt angezeigt (meist übernimmt das die Klinik)',
      quelle: '§ 18 Personenstandsgesetz',
      unterlagen: [
        'Geburtsbescheinigung der Klinik bzw. der Hebamme',
        'Personalausweise der Eltern',
        'Heiratsurkunde bzw. Vaterschaftsanerkennung, wenn die Eltern nicht verheiratet sind',
        'Krankenversicherungsnachweise der Eltern',
      ],
      schritte: [
        'Geburtsurkunde beim Standesamt beantragen (mehrere Exemplare für Kindergeld, Elterngeld, Krankenkasse)',
        'Kind bei der Krankenkasse anmelden',
        'Kindergeld bei der Familienkasse beantragen',
        'Elterngeld beantragen (rückwirkend gibt es höchstens 3 Monate)',
        'Elternzeit schriftlich beim Arbeitgeber anmelden (7 Wochen vor Beginn)',
        'Kind im Papiertiger anlegen und Geburtsurkunde hochladen',
      ]),
  BehoerdenCheckliste('heirat', 'Heiraten', 'Anmeldung beim Standesamt und danach alles ändern',
      frist: '',
      unterlagen: [
        'Personalausweise oder Reisepässe beider Partner',
        'Beglaubigte Abschrift aus dem Geburtenregister (Geburtsurkunde)',
        'Aktuelle Meldebescheinigung',
        'Bei früherer Ehe: Nachweis über die Auflösung',
      ],
      schritte: [
        'Termin beim Standesamt zur Anmeldung der Eheschließung (gilt meist 6 Monate)',
        'Namensführung festlegen',
        'Steuerklasse beim Finanzamt ändern lassen',
        'Neue Namen bei Arbeitgeber, Krankenkasse, Bank, Versicherungen und Ausweisstelle mitteilen',
        'Verträge und Vollmachten überprüfen (Testament, Vorsorgevollmacht)',
      ]),
];

/// Direkt zur Online-Stelle (Beschriftung, Adresse), je Checkliste.
const behoerdenLinks = <String, List<(String, String)>>{
  'ummelden': [('Online-Dienste und Behördenfinder', 'https://service.bund.de'), ('Verwaltungsportal des Bundes', 'https://verwaltung.bund.de')],
  'abmelden': [('Online-Dienste und Behördenfinder', 'https://service.bund.de')],
  'gewerbe': [
    ('Online-Dienste und Behördenfinder', 'https://service.bund.de'),
    ('Fragebogen zur steuerlichen Erfassung (ELSTER)', 'https://www.elster.de'),
    ('Industrie- und Handelskammer', 'https://www.ihk.de'),
  ],
  'aufenthalt': [('Informationen des Bundesamts für Migration', 'https://www.bamf.de'), ('Behördenfinder', 'https://service.bund.de')],
  'ausweis': [('Personalausweisportal des Bundes', 'https://www.personalausweisportal.de'), ('Behördenfinder', 'https://service.bund.de')],
  'auto': [('Fahrzeug online zulassen (i-Kfz)', 'https://www.i-kfz.de')],
  'arbeitslos': [('Agentur für Arbeit: Arbeitslosengeld', 'https://www.arbeitsagentur.de/arbeitslos-arbeit-finden/arbeitslosengeld')],
  'geburt': [('Familienportal des Bundes', 'https://www.familienportal.de'), ('Behördenfinder: Standesamt', 'https://service.bund.de')],
  'heirat': [('Behördenfinder: Standesamt', 'https://service.bund.de'), ('Steuer: ELSTER', 'https://www.elster.de')],
};

/// Kurz erklärt: Warum musst du das tun, und was passiert, wenn nicht?
const behoerdenWarum = <String, String>{
  'ummelden': 'Wer umzieht, muss sich anmelden. Ohne Anmeldung kann ein Bußgeld drohen, und viele Behörden schicken Post an die alte Adresse.',
  'gewerbe': 'Wer dauerhaft Gewinn erzielen will, braucht in der Regel ein Gewerbe. Ohne Anmeldung drohen Bußgelder, und das Finanzamt erfährt es meist trotzdem.',
  'aufenthalt': 'Läuft dein Aufenthaltstitel ab, ohne dass du einen Antrag gestellt hast, kann dein Aufenthalt unerlaubt werden. Stell den Antrag deshalb rechtzeitig.',
  'arbeitslos': 'Wer sich zu spät arbeitsuchend meldet, kann eine Sperrzeit beim Arbeitslosengeld bekommen. Melde dich deshalb sofort.',
  'geburt': 'Die Geburt eines Kindes muss beim Standesamt angezeigt werden. Mit der Geburtsurkunde beantragst du danach Kindergeld, Elterngeld und die Krankenversicherung.',
  'heirat': 'Nach der Hochzeit ändern sich Name, Steuerklasse und Versicherungen. Plane die Meldungen gleich mit ein.',
};

const behoerdenHinweis =
    'Allgemeine Information, keine Rechtsberatung. Unterlagen und Gebühren unterscheiden sich je nach Stadt – '
    'bitte vorher auf der Website deiner Behörde prüfen.';
