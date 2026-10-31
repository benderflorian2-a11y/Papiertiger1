/// Job, Karriere und Weiterbildung: Stellenanzeigen auswerten, Bewerbungsunterlagen prüfen,
/// Lebenslauf, Anschreiben, Gespräch und Arbeitszeugnis. Reines Dart, testbar.
library;

import '../data/karriere.dart';
import '../data/models.dart';
import 'format.dart';

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
String _monat(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.year}';

// ---------------------------------------------------------------- Stellenanzeige

class AnzeigeInfo {
  AnzeigeInfo({
    required this.unterlagen,
    this.frist,
    this.email,
    this.ansprechpartner,
    this.arbeitszeit,
    this.befristet = false,
    this.gehaltGewuenscht = false,
    this.eintrittGewuenscht = false,
    this.gehaltsangabe,
  });

  /// Was die Firma sehen will.
  final List<String> unterlagen;
  final DateTime? frist;
  final String? email;

  /// z. B. „Frau Schmidt“ – für die Anrede.
  final String? ansprechpartner;
  final String? arbeitszeit;
  final bool befristet;

  /// Anzeige verlangt Gehaltsvorstellung bzw. frühestmöglichen Eintritt.
  final bool gehaltGewuenscht;
  final bool eintrittGewuenscht;

  /// Gehaltsangabe aus der Anzeige, falls genannt.
  final String? gehaltsangabe;
}

final _fristRe = RegExp(r'(?:bis(?:\s+zum)?|spätestens(?:\s+am)?|bewerbungsschluss:?|bewerbungsfrist:?)\s*(\d{1,2})\.(\d{1,2})\.(\d{2,4})',
    caseSensitive: false);
final _mailRe = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
final _ansprechRe = RegExp(r'\b(Frau|Herr|Herrn)\s+(?:Dr\.\s+)?([A-ZÄÖÜ][a-zäöüß]+(?:-[A-ZÄÖÜ][a-zäöüß]+)?)');
final _gehaltRe = RegExp(r'(\d{1,3}(?:\.\d{3})+|\d{4,6})\s*(?:€|EUR|Euro)(?:\s*(?:brutto|pro\s+(?:Jahr|Monat)|im\s+(?:Jahr|Monat)|jährlich|monatlich))?',
    caseSensitive: false);

/// Wertet eine Stellenanzeige ohne KI aus: verlangte Unterlagen, Frist, Kontakt, Arbeitszeit.
AnzeigeInfo anzeigeAuswerten(String text) {
  final t = text.toLowerCase();
  bool hat(String muster) => RegExp(muster, caseSensitive: false).hasMatch(t);
  final unterlagen = <String>[
    if (!hat(r'ohne anschreiben|kein anschreiben')) 'Anschreiben',
    'Lebenslauf',
    if (hat(r'zeugnis|zeugnisse|vollständigen unterlagen|vollständige unterlagen|aussagekräftigen unterlagen')) 'Zeugnisse',
    if (hat(r'zertifikat|nachweis|qualifikationsnachweis|führerschein')) 'Nachweise und Zertifikate',
    if (hat(r'führungszeugnis')) 'Führungszeugnis',
    if (hat(r'arbeitsprobe|portfolio|referenzprojekt')) 'Arbeitsproben bzw. Portfolio',
    if (hat(r'referenz(?!projekt)')) 'Referenzen',
    if (hat(r'foto|lichtbild')) 'Bewerbungsfoto',
  ];
  DateTime? frist;
  final fm = _fristRe.firstMatch(text);
  if (fm != null) {
    var j = int.parse(fm.group(3)!);
    if (j < 100) j += 2000;
    final m = int.parse(fm.group(2)!), tag = int.parse(fm.group(1)!);
    if (m >= 1 && m <= 12 && tag >= 1 && tag <= 31) frist = DateTime(j, m, tag);
  }
  final ap = _ansprechRe.firstMatch(text);
  final gehalt = _gehaltRe.firstMatch(text);
  return AnzeigeInfo(
    unterlagen: unterlagen,
    frist: frist,
    email: _mailRe.firstMatch(text)?.group(0),
    ansprechpartner: ap == null ? null : '${ap.group(1) == 'Herrn' ? 'Herr' : ap.group(1)} ${ap.group(2)}',
    arbeitszeit: hat(r'vollzeit') && hat(r'teilzeit')
        ? 'Voll- oder Teilzeit'
        : hat(r'vollzeit')
            ? 'Vollzeit'
            : hat(r'teilzeit')
                ? 'Teilzeit'
                : hat(r'minijob|538|556|603')
                    ? 'Minijob'
                    : null,
    befristet: hat(r'befristet') && !hat(r'unbefristet'),
    gehaltGewuenscht: hat(r'gehaltsvorstellung|gehaltswunsch|gehaltsvorstellungen'),
    eintrittGewuenscht: hat(r'eintrittstermin|frühestmöglich|frühestmöglichen|verfügbarkeit'),
    gehaltsangabe: gehalt?.group(0),
  );
}

