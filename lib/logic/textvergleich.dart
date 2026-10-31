/// Zwei Fassungen eines Textes satzweise vergleichen (z. B. alte und neue Vertragsbedingungen).
library;

enum Aenderung { gleich, entfernt, neu }

/// Abkürzungen, nach denen kein neuer Satz beginnt.
final _abkuerzung = RegExp(r'(?:^|\s)(?:Nr|MwSt|USt|z\.\s?B|ca|bzw|ggf|inkl|zzgl|Str|Abs|Art|Tel|Hr|Fr|Dr|vgl|evtl|u\.\s?a|d\.\s?h|bspw|max|min|Std|Mo|Di|Mi|Do|Fr|Sa|So)\.$');

List<String> _saetze(String t) {
  final out = <String>[];
  for (final zeile in t.replaceAll('\r', '').split(RegExp(r'\n+'))) {
    var rest = '';
    for (final teil in zeile.split(RegExp(r'(?<=[.!?;])\s+(?=[A-ZÄÖÜ§(])'))) {
      rest = rest.isEmpty ? teil : '$rest $teil';
      if (!_abkuerzung.hasMatch(rest.trim())) {
        out.add(rest);
        rest = '';
      }
    }
    if (rest.isNotEmpty) out.add(rest);
  }
  return out.map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim()).where((s) => s.length > 1).toList();
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-zäöüß0-9]'), '');

/// Satzweise Unterschiede in Reihenfolge; gleiche Sätze bleiben mit [Aenderung.gleich] drin.
List<(Aenderung, String)> textUnterschiede(String alt, String neu, {int max = 600}) {
  final a = _saetze(alt).take(max).toList(), b = _saetze(neu).take(max).toList();
  final na = a.map(_norm).toList(), nb = b.map(_norm).toList();
  // Längste gemeinsame Teilfolge
  final l = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      l[i][j] = na[i] == nb[j] ? l[i + 1][j + 1] + 1 : (l[i + 1][j] >= l[i][j + 1] ? l[i + 1][j] : l[i][j + 1]);
    }
  }
  final out = <(Aenderung, String)>[];
  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (na[i] == nb[j]) {
      out.add((Aenderung.gleich, b[j]));
      i++;
      j++;
    } else if (l[i + 1][j] >= l[i][j + 1]) {
      out.add((Aenderung.entfernt, a[i++]));
    } else {
      out.add((Aenderung.neu, b[j++]));
    }
  }
  while (i < a.length) {
    out.add((Aenderung.entfernt, a[i++]));
  }
  while (j < b.length) {
    out.add((Aenderung.neu, b[j++]));
  }
  return out;
}

/// Beträge, Prozente und Daten, die in einer geänderten Stelle vorkommen – das sind meist die wichtigen.
bool enthaeltWerte(String s) => RegExp(r'\d+,\d{2}|\d+\s?%|\d{1,2}\.\d{1,2}\.\d{2,4}|€|euro', caseSensitive: false).hasMatch(s);
