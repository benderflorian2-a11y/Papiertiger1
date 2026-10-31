/// Passende Stellen in einem langen Dokument finden – ohne KI, über gemeinsame Wörter.
library;

const _fuellwoerter = {
  'der', 'die', 'das', 'den', 'dem', 'des', 'ein', 'eine', 'einen', 'einem', 'einer', 'und', 'oder', 'ist', 'sind',
  'wie', 'was', 'wo', 'wann', 'warum', 'wer', 'kann', 'ich', 'mein', 'meine', 'mit', 'für', 'von', 'zu', 'zum', 'zur',
  'im', 'in', 'an', 'am', 'auf', 'bei', 'es', 'man', 'muss', 'soll', 'wird', 'werden', 'nicht', 'auch', 'sich', 'mir', 'mich',
};

List<String> _woerter(String s) => RegExp(r'[a-zäöüß0-9]{3,}')
    .allMatches(s.toLowerCase())
    .map((m) => m.group(0)!)
    .where((w) => !_fuellwoerter.contains(w))
    .toList();

bool _passt(String wort, String suchwort) {
  if (wort == suchwort) return true;
  // einfache Wortstämme: „entkalken“ findet „Entkalkung“, „Filter“ findet „Filters“
  final n = suchwort.length >= 6 ? suchwort.length - 2 : suchwort.length;
  return wort.length >= n && suchwort.length >= 4 && wort.startsWith(suchwort.substring(0, n));
}

/// Die besten Absätze zur Frage, bestes zuerst.
List<String> textstellenFinden(String text, String frage, {int max = 3}) {
  final such = _woerter(frage).toSet();
  if (such.isEmpty) return [];
  var absaetze = text.split(RegExp(r'\n\s*\n')).map((a) => a.trim()).where((a) => a.length > 15).toList();
  // Ohne Leerzeilen: in Blöcke zu 4 Zeilen teilen
  if (absaetze.length <= 1) {
    final zeilen = text.split('\n').where((z) => z.trim().isNotEmpty).toList();
    absaetze = [for (var i = 0; i < zeilen.length; i += 4) zeilen.sublist(i, (i + 4).clamp(0, zeilen.length)).join('\n')];
  }
  final bewertet = <(String, int)>[];
  for (final a in absaetze) {
    final w = _woerter(a);
    final treffer = such.where((s) => w.any((x) => _passt(x, s))).length;
    if (treffer > 0) bewertet.add((a, treffer));
  }
  bewertet.sort((a, b) => b.$2.compareTo(a.$2));
  return bewertet.take(max).map((e) => e.$1.length > 700 ? '${e.$1.substring(0, 700)} …' : e.$1).toList();
}
