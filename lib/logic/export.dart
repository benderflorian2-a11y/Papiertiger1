import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/geschaeft.dart';
import '../data/haushalt.dart';
import '../data/karriere.dart';
import '../data/models.dart';
import 'formular_eintrag.dart';
import 'kalkulation.dart';
import 'kommunikation.dart';
import 'rechnungen.dart';
import 'ordnung.dart';
import 'steuer.dart';

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _dateiname(String s) =>
    s.replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüß \-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');

const _orange = PdfColor.fromInt(0xFFC9650F);

pw.ThemeData? _thema;

/// Schrift für alle PDFs: Liberation Sans (eingebettet). Die PDF-Standardschrift kann weder €
/// noch „ “ – darstellen. Ohne Schriftdatei (z. B. in reinen Logik-Tests) die Standardschrift.
Future<pw.ThemeData> pdfThema() async {
  final t = _thema;
  if (t != null) return t;
  try {
    Future<pw.Font> schrift(String n) async => pw.Font.ttf(await rootBundle.load('assets/fonts/LiberationSans-$n.ttf'));
    return _thema = pw.ThemeData.withFont(
      base: await schrift('Regular'),
      bold: await schrift('Bold'),
      italic: await schrift('Italic'),
      boldItalic: await schrift('BoldItalic'),
    );
  } catch (_) {
    return pw.ThemeData();
  }
}

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
  final doc = pw.Document(theme: await pdfThema(), title: titelVon(b), author: 'Papiertiger');
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
  final doc = pw.Document(theme: await pdfThema(), title: a.titel, author: 'Papiertiger');
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

/// Antwort als richtiger Brief nach DIN 5008 (Form B): Anschrift passt ins
/// Fenster eines DIN-lang-Umschlags, mit Falz- und Lochmarken.
Future<File> antwortAlsPdf(String text, {String titel = 'Antwort'}) async {
  final t = briefTeile(text);
  final doc = pw.Document(theme: await pdfThema(), title: titel, author: 'Papiertiger');
  final mm = PdfPageFormat.mm;
  const klein = pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700);
  const normal = pw.TextStyle(fontSize: 11, lineSpacing: 2);
  final absaetze = (t?.inhalt ?? text)
      .split(RegExp(r'\n\s*\n'))
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();
  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(25 * mm, 15 * mm, 20 * mm, 20 * mm),
      buildBackground: (c) => c.pageNumber > 1
          ? pw.SizedBox()
          : pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(children: [
                for (final y in [105.0, 148.5, 210.0])
                  pw.Positioned(
                    left: 5 * mm,
                    top: y * mm,
                    child: pw.Container(width: (y == 148.5 ? 7 : 4) * mm, height: 0.4, color: PdfColors.grey500),
                  ),
              ]),
            ),
    ),
    build: (c) => [
      if (t != null) ...[
        pw.SizedBox(
          height: 30 * mm,
          child: pw.Align(
            alignment: pw.Alignment.topRight,
            child: pw.Text(t.absender, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5)),
          ),
        ),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
            width: 85 * mm,
            height: 45 * mm,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(t.absender.split('\n').map((z) => z.trim()).where((z) => z.isNotEmpty).join(' · '),
                  style: klein, maxLines: 1),
              pw.SizedBox(height: 3 * mm),
              pw.Text(t.empfaenger, style: normal),
            ]),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.bottomRight,
              child: pw.Text(t.datum, style: normal),
            ),
          ),
        ]),
        pw.SizedBox(height: 8 * mm),
        pw.Text(t.betreff, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8 * mm),
      ],
      for (final a in absaetze) pw.Paragraph(text: a, style: normal, textAlign: pw.TextAlign.left, margin: pw.EdgeInsets.only(bottom: 4 * mm)),
    ],
  ));
  return _speichern(doc, titel);
}

Future<void> dateiTeilen(String pfad, {String? text, String? mimeType}) =>
    SharePlus.instance.share(ShareParams(files: [XFile(pfad, mimeType: mimeType)], text: text));

/// Mehrere Dateien auf einmal teilen, z. B. Brief-PDF mit Anlagen an die E-Mail-App.
Future<void> dateienTeilen(List<String> pfade, {String? text, String? betreff}) => SharePlus.instance
    .share(ShareParams(files: [for (final p in pfade) XFile(p)], text: text, subject: betreff));

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

