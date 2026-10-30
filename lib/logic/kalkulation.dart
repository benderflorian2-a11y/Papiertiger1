/// Kalkulation für Handwerk und Dienstleistung: Katalog, Verkaufspreise aus Einkauf,
/// Aufschlag und Arbeitszeit, Aufmaß und Angebotsentwurf per KI. Reines Dart, testbar.
library;

import '../data/geschaeft.dart';

double _rund(double x) => (x * 100).round() / 100;

/// Verkaufspreis netto je Einheit: Festpreis oder Einkauf + Aufschlag + Lohn.
double vkPreis(Artikel a, {required double stundensatz}) =>
    a.festpreis ?? _rund(a.einkauf * (1 + a.aufschlagProzent / 100) + a.minuten / 60 * stundensatz);

Position positionAusArtikel(Artikel a, {required double stundensatz, double menge = 1, bool kleinunternehmer = false}) =>
    Position(
      text: a.text,
      menge: menge,
      einheit: a.einheit,
      preis: vkPreis(a, stundensatz: stundensatz),
      ustSatz: kleinunternehmer ? 0 : a.ustSatz,
      einkauf: a.einkauf,
      minuten: a.minuten,
    );

/// Menge aus dem Aufmaß (Abzüge werden abgezogen), auf 2 Nachkommastellen.
double aufmassMenge(List<AufmassZeile> l) {
  final x = l.fold(0.0, (s, a) => s + a.wert);
  return x < 0 ? 0 : _rund(x);
}

String _z(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',');

/// Kurzform fürs PDF: „Wand Nord 4,20 × 2,50 · - Fenster 1,20 × 1,40“ (nur Zeichen, die die PDF-Schrift kennt).
String aufmassText(List<AufmassZeile> l) => l.map((a) {
      final masse = [if (a.anzahl != 1) _z(a.anzahl), for (final m in [a.laenge, a.breite, a.hoehe]) if (m != null) _z(m)];
      return '${a.abzug ? '- ' : ''}${a.text.isEmpty ? '' : '${a.text} '}${masse.join(' × ')}';
    }).join(' · ');

class Kalkulation {
  Kalkulation({required this.netto, required this.material, required this.lohn, required this.stunden});

  final double netto;
  final double material;
  final double lohn;
  final double stunden;

  /// Was nach Material und Lohn übrig bleibt (für Gemeinkosten und Gewinn).
  double get rohertrag => _rund(netto - material - lohn);
  double? get rohertragProzent => netto == 0 ? null : _rund(rohertrag / netto * 100);
}

/// Kalkulation eines Angebots: Material-Einkauf, Lohn und Rohertrag.
Kalkulation kalkulationVon(Rechnung r, {required double stundensatz, required double netto}) {
  var material = 0.0, minuten = 0.0;
  for (final p in r.positionen) {
    material += p.einkauf * p.menge;
    minuten += p.minuten * p.menge;
  }
  return Kalkulation(
    netto: netto,
    material: _rund(material),
    lohn: _rund(minuten / 60 * stundensatz),
    stunden: _rund(minuten / 60),
  );
}

double? _zahl(String s) {
  final t = s.replaceAll('€', '').replaceAll('"', '').trim();
  if (t.isEmpty) return null;
  // 1.234,56 oder 1234.56
  final deutsch = t.contains(',');
  return double.tryParse(deutsch ? t.replaceAll('.', '').replaceAll(',', '.') : t);
}

