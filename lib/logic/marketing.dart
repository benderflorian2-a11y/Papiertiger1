/// Marketing für Selbstständige: KI-Anfragen für Texte und Kunden, die man
/// wieder ansprechen könnte. Reines Dart, damit es testbar ist.
library;

import '../data/geschaeft.dart';

class MarketingArt {
  const MarketingArt(this.key, this.titel, this.beschreibung, this.auftrag,
      {this.eingabe = 'Worum geht es?', this.beispiel = 'z. B. Neue Öffnungszeiten ab Dezember', this.zielgruppe = true});

  final String key;
  final String titel;
  final String beschreibung;

  /// Was die KI schreiben soll.
  final String auftrag;

  /// Beschriftung und Beispiel für das Eingabefeld.
  final String eingabe;
  final String beispiel;
  final bool zielgruppe;
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
      'Schreibe eine höfliche, sachliche öffentliche Antwort auf die Kundenbewertung unten. Bedanke dich, geh auf Kritik ein, nenne keine privaten Details. Höchstens 80 Wörter.',
      eingabe: 'Die Bewertung des Kunden', beispiel: 'Bewertung hier einfügen', zielgruppe: false),
  MarketingArt('anfrage', 'Kundenanfrage beantworten', 'Schnell und freundlich',
      'Beantworte die Kundenanfrage unten freundlich und konkret. Wenn Angaben fehlen (Preis, Termin), setze [eckige Klammern]. Höchstens 120 Wörter.',
      eingabe: 'Die Anfrage des Kunden', beispiel: 'Nachricht hier einfügen', zielgruppe: false),
  MarketingArt('optimieren', 'Angebots- oder Verkaufstext verbessern', 'Klarer und überzeugender',
      'Überarbeite den Text unten: klarer, kürzer, Nutzen für den Kunden zuerst, eine Handlungsaufforderung am Ende. Gib danach drei kurze Begründungen, was du geändert hast.',
      eingabe: 'Dein bisheriger Text', beispiel: 'Text hier einfügen', zielgruppe: true),
  MarketingArt('plattformen', 'Für andere Plattformen umschreiben', 'Instagram, LinkedIn, Website, Newsletter',
      'Schreibe den Text unten in vier Fassungen um: INSTAGRAM (locker, mit Hashtags), LINKEDIN (sachlich), WEBSITE (2 bis 3 Sätze), NEWSLETTER (mit Betreffzeile). Jede Fassung mit Überschrift.',
      eingabe: 'Ausgangstext', beispiel: 'Text hier einfügen', zielgruppe: false),
  MarketingArt('redaktion', 'Redaktionsplan', '4 Wochen Beiträge planen',
      'Erstelle einen Redaktionsplan für 4 Wochen mit 2 Beiträgen pro Woche. Für jeden Beitrag: Woche, Kanal, Thema, ein Satz Idee, passendes Format (Foto, Video, Text).',
      eingabe: 'Worum geht es in deinem Betrieb?', beispiel: 'z. B. Fensterreinigung, Schwerpunkt Herbst und Weihnachten'),
  MarketingArt('video', 'Ideen für Videos und Reels', 'Kurz, einfach, mit dem Handy',
      'Liefere 5 Ideen für kurze Videos oder Reels (15 bis 45 Sekunden), die man allein mit dem Handy drehen kann. Je Idee: Titel, Ablauf in 3 Schritten, Text für den ersten Satz.',
      eingabe: 'Worum geht es?', beispiel: 'z. B. Vorher-nachher bei der Fensterreinigung'),
  MarketingArt('website', 'Website-Text', 'Startseite oder „Über uns“',
      'Schreibe einen Website-Text mit Überschrift, kurzem Einleitungssatz, drei Abschnitten mit Zwischenüberschrift (Leistungen, Ablauf, Warum wir) und einer Handlungsaufforderung. Höchstens 250 Wörter.',
      eingabe: 'Was bietest du an?', beispiel: 'z. B. Fensterreinigung für Privathaushalte in Köln'),
  MarketingArt('feedback', 'Feedback und Bewertungen zusammenfassen', 'Themen erkennen',
      'Fasse die Kundenstimmen unten zusammen. Antworte im Format:\nGESAMTEINDRUCK: <ein Satz>\nLOB:\n- <Themen mit Häufigkeit>\nKRITIK:\n- <Themen mit Häufigkeit>\nVERBESSERUNGEN:\n- <2 bis 3 konkrete Vorschläge>',
      eingabe: 'Bewertungen, Umfrage-Antworten oder Feedback', beispiel: 'Mehrere Texte untereinander einfügen', zielgruppe: false),
  MarketingArt('umfrage', 'Umfrage auswerten', 'Antworten zählen und deuten',
      'Werte die Umfrage unten aus. Die Auszählung ist schon gemacht, übernimm die Zahlen genau. Antworte im Format:\nWICHTIGSTE ERGEBNISSE:\n- <3 bis 5 Punkte mit Prozent>\nAUFFÄLLIG:\n- <Überraschendes oder Widersprüchliches>\nWAS DU TUN KANNST:\n- <2 bis 3 konkrete Schritte>\nWeise darauf hin, wenn sehr wenige Antworten vorliegen.',
      eingabe: 'Umfrage-Ergebnisse (Tabelle aus Google Forms, Excel o. ä. einfügen)',
      beispiel: 'Erste Zeile die Fragen, darunter eine Zeile je Antwort',
      zielgruppe: false),
  MarketingArt('kampagne', 'Kampagne auswerten', 'Zahlen verständlich machen',
      'Werte die Zahlen der Kampagne unten aus: Was lief gut, was schlecht, was sollte man beim nächsten Mal ändern? Rechne Kennzahlen wie Kosten pro Klick oder pro Anfrage nach, wenn die Zahlen dafür da sind.',
      eingabe: 'Zahlen der Kampagne', beispiel: 'z. B. 500 € Budget, 12.000 Aufrufe, 340 Klicks, 9 Anfragen', zielgruppe: false),
  MarketingArt('praesentation', 'Präsentation gliedern', 'Folien für Kunden oder Pitch',
      'Erstelle die Gliederung einer kurzen Präsentation mit 6 bis 8 Folien. Je Folie: Überschrift und 2 bis 3 Stichpunkte.',
      eingabe: 'Worum geht die Präsentation?', beispiel: 'z. B. Angebot für eine Hausverwaltung'),
  MarketingArt('flyer', 'Flyer- oder Anzeigentext', 'Überschrift und kurzer Text',
      'Schreibe einen Flyer- oder Anzeigentext: eine starke Überschrift, drei kurze Vorteile als Stichpunkte und eine Handlungsaufforderung mit Kontakt.'),
];

