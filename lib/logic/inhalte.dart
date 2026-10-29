/// Feste Inhalte: Checklisten, Leistungen, Antrags-Helfer.
/// Allgemeine Informationen ohne Gewähr, keine Rechts- oder Sozialberatung.
library;

class Ereignis {
  const Ereignis(this.key, this.titel, this.untertitel, this.punkte);

  final String key;
  final String titel;
  final String untertitel;
  final List<String> punkte;
}

const lebensEreignisse = [
  Ereignis('umzug', 'Umzug', 'Alles für den Wohnungswechsel', [
    'Alten Mietvertrag fristgerecht kündigen',
    'Umzugstermin und Helfer oder Umzugsfirma festlegen',
    'Nachsendeauftrag bei der Post einrichten',
    'Innerhalb von 2 Wochen beim Bürgeramt ummelden',
    'Wohnungsgeberbestätigung vom neuen Vermieter holen',
    'Strom, Gas und Internet ummelden oder neu abschließen',
    'Neue Adresse an Bank, Arbeitgeber und Krankenkasse melden',
    'Neue Adresse an Versicherungen und Rundfunkbeitrag melden',
    'Fahrzeug ummelden (falls vorhanden)',
    'Übergabeprotokoll für alte und neue Wohnung machen',
  ]),
  Ereignis('job', 'Jobwechsel', 'Neuer Job, neue Unterlagen', [
    'Alten Arbeitsvertrag fristgerecht kündigen',
    'Arbeitszeugnis beim alten Arbeitgeber anfordern',
    'Resturlaub klären',
    'Steuer-ID und Sozialversicherungsnummer an den neuen Arbeitgeber geben',
    'Krankenkasse beim neuen Arbeitgeber angeben',
    'Bankverbindung für das Gehalt angeben',
    'Betriebliche Altersvorsorge prüfen',
    'Bei Lücke zwischen den Jobs: rechtzeitig bei der Agentur für Arbeit melden',
  ]),
  Ereignis('hochzeit', 'Hochzeit', 'Vom Standesamt bis zur Steuerklasse', [
    'Termin beim Standesamt anmelden',
    'Unterlagen fürs Standesamt besorgen (z. B. Geburtsurkunde)',
    'Neuen Namen beim Bürgeramt eintragen lassen (Ausweis)',
    'Namensänderung an Bank, Arbeitgeber und Krankenkasse melden',
    'Steuerklassen prüfen',
    'Versicherungen zusammenlegen oder anpassen',
    'Begünstigte in Versicherungen aktualisieren',
  ]),
  Ereignis('baby', 'Baby', 'Die wichtigsten Anträge rund ums Kind', [
    'Geburtsurkunde beim Standesamt beantragen',
    'Kind bei der Krankenkasse anmelden',
    'Kindergeld bei der Familienkasse beantragen',
    'Elterngeld bei der Elterngeldstelle beantragen',
    'Elternzeit beim Arbeitgeber anmelden (spätestens 7 Wochen vorher)',
    'Kinderzuschlag prüfen',
    'Kita-Platz suchen und anmelden',
    'Steuer-ID des Kindes aufbewahren (kommt per Post)',
  ]),
];

class Frage {
  const Frage(this.key, this.text);

  final String key;
  final String text;
}

const leistungsFragen = [
  Frage('kinder', 'Lebt bei dir ein Kind unter 25 Jahren?'),
  Frage('baby', 'Erwartest du ein Baby oder ist dein Kind jünger als 14 Monate?'),
  Frage('allein', 'Bist du alleinerziehend?'),
  Frage('miete', 'Ist dein Einkommen knapp, sodass Miete oder Lebenshaltung schwer zu bezahlen sind?'),
  Frage('arbeitslos', 'Bist du gerade ohne Arbeit?'),
  Frage('ausbildung', 'Bist du in Ausbildung oder im Studium?'),
  Frage('rente', 'Bist du in Rente oder im Rentenalter?'),
  Frage('pflege', 'Pflegst du einen Angehörigen oder bist du selbst pflegebedürftig?'),
  Frage('behinderung', 'Hast du eine Behinderung oder eine chronische Erkrankung?'),
  Frage('arbeitnehmer', 'Bist du angestellt?'),
];

class Leistung {
  const Leistung(this.titel, this.text, this.stelle, this.bedingung, {this.link, this.antrag});

  final String titel;
  final String text;
  final String stelle;
  final bool Function(Map<String, bool> a) bedingung;

