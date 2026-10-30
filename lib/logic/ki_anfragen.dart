/// Anfragen an die KI für Antworten, Vergleiche und Vorgangs-Zusammenfassungen.
library;

import '../data/models.dart';
import 'kommunikation.dart';
import 'ordnung.dart';

String _kuerzen(String t, int max) {
  final s = t.trim();
  return s.length <= max ? s : '${s.substring(0, max)} …';
}

String _datum(DateTime? d) => d == null
    ? 'unbekannt'
    : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

const antwortZiele = [
  'Rückfrage stellen',
  'Um Fristverlängerung bitten',
  'Unterlagen nachreichen',
  'Ratenzahlung anbieten',
  'Widerspruch oder Einspruch einlegen',
  'Beschwerde oder Reklamation',
  'Kündigen',
  'Rückerstattung anfordern',
  'Eigene Nachricht',
];

const antwortToene = ['höflich', 'sachlich', 'bestimmt'];

String antwortAnfrage(Brief b, Profil p,
    {required String ziel, required String ton, String inhalt = '', String sprache = 'Deutsch'}) {
  final absender = p.name.isEmpty ? '[Dein Name]' : p.name;
  final adresse = p.adresse.isEmpty ? '[Deine Adresse]' : p.adresse;
  final an = kontaktVon(b, p).adresse?.replaceAll('\n', ', ') ?? b.absenderName ?? 'der Absender des Schreibens';
  return '''
Schreibe einen fertigen Brief als Antwort auf das Schreiben unten.

Ziel des Briefs: $ziel
Ton: $ton
Sprache des Briefs: $sprache
${inhalt.trim().isEmpty ? '' : 'Das möchte der Absender sagen: ${inhalt.trim()}\n'}
Absender des Briefs: $absender, $adresse
Empfänger: $an
${b.aktenzeichen != null ? 'Bezug: ${b.aktenzeichen}\n' : ''}Datum des Schreibens: ${_datum(b.briefDatum)}

Regeln:
- Aufbau, jeder Teil durch eine Leerzeile getrennt: Absender (Name und Adresse), Empfänger (Name und Adresse), Ort und Datum, eine Zeile „Betreff: …“, Anrede, Text, Grußformel und Name.
- Kurz, klar und korrekt. Erfinde keine Fakten. Wo Angaben fehlen, setze [eckige Klammern].
- Keine Erklärung vor oder nach dem Brief, nur der Brief selbst.

Schreiben, auf das geantwortet wird:
"""
${_kuerzen(b.text, 5000)}
"""
''';
}

/// Aus einem Diktat (gesprochen, ungeordnet) einen fertigen Brief oder eine E-Mail machen.
String diktatAnfrage(String diktat, Profil p, {String art = 'Brief', String ton = 'sachlich und freundlich'}) {
  final absender = p.name.isEmpty ? '[Dein Name]' : p.name;
  final adresse = p.adresse.isEmpty ? '[Deine Adresse]' : p.adresse;
  final brief = art == 'Brief';
  return '''
Mach aus dem gesprochenen Text unten ${brief ? 'einen fertigen Brief' : 'eine fertige E-Mail'} auf Deutsch.
Der Text wurde diktiert: Er kann Füllwörter, Wiederholungen und Erkennungsfehler enthalten. Übernimm nur, was gemeint ist.

Ton: $ton
Absender: $absender, $adresse

Regeln:
${brief ? '- Aufbau, jeder Teil durch eine Leerzeile getrennt: Absender (Name und Adresse), Empfänger (Name und Adresse), Ort und Datum, eine Zeile „Betreff: …“, Anrede, Text, Grußformel und Name.' : '- Aufbau: eine Zeile „Betreff: …“, Anrede, Text, Grußformel und Name.'}
- Erfinde keine Fakten, Beträge oder Daten. Wo Angaben fehlen (z. B. Empfänger, Aktenzeichen), setze [eckige Klammern].
- Keine Erklärung vor oder nach dem Text.

Diktat:
"""
${_kuerzen(diktat, 5000)}
"""
''';
}

