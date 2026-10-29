/// Liest E-Mails im .eml-Format (z. B. aus Gmail „Herunterladen“ oder aus
/// Outlook gespeichert). Reines Dart, damit es testbar ist.
library;

import 'dart:convert';
import 'dart:typed_data';

class MailAnhang {
  MailAnhang(this.name, this.mime, this.daten);

  final String name;
  final String mime;
  final Uint8List daten;

  bool get istPdf => mime == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
  bool get istBild => mime.startsWith('image/');
}

class Mail {
  Mail({
    required this.von,
    required this.an,
    required this.betreff,
    required this.datum,
    required this.text,
    required this.anhaenge,
  });

  final String von;
  final String an;
  final String betreff;
  final DateTime? datum;
  final String text;
  final List<MailAnhang> anhaenge;

  /// Text für die Auswertung: Kopfzeilen und Inhalt.
  String get alsBrieftext {
    final z = StringBuffer();
    if (von.isNotEmpty) z.writeln('Von: $von');
    if (datum != null) {
      final d = datum!;
      z.writeln('Datum: ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}');
    }
    if (betreff.isNotEmpty) z.writeln('Betreff: $betreff');
    z
      ..writeln()
      ..write(text.trim());
    return z.toString();
  }
}

class _Teil {
  _Teil(this.kopf, this.inhalt);

  final Map<String, String> kopf;

  /// Rohinhalt, ein Zeichen pro Byte (latin1).
  final String inhalt;

  String feld(String name) => kopf[name] ?? '';
}

/// Zerlegt Kopf und Inhalt. Kopfnamen klein, Folgezeilen zusammengefügt.
_Teil _zerlegen(String roh) {
  final s = roh.replaceAll('\r\n', '\n');
  final ende = s.indexOf('\n\n');
  final kopfText = ende < 0 ? s : s.substring(0, ende);
  final inhalt = ende < 0 ? '' : s.substring(ende + 2);
  final kopf = <String, String>{};
  String? letzter;
  for (final zeile in kopfText.split('\n')) {
    if (zeile.isEmpty) continue;
    if ((zeile.startsWith(' ') || zeile.startsWith('\t')) && letzter != null) {
      kopf[letzter] = '${kopf[letzter]} ${zeile.trim()}';
      continue;
    }
    final i = zeile.indexOf(':');
    if (i <= 0) continue;
    letzter = zeile.substring(0, i).trim().toLowerCase();
    kopf.putIfAbsent(letzter, () => zeile.substring(i + 1).trim());
  }
  return _Teil(kopf, inhalt);
}

/// Wert und Parameter eines Kopffelds, z. B. `text/plain; charset=utf-8`.
(String, Map<String, String>) _parameter(String feld) {
  final teile = feld.split(';');
  final p = <String, String>{};
  for (final t in teile.skip(1)) {
    final i = t.indexOf('=');
    if (i < 0) continue;
    var v = t.substring(i + 1).trim();
    if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
    p[t.substring(0, i).trim().toLowerCase()] = v;
  }
  return (teile.first.trim().toLowerCase(), p);
}

Uint8List _bytes(String latin1) => Uint8List.fromList(latin1.codeUnits.map((c) => c & 0xff).toList());

Uint8List _quotedPrintable(String s) {
  final t = s.replaceAll('\r\n', '\n').replaceAll('=\n', '');
  final out = <int>[];
  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (c == '=' && i + 2 < t.length) {
      final h = int.tryParse(t.substring(i + 1, i + 3), radix: 16);
      if (h != null) {
        out.add(h);
        i += 2;
        continue;
      }
    }
    out.add(t.codeUnitAt(i) & 0xff);
  }
  return Uint8List.fromList(out);
}

Uint8List _dekodieren(String inhalt, String kodierung) {
  switch (kodierung.toLowerCase()) {
    case 'base64':
      try {
        final rein = inhalt.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
        return base64.decode(base64.normalize(rein));
      } catch (_) {
        return _bytes(inhalt);
      }
    case 'quoted-printable':
      return _quotedPrintable(inhalt);
    default:
      return _bytes(inhalt);
  }
}

String _alsText(Uint8List b, String zeichensatz) {
  final z = zeichensatz.toLowerCase();
  if (z.contains('8859') || z.contains('1252') || z.contains('latin')) return latin1.decode(b);
  return utf8.decode(b, allowMalformed: true);
}

final _wort = RegExp(r'=\?([^?]+)\?([bBqQ])\?([^?]*)\?=');

