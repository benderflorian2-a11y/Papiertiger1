/// Anfragen an die KI für Antworten, Vergleiche und Vorgangs-Zusammenfassungen.
library;

import '../data/models.dart';
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
  return '''
Schreibe einen fertigen Brief als Antwort auf das Schreiben unten.

Ziel des Briefs: $ziel
Ton: $ton
Sprache des Briefs: $sprache
${inhalt.trim().isEmpty ? '' : 'Das möchte der Absender sagen: ${inhalt.trim()}\n'}
Absender des Briefs: $absender, $adresse
Empfänger: ${b.absenderName ?? 'der Absender des Schreibens'}
${b.aktenzeichen != null ? 'Bezug: ${b.aktenzeichen}\n' : ''}Datum des Schreibens: ${_datum(b.briefDatum)}

Regeln:
- Beginne mit Absender, Empfänger, Datum, Betreff und Anrede, ende mit Grußformel und Name.
- Kurz, klar und korrekt. Erfinde keine Fakten. Wo Angaben fehlen, setze [eckige Klammern].
- Keine Erklärung vor oder nach dem Brief, nur der Brief selbst.

Schreiben, auf das geantwortet wird:
"""
${_kuerzen(b.text, 5000)}
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