String vergleichAnfrage(Brief alt, Brief neu) => '''
Vergleiche die beiden Dokumente unten und erkläre die Unterschiede in einfachen, kurzen Sätzen auf Deutsch. Sprich den Leser mit „du“ an.

Antworte in diesem Format:
WICHTIGSTE ÄNDERUNG: <ein Satz>
UNTERSCHIEDE:
- <jeder Unterschied mit altem und neuem Wert, z. B. Beträge, Daten, Bedingungen>
WAS HEISST DAS FÜR DICH:
- <2 bis 3 Punkte>

Übernimm Zahlen und Daten genau. Erfinde nichts.

Dokument A (älter, vom ${_datum(alt.briefDatum ?? alt.erstellt)}, „${titelVon(alt)}“):
"""
${_kuerzen(alt.text, 2800)}
"""

Dokument B (neuer, vom ${_datum(neu.briefDatum ?? neu.erstellt)}, „${titelVon(neu)}“):
"""
${_kuerzen(neu.text, 2800)}
"""
''';

String akteAnfrage(Akte a) {
  final teile = StringBuffer();
  for (final b in a.briefe.take(8).toList().reversed) {
    teile.writeln('- ${_datum(b.briefDatum ?? b.erstellt)}, ${titelVon(b)}: ${_kuerzen(b.erklaerung, 500)}'
        '${b.erledigt ? ' (erledigt)' : ''}');
  }
  return '''
Hier sind alle Schreiben eines Vorgangs (${a.titel}), älteste zuerst, jeweils kurz zusammengefasst:

$teile
Fasse den ganzen Vorgang in einfachen, kurzen Sätzen auf Deutsch zusammen. Sprich den Leser mit „du“ an.

Antworte in diesem Format:
WORUM ES GEHT: <2 bis 3 Sätze>
VERLAUF:
- <wichtige Schritte in zeitlicher Reihenfolge>
STAND HEUTE: <ein bis zwei Sätze>
NOCH OFFEN:
- <was noch zu tun ist, oder - Nichts>

Erfinde nichts, nutze nur die Angaben oben.
''';
}

/// Übersetzt einen Brief, damit man ihn in der eigenen Sprache versteht.
String uebersetzungAnfrage(Brief b, String sprache) => '''
Übersetze das Schreiben unten vollständig und genau ins $sprache.
Behalte Zahlen, Beträge, Daten, Namen und Aktenzeichen unverändert bei.
Fasse nichts zusammen und lass nichts weg. Nur die Übersetzung, keine Erklärung.

Schreiben:
"""
${_kuerzen(b.text, 5000)}
"""
''';

/// Brief in einfachen Worten in der Sprache des Nutzers erklären (Antworten schreibt der Tiger weiter auf Deutsch).
String erklaerungAnfrage(Brief b, String sprache) => '''
Erkläre das deutsche Schreiben unten in einfachen Worten auf $sprache. Antworte NUR auf $sprache, im Format:
1. Wer schreibt und worum geht es? (2 Sätze)
2. Was muss ich tun? (Stichpunkte)
3. Bis wann? Wie viel Geld? (falls im Schreiben genannt)
4. Was passiert, wenn ich nichts tue?
Übernimm Beträge, Daten und Aktenzeichen genau. Erfinde nichts. Fachwörter auf Deutsch in Klammern dazuschreiben.

Schreiben:
"""
${_kuerzen(b.text, 5000)}
"""
''';

/// Gezielte KI-Prüfungen je nach Art des Schreibens.
class Pruefung {
  const Pruefung(this.key, this.titel, this.beschreibung, this.auftrag);

  final String key;
  final String titel;
  final String beschreibung;
  final String auftrag;
}

