/// Projekte für Selbstständige: Zeiten, Material, Nachkalkulation, Berichte,
/// Aufgaben aus Besprechungen und Rechnungsentwurf. Reines Dart, damit es testbar ist.
library;

import '../data/geschaeft.dart';
import '../data/models.dart';
import 'rechnungen.dart';

double _rund(double x) => (x * 100).round() / 100;

DateTime _tagesende(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

double stundenVon(Projekt p, {DateTime? von, DateTime? bis}) => p.zeiten
    .where((z) => (von == null || !z.datum.isBefore(von)) && (bis == null || !z.datum.isAfter(_tagesende(bis))))
    .fold(0.0, (s, z) => s + z.stunden);

class Nachkalkulation {
  Nachkalkulation({required this.zeit, required this.material, this.angebot, this.eingang = 0});

  /// Eingangsrechnungen bzw. Belege, die dem Projekt zugeordnet sind (netto).
  final double eingang;

  /// Stunden × Stundensatz.
  final double zeit;
  final double material;

  /// Angebotssumme netto, falls ein Angebot verknüpft ist.
  final double? angebot;

  double get kosten => _rund(zeit + material + eingang);

  /// Positiv: teurer als angeboten.
  double? get abweichung => angebot == null ? null : _rund(kosten - angebot!);
  double? get abweichungProzent => angebot == null || angebot == 0 ? null : _rund((kosten - angebot!) / angebot! * 100);
}

/// [belege]: Eingangsrechnungen mit projektId. Ohne Kleinunternehmer wird die Vorsteuer
/// (19 % angenommen) herausgerechnet, weil sie vom Finanzamt zurückkommt.
Nachkalkulation nachkalkulation(Projekt p, List<Rechnung> rechnungen, {List<Beleg> belege = const [], bool kleinunternehmer = true}) {
  Rechnung? angebot;
  for (final r in rechnungen) {
    if (r.id == p.angebotId) angebot = r;
  }
  return Nachkalkulation(
    zeit: _rund(stundenVon(p) * p.stundensatz),
    material: _rund(p.material.fold(0.0, (s, m) => s + m.summe)),
    angebot: angebot == null ? null : summenVon(angebot, kleinunternehmer: true).netto,
    eingang: _rund(belege
        .where((b) => b.projektId == p.id && b.betrag != null)
        .fold(0.0, (s, b) => s + (kleinunternehmer ? b.betrag! : b.betrag! / 1.19))),
  );
}

/// Rechnungsentwurf aus Projektzeiten und Material.
Rechnung rechnungAusProjekt(Projekt p, List<Rechnung> alle,
    {required String id, required DateTime datum, required int zahlungszielTage, int ustSatz = 19}) {
  final daten = p.zeiten.map((z) => z.datum).toList()..sort();
  return Rechnung(
    id: id,
    art: 'rechnung',
    nummer: naechsteNummer(alle, art: 'rechnung', jahr: datum.year),
    kundeId: p.kundeId,
    datum: datum,
    leistungVon: daten.isEmpty ? datum : daten.first,
    leistungBis: daten.isEmpty ? datum : daten.last,
    zahlungszielTage: zahlungszielTage,
    projektId: p.id,
    positionen: [
      if (stundenVon(p) > 0)
        Position(text: 'Arbeitszeit ${p.name}', menge: stundenVon(p), einheit: 'Std.', preis: p.stundensatz, ustSatz: ustSatz),
      for (final m in p.material)
        Position(text: m.text, menge: m.menge, einheit: m.einheit, preis: m.preis, ustSatz: ustSatz),
    ],
  );
}

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
String _h(double h) => h.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',');

/// Wochenbericht bzw. Tätigkeitsnachweis über alle Projekte im Zeitraum.
String taetigkeitsnachweis(List<Projekt> projekte, Map<String, String> kundenNamen,
    {required DateTime von, required DateTime bis, String? person}) {
  final z = StringBuffer('Tätigkeitsnachweis ${_d(von)} – ${_d(bis)}${person == null ? '' : ' · $person'}\n');
  var gesamt = 0.0;
  for (final p in projekte) {
    final eintraege = p.zeiten
        .where((e) => !e.datum.isBefore(von) && !e.datum.isAfter(_tagesende(bis)) && (person == null || e.person == person))
        .toList()
      ..sort((a, b) => a.datum.compareTo(b.datum));
    if (eintraege.isEmpty) continue;
    final summe = eintraege.fold(0.0, (s, e) => s + e.stunden);
    gesamt += summe;
    final kunde = kundenNamen[p.kundeId];
    z.write('\n${p.name}${kunde == null ? '' : ' ($kunde)'} – ${_h(summe)} Std.\n');
    for (final e in eintraege) {
      z.write('  ${_d(e.datum)}  ${_h(e.stunden)} Std.${e.person.isEmpty ? '' : '  ${e.person}'}${e.text.isEmpty ? '' : '  ${e.text}'}\n');
    }
  }
  z.write('\nGesamt: ${_h(gesamt)} Stunden\n');
  return z.toString();
}

