/// Text oder Unterschrift, die auf eine Formularseite geschrieben wird (Positionen relativ 0…1).
library;

import 'dart:convert';

import '../data/models.dart';

class FormularEintrag {
  FormularEintrag({required this.seite, required this.x, required this.y, this.text = '', this.bild, this.groesse = 0.022});

  final int seite;

  /// Linke obere Ecke, relativ zu Breite bzw. Höhe der Seite.
  double x;
  double y;
  String text;

  /// Pfad zu einem Bild (Unterschrift) statt Text.
  String? bild;

  /// Schriftgröße bzw. Bildhöhe relativ zur Seitenbreite.
  double groesse;

  Map<String, dynamic> toJson() => {'seite': seite, 'x': x, 'y': y, 'text': text, 'bild': bild, 'groesse': groesse};

  factory FormularEintrag.fromJson(Map<String, dynamic> j) => FormularEintrag(
        seite: (j['seite'] as num?)?.toInt() ?? 0,
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        text: j['text'] as String? ?? '',
        bild: j['bild'] as String?,
        groesse: (j['groesse'] as num?)?.toDouble() ?? 0.022,
      );
}

String formularSchluessel(String briefId) => 'formular:$briefId';

List<FormularEintrag> formularLaden(Map<String, String> notizen, String briefId) {
  final roh = notizen[formularSchluessel(briefId)];
  if (roh == null) return [];
  try {
    return (jsonDecode(roh) as List).whereType<Map<String, dynamic>>().map(FormularEintrag.fromJson).toList();
  } catch (_) {
    return [];
  }
}

void formularSpeichern(Map<String, String> notizen, String briefId, List<FormularEintrag> l) {
  if (l.isEmpty) {
    notizen.remove(formularSchluessel(briefId));
  } else {
    notizen[formularSchluessel(briefId)] = jsonEncode(l.map((e) => e.toJson()).toList());
  }
}

/// Vorschläge zum Eintragen aus dem Profil: (Bezeichnung, Wert).
List<(String, String)> formularVorschlaege(Profil p, {DateTime? heute}) {
  final h = heute ?? DateTime.now();
  final zeilen = p.adresse.split(RegExp(r'[\n,]')).map((z) => z.trim()).where((z) => z.isNotEmpty).toList();
  final plzOrt = zeilen.where((z) => RegExp(r'^\d{5}\s').hasMatch(z)).firstOrNull;
  final strasse = zeilen.where((z) => z != plzOrt).firstOrNull;
  return [
    if (p.name.isNotEmpty) ('Name', p.name),
    if (p.vorname.isNotEmpty) ('Vorname', p.vorname),
    if (p.nachname.isNotEmpty) ('Nachname', p.nachname),
    if (strasse != null) ('Straße', strasse),
    if (plzOrt != null) ('PLZ Ort', plzOrt),
    if (plzOrt != null) ('PLZ', plzOrt.substring(0, 5)),
    if (plzOrt != null) ('Ort', plzOrt.substring(5).trim()),
    for (final (k, label) in profilFelder)
      if ((p.extra[k] ?? '').isNotEmpty) (label, p.extra[k]!),
    ('Datum heute', '${h.day.toString().padLeft(2, '0')}.${h.month.toString().padLeft(2, '0')}.${h.year}'),
    if (plzOrt != null) ('Ort, Datum', '${plzOrt.substring(5).trim()}, ${h.day.toString().padLeft(2, '0')}.${h.month.toString().padLeft(2, '0')}.${h.year}'),
    ('Kreuz', 'X'),
  ];
}