String _euro(double b) => '${b.toStringAsFixed(2).replaceAll('.', ',')} €';

/// Jahresübersicht für die Steuererklärung als PDF.
Future<File> steuerAlsPdf(int jahr, List<SteuerPosten> posten, {Werbungskosten? werbung}) async {
  final doc = pw.Document(theme: await pdfThema(), title: 'Steuer $jahr', author: 'Papiertiger');
  final summen = summenNachKategorie(posten);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    footer: (c) => pw.Text('Erstellt mit Papiertiger. Keine Steuerberatung, ohne Gewähr.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    build: (c) => [
      pw.Header(level: 0, text: 'Steuer-Unterlagen $jahr'),
      pw.Text('Stand ${_d(DateTime.now())} · ${posten.length} Posten'),
      pw.SizedBox(height: 10),
      pw.Text('Summen nach Kategorie', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
      pw.TableHelper.fromTextArray(
        headers: ['Kategorie', 'Summe'],
        data: [for (final e in summen.entries) [e.key, _euro(e.value)]],
        cellAlignments: {1: pw.Alignment.centerRight},
      ),
      if (werbung != null) ...[
        pw.SizedBox(height: 10),
        pw.Text('Werbungskosten (geschätzt)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
        pw.Bullet(text: 'Fahrten zur Arbeit: ${_euro(werbung.fahrt)}'),
        pw.Bullet(text: 'Homeoffice-Pauschale: ${_euro(werbung.homeoffice)}'),
        pw.Bullet(text: 'Arbeitsmittel und Fortbildung: ${_euro(werbung.weitere)}'),
        pw.Bullet(text: 'Zusammen: ${_euro(werbung.summe)} (Pauschbetrag: ${_euro(arbeitnehmerPauschbetrag)})'),
      ],
      pw.SizedBox(height: 10),
      pw.Text('Alle Posten', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
      pw.TableHelper.fromTextArray(
        headers: ['Datum', 'Beschreibung', 'Kategorie', 'Betrag'],
        data: [
          for (final p in posten)
            [_d(p.datum), p.vorschlag ? '${p.titel} (Vorschlag)' : p.titel, p.kategorie, p.betrag == null ? '–' : _euro(p.betrag!)],
        ],
        cellAlignments: {3: pw.Alignment.centerRight},
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  ));
  return _speichern(doc, 'Papiertiger Steuer $jahr');
}

/// Speichert Text als Datei (z. B. CSV) zum Teilen.
Future<File> textDatei(String name, String inhalt) async {
  final ordner = await getTemporaryDirectory();
  final datei = File('${ordner.path}/${_dateiname(name.replaceAll(RegExp(r'\.[a-z]+$'), ''))}${RegExp(r'\.[a-z]+$').firstMatch(name)?.group(0) ?? ''}');
  await datei.writeAsString(inhalt);
  return datei;
}

String _menge(double m) => m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(2).replaceAll('.', ',');

/// Rechnung oder Angebot als PDF mit Fenster-Anschrift, Positionen und Summen.
Future<File> rechnungAlsPdf(Rechnung r, Firma f, Kunde? k, {List<Rechnung> alle = const []}) async {
  final s = summenVon(r, kleinunternehmer: f.kleinunternehmer);
  final zahlen = zuZahlen(r, alle, kleinunternehmer: f.kleinunternehmer);
  final abschlaege = r.art == 'schluss' ? abschlaegeZu(r, alle) : <Rechnung>[];
  final ohnePreise = r.art == 'lieferschein';
  final qr = r.istRechnung && zahlen.brutto > 0
      ? giroCode(name: f.name, iban: f.iban, bic: f.bic, betrag: zahlen.brutto, zweck: '${r.artName} ${r.nummer}')
      : '';
  final titel = r.artName;
  final doc = pw.Document(theme: await pdfThema(), title: '$titel ${r.nummer}', author: f.name);
  final mm = PdfPageFormat.mm;
  const klein = pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700);
  const normal = pw.TextStyle(fontSize: 10);
  final fett = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  final fuss = [
    f.name,
    if (f.steuernummer.isNotEmpty) 'Steuernr. ${f.steuernummer}',
    if (f.ustId.isNotEmpty) 'USt-IdNr. ${f.ustId}',
    if (f.iban.isNotEmpty) 'IBAN ${f.iban}${f.bank.isNotEmpty ? ' (${f.bank})' : ''}',
    if (f.email.isNotEmpty) f.email,
    if (f.telefon.isNotEmpty) f.telefon,
  ].join('  ·  ');
  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(25 * mm, 15 * mm, 20 * mm, 20 * mm),
    ),
    footer: (c) => pw.Column(children: [
      pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      pw.Text(fuss, style: klein, textAlign: pw.TextAlign.center),
      pw.Text('Seite ${c.pageNumber} von ${c.pagesCount}', style: klein),
    ]),
    build: (c) => [
      pw.SizedBox(
        height: 30 * mm,
        child: pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text('${f.name}\n${f.adresse}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9.5)),
        ),
      ),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
          width: 85 * mm,
          height: 45 * mm,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text([f.name, ...f.adresse.split('\n')].where((z) => z.trim().isNotEmpty).join(' · '), style: klein, maxLines: 1),
            pw.SizedBox(height: 3 * mm),
            pw.Text('${k?.name ?? ''}\n${k?.adresse ?? ''}', style: const pw.TextStyle(fontSize: 11)),
          ]),
        ),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('$titel Nr. ${r.nummer}', style: fett),
            pw.Text('Datum: ${_d(r.datum)}', style: normal),
            if (r.leistungVon != null)
              pw.Text(
                  r.leistungBis == null || r.leistungBis == r.leistungVon
                      ? 'Leistungsdatum: ${_d(r.leistungVon!)}'
                      : 'Leistungszeitraum: ${_d(r.leistungVon!)} – ${_d(r.leistungBis!)}',
                  style: normal),
          ]),
        ),
      ]),
      pw.SizedBox(height: 6 * mm),
      pw.Text(titel, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4 * mm),
      if (ohnePreise)
        pw.TableHelper.fromTextArray(
          headers: ['Pos.', 'Beschreibung', 'Menge'],
          data: [
            for (var i = 0; i < r.positionen.length; i++)
              ['${i + 1}', r.positionen[i].text, '${_menge(r.positionen[i].menge)} ${r.positionen[i].einheit}'],
          ],
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignments: {0: pw.Alignment.centerLeft, 2: pw.Alignment.centerRight},
          columnWidths: {1: const pw.FlexColumnWidth(3)},
        )
      else
        pw.TableHelper.fromTextArray(
          headers: ['Pos.', 'Beschreibung', 'Menge', 'Einzelpreis', if (!f.kleinunternehmer) 'USt', 'Gesamt'],
          data: [
            for (var i = 0; i < r.positionen.length; i++)
              [
                '${i + 1}',
                r.positionen[i].aufmass.isEmpty
                    ? r.positionen[i].text
                    : '${r.positionen[i].text}\nAufmaß: ${aufmassText(r.positionen[i].aufmass)}',
                '${_menge(r.positionen[i].menge)} ${r.positionen[i].einheit}',
                _euro(r.positionen[i].preis),
                if (!f.kleinunternehmer) '${r.positionen[i].ustSatz} %',
                _euro(r.positionen[i].netto),
              ],
          ],
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          columnWidths: {1: const pw.FlexColumnWidth(3)},
        ),
      pw.SizedBox(height: 4 * mm),
      if (!ohnePreise)
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 80 * mm,
            child: pw.Column(children: [
              if (s.rabatt > 0) ...[
                _summenZeile('Zwischensumme', _euro(s.zwischensumme), normal),
                _summenZeile(
                    r.rabattProzent > 0 && r.rabattBetrag == 0
                        ? 'abzgl. ${_menge(r.rabattProzent)} % Rabatt'
                        : 'abzgl. Rabatt',
                    '-${_euro(s.rabatt)}',
                    normal),
              ],
              _summenZeile(f.kleinunternehmer ? 'Gesamtbetrag' : 'Summe netto', _euro(s.netto), normal),
              if (!f.kleinunternehmer)
                for (final e in s.ust.entries) _summenZeile('zzgl. ${e.key} % USt', _euro(e.value), normal),
              if (!f.kleinunternehmer) _summenZeile('Gesamtbetrag', _euro(s.brutto), fett),
              for (final a in abschlaege)
                _summenZeile('abzgl. Abschlagsrechnung ${a.nummer}',
                    '-${_euro(summenVon(a, kleinunternehmer: f.kleinunternehmer).brutto)}', normal),
              if (abschlaege.isNotEmpty) _summenZeile('Noch zu zahlen', _euro(zahlen.brutto), fett),
            ]),
          ),
        ),
      pw.SizedBox(height: 6 * mm),
      if (f.kleinunternehmer) pw.Text(kleinunternehmerHinweis, style: normal),
      if (r.art == 'kostenvoranschlag')
        pw.Text('Unverbindlicher Kostenvoranschlag. Abweichungen von mehr als 15 % teile ich Ihnen vorher mit.', style: normal)
      else if (r.istAngebot)
        pw.Text('Dieses Angebot gilt 30 Tage ab dem ${_d(r.datum)}.', style: normal)
      else if (r.art == 'auftragsbestaetigung')
        pw.Text('Vielen Dank für Ihren Auftrag. Hiermit bestätige ich die Ausführung der oben genannten Leistungen '
            'zu den genannten Preisen.', style: normal)
      else if (r.art == 'lieferschein') ...[
        pw.Text('Ware bzw. Leistung vollständig und in einwandfreiem Zustand erhalten:', style: normal),
        pw.SizedBox(height: 14 * mm),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Divider(thickness: 0.5),
            pw.Text('Ort, Datum', style: klein),
          ])),
          pw.SizedBox(width: 10 * mm),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Divider(thickness: 0.5),
            pw.Text('Unterschrift Empfänger', style: klein),
          ])),
        ]),
      ] else if (zahlen.brutto <= 0)
        pw.Text('Der Betrag ist durch die Abschlagszahlungen bereits beglichen.', style: normal)
      else
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Text(
                'Bitte überweisen Sie ${_euro(zahlen.brutto)} bis zum ${_d(faelligAm(r))}'
                '${f.iban.isEmpty ? '' : ' auf das Konto ${f.iban}'} unter Angabe der Rechnungsnummer ${r.nummer}.'
                '${qr.isEmpty ? '' : '\n\nBequem bezahlen: Den GiroCode mit Ihrer Banking-App scannen.'}',
                style: normal),
          ),
          if (qr.isNotEmpty) ...[
            pw.SizedBox(width: 6 * mm),
            pw.Column(children: [
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qr, width: 28 * mm, height: 28 * mm),
              pw.SizedBox(height: 1 * mm),
              pw.Text('GiroCode', style: klein),
            ]),
          ],
        ]),
      if (r.notiz.isNotEmpty) ...[pw.SizedBox(height: 4 * mm), pw.Text(r.notiz, style: normal)],
      pw.SizedBox(height: 6 * mm),
      if (r.art != 'lieferschein' && r.art != 'auftragsbestaetigung') pw.Text('Vielen Dank für Ihren Auftrag!', style: normal),
    ],
  ));
  return _speichern(doc, '$titel ${r.nummer} ${k?.name ?? ''}');
}