const pruefungen = [
  Pruefung('versicherung', 'Versicherungsschutz erklären', 'Was ist versichert, was nicht?',
      'Erkläre, was laut diesem Schreiben versichert ist und was nicht. Antworte im Format:\n'
          'VERSICHERT:\n- <Leistungen mit Summen>\nNICHT VERSICHERT ODER EINGESCHRÄNKT:\n- <Ausschlüsse, Selbstbeteiligung, Wartezeiten>\n'
          'WORAUF ACHTEN:\n- <Pflichten, Fristen bei Schäden>\nWenn etwas im Text nicht steht, schreibe „steht nicht im Schreiben“.'),
  Pruefung('nebenkosten', 'Nebenkostenabrechnung prüfen', 'Auffälligkeiten finden',
      'Prüfe diese Nebenkosten- oder Betriebskostenabrechnung auf Auffälligkeiten. Antworte im Format:\n'
          'ERGEBNIS: <Nachzahlung oder Guthaben mit Betrag>\nAUFFÄLLIG:\n- <z. B. Abrechnungszeitraum über 12 Monate, Abrechnung später als 12 Monate nach Ende des Zeitraums, '
          'Kosten wie Verwaltung oder Reparaturen, die meist nicht umlagefähig sind, stark gestiegene Posten, fehlender Verteilerschlüssel>\n'
          'NACHFRAGEN:\n- <was du beim Vermieter erfragen oder per Belegeinsicht prüfen kannst>\n'
          'Nenne nur, was im Text belegt ist. Keine Rechtsberatung.'),
  Pruefung('bescheid', 'Bescheid nachrechnen', 'Rechnung plausibel?',
      'Prüfe die Berechnung in diesem Bescheid auf Plausibilität. Rechne Summen und Differenzen nach, die im Text stehen. Antworte im Format:\n'
          'ERGEBNIS: <Betrag laut Bescheid>\nNACHGERECHNET:\n- <jede geprüfte Rechnung mit Zahlen, „stimmt“ oder „weicht ab um …“>\n'
          'BITTE PRÜFEN:\n- <Angaben, die du mit deinen Unterlagen vergleichen solltest, z. B. Einkommen, Zeiträume, Personenzahl>\n'
          'Das ist eine Plausibilitätsprüfung, keine verbindliche Berechnung.'),
  Pruefung('mahnung', 'Mahnung und Gebühren prüfen', 'Sind die Kosten üblich?',
      'Erkläre die Forderung in dieser Mahnung. Antworte im Format:\n'
          'HAUPTFORDERUNG: <Betrag und wofür>\nGEBÜHREN UND ZINSEN:\n- <jeder Posten mit Betrag>\nAUFFÄLLIG:\n- <z. B. sehr hohe Mahn- oder Inkassogebühren, unklarer Ursprung, fehlende Rechnungsnummer>\n'
          'WAS DU TUN KANNST:\n- <bezahlen, nachfragen, bestreiten, Beratung>\nKeine Rechtsberatung.'),
  Pruefung('vertrag', 'Vertrag verständlich zusammenfassen', 'Kosten, Laufzeit, Haken',
      'Fasse diesen Vertrag verständlich zusammen. Antworte im Format:\nKOSTEN:\n- <alle Kosten>\nLAUFZEIT UND KÜNDIGUNG:\n- <Mindestlaufzeit, Frist, Verlängerung>\n'
          'WICHTIGE BEDINGUNGEN:\n- <Pflichten, Preisanpassungen, Sonderregeln>\nWORAUF ACHTEN:\n- <mögliche Haken>'),
  Pruefung('termin', 'Termin bei der Behörde vorbereiten', 'Was mitnehmen, was fragen?',
      'Hilf bei der Vorbereitung auf den Termin, um den es in diesem Schreiben geht. Antworte im Format:\n'
          'TERMIN: <wann, wo, bei wem – nur wenn im Text>\nMITBRINGEN:\n- <Dokumente und Nachweise>\nFRAGEN, DIE DU STELLEN KANNST:\n- <3 bis 5 Fragen>\n'
          'WENN DU NICHT KOMMEN KANNST:\n- <was das Schreiben dazu sagt, sonst: rechtzeitig absagen und neuen Termin erbitten>'),
];

/// Welche Prüfungen zu einem Brief passen (die passendste zuerst).
List<Pruefung> pruefungenFuer(Brief b) {
  final t = b.text.toLowerCase();
  final keys = <String>[
    if (b.kategorie == 'versicherung' || t.contains('versicherungsschein') || t.contains('versicherungsbedingungen')) 'versicherung',
    if (t.contains('nebenkosten') || t.contains('betriebskosten')) 'nebenkosten',
    if (b.typ == 'bescheid' || b.typ.startsWith('renten') || t.contains('bescheid')) 'bescheid',
    if (b.typ == 'mahnung' || b.kategorie == 'inkasso' || t.contains('mahngebühr')) 'mahnung',
    if (t.contains('vertragsbedingungen') || t.contains('mindestlaufzeit') || t.contains('vertragsbestätigung')) 'vertrag',
    if (t.contains('termin') && (t.contains('vorsprache') || t.contains('einladung') || t.contains('eingeladen') || t.contains('erscheinen'))) 'termin',
  ];
  return [for (final k in keys) pruefungen.firstWhere((p) => p.key == k)];
}

String pruefAnfrage(Pruefung p, Brief b) => '''
${p.auftrag}

Schreibe einfach und kurz auf Deutsch, sprich den Leser mit „du“ an. Übernimm Zahlen und Daten genau, erfinde nichts.

Schreiben:
"""
${_kuerzen(b.text, 5000)}
"""
''';
