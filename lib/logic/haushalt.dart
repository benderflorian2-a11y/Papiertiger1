/// Haushalt: Verbrauch hochrechnen, Abschlag prüfen, Inventar, Notfallmappe.
/// Reines Dart, damit es testbar ist. Alle Werte sind Schätzungen.
library;

import '../data/haushalt.dart';
import '../data/models.dart';

class Verbrauch {
  Verbrauch({required this.menge, required this.tage, required this.proJahr});

  /// Verbrauch zwischen erster und letzter Ablesung.
  final double menge;
  final int tage;

  /// Auf 365 Tage hochgerechnet.
  final double proJahr;
}

/// Verbrauch aus den Ablesungen. Null bei weniger als zwei Ablesungen oder zu kurzem Abstand.
Verbrauch? verbrauchVon(Zaehler z, {int minTage = 7}) {
  if (z.ablesungen.length < 2) return null;
  final l = [...z.ablesungen]..sort((a, b) => a.datum.compareTo(b.datum));
  DateTime utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  // In UTC gerechnet, damit die Zeitumstellung keinen Tag verschluckt.
  final tage = utc(l.last.datum).difference(utc(l.first.datum)).inDays;
  final menge = l.last.stand - l.first.stand;
  if (tage < minTage || menge < 0) return null;
  return Verbrauch(menge: menge, tage: tage, proJahr: (menge / tage * 365 * 10).round() / 10);
}

class Abschlagscheck {
  Abschlagscheck({required this.kostenJahr, required this.abschlaegeJahr});

  final double kostenJahr;
  final double abschlaegeJahr;

  /// Positiv: voraussichtlich Nachzahlung. Negativ: voraussichtlich Guthaben.
  double get differenz => kostenJahr - abschlaegeJahr;
}

/// Hochgerechnete Jahreskosten (Verbrauch × Preis + Grundpreis) gegen die Abschläge.
Abschlagscheck? abschlagPruefen(Zaehler z) {
  final v = verbrauchVon(z);
  if (v == null || z.preis == null || z.abschlagMonat == null) return null;
  final kosten = v.proJahr * z.preis! + (z.grundpreisMonat ?? 0) * 12;
  return Abschlagscheck(kostenJahr: (kosten * 100).round() / 100, abschlaegeJahr: z.abschlagMonat! * 12);
}

/// Ein neuer Zählerstand darf nicht kleiner sein als der letzte.
String? ablesungPruefen(Zaehler z, double stand, DateTime datum) {
  final frueher = z.ablesungen.where((a) => !a.datum.isAfter(datum)).toList()..sort((a, b) => a.datum.compareTo(b.datum));
  if (frueher.isNotEmpty && stand < frueher.last.stand) {
    return 'Der Stand ist kleiner als am ${frueher.last.datum.day}.${frueher.last.datum.month}. (${frueher.last.stand}). '
        'Wurde der Zähler getauscht? Dann lege einen neuen Zähler an.';
  }
  return null;
}

// ---------------------------------------------------------------- Inventar

double inventarWert(List<Gegenstand> l) => l.fold(0.0, (s, g) => s + (g.preis ?? 0));

Map<String, double> wertNachRaum(List<Gegenstand> l) {
  final m = <String, double>{};
  for (final g in l) {
    final r = g.raum.isEmpty ? 'Ohne Raum' : g.raum;
    m[r] = (m[r] ?? 0) + (g.preis ?? 0);
  }
  return m;
}

/// Gegenstand aus einem Kassenbon übernehmen.
Gegenstand gegenstandAusBeleg(Beleg b, String id) =>
    Gegenstand(id: id, name: b.haendler, kaufdatum: b.datum, preis: b.betrag, belegId: b.id, bild: null);

// ---------------------------------------------------------------- Notfallmappe

const notfallDokumente = [
  'Personalausweis / Reisepass',
  'Geburts- und Heiratsurkunde',
  'Krankenversichertenkarte und Impfpass',
  'Vorsorgevollmacht',
  'Patientenverfügung',
  'Betreuungsverfügung',
  'Testament',
  'Versicherungspolicen',
  'Bankverbindungen und Konten',
  'Mietvertrag oder Grundbuchauszug',
  'Renten- und Steuerunterlagen',
  'Fahrzeugpapiere',
  'Zeugnisse und Arbeitsvertrag',
  'Hinweis, wo Passwörter liegen (nicht die Passwörter selbst)',
];

// ---------------------------------------------------------------- Wiederkehrende Aufgaben

class TerminVorlage {
  const TerminVorlage(this.titel, this.monate, this.art, this.notiz);

  final String titel;
  final int monate;
  final String art;
  final String notiz;
}

const haushaltsTermine = [
  TerminVorlage('Rauchmelder prüfen', 12, 'Wartung', 'Testknopf drücken, Batterie prüfen.'),
  TerminVorlage('Heizung warten lassen', 12, 'Wartung', 'Am besten vor der Heizsaison.'),
  TerminVorlage('Zählerstände ablesen', 1, 'Sonstiges', 'Strom, Gas, Wasser im Papiertiger eintragen.'),
  TerminVorlage('Dunstabzug-Filter wechseln', 3, 'Wartung', ''),
  TerminVorlage('Kühlschrank abtauen', 6, 'Wartung', ''),
  TerminVorlage('Erste-Hilfe-Kasten prüfen', 12, 'Sonstiges', 'Haltbarkeit von Pflastern und Verbandszeug.'),
  TerminVorlage('Reifen wechseln', 6, 'TÜV / Auto', 'Faustregel: von O bis O (Oktober bis Ostern).'),
];

Termin terminAusVorlage(TerminVorlage v, {required String id, required DateTime start}) => Termin(
      id: id,
      titel: v.titel,
      datum: DateTime(start.year, start.month, start.day, 10),
      wiederholungMonate: v.monate,
      art: v.art,
      notiz: v.notiz,
    );