pw.Widget _summenZeile(String a, String b, pw.TextStyle st) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(children: [pw.Expanded(child: pw.Text(a, style: st)), pw.Text(b, style: st)]),
    );

/// Inventarliste mit Fotos, z. B. für die Hausratversicherung.
Future<File> inventarAlsPdf(List<Gegenstand> liste) async {
  final doc = pw.Document(theme: await pdfThema(), title: 'Inventar', author: 'Papiertiger');
  final summe = liste.fold(0.0, (s, g) => s + (g.preis ?? 0));
  final fotos = <(Gegenstand, pw.MemoryImage)>[];
  for (final g in liste) {
    if (g.bild == null) continue;
    final f = File(g.bild!);
    if (f.existsSync()) fotos.add((g, pw.MemoryImage(await f.readAsBytes())));
  }
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    footer: (c) => pw.Text('Erstellt mit Papiertiger am ${_d(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    build: (c) => [
      pw.Header(level: 0, text: 'Inventarliste'),
      pw.Text('${liste.length} Gegenstände · Gesamtwert ${_euro(summe)} (Kaufpreise)'),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: ['Gegenstand', 'Raum', 'Kaufdatum', 'Seriennummer', 'Preis'],
        data: [
          for (final g in liste)
            [g.name, g.raum, g.kaufdatum == null ? '' : _d(g.kaufdatum!), g.seriennummer, g.preis == null ? '' : _euro(g.preis!)],
        ],
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellAlignments: {4: pw.Alignment.centerRight},
      ),
      if (fotos.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text('Fotos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _orange)),
        for (var i = 0; i < fotos.length; i += 3)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              for (final (g, bild) in fotos.skip(i).take(3))
                pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 8),
                  child: pw.SizedBox(
                    width: 150,
                    child: pw.Column(children: [
                      pw.SizedBox(height: 110, child: pw.Image(bild, fit: pw.BoxFit.cover)),
                      pw.Text(g.name, style: const pw.TextStyle(fontSize: 8)),
                    ]),
                  ),
                ),
            ]),
          ),
      ],
    ],
  ));
  return _speichern(doc, 'Inventar ${_d(DateTime.now())}');
}