// ---------------------------------------------------------------- Vollständigkeit

/// Was in der Bewerbung noch fehlt. Leere Liste = vollständig.
List<String> bewerbungPruefen(Bewerbung b, Lebenslauf l, Profil p, {required int anlagen}) {
  final info = anzeigeAuswerten(b.anzeige);
  final a = b.anschreiben.toLowerCase();
  return [
    if (p.name.trim().isEmpty || p.adresse.trim().isEmpty) 'Name und Adresse im Profil',
    if (l.telefon.trim().isEmpty && l.email.trim().isEmpty) 'Telefon oder E-Mail im Lebenslauf',
    if (l.stationen.isEmpty) 'Lebenslauf: noch keine Stationen',
    if (info.unterlagen.contains('Anschreiben') && b.anschreiben.trim().isEmpty) 'Anschreiben',
    if (b.anschreiben.isNotEmpty && RegExp(r'\[[^\]]+\]').hasMatch(b.anschreiben)) 'Platzhalter in [Klammern] im Anschreiben ausfüllen',
    if (info.gehaltGewuenscht && b.anschreiben.isNotEmpty && !RegExp(r'gehalt|€|euro|brutto').hasMatch(a))
      'Gehaltsvorstellung (wird in der Anzeige verlangt)',
    if (info.eintrittGewuenscht && b.anschreiben.isNotEmpty && !RegExp(r'eintritt|ab dem|ab sofort|zum \d|verfügbar|kündigungsfrist').hasMatch(a))
      'Frühestmöglicher Eintrittstermin (wird in der Anzeige verlangt)',
    if (info.ansprechpartner != null &&
        b.anschreiben.isNotEmpty &&
        !a.contains(info.ansprechpartner!.split(' ').last.toLowerCase()))
      'Anrede mit Namen: ${info.ansprechpartner}',
    if (info.unterlagen.contains('Zeugnisse') && anlagen == 0) 'Zeugnisse als Anlage',
    for (final u in info.unterlagen.where((u) => !['Anschreiben', 'Lebenslauf', 'Zeugnisse'].contains(u)))
      if (!b.erledigt.contains(u)) u,
    if (info.frist != null && b.beworbenAm == null && info.frist!.isBefore(DateTime.now())) 'Bewerbungsfrist ist schon vorbei',
  ];
}

/// Lücken im Lebenslauf von mehr als [monate] Monaten (Beruf und Ausbildung).
List<(DateTime, DateTime)> lebenslaufLuecken(List<Station> l, {int monate = 3, DateTime? heute}) {
  final s = l.where((x) => x.von != null && x.art != 'Ehrenamt').toList()..sort((a, b) => a.von!.compareTo(b.von!));
  final out = <(DateTime, DateTime)>[];
  DateTime? ende;
  for (final x in s) {
    if (ende != null) {
      final grenze = DateTime(ende.year, ende.month + monate + 1);
      if (!x.von!.isBefore(grenze)) out.add((ende, x.von!));
    }
    final e = x.bis ?? heute ?? DateTime.now();
    if (ende == null || e.isAfter(ende)) ende = e;
  }
  return out;
}

