import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../logic/export.dart';
import '../logic/zeitplan.dart';
import 'widgets/common.dart';

/// Erstellt einen Kalendereintrag und öffnet das Teilen-Menü (Kalender-App wählen).
Future<void> inKalender(BuildContext context, String titel, DateTime datum,
    {String beschreibung = '', bool mitUhrzeit = false}) async {
  try {
    final ics = icsErstellen(titel, datum,
        ganztags: !mitUhrzeit, beschreibung: '$beschreibung\n\nErstellt mit Papiertiger.');
    final ordner = await getTemporaryDirectory();
    final datei = File('${ordner.path}/termin_${stabileId(titel + datum.toIso8601String())}.ics');
    await datei.writeAsString(ics);
    await dateiTeilen(datei.path, mimeType: 'text/calendar');
  } catch (e) {
    if (context.mounted) zeigeHinweis(context, 'Kalendereintrag konnte nicht erstellt werden: $e');
  }
}
