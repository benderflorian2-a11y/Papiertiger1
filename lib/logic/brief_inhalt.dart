/// Liest aus jedem Brief heraus, was drinsteht – nicht nur Betrag und Frist:
/// Betreff, die wichtigsten Aussagen, alle Nummern, Bankverbindung, Beträge, Termine und Daten,
/// Kontakt und Anlagen. Reines Dart, ohne Internet, testbar.
library;

import 'brief_analyse.dart';
import 'textvergleich.dart';

class InhaltPunkt {
  const InhaltPunkt(this.gruppe, this.label, this.wert);

  /// Nummern, Bank, Beträge, Termine, Kontakt, Anlagen
  final String gruppe;
  final String label;
  final String wert;

  @override
  String toString() => '$gruppe › $label: $wert';
}

class BriefInhalt {
  BriefInhalt({this.betreff, required this.kernaussagen, required this.punkte});

  final String? betreff;

  /// Die wichtigsten Sätze aus dem Brief, in ihrer Reihenfolge.
  final List<String> kernaussagen;
  final List<InhaltPunkt> punkte;

  bool get leer => betreff == null && kernaussagen.isEmpty && punkte.isEmpty;

  /// Punkte nach Gruppe, in fester Reihenfolge.
  Map<String, List<InhaltPunkt>> get gruppen => {
        for (final g in inhaltGruppen)
          if (punkte.any((p) => p.gruppe == g)) g: punkte.where((p) => p.gruppe == g).toList(),
      };
}

const inhaltGruppen = ['Termine & Daten', 'Beträge', 'Nummern', 'Bankverbindung', 'Kontakt', 'Anlagen'];

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _euro(double b) {
  final s = b.toStringAsFixed(2).split('.');
  final ganz = s[0];
  final buf = StringBuffer();
  for (var i = 0; i < ganz.length; i++) {
    if (i > 0 && (ganz.length - i) % 3 == 0) buf.write('.');
    buf.write(ganz[i]);
  }
  return '$buf,${s[1]} €';
}

