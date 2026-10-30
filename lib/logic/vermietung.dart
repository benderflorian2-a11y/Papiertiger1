/// Vermietung: Nebenkostenabrechnung, Mieterhöhung, Mieteingänge. Allgemeine Hinweise, keine Rechtsberatung.
library;

import '../data/vermietung.dart';
import 'kontoauszug.dart';

double _rund(double x) => (x * 100).round() / 100;
String _e(double b) => '${b.toStringAsFixed(2).replaceAll('.', ',')} €';
String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Tage, die der Mieter im Jahr in der Wohnung war.
int bewohnteTage(Mieter m, int jahr) {
  final start = DateTime.utc(jahr, 1, 1), ende = DateTime.utc(jahr, 12, 31);
  final von = m.einzug == null ? start : DateTime.utc(m.einzug!.year, m.einzug!.month, m.einzug!.day);
  final bis = m.auszug == null ? ende : DateTime.utc(m.auszug!.year, m.auszug!.month, m.auszug!.day);
  final a = von.isAfter(start) ? von : start;
  final b = bis.isBefore(ende) ? bis : ende;
  if (b.isBefore(a)) return 0;
  return b.difference(a).inDays + 1;
}

int _tageImJahr(int jahr) => DateTime.utc(jahr + 1, 1, 1).difference(DateTime.utc(jahr, 1, 1)).inDays;

class Abrechnungszeile {
  Abrechnungszeile(this.art, this.gesamt, this.schluessel, this.anteil);
  final String art;
  final double gesamt;
  final String schluessel;
  final double anteil;
}

class NebenkostenErgebnis {
  NebenkostenErgebnis({required this.zeilen, required this.vorauszahlungen, required this.tage, required this.tageImJahr});

  final List<Abrechnungszeile> zeilen;
  final double vorauszahlungen;
  final int tage;
  final int tageImJahr;

  double get kosten => _rund(zeilen.fold(0.0, (s, z) => s + z.anteil));

  /// Positiv = Nachzahlung, negativ = Guthaben.
  double get saldo => _rund(kosten - vorauszahlungen);
}

/// Anteil des Mieters an den Nebenkosten eines Jahres (zeitanteilig bei Ein- oder Auszug).
NebenkostenErgebnis nebenkostenFuer(Mieter m, Nebenkostenjahr j, Mietobjekt o) {
  final tage = bewohnteTage(m, j.jahr);
  final tageJahr = _tageImJahr(j.jahr);
  final zeit = tage / tageJahr;
  final zeilen = <Abrechnungszeile>[];
  for (final p in j.posten) {
    final quote = switch (p.schluessel) {
      'personen' => j.gesamtpersonen <= 0 ? 0.0 : m.personen / j.gesamtpersonen,
      'einheiten' => o.einheiten <= 0 ? 0.0 : 1 / o.einheiten,
      _ => o.gesamtflaeche <= 0 ? 0.0 : m.flaeche / o.gesamtflaeche,
    };
    zeilen.add(Abrechnungszeile(p.art, p.betrag, p.schluessel, _rund(p.betrag * quote * zeit)));
  }
  // Vorauszahlungen: volle Monate im Jahr, in denen gewohnt wurde (vereinfacht: anteilig nach Tagen)
  final voraus = _rund(m.nebenkosten * 12 * zeit);
  return NebenkostenErgebnis(zeilen: zeilen, vorauszahlungen: voraus, tage: tage, tageImJahr: tageJahr);
}

/// Bis wann die Abrechnung beim Mieter sein muss (§ 556 Abs. 3 BGB: 12 Monate nach Ende des Zeitraums).
DateTime abrechnungsfrist(int jahr) => DateTime(jahr + 1, 12, 31);

