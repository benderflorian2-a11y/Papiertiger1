import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/geschaeft.dart';
import '../data/haushalt.dart';
import '../data/models.dart';
import 'kommunikation.dart';
import 'rechnungen.dart';
import 'ordnung.dart';
import 'steuer.dart';

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

/// Antwort als richtiger Brief nach DIN 5008 (Form B): Anschrift passt ins
/// Fenster eines DIN-lang-Umschlags, mit Falz- und Lochmarken.
Future<File> antwortAlsPdf(String text, {String titel = 'Antwort'}) async {
  final t = briefTeile(text);
  final doc = pw.Document(title: titel, author: 'Papiertiger');
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
  final doc = pw.Document(title: 'Steuer $jahr', author: 'Papiertiger');
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
  final doc = pw.Document(title: '$titel ${r.nummer}', author: f.name);
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
                r.positionen[i].text,
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
  final doc = pw.Document(title: 'Inventar', author: 'Papiertiger');
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
  final doc = pw.Document(title: titel, author: 'Papiertiger');
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
