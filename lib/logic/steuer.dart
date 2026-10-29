/// Steuer-Vorbereitung für Privatleute. Keine Steuerberatung: Werte sind
/// allgemeine Pauschalen (Stand 2026) und immer ohne Gewähr.
library;

import '../data/models.dart';
import 'behoerden.dart';
import 'brief_analyse.dart';

// ---------------------------------------------------------------- Kategorie-Vorschlag

const _steuerWoerter = <String, List<String>>{
  'Handwerkerleistungen': ['handwerker', 'reparatur', 'montage', 'malerarbeiten', 'sanitär', 'elektroinstallation', 'schornsteinfeger'],
  'Haushaltsnahe Dienstleistungen': ['reinigung', 'gartenpflege', 'hausmeister', 'winterdienst', 'haushaltshilfe', 'treppenhausreinigung'],
  'Krankheitskosten': ['apotheke', 'zuzahlung', 'arztrechnung', 'zahnarzt', 'physiotherapie', 'brille', 'hörgerät', 'heilpraktiker'],
  'Spenden': ['spende', 'zuwendungsbestätigung', 'spendenquittung', 'mitgliedsbeitrag'],
  'Fortbildung': ['fortbildung', 'weiterbildung', 'seminar', 'lehrgang', 'fachbuch', 'kursgebühr'],
  'Arbeitsmittel': ['laptop', 'notebook', 'bürostuhl', 'schreibtisch', 'monitor', 'arbeitskleidung', 'drucker'],
  'Versicherungen': ['haftpflicht', 'berufsunfähigkeit', 'unfallversicherung', 'beitragsrechnung', 'versicherungsbeitrag'],
};

/// Schlägt eine Steuer-Kategorie vor, wenn der Text eindeutige Hinweise enthält.
String? steuerVorschlag(String text) {
  final l = text.toLowerCase();
  String? beste;
  var punkte = 0;
  _steuerWoerter.forEach((k, woerter) {
    final n = woerter.where(l.contains).length;
    if (n > punkte) {
      punkte = n;
      beste = k;
    }
  });
  return beste;
}

// ---------------------------------------------------------------- Pauschalen

/// Arbeitnehmer-Pauschbetrag (Werbungskosten), seit 2023.
const arbeitnehmerPauschbetrag = 1230.0;

/// Entfernungspauschale: ab 2026 38 Cent ab dem ersten Kilometer,
/// 2022–2025 30 Cent für die ersten 20 km und 38 Cent ab dem 21. km.
double entfernungspauschale({required int km, required int tage, required int jahr}) {
  if (km <= 0 || tage <= 0) return 0;
  final proTag = jahr >= 2026
      ? km * 0.38
      : (km <= 20 ? km * 0.30 : 20 * 0.30 + (km - 20) * (jahr >= 2022 ? 0.38 : 0.35));
  return (proTag * tage * 100).round() / 100;
}

/// Homeoffice-Pauschale: 6 € pro Tag, höchstens 210 Tage (1.260 €) – seit 2023.
double homeofficePauschale(int tage) => (tage.clamp(0, 210)) * 6.0;

class Werbungskosten {
  Werbungskosten({required this.fahrt, required this.homeoffice, required this.weitere});

  final double fahrt;
  final double homeoffice;

  /// Arbeitsmittel, Fortbildung u. Ä. aus markierten Belegen und Briefen.
  final double weitere;

  double get summe => fahrt + homeoffice + weitere;

  /// Lohnt es sich, die Werbungskosten einzeln anzugeben?
  bool get ueberPauschale => summe > arbeitnehmerPauschbetrag;
  double get mehrAlsPauschale => summe - arbeitnehmerPauschbetrag;
}

/// Abgabefrist ohne Steuerberater für ein Steuerjahr: 31. Juli des Folgejahres
/// (fällt sie aufs Wochenende oder einen Feiertag, am nächsten Werktag).
DateTime abgabefrist(int steuerjahr) => naechsterWerktag(DateTime(steuerjahr + 1, 7, 31));

/// Freiwillige Erklärung (Antragsveranlagung): bis zu 4 Jahre rückwirkend.
DateTime freiwilligBis(int steuerjahr) => DateTime(steuerjahr + 4, 12, 31);