String _rtf(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r == 92 || r == 123 || r == 125) {
      b.write('\\${String.fromCharCode(r)}');
    } else if (r == 10) {
      b.write('\\par\n');
    } else if (r < 128) {
      b.writeCharCode(r);
    } else {
      // Unicode für Umlaute und andere Zeichen
      final v = r > 32767 ? r - 65536 : r;
      b.write('\\u$v?');
    }
  }
  return b.toString();
}

/// Text als Word-Datei (RTF – öffnet sich in Word, LibreOffice und Google Docs).
Future<File> alsWord(String titel, String text) async {
  final inhalt = '{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Arial;}}\\fs22\n${_rtf(text.replaceAll('\r\n', '\n'))}\n}';
  return textDatei('$titel.rtf', inhalt);
}

/// Belege mit Fotos als PDF, z. B. für die Steuerberatung.
Future<File> belegeAlsPdf(String titel, List<Beleg> belege) async {
  final doc = pw.Document(theme: await pdfThema(), title: titel, author: 'Papiertiger');
  final summe = belege.fold(0.0, (s, b) => s + (b.betrag ?? 0));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    footer: (c) => pw.Text('Erstellt mit Papiertiger am ${_d(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    build: (c) => [
      pw.Header(level: 0, text: titel),
      pw.Text('${belege.length} Belege · zusammen ${_euro(summe)}'),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: ['Nr.', 'Datum', 'Händler', 'Kategorie', 'Betrag'],
        data: [
          for (var i = 0; i < belege.length; i++)
            ['${i + 1}', _d(belege[i].datum), belege[i].haendler, belege[i].kategorie ?? '', belege[i].betrag == null ? '' : _euro(belege[i].betrag!)],
        ],
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellAlignments: {4: pw.Alignment.centerRight},
      ),
    ],
  ));
  for (var i = 0; i < belege.length; i++) {
    final b = belege[i];
    if (b.bild == null) continue;
    final f = File(b.bild!);
    if (!f.existsSync()) continue;
    final bild = pw.MemoryImage(await f.readAsBytes());
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (c) => pw.Column(children: [
        pw.Text('Beleg ${i + 1}: ${b.haendler}, ${_d(b.datum)}${b.betrag == null ? '' : ', ${_euro(b.betrag!)}'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Expanded(child: pw.Image(bild, fit: pw.BoxFit.contain)),
      ]),
    ));
  }
  return _speichern(doc, titel);
}

