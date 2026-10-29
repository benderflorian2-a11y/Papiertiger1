import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'texterkennung.dart';

class PdfErgebnis {
  PdfErgebnis(this.text, this.bilder, this.pdfPfad, this.seiten);

  final String text;
  final List<String> bilder;
  final String pdfPfad;
  final int seiten;
}

/// Liest PDFs: zuerst die Textebene, bei gescannten PDFs per Texterkennung.
class PdfImport {
  static const maxSeiten = 15;
  static Future<void>? _start;

  static Future<void> starten() => _start ??= () async {
        try {
          await pdfrxFlutterInitialize();
        } catch (_) {}
      }();

  static Future<Directory> _ordner(String name) async {
    final basis = await getApplicationDocumentsDirectory();
    final d = Directory('${basis.path}/$name');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Lässt den Nutzer ein PDF auswählen und legt eine Kopie in der App ab.
  static Future<String?> waehlen() async {
    const gruppe = XTypeGroup(
      label: 'PDF',
      extensions: <String>['pdf'],
      mimeTypes: <String>['application/pdf'],
      uniformTypeIdentifiers: <String>['com.adobe.pdf'],
    );
    final datei = await openFile(acceptedTypeGroups: const <XTypeGroup>[gruppe]);
    if (datei == null) return null;
    final ziel = '${(await _ordner('pdf')).path}/${DateTime.now().microsecondsSinceEpoch}.pdf';
    await datei.saveTo(ziel);
    return ziel;
  }

  static Future<PdfErgebnis> lesen(String pfad, {void Function(int seite, int von)? fortschritt}) async {
    await starten();
    final doc = await PdfDocument.openFile(pfad);
    try {
      final bilderOrdner = await _ordner('bilder');
      final seiten = doc.pages.take(maxSeiten).toList();
      final texte = <String>[];
      final bilder = <String>[];
      for (var i = 0; i < seiten.length; i++) {
        fortschritt?.call(i + 1, seiten.length);
        final seite = seiten[i];
        var text = (await seite.loadText())?.fullText.trim() ?? '';

        // Seite als Bild: für die Vorschau und für gescannte PDFs ohne Text.
        final faktor = (2200 / seite.width).clamp(1.0, 3.0);
        final w = (seite.width * faktor).round();
        final h = (seite.height * faktor).round();
        final bild = await seite.render(
          width: w,
          height: h,
          fullWidth: w.toDouble(),
          fullHeight: h.toDouble(),
          backgroundColor: 0xffffffff,
        );
        if (bild != null) {
          try {
            final img = await bild.createImage();
            final daten = await img.toByteData(format: ui.ImageByteFormat.png);
            img.dispose();
            if (daten != null) {
              final ziel = '${bilderOrdner.path}/${DateTime.now().microsecondsSinceEpoch}_$i.png';
              await File(ziel).writeAsBytes(daten.buffer.asUint8List());
              bilder.add(ziel);
              if (text.length < 30) text = await Texterkennung.textErkennen([ziel]);
            }
          } finally {
            bild.dispose();
          }
        }
        texte.add(text);
      }
      return PdfErgebnis(texte.join('\n\n'), bilder, pfad, doc.pages.length);
    } finally {
      await doc.dispose();
    }
  }
}
