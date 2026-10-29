/// Alltag: Einkaufsliste, Vorräte, Haushaltsaufgaben, Packlisten, Wohnungsübergabe.
/// Reines Dart, damit es testbar ist.
library;

import '../data/alltag.dart';

/// Reihenfolge wie in einem typischen Supermarkt.
const einkaufsKategorien = [
  'Obst & Gemüse',
  'Brot & Backwaren',
  'Kühlregal',
  'Fleisch & Fisch',
  'Vorrat',
  'Tiefkühl',
  'Getränke',
  'Süßes & Snacks',
  'Drogerie',
  'Haushalt',
  'Sonstiges',
];

const _einkaufsWoerter = <String, List<String>>{
  'Obst & Gemüse': ['apfel', 'äpfel', 'banane', 'tomate', 'gurke', 'salat', 'kartoffel', 'zwiebel', 'knoblauch', 'paprika', 'möhre', 'karotte', 'zitrone', 'obst', 'gemüse', 'beeren', 'brokkoli', 'zucchini', 'pilze', 'champignon', 'kräuter', 'petersilie', 'ingwer', 'avocado', 'trauben', 'orange'],
  'Brot & Backwaren': ['brot', 'brötchen', 'toast', 'baguette', 'croissant', 'kuchen', 'wrap', 'tortilla'],
  'Kühlregal': ['milch', 'joghurt', 'käse', 'butter', 'sahne', 'quark', 'eier', 'ei ', 'schmand', 'frischkäse', 'mozzarella', 'feta', 'aufschnitt', 'margarine'],
  'Fleisch & Fisch': ['hähnchen', 'huhn', 'rind', 'hack', 'schwein', 'wurst', 'schinken', 'speck', 'lachs', 'fisch', 'thunfisch', 'garnelen', 'fleisch', 'steak'],
  'Vorrat': ['nudeln', 'spaghetti', 'reis', 'mehl', 'zucker', 'salz', 'pfeffer', 'öl', 'essig', 'konserve', 'dose', 'linsen', 'bohnen', 'tomatenmark', 'passierte', 'brühe', 'gewürz', 'haferflocken', 'müsli', 'honig', 'marmelade', 'kaffee', 'tee', 'senf', 'ketchup', 'mayonnaise'],
  'Tiefkühl': ['tk-', 'tiefkühl', 'pizza', 'eis', 'pommes', 'spinat tk'],
  'Getränke': ['wasser', 'saft', 'bier', 'wein', 'cola', 'limo', 'sprudel', 'mineralwasser'],
  'Süßes & Snacks': ['schokolade', 'chips', 'kekse', 'gummibärchen', 'nüsse', 'riegel'],
  'Drogerie': ['zahnpasta', 'shampoo', 'duschgel', 'seife', 'deo', 'toilettenpapier', 'klopapier', 'windeln', 'taschentücher', 'zahnbürste', 'creme'],
  'Haushalt': ['spülmittel', 'waschmittel', 'müllbeutel', 'schwamm', 'putzmittel', 'alufolie', 'backpapier', 'küchenrolle', 'batterien', 'glühbirne', 'spültabs'],
};

/// Kategorie eines Einkaufs: selbst gewählt, sonst aus dem Text.
String einkaufKategorie(Einkauf e) {
  if (e.kategorie != null) return e.kategorie!;
  final t = ' ${e.text.toLowerCase()} ';
  for (final k in einkaufsKategorien) {
    if ((_einkaufsWoerter[k] ?? const []).any(t.contains)) return k;
  }
  return 'Sonstiges';
}

/// Einkaufsliste nach Gängen sortiert: offene zuerst, in Supermarkt-Reihenfolge.
List<(String, List<Einkauf>)> einkaufNachKategorie(List<Einkauf> liste) {
  final m = <String, List<Einkauf>>{};
  for (final e in liste.where((e) => !e.erledigt)) {
    m.putIfAbsent(einkaufKategorie(e), () => []).add(e);
  }
  return [for (final k in einkaufsKategorien) if (m[k] != null) (k, m[k]!)];
}

final _mengeVorne = RegExp(r'^\s*(?:[-•*]|\d+[.)])\s*');