/// Regiebericht oder Abnahmeprotokoll mit Unterschrift des Kunden.
Future<File> berichtAlsPdf(Baubericht b, Projekt p, Firma f, Kunde? k) async {
  final doc = pw.Document(theme: await pdfThema(), title: '${b.titel} ${p.name}', author: f.name);
  const normal = pw.TextStyle(fontSize: 10);
  final fett = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  pw.MemoryImage? unterschrift;
  if (b.unterschrift != null && File(b.unterschrift!).existsSync()) {
    unterschrift = pw.MemoryImage(await File(b.unterschrift!).readAsBytes());
  }
  pw.Widget feld(String titel, String text) => text.trim().isEmpty
      ? pw.SizedBox()
      : pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(titel, style: fett),
            pw.Text(text, style: normal),
          ]),
        );
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (c) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Text(b.titel, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('${f.name}\n${f.adresse}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
      ]),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        data: [
          ['Projekt', p.name],
          if (p.adresse.isNotEmpty) ['Ort', p.adresse],
          ['Auftraggeber', [k?.name ?? '', k?.adresse ?? ''].where((x) => x.isNotEmpty).join(', ')],
          ['Datum', _d(b.datum)],
          if (b.art == 'regie' && b.stunden > 0) ['Arbeitszeit', '${_menge(b.stunden)} Std.'],
          if (b.personen.isNotEmpty) ['Ausgeführt von', b.personen],
        ],
        cellStyle: normal,
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: {0: const pw.FixedColumnWidth(110)},
      ),
      pw.SizedBox(height: 12),
      if (b.art == 'regie') ...[
        feld('Ausgeführte Zusatzarbeiten', b.text),
        feld('Verwendetes Material', b.material),
        pw.Text('Die oben genannten Arbeiten wurden zusätzlich zum Auftrag ausgeführt und werden nach Aufwand berechnet.',
            style: normal),
      ] else ...[
        feld('Abgenommene Leistung', b.text),
        pw.Text(b.maengel.trim().isEmpty ? 'Die Leistung wurde ohne Mängel abgenommen.' : 'Die Leistung wurde mit folgenden Mängeln abgenommen:',
            style: fett),
        if (b.maengel.trim().isNotEmpty) pw.Text(b.maengel, style: normal),
        pw.SizedBox(height: 6),
        pw.Text('Mit der Abnahme beginnt die Gewährleistungsfrist.', style: normal),
      ],
      pw.SizedBox(height: 30),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('${p.adresse.isEmpty ? '' : '${p.adresse.split(',').last.trim()}, '}${_d(b.unterschriebenAm ?? b.datum)}', style: normal),
            pw.Divider(thickness: 0.5),
            pw.Text('Ort, Datum', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ]),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (unterschrift != null) pw.Image(unterschrift, height: 45) else pw.SizedBox(height: 45),
            pw.Divider(thickness: 0.5),
            pw.Text('Unterschrift Auftraggeber${b.unterschriftName.isEmpty ? '' : ' (${b.unterschriftName})'}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ]),
        ),
      ]),
    ],
  ));
  return _speichern(doc, '${b.titel} ${p.name} ${_d(b.datum)}');
}

