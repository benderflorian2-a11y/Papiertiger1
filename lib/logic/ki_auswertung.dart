/// Baut die Anfrage an die KI und liest ihre Antwort aus.
/// Reines Dart ohne Plugins, damit es testbar ist.
library;

import '../data/models.dart';
import 'brief_analyse.dart';

/// Höchstens so viele Zeichen Brieftext gehen an die KI (passt ins Kontextfenster).
const kiMaxZeichen = 9000;

String kiAnfrage(String brieftext) {
  var text = brieftext.trim();
  if (text.length > kiMaxZeichen) text = text.substring(0, kiMaxZeichen);
  return '''
Du bist der Papiertiger, ein Helfer, der Briefe von Ämtern, Versicherungen, Vermietern und Firmen in einfacher Sprache erklärt.

Lies den folgenden Brief vollständig. Der Text stammt aus einer automatischen Texterkennung und kann kleine Fehler enthalten.

Regeln:
- Schreibe auf Deutsch, in kurzen, einfachen Sätzen, ohne Amtsdeutsch. Sprich den Leser mit „du“ an.
- Erfinde nichts. Schreibe nur, was wirklich im Brief steht.
- Übernimm Beträge und Daten genau so, wie sie im Brief stehen.

Antworte GENAU in diesem Format und mit nichts anderem:

ABSENDER: <wer schreibt>
ART: <Art des Briefs in 1 bis 3 Wörtern, z. B. Rechnung, Mahnung, Steuerbescheid, Renteninformation, Vertragsänderung, Information>
KURZFASSUNG: <3 bis 5 Sätze: Worum geht es? Was ist das Wichtigste?>
BEDEUTUNG:
- <Was heißt das konkret für dich? 2 bis 4 Punkte>
ZU TUN:
- <Was musst du tun? Wenn nichts zu tun ist, schreibe genau: - Nichts>
GELD: <ZAHLEN Betrag | BEKOMMEN Betrag | KEINS>
FRIST: <TT.MM.JJJJ | KEINE>
DRINGLICHKEIT: <HOCH | MITTEL | NIEDRIG>
UNTERLAGEN:
- <Unterlagen oder Nachweise, die der Absender verlangt. Wenn keine verlangt werden, schreibe genau: - Keine>
FÜR: <Name der Person, an die der Brief gerichtet ist, oder UNBEKANNT>

Zu DRINGLICHKEIT: HOCH bei Mahnung, Inkasso, Gericht, drohenden Kosten oder einer Frist in den nächsten 7 Tagen. MITTEL, wenn etwas zu tun oder zu zahlen ist. NIEDRIG bei reinen Informationen.
Zu GELD: Schreibe ZAHLEN nur, wenn der Leser wirklich Geld überweisen oder bezahlen soll. Schreibe BEKOMMEN, wenn er Geld erhält, zum Beispiel eine Erstattung, ein Guthaben, eine Rente oder eine Leistung. Beträge, die nur informieren, zum Beispiel eine voraussichtliche spätere Rente, ein Kontostand oder ein Jahreseinkommen, sind KEINS.
Zu FRIST: Nur ein Datum, bis zu dem der Leser etwas tun muss. Kein Briefdatum und kein Zeitraum.

Brief:
"""
$text
"""
''';
}

enum Geldrichtung { zahlen, bekommen, keins, unbekannt }

class KiErgebnis {
  KiErgebnis({
    this.absender,
    this.art,
    this.kurzfassung = '',
    this.bedeutung = const [],
    this.zuTun = const [],
    this.geld = Geldrichtung.unbekannt,
    this.betrag,
    this.frist,
    this.keineFrist = false,
    this.dringlichkeit,
    this.unterlagen = const [],
    this.fuer,
  });

  final String? absender;
  final String? art;
  final String kurzfassung;
  final List<String> bedeutung;
  final List<String> zuTun;
  final Geldrichtung geld;
  final double? betrag;
  final DateTime? frist;
  final bool keineFrist;

  /// 0 niedrig, 1 mittel, 2 hoch.
  final int? dringlichkeit;
  final List<String> unterlagen;
  final String? fuer;

  bool get brauchbar => kurzfassung.length >= 20;
}

String _sauber(String s) => s
    .replaceAll('**', '')
    .replaceAll('__', '')
    .replaceAll(RegExp(r'^[\s>#*]+'), '')
    .trim();

final _kopf = RegExp(
    r'^(absender|art|kurzfassung|bedeutung|zu tun|geld|frist|dringlichkeit|unterlagen|für|fuer)\s*:\s*(.*)$',
    caseSensitive: false,
    unicode: true);