/// Macht aus einem Rezept, einer Nachricht oder Notiz einzelne Einkäufe (eine Zeile = ein Eintrag).
/// Überschriften wie „Zutaten:“ und Anleitungsschritte werden übersprungen.
List<Einkauf> einkaufAusText(String text, {List<Einkauf> vorhanden = const []}) {
  final schon = {for (final e in vorhanden.where((e) => !e.erledigt)) e.text.toLowerCase()};
  final out = <Einkauf>[];
  for (var z in text.split(RegExp(r'[\n,;]'))) {
    z = z.replaceFirst(_mengeVorne, '').trim();
    // Überschriften enden mit „:“, Anleitungssätze mit „.“
    if (z.isEmpty || z.length > 60 || z.endsWith(':') || z.endsWith('.')) continue;
    // Anleitungen sind lange Sätze mit Verben im Imperativ – grob: mehr als 6 Wörter
    if (z.split(RegExp(r'\s+')).length > 6) continue;
    if (schon.contains(z.toLowerCase())) continue;
    schon.add(z.toLowerCase());
    out.add(Einkauf(text: z));
  }
  return out;
}

/// Einkauf abschließen: Erledigtes entfernen, wiederkehrende Einkäufe wieder auf „offen“.
void einkaufAbschliessen(List<Einkauf> liste) {
  liste.removeWhere((e) => e.erledigt && !e.immer);
  for (final e in liste) {
    if (e.immer) e.erledigt = false;
  }
}

String einkaufAlsText(List<Einkauf> liste) {
  final z = StringBuffer('Einkaufsliste\n');
  for (final (k, l) in einkaufNachKategorie(liste)) {
    z.write('\n$k\n');
    for (final e in l) {
      z.write('☐ ${e.text}\n');
    }
  }
  return z.toString();
}

// ---------------------------------------------------------------- Vorräte

/// Vorräte, die in [tage] Tagen oder früher ablaufen, früheste zuerst.
List<Vorrat> laeuftBaldAb(List<Vorrat> l, {required DateTime heute, int tage = 3}) {
  final grenze = DateTime(heute.year, heute.month, heute.day + tage);
  return l.where((v) => v.ablauf != null && !v.ablauf!.isAfter(grenze)).toList()
    ..sort((a, b) => a.ablauf!.compareTo(b.ablauf!));
}

/// Anfrage an die KI: Rezepte aus dem, was da ist – bald Ablaufendes zuerst verbrauchen.
String rezeptAnfrage(List<Vorrat> vorraete, {required DateTime heute, String wunsch = ''}) {
  final bald = laeuftBaldAb(vorraete, heute: heute).map((v) => v.name).toSet();
  final alle = vorraete.map((v) => v.menge.isEmpty ? v.name : '${v.name} (${v.menge})').join(', ');
  return '''
Schlage 3 einfache Rezepte vor, die man mit diesen Zutaten kochen kann: $alle.
${bald.isEmpty ? '' : 'Verwende bevorzugt, was bald abläuft: ${bald.join(', ')}.\n'}${wunsch.trim().isEmpty ? '' : 'Wunsch: ${wunsch.trim()}\n'}
Für jedes Rezept: NAME, ZEIT in Minuten, ZUTATEN (was fehlt, markiere mit „(kaufen)“), ZUBEREITUNG in höchstens 5 kurzen Schritten.
Übliche Grundzutaten wie Salz, Pfeffer, Öl darfst du voraussetzen. Antworte auf Deutsch.
''';
}

/// Anfrage für einen Wochenplan mit Einkaufsliste.
String essensplanAnfrage({int personen = 2, String wunsch = '', List<Vorrat> vorraete = const []}) => '''
Erstelle einen einfachen Essensplan für 7 Abendessen (Montag bis Sonntag) für $personen Personen.
${wunsch.trim().isEmpty ? '' : 'Wünsche: ${wunsch.trim()}\n'}${vorraete.isEmpty ? '' : 'Vorhanden: ${vorraete.map((v) => v.name).join(', ')}\n'}
Antworte im Format:
MONTAG: <Gericht>
DIENSTAG: <Gericht>
… bis SONNTAG
EINKAUFSLISTE:
- <eine Zutat pro Zeile, mit Menge>
Antworte auf Deutsch, alltagstauglich und günstig.
''';

const wochentage = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

/// Liest „MONTAG: Spaghetti“ usw. aus einer KI-Antwort.
Map<String, String> essensplanLesen(String antwort) {
  final out = <String, String>{};
  for (final z in antwort.split('\n')) {
    final m = RegExp(r'^\W*(montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag)\W*[:\-–]\s*(.+)$', caseSensitive: false)
        .firstMatch(z.trim());
    if (m == null) continue;
    final tag = wochentage.indexWhere((t) => t.toLowerCase() == m.group(1)!.toLowerCase()) + 1;
    out['$tag'] = m.group(2)!.replaceAll('**', '').trim();
  }
  return out;
}