const marketingToene = ['freundlich', 'professionell', 'locker'];

String marketingAnfrage(MarketingArt art, Firma f,
    {required String thema, String zielgruppe = '', String ton = 'freundlich'}) {
  final kontakt = [if (f.telefon.isNotEmpty) f.telefon, if (f.email.isNotEmpty) f.email].join(', ');
  if (art.key == 'umfrage') {
    final z = umfrageZaehlen(thema);
    if (z.isNotEmpty) thema = '$z\n\nRohdaten (gekürzt):\n${thema.length > 3000 ? thema.substring(0, 3000) : thema}';
  }
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
      if (r.kundeId != k.id || !r.istRechnung || r.storniert) continue;
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
          !rechnungen.any((x) => x.istRechnung && x.kundeId == r.kundeId && !x.datum.isBefore(r.datum)))
      .toList()
    ..sort((a, b) => a.datum.compareTo(b.datum));
}


/// Zählt eine eingefügte Umfrage-Tabelle aus (Tab, Semikolon oder Komma getrennt;
/// erste Zeile = Fragen). Fragen mit wenigen verschiedenen Antworten werden gezählt,
/// Freitext-Fragen nur mit der Zahl der Antworten genannt. Leer, wenn es keine Tabelle ist.
String umfrageZaehlen(String text) {
  final zeilen = text.split('\n').map((z) => z.trimRight()).where((z) => z.trim().isNotEmpty).toList();
  if (zeilen.length < 2) return '';
  final trenner = ['\t', ';', ','].firstWhere((t) => zeilen.first.contains(t), orElse: () => '');
  if (trenner.isEmpty) return '';
  List<String> teile(String z) => z.split(trenner).map((x) => x.trim().replaceAll(RegExp(r'^"|"$'), '')).toList();
  final fragen = teile(zeilen.first);
  final antworten = zeilen.skip(1).map(teile).toList();
  final out = StringBuffer('Auszählung (${antworten.length} Antworten):');
  for (var i = 0; i < fragen.length; i++) {
    if (RegExp(r'zeitstempel|timestamp|e-mail|email|name', caseSensitive: false).hasMatch(fragen[i])) continue;
    final werte = [for (final a in antworten) if (i < a.length && a[i].isNotEmpty) a[i]];
    if (werte.isEmpty) continue;
    final zaehler = <String, int>{};
    for (final w in werte) {
      zaehler[w] = (zaehler[w] ?? 0) + 1;
    }
    out.write('\n\n${fragen[i]}');
    if (zaehler.length > 8 && zaehler.length > werte.length / 2) {
      out.write(' – Freitext, ${werte.length} Antworten');
      continue;
    }
    final sortiert = zaehler.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortiert) {
      out.write('\n- ${e.key}: ${e.value} (${(e.value * 100 / werte.length).round()} %)');
    }
  }
  return out.toString();
}
