/// Einfache Sprachbefehle für die Startseite, z. B. „Was muss ich diese Woche bezahlen?“
/// oder „Milch auf die Einkaufsliste“. Ohne KI, nur nach Schlüsselwörtern.
library;

enum BefehlArt { einkauf, zahlungen, fristen, termine, suche, scannen, unbekannt }

class Befehl {
  const Befehl(this.art, [this.rest = '']);
  final BefehlArt art;

  /// Bei Einkauf: die Artikel. Bei Suche: der Suchbegriff.
  final String rest;
}

Befehl befehlVerstehen(String gesprochen) {
  final t = gesprochen.toLowerCase().trim();
  final einkauf = RegExp(r'^(?:schreib(?:e)?\s+|setz(?:e)?\s+|pack(?:e)?\s+)?(.+?)\s+(?:auf|zur|in)\s+(?:die\s+|meine\s+)?einkaufsliste$')
      .firstMatch(t);
  if (einkauf != null) return Befehl(BefehlArt.einkauf, einkauf.group(1)!.replaceAll(RegExp(r'\s+und\s+'), ', '));
  if (RegExp(r'scann|fotografier|neuer brief|brief aufnehmen').hasMatch(t)) return const Befehl(BefehlArt.scannen);
  if (RegExp(r'bezahl|zahlung|überweis|rechnung|schulde').hasMatch(t)) return const Befehl(BefehlArt.zahlungen);
  if (RegExp(r'termin|kalender|verabredung').hasMatch(t)) return const Befehl(BefehlArt.termine);
  if (RegExp(r'frist|fällig|erledigen|zu tun|was steht an|diese woche').hasMatch(t)) return const Befehl(BefehlArt.fristen);
  final suche = RegExp(r'^(?:such(?:e)?|zeig(?:e)?(?:\s+mir)?|finde?|wo ist)\s+(?:den\s+|die\s+|das\s+|nach\s+|meinen?\s+|meine\s+)?(.+)$').firstMatch(t);
  if (suche != null) return Befehl(BefehlArt.suche, suche.group(1)!.replaceAll(RegExp(r'[?.!]$'), '').trim());
  return Befehl(BefehlArt.unbekannt, t);
}
