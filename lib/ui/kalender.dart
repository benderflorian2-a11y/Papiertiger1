import 'package:flutter/material.dart';

import '../logic/export.dart';
import '../logic/handykalender.dart';
import '../logic/zeitplan.dart';
import 'widgets/common.dart';

/// Erstellt einen Kalendereintrag und öffnet das Teilen-Menü (Kalender-App wählen).
Future<void> inKalender(BuildContext context, String titel, DateTime datum,
    {String beschreibung = '', bool mitUhrzeit = false}) async {
  // Direkt in den Handykalender (mit Erlaubnis); sonst über das Teilen-Menü
  if (Handykalender.verfuegbar && await Handykalender.erlaubnis()) {
    final id = await Handykalender.eintragen(titel, datum,
        text: beschreibung, ganztags: !mitUhrzeit, erinnerung: mitUhrzeit ? const [60] : const [900]);
    if (id > 0) {
      if (context.mounted) zeigeHinweis(context, 'Im Kalender eingetragen.');
      return;
    }
  }
  try {
    final ics = icsErstellen(titel, datum,
        ganztags: !mitUhrzeit, beschreibung: '$beschreibung\n\nErstellt mit Papiertiger.');
    final datei = await textDatei('termin_${stabileId(titel + datum.toIso8601String())}.ics', ics);
    await dateiTeilen(datei.path, mimeType: 'text/calendar');
  } catch (e) {
    if (context.mounted) zeigeHinweis(context, 'Kalendereintrag konnte nicht erstellt werden: $e');
  }
}
