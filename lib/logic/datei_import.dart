/// Liest geteilte oder ausgewählte Dateien: PDF, E-Mail (.eml), Bilder, Text.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'android_kanal.dart';
import 'email.dart';
import 'pdf_import.dart';
import 'texterkennung.dart';

class ImportErgebnis {
  ImportErgebnis(this.text, this.bilder, this.pdfPfad, this.hinweise);

  final String text;
  final List<String> bilder;
  final String? pdfPfad;

  /// Was der Nutzer wissen sollte, z. B. übersprungene Anhänge.
  final List<String> hinweise;
}

enum DateiArt { pdf, email, bild, text, unbekannt }

DateiArt dateiArt(String? name, String? mime) {
  final n = (name ?? '').toLowerCase();
  final m = (mime ?? '').toLowerCase();
  if (m == 'application/pdf' || n.endsWith('.pdf')) return DateiArt.pdf;
  if (m == 'message/rfc822' || n.endsWith('.eml')) return DateiArt.email;
  if (m.startsWith('image/') || RegExp(r'\.(jpe?g|png|webp|heic)$').hasMatch(n)) return DateiArt.bild;
  if (m.startsWith('text/') || n.endsWith('.txt')) return DateiArt.text;
  return DateiArt.unbekannt;
}

Future<Directory> _ordner(String name) async {
  final basis = await getApplicationDocumentsDirectory();
  final d = Directory('${basis.path}/$name');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

String _endung(String name, String standard) {
  final i = name.lastIndexOf('.');
  return i < 0 ? standard : name.substring(i).toLowerCase();
}

/// Legt eine dauerhafte Kopie in der App ab (geteilte Dateien liegen nur im Zwischenspeicher).
Future<String> _ablegen(List<int> daten, String ordner, String endung) async {
  final ziel = '${(await _ordner(ordner)).path}/${DateTime.now().microsecondsSinceEpoch}$endung';
  await File(ziel).writeAsBytes(daten);
  return ziel;
}

class DateiImport {
  /// Lässt den Nutzer ein PDF oder eine gespeicherte E-Mail auswählen.
  static Future<Geteilt?> waehlen() async {
    const gruppe = XTypeGroup(
      label: 'PDF oder E-Mail',
      extensions: <String>['pdf', 'eml'],
      mimeTypes: <String>['application/pdf', 'message/rfc822', 'application/octet-stream'],
      uniformTypeIdentifiers: <String>['com.adobe.pdf', 'com.apple.mail.email'],
    );
    final datei = await openFile(acceptedTypeGroups: const <XTypeGroup>[gruppe]);
    if (datei == null) return null;
    return Geteilt(pfad: datei.path, name: datei.name, mime: datei.mimeType);
  }

  static Future<ImportErgebnis> lesen(List<Geteilt> teile, {void Function(String stand)? stand}) async {
    final texte = <String>[];
    final bilder = <String>[];
    final hinweise = <String>[];
    String? pdfPfad;

    Future<void> pdfLesen(List<int> daten, String name) async {
      final pfad = await _ablegen(daten, 'pdf', '.pdf');
      pdfPfad ??= pfad;
      final e = await PdfImport.lesen(pfad, fortschritt: (s, von) => stand?.call('$name: Seite $s von $von'));
      if (e.text.trim().isNotEmpty) texte.add(e.text);
      bilder.addAll(e.bilder);
      if (e.seiten > PdfImport.maxSeiten) {
        hinweise.add('$name hat ${e.seiten} Seiten. Gelesen wurden die ersten ${PdfImport.maxSeiten}.');
      }
    }

    Future<void> bildLesen(List<int> daten, String name) async {
      final pfad = await _ablegen(daten, 'bilder', _endung(name, '.jpg'));
      bilder.add(pfad);
      stand?.call('Texterkennung: $name');
      final t = await Texterkennung.textErkennen([pfad]);
      if (t.trim().isNotEmpty) texte.add(t);
    }

    for (final t in teile) {
      if (t.istText) {
        final text = t.text?.trim() ?? '';
        if (text.isEmpty) continue;
        texte.add(t.betreff == null || t.betreff!.trim().isEmpty ? text : 'Betreff: ${t.betreff!.trim()}\n\n$text');
        continue;
      }
      final datei = File(t.pfad!);
      if (!datei.existsSync()) continue;
      final name = t.name ?? datei.uri.pathSegments.last;
      final daten = await datei.readAsBytes();
      switch (dateiArt(name, t.mime)) {
        case DateiArt.pdf:
          stand?.call('Der Tiger liest $name …');
          await pdfLesen(daten, name);
        case DateiArt.email:
          stand?.call('Der Tiger liest die E-Mail …');
          final mail = emlLesen(daten);
          texte.add(mail.alsBrieftext);
          for (final a in mail.anhaenge) {
            if (a.istPdf) {
              await pdfLesen(a.daten, a.name);
            } else if (a.istBild && a.daten.length > 30000) {
              // Kleine Bilder sind meist Logos oder Signaturen.
              await bildLesen(a.daten, a.name);
            } else if (!a.istBild) {
              hinweise.add('Anhang „${a.name}“ wurde nicht gelesen (Format ${a.mime}).');
            }
          }
        case DateiArt.bild:
          await bildLesen(daten, name);
        case DateiArt.text:
          texte.add(utf8.decode(daten, allowMalformed: true));
        case DateiArt.unbekannt:
          hinweise.add('„$name“ kann der Tiger nicht lesen. Möglich sind PDF, E-Mail (.eml), Bilder und Text.');
      }
    }
    return ImportErgebnis(texte.join('\n\n'), bilder, pdfPfad, hinweise);
  }
}
