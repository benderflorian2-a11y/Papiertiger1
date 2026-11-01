// Beispieldaten für Rundgang und Klicktest: alle Bereiche gefüllt.
import 'dart:convert';

String _t(int tage) => DateTime(2026, 10, 31).add(Duration(days: tage)).toIso8601String();

const _brieftext = '''Finanzamt Musterstadt
Steuernummer 123/456/78901
Bescheid für 2025 über Einkommensteuer

Sehr geehrte Frau Muster,
die Einkommensteuer wird auf 1.234,56 € festgesetzt. Bitte zahlen Sie den Betrag bis zum 15.11.2026
auf das Konto IBAN DE12 3456 7890 1234 5678 90.

Rechtsbehelfsbelehrung
Gegen diesen Bescheid ist der Einspruch zulässig. Er ist innerhalb eines Monats nach Bekanntgabe einzulegen.''';

const _anleitung = '''Kaffeemaschine KM 300 – Bedienungsanleitung

Entkalkung
Wenn die Lampe rot blinkt, Entkalker in den Wassertank geben und die Taste 5 Sekunden halten.

Garantie
Die Garantie beträgt 24 Monate ab Kaufdatum.''';

Map<String, Object> beispielDaten({bool sperre = false}) {
  Map<String, dynamic> brief(String id, String titel, String kat, String text, {Map<String, dynamic> mehr = const {}}) => {
        'id': id,
        'titel': titel,
        'kategorie': kat,
        'typ': 'bescheid',
        'text': text,
        'erklaerung': 'Das Finanzamt will 1.234,56 € von dir. Zahle bis 15.11.2026.',
        'erstellt': _t(-3),
        'briefDatum': _t(-5),
        'bilder': ['test/fixtures/formular.png'],
        ...mehr,
      };
  final rechnung = {
    'id': 'r1',
    'art': 'rechnung',
    'nummer': '2026-007',
    'kundeId': 'k1',
    'datum': _t(-20),
    'leistungVon': _t(-25),
    'positionen': [
      {'text': 'Wände streichen Wohnzimmer', 'menge': 42.5, 'einheit': 'm²', 'preis': 12.4, 'ustSatz': 19},
      {'text': 'Arbeitszeit Geselle', 'menge': 6, 'einheit': 'Std.', 'preis': 55, 'ustSatz': 19},
    ],
    'zahlungszielTage': 14,
  };
  final angebot = {
    ...rechnung,
    'id': 'a1',
    'art': 'angebot',
    'nummer': 'A-2026-003',
    'datum': _t(-2),
    'rabattProzent': 5,
  };
  return {
    'onboardingFertig': true,
    'profil': jsonEncode({
      'name': 'Erika Muster',
      'adresse': 'Hauptstraße 5\n12345 Musterstadt',
      'extra': {'geburtsdatum': '01.02.1985', 'iban': 'DE12 3456 7890 1234 5678 90', 'telefon': '0151 2345678'},
    }),
    'checklisten': jsonEncode({
      for (final l in ['familie', 'angestellt', 'selbststaendig', 'handwerk', 'vermieter', 'jobsuche']) 'lage:$l': true,
      'bereich:selbststaendig': true,
      'bereich:haushalt': true,
      if (sperre) 'sicher:sperre': true,
    }),
    'notizen': jsonEncode({if (sperre) 'sicher:pin': 'AAAAAAAAAAAAAAAAAAAAAA==:AAAA'}),
    'briefe': jsonEncode([
      brief('b1', 'Einkommensteuerbescheid 2025', 'finanzamt', _brieftext,
          mehr: {'frist': _t(15), 'betrag': 1234.56, 'aktenzeichen': '123/456/78901', 'absenderName': 'Finanzamt Musterstadt'}),
      brief('b2', 'Angebot Malerarbeiten Huber', 'sonstiges',
          'Angebot Nr. 17\nMalerarbeiten Wohnzimmer\nZwischensumme netto 2.000,00 €\nMwSt. 19 % 380,00 €\nGesamtbetrag 2.380,00 €\nDas Angebot ist gültig bis 05.11.2026.',
          mehr: {'absenderName': 'Maler Huber'}),
      brief('b3', 'Angebot Farbe & Co', 'sonstiges', 'Kostenvoranschlag\nSumme netto 2.900,00 €\nGesamtbetrag 3.451,00 €\nBindefrist 4 Wochen',
          mehr: {'absenderName': 'Farbe & Co'}),
      brief('b4', 'Bedienungsanleitung Kaffeemaschine', 'sonstiges', _anleitung),
      brief('b5', 'Kontoauszug Oktober', 'bank',
          'Kontoauszug 10/2026\n01.10.2026 Netflix 13,99-\n01.10.2026 Stadtwerke Abschlag 85,00-\n05.10.2026 Kunde Müller RE 2026-007 1.020,00+\n01.09.2026 Netflix 13,99-'),
    ]),
    'vertraege': jsonEncode([
      {'id': 'v1', 'anbieter': 'Stadtwerke Musterstadt', 'art': 'Strom', 'beginn': _t(-400), 'kostenMonat': 85.0, 'laufzeitMonate': 12},
      {'id': 'v2', 'anbieter': 'Haftpflicht AG', 'art': 'Versicherung', 'beginn': _t(-800), 'kostenMonat': 6.5, 'versicherungsArt': 'Haftpflicht'},
    ]),
    'belege': jsonEncode([
      {'id': 'bl1', 'haendler': 'Elektromarkt', 'datum': _t(-60), 'betrag': 499.0, 'garantieMonate': 24, 'kategorie': 'Technik'},
      {'id': 'bl2', 'haendler': 'Baumarkt', 'datum': _t(-10), 'betrag': 89.9, 'geschaeftlich': true, 'projektId': 'p1'},
    ]),
    'termine': jsonEncode([
      {'id': 't1', 'titel': 'Zahnarzt', 'datum': _t(3), 'art': 'termin'},
    ]),
    'firma': jsonEncode({
      'name': 'Muster Malerbetrieb',
      'adresse': 'Werkstraße 1\n12345 Musterstadt',
      'steuernummer': '123/456/78901',
      'ustId': 'DE123456789',
      'iban': 'DE12345678901234567890',
      'bic': 'SPKADE2HXXX',
      'bank': 'Sparkasse',
      'email': 'info@muster-maler.de',
      'telefon': '0123 456789',
      'stundensatz': 55,
    }),
    'kunden': jsonEncode([
      {'id': 'k1', 'name': 'Familie Müller', 'adresse': 'Lindenweg 3\n12345 Musterstadt', 'email': 'mueller@example.de'},
    ]),
    'rechnungen': jsonEncode([rechnung, angebot]),
    'projekte': jsonEncode([
      {
        'id': 'p1',
        'name': 'Wohnzimmer Müller',
        'kundeId': 'k1',
        'status': 'laufend',
        'angebotId': 'a1',
        'erstellt': _t(-30),
        'adresse': 'Lindenweg 3, 12345 Musterstadt',
        'zeiten': [
          {'datum': _t(-5), 'stunden': 6, 'person': 'Tom', 'text': 'Streichen'},
        ],
        'tagebuch': [
          {'datum': _t(-5), 'wetter': 'sonnig', 'personen': 'Tom, Ali', 'arbeiten': 'Wände grundiert', 'material': '2 Eimer Grundierung'},
        ],
        'berichte': [
          {'id': 'rb1', 'art': 'regie', 'datum': _t(-4), 'text': 'Zusätzlich Decke gespachtelt', 'stunden': 2, 'personen': 'Tom'},
        ],
      },
    ]),
    'artikel': jsonEncode([
      {'id': 'art1', 'text': 'Dispersionsfarbe weiß 10 l', 'nummer': 'F-100', 'einheit': 'Eimer', 'einkauf': 38.5, 'aufschlagProzent': 25, 'ustSatz': 19},
    ]),
    'einsaetze': jsonEncode([
      {'id': 'e1', 'von': _t(0), 'bis': _t(2), 'personen': ['Tom'], 'projektId': 'p1', 'art': 'baustelle'},
    ]),
    'mitarbeiter': ['Tom', 'Ali'],
    'stempel': jsonEncode([]),
    'zaehler': jsonEncode([
      {
        'id': 'z1',
        'art': 'Strom',
        'nummer': '1ESY123',
        'preis': 0.32,
        'abschlagMonat': 85,
        'ablesungen': [
          {'datum': _t(-365), 'stand': 10000},
          {'datum': _t(-30), 'stand': 12600},
        ],
      },
    ]),
    'inventar': jsonEncode([
      {'id': 'g1', 'name': 'Fernseher', 'raum': 'Wohnzimmer', 'kaufdatum': _t(-300), 'preis': 899.0},
    ]),
    'sparziele': jsonEncode([
      {'id': 's1', 'name': 'Urlaub', 'ziel': 2000, 'gespart': 650, 'bis': _t(200)},
    ]),
    'alltag': jsonEncode({
      'einkauf': [
        {'text': 'Milch', 'kategorie': 'Kühlregal'},
        {'text': 'Brot', 'kategorie': 'Backwaren'},
      ],
      'vorraete': [
        {'name': 'Nudeln', 'menge': '2 Pakete', 'ablauf': _t(5), 'ort': 'Vorratsschrank'},
      ],
      'hausaufgaben': [
        {'text': 'Müll rausbringen', 'personen': ['Erika', 'Max']},
      ],
      'geschenke': [
        {'idee': 'Buch', 'fuer': 'Max', 'anlass': 'Geburtstag', 'datum': _t(20), 'preis': 25},
      ],
      'reisen': [
        {'id': 'reise1', 'ziel': 'Ostsee', 'von': _t(60), 'bis': _t(67), 'art': 'Urlaub'},
      ],
    }),
    'karriere': jsonEncode({
      'lebenslauf': {
        'telefon': '0151 2345678',
        'stationen': [
          {'art': 'Ausbildung', 'titel': 'Kauffrau für Büromanagement', 'ort': 'IHK', 'von': _t(-3000), 'bis': _t(-2200)},
          {'art': 'Beruf', 'titel': 'Sachbearbeiterin', 'ort': 'Firma A', 'von': _t(-2100)},
        ],
        'kenntnisse': ['Excel', 'DATEV'],
        'sprachen': ['Englisch – gut'],
      },
      'bewerbungen': [
        {'id': 'bw1', 'firma': 'Muster GmbH', 'stelle': 'Bürokauffrau', 'status': 'Beworben', 'beworbenAm': _t(-14)},
      ],
      'weiterbildungen': [
        {'id': 'w1', 'titel': 'Geprüfte Fachwirtin', 'kosten': 4200, 'anmeldungBis': _t(40)},
      ],
    }),
    'familie': jsonEncode({
      'kinder': [
        {'id': 'kind1', 'name': 'Max', 'geburt': _t(-900), 'einrichtung': 'Kita Sonnenschein'},
      ],
      'vorsorge': {
        'kontakte': [
          {'name': 'Hans Muster', 'telefon': '0123 9876', 'beziehung': 'Bruder'},
        ],
        'hausarzt': 'Dr. Meier, 0123 1111',
      },
    }),
    'vermietung': jsonEncode({
      'objekte': [
        {'id': 'o1', 'adresse': 'Lindenweg 3, 12345 Musterstadt', 'gesamtflaeche': 180, 'einheiten': 3},
      ],
      'mieter': [
        {
          'id': 'm1',
          'objektId': 'o1',
          'name': 'Max Mieter',
          'wohnung': '1. OG',
          'einzug': _t(-900),
          'kaltmiete': 600,
          'nebenkosten': 150,
          'flaeche': 62,
          'personen': 2,
          'kaution': 1800,
        },
      ],
      'nebenkosten': [],
    }),
  };
}

