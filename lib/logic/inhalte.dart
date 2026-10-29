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
  const Leistung(this.titel, this.text, this.stelle, this.bedingung);

  final String titel;
  final String text;
  final String stelle;
  final bool Function(Map<String, bool> a) bedingung;
}

bool _ja(Map<String, bool> a, String k) => a[k] == true;

final leistungen = <Leistung>[
  Leistung('Kindergeld', 'Monatliche Zahlung für Kinder, meist bis 18, in Ausbildung bis 25.',
      'Familienkasse (arbeitsagentur.de)', (a) => _ja(a, 'kinder') || _ja(a, 'baby')),
  Leistung('Kinderzuschlag', 'Zusätzliches Geld für Familien mit kleinem Einkommen.',
      'Familienkasse (arbeitsagentur.de)',
      (a) => (_ja(a, 'kinder') || _ja(a, 'baby')) && _ja(a, 'miete')),
  Leistung('Elterngeld', 'Ersatz für fehlendes Einkommen in den ersten Lebensmonaten des Kindes.',
      'Elterngeldstelle deiner Stadt oder deines Kreises', (a) => _ja(a, 'baby')),
  Leistung('Unterhaltsvorschuss', 'Wenn der andere Elternteil keinen oder zu wenig Unterhalt zahlt.',
      'Jugendamt deiner Stadt', (a) => _ja(a, 'allein') && _ja(a, 'kinder')),
  Leistung('Entlastungsbetrag für Alleinerziehende', 'Steuerlicher Freibetrag, der dein Netto erhöht.',
      'Finanzamt (Steuerklasse II)', (a) => _ja(a, 'allein')),
  Leistung('Wohngeld', 'Zuschuss zur Miete oder zu den Wohnkosten bei kleinem Einkommen.',
      'Wohngeldstelle deiner Stadt oder Gemeinde', (a) => _ja(a, 'miete')),
  Leistung('Bürgergeld', 'Sicherung des Lebensunterhalts für erwerbsfähige Menschen ohne ausreichendes Einkommen.',
      'Jobcenter', (a) => _ja(a, 'arbeitslos') && _ja(a, 'miete')),
  Leistung('Arbeitslosengeld', 'Wenn du vorher versicherungspflichtig gearbeitet hast.',
      'Agentur für Arbeit', (a) => _ja(a, 'arbeitslos')),
  Leistung('BAföG', 'Förderung für Studium und schulische Ausbildung.',
      'Amt für Ausbildungsförderung (bafög.de)', (a) => _ja(a, 'ausbildung')),
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
      (a) => (_ja(a, 'arbeitslos') && _ja(a, 'miete')) || _ja(a, 'ausbildung') || (_ja(a, 'rente') && _ja(a, 'miete'))),
  Leistung('Bildung und Teilhabe', 'Zuschüsse für Schulsachen, Ausflüge, Mittagessen und Vereine für Kinder.',
      'Jobcenter, Sozialamt oder Wohngeldstelle',
      (a) => _ja(a, 'kinder') && _ja(a, 'miete')),
  Leistung('Steuererklärung', 'Viele Angestellte bekommen mit einer Steuererklärung Geld zurück.',
      'Finanzamt (z. B. über ELSTER)', (a) => _ja(a, 'arbeitnehmer') || _ja(a, 'ausbildung')),
];

class AntragsHelfer {
  const AntragsHelfer(this.key, this.titel, this.untertitel, this.stelle, this.wo,
      this.fragen, this.unterlagen);

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
  ),
  AntragsHelfer(
    'wohngeld',
    'Wohngeld',
    'Antrag bei der Wohngeldstelle',
    'Wohngeldstelle deiner Stadt oder Gemeinde',
    'Bei deiner Wohngeldstelle, in vielen Bundesländern auch online über das Serviceportal deines Landes.',
    [
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
  ),
];