/// Bautagebuch mit Fotos des jeweiligen Tages.
Future<File> bautagebuchAlsPdf(Projekt p, Firma f, Kunde? k) async {
  final doc = pw.Document(theme: await pdfThema(), title: 'Bautagebuch ${p.name}', author: f.name);
  const normal = pw.TextStyle(fontSize: 10);
  final fett = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
  final tage = [...p.tagebuch]..sort((a, b) => a.datum.compareTo(b.datum));
  bool gleicherTag(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  final bilder = <Baufoto, pw.MemoryImage>{};
  for (final foto in p.fotos) {
    final datei = File(foto.pfad);
    if (datei.existsSync()) bilder[foto] = pw.MemoryImage(await datei.readAsBytes());
  }
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    footer: (c) => pw.Text('${f.name} · Bautagebuch ${p.name} · Seite ${c.pageNumber}/${c.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
    build: (c) => [
      pw.Text('Bautagebuch', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('${p.name}${p.adresse.isEmpty ? '' : ' · ${p.adresse}'}${k == null ? '' : ' · ${k.name}'}', style: normal),
      pw.SizedBox(height: 10),
      for (final t in tage) ...[
        pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text('${_d(t.datum)}${t.wetter.isEmpty ? '' : '  ·  Wetter: ${t.wetter}'}', style: fett),
        ),
        pw.SizedBox(height: 4),
        if (t.personen.isNotEmpty) pw.Text('Anwesend: ${t.personen}', style: normal),
        if (t.arbeiten.isNotEmpty) pw.Text('Arbeiten: ${t.arbeiten}', style: normal),
        if (t.material.isNotEmpty) pw.Text('Material: ${t.material}', style: normal),
        if (t.besonderheiten.isNotEmpty) pw.Text('Besonderheiten: ${t.besonderheiten}', style: normal),
        pw.Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in bilder.entries)
            if (gleicherTag(e.key.datum, t.datum))
              pw.Column(children: [
                pw.Image(e.value, width: 160, height: 120, fit: pw.BoxFit.cover),
                if (e.key.text.isNotEmpty) pw.Text(e.key.text, style: const pw.TextStyle(fontSize: 8)),
              ]),
        ]),
        pw.SizedBox(height: 10),
      ],
    ],
  ));
  return _speichern(doc, 'Bautagebuch ${p.name}');
}