/// Kopfzeilen mit Sonderzeichen: =?UTF-8?B?...?= und =?ISO-8859-1?Q?...?=
String kopfDekodieren(String s) {
  final ohneLuecken = s.replaceAllMapped(RegExp(r'\?=\s+=\?'), (_) => '?==?');
  final roh = ohneLuecken.replaceAllMapped(_wort, (m) {
    final b = m.group(2)!.toLowerCase() == 'b'
        ? _dekodieren(m.group(3)!, 'base64')
        : _quotedPrintable(m.group(3)!.replaceAll('_', ' '));
    return _alsText(b, m.group(1)!);
  });
  // Kopfzeilen ohne Kodierung können trotzdem UTF-8-Bytes enthalten.
  if (!roh.codeUnits.any((c) => c > 0x7f && c <= 0xff)) return roh;
  return _alsText(_bytes(roh), 'utf-8').contains('�') ? roh : _alsText(_bytes(roh), 'utf-8');
}

/// Macht aus HTML lesbaren Text.
String htmlZuText(String html) {
  var s = html
      .replaceAll(RegExp(r'<(style|script|head)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|tr|li|h[1-6])>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&auml;': 'ä',
    '&ouml;': 'ö',
    '&uuml;': 'ü',
    '&Auml;': 'Ä',
    '&Ouml;': 'Ö',
    '&Uuml;': 'Ü',
    '&szlig;': 'ß',
    '&euro;': '€',
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
  return s
      .split('\n')
      .map((z) => z.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

const _monate = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// Datum aus dem Mail-Kopf, z. B. „Tue, 28 Oct 2026 10:15:00 +0100“ (Ortszeit des Absenders).
DateTime? mailDatum(String s) {
  final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})\w*\s+(\d{4})(?:\s+(\d{1,2}):(\d{2}))?').firstMatch(s);
  if (m == null) return null;
  final monat = _monate[m.group(2)!.toLowerCase()];
  if (monat == null) return null;
  return DateTime(int.parse(m.group(3)!), monat, int.parse(m.group(1)!),
      int.tryParse(m.group(4) ?? '') ?? 0, int.tryParse(m.group(5) ?? '') ?? 0);
}

/// Liest eine .eml-Datei.
Mail emlLesen(Uint8List daten) {
  final haupt = _zerlegen(latin1.decode(daten, allowInvalid: true));
  final texte = <String>[];
  final htmls = <String>[];
  final anhaenge = <MailAnhang>[];

  void teilLesen(_Teil t, int tiefe) {
    final (typ, p) = _parameter(t.feld('content-type').isEmpty ? 'text/plain' : t.feld('content-type'));
    if (typ.startsWith('multipart/') && p['boundary'] != null && tiefe < 8) {
      final grenze = '--${p['boundary']}';
      final stuecke = t.inhalt.split(grenze);
      for (final s in stuecke.skip(1)) {
        if (s.startsWith('--')) break;
        teilLesen(_zerlegen(s.replaceFirst(RegExp(r'^\r?\n'), '')), tiefe + 1);
      }
      return;
    }
    if (typ == 'message/rfc822' && tiefe < 8) {
      teilLesen(_zerlegen(t.inhalt), tiefe + 1);
      return;
    }
    final bytes = _dekodieren(t.inhalt, t.feld('content-transfer-encoding'));
    final (art, dp) = _parameter(t.feld('content-disposition'));
    final name = kopfDekodieren(dp['filename'] ?? p['name'] ?? '');
    final istAnhang = art == 'attachment' || (name.isNotEmpty && !typ.startsWith('text/'));
    if (!istAnhang && typ == 'text/plain') {
      texte.add(_alsText(bytes, p['charset'] ?? 'utf-8'));
    } else if (!istAnhang && typ == 'text/html') {
      htmls.add(htmlZuText(_alsText(bytes, p['charset'] ?? 'utf-8')));
    } else if (bytes.isNotEmpty) {
      anhaenge.add(MailAnhang(name.isEmpty ? 'anhang' : name, typ, bytes));
    }
  }

  teilLesen(haupt, 0);
  final text = (texte.isNotEmpty ? texte : htmls).join('\n\n').replaceAll('\r\n', '\n').trim();
  return Mail(
    von: kopfDekodieren(haupt.feld('from')),
    an: kopfDekodieren(haupt.feld('to')),
    betreff: kopfDekodieren(haupt.feld('subject')),
    datum: mailDatum(haupt.feld('date')),
    text: text,
    anhaenge: anhaenge,
  );
}
