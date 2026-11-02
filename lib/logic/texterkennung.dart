import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Fotografieren, Bild sichern und Text auf dem Handy erkennen.
class Texterkennung {
  static final _picker = ImagePicker();

  /// Fotografiert eine Seite oder wählt sie aus der Galerie.
  /// Gibt den Pfad der dauerhaft gespeicherten Kopie zurück.
  static Future<String?> bildHolen({required bool kamera}) async {
    final XFile? datei = await _picker.pickImage(
      source: kamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (datei == null) return null;
    return _ablegen(datei.path);
  }

  /// Dauerhafte Kopie im App-Ordner (Kamera und Scanner legen nur im Zwischenspeicher ab).
  static Future<String> _ablegen(String pfad) async {
    final ordner = await getApplicationDocumentsDirectory();
    final bilder = Directory('${ordner.path}/bilder');
    if (!bilder.existsSync()) bilder.createSync(recursive: true);
    final ziel = '${bilder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(pfad).copy(ziel);
    return ziel;
  }

  /// Dokumenten-Scanner von Google (Android, läuft auf dem Handy): findet die Ränder des Briefs,
  /// richtet ihn gerade aus, entfernt Schatten und nimmt mehrere Seiten nacheinander auf.
  /// null = Scanner nicht verfügbar (dann normale Kamera), leere Liste = abgebrochen.
  static Future<List<String>?> scannen({int maxSeiten = 10}) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(pageLimit: maxSeiten, mode: ScannerMode.full, isGalleryImport: true),
    );
    try {
      final ergebnis = await scanner.scanDocument();
      return [for (final p in ergebnis.images ?? const <String>[]) await _ablegen(p)];
    } on PlatformException catch (e) {
      if ((e.message ?? '').toLowerCase().contains('cancel')) return [];
      return null;
    } on MissingPluginException {
      return null;
    } finally {
      try {
        await scanner.close();
      } catch (_) {}
    }
  }

  /// Erkennt den Text auf allen Seiten, in Reihenfolge.
  static Future<String> textErkennen(List<String> pfade) async {
    final erkenner = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final teile = <String>[];
      for (final pfad in pfade) {
        final ergebnis = await erkenner.processImage(InputImage.fromFilePath(pfad));
        teile.add(ergebnis.text);
      }
      return teile.join('\n\n');
    } finally {
      await erkenner.close();
    }
  }
}
