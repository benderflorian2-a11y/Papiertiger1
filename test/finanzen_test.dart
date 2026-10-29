import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/finanzen.dart';

Brief _b(String id, {double? betrag, bool guthaben = false, DateTime? frist, List<String> aufgaben = const []}) => Brief(
      id: id,
      erstellt: DateTime(2026, 10, 1),
      kategorie: 'stadt',
      typ: 'rechnung',
      text: '',
      erklaerung: '',
      betrag: betrag,
      guthaben: guthaben,
      frist: frist,
      aufgaben: aufgaben.map(Aufgabe.new).toList(),
    );

void main() {
  test('IBAN prüfen und lesbar machen', () {
    expect(ibanGueltig('DE89 3704 0044 0532 0130 00'), isTrue);
    expect(ibanGueltig('DE89 3704 0044 0532 0130 01'), isFalse);
    expect(ibanGueltig('DE89 3704 0044 0532 0130'), isFalse);
    expect(ibanLesbar('DE89370400440532013000'), 'DE89 3704 0044 0532 0130 00');
  });

  test('Überweisungsdaten aus dem Brief', () {
    const text = 'Bitte überweisen Sie 120,00 € bis 15.11.2026 auf folgendes Konto:\n'
        'IBAN: DE89 3704 0044 0532 0130 00\nBIC: COBADEFFXXX\nVerwendungszweck: Kassenzeichen 4711-0815\n';
    final u = ueberweisungFinden(text, empfaenger: 'Stadtkasse', betrag: 120);
    expect(u.iban, 'DE89370400440532013000');
    expect(u.bic, 'COBADEFFXXX');
    expect(u.zweck, 'Kassenzeichen 4711-0815');
    expect(u.vollstaendig, isTrue);
    expect(ueberweisungFinden(text, eigeneIban: 'DE89 3704 0044 0532 0130 00').iban, isNull);
    final ohneZweck = ueberweisungFinden('Rechnungsnummer: RE-2026-001\nIBAN DE89370400440532013000');
    expect(ohneZweck.zweck, 'RE-2026-001');
    expect(ohneZweck.iban, 'DE89370400440532013000');
  });

  test('Offene Zahlungen, Gutschriften, Monatsüberblick', () {
    final a = _b('a', betrag: 50, frist: DateTime(2026, 11, 20));
    final b = _b('b', betrag: 30, frist: DateTime(2026, 11, 5));
    final c = _b('c', betrag: 99, frist: DateTime(2026, 12, 20));
    final g = _b('g', betrag: 200, guthaben: true);
    final p = _b('p', betrag: 10)..bezahltAm = DateTime(2026, 11, 2);
    final briefe = [a, b, c, g, p];
    expect(offeneZahlungen(briefe).map((x) => x.id), ['b', 'a', 'c']);
    expect(summe(erwarteteGutschriften(briefe)), 200);
    final m = monatsUeberblick(
      briefe: briefe,
      vertraege: [
        Vertrag(id: 'v', anbieter: 'X', art: 'Handy', beginn: DateTime(2025, 1, 1), kostenMonat: 20),
        Vertrag(id: 'w', anbieter: 'Y', art: 'Gas', beginn: DateTime(2025, 1, 1), kostenMonat: 70, gekuendigt: true),
      ],
      belege: [
        Beleg(id: '1', haendler: 'Markt', datum: DateTime(2026, 11, 3), betrag: 12.5),
        Beleg(id: '2', haendler: 'Markt', datum: DateTime(2026, 10, 3), betrag: 99),
      ],
      monat: DateTime(2026, 11),
    );
    expect(m.fixkosten, 20);
    expect(m.faellig, 80);
    expect(m.bezahlt, 10);
    expect(m.ausgaben, 12.5);
    expect(m.gesamt, 122.5);
  });

  test('Bezahlt vermerken hakt Zahlungs-Aufgaben ab', () {
    final nurZahlen = _b('z', betrag: 10, aufgaben: ['Betrag überweisen']);
    alsBezahltMarkieren(nurZahlen, DateTime(2026, 11, 1));
    expect(nurZahlen.erledigt, isTrue);
    final mehr = _b('m', betrag: 10, aufgaben: ['Betrag überweisen', 'Unterlagen schicken']);
    alsBezahltMarkieren(mehr, DateTime(2026, 11, 1));
    expect(mehr.aufgaben.first.erledigt, isTrue);
    expect(mehr.erledigt, isFalse);
    expect(offeneZahlungen([mehr]), isEmpty);
    bezahltZuruecknehmen(mehr);
    expect(offeneZahlungen([mehr]), [mehr]);
  });

  test('Ratenplan', () {
    final p = ratenplan(250, 100, DateTime(2026, 12, 1));
    expect(p.map((r) => r.betrag), [100, 100, 50]);
    expect(p.map((r) => r.datum), [DateTime(2026, 12, 1), DateTime(2027, 1, 1), DateTime(2027, 2, 1)]);
    expect(p.last.rest, 0);
    expect(ratenplan(100, 0, DateTime(2026, 12, 1)), isEmpty);
  });

  test('Kategorien, Budgets, Prognose', () {
    final belege = [
      Beleg(id: '1', haendler: 'REWE Markt', datum: DateTime(2026, 11, 3), betrag: 80),
      Beleg(id: '2', haendler: 'dm drogerie', datum: DateTime(2026, 11, 4), betrag: 20),
      Beleg(id: '3', haendler: 'Unbekannt', datum: DateTime(2026, 11, 5), betrag: 10, kategorie: 'Freizeit'),
      Beleg(id: '4', haendler: 'Aldi', datum: DateTime(2026, 10, 5), betrag: 90),
    ];
    expect(belegKategorie(belege[0]), 'Lebensmittel');
    expect(belegKategorie(belege[1]), 'Drogerie');
    expect(belegKategorie(belege[2]), 'Freizeit');
    final vertraege = [Vertrag(id: 'v', anbieter: 'Netflix', art: 'Streaming', beginn: DateTime(2025, 1, 1), kostenMonat: 13)];
    final k = ausgabenNachKategorie(belege: belege, vertraege: vertraege, monat: DateTime(2026, 11));
    expect(k.first, ('Lebensmittel', 80.0));
    expect(k.firstWhere((x) => x.$1 == 'Freizeit').$2, 23);
    final b = budgets({'budget:Lebensmittel': '60', 'budget:Drogerie': '50', 'anderes': 'x'}, k);
    expect(b.first.kategorie, 'Lebensmittel');
    expect(b.first.ueberschritten, isTrue);
    expect(b.last.ueberschritten, isFalse);
    // Fixkosten 13 + Belege Aug–Okt (90/3) + nichts fällig
    expect(prognoseNaechsterMonat(briefe: const [], vertraege: vertraege, belege: belege, heute: DateTime(2026, 11, 10)), 43);
  });

  test('Sparziel: Rate pro Monat', () {
    final z = Sparziel(id: 's', name: 'Urlaub', ziel: 1200, gespart: 200, bis: DateTime(2027, 6, 1));
    expect(sparrateProMonat(z, heute: DateTime(2026, 11, 1)), closeTo(142.86, 0.01));
    expect(sparrateProMonat(Sparziel(id: 'x', name: 'x', ziel: 100, gespart: 100), heute: DateTime(2026)), 0);
    expect(sparrateProMonat(Sparziel(id: 'y', name: 'y', ziel: 100), heute: DateTime(2026)), isNull);
    expect(Sparziel.fromJson(z.toJson()).bis, DateTime(2027, 6, 1));
  });

  test('Doppelte und auffällige Rechnungen, Sparpotenziale', () {
    Brief r(String id, double betrag, DateTime d, {String typ = 'rechnung'}) => Brief(
        id: id, erstellt: d, briefDatum: d, kategorie: 'energie', typ: typ, text: '', erklaerung: '', absenderName: 'Stadtwerke', betrag: betrag);
    final l = [
      r('a', 50, DateTime(2026, 1, 1)),
      r('b', 52, DateTime(2026, 4, 1)),
      r('c', 48, DateTime(2026, 7, 1)),
      r('d', 200, DateTime(2026, 9, 1)),
      r('e', 200, DateTime(2026, 9, 20)),
      r('f', 200, DateTime(2026, 9, 25), typ: 'mahnung'),
    ];
    final a = auffaelligeRechnungen(l);
    expect(a.where((x) => x.text.contains('doppelt berechnet')).single.briefIds, ['d', 'e']);
    expect(a.where((x) => x.text.contains('mehr als doppelt')).map((x) => x.briefIds.single), containsAll(['d', 'e']));

    final hinweise = sparpotenziale(
      vertraege: [
        Vertrag(id: '1', anbieter: 'Netflix', art: 'Streaming', beginn: DateTime(2025), kostenMonat: 13),
        Vertrag(id: '2', anbieter: 'Disney+', art: 'Streaming', beginn: DateTime(2025), kostenMonat: 10),
        Vertrag(id: '3', anbieter: 'HUK', art: 'Versicherung', versicherungsArt: 'Kfz', beginn: DateTime(2025), kostenMonat: 45),
      ],
      briefe: l,
      budgets: [BudgetStand('Lebensmittel', 300, 350)],
    );
    expect(hinweise.first, contains('2× Streaming (Netflix, Disney+)'));
    expect(hinweise.any((h) => h.contains('1 Mahnung')), isTrue);
    expect(hinweise.any((h) => h.contains('Budget „Lebensmittel“ überschritten')), isTrue);
    expect(hinweise.any((h) => h.startsWith('HUK: Bei jährlicher')), isTrue);
  });
}

