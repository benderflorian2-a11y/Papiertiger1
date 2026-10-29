/// Ordnung im Papierkram: Titel, Ordner, Vorgänge (Akten), Dringlichkeit,
/// Duplikate, angeforderte Unterlagen und Aufbewahrung.
/// Reines Dart, damit es testbar ist.
library;

import '../data/models.dart';
import 'brief_analyse.dart';
import 'datum.dart';

// ---------------------------------------------------------------- Ordner

class Ordner {
  const Ordner(this.key, this.name, this.kategorien, this.aufbewahrungJahre, this.aufbewahrungText);

  final String key;
  final String name;
  final List<String> kategorien;

  /// Empfohlene Aufbewahrung in Jahren ab Jahresende; null = dauerhaft bzw. abhängig.
  final int? aufbewahrungJahre;
  final String aufbewahrungText;
}

const alleOrdner = <Ordner>[
  Ordner('steuern', 'Steuern', ['finanzamt'], 10,
      'Steuerbescheide und Belege mindestens 4 Jahre aufheben, sicherer sind 10 Jahre.'),
  Ordner('rente', 'Rente', ['rente'], null,
      'Rentenunterlagen dauerhaft aufheben. Sie werden für deinen Rentenantrag gebraucht.'),
  Ordner('familie', 'Familie & Kinder', ['familienkasse'], null,
      'Aufheben, solange du die Leistung bekommst, danach noch 4 Jahre.'),
  Ordner('arbeit', 'Arbeit & Soziales', ['jobcenter', 'arbeitsagentur'], 4,
      'Bescheide mindestens 4 Jahre aufheben, falls Geld zurückgefordert wird.'),
  Ordner('gesundheit', 'Gesundheit', ['krankenkasse'], 4,
      'Schreiben der Krankenkasse mindestens 4 Jahre aufheben.'),
  Ordner('wohnen', 'Wohnen & Energie', ['vermieter', 'energie', 'rundfunk'], 3,
      'Abrechnungen mindestens 3 Jahre aufheben, so lange können Forderungen gestellt werden.'),
  Ordner('vertraege', 'Verträge & Versicherungen', ['versicherung', 'telefon'], null,
      'Aufheben, solange der Vertrag läuft, danach noch 3 Jahre.'),
  Ordner('geld', 'Geld & Forderungen', ['bank', 'inkasso'], 3,
      'Mindestens 3 Jahre aufheben, so lange können Forderungen gestellt werden.'),
  Ordner('recht', 'Recht & Behörden', ['gericht', 'bussgeld', 'stadt'], null,
      'Gerichtliche und behördliche Schreiben am besten dauerhaft aufheben.'),
  Ordner('sonstiges', 'Sonstiges', ['sonstiges'], 3, 'Im Zweifel mindestens 3 Jahre aufheben.'),
];

Ordner ordnerFuer(Brief b) => alleOrdner.firstWhere(
      (o) => o.kategorien.contains(b.kategorie),
      orElse: () => alleOrdner.last,
    );

Ordner ordnerMitKey(String key) =>
    alleOrdner.firstWhere((o) => o.key == key, orElse: () => alleOrdner.last);

class Aufbewahrung {
  Aufbewahrung(this.bis, this.text);

  /// Ab diesem Tag darf der Brief nach Empfehlung weg; null = nicht wegwerfen.
  final DateTime? bis;
  final String text;
}

Aufbewahrung aufbewahrung(Brief b) {
  final o = ordnerFuer(b);
  final jahre = o.aufbewahrungJahre;
  if (jahre == null) return Aufbewahrung(null, o.aufbewahrungText);
  final basis = b.briefDatum ?? b.erstellt;
  return Aufbewahrung(DateTime(basis.year + jahre + 1, 1, 1), o.aufbewahrungText);
}

// ---------------------------------------------------------------- Titel

String _kurz(String s, int max) => s.length <= max ? s : '${s.substring(0, max - 1)}…';

/// Ein sprechender Titel, z. B. „Finanzamt Köln – Steuerbescheid“.
String autoTitel(Brief b) {
  final absender = b.absenderName ?? kategorieFuer(b.kategorie).name;
  final art = b.kiArt ?? typFuer(b.typ).name;
  if (absender.toLowerCase().contains(art.toLowerCase())) return _kurz(absender, 60);
  return '${_kurz(absender, 40)} – ${_kurz(art, 30)}';
}

String titelVon(Brief b) => (b.titel != null && b.titel!.trim().isNotEmpty) ? b.titel!.trim() : autoTitel(b);

// ---------------------------------------------------------------- Dringlichkeit

enum Dringlichkeit { niedrig, mittel, hoch }

const _hochTypen = {'mahnbescheid', 'mahnung', 'anhoerung'};
const _hochKategorien = {'gericht', 'inkasso'};
const _mittelTypen = {'mitwirkung', 'bescheid', 'rentenbescheid', 'erhoehung', 'rechnung', 'abrechnung'};

