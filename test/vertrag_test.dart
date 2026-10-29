import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/vertrag_logik.dart';
import 'package:papiertiger/logic/zeitplan.dart';

const _police = '''
Allianz Versicherungs-AG
Versicherungsschein Privathaftpflichtversicherung
Versicherungsnummer: AS-123456789
Versicherungsbeginn: 01.11.2026
Vertragslaufzeit: 1 Jahr, verlängert sich jeweils um ein Jahr
Kündigungsfrist: 3 Monate zum Ablauf
Jahresbeitrag: 65,40 €
''';

const _handy = '''
Vodafone GmbH
Ihre Vertragsbestätigung
Kundennummer: 123456789
Tarif: Red M
Mindestlaufzeit 24 Monate
Grundgebühr monatlich 39,99 €
Die Kündigungsfrist beträgt 1 Monat zum Ende der Mindestlaufzeit.
''';

Brief _brief(String id, String text, String absender) => Brief(
    id: id,
    erstellt: DateTime(2026, 10, 1),
    kategorie: 'versicherung',
    typ: 'schreiben',
    text: text,
    erklaerung: '',
    absenderName: absender);

void main() {
  test('Versicherungsschein wird gelesen', () {
    final v = vertragAusText(_police);
    expect(v.art, 'Versicherung');
    expect(v.versicherungsArt, 'Privathaftpflicht');
    expect(v.nummer, 'AS-123456789');
    expect(v.beginn, DateTime(2026, 11, 1));
    expect(v.laufzeitMonate, 12);
    expect(v.fristWert, 3);
    expect(v.fristInWochen, isFalse);
    expect(v.zahlweiseMonate, 12);
    expect(v.kostenMonat, closeTo(5.45, 0.001));
    final vertrag = v.alsVertrag(id: 'x', anbieter: 'Allianz');
    expect(vertrag.betragProZahlung, closeTo(65.40, 0.001));
  });

  test('Handyvertrag wird gelesen', () {
    final v = vertragAusText(_handy);
    expect(v.art, 'Handy');
    expect(v.versicherungsArt, isNull);
    expect(v.nummer, '123456789');
    expect(v.laufzeitMonate, 24);
    expect(v.fristWert, 1);
    expect(v.zahlweiseMonate, 1);
    expect(v.kostenMonat, closeTo(39.99, 0.001));
    expect(vertragAusText('Der Vertrag ist monatlich kündbar.').laufzeitMonate, 0);
    expect(vertragAusText('Vielen Dank für Ihren Einkauf.').gefunden, isFalse);
  });

  test('Preiserhöhung erkennen', () {
    final p = preisaenderungFinden(
        'Wir passen unsere Preise an: Ihre Grundgebühr erhöht sich ab dem 01.01.2027 von 39,99 € auf 44,99 €.')!;
    expect(p.ab, DateTime(2027, 1, 1));
    expect(p.alt, 39.99);
    expect(p.neu, 44.99);
    expect(preisaenderungFinden(_handy), isNull);
  });

  test('Brief wird dem richtigen Vertrag zugeordnet', () {
    final handy = Vertrag(id: 'h', anbieter: 'Vodafone', art: 'Handy', beginn: DateTime(2025, 1, 1), nummer: '123456789');
    final haft = Vertrag(id: 'a', anbieter: 'Allianz', art: 'Versicherung', beginn: DateTime(2025, 1, 1));
    expect(vertragZuBrief(_brief('1', 'Kundennummer 123 456 789', 'Unbekannt'), [haft, handy]), handy);
    expect(vertragZuBrief(_brief('2', 'Beitragsrechnung', 'Allianz Versicherungs-AG'), [handy, haft]), haft);
    expect(vertragZuBrief(_brief('3', 'Hallo', 'Stadtwerke'), [handy, haft]), isNull);
    haft.briefIds.add('3');
    expect(vertragZuBrief(_brief('3', 'Hallo', 'Stadtwerke'), [handy, haft]), haft);
  });

  test('Kosten, Kündigungsbestätigung, Widerruf', () {
    final a = Vertrag(id: 'a', anbieter: 'A', art: 'Handy', beginn: DateTime(2026, 10, 20), kostenMonat: 39.99);
    final b = Vertrag(
        id: 'b', anbieter: 'B', art: 'Versicherung', beginn: DateTime(2026, 9, 1), kostenMonat: 5.45, zahlweiseMonate: 12);
    final c = Vertrag(
        id: 'c',
        anbieter: 'C',
        art: 'Fitnessstudio',
        beginn: DateTime(2024, 1, 1),
        kostenMonat: 30,
        gekuendigt: true,
        gekuendigtAm: DateTime(2026, 10, 1));
    final k = kostenUebersicht([a, b, c]);
    expect(k.monat, closeTo(45.44, 0.001));
    expect(k.jahr, closeTo(545.28, 0.001));
    expect(k.nachArt.first.$1, 'Handy');

    expect(bestaetigungPruefenAb(c), DateTime(2026, 10, 15));
    expect(bestaetigungPruefenAb(a), isNull);
    final f = faelligkeiten(
        briefe: const [], vertraege: [c], belege: const [], termine: const [], heute: DateTime(2026, 10, 28));
    expect(f.single.text, contains('Kündigungsbestätigung'));
    c.bestaetigt = true;
    expect(bestaetigungPruefenAb(c), isNull);

    expect(widerrufBis(a, heute: DateTime(2026, 10, 28)), DateTime(2026, 11, 3));
    expect(widerrufBis(b, heute: DateTime(2026, 10, 28)), isNull);

    final kopie = Vertrag.fromJson(c.toJson());
    expect(kopie.gekuendigtAm, DateTime(2026, 10, 1));
    expect(kopie.bestaetigt, isTrue);
  });

  test('Tarifvergleich über 24 Monate', () {
    final e = tarifeVergleichen([
      Tarif(name: 'A', monat: 30, einmalig: 40),
      Tarif(name: 'B', monat: 25, einmalig: 70, bonus: 50),
      Tarif(name: 'C', monat: 28),
    ]);
    expect(e.map((x) => x.tarif.name), ['B', 'C', 'A']);
    expect(e.first.gesamt, 620);
    expect(e.first.effektivMonat, closeTo(25.83, 0.001));
  });

  test('Schadensmeldung und Anbieterwechsel', () {
    final hausrat = schadenUnterlagen('Hausrat');
    expect(hausrat.first, contains('Polizeiliche Anzeige'));
    expect(hausrat, contains('Fotos vom Schaden (Übersicht und Nahaufnahmen)'));
    expect(schadenUnterlagen(null).length, 6);
    final strom = Vertrag(id: 's', anbieter: 'E.ON', art: 'Strom', beginn: DateTime(2024, 1, 1), laufzeitMonate: 12);
    final schritte = wechselSchritte(strom, heute: DateTime(2026, 10, 28));
    expect(schritte.any((s) => s.contains('kündigt meist für dich')), isTrue);
    expect(schritte.any((s) => s.contains('Zählerstand')), isTrue);
    final handy = Vertrag(id: 'h', anbieter: 'O2', art: 'Handy', beginn: DateTime(2026, 1, 1));
    expect(wechselSchritte(handy, heute: DateTime(2026, 10, 28)).any((s) => s.contains('Rufnummer')), isTrue);
  });

  test('Probeabo und Rückgabefrist erscheinen als Fälligkeit', () {
    final heute = DateTime(2026, 10, 28);
    final v = Vertrag(id: 'p', anbieter: 'Streamingdienst', art: 'Streaming', beginn: DateTime(2026, 10, 1), laufzeitMonate: 0, probeBis: DateTime(2026, 11, 1));
    final b = Beleg(id: 'b', haendler: 'Onlineshop', datum: DateTime(2026, 10, 20), garantieMonate: 0, rueckgabeBis: DateTime(2026, 11, 3));
    final f = faelligkeiten(briefe: const [], vertraege: [v], belege: [b], termine: const [], heute: heute);
    expect(f.any((x) => x.text.startsWith('Probezeit endet')), isTrue);
    expect(f.any((x) => x.text.startsWith('Rückgabe noch möglich')), isTrue);
    expect(Vertrag.fromJson(v.toJson()).probeBis, DateTime(2026, 11, 1));
    expect(Beleg.fromJson(b.toJson()).rueckgabeBis, DateTime(2026, 11, 3));
  });
}

