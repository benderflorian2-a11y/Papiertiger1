import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/steuer.dart';
import 'package:papiertiger/logic/steuer_hilfe.dart';

void main() {
  test('Zahlen aus Eingaben lesen', () {
    expect(zahlAusText('12,5'), 12.5);
    expect(zahlAusText('1.200'), 1200);
    expect(zahlAusText('1.234,56 €'), 1234.56);
    expect(zahlAusText('  42 000 '), 42000);
    expect(zahlAusText('abc'), isNull);
    expect(zahlAusText(''), isNull);
  });

  test('Einkommensteuer 2026: Grenzen und Stetigkeit', () {
    expect(einkommensteuer(10000), 0);
    expect(einkommensteuer(12348), 0);
    expect(einkommensteuer(17799), closeTo(1034, 2));
    expect(einkommensteuer(69878), closeTo(18213, 3));
    expect(einkommensteuer(277825), closeTo(105550, 3));
    expect(einkommensteuer(50000), closeTo(10548, 5));
    // Je mehr Einkommen, desto mehr Steuer
    expect(einkommensteuer(40001), greaterThanOrEqualTo(einkommensteuer(40000)));
  });

  test('Ersparnis und Grenzsteuersatz', () {
    expect(steuerErsparnis(50000, 1000), closeTo(einkommensteuer(50000) - einkommensteuer(49000), 0.01));
    expect(steuerErsparnis(50000, 1000), inInclusiveRange(250, 400));
    expect(steuerErsparnis(0, 500), 0);
    expect(grenzsteuersatz(100000), closeTo(42, 0.5));
    expect(grenzsteuersatz(10000), 0);
  });

  test('Handwerker, Haushaltsnahe, Spenden', () {
    expect(handwerkerErmaessigung(2000), closeTo(240, 0.01));
    expect(handwerkerErmaessigung(100000), 1200);
    expect(haushaltsnaheErmaessigung(1000), 200);
    expect(haushaltsnaheErmaessigung(50000), 4000);
    expect(spendenAbziehbar(10000, 30000), 6000);
  });

  test('Werbungskosten-Rechner: Standard 220 Tage, Komma, keine Doppelzählung', () {
    // Feld „Tage im Büro“ zeigt 220 an, auch wenn nichts gespeichert wurde – dann muss auch mit 220 gerechnet werden
    final w = werbungskostenAus(2026, {'km': '10'}, const []);
    expect(w.fahrt, closeTo(10 * 0.38 * 220, 0.01));
    // Bewusst leer gelassen heißt: 0 Tage
    expect(werbungskostenAus(2026, {'km': '10', 'arbeitstage': ''}, const []).fahrt, 0);
    // Komma-Eingabe: 12,5 km → 12 volle Kilometer
    expect(werbungskostenAus(2026, {'km': '12,5', 'arbeitstage': '100'}, const []).fahrt, closeTo(12 * 0.38 * 100, 0.01));
    expect(werbungskostenAus(2026, {'homeoffice': '300'}, const []).homeoffice, 1260);
    // Fahrtkosten-Belege werden nicht zusätzlich zur Entfernungspauschale gezählt
    final posten = [
      SteuerPosten(DateTime(2026, 3, 1), 'Tankstelle', 'Fahrtkosten', 80),
      SteuerPosten(DateTime(2026, 3, 2), 'Laptop', 'Arbeitsmittel', 500),
    ];
    expect(werbungskostenAus(2026, {}, posten).weitere, 500);
  });

  test('Tipps: Pauschbetrag und Handwerker', () {
    final w = Werbungskosten(fahrt: 1500, homeoffice: 0, weitere: 0);
    final t = steuerTipps(zvE: 40000, werbung: w, summen: {'Handwerkerleistungen': 2000}, selbststaendig: false);
    expect(t.any((x) => x.titel == 'Einzeln angeben lohnt sich' && (x.ersparnis ?? 0) > 0), isTrue);
    expect(t.any((x) => x.titel == 'Handwerkerleistungen' && x.ersparnis == handwerkerErmaessigung(2000)), isTrue);
    final s = steuerTipps(zvE: 40000, werbung: Werbungskosten(fahrt: 0, homeoffice: 0, weitere: 0), summen: {}, selbststaendig: true);
    expect(s.any((x) => x.titel == 'Steuern zurücklegen'), isTrue);
  });

  test('Katalog ist gefüllt', () {
    expect(absetzenPrivat.length, greaterThanOrEqualTo(8));
    expect(absetzenGewerbe.length, greaterThanOrEqualTo(5));
    expect(absetzenPrivat.every((p) => p.titel.isNotEmpty && p.kurz.isNotEmpty && p.details.isNotEmpty), isTrue);
  });
}