Dringlichkeit dringlichkeit(Brief b, {DateTime? heute}) {
  if (b.erledigt) return Dringlichkeit.niedrig;
  final jetzt = nurTag(heute ?? DateTime.now());
  var stufe = Dringlichkeit.niedrig;

  final offeneUnterlagen = b.unterlagen.any((u) => !u.erledigt);
  if (b.frist != null ||
      (b.betrag != null && !b.guthaben) ||
      _mittelTypen.contains(b.typ) ||
      offeneUnterlagen) {
    stufe = Dringlichkeit.mittel;
  }
  if (_hochTypen.contains(b.typ) || _hochKategorien.contains(b.kategorie)) {
    stufe = Dringlichkeit.hoch;
  }
  if (b.frist != null && nurTag(b.frist!).difference(jetzt).inDays <= 7) {
    stufe = Dringlichkeit.hoch;
  }
  final ki = b.kiDringlichkeit;
  if (ki != null && ki > stufe.index && ki < Dringlichkeit.values.length) {
    stufe = Dringlichkeit.values[ki];
  }
  return stufe;
}

// ---------------------------------------------------------------- Duplikate

Set<String> _woerter(String text) => RegExp(r'[a-zäöüß0-9]{3,}')
    .allMatches(text.toLowerCase())
    .map((m) => m.group(0)!)
    .toSet();

double aehnlichkeit(String a, String b) {
  final x = _woerter(a), y = _woerter(b);
  if (x.isEmpty || y.isEmpty) return 0;
  final schnitt = x.intersection(y).length;
  return schnitt / (x.length + y.length - schnitt);
}

/// Findet einen schon gespeicherten Brief, der vermutlich derselbe ist.
Brief? duplikatFinden(Brief neu, List<Brief> alle) {
  for (final b in alle) {
    if (b.id == neu.id) continue;
    final gleicheEckdaten = neu.aktenzeichen != null &&
        neu.aktenzeichen == b.aktenzeichen &&
        neu.briefDatum != null &&
        neu.briefDatum == b.briefDatum &&
        neu.betrag == b.betrag;
    if (gleicheEckdaten) return b;
    if (neu.text.length > 200 && b.text.length > 200 && aehnlichkeit(neu.text, b.text) >= 0.85) {
      return b;
    }
  }
  return null;
}

// ---------------------------------------------------------------- Vorgänge (Akten)

class Akte {
  Akte(this.schluessel, this.titel, this.briefe);

  final String schluessel;
  final String titel;

  /// Neueste zuerst.
  final List<Brief> briefe;

  Brief get neuester => briefe.first;
}

String _normal(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]'), '');

/// Briefe mit gleichem Aktenzeichen bilden einen Vorgang, sonst gleicher Absender.
String akteSchluessel(Brief b) {
  final az = b.aktenzeichen;
  if (az != null) {
    final wert = _normal(az.split(': ').last);
    if (wert.length >= 4) return 'az:$wert';
  }
  return 'abs:${b.kategorie}:${_normal(b.absenderName ?? '')}';
}

List<Akte> aktenBilden(List<Brief> briefe) {
  final gruppen = <String, List<Brief>>{};
  for (final b in briefe) {
    gruppen.putIfAbsent(akteSchluessel(b), () => []).add(b);
  }
  final akten = <Akte>[];
  gruppen.forEach((k, liste) {
    liste.sort((a, b) => (b.briefDatum ?? b.erstellt).compareTo(a.briefDatum ?? a.erstellt));
    final erster = liste.first;
    final name = erster.absenderName ?? kategorieFuer(erster.kategorie).name;
    final az = erster.aktenzeichen;
    akten.add(Akte(k, az != null && k.startsWith('az:') ? '$name · ${az.split(': ').last}' : name, liste));
  });
  akten.sort((a, b) =>
      (b.neuester.briefDatum ?? b.neuester.erstellt).compareTo(a.neuester.briefDatum ?? a.neuester.erstellt));
  return akten;
}

// ---------------------------------------------------------------- Unterlagen

const _unterlagenAusloeser = [
  'folgende unterlagen',
  'folgenden unterlagen',
  'folgende nachweise',
  'folgenden nachweise',
  'fehlende unterlagen',
  'bitte reichen sie',
  'bitte senden sie',
  'bitte übersenden sie',
  'benötigen wir noch',
  'benötigen wir von ihnen',
];

final _aufzaehlung = RegExp(r'^\s*([-•*–□☐▪●]|\d{1,2}[.)]|[a-h]\))\s+(.+)$');

/// Liest Aufzählungen nach Formulierungen wie „folgende Unterlagen“.
List<String> unterlagenFinden(String text) {
  final zeilen = text.split('\n');
  final ergebnis = <String>[];
  for (var i = 0; i < zeilen.length; i++) {
    final z = zeilen[i].toLowerCase();
    if (!_unterlagenAusloeser.any(z.contains)) continue;
    for (var j = i + 1; j < zeilen.length && j <= i + 15; j++) {
      final m = _aufzaehlung.firstMatch(zeilen[j]);
      if (m == null) {
        if (ergebnis.isNotEmpty) break;
        continue;
      }
      final punkt = m.group(2)!.trim().replaceAll(RegExp(r'[;,.]$'), '');
      if (punkt.length >= 3 && punkt.length <= 120 && !ergebnis.contains(punkt)) ergebnis.add(punkt);
    }
    if (ergebnis.isNotEmpty) break;
  }
  return ergebnis;
}
