/// Lebenslagen: Die App zeigt nur, was zur eigenen Situation passt. Ohne Auswahl ist alles sichtbar.
library;

class Lebenslage {
  const Lebenslage(this.key, this.titel, this.text);

  final String key;
  final String titel;
  final String text;
}

const lebenslagen = [
  Lebenslage('familie', 'Familie & Haushalt', 'Einkauf, Kinder, Kindergeld, Haushaltsbuch'),
  Lebenslage('senior', 'Rente & Ruhestand', 'Große Schrift, Rente, Vorsorgemappe'),
  Lebenslage('ausbildung', 'Studium & Ausbildung', 'BAföG, erste Wohnung, Bewerbung'),
  Lebenslage('angestellt', 'Angestellt', 'Lohnabrechnung, Steuer, Karriere'),
  Lebenslage('jobsuche', 'Auf Jobsuche', 'Bewerbungen, Jobcenter, Weiterbildung'),
  Lebenslage('selbststaendig', 'Selbstständig / Freiberuf', 'Angebote, Rechnungen, Kunden, Buchhaltung'),
  Lebenslage('handwerk', 'Handwerksbetrieb', 'Aufmaß, Baustelle, Team, Plantafel'),
  Lebenslage('vermieter', 'Vermieter', 'Mieter, Mieteingänge, Nebenkosten'),
];

/// Für welche Lebenslagen ein Modul gedacht ist (leer = für alle).
const _modulLagen = <String, Set<String>>{
  'karriere': {'angestellt', 'jobsuche', 'ausbildung'},
  'gewerbe': {'selbststaendig', 'handwerk'},
  'haushalt': {'familie', 'senior', 'vermieter'},
  'vermietung': {'vermieter'},
  'vorsorge': {'senior', 'familie'},
  'kinder': {'familie'},
};

/// Ist ein Modul bei den gewählten Lebenslagen sichtbar? Ohne Auswahl ist alles sichtbar.
bool modulSichtbar(String modul, Set<String> lagen) {
  final fuer = _modulLagen[modul];
  if (fuer == null || lagen.isEmpty) return true;
  return fuer.intersection(lagen).isNotEmpty;
}

/// Handwerks-Funktionen (Aufmaß, Baustelle, Plantafel, Stempeluhr) zeigen? Nicht für reine Freiberufler.
bool handwerkSichtbar(Set<String> lagen) => !(lagen.contains('selbststaendig') && !lagen.contains('handwerk'));

/// Große Schrift vorschlagen, wenn „Rente & Ruhestand“ gewählt ist.
bool grossschriftVorschlagen(Set<String> lagen) => lagen.contains('senior');
