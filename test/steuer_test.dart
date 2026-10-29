import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/steuer.dart';

void main() {
  test('Kategorie-Vorschlag', () {
    expect(steuerVorschlag('Rechnung für Malerarbeiten und Montage durch Ihren Handwerker'), 'Handwerkerleistungen');
    expect(steuerVorschlag('Apotheke am Markt – Zuzahlung'), 'Krankheitskosten');
    expect(steuerVorschlag('Zuwendungsbestätigung über eine Spende'), 'Spenden');
    expect(steuerVorschlag('Kassenbon Supermarkt Milch Brot'), isNull);
  });

  test('Pauschalen', () {
    expect(entfernungspauschale(km: 30, tage: 200, jahr: 2026), closeTo(2280, 0.001));
    expect(entfernungspauschale(km: 30, tage: 200, jahr: 2025), closeTo(1960, 0.001));
    expect(entfernungspauschale(km: 15, tage: 200, jahr: 2025), closeTo(900, 0.001));
    expect(homeofficePauschale(250), 1260);
    expect(homeofficePauschale(100), 600);
    final w = Werbungskosten(fahrt: 900, homeoffice: 300, weitere: 100);
    expect(w.ueberPauschale, isTrue);
    expect(w.mehrAlsPauschale, closeTo(70, 0.001));
  });

  test('Abgabefristen', () {
    expect(abgabefrist(2025), DateTime(2026, 7, 31));
    expect(abgabefrist(2026), DateTime(2027, 8, 2));
    expect(freiwilligBis(2022), DateTime(2026, 12, 31));
  });

  test('Jahresübersicht mit Versicherungsbeiträgen als Vorschlag', () {
    final posten = steuerPosten(
      jahr: 2025,
      briefe: [
        Brief(
            id: 'b',
            erstellt: DateTime(2025, 6, 1),
            briefDatum: DateTime(2025, 5, 20),
            kategorie: 'sonstiges',
            typ: 'rechnung',
            text: '',
            erklaerung: '',
            absenderName: 'Maler Müller',
            betrag: 400,
            steuerKategorie: 'Handwerkerleistungen'),
      ],
      belege: [
        Beleg(id: '1', haendler: 'Apotheke', datum: DateTime(2025, 3, 1), betrag: 20, steuerKategorie: 'Krankheitskosten'),
        Beleg(id: '2', haendler: 'Apotheke', datum: DateTime(2024, 3, 1), betrag: 99, steuerKategorie: 'Krankheitskosten'),
        Beleg(id: '3', haendler: 'Markt', datum: DateTime(2025, 3, 1), betrag: 5),
      ],
      vertraege: [
        Vertrag(
            id: 'v',
            anbieter: 'Allianz',
            art: 'Versicherung',
            versicherungsArt: 'Hausrat',
            beginn: DateTime(2025, 4, 15),
            kostenMonat: 10),
        Vertrag(
            id: 'w',
            anbieter: 'HUK',
            art: 'Versicherung',
            beginn: DateTime(2020, 1, 1),
            kostenMonat: 10,
            gekuendigt: true,
            gekuendigtAm: DateTime(2025, 10, 3)),
        Vertrag(id: 'x', anbieter: 'Netflix', art: 'Streaming', beginn: DateTime(2020, 1, 1), kostenMonat: 13),
      ],
    );
    expect(posten.length, 4);
    final s = summenNachKategorie(posten);
    expect(s['Handwerkerleistungen'], 400);
    expect(s['Krankheitskosten'], 20);
    expect(s['Versicherungen'], closeTo(160, 0.001));
    expect(posten.where((p) => p.vorschlag).map((p) => p.betrag), containsAll([90.0, 70.0]));
    final csv = steuerCsv(posten);
    expect(csv, startsWith('﻿Datum;Beschreibung;Kategorie;Betrag;Quelle'));
    expect(csv, contains('"Allianz (Hausrat)"'));
    expect(csv, contains('400,00'));
  });
}
