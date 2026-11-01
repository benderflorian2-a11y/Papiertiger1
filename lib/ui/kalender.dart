import 'package:flutter/material.dart';

import '../logic/export.dart';
import '../logic/zeitplan.dart';
import 'widgets/common.dart';

/// Erstellt einen Kalendereintrag und öffnet das Teilen-Menü (Kalender-App wählen).
Future<void> inKalender(BuildContext context, String titel, DateTime datum,
    {String beschreibung = '', bool mitUhrzeit = false}) async {
  try {
    final ics = icsErstellen(titel, datum,
        ganztags: !mitUhrzeit, beschreibung: '$beschreibung\n\nErstellt mit Papiertiger.');
    final datei = await textDatei('termin_${stabileId(titel + datum.toIso8601String())}.ics', ics);
    await dateiTeilen(datei.path, mimeType: 'text/calendar');
  } catch (e) {
    if (context.mounted) zeigeHinweis(context, 'Kalendereintrag konnte nicht erstellt werden: $e');
  }
}
