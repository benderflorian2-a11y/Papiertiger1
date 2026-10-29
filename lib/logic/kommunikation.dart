/// Schriftverkehr: Kontaktdaten aus Briefen, Antwort-Layout, Versand-Verlauf.
/// Reines Dart, damit es testbar ist.
library;

import '../data/models.dart';
import 'ordnung.dart';

// ---------------------------------------------------------------- Kontaktdaten

class Kontakt {
  Kontakt({this.emails = const [], this.telefon = const [], this.fax = const [], this.adresse});

  final List<String> emails;
  final List<String> telefon;
  final List<String> fax;

  /// Postanschrift des Absenders, mehrzeilig.
  final String? adresse;

  bool get leer => emails.isEmpty && telefon.isEmpty && fax.isEmpty && adresse == null;
}

final _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}');
final _nummer = RegExp(r'(\+?\(?\d[\d \t/\-()]{4,}\d)');
final _telLabel =
    RegExp(r'\b(telefon|tel|fon|hotline|servicenummer|rufnummer|mobil)\b\.?\s*:?', caseSensitive: false);
final _faxLabel = RegExp(r'\b(telefax|fax)\b\.?\s*:?', caseSensitive: false);
final _plzOrt = RegExp(r'\b(\d{5})\s+([A-ZÄÖÜ][\wäöüßÄÖÜ.\- ]{1,40})');
final _strasse = RegExp(
    r'([A-ZÄÖÜ][\wäöüßÄÖÜ.\- ]{2,40}(?:str\.|straße|strasse|weg|platz|allee|ring|gasse|damm|ufer|markt)\s*\d+\s*[a-zA-Z]?|Postfach\s*[\d ]+)',
    caseSensitive: false);

/// Telefonnummer zum Wählen: nur Ziffern und führendes +.
String nummerWaehlbar(String s) {
  final plus = s.trim().startsWith('+');
  final ziffern = s.replaceAll(RegExp(r'[^\d]'), '');
  return plus ? '+$ziffern' : ziffern;
}

List<String> _nummernNach(String text, RegExp label) {
  final out = <String>[];
  for (final m in label.allMatches(text)) {
    final rest = text.substring(m.end, (m.end + 40).clamp(0, text.length)).split('\n').first;
    final n = _nummer.firstMatch(rest);
    if (n == null) continue;
    final nr = n.group(1)!.trim();
    final z = nummerWaehlbar(nr);
    if (z.length < 6 || z.length > 16) continue;
    if (!out.any((x) => nummerWaehlbar(x) == z)) out.add(nr);
  }
  return out;
}

/// Sucht die Postanschrift des Absenders. Die eigene Adresse wird übersprungen.
String? adresseFinden(String text, {String? name, String eigeneAdresse = ''}) {
  final eigene = eigeneAdresse.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final zeilen = text.split('\n').take(40).toList();
  for (var i = 0; i < zeilen.length; i++) {
    final z = zeilen[i].trim();
    final plz = _plzOrt.firstMatch(z);
    if (plz == null) continue;
    final ort = '${plz.group(1)} ${plz.group(2)!.trim().split(RegExp(r'\s{2,}|·|\|')).first.trim()}';
    // Rücksendezeile im Fenster: „Finanzamt X · Musterstr. 1 · 12345 Ort“
    String? strasse;
    final vorher = z.substring(0, plz.start);
    strasse = _strasse.firstMatch(vorher)?.group(1)?.trim();
    if (strasse == null && i > 0) strasse = _strasse.firstMatch(zeilen[i - 1])?.group(1)?.trim();
    if (strasse == null) continue;
    final schluessel = strasse.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (eigene.isNotEmpty && eigene.contains(schluessel)) continue;
    return [if (name != null && name.trim().isNotEmpty) name.trim(), strasse, ort].join('\n');
  }
  return null;
}

Kontakt kontaktFinden(String text, {String? name, String eigeneAdresse = ''}) => Kontakt(
      emails: {
        for (final m in _email.allMatches(text)) m.group(0)!.toLowerCase().replaceAll(RegExp(r'\.$'), ''),
      }.toList(),
      telefon: _nummernNach(text, _telLabel),
      fax: _nummernNach(text, _faxLabel),
      adresse: adresseFinden(text, name: name, eigeneAdresse: eigeneAdresse),
    );

Kontakt kontaktVon(Brief b, Profil p) =>
    kontaktFinden(b.text, name: b.absenderName, eigeneAdresse: p.adresse);

// ---------------------------------------------------------------- E-Mail-Link