/// Bewerbung, bei der nach zwei Wochen ohne Antwort nachgefragt werden kann.
bool nachfassenFaellig(Bewerbung b, {required DateTime heute, int tage = 14}) =>
    b.status == 'Beworben' && b.beworbenAm != null && heute.difference(b.beworbenAm!).inDays >= tage;

// ---------------------------------------------------------------- Lebenslauf als Text

String lebenslaufText(Lebenslauf l, Profil p) {
  final z = StringBuffer('Lebenslauf\n\n${p.name}\n${p.adresse}\n');
  if (l.telefon.isNotEmpty) z.write('Telefon: ${l.telefon}\n');
  if (l.email.isNotEmpty) z.write('E-Mail: ${l.email}\n');
  if (l.geburtsdatum != null) z.write('Geboren am ${_d(l.geburtsdatum!)}\n');
  if (l.kurzprofil.isNotEmpty) z.write('\n${l.kurzprofil}\n');
  for (final art in stationsArten) {
    final st = l.stationen.where((s) => s.art == art).toList()
      ..sort((a, b) => (b.von ?? DateTime(0)).compareTo(a.von ?? DateTime(0)));
    if (st.isEmpty) continue;
    z.write('\n${art == 'Beruf' ? 'Berufserfahrung' : art}\n');
    for (final s in st) {
      final zeit = s.von == null ? '' : '${_monat(s.von!)} – ${s.bis == null ? 'heute' : _monat(s.bis!)}';
      z.write('$zeit  ${s.titel}${s.ort.isEmpty ? '' : ', ${s.ort}'}\n');
      if (s.text.isNotEmpty) z.write('    ${s.text.replaceAll('\n', '\n    ')}\n');
    }
  }
  if (l.kenntnisse.isNotEmpty) z.write('\nKenntnisse\n${l.kenntnisse.join(', ')}\n');
  if (l.sprachen.isNotEmpty) z.write('\nSprachen\n${l.sprachen.join(', ')}\n');
  return z.toString();
}

// ---------------------------------------------------------------- KI-Anfragen

String passungAnfrage(String anzeige, Lebenslauf l, Profil p) => '''
Vergleiche die Stellenanzeige mit meinem Lebenslauf. Antworte auf Deutsch, kurz und ehrlich, im Format:
MUSS-ANFORDERUNGEN:
- <Anforderung> – erfüllt / teilweise / fehlt
WÜNSCHENSWERT:
- <Anforderung> – erfüllt / teilweise / fehlt
PASSUNG: <hoch / mittel / gering> – <ein Satz>
BETONEN IM ANSCHREIBEN:
- <2 bis 3 Punkte aus meinem Lebenslauf>
OFFENE FRAGEN AN DIE FIRMA:
- <2 Punkte>
Erfinde keine Erfahrungen, die nicht im Lebenslauf stehen.

Stellenanzeige:
"""
${anzeige.trim()}
"""

Mein Lebenslauf:
"""
${lebenslaufText(l, p)}
"""
''';