/// Bestellliste: noch nicht bestelltes Material aller laufenden Projekte.
String bestellliste(List<Projekt> projekte) {
  final z = StringBuffer('Bestellliste\n');
  var leer = true;
  for (final p in projekte.where((p) => p.status != 'Abgerechnet' && p.status != 'Fertig')) {
    final offen = p.material.where((m) => !m.bestellt).toList();
    if (offen.isEmpty) continue;
    leer = false;
    z.write('\nFür ${p.name}:\n');
    for (final m in offen) {
      z.write('- ${_h(m.menge)} ${m.einheit} ${m.text}\n');
    }
  }
  return leer ? '' : z.toString();
}

final _aufgabeZeile = RegExp(r'^\s*(?:[-*•]|\[ \]|todo:|aufgabe:)\s*(.+)$', caseSensitive: false);
final _personAm = RegExp(r'@([A-Za-zÄÖÜäöüß]+)');
final _personDoppelpunkt = RegExp(r'^([A-ZÄÖÜ][a-zäöüß]+):\s+(.+)$');

/// Aufgaben aus einem Besprechungsprotokoll: Zeilen mit „-“, „*“, „[ ]“ oder „TODO“.
/// „@Name“ oder „Name: …“ legt fest, wer die Aufgabe übernimmt.
List<ProjektAufgabe> aufgabenAusProtokoll(String text) {
  final out = <ProjektAufgabe>[];
  for (final zeile in text.split('\n')) {
    final m = _aufgabeZeile.firstMatch(zeile);
    if (m == null) continue;
    var t = m.group(1)!.trim();
    var person = '';
    final at = _personAm.firstMatch(t);
    if (at != null) {
      person = at.group(1)!;
      t = t.replaceFirst(at.group(0)!, '').replaceAll(RegExp(r'\s+'), ' ').trim();
    } else {
      final dp = _personDoppelpunkt.firstMatch(t);
      if (dp != null) {
        person = dp.group(1)!;
        t = dp.group(2)!.trim();
      }
    }
    if (t.isNotEmpty) out.add(ProjektAufgabe(text: t, person: person));
  }
  return out;
}

/// Vorlagen für Standardabläufe: gespeichert als 'vorlage:<Name>' mit einer Aufgabe pro Zeile.
Map<String, List<String>> ablaufVorlagen(Map<String, String> notizen) => {
      for (final e in notizen.entries)
        if (e.key.startsWith('vorlage:'))
          e.key.substring(8): e.value.split('\n').map((z) => z.trim()).where((z) => z.isNotEmpty).toList(),
    };

const standardVorlagen = <String, List<String>>{
  'Neuer Auftrag': [
    'Auftrag schriftlich bestätigen',
    'Termin mit Kunde abstimmen',
    'Material prüfen und bestellen',
    'Arbeit erledigen und Zeiten erfassen',
    'Abnahme / Fotos vom Ergebnis',
    'Rechnung schreiben',
    'Zahlungseingang prüfen',
    'Um Bewertung bitten',
  ],
  'Monatsabschluss': [
    'Alle Belege fotografieren',
    'Offene Rechnungen prüfen und mahnen',
    'Zeiten für den Monat abschließen',
    'Umsatzsteuer-Voranmeldung (falls nötig)',
    'Rücklage für Steuern überweisen',
  ],
};

// ---------------------------------------------------------------- Baustelle

/// Regieberichte, die noch nicht abgerechnet sind.
List<Baubericht> offeneRegieberichte(Projekt p) =>
    p.berichte.where((b) => b.art == 'regie' && !b.abgerechnet).toList()..sort((a, b) => a.datum.compareTo(b.datum));

/// Rechnungspositionen aus Regieberichten: Stunden zum Stundensatz, Material als eigene Zeile (Preis von dir).
List<Position> regiePositionen(List<Baubericht> berichte, {required double stundensatz, int ustSatz = 19}) => [
      for (final b in berichte) ...[
        if (b.stunden > 0)
          Position(
            text: 'Regiearbeiten ${_d(b.datum)}: ${b.text.trim().split('\n').first}',
            menge: b.stunden,
            einheit: 'Std.',
            preis: stundensatz,
            ustSatz: ustSatz,
          ),
        if (b.material.trim().isNotEmpty)
          Position(text: 'Material Regie ${_d(b.datum)}: ${b.material.trim()}', einheit: 'pauschal', ustSatz: ustSatz),
      ],
    ];

/// Bautagebuch als Text für einen Zeitraum.
String bautagebuchText(Projekt p, {DateTime? von, DateTime? bis}) {
  final l = p.tagebuch
      .where((t) => (von == null || !t.datum.isBefore(von)) && (bis == null || !t.datum.isAfter(_tagesende(bis))))
      .toList()
    ..sort((a, b) => a.datum.compareTo(b.datum));
  final z = StringBuffer('Bautagebuch ${p.name}${p.adresse.isEmpty ? '' : ' – ${p.adresse}'}\n');
  for (final t in l) {
    z.write('\n${_d(t.datum)}${t.wetter.isEmpty ? '' : ' · Wetter: ${t.wetter}'}\n');
    if (t.personen.isNotEmpty) z.write('Anwesend: ${t.personen}\n');
    if (t.arbeiten.isNotEmpty) z.write('Arbeiten: ${t.arbeiten}\n');
    if (t.material.isNotEmpty) z.write('Material: ${t.material}\n');
    if (t.besonderheiten.isNotEmpty) z.write('Besonderheiten: ${t.besonderheiten}\n');
  }
  return z.toString();
}