  /// Offizielle Info-Seite.
  final String? link;

  /// Schlüssel eines Antrags-Helfers in [antraege].
  final String? antrag;
}

const _aa = 'https://www.arbeitsagentur.de';
const _fp = 'https://familienportal.de';

bool _ja(Map<String, bool> a, String k) => a[k] == true;

final leistungen = <Leistung>[
  Leistung('Kindergeld', 'Monatliche Zahlung für Kinder, meist bis 18, in Ausbildung bis 25.',
      'Familienkasse (arbeitsagentur.de)', (a) => _ja(a, 'kinder') || _ja(a, 'baby'),
      link: '$_aa/familie-und-kinder/kindergeld', antrag: 'kindergeld'),
  Leistung('Kinderzuschlag', 'Zusätzliches Geld für Familien mit kleinem Einkommen.',
      'Familienkasse (arbeitsagentur.de)',
      (a) => (_ja(a, 'kinder') || _ja(a, 'baby')) && _ja(a, 'miete'),
      link: '$_aa/familie-und-kinder/kinderzuschlag', antrag: 'kinderzuschlag'),
  Leistung('Elterngeld', 'Ersatz für fehlendes Einkommen in den ersten Lebensmonaten des Kindes.',
      'Elterngeldstelle deiner Stadt oder deines Kreises', (a) => _ja(a, 'baby'),
      link: _fp, antrag: 'elterngeld'),
  Leistung('Unterhaltsvorschuss', 'Wenn der andere Elternteil keinen oder zu wenig Unterhalt zahlt.',
      'Jugendamt deiner Stadt', (a) => _ja(a, 'allein') && _ja(a, 'kinder'), link: _fp),
  Leistung('Entlastungsbetrag für Alleinerziehende', 'Steuerlicher Freibetrag, der dein Netto erhöht.',
      'Finanzamt (Steuerklasse II)', (a) => _ja(a, 'allein')),
  Leistung('Wohngeld', 'Zuschuss zur Miete oder zu den Wohnkosten bei kleinem Einkommen.',
      'Wohngeldstelle deiner Stadt oder Gemeinde', (a) => _ja(a, 'miete'), antrag: 'wohngeld'),
  Leistung('Bürgergeld', 'Sicherung des Lebensunterhalts für erwerbsfähige Menschen ohne ausreichendes Einkommen.',
      'Jobcenter', (a) => _ja(a, 'arbeitslos') && _ja(a, 'miete'),
      link: '$_aa/arbeitslos-arbeit-finden/buergergeld', antrag: 'buergergeld'),
  Leistung('Arbeitslosengeld', 'Wenn du vorher versicherungspflichtig gearbeitet hast.',
      'Agentur für Arbeit', (a) => _ja(a, 'arbeitslos'), link: '$_aa/arbeitslos-arbeit-finden/arbeitslosengeld'),
  Leistung('BAföG', 'Förderung für Studium und schulische Ausbildung.',
      'Amt für Ausbildungsförderung (bafög.de)', (a) => _ja(a, 'ausbildung'),
      link: 'https://www.xn--bafg-7qa.de', antrag: 'bafoeg'),
  Leistung('Berufsausbildungsbeihilfe', 'Zuschuss während einer betrieblichen Ausbildung.',
      'Agentur für Arbeit', (a) => _ja(a, 'ausbildung') && _ja(a, 'miete')),
  Leistung('Grundsicherung im Alter', 'Wenn die Rente nicht zum Leben reicht.',
      'Sozialamt deiner Stadt', (a) => _ja(a, 'rente') && _ja(a, 'miete')),
  Leistung('Pflegegeld und Pflegeleistungen', 'Unterstützung bei Pflege zu Hause, je nach Pflegegrad.',
      'Pflegekasse (bei der Krankenkasse)', (a) => _ja(a, 'pflege')),
  Leistung('Schwerbehindertenausweis', 'Kann Nachteilsausgleiche wie Steuerfreibeträge oder Zusatzurlaub bringen.',
      'Versorgungsamt deines Landes', (a) => _ja(a, 'behinderung')),
  Leistung('Befreiung vom Rundfunkbeitrag', 'Bei Bürgergeld, Grundsicherung, BAföG und weiteren Leistungen möglich.',
      'ARD ZDF Deutschlandradio Beitragsservice',
      (a) => (_ja(a, 'arbeitslos') && _ja(a, 'miete')) || _ja(a, 'ausbildung') || (_ja(a, 'rente') && _ja(a, 'miete')),
      link: 'https://www.rundfunkbeitrag.de', antrag: 'rundfunk'),
  Leistung('Bildung und Teilhabe', 'Zuschüsse für Schulsachen, Ausflüge, Mittagessen und Vereine für Kinder.',
      'Jobcenter, Sozialamt oder Wohngeldstelle',
      (a) => _ja(a, 'kinder') && _ja(a, 'miete')),
  Leistung('Steuererklärung', 'Viele Angestellte bekommen mit einer Steuererklärung Geld zurück.',
      'Finanzamt (z. B. über ELSTER)', (a) => _ja(a, 'arbeitnehmer') || _ja(a, 'ausbildung'),
      link: 'https://www.elster.de'),
];