String anschreibenAnfrage(Bewerbung b, Lebenslauf l, Profil p, {String eigeneNotizen = ''}) {
  final info = anzeigeAuswerten(b.anzeige);
  return '''
Schreibe ein Bewerbungsanschreiben auf Deutsch für die Stelle „${b.stelle}“ bei ${b.firma}.

Aufbau, jeder Teil durch eine Leerzeile getrennt: Absender (${p.name.isEmpty ? '[Name]' : p.name}, ${p.adresse.isEmpty ? '[Adresse]' : p.adresse}${l.telefon.isEmpty ? '' : ', ${l.telefon}'}${l.email.isEmpty ? '' : ', ${l.email}'}), Empfänger (${b.firma}${b.kontakt.isEmpty ? '' : ', ${b.kontakt}'}), Ort und Datum, eine Zeile „Betreff: Bewerbung als ${b.stelle}“, Anrede, Text, Grußformel und Name.

Regeln:
- Anrede: ${info.ansprechpartner != null ? 'Sehr geehrte${info.ansprechpartner!.startsWith('Herr') ? 'r' : ''} ${info.ansprechpartner},' : (b.kontakt.isNotEmpty ? 'mit dem Namen ${b.kontakt}' : 'Sehr geehrte Damen und Herren,')}
- Höchstens eine Seite. Kein „hiermit bewerbe ich mich“ als ersten Satz.
- Nur Erfahrungen aus dem Lebenslauf verwenden, nichts erfinden. Bezug auf 2 bis 3 Anforderungen der Anzeige.
${info.gehaltGewuenscht ? '- Die Anzeige verlangt eine Gehaltsvorstellung: schreibe „Meine Gehaltsvorstellung liegt bei [Betrag] Euro brutto im Jahr.“\n' : ''}${info.eintrittGewuenscht ? '- Die Anzeige fragt nach dem Eintrittstermin: schreibe „Ich kann die Stelle zum [Datum] antreten.“\n' : ''}- Nur das Anschreiben, keine Erklärung davor oder danach.
${eigeneNotizen.trim().isEmpty ? '' : '\nDas möchte ich unbedingt erwähnen: ${eigeneNotizen.trim()}\n'}
Stellenanzeige:
"""
${b.anzeige.trim()}
"""

Mein Lebenslauf:
"""
${lebenslaufText(l, p)}
"""
''';
}

String gespraechAnfrage(Bewerbung b, Lebenslauf l, Profil p) => '''
Bereite mich auf ein Vorstellungsgespräch als „${b.stelle}“ bei ${b.firma} vor. Antworte auf Deutsch im Format:
WAHRSCHEINLICHE FRAGEN:
- <Frage> → <kurzer Antwortvorschlag aus meinem Lebenslauf>
(8 Fragen, auch eine nach Schwächen und eine nach dem Gehalt)
MEINE FRAGEN AN DIE FIRMA:
- <4 sinnvolle Fragen>
CHECKLISTE FÜR DEN TAG:
- <4 Punkte>
Erfinde nichts über mich. Unzulässige Fragen (z. B. nach Schwangerschaft, Religion) kurz markieren.

Stellenanzeige:
"""
${b.anzeige.trim()}
"""

Mein Lebenslauf:
"""
${lebenslaufText(l, p)}
"""
''';

String zeugnisAnfrage(String zeugnis) => '''
Übersetze dieses Arbeitszeugnis aus der Zeugnissprache in Klartext. Antworte auf Deutsch im Format:
GESAMTNOTE (geschätzt): <1 bis 6> – <ein Satz>
LEISTUNG: <Note> – <Begründung mit Zitat>
VERHALTEN: <Note> – <Begründung mit Zitat>
AUFFÄLLIG:
- <versteckte Hinweise, fehlende übliche Teile, z. B. fehlende Dankes- und Bedauernsformel>
Kennzeichne Unsicheres. Keine Rechtsberatung.

Zeugnis:
"""
${zeugnis.trim()}
"""
''';

/// Schnelle Einschätzung der Zufriedenheitsformel (ohne KI). null = keine typische Formel gefunden.
(int, String)? zeugnisFormel(String zeugnis) {
  final t = zeugnis.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const formeln = [
    (r'stets zu unserer vollsten zufriedenheit', 1, 'sehr gut'),
    (r'stets zu unserer vollen zufriedenheit', 2, 'gut'),
    (r'zu unserer vollsten zufriedenheit', 2, 'gut'),
    (r'zu unserer vollen zufriedenheit', 3, 'befriedigend'),
    (r'stets zu unserer zufriedenheit', 3, 'befriedigend'),
    (r'im (?:großen|grossen) und ganzen zu unserer zufriedenheit', 5, 'mangelhaft'),
    (r'zu unserer zufriedenheit', 4, 'ausreichend'),
    (r'hat sich (?:stets )?bemüht', 6, 'ungenügend'),
  ];
  for (final (muster, note, wort) in formeln) {
    if (RegExp(muster).hasMatch(t)) return (note, wort);
  }
  return null;
}