/// Arbeitsauftrag für Mitarbeiter: wo, wann, wer, was – ohne Preise.
Future<File> arbeitsauftragAlsPdf(Projekt p, Firma f, Kunde? k, {List<Einsatz> einsaetze = const [], Rechnung? auftrag}) async {
  final doc = pw.Document(theme: await pdfThema(), title: 'Arbeitsauftrag ${p.name}', author: f.name);
  const normal = pw.TextStyle(fontSize: 10);
  final fett = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
  final plan = einsaetze.where((e) => e.projektId == p.id).toList()..sort((a, b) => a.von.compareTo(b.von));
  final offen = p.aufgaben.where((a) => !a.erledigt).toList();
  pw.Widget titel(String t) => pw.Padding(padding: const pw.EdgeInsets.only(top: 12, bottom: 4), child: pw.Text(t, style: fett));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (c) => [
      pw.Row(children: [
        pw.Expanded(child: pw.Text('Arbeitsauftrag', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text(f.name, style: normal),
      ]),
      pw.SizedBox(height: 8),
      pw.Text(p.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      if (p.adresse.isNotEmpty) pw.Text('Ort: ${p.adresse}', style: normal),
      if (k != null) pw.Text('Kunde: ${k.name}${k.email.isEmpty ? '' : ' · ${k.email}'}', style: normal),
      if (p.notiz.isNotEmpty) pw.Text(p.notiz, style: normal),
      if (plan.isNotEmpty) ...[
        titel('Einsatz'),
        for (final e in plan)
          pw.Text('${_d(e.von)}${e.bis.isAfter(e.von) ? ' – ${_d(e.bis)}' : ''}: ${e.personen.join(', ')}${e.notiz.isEmpty ? '' : ' (${e.notiz})'}',
              style: normal),
      ],
      if (auftrag != null && auftrag.positionen.isNotEmpty) ...[
        titel('Leistungen'),
        pw.TableHelper.fromTextArray(
          headers: ['', 'Leistung', 'Menge'],
          data: [
            for (final x in auftrag.positionen)
              ['[ ]', x.aufmass.isEmpty ? x.text : '${x.text}\nAufmaß: ${aufmassText(x.aufmass)}', '${_menge(x.menge)} ${x.einheit}'],
          ],
          cellStyle: normal,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          columnWidths: {0: const pw.FixedColumnWidth(18), 1: const pw.FlexColumnWidth(4), 2: const pw.FlexColumnWidth(1)},
        ),
      ],
      if (p.material.isNotEmpty) ...[
        titel('Material'),
        for (final m in p.material)
          pw.Text('[ ] ${_menge(m.menge)} ${m.einheit} ${m.text}${m.bestellt ? '' : '  (noch nicht bestellt)'}', style: normal),
      ],
      if (offen.isNotEmpty) ...[
        titel('Aufgaben'),
        for (final a in offen) pw.Text('[ ] ${a.text}${a.person.isEmpty ? '' : ' -> ${a.person}'}', style: normal),
      ],
      titel('Rückmeldung'),
      pw.Text('Arbeitszeit, Material und Besonderheiten bitte in der Stempeluhr bzw. im Bautagebuch erfassen.', style: normal),
    ],
  ));
  return _speichern(doc, 'Arbeitsauftrag ${p.name}');
}

/// Tabellarischer Lebenslauf (ohne Unterschrift, mit Foto falls vorhanden).
Future<File> lebenslaufAlsPdf(Lebenslauf l, Profil p) async {
  final doc = pw.Document(theme: await pdfThema(), title: 'Lebenslauf ${p.name}', author: p.name);
  const normal = pw.TextStyle(fontSize: 10);
  const grau = pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700);
  final fett = pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold);
  pw.MemoryImage? foto;
  if (l.foto != null && File(l.foto!).existsSync()) foto = pw.MemoryImage(await File(l.foto!).readAsBytes());
  String monat(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.year}';
  pw.Widget abschnitt(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(t, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _orange)),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        ]),
      );
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
    build: (c) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Lebenslauf', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(p.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text(p.adresse.replaceAll('\n', ', '), style: normal),
            if (l.telefon.isNotEmpty) pw.Text('Telefon: ${l.telefon}', style: normal),
            if (l.email.isNotEmpty) pw.Text('E-Mail: ${l.email}', style: normal),
            if (l.geburtsdatum != null) pw.Text('Geboren am ${_d(l.geburtsdatum!)}', style: normal),
          ]),
        ),
        if (foto != null) pw.Image(foto, width: 90, height: 115, fit: pw.BoxFit.cover),
      ]),
      if (l.kurzprofil.isNotEmpty) ...[pw.SizedBox(height: 10), pw.Text(l.kurzprofil, style: normal)],
      for (final art in stationsArten)
        if (l.stationen.any((s) => s.art == art)) ...[
          abschnitt(art == 'Beruf' ? 'Berufserfahrung' : art),
          for (final s in (l.stationen.where((s) => s.art == art).toList()
            ..sort((a, b) => (b.von ?? DateTime(0)).compareTo(a.von ?? DateTime(0)))))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.SizedBox(
                  width: 100,
                  child: pw.Text(s.von == null ? '' : '${monat(s.von!)} – ${s.bis == null ? 'heute' : monat(s.bis!)}', style: grau),
                ),
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(s.titel, style: fett),
                    if (s.ort.isNotEmpty) pw.Text(s.ort, style: normal),
                    if (s.text.isNotEmpty) pw.Text(s.text, style: normal),
                  ]),
                ),
              ]),
            ),
        ],
      if (l.kenntnisse.isNotEmpty) ...[abschnitt('Kenntnisse'), pw.Text(l.kenntnisse.join(' · '), style: normal)],
      if (l.sprachen.isNotEmpty) ...[abschnitt('Sprachen'), pw.Text(l.sprachen.join(' · '), style: normal)],
      pw.SizedBox(height: 24),
      pw.Text('${p.adresse.split(RegExp(r'[\n,]')).last.replaceAll(RegExp(r'^\s*\d{5}\s*'), '').trim()}, ${_d(DateTime.now())}', style: normal),
    ],
  ));
  return _speichern(doc, 'Lebenslauf ${p.name}');
}