const steuerCheckliste = [
  'Lohnsteuerbescheinigung vom Arbeitgeber',
  'Bescheinigungen über Lohnersatzleistungen (z. B. Elterngeld, Krankengeld, Arbeitslosengeld)',
  'Nebenkostenabrechnung (haushaltsnahe Dienstleistungen, Handwerker)',
  'Rechnungen von Handwerkern (nur mit Überweisung, nicht bar)',
  'Spendenquittungen',
  'Belege für Arbeitsmittel und Fortbildung',
  'Arbeitstage und Entfernung zur Arbeit, Homeoffice-Tage',
  'Beitragsbescheinigungen Kranken- und Pflegeversicherung',
  'Bescheinigungen über Riester, Rürup oder Altersvorsorge',
  'Steuerbescheid vom Vorjahr',
];

// ---------------------------------------------------------------- Jahresübersicht

class SteuerPosten {
  SteuerPosten(this.datum, this.titel, this.kategorie, this.betrag, {this.vorschlag = false, this.quelle = ''});

  final DateTime datum;
  final String titel;
  final String kategorie;
  final double? betrag;

  /// Nicht markiert, sondern aus Verträgen abgeleitet – bitte prüfen.
  final bool vorschlag;
  final String quelle;
}

/// Alle markierten Belege und Briefe eines Jahres, dazu Versicherungsbeiträge aus Verträgen als Vorschlag.
List<SteuerPosten> steuerPosten({
  required int jahr,
  required List<Brief> briefe,
  required List<Beleg> belege,
  required List<Vertrag> vertraege,
}) {
  final out = <SteuerPosten>[
    for (final b in belege)
      if (b.steuerKategorie != null && b.datum.year == jahr)
        SteuerPosten(b.datum, b.haendler.isEmpty ? 'Beleg' : b.haendler, b.steuerKategorie!, b.betrag, quelle: 'Beleg'),
    for (final b in briefe)
      if (b.steuerKategorie != null && (b.briefDatum ?? b.erstellt).year == jahr)
        SteuerPosten(b.briefDatum ?? b.erstellt, b.absenderName ?? kategorieFuer(b.kategorie).name, b.steuerKategorie!,
            b.guthaben ? null : b.betrag,
            quelle: 'Brief'),
  ];
  for (final v in vertraege) {
    if (v.art != 'Versicherung' || v.kostenMonat == null) continue;
    final start = DateTime(v.beginn.year, v.beginn.month);
    final ende = v.gekuendigtAm == null ? null : DateTime(v.gekuendigtAm!.year, v.gekuendigtAm!.month);
    var monate = 0;
    for (var m = 1; m <= 12; m++) {
      final d = DateTime(jahr, m);
      if (d.isBefore(start) || (ende != null && d.isAfter(ende))) continue;
      monate++;
    }
    if (monate == 0) continue;
    out.add(SteuerPosten(DateTime(jahr, 12, 31), '${v.anbieter} (${v.versicherungsArt ?? 'Versicherung'})',
        'Versicherungen', (v.kostenMonat! * monate * 100).round() / 100,
        vorschlag: true, quelle: 'Vertrag, $monate Monate'));
  }
  out.sort((a, b) => a.datum.compareTo(b.datum));
  return out;
}

Map<String, double> summenNachKategorie(List<SteuerPosten> posten) {
  final s = <String, double>{};
  for (final p in posten) {
    s[p.kategorie] = (s[p.kategorie] ?? 0) + (p.betrag ?? 0);
  }
  return s;
}

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
String _csv(String s) => '"${s.replaceAll('"', '""')}"';

/// Tabelle für Excel, Numbers oder den Steuerberater.
String steuerCsv(List<SteuerPosten> posten) {
  final z = StringBuffer('﻿Datum;Beschreibung;Kategorie;Betrag;Quelle\n');
  for (final p in posten) {
    z.writeln([
      _d(p.datum),
      _csv(p.titel),
      _csv(p.kategorie),
      p.betrag?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
      _csv(p.vorschlag ? '${p.quelle} (Vorschlag)' : p.quelle),
    ].join(';'));
  }
  return z.toString();
}
