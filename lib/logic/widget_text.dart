/// Text für das Startbildschirm-Widget. Reines Dart, testbar.
library;

import 'zeitplan.dart';

String _d(DateTime d, DateTime heute) {
  final t = DateTime(d.year, d.month, d.day).difference(DateTime(heute.year, heute.month, heute.day)).inDays;
  if (t < 0) return 'überfällig';
  if (t == 0) return 'heute';
  if (t == 1) return 'morgen';
  if (t < 7) return 'in $t Tagen';
  return '${d.day}.${d.month}.';
}

/// (Titel, Text): die nächsten drei Fälligkeiten und offene Zahlungen.
(String, String) widgetTexte(List<Faelligkeit> f, {required int offeneZahlungen, required String summe, required DateTime heute}) {
  final naechste = f.take(3).toList();
  final titel = naechste.isEmpty ? 'Papiertiger' : 'Als Nächstes: ${_d(naechste.first.datum, heute)}';
  final zeilen = [
    for (final x in naechste) '• ${_d(x.datum, heute)}: ${x.titel}',
    if (offeneZahlungen > 0) '€ $offeneZahlungen offen: $summe',
  ];
  return (titel, zeilen.isEmpty ? 'Nichts offen. Der Tiger schläft entspannt.' : zeilen.join('\n'));
}
