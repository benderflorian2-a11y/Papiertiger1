/// Gemeinsame Zahlenformate.
library;

/// 1234.5 → „1.234,50 €“
String euroBetrag(double b) {
  final t = b.abs().toStringAsFixed(2).split('.');
  final ganz = t[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '${b < 0 ? '-' : ''}$ganz,${t[1]} €';
}