/// Liest die Antwort der KI. Ist robust gegen Markdown und kleine Formatfehler.
KiErgebnis kiAntwortLesen(String antwort) {
  final felder = <String, List<String>>{};
  String? aktuell;
  for (final roh in antwort.split('\n')) {
    final zeile = _sauber(roh);
    if (zeile.isEmpty) continue;
    final m = _kopf.firstMatch(zeile);
    if (m != null) {
      aktuell = m.group(1)!.toLowerCase();
      if (aktuell == 'fuer') aktuell = 'für';
      felder[aktuell] = [];
      final rest = m.group(2)!.trim();
      if (rest.isNotEmpty) felder[aktuell]!.add(rest);
    } else if (aktuell != null) {
      felder[aktuell]!.add(zeile);
    }
  }

  String? eins(String k) {
    final l = felder[k];
    if (l == null || l.isEmpty) return null;
    final t = l.join(' ').trim();
    return t.isEmpty ? null : t;
  }

  List<String> punkte(String k) {
    final l = felder[k] ?? [];
    final out = <String>[];
    for (final z in l) {
      final t = z.replaceFirst(RegExp(r'^([-•*–]|\d+[.)])\s*'), '').trim();
      if (t.isEmpty) continue;
      if (RegExp(r'^(nichts|keine?s?)\.?$', caseSensitive: false).hasMatch(t)) continue;
      out.add(t);
    }
    return out;
  }

  var geld = Geldrichtung.unbekannt;
  double? betrag;
  final g = eins('geld');
  if (g != null) {
    final gl = g.toLowerCase();
    if (gl.startsWith('zahlen')) {
      geld = Geldrichtung.zahlen;
    } else if (gl.startsWith('bekommen')) {
      geld = Geldrichtung.bekommen;
    } else if (gl.startsWith('kein')) {
      geld = Geldrichtung.keins;
    }
    betrag = ersterBetrag(g);
  }

  DateTime? frist;
  var keineFrist = false;
  final f = eins('frist');
  if (f != null) {
    final d = datumsFunde(f);
    if (d.isNotEmpty) {
      frist = d.first.wert;
    } else if (f.toLowerCase().startsWith('kein')) {
      keineFrist = true;
    }
  }

  int? dringlichkeit;
  final dr = eins('dringlichkeit')?.toLowerCase();
  if (dr != null) {
    if (dr.startsWith('hoch')) {
      dringlichkeit = 2;
    } else if (dr.startsWith('mittel')) {
      dringlichkeit = 1;
    } else if (dr.startsWith('niedrig')) {
      dringlichkeit = 0;
    }
  }
  var fuer = eins('für');
  if (fuer != null && (fuer.toLowerCase().startsWith('unbekannt') || fuer.length > 60)) fuer = null;

  return KiErgebnis(
    dringlichkeit: dringlichkeit,
    unterlagen: punkte('unterlagen'),
    fuer: fuer,
    absender: eins('absender'),
    art: eins('art'),
    kurzfassung: eins('kurzfassung') ?? '',
    bedeutung: punkte('bedeutung'),
    zuTun: punkte('zu tun'),
    geld: geld,
    betrag: betrag,
    frist: frist,
    keineFrist: keineFrist,
  );
}

final _zahlRe = RegExp(r'(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?');

double? ersterBetrag(String s) {
  final m = _zahlRe.firstMatch(s);
  if (m == null) return null;
  final ganz = m.group(1)!.replaceAll('.', '');
  final cent = (m.group(2) ?? '0').padRight(2, '0');
  return double.tryParse('$ganz.$cent');
}

/// Alle Geldbeträge im Text, mit und ohne Cent.
Set<int> _centImText(String text) {
  final out = <int>{};
  for (final m in _zahlRe.allMatches(text)) {
    final ganz = m.group(1)!.replaceAll('.', '');
    final cent = (m.group(2) ?? '0').padRight(2, '0');
    final w = int.tryParse(ganz);
    final c = int.tryParse(cent);
    if (w != null && c != null) out.add(w * 100 + c);
  }
  return out;
}

bool _datumImText(String text, DateTime d) =>
    datumsFunde(text).any((f) => f.wert.year == d.year && f.wert.month == d.month && f.wert.day == d.day);

/// Übernimmt das KI-Ergebnis in den Brief. Zahlen und Daten nur,
/// wenn sie wirklich im Brieftext stehen.
void kiUebernehmen(Brief b, KiErgebnis k) {
  if (!k.brauchbar) return;
  b.erklaerung = k.kurzfassung;
  if (k.bedeutung.isNotEmpty) b.bedeutung = k.bedeutung;
  if (k.art != null && k.art!.length <= 40) b.kiArt = k.art;
  if ((b.absenderName == null || b.kategorie == 'sonstiges') &&
      k.absender != null &&
      k.absender!.length <= 70) {
    b.absenderName = k.absender;
  }

  // Geld
  final betragBelegt = k.betrag != null && _centImText(b.text).contains((k.betrag! * 100).round());
  switch (k.geld) {
    case Geldrichtung.zahlen:
      if (betragBelegt) b.betrag = k.betrag;
      b.guthaben = false;
    case Geldrichtung.bekommen:
      if (betragBelegt) b.betrag = k.betrag;
      b.guthaben = true;
    case Geldrichtung.keins:
      b.betrag = null;
      b.guthaben = false;
    case Geldrichtung.unbekannt:
      break;
  }

  // Frist
  if (k.frist != null && _datumImText(b.text, k.frist!)) {
    b.frist = k.frist;
    b.fristUnsicher = false;
  } else if (k.keineFrist && b.fristUnsicher) {
    b.frist = null;
    b.fristUnsicher = false;
  }

  // Aufgaben: die der KI ersetzen die automatisch erzeugten, erledigte bleiben.
  final erledigt = b.aufgaben.where((a) => a.erledigt).toList();
  final neu = <Aufgabe>[...erledigt];
  for (final t in k.zuTun) {
    if (!neu.any((a) => a.text == t)) neu.add(Aufgabe(t));
  }
  if (k.zuTun.isEmpty && erledigt.isEmpty) neu.add(Aufgabe('Brief aufbewahren'));
  b.aufgaben = neu;

  if (k.dringlichkeit != null) b.kiDringlichkeit = k.dringlichkeit;
  if (k.fuer != null) b.person = k.fuer;
  for (final u in k.unterlagen) {
    if (!b.unterlagen.any((x) => x.text.toLowerCase() == u.toLowerCase())) b.unterlagen.add(Aufgabe(u));
  }
  b.kiFertig = true;
}