// ---------------------------------------------------------------- Weiterbildung

/// Allgemeine Hinweise zur Förderung. Bedingungen bei der jeweiligen Stelle prüfen.
const foerderHinweise = [
  ('Bildungsgutschein', 'Agentur für Arbeit bzw. Jobcenter – wenn du arbeitslos bist oder es dir droht. Übernimmt meist die Kursgebühren.'),
  ('Aufstiegs-BAföG', 'Für Meister, Techniker, Fachwirt und ähnliche Abschlüsse – Zuschuss und zinsgünstiges Darlehen, unabhängig vom Alter.'),
  ('Weiterbildungsstipendium', 'Für junge Berufstätige mit sehr gutem Berufsabschluss (Stiftung Begabtenförderung berufliche Bildung).'),
  ('Förderung über den Arbeitgeber', 'Die Agentur für Arbeit kann Weiterbildung von Beschäftigten bezuschussen – frag deinen Arbeitgeber.'),
  ('Bildungsurlaub', 'In fast allen Bundesländern (nicht in Bayern und Sachsen) meist 5 Tage bezahlte Freistellung im Jahr für anerkannte Kurse.'),
  ('Steuer', 'Selbst bezahlte berufliche Fortbildung kannst du als Werbungskosten absetzen.'),
];

// ---------------------------------------------------------------- Gehaltsabrechnungen

class Gehalt {
  Gehalt({required this.brief, required this.monat, this.brutto, this.netto});

  final Brief brief;
  final DateTime monat;
  final double? brutto;
  final double? netto;
}

bool istGehaltsabrechnung(Brief b) =>
    RegExp(r'entgeltabrechnung|lohnabrechnung|gehaltsabrechnung|verdienstabrechnung|bezügemitteilung', caseSensitive: false)
        .hasMatch('${b.titel ?? ''} ${b.kiArt ?? ''} ${b.text}');

double? _betragNach(String text, String muster) {
  final m = RegExp('(?:$muster)[^\\d\\n]{0,40}?(\\d{1,3}(?:\\.\\d{3})*,\\d{2})', caseSensitive: false).firstMatch(text);
  return m == null ? null : double.parse(m.group(1)!.replaceAll('.', '').replaceAll(',', '.'));
}

/// Gehaltsabrechnungen aus dem Archiv mit Brutto und Netto, älteste zuerst.
List<Gehalt> gehaltsVerlauf(List<Brief> briefe) {
  final l = <Gehalt>[];
  for (final b in briefe.where(istGehaltsabrechnung)) {
    final d = b.briefDatum ?? b.erstellt;
    l.add(Gehalt(
      brief: b,
      monat: DateTime(d.year, d.month),
      brutto: _betragNach(b.text, r'gesamt-?brutto|bruttoentgelt|bruttoverdienst|brutto'),
      netto: _betragNach(b.text, r'auszahlungsbetrag|auszahlung|nettobetrag|nettoverdienst|nettoentgelt|netto'),
    ));
  }
  l.sort((a, b) => a.monat.compareTo(b.monat));
  return l;
}

/// Auffällige Änderungen beim Netto (mehr als [prozent] % zum Vormonat).
List<String> gehaltsAuffaelligkeiten(List<Gehalt> l, {double prozent = 5}) {
  final out = <String>[];
  for (var i = 1; i < l.length; i++) {
    final a = l[i - 1].netto, b = l[i].netto;
    if (a == null || b == null || a == 0) continue;
    final diff = (b - a) / a * 100;
    if (diff.abs() >= prozent) {
      out.add('${l[i].monat.month}/${l[i].monat.year}: Netto ${diff > 0 ? '+' : ''}${diff.toStringAsFixed(0)} % '
          '(${euroBetrag(b)} statt ${euroBetrag(a)})');
    }
  }
  return out;
}
