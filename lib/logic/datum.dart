/// Datums-Helfer ohne Flutter-Abhängigkeit.
library;

DateTime nurTag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Addiert Monate und bleibt im richtigen Monat (31. Jan + 1 Monat = 28./29. Feb).
DateTime plusMonate(DateTime d, int monate) {
  final ziel = DateTime(d.year, d.month + monate, 1);
  final letzterTag = DateTime(ziel.year, ziel.month + 1, 0).day;
  final tag = d.day > letzterTag ? letzterTag : d.day;
  return DateTime(ziel.year, ziel.month, tag);
}