String abrechnungText(Mieter m, Nebenkostenjahr j, Mietobjekt o, NebenkostenErgebnis r, {required String vermieter, required String adresse}) {
  final z = StringBuffer('$vermieter\n$adresse\n\n${m.name}\n${o.adresse}${m.wohnung.isEmpty ? '' : ', ${m.wohnung}'}\n\n'
      '[Ort], ${_d(DateTime.now())}\n\nBetreff: Betriebskostenabrechnung ${j.jahr}\n\n'
      'Sehr geehrte${m.name.contains('Herr') ? 'r' : ''} ${m.name},\n\n'
      'anbei erhalten Sie die Abrechnung der Betriebskosten für den Zeitraum 01.01.${j.jahr} bis 31.12.${j.jahr}'
      '${r.tage < r.tageImJahr ? ' (anteilig für ${r.tage} von ${r.tageImJahr} Tagen)' : ''}.\n\n');
  z.write('Gesamtfläche ${o.gesamtflaeche.toStringAsFixed(1).replaceAll('.', ',')} m², Ihre Fläche ${m.flaeche.toStringAsFixed(1).replaceAll('.', ',')} m²'
      '${j.gesamtpersonen > 0 ? ', Personen im Haus ${j.gesamtpersonen}, in Ihrer Wohnung ${m.personen}' : ''}, Wohnungen ${o.einheiten}.\n\n');
  for (final x in r.zeilen) {
    z.write('- ${x.art}: Gesamtkosten ${_e(x.gesamt)}, ${umlageSchluessel[x.schluessel] ?? x.schluessel} → Ihr Anteil ${_e(x.anteil)}\n');
  }
  z.write('\nIhre Kosten gesamt: ${_e(r.kosten)}\nIhre Vorauszahlungen: ${_e(r.vorauszahlungen)}\n');
  z.write(r.saldo >= 0
      ? 'Nachzahlung: ${_e(r.saldo)} – bitte überweisen Sie den Betrag innerhalb von 30 Tagen.\n'
      : 'Guthaben: ${_e(-r.saldo)} – ich überweise Ihnen den Betrag in den nächsten Tagen.\n');
  z.write('\nDie Belege können Sie nach Absprache bei mir einsehen.\n\nMit freundlichen Grüßen\n\n$vermieter');
  return z.toString();
}

/// Mieterhöhung bis zur ortsüblichen Vergleichsmiete (§ 558 BGB), vereinfacht.
/// Liefert (Verlangen frühestens am, wirksam frühestens ab, Hinweis).
(DateTime, DateTime, String) mieterhoehungMoeglich(Mieter m) {
  final basis = m.letzteErhoehung ?? m.einzug ?? DateTime.now();
  final verlangen = DateTime(basis.year + 1, basis.month, basis.day);
  final wirksam = DateTime(basis.year, basis.month + 15, basis.day);
  final max20 = _rund(m.kaltmiete * 1.2);
  return (
    verlangen,
    wirksam,
    'Höchstens bis zur ortsüblichen Vergleichsmiete (Mietspiegel) und in 3 Jahren um höchstens 20 % '
        '(in vielen Städten 15 %) – bei ${_e(m.kaltmiete)} also höchstens ${_e(max20)} kalt. '
        'Der Mieter muss zustimmen; er hat dafür bis zum Ende des übernächsten Monats Zeit.'
  );
}

/// Mieteingänge eines Monats: welcher Mieter hat (laut Kontoauszug) gezahlt?
List<(Mieter, Gutschrift?)> mieteingaenge(List<Mieter> mieter, List<Gutschrift> eingaenge, {required int jahr, required int monat}) {
  final frei = eingaenge.where((g) => g.datum.year == jahr && g.datum.month == monat).toList();
  final out = <(Mieter, Gutschrift?)>[];
  for (final m in mieter.where((m) => m.auszug == null || !m.auszug!.isBefore(DateTime(jahr, monat)))) {
    final nachname = m.name.split(' ').last.toLowerCase();
    final g = frei.where((g) => '${g.von} ${g.text}'.toLowerCase().contains(nachname) && (g.betrag - m.warmmiete).abs() < 0.01).firstOrNull ??
        frei.where((g) => (g.betrag - m.warmmiete).abs() < 0.01 && '${g.von} ${g.text}'.toLowerCase().contains('miete')).firstOrNull;
    if (g != null) frei.remove(g);
    out.add((m, g));
  }
  return out;
}
