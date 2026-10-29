import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import 'ordnung.dart';

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _dateiname(String s) =>
    s.replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüß \-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');

const _orange = PdfColor.fromInt(0xFFC9650F);

List<pw.Widget> _briefTeil(Brief b) => [
      pw.Header(level: 1, text: titelVon(b)),
      pw.Text('Datum: ${_d(b.briefDatum ?? b.erstellt)}   ·   Ordner: ${ordnerFuer(b).name}'
          '${b.aktenzeichen != null ? '   ·   ${b.aktenzeichen}' : ''}'),
      pw.SizedBox(height: 8),
      pw.Text('Einfach erklärt', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
      pw.Paragraph(text: b.erklaerung),
      if (b.fakten.isNotEmpty) ...[
        pw.Text('Das steht drin', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
        for (final f in b.fakten) pw.Bullet(text: '${f.label}: ${f.wert}'),
      ],
      if (b.bedeutung.isNotEmpty) ...[
        pw.Text('Was heißt das für dich?', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
        for (final z in b.bedeutung) pw.Bullet(text: z),
      ],
      if (b.frist != null) pw.Text('Frist: ${_d(b.frist!)}${b.fristUnsicher ? ' (bitte prüfen)' : ''}'),
      if (b.aufgaben.isNotEmpty) ...[
        pw.Text('Aufgaben', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
        for (final a in b.aufgaben) pw.Bullet(text: '${a.erledigt ? '[x]' : '[ ]'} ${a.text}'),
      ],
      if (b.unterlagen.isNotEmpty) ...[
        pw.Text('Verlangte Unterlagen', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
        for (final u in b.unterlagen) pw.Bullet(text: '${u.erledigt ? '[x]' : '[ ]'} ${u.text}'),
      ],
    ];

Future<List<pw.Widget>> _bilder(Brief b) async {
  final out = <pw.Widget>[];
  for (final pfad in b.bilder) {
    final f = File(pfad);
    if (!f.existsSync()) continue;
    out.add(pw.Center(child: pw.Image(pw.MemoryImage(await f.readAsBytes()), fit: pw.BoxFit.contain)));
  }
  return out;
}

Future<File> _speichern(pw.Document doc, String name) async {
  final ordner = await getTemporaryDirectory();
  final datei = File('${ordner.path}/${_dateiname(name)}.pdf');
  await datei.writeAsBytes(await doc.save());
  return datei;
}

const _fuss = 'Erstellt mit Papiertiger. Die Erklärungen sind automatisch erstellt und ersetzen keine Beratung.';

Future<File> briefAlsPdf(Brief b) async {
  final doc = pw.Document(title: titelVon(b), author: 'Papiertiger');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    footer: (c) => pw.Text(_fuss, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    build: (c) => _briefTeil(b),
  ));
  for (final bild in await _bilder(b)) {
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (c) => bild));
  }
  return _speichern(doc, titelVon(b));
}

Future<File> akteAlsPdf(Akte a) async {
  final doc = pw.Document(title: a.titel, author: 'Papiertiger');
  final reihenfolge = a.briefe.reversed.toList();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    footer: (c) => pw.Text(_fuss, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    build: (c) => [
      pw.Header(level: 0, text: 'Vorgang: ${a.titel}'),
      pw.Text('${a.briefe.length} Dokumente, Stand ${_d(DateTime.now())}'),
      pw.SizedBox(height: 6),
      for (final b in reihenfolge) pw.Bullet(text: '${_d(b.briefDatum ?? b.erstellt)}  ${titelVon(b)}'),
      for (final b in reihenfolge) ...[pw.NewPage(), ..._briefTeil(b)],
    ],
  ));
  for (final b in reihenfolge) {
    for (final bild in await _bilder(b)) {
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (c) => bild));
    }
  }
  return _speichern(doc, 'Vorgang ${a.titel}');
}

Future<void> dateiTeilen(String pfad, {String? text, String? mimeType}) =>
    SharePlus.instance.share(ShareParams(files: [XFile(pfad, mimeType: mimeType)], text: text));

Future<void> textTeilen(String text) => SharePlus.instance.share(ShareParams(text: text));

String _csv(String s) => '"${s.replaceAll('"', '""')}"';

/// Alle Dokumente als Tabelle (CSV, öffnet in Excel, Numbers, Google Tabellen).
Future<File> archivAlsTabelle(List<Brief> briefe) async {
  final z = StringBuffer('\uFEFFDatum;Titel;Ordner;Absender;Aktenzeichen;Betrag;Geld;Frist;Status\n');
  for (final b in briefe) {
    z.writeln([
      _d(b.briefDatum ?? b.erstellt),
      _csv(titelVon(b)),
      _csv(ordnerFuer(b).name),
      _csv(b.absenderName ?? ''),
      _csv(b.aktenzeichen?.split(': ').last ?? ''),
      b.betrag?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
      b.betrag == null ? '' : (b.guthaben ? 'bekommen' : 'zahlen'),
      b.frist != null ? _d(b.frist!) : '',
      b.erledigt ? 'erledigt' : 'offen',
    ].join(';'));
  }
  final ordner = await getTemporaryDirectory();
  final datei = File('${ordner.path}/Papiertiger_Archiv_${_d(DateTime.now()).replaceAll('.', '-')}.csv');
  await datei.writeAsString(z.toString());
  return datei;
}