/// Ausgefülltes Formular: jede Seite als Bild, darauf die eingetragenen Texte und Unterschriften.
Future<File> formularAlsPdf(List<String> seitenBilder, List<FormularEintrag> eintraege, {String titel = 'Formular'}) async {
  final doc = pw.Document(theme: await pdfThema(), title: titel, author: 'Papiertiger');
  for (var i = 0; i < seitenBilder.length; i++) {
    final datei = File(seitenBilder[i]);
    if (!datei.existsSync()) continue;
    final bytes = await datei.readAsBytes();
    final bild = pw.MemoryImage(bytes);
    final w = (bild.width ?? 1240).toDouble(), h = (bild.height ?? 1754).toDouble();
    // Seite im Seitenverhältnis des Bildes, Breite wie A4
    final breite = PdfPageFormat.a4.width;
    final hoehe = breite * h / w;
    final hier = eintraege.where((e) => e.seite == i).toList();
    final bilder = <FormularEintrag, pw.MemoryImage>{};
    for (final e in hier.where((e) => e.bild != null)) {
      final f = File(e.bild!);
      if (f.existsSync()) bilder[e] = pw.MemoryImage(await f.readAsBytes());
    }
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(breite, hoehe),
      margin: pw.EdgeInsets.zero,
      build: (c) => pw.Stack(children: [
        pw.Positioned.fill(child: pw.Image(bild, fit: pw.BoxFit.fill)),
        for (final e in hier)
          pw.Positioned(
            left: e.x * breite,
            top: e.y * hoehe,
            child: e.bild != null
                ? (bilder[e] == null ? pw.SizedBox() : pw.Image(bilder[e]!, height: e.groesse * breite * 3))
                : pw.Text(e.text, style: pw.TextStyle(fontSize: e.groesse * breite, color: PdfColors.blue900)),
          ),
      ]),
    ));
  }
  return _speichern(doc, '$titel ausgefüllt');
}
