/// Bankenliste (Name, Bankleitzahl, FinTS-Adresse) zum Suchen und Auswählen.
/// Die Daten liegen in assets/daten/banken.json als [[name, blz, url], …].
library;

import 'dart:convert';

class Bank {
  const Bank(this.name, this.blz, this.url);

  final String name;
  final String blz;
  final String url;
}

List<Bank> bankenLesen(String json) => [
      for (final z in (jsonDecode(json) as List))
        if (z is List && z.length >= 3) Bank('${z[0]}', '${z[1]}', '${z[2]}'),
    ];

/// Sucht nach Name (alle eingegebenen Wörter müssen vorkommen) oder Bankleitzahl.
/// Treffer, die mit der Eingabe beginnen, kommen zuerst.
List<Bank> bankenSuchen(List<Bank> alle, String eingabe, {int max = 40}) {
  final q = eingabe.trim().toLowerCase();
  if (q.isEmpty) return [];
  final woerter = q.split(RegExp(r'\s+'));
  final treffer = alle.where((b) {
    final n = b.name.toLowerCase();
    return woerter.every((w) => n.contains(w) || b.blz.startsWith(w));
  }).toList();
  treffer.sort((a, b) {
    final x = a.name.toLowerCase().startsWith(q) ? 0 : 1, y = b.name.toLowerCase().startsWith(q) ? 0 : 1;
    return x != y ? x - y : a.name.compareTo(b.name);
  });
  return treffer.take(max).toList();
}