class AntragsHelfer {
  const AntragsHelfer(this.key, this.titel, this.untertitel, this.stelle, this.wo,
      this.fragen, this.unterlagen, {this.link, this.nachfragenWochen = 6});

  /// Offizielle Info- oder Antragsseite.
  final String? link;

  /// Nach so vielen Wochen ohne Bescheid erinnert der Tiger ans Nachfragen.
  final int nachfragenWochen;

  final String key;
  final String titel;
  final String untertitel;
  final String stelle;
  final String wo;
  final List<String> fragen;
  final List<String> unterlagen;
}

const antraege = [
  AntragsHelfer(
    'kindergeld',
    'Kindergeld',
    'Antrag bei der Familienkasse',
    'Familienkasse der Bundesagentur für Arbeit',
    'Online auf arbeitsagentur.de unter „Kindergeld beantragen“ oder mit dem Papierformular KG 1.',
    [
      'Dein Name',
      'Deine Anschrift',
      'Deine Steuer-ID',
      'Deine IBAN',
      'Vor- und Nachname des Kindes',
      'Geburtsdatum des Kindes',
      'Dein Familienstand',
      'Lebt das Kind in deinem Haushalt? Seit wann?',
      'Ist das Kind über 18? Wenn ja: Schule, Ausbildung oder Studium?',
    ],
    [
      'Deine Steuer-Identifikationsnummer',
      'Steuer-Identifikationsnummer des Kindes',
      'Geburtsurkunde des Kindes (bereithalten, falls sie verlangt wird)',
      'Bei Kindern über 18: Schul-, Ausbildungs- oder Studienbescheinigung',
      'Deine Bankverbindung (IBAN)',
    ],
    link: '$_aa/familie-und-kinder/kindergeld',
  ),
  AntragsHelfer(
    'wohngeld',
    'Wohngeld',
    'Antrag bei der Wohngeldstelle',
    'Wohngeldstelle deiner Stadt oder Gemeinde',
    'Bei deiner Wohngeldstelle, in vielen Bundesländern auch online über das Serviceportal deines Landes.',
    [
      'Dein Name',
      'Deine Anschrift',
      'Wie viele Personen leben in deinem Haushalt?',
      'Wie hoch ist deine Bruttokaltmiete pro Monat?',
      'Wie hoch sind die Einkommen aller Haushaltsmitglieder?',
      'Bekommst du schon andere Leistungen (z. B. Bürgergeld)?',
      'Seit wann wohnst du in der Wohnung?',
    ],
    [
      'Mietvertrag',
      'Mietbescheinigung vom Vermieter (Formular der Wohngeldstelle)',
      'Einkommensnachweise der letzten 12 Monate aller Haushaltsmitglieder',
      'Personalausweis',
      'Kontoauszüge (falls verlangt)',
      'Bescheide über andere Leistungen (z. B. Rente, Unterhalt, Kindergeld)',
    ],
    nachfragenWochen: 8,
  ),
  AntragsHelfer(
    'kinderzuschlag',
    'Kinderzuschlag',
    'Zusätzlich zum Kindergeld bei kleinem Einkommen',
    'Familienkasse der Bundesagentur für Arbeit',
    'Online auf arbeitsagentur.de unter „Kinderzuschlag beantragen“ oder mit dem Formular KiZ 1.',
    [
      'Dein Name',
      'Deine Anschrift',
      'Deine IBAN',
      'Kindergeldnummer',
      'Wie viele Personen leben in deinem Haushalt?',
      'Bruttoeinkommen aller Erwachsenen in den letzten 6 Monaten',
      'Miete und Heizkosten pro Monat',
    ],
    [
      'Einkommensnachweise der letzten 6 Monate',
      'Mietvertrag und Nachweis der Heizkosten',
      'Nachweise über Unterhalt oder Unterhaltsvorschuss (falls vorhanden)',
      'Kontoauszüge (falls verlangt)',
    ],
    link: '$_aa/familie-und-kinder/kinderzuschlag',
  ),
  AntragsHelfer(
    'elterngeld',
    'Elterngeld',
    'Nach der Geburt bei der Elterngeldstelle',
    'Elterngeldstelle deiner Stadt oder deines Kreises',
    'In vielen Bundesländern online über „ElterngeldDigital“, sonst mit dem Formular deines Landes.',
    [
      'Dein Name',
      'Deine Anschrift',
      'Dein Geburtsdatum',
      'Deine Steuer-ID',
      'Deine IBAN',
      'Name und Geburtsdatum des Kindes',
      'Welche Lebensmonate möchtest du Elterngeld (Basis oder Plus)?',
      'Bekommt der andere Elternteil auch Elterngeld? Für welche Monate?',
    ],
    [
      'Geburtsurkunde für Elterngeld',
      'Einkommensnachweise der 12 Monate vor der Geburt (Lohnabrechnungen oder Steuerbescheid)',
      'Bescheinigung über Mutterschaftsgeld und Arbeitgeberzuschuss',
      'Arbeitszeitbestätigung, falls du in Teilzeit arbeitest',
    ],
    link: _fp,
    nachfragenWochen: 8,
  ),
  AntragsHelfer(
    'bafoeg',
    'BAföG',
    'Förderung für Studium und Schule',
    'Amt für Ausbildungsförderung (beim Studierendenwerk oder der Stadt)',
    'Online über „BAföG Digital“ auf bafög.de.',
    [
      'Dein Name',
      'Deine Anschrift',
      'Dein Geburtsdatum',
      'Deine IBAN',
      'Hochschule oder Schule und Fach',
      'Wohnst du bei deinen Eltern?',
      'Einkommen der Eltern im vorletzten Kalenderjahr',
    ],
    [
      'Immatrikulations- oder Schulbescheinigung',
      'Einkommensnachweise der Eltern (Steuerbescheid vom vorletzten Jahr)',
      'Nachweis über eigenes Vermögen',
      'Mietvertrag, falls du nicht bei den Eltern wohnst',
      'Krankenversicherungsnachweis',
    ],
    link: 'https://www.xn--bafg-7qa.de',
    nachfragenWochen: 8,
  ),
  AntragsHelfer(
    'rundfunk',
    'Befreiung vom Rundfunkbeitrag',
    'Bei Bürgergeld, BAföG, Grundsicherung und mehr',
    'ARD ZDF Deutschlandradio Beitragsservice',
    'Online auf rundfunkbeitrag.de unter „Befreiung oder Ermäßigung beantragen“.',
    [
      'Dein Name',
      'Deine Anschrift',
      'Deine Beitragsnummer',
      'Welche Leistung bekommst du? Seit wann, bis wann?',
    ],
    [
      'Aktueller Bescheid über die Leistung (z. B. Bürgergeld, BAföG, Grundsicherung)',
    ],
    link: 'https://www.rundfunkbeitrag.de',
  ),
  AntragsHelfer(
    'buergergeld',
    'Bürgergeld',
    'Erstantrag oder Weiterbewilligung beim Jobcenter',
    'Jobcenter deiner Stadt',
    'Online über jobcenter.digital oder mit dem Papierantrag beim Jobcenter. Die Weiterbewilligung rechtzeitig vor Ende des Bewilligungszeitraums stellen.',
    [
      'Dein Name',
      'Deine Anschrift',
      'Dein Geburtsdatum',
      'Deine IBAN',
      'Wer lebt mit dir in der Bedarfsgemeinschaft?',
      'Miete, Nebenkosten und Heizkosten pro Monat',
      'Einkommen aller Personen im Haushalt',
      'Vermögen (Konten, Sparbücher, Auto)',
    ],
    [
      'Personalausweis',
      'Mietvertrag und letzte Nebenkostenabrechnung',
      'Kontoauszüge der letzten 3 Monate',
      'Einkommensnachweise (Lohnabrechnungen, Kindergeld, Unterhalt)',
      'Nachweise über Vermögen',
      'Krankenversicherungsnachweis',
    ],
    link: '$_aa/arbeitslos-arbeit-finden/buergergeld',
    nachfragenWochen: 4,
  ),
];

AntragsHelfer? antragMitKey(String key) {
  for (final a in antraege) {
    if (a.key == key) return a;
  }
  return null;
}
