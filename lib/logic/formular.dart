/// Formular-Ausfüllhilfe: erkennt Felder in einem Formular und schlägt
/// Werte aus dem Profil vor. Reines Dart, damit es testbar ist.
library;

import '../data/models.dart';

class FormFeld {
  FormFeld(this.label, this.wert, {this.hinweis = ''});

  final String label;

  /// Vorgeschlagener Wert; null = fehlt noch.
  final String? wert;
  final String hinweis;
}

class FormularHilfe {
  FormularHilfe(this.felder, this.unterschriften, this.fehlt);

  final List<FormFeld> felder;
  final List<String> unterschriften;
  final List<String> fehlt;
}

/// Ordnet Feldbeschriftungen Profilwerten zu.
String? profilWert(String label, Profil p) {
  final l = label.toLowerCase();
  String? extra(String k) {
    final v = p.extra[k]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? leer(String v) => v.trim().isEmpty ? null : v.trim();
  final adresse = p.adresse.split('\n').map((z) => z.trim()).where((z) => z.isNotEmpty).toList();
  final strasse = adresse.isNotEmpty ? adresse.first : null;
  final plzOrt = adresse.length > 1 ? adresse[1] : null;
  final plz = plzOrt == null ? null : RegExp(r'\b\d{5}\b').firstMatch(plzOrt)?.group(0);
  final ort = plzOrt?.replaceFirst(RegExp(r'^\s*\d{5}\s*'), '').trim();

  if (l.contains('geburtsname')) return null;
  if (l.contains('geburtsdatum') || l.contains('geboren am')) return extra('geburtsdatum');
  if (l.contains('geburtsort')) return extra('geburtsort');
  if (l.contains('vorname')) return leer(p.vorname);
  if (l.contains('nachname') || l.contains('familienname') || l == 'name, vorname') {
    return l.contains('vorname') ? null : leer(p.nachname);
  }
  if (l.contains('name') && !l.contains('bank') && !l.contains('arbeitgeber')) return leer(p.name);
  if (l.contains('straße') || l.contains('strasse') || l.contains('hausnummer')) return strasse;
  if (l.contains('postleitzahl') || RegExp(r'\bplz\b').hasMatch(l)) return plzOrt ?? plz;
  if (l.contains('wohnort') || RegExp(r'^\s*ort\b').hasMatch(l)) return (ort == null || ort.isEmpty) ? null : ort;
  if (l.contains('anschrift') || l.contains('adresse')) return leer(p.adresse.replaceAll('\n', ', '));
  if (l.contains('telefon') || l.contains('tel.') || l.contains('mobil')) return extra('telefon');
  if (l.contains('e-mail') || l.contains('email')) return extra('email');
  if (l.contains('iban')) return extra('iban');
  if (l.contains('kreditinstitut') || l.contains('bank')) return extra('bank');
  if (l.contains('steuer-id') || l.contains('steueridentifikationsnummer') || l.contains('identifikationsnummer')) {
    return extra('steuerid');
  }
  if (l.contains('krankenkasse') || l.contains('krankenversicherung')) return extra('krankenkasse');
  if (l.contains('versichertennummer') || l.contains('krankenversichertennummer')) return extra('versichertennummer');
  if (l.contains('rentenversicherungsnummer') || l.contains('sozialversicherungsnummer')) {
    return extra('rentenversicherungsnummer');
  }
  if (l.contains('familienstand')) return extra('familienstand');
  if (l.contains('staatsangehörigkeit')) return extra('staatsangehoerigkeit');
  if (l.contains('arbeitgeber')) return extra('arbeitgeber');
  if (l.contains('beruf')) return extra('beruf');
  return null;
}

final _feldzeile = RegExp(r'^\s*([A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß .,/()\-]{1,45}?)\s*(?::|_{3,}|\.{4,})\s*[_.\s]*$');
final _unterschrift = RegExp(r'unterschrift|unterzeichne|ort,?\s*datum', caseSensitive: false);

/// Findet Felder ohne KI: Zeilen wie „Vorname: ____“ oder „Geburtsdatum:“.
FormularHilfe formularErkennen(String text, Profil p) {
  final felder = <FormFeld>[];
  final unterschriften = <String>[];
  final gesehen = <String>{};
  for (final zeile in text.split('\n')) {
    final z = zeile.trim();
    if (z.isEmpty) continue;
    if (_unterschrift.hasMatch(z) && z.length <= 80) {
      if (!unterschriften.contains(z)) unterschriften.add(z);
      continue;
    }
    final m = _feldzeile.firstMatch(z);
    if (m == null) continue;
    final label = m.group(1)!.trim();
    if (!gesehen.add(label.toLowerCase())) continue;
    felder.add(FormFeld(label, profilWert(label, p)));
  }
  final fehlt = [for (final f in felder) if (f.wert == null) f.label];
  return FormularHilfe(felder, unterschriften, fehlt);
}

String formularAnfrage(String text, Profil p) {
  final daten = StringBuffer()
    ..writeln('Name: ${p.name.isEmpty ? 'unbekannt' : p.name}')
    ..writeln('Adresse: ${p.adresse.isEmpty ? 'unbekannt' : p.adresse.replaceAll('\n', ', ')}');
  for (final (k, label) in profilFelder) {
    final v = p.extra[k];
    if (v != null && v.trim().isNotEmpty) daten.writeln('$label: $v');
  }
  final t = text.length > 6000 ? text.substring(0, 6000) : text;
  return '''
Das folgende Dokument ist ein Formular. Hilf beim Ausfüllen.

Bekannte Angaben der Person:
$daten
Antworte GENAU in diesem Format, eine Zeile pro Feld, das im Formular ausgefüllt werden muss:
FELD: <Feldname wie im Formular> | WERT: <Wert aus den bekannten Angaben oder FEHLT> | HINWEIS: <kurzer Tipp oder leer>
Danach:
UNTERSCHRIFT:
- <jede Stelle, an der unterschrieben werden muss, oder - Keine>
ANLAGEN:
- <Unterlagen, die beigelegt werden müssen, oder - Keine>

Erfinde keine Werte. Nutze nur die bekannten Angaben.

Formular:
"""
$t
"""
''';
}

/// Liest die KI-Antwort zur Ausfüllhilfe.
FormularHilfe formularAntwortLesen(String antwort) {
  final felder = <FormFeld>[];
  final unterschriften = <String>[];
  final anlagen = <String>[];
  List<String>? liste;
  for (final roh in antwort.split('\n')) {
    final z = roh.replaceAll('**', '').trim();
    if (z.isEmpty) continue;
    final f = RegExp(r'^FELD:\s*(.+?)\s*\|\s*WERT:\s*(.*?)\s*(?:\|\s*HINWEIS:\s*(.*))?$', caseSensitive: false)
        .firstMatch(z);
    if (f != null) {
      final wert = f.group(2)!.trim();
      final fehlt = wert.isEmpty || wert.toUpperCase().startsWith('FEHLT') || wert.toLowerCase() == 'unbekannt';
      felder.add(FormFeld(f.group(1)!.trim(), fehlt ? null : wert, hinweis: (f.group(3) ?? '').trim()));
      liste = null;
      continue;
    }
    if (RegExp(r'^UNTERSCHRIFT', caseSensitive: false).hasMatch(z)) {
      liste = unterschriften;
      continue;
    }
    if (RegExp(r'^ANLAGEN', caseSensitive: false).hasMatch(z)) {
      liste = anlagen;
      continue;
    }
    if (liste != null) {
      final t = z.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim();
      if (t.isNotEmpty && !RegExp(r'^keine?\.?$', caseSensitive: false).hasMatch(t)) liste.add(t);
    }
  }
  final fehlt = [for (final f in felder) if (f.wert == null) f.label, ...anlagen.map((a) => 'Anlage: $a')];
  return FormularHilfe(felder, unterschriften, fehlt);
}