/// mailto-Link. Die E-Mail-App öffnet sich, verschickt wird erst dort.
Uri mailtoLink({String an = '', String betreff = '', String text = ''}) {
  String enc(String s) => Uri.encodeComponent(s.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n'));
  final q = [
    if (betreff.isNotEmpty) 'subject=${enc(betreff)}',
    if (text.isNotEmpty) 'body=${enc(text)}',
  ].join('&');
  return Uri.parse('mailto:${Uri.encodeComponent(an).replaceAll('%40', '@')}${q.isEmpty ? '' : '?$q'}');
}

// ---------------------------------------------------------------- Brief-Layout

class BriefTeile {
  BriefTeile({
    required this.absender,
    required this.empfaenger,
    required this.datum,
    required this.betreff,
    required this.inhalt,
  });

  final String absender;
  final String empfaenger;
  final String datum;
  final String betreff;
  final String inhalt;
}

final _datumZeile = RegExp(r'\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4}|\d{1,2}\.\s+[A-ZÄÖÜa-zäöü]+\s+\d{4}');

/// Zerlegt einen Antworttext (Absender, Empfänger, Datum, Betreff, Inhalt),
/// damit er als richtiger Brief gesetzt werden kann. null = kein Briefaufbau erkannt.
BriefTeile? briefTeile(String text) {
  final absaetze = text
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n\s*\n'))
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();
  final i = absaetze.indexWhere((a) => RegExp(r'^(betreff|betr\.|subject)\s*:', caseSensitive: false).hasMatch(a));
  if (i < 2 || i > 5) return null;
  var kopf = absaetze.sublist(0, i);
  var datum = '';
  final letzter = kopf.last;
  if (_datumZeile.hasMatch(letzter) && letzter.split('\n').length == 1) {
    datum = letzter.replaceFirst(RegExp(r'^Datum\s*:\s*', caseSensitive: false), '');
    kopf = kopf.sublist(0, kopf.length - 1);
  }
  if (kopf.length < 2) return null;
  final betreffZeilen = absaetze[i].split('\n');
  final betreff = betreffZeilen.first.replaceFirst(RegExp(r'^[^:]*:\s*'), '').trim();
  final inhalt = [
    if (betreffZeilen.length > 1) betreffZeilen.skip(1).join('\n'),
    ...absaetze.skip(i + 1),
  ].join('\n\n');
  return BriefTeile(
    absender: kopf.first,
    empfaenger: kopf.sublist(1).join('\n'),
    datum: datum,
    betreff: betreff,
    inhalt: inhalt,
  );
}

/// Betreffzeile eines Antworttexts, für die E-Mail.
String betreffVon(String text) => briefTeile(text)?.betreff ?? '';

/// Für die E-Mail: nur Anrede bis Gruß, ohne Adressblock.
String mailInhalt(String text) => briefTeile(text)?.inhalt ?? text;

// ---------------------------------------------------------------- Verlauf

const versandWege = ['Post', 'Einschreiben', 'E-Mail', 'Fax', 'Online-Portal', 'Persönlich abgegeben'];

/// Nach so vielen Tagen ohne Antwort erinnert der Tiger ans Nachfassen.
const nachfassTage = 28;

/// Vermerkt eine verschickte Antwort und plant das Nachfassen.
void antwortVermerken(Brief b, {required String weg, DateTime? am, String text = '', String? sendungsnummer}) {
  final d = am ?? DateTime.now();
  b.verlauf.add(Eintrag(
      id: neueId(),
      datum: d,
      art: 'gesendet',
      weg: weg,
      text: text,
      sendungsnummer: sendungsnummer?.trim().isEmpty ?? true ? null : sendungsnummer!.trim()));
  b.antwortGesendet = d;
  b.nachfassenAm = DateTime(d.year, d.month, d.day).add(const Duration(days: nachfassTage));
}

/// Vermerkt, dass eine Antwort des Absenders da ist: kein Nachfassen mehr.
void antwortErhalten(Brief b, {String text = ''}) {
  b.verlauf.add(Eintrag(id: neueId(), datum: DateTime.now(), art: 'erhalten', text: text));
  b.nachfassenAm = null;
}

/// Verlauf eines Briefs, neueste zuerst. Ältere Antworten ohne Eintrag werden ergänzt.
List<Eintrag> verlaufVon(Brief b) {
  final l = [...b.verlauf];
  if (b.antwortGesendet != null && !l.any((e) => e.art == 'gesendet')) {
    l.add(Eintrag(id: 'alt', datum: b.antwortGesendet!, art: 'gesendet'));
  }
  l.sort((a, c) => c.datum.compareTo(a.datum));
  return l;
}

class VerlaufZeile {
  VerlaufZeile(this.brief, this.eintrag);

  final Brief brief;
  final Eintrag eintrag;
}

/// Gesamter Schriftverkehr über alle Briefe, neueste zuerst.
List<VerlaufZeile> gesamtVerlauf(List<Brief> briefe) {
  final l = [
    for (final b in briefe)
      for (final e in verlaufVon(b)) VerlaufZeile(b, e),
  ];
  l.sort((a, c) => c.eintrag.datum.compareTo(a.eintrag.datum));
  return l;
}

/// Briefe, auf deren Antwort du wartest, älteste zuerst.
List<Brief> wartetAufAntwort(List<Brief> briefe) =>
    briefe.where((b) => b.nachfassenAm != null).toList()
      ..sort((a, c) => a.nachfassenAm!.compareTo(c.nachfassenAm!));

String verlaufTitel(Eintrag e) => switch (e.art) {
      'gesendet' => e.weg.isEmpty ? 'Antwort verschickt' : 'Verschickt per ${e.weg}',
      'erhalten' => 'Antwort erhalten',
      'anruf' => e.person == null || e.person!.isEmpty ? 'Telefonat' : 'Telefonat mit ${e.person}',
      _ => 'Notiz',
    };

/// Kurzer Text für die Akte, z. B. für PDF-Export oder Teilen.
String verlaufAlsText(Brief b) {
  String d(DateTime x) =>
      '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
  final z = StringBuffer('Schriftverkehr: ${titelVon(b)}\n');
  for (final e in verlaufVon(b).reversed) {
    z.write('\n${d(e.datum)}  ${verlaufTitel(e)}');
    if (e.sendungsnummer != null) z.write(' (Sendungsnummer ${e.sendungsnummer})');
    if (e.text.isNotEmpty) z.write('\n    ${e.text.replaceAll('\n', '\n    ')}');
  }
  return z.toString();
}

// ---------------------------------------------------------------- Sprache und Fristquelle

const _sprachWoerter = <String, List<String>>{
  'Deutsch': [' und ', ' der ', ' die ', ' das ', ' nicht ', ' ihre ', ' sie ', ' mit ', ' wir '],
  'Englisch': [' the ', ' and ', ' your ', ' you ', ' please ', ' with ', ' this ', ' we '],
  'Türkisch': [' ve ', ' bir ', ' için ', ' ile ', ' bu ', ' lütfen ', ' sayın '],
  'Französisch': [' le ', ' la ', ' et ', ' vous ', ' votre ', ' nous ', ' pour '],
  'Spanisch': [' el ', ' los ', ' y ', ' usted ', ' por ', ' para ', ' su '],
  'Italienisch': [' il ', ' gli ', ' e ', ' per ', ' lei ', ' suo ', ' della '],
  'Polnisch': [' i ', ' nie ', ' się ', ' na ', ' jest ', ' pan ', ' pani '],
  'Ukrainisch': [' і ', ' та ', ' не ', ' на ', ' ви ', ' ваш '],
  'Russisch': [' и ', ' не ', ' на ', ' вы ', ' ваш ', ' что '],
  'Arabisch': [' في ', ' من ', ' على ', ' إلى ', ' أن '],
};

/// Erkennt grob die Sprache eines Briefs (für Antworten in der Sprache des Absenders).
String spracheErkennen(String text) {
  final t = ' ${text.toLowerCase().replaceAll(RegExp(r'[\s,.;:!?()]+'), ' ')} ';
  var beste = 'Deutsch';
  var punkte = 0;
  _sprachWoerter.forEach((sprache, woerter) {
    var n = 0;
    for (final w in woerter) {
      n += w.allMatches(t).length;
    }
    if (n > punkte) {
      punkte = n;
      beste = sprache;
    }
  });
  return beste;
}

/// Der Satz im Brief, in dem das Fristdatum steht – damit die Frist eine Quelle hat.
String? fristQuelle(String text, DateTime frist) {
  final d = frist.day, m = frist.month, j = frist.year;
  final muster = RegExp(
      '(?<!\\d)(?:0?$d\\.\\s?0?$m\\.\\s?(?:$j|${j % 100})(?!\\d)|0?$d\\.\\s?(?:${_monatsnamen[m - 1]})\\w*\\s+$j)',
      caseSensitive: false);
  final treffer = muster.firstMatch(text);
  if (treffer == null) return null;
  var start = text.lastIndexOf(RegExp(r'[.!?\n]\s'), treffer.start);
  // Datumspunkte („15.11.“) nicht als Satzende werten: weiter nach vorne suchen.
  while (start > 0 && RegExp(r'\d').hasMatch(text[start - 1 < 0 ? 0 : start - 1]) && text[start] == '.') {
    start = text.lastIndexOf(RegExp(r'[.!?\n]\s'), start - 1);
  }
  final ende = text.indexOf(RegExp(r'[.!?](\s|$)|\n'), treffer.end);
  final satz = text
      .substring(start < 0 ? 0 : start + 1, ende < 0 ? text.length : ende + 1)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return satz.length > 220 ? '${satz.substring(0, 217)}…' : satz;
}

const _monatsnamen = [
  'januar', 'februar', 'märz', 'april', 'mai', 'juni', 'juli', 'august', 'september', 'oktober', 'november', 'dezember',
];


/// Trägt eine Anlage in den Brief ein: ergänzt die Liste unter „Anlagen:“ oder legt sie am Ende an.
String anlagenVermerk(String text, String anlage) {
  final zeilen = text.trimRight().split('\n');
  final kopf = zeilen.lastIndexWhere((z) => RegExp(r'^\s*Anlagen?\s*:?\s*$', caseSensitive: false).hasMatch(z));
  if (kopf < 0) return '${text.trimRight()}\n\nAnlagen:\n- $anlage';
  var ende = kopf + 1;
  while (ende < zeilen.length && zeilen[ende].trim().startsWith('-')) {
    if (zeilen[ende].trim().substring(1).trim() == anlage) return text;
    ende++;
  }
  zeilen[kopf] = 'Anlagen:';
  zeilen.insert(ende, '- $anlage');
  return zeilen.join('\n');
}
