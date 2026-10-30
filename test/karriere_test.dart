import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/karriere.dart';
import 'package:papiertiger/data/models.dart';
import 'package:papiertiger/logic/karriere.dart';

const _anzeige = '''
Wir suchen ab sofort eine Bürokauffrau (m/w/d) in Vollzeit, unbefristet.
Gehalt: 42.000 € brutto pro Jahr.
Bitte senden Sie Ihre vollständigen Unterlagen inkl. Gehaltsvorstellung und frühestmöglichem Eintrittstermin
bis zum 15.12.2026 an Frau Schmidt: bewerbung@muster-gmbh.de
Ein Führungszeugnis ist bei Einstellung vorzulegen.
''';

Lebenslauf _lebenslauf() => Lebenslauf(telefon: '0123 4567', stationen: [
      Station(art: 'Ausbildung', titel: 'Kauffrau für Büromanagement', ort: 'IHK', von: DateTime(2018, 8), bis: DateTime(2021, 6)),
      Station(art: 'Beruf', titel: 'Sachbearbeiterin', ort: 'Firma A', von: DateTime(2021, 8), bis: DateTime(2023, 3)),
      Station(art: 'Beruf', titel: 'Assistenz', ort: 'Firma B', von: DateTime(2024, 1)),
    ], kenntnisse: ['Excel', 'DATEV'], sprachen: ['Englisch – gut']);

void main() {
  test('Stellenanzeige auswerten', () {
    final i = anzeigeAuswerten(_anzeige);
    expect(i.frist, DateTime(2026, 12, 15));
    expect(i.email, 'bewerbung@muster-gmbh.de');
    expect(i.ansprechpartner, 'Frau Schmidt');
    expect(i.arbeitszeit, 'Vollzeit');
    expect(i.befristet, isFalse);
    expect(i.gehaltGewuenscht, isTrue);
    expect(i.eintrittGewuenscht, isTrue);
    expect(i.gehaltsangabe, startsWith('42.000 €'));
    expect(i.unterlagen, containsAll(['Anschreiben', 'Lebenslauf', 'Zeugnisse', 'Führungszeugnis']));
    expect(anzeigeAuswerten('Bewerbung ohne Anschreiben möglich, Teilzeit, befristet').unterlagen, isNot(contains('Anschreiben')));
  });

  test('Bewerbung auf Vollständigkeit prüfen', () {
    final p = Profil(name: 'Erika Muster', adresse: 'Weg 1\n12345 Ort');
    final b = Bewerbung(id: 'b', firma: 'Muster GmbH', stelle: 'Bürokauffrau', anzeige: _anzeige);
    var fehlt = bewerbungPruefen(b, _lebenslauf(), p, anlagen: 0);
    expect(fehlt, containsAll(['Anschreiben', 'Zeugnisse als Anlage', 'Führungszeugnis']));
    b.anschreiben = 'Sehr geehrte Damen und Herren,\nich bewerbe mich [Grund].';
    fehlt = bewerbungPruefen(b, _lebenslauf(), p, anlagen: 1);
    expect(fehlt, containsAll([
      'Platzhalter in [Klammern] im Anschreiben ausfüllen',
      'Gehaltsvorstellung (wird in der Anzeige verlangt)',
      'Frühestmöglicher Eintrittstermin (wird in der Anzeige verlangt)',
      'Anrede mit Namen: Frau Schmidt',
    ]));
    b
      ..anschreiben = 'Sehr geehrte Frau Schmidt,\nmeine Gehaltsvorstellung liegt bei 44.000 Euro. Ich kann ab dem 1.2. beginnen.'
      ..erledigt.add('Führungszeugnis');
    expect(bewerbungPruefen(b, _lebenslauf(), p, anlagen: 1), isEmpty);
  });

  test('Lücken im Lebenslauf und Nachfassen', () {
    final l = lebenslaufLuecken(_lebenslauf().stationen, heute: DateTime(2026, 10, 30));
    expect(l.single, (DateTime(2023, 3), DateTime(2024, 1)));
    final b = Bewerbung(id: 'b', firma: 'F', stelle: 'S', status: 'Beworben', beworbenAm: DateTime(2026, 10, 1));
    expect(nachfassenFaellig(b, heute: DateTime(2026, 10, 10)), isFalse);
    expect(nachfassenFaellig(b, heute: DateTime(2026, 10, 15)), isTrue);
    b.status = 'Absage';
    expect(nachfassenFaellig(b, heute: DateTime(2026, 10, 15)), isFalse);
  });

  test('Lebenslauf als Text und KI-Anfragen', () {
    final p = Profil(name: 'Erika Muster', adresse: 'Weg 1, 12345 Ort');
    final t = lebenslaufText(_lebenslauf(), p);
    expect(t, contains('Berufserfahrung\n01/2024 – heute  Assistenz, Firma B'));
    expect(t.indexOf('Assistenz'), lessThan(t.indexOf('Sachbearbeiterin')));
    expect(t, contains('Kenntnisse\nExcel, DATEV'));
    final b = Bewerbung(id: 'b', firma: 'Muster GmbH', stelle: 'Bürokauffrau', anzeige: _anzeige);
    final a = anschreibenAnfrage(b, _lebenslauf(), p);
    expect(a, contains('Sehr geehrte Frau Schmidt,'));
    expect(a, contains('Gehaltsvorstellung liegt bei [Betrag]'));
    expect(a, contains('Nur Erfahrungen aus dem Lebenslauf'));
    expect(passungAnfrage(_anzeige, _lebenslauf(), p), contains('MUSS-ANFORDERUNGEN'));
    expect(gespraechAnfrage(b, _lebenslauf(), p), contains('Unzulässige Fragen'));
  });

  test('Zeugnissprache', () {
    expect(zeugnisFormel('Sie erledigte ihre Aufgaben stets zu unserer vollsten Zufriedenheit.'), (1, 'sehr gut'));
    expect(zeugnisFormel('stets zu unserer vollen Zufriedenheit'), (2, 'gut'));
    expect(zeugnisFormel('zu unserer vollen   Zufriedenheit'), (3, 'befriedigend'));
    expect(zeugnisFormel('im Großen und Ganzen zu unserer Zufriedenheit'), (5, 'mangelhaft'));
    expect(zeugnisFormel('zu unserer Zufriedenheit'), (4, 'ausreichend'));
    expect(zeugnisFormel('Er hat sich bemüht, die Aufgaben zu erledigen.'), (6, 'ungenügend'));
    expect(zeugnisFormel('Ein freundlicher Kollege.'), isNull);
  });

  test('Karriere übersteht Speichern', () {
    final k = Karriere(
      lebenslauf: _lebenslauf()..foto = '/f.jpg',
      bewerbungen: [Bewerbung(id: 'b', firma: 'F', stelle: 'S', briefIds: ['x'], erledigt: ['Führungszeugnis'])],
      weiterbildungen: [Weiterbildung(id: 'w', titel: 'Fachwirt', kosten: 4200, anmeldungBis: DateTime(2027, 1, 15))],
    );
    final k2 = Karriere.fromJson(jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>);
    expect(k2.lebenslauf.stationen.length, 3);
    expect(k2.lebenslauf.stationen.last.bis, isNull);
    expect(k2.lebenslauf.foto, '/f.jpg');
    expect(k2.bewerbungen.single.erledigt, ['Führungszeugnis']);
    expect(k2.weiterbildungen.single.kosten, 4200);
    expect(Karriere.fromJson({}).bewerbungen, isEmpty);
  });
}
