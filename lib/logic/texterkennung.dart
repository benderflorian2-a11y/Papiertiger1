import 'dart:io';

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
    final ordner = await getApplicationDocumentsDirectory();
    final bilder = Directory('${ordner.path}/bilder');
    if (!bilder.existsSync()) bilder.createSync(recursive: true);
    final ziel = '${bilder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(datei.path).copy(ziel);
    return ziel;
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