/// Text der Zeile vor [pos] (höchstens [max] Zeichen).
String _kontext(String text, int pos, {int max = 50}) {
  final anfang = text.lastIndexOf('\n', pos - 1) + 1;
  var s = text.substring(anfang, pos);
  if (s.length > max) {
    s = s.substring(s.length - max);
    final i = s.indexOf(' ');
    if (i >= 0) s = s.substring(i + 1); // nicht mitten im Wort anfangen
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final _ende = RegExp(r'[\s:=.,\-–(]+$');
final _fuellwort = RegExp(
    r'(?:^|\s+)(am|zum|bis|ab|vom|von|bis zum|ab dem|in höhe von|i\. ?h\. ?v\.?|über|insgesamt|beträgt|betrag von|um|den|der|die|des|sie)$',
    caseSensitive: false);

/// Beschriftung aus dem Text davor. Kurze Beschriftungen („Gesamtbetrag:“) bleiben,
/// bei Fließtext wird nach Stichwort benannt.
String _label(String kontext, String art) {
  var s = kontext.replaceAll(_ende, '');
  for (var i = 0; i < 3; i++) {
    s = s.replaceAll(_fuellwort, '').replaceAll(_ende, '');
  }
  final woerter = s.isEmpty ? 0 : s.split(' ').length;
  // Beschriftung statt Fließtext: endet mit „:“ oder besteht nur aus groß geschriebenen Wörtern
  final beschriftung = kontext.trimRight().endsWith(':') || s.split(' ').every((w) => RegExp(r'^[A-ZÄÖÜ0-9]').hasMatch(w));
  if (beschriftung && woerter > 0 && woerter <= 4 && s.length <= 40 && !RegExp(r'\d{2}\.\d{2}\.|\d+,\d{2}').hasMatch(s)) {
    return _gross(s);
  }
  final l = kontext.toLowerCase();
  bool hat(List<String> w) => w.any(l.contains);
  if (art == 'datum') {
    if (hat(['spätestens', 'frist', 'bis zum', 'bis spätestens', ' bis'])) return 'Frist';
    if (hat(['termin', 'einladung', 'erscheinen', 'vorsprache', 'besuch', 'kommen', ' um '])) return 'Termin';
    if (hat(['gültig', 'wirksam', ' ab ', 'ab dem', 'beginnt', 'seit'])) return 'Gültig ab';
    if (hat(['abgebucht', 'lastschrift', 'einzug', 'eingezogen'])) return 'Abbuchung';
    if (hat(['geboren', 'geb.'])) return 'Geburtsdatum';
    return 'Datum';
  }
  if (hat(['erstatt', 'guthaben', 'gutschrift', 'zurück'])) return 'Erstattung';
  if (hat(['monatlich', 'abschlag', 'pro monat', 'je monat', 'rate'])) return 'Monatlich';
  if (hat(['jährlich', 'pro jahr', 'jahresbeitrag'])) return 'Jährlich';
  if (hat(['nachzahl'])) return 'Nachzahlung';
  if (hat(['gebühr', 'kosten', 'mahngebühr'])) return 'Gebühr';
  if (hat(['überweis', 'zahl', 'offen', 'fällig', 'ausgleich'])) return 'Zu zahlen';
  return 'Betrag';
}

String _gross(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Prüft eine IBAN mit der Prüfziffer (Modulo 97).
bool ibanGueltig(String iban) {
  final s = iban.replaceAll(' ', '').toUpperCase();
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{10,30}$').hasMatch(s)) return false;
  if (s.startsWith('DE') && s.length != 22) return false;
  final umgestellt = s.substring(4) + s.substring(0, 4);
  var rest = 0;
  for (final c in umgestellt.codeUnits) {
    final z = c >= 65 ? (c - 55).toString() : String.fromCharCode(c);
    for (final ziffer in z.codeUnits) {
      rest = (rest * 10 + ziffer - 48) % 97;
    }
  }
  return rest == 1;
}

String _ibanSchoen(String s) {
  final r = s.replaceAll(' ', '').toUpperCase();
  return [for (var i = 0; i < r.length; i += 4) r.substring(i, i + 4 > r.length ? r.length : i + 4)].join(' ');
}

const _nummern = <String, String>{
  r'aktenzeichen|az\.|geschäftszeichen|gesch\.-z(?:eichen|\.)|unser zeichen|ihr zeichen': 'Aktenzeichen',
  r'steuernummer|st\.-?nr\.?': 'Steuernummer',
  r'steuer-?id(?:entifikationsnummer)?|identifikationsnummer|idnr\.?': 'Steuer-ID',
  r'kundennummer|kunden-nr\.?|kd\.-?nr\.?': 'Kundennummer',
  r'vertragsnummer|vertrags-nr\.?|vertragskonto': 'Vertragsnummer',
  r'rechnungsnummer|rechnungs-nr\.?|rg\.-?nr\.?|re\.-?nr\.?': 'Rechnungsnummer',
  r'versicherungsscheinnummer|versicherungsschein-nr\.?|policennummer': 'Versicherungsschein',
  r'versicherungsnummer|rentenversicherungsnummer|vers\.-?nr\.?': 'Versicherungsnummer',
  r'mitgliedsnummer|mitglieds-nr\.?': 'Mitgliedsnummer',
  r'kassenzeichen': 'Kassenzeichen',
  r'beitragsnummer': 'Beitragsnummer',
  r'bg-nummer|bedarfsgemeinschaft': 'BG-Nummer',
  r'zählernummer|zähler-nr\.?|zählernr\.?': 'Zählernummer',
  r'personalnummer': 'Personalnummer',
  r'bestellnummer|auftragsnummer|auftrags-nr\.?': 'Auftragsnummer',
  r'schadennummer|schaden-nr\.?': 'Schadennummer',
  r'mandatsreferenz': 'Mandatsreferenz',
  r'gläubiger-?id(?:entifikationsnummer)?': 'Gläubiger-ID',
  r'kennzeichen|amtl\. kennzeichen': 'Kennzeichen',
  r'verwendungszweck': 'Verwendungszweck',
};

final _betreffRe = RegExp(r'^[ \t]*(?:betreff|betr\.|betrifft|thema)\s*[:.]?\s*(.{3,})$', caseSensitive: false, multiLine: true);
final _anrede = RegExp(r'^[ \t]*(sehr geehrte|guten tag|hallo|liebe[rs]?\s)', caseSensitive: false, multiLine: true);
final _gruss = RegExp(r'^[ \t]*(mit freundlichen grüßen|freundliche grüße|mit freundlichem gruß|viele grüße|hochachtungsvoll)', caseSensitive: false, multiLine: true);

/// Sätze, die meistens nur Beiwerk sind.
final _beiwerk = RegExp(
    r'sehr geehrte|guten tag|freundlichen grüß|dieses schreiben wurde maschinell|ohne unterschrift gültig|seite \d+ von|'
    r'bankverbindung|geschäftsführ|amtsgericht|handelsregister|ust-?id|sitz der gesellschaft|vorstand|'
    r'datenschutz|www\.|@|telefon|tel\.|fax|öffnungszeiten|bei fragen|stehen wir ihnen|gerne zur verfügung|'
    r'vielen dank für ihr|wir danken ihnen|hinweise zum datenschutz',
    caseSensitive: false);

/// Wörter, die eine Aussage wichtig machen (mehrfach zählen).
const _gewicht = <String, int>{
  'bitte': 2, 'müssen': 3, 'muss': 3, 'sind verpflichtet': 3, 'verpflichtet': 2, 'spätestens': 3, 'bis zum': 2,
  'frist': 3, 'innerhalb': 2, 'fällig': 3, 'zahlen': 2, 'überweisen': 3, 'abgebucht': 2, 'erstatten': 3, 'erstattet': 3,
  'guthaben': 2, 'nachzahlung': 3, 'festgesetzt': 3, 'bewilligt': 3, 'abgelehnt': 3, 'gekündigt': 3, 'kündigung': 2,
  'erhöht': 3, 'erhöhung': 3, 'senkt': 2, 'ändert sich': 3, 'änderung': 2, 'ab dem': 2, 'ab sofort': 2, 'beträgt': 2,
  'termin': 2, 'einladung': 2, 'unterlagen': 2, 'nachweis': 2, 'einreichen': 2, 'vorlegen': 2, 'widerspruch': 3,
  'einspruch': 3, 'mahnung': 3, 'mahngebühr': 3, 'vollstreckung': 3, 'gesperrt': 3, 'nicht': 1, 'keine': 1,
  'entfällt': 2, 'bestätigen': 2, 'wir teilen ihnen mit': 2, 'hiermit': 1, 'leider': 2, 'wichtig': 2,
};

/// Die wichtigsten Sätze aus dem Hauptteil (zwischen Anrede und Gruß).
List<String> kernaussagen(String text, {int max = 6}) {
  var rumpf = text.replaceAll('\r', '');
  final a = _anrede.firstMatch(rumpf);
  if (a != null) {
    final zeilenEnde = rumpf.indexOf('\n', a.start);
    rumpf = zeilenEnde < 0 ? '' : rumpf.substring(zeilenEnde + 1);
  }
  final g = _gruss.firstMatch(rumpf);
  if (g != null) rumpf = rumpf.substring(0, g.start);
  // Umbrochene Zeilen zu Absätzen zusammenfügen (Leerzeile = neuer Absatz)
  final absaetze = rumpf
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.replaceAll(RegExp(r'-\n(?=[a-zäöü])'), '').replaceAll(RegExp(r'\s*\n\s*'), ' ').trim())
      .where((p) => p.isNotEmpty)
      .join('\n');
  final saetze = saetzeTrennen(absaetze);
  final bewertet = <(int, int, String)>[];
  for (var i = 0; i < saetze.length; i++) {
    final s = saetze[i];
    final w = s.split(' ').length;
    if (w < 5 || s.length > 400 || _beiwerk.hasMatch(s)) continue;
    // Tabellenzeilen und Adressen: kaum Kleinbuchstaben-Wörter
    if (RegExp(r'[a-zäöüß]{3,}').allMatches(s).length < 4) continue;
    final l = s.toLowerCase();
    var punkte = 0;
    for (final e in _gewicht.entries) {
      if (l.contains(e.key)) punkte += e.value;
    }
    if (RegExp(r'\d+,\d{2}\s?(€|eur)|\d{1,2}\.\d{1,2}\.\d{2,4}|\d+\s?%', caseSensitive: false).hasMatch(s)) punkte += 2;
    if (i < 3) punkte += 1; // Der Anfang sagt meist, worum es geht
    bewertet.add((punkte, i, s));
  }
  final beste = [...bewertet]..sort((x, y) => y.$1 != x.$1 ? y.$1.compareTo(x.$1) : x.$2.compareTo(y.$2));
  final auswahl = beste.where((b) => b.$1 > 0).take(max).toList()..sort((x, y) => x.$2.compareTo(y.$2));
  // Brief ganz ohne Signalwörter: dann die ersten Sätze
  if (auswahl.isEmpty) return bewertet.take(3).map((b) => b.$3).toList();
  return auswahl.map((b) => b.$3).toList();
}

String? _betreff(String text) {
  final m = _betreffRe.firstMatch(text);
  if (m != null) return m[1]!.trim();
  // Sonst: die Zeile direkt über der Anrede
  final a = _anrede.firstMatch(text);
  if (a == null) return null;
  final davor = text.substring(0, a.start).trimRight().split('\n').reversed;
  for (final z in davor) {
    final t = z.trim();
    if (t.isEmpty) continue;
    if (t.length < 8 || t.length > 120) return null;
    if (datumsFunde(t).isNotEmpty && t.length < 40) return null; // Ort, Datum
    if (RegExp(r'^\d{5}\s').hasMatch(t)) return null; // Postleitzahl
    return t;
  }
  return null;
}

/// Alles herauslesen, was im Brief steht.
BriefInhalt inhaltLesen(String text, {DateTime? briefDatum}) {
  final punkte = <InhaltPunkt>[];
  final gesehen = <String>{};
  void neu(String gruppe, String label, String wert) {
    final w = wert.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (w.isEmpty || !gesehen.add('$label|${w.toLowerCase()}')) return;
    if (punkte.where((p) => p.gruppe == gruppe).length >= 10) return;
    punkte.add(InhaltPunkt(gruppe, label, w));
  }

  // Termine & Daten – mit dem, was davor steht, und Uhrzeit
  for (final f in datumsFunde(text)) {
    final rest = text.substring(f.start);
    final ende = RegExp(r'^\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4}|^\d{1,2}\.?\s+\p{L}+\s+\d{4}', unicode: true).firstMatch(rest);
    final danach = ende == null ? '' : rest.substring(ende.end);
    final uhr = RegExp(r'^\s*(?:,|um|ab|von)?\s*(\d{1,2})[:.](\d{2})\s*(?:uhr|h\b)', caseSensitive: false).firstMatch(danach);
    final bis = RegExp(r'^\s*(?:bis|–|-)\s*(?:zum\s*)?(\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4})').firstMatch(danach);
    final kontext = _kontext(text, f.start);
    var label = _label(kontext, 'datum');
    final kurz = kontext.split(' ').length <= 2;
    if (briefDatum != null && f.wert == briefDatum && (kurz || label == 'Datum')) label = 'Briefdatum';
    // „Musterstadt, 14.10.2026“
    if (RegExp(r'^[A-ZÄÖÜ][\wäöüß\-. ]{1,30},$').hasMatch(kontext)) label = 'Briefdatum';
    if (uhr != null && label == 'Datum') label = 'Termin';
    if (bis != null || RegExp(r'(zeitraum|vom)$', caseSensitive: false).hasMatch(kontext)) label = bis != null && label == 'Datum' ? 'Zeitraum' : label;
    var wert = _d(f.wert);
    if (uhr != null) wert += ', ${uhr[1]}:${uhr[2]} Uhr';
    if (bis != null) wert += ' bis ${bis[1]!.replaceAll(' ', '')}';
    // Das Ende eines Zeitraums nicht noch einmal einzeln
    if (punkte.any((p) => p.gruppe == 'Termine & Daten' && p.wert.endsWith('bis ${_d(f.wert)}'))) continue;
    neu('Termine & Daten', label, wert);
  }

  // Beträge mit Beschriftung
  for (final f in betragsFunde(text)) {
    neu('Beträge', _label(_kontext(text, f.start), 'betrag'), _euro(f.wert));
  }

  // Nummern
  for (final e in _nummern.entries) {
    final re = RegExp('(?:^|[^a-zäöüß])(?:${e.key})\\s*[:.#]?\\s*([A-Z0-9][A-Z0-9/\\-. ]{1,32})', caseSensitive: false, multiLine: true);
    for (final m in re.allMatches(text)) {
      var w = m[1]!.split(RegExp(r'\s{2,}|\n')).first.trim();
      // Nur bis zum ersten Wort ohne Ziffer (z. B. „12345 Bitte …“)
      final teile = w.split(' ');
      final behalten = <String>[];
      for (final t in teile) {
        if (behalten.isNotEmpty && !RegExp(r'\d').hasMatch(t)) break;
        behalten.add(t);
      }
      w = behalten.join(' ').replaceAll(RegExp(r'[.\-/]+$'), '');
      if (e.value == 'Verwendungszweck') {
        w = m[1]!.split('\n').first.trim();
        if (w.length >= 3) neu('Bankverbindung', e.value, w);
        continue;
      }
      if (w.length < 3 || !RegExp(r'\d').hasMatch(w)) continue;
      neu('Nummern', e.value, w);
    }
  }

  // Bankverbindung
  for (final m in RegExp(r'\b([A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){3,7}(?: ?[A-Z0-9]{1,3})?)\b').allMatches(text.toUpperCase())) {
    final iban = m[1]!.replaceAll(' ', '');
    for (var laenge = iban.length; laenge >= 15; laenge--) {
      if (ibanGueltig(iban.substring(0, laenge))) {
        neu('Bankverbindung', 'IBAN', _ibanSchoen(iban.substring(0, laenge)));
        break;
      }
    }
  }
  for (final m in RegExp(r'\b(?:bic|swift)\s*[:.]?\s*([A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?)\b', caseSensitive: false).allMatches(text)) {
    neu('Bankverbindung', 'BIC', m[1]!.toUpperCase());
  }
  final bank = RegExp(r'^\s*(?:bank|kreditinstitut|geldinstitut)\s*:\s*(.{3,50})$', caseSensitive: false, multiLine: true).firstMatch(text);
  if (bank != null) neu('Bankverbindung', 'Bank', bank[1]!);

  // Kontakt
  for (final m in RegExp(
          r'(?:ansprechpartner(?:in)?|sachbearbeiter(?:in)?|bearbeitet von|ihr kontakt|auskunft erteilt|ihre ansprechpartnerin|ihr ansprechpartner)\s*[:]?\s*([A-ZÄÖÜ][^\n,]{2,50})',
          caseSensitive: false)
      .allMatches(text)) {
    neu('Kontakt', 'Ansprechpartner', m[1]!.replaceAll(RegExp(r'\s+(telefon|tel\.?|e-mail|zimmer).*$', caseSensitive: false), ''));
  }
  for (final m in RegExp(r'(?:telefon(?:nummer)?|tel\.?|fon|rufnummer|hotline|servicenummer|service-telefon)\s*[:.]?\s*(\+?[\d][\d \/()\-]{5,22}\d)', caseSensitive: false)
      .allMatches(text)) {
    final nummer = m[1]!.trim();
    if (nummer.replaceAll(RegExp(r'\D'), '').length >= 6) neu('Kontakt', 'Telefon', nummer);
  }
  for (final m in RegExp(r'(?:fax|telefax)\s*[:.]?\s*(\+?[\d][\d \/()\-]{5,22}\d)', caseSensitive: false).allMatches(text)) {
    neu('Kontakt', 'Fax', m[1]!.trim());
  }
  for (final m in RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}').allMatches(text)) {
    neu('Kontakt', 'E-Mail', m[0]!.toLowerCase());
  }
  for (final m in RegExp(r'\b(?:https?://)?(www\.[a-z0-9\-]+(?:\.[a-z0-9\-]+)*\.[a-z]{2,}(?:/[^\s,;)]*)?)', caseSensitive: false).allMatches(text)) {
    neu('Kontakt', 'Internet', m[1]!.toLowerCase().replaceAll(RegExp(r'[.]$'), ''));
  }
  for (final m in RegExp(r'(?:öffnungszeiten|sprechzeiten|erreichbar)\s*[:]?\s*([^\n]{5,80})', caseSensitive: false).allMatches(text)) {
    neu('Kontakt', 'Erreichbar', m[1]!);
  }

  // Anlagen
  final anl = RegExp(r'^[ \t]*anlage(?:n)?[ \t]*:?[ \t]*(.*)$', caseSensitive: false, multiLine: true).firstMatch(text);
  if (anl != null) {
    final zeilen = <String>[];
    if (anl[1]!.trim().isNotEmpty) zeilen.add(anl[1]!.trim());
    for (final z in text.substring(anl.end).split('\n').skip(1)) {
      final t = z.trim();
      if (t.isEmpty || zeilen.length >= 6) break;
      zeilen.add(t);
    }
    for (final z in zeilen) {
      final t = z.replaceFirst(RegExp(r'^[-•*–]\s*|^\d+[.)]\s*'), '');
      if (t.length >= 3 && t.length <= 80) neu('Anlagen', 'Anlage', t);
    }
  }

  return BriefInhalt(betreff: _betreff(text), kernaussagen: kernaussagen(text), punkte: punkte);
}