/// Einkaufsliste aus der KI-Antwort (Zeilen unter „EINKAUFSLISTE:“).
List<Einkauf> einkaufAusEssensplan(String antwort) {
  final i = antwort.toUpperCase().indexOf('EINKAUFSLISTE');
  if (i < 0) return [];
  final rest = antwort.substring(i).split('\n').skip(1).join('\n');
  return einkaufAusText(rest);
}

// ---------------------------------------------------------------- Haushaltsaufgaben

DateTime? naechstesMal(Hausaufgabe a) =>
    a.zuletzt == null ? null : DateTime(a.zuletzt!.year, a.zuletzt!.month, a.zuletzt!.day + a.alleTage);

/// Wer als Nächstes dran ist (reihum).
String? werIstDran(Hausaufgabe a) =>
    a.personen.isEmpty ? null : a.personen[(a.zuletztVon + (a.zuletzt == null ? 0 : 1)) % a.personen.length];

/// Aufgabe erledigt: Datum merken und zur nächsten Person weiterreichen.
void hausaufgabeErledigt(Hausaufgabe a, DateTime am) {
  if (a.personen.isNotEmpty && a.zuletzt != null) a.zuletztVon = (a.zuletztVon + 1) % a.personen.length;
  a.zuletzt = am;
}

bool hausaufgabeFaellig(Hausaufgabe a, {required DateTime heute}) {
  final n = naechstesMal(a);
  return n == null || !n.isAfter(DateTime(heute.year, heute.month, heute.day));
}

// ---------------------------------------------------------------- Reisen und Wohnung

const reiseArten = ['Sommer', 'Winter', 'Städtereise', 'Geschäftsreise'];

const _packBasis = [
  'Personalausweis / Reisepass',
  'Krankenversichertenkarte und Auslandskrankenversicherung',
  'Buchungsbestätigungen und Tickets',
  'Bargeld und Karte',
  'Handy und Ladekabel',
  'Medikamente',
  'Zahnbürste und Kosmetik',
  'Unterwäsche und Socken',
  'Schlafsachen',
];

const _packJeArt = <String, List<String>>{
  'Sommer': ['Sonnencreme', 'Sonnenbrille', 'Badesachen', 'Kopfbedeckung', 'Sandalen', 'Mückenschutz'],
  'Winter': ['Warme Jacke', 'Mütze, Schal, Handschuhe', 'Thermounterwäsche', 'Lippenpflege', 'Feste Schuhe'],
  'Städtereise': ['Bequeme Schuhe', 'Kleiner Rucksack', 'Regenschirm', 'Powerbank', 'Stadtplan / Offline-Karte'],
  'Geschäftsreise': ['Laptop und Netzteil', 'Unterlagen und Visitenkarten', 'Business-Kleidung', 'Reisekostenbelege sammeln'],
};

List<PackStueck> packliste(String art, {bool kinder = false, bool ausland = false}) => [
      for (final t in [
        ..._packBasis,
        ...?_packJeArt[art],
        if (ausland) 'Reiseadapter',
        if (ausland) 'Visum prüfen',
        if (kinder) 'Kinderreisepass',
        if (kinder) 'Spielzeug und Beschäftigung',
        if (kinder) 'Snacks für unterwegs',
      ])
        PackStueck(t),
    ];

String reiseplanAnfrage(Reise r) => '''
Erstelle einen einfachen Reiseplan für ${r.ziel}${r.von != null && r.bis != null ? ' für ${r.bis!.difference(r.von!).inDays + 1} Tage' : ''} (Reiseart: ${r.art}).
Für jeden Tag: TAG <Nummer>: Vormittag, Nachmittag, Abend – jeweils ein kurzer Vorschlag.
Danach: GUT ZU WISSEN: 3 praktische Hinweise (Anreise, Geld, Sicherheit).
Antworte auf Deutsch, kurz und praktisch. Erfinde keine Öffnungszeiten oder Preise.
''';

const wohnungsuebergabe = [
  'Termin mit Vermieter / Nachmieter vereinbaren',
  'Alle Räume fotografieren (mit Datum)',
  'Zählerstände Strom, Gas, Wasser ablesen und fotografieren',
  'Mängel und Schäden im Protokoll festhalten',
  'Schlüssel zählen und Anzahl ins Protokoll schreiben',
  'Schönheitsreparaturen laut Mietvertrag prüfen',
  'Übergabeprotokoll von beiden unterschreiben lassen, Kopie behalten',
  'Kaution: Rückzahlung schriftlich anfordern',
  'Strom, Internet, Rundfunkbeitrag ummelden',
  'Nachsendeauftrag einrichten',
  'Wohnsitz beim Bürgeramt ummelden (innerhalb von 2 Wochen)',
];