/// Katalog aus einer Tabelle (CSV aus Excel oder vom Großhändler): Semikolon, Tab oder Komma.
/// Erkennt Spalten über die Überschrift (Nummer, Bezeichnung, Einheit, Preis/EK, VK, Minuten).
/// Ohne Überschrift: Nummer; Bezeichnung; Einheit; Einkaufspreis.
List<Artikel> katalogAusCsv(String text, {required String Function() neueId, double aufschlag = 0}) {
  final zeilen = text.split('\n').map((z) => z.trimRight()).where((z) => z.trim().isNotEmpty).toList();
  if (zeilen.isEmpty) return [];
  final trenner = ['\t', ';', ','].firstWhere((t) => zeilen.first.contains(t), orElse: () => ';');
  List<String> teile(String z) => z.split(trenner).map((x) => x.trim().replaceAll(RegExp(r'^"|"$'), '')).toList();
  final kopf = teile(zeilen.first).map((x) => x.toLowerCase()).toList();
  final belegt = <int>{};
  // Namen in Reihenfolge prüfen; eine Spalte wird nur einmal vergeben.
  int spalte(List<String> namen) {
    for (final n in namen) {
      final i = n.startsWith('=')
          ? kopf.indexWhere((k) => k == n.substring(1))
          : [for (var i = 0; i < kopf.length; i++) i].firstWhere((i) => !belegt.contains(i) && kopf[i].contains(n), orElse: () => -1);
      if (i >= 0 && !belegt.contains(i)) {
        belegt.add(i);
        return i;
      }
    }
    return -1;
  }
  final hatKopf = kopf.any((k) => RegExp(r'bezeichnung|artikel|beschreibung|text|preis|einheit').hasMatch(k));
  var nr = 0, text_ = 1, einheit = 2, ek = 3, vk = -1, minuten = -1;
  if (hatKopf) {
    text_ = spalte(['bezeichnung', 'beschreibung', 'text', 'name', 'artikel']);
    nr = spalte(['nummer', 'nr']);
    einheit = spalte(['einheit', '=me']);
    vk = spalte(['vk', 'verkauf']);
    ek = spalte(['ek', 'einkauf', 'netto', 'preis']);
    minuten = spalte(['minuten', 'zeit', '=min']);
    if (text_ < 0) return [];
  }
  String feld(List<String> t, int i) => i >= 0 && i < t.length ? t[i] : '';
  final out = <Artikel>[];
  for (final z in zeilen.skip(hatKopf ? 1 : 0)) {
    final t = teile(z);
    final name = feld(t, text_);
    if (name.isEmpty) continue;
    final festpreis = _zahl(feld(t, vk));
    out.add(Artikel(
      id: neueId(),
      text: name,
      nummer: feld(t, nr),
      einheit: feld(t, einheit).isEmpty ? 'Stück' : feld(t, einheit),
      einkauf: _zahl(feld(t, ek)) ?? 0,
      aufschlagProzent: aufschlag,
      minuten: _zahl(feld(t, minuten)) ?? 0,
      festpreis: festpreis,
    ));
  }
  return out;
}

/// Suche im Katalog nach Nummer oder Wörtern der Bezeichnung.
List<Artikel> katalogSuchen(List<Artikel> l, String q) {
  final w = q.toLowerCase().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (w.isEmpty) return l;
  return l.where((a) {
    final t = '${a.nummer} ${a.text} ${a.gruppe}'.toLowerCase();
    return w.every(t.contains);
  }).toList();
}

// ---------------------------------------------------------------- Angebot per KI

/// KI-Anfrage: aus Notizen, Diktat oder Aufmaß einen Angebotsentwurf machen. Preise kommen
/// aus dem Katalog; was dort fehlt, bekommt Preis 0 und muss von dir ergänzt werden.
String angebotAnfrage(String notizen, List<Artikel> katalog, {required double stundensatz}) {
  final k = katalog.take(80).map((a) => '- ${a.text} (${a.einheit})').join('\n');
  return '''
Erstelle aus den Notizen unten die Positionen für ein Handwerker-Angebot.
${katalog.isEmpty ? '' : 'Verwende nach Möglichkeit genau diese Bezeichnungen aus meinem Katalog:\n$k\n'}
Antworte NUR mit einer Zeile pro Position im Format:
POS: <Bezeichnung> | <Menge> | <Einheit>

Regeln:
- Mengen nur aus den Notizen übernehmen oder daraus berechnen (z. B. Fläche = Länge × Breite). Nichts erfinden.
- Wenn eine Menge fehlt, schreibe 1 und setze ans Ende der Bezeichnung „[Menge prüfen]“.
- Keine Preise, keine Erklärungen.

Notizen:
"""
${notizen.trim()}
"""
''';
}

/// Liest „POS: …“-Zeilen. Bekannte Artikel bekommen ihren Katalogpreis, andere Preis 0.
List<Position> angebotLesen(String antwort, List<Artikel> katalog, {required double stundensatz, bool kleinunternehmer = false}) {
  final out = <Position>[];
  for (final z in antwort.split('\n')) {
    final m = RegExp(r'^\W*(?:pos(?:ition)?\s*\d*\s*[:.)-])?\s*(.+?)\s*\|\s*([\d.,]+)\s*\|\s*(.+?)\s*$', caseSensitive: false)
        .firstMatch(z.replaceAll('**', ''));
    if (m == null) continue;
    final text = m.group(1)!.trim();
    final menge = _zahl(m.group(2)!) ?? 1;
    final einheit = m.group(3)!.trim();
    final treffer = katalog.where((a) => a.text.toLowerCase() == text.toLowerCase().replaceAll('[menge prüfen]', '').trim());
    if (treffer.isNotEmpty) {
      out.add(positionAusArtikel(treffer.first, stundensatz: stundensatz, menge: menge, kleinunternehmer: kleinunternehmer)
        ..text = text);
    } else {
      out.add(Position(text: text, menge: menge, einheit: einheit, ustSatz: kleinunternehmer ? 0 : 19));
    }
  }
  return out;
}
