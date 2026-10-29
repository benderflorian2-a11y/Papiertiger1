/// Marketing für Selbstständige: KI-Anfragen für Texte und Kunden, die man
/// wieder ansprechen könnte. Reines Dart, damit es testbar ist.
library;

import '../data/geschaeft.dart';

class MarketingArt {
  const MarketingArt(this.key, this.titel, this.beschreibung, this.auftrag);

  final String key;
  final String titel;
  final String beschreibung;

  /// Was die KI schreiben soll.
  final String auftrag;
}

const marketingArten = [
  MarketingArt('post', 'Social-Media-Post', 'Instagram, Facebook, LinkedIn',
      'Schreibe einen kurzen Social-Media-Post (höchstens 80 Wörter) mit 3 bis 5 passenden Hashtags am Ende.'),
  MarketingArt('google', 'Google-Unternehmensprofil', 'Beitrag oder Beschreibung',
      'Schreibe einen kurzen Beitrag für ein Google-Unternehmensprofil (höchstens 60 Wörter) mit klarer Handlungsaufforderung.'),
  MarketingArt('angebot', 'Leistungsbeschreibung', 'Für Website oder Angebot',
      'Schreibe eine verständliche Beschreibung der Leistung für eine Website oder ein Angebot: Nutzen für den Kunden, Ablauf, was enthalten ist. Höchstens 150 Wörter.'),
  MarketingArt('newsletter', 'Kunden-E-Mail', 'Neuigkeit oder Aktion',
      'Schreibe eine kurze, freundliche E-Mail an Bestandskunden mit Betreffzeile. Höchstens 120 Wörter. Am Ende ein Satz, dass man sich jederzeit abmelden kann.'),
  MarketingArt('bewertung', 'Bitte um Bewertung', 'Nach einem Auftrag',
      'Schreibe eine kurze, persönliche Nachricht an einen zufriedenen Kunden mit der Bitte um eine Online-Bewertung. Höchstens 60 Wörter. Kein Druck, keine Gegenleistung anbieten.'),
  MarketingArt('antwort', 'Antwort auf Bewertung', 'Lob oder Kritik',
      'Schreibe eine höfliche, sachliche öffentliche Antwort auf die Kundenbewertung unten. Bedanke dich, geh auf Kritik ein, nenne keine privaten Details. Höchstens 80 Wörter.'),
  MarketingArt('flyer', 'Flyer- oder Anzeigentext', 'Überschrift und kurzer Text',
      'Schreibe einen Flyer- oder Anzeigentext: eine starke Überschrift, drei kurze Vorteile als Stichpunkte und eine Handlungsaufforderung mit Kontakt.'),
];

const marketingToene = ['freundlich', 'professionell', 'locker'];

String marketingAnfrage(MarketingArt art, Firma f,
    {required String thema, String zielgruppe = '', String ton = 'freundlich'}) {
  final kontakt = [if (f.telefon.isNotEmpty) f.telefon, if (f.email.isNotEmpty) f.email].join(', ');
  return '''
${art.auftrag}

Firma: ${f.name.isEmpty ? '[Firmenname]' : f.name}
${kontakt.isEmpty ? '' : 'Kontakt: $kontakt\n'}Thema bzw. Inhalt: ${thema.trim()}
${zielgruppe.trim().isEmpty ? '' : 'Zielgruppe: ${zielgruppe.trim()}\n'}Ton: $ton
Sprache: Deutsch

Regeln:
- Keine erfundenen Preise, Rabatte, Auszeichnungen oder Kundenstimmen.
- Keine Übertreibungen wie „der Beste“ oder „Nummer 1“.
- Nur der fertige Text, keine Erklärung davor oder danach.
''';
}

/// Kurze Bitte um eine Bewertung, ohne KI.
String bewertungsText(Firma f, Kunde k) =>
    'Hallo ${k.name},\n\nvielen Dank für Ihren Auftrag! Wenn Sie zufrieden waren, würde ich mich sehr über eine kurze '
    'Bewertung freuen – das hilft mir als kleinem Betrieb sehr.\n\nViele Grüße\n${f.name}';

/// Kunden, deren letzter bezahlter Auftrag länger her ist – Ideen für eine Nachfrage.
List<(Kunde, DateTime)> wiederAnsprechen(List<Kunde> kunden, List<Rechnung> rechnungen,
    {required DateTime heute, int abTagen = 90}) {
  final out = <(Kunde, DateTime)>[];
  for (final k in kunden) {
    DateTime? letzte;
    for (final r in rechnungen) {
      if (r.kundeId != k.id || r.istAngebot || r.storniert) continue;
      if (letzte == null || r.datum.isAfter(letzte)) letzte = r.datum;
    }
    if (letzte != null && heute.difference(letzte).inDays >= abTagen) out.add((k, letzte));
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

/// Offene Angebote, bei denen eine Nachfrage sinnvoll sein kann.
List<Rechnung> angeboteNachfassen(List<Rechnung> rechnungen, {required DateTime heute, int abTagen = 7}) {
  return rechnungen
      .where((r) =>
          r.istAngebot &&
          !r.storniert &&
          heute.difference(r.datum).inDays >= abTagen &&
          heute.difference(r.datum).inDays <= 60 &&
          r.kundeId.isNotEmpty &&
          !rechnungen.any((x) => !x.istAngebot && x.kundeId == r.kundeId && !x.datum.isBefore(r.datum)))
      .toList()
    ..sort((a, b) => a.datum.compareTo(b.datum));
}
