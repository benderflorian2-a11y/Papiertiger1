import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/logic/datei_import.dart';
import 'package:papiertiger/logic/email.dart';

Uint8List _eml(String s) => Uint8List.fromList(latin1.encode(s.replaceAll('\n', '\r\n')));

void main() {
  test('E-Mail mit Text, HTML-Alternative und PDF-Anhang', () {
    final betreff = base64.encode(utf8.encode('Ihr Steuerbescheid für 2025'));
    final mail = emlLesen(_eml('''
From: =?UTF-8?Q?Finanzamt_K=C3=B6ln?= <poststelle@fa-koeln.de>
To: florian@example.de
Subject: =?UTF-8?B?$betreff?=
Date: Tue, 28 Oct 2026 10:15:00 +0100
MIME-Version: 1.0
Content-Type: multipart/mixed;
 boundary="AAA"

--AAA
Content-Type: multipart/alternative; boundary="BBB"

--BBB
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: quoted-printable

Sehr geehrter Herr Bender,
bitte zahlen Sie bis zum 15.11.2026 den Betrag von 120,00 =E2=82=AC. Mit freundl=
ichen Gr=C3=BC=C3=9Fen
--BBB
Content-Type: text/html; charset=utf-8

<p>HTML-Version</p>
--BBB--
--AAA
Content-Type: application/pdf; name="Bescheid.pdf"
Content-Disposition: attachment; filename="Bescheid.pdf"
Content-Transfer-Encoding: base64

JVBERi0xLjQK
--AAA--
'''));
    expect(mail.von, 'Finanzamt Köln <poststelle@fa-koeln.de>');
    expect(mail.betreff, 'Ihr Steuerbescheid für 2025');
    expect(mail.datum, DateTime(2026, 10, 28, 10, 15));
    expect(mail.text, contains('120,00 €. Mit freundlichen Grüßen'));
    expect(mail.text, isNot(contains('HTML-Version')));
    expect(mail.anhaenge.single.name, 'Bescheid.pdf');
    expect(mail.anhaenge.single.istPdf, isTrue);
    expect(latin1.decode(mail.anhaenge.single.daten), '%PDF-1.4\n');
    expect(mail.alsBrieftext, startsWith('Von: Finanzamt Köln'));
    expect(mail.alsBrieftext, contains('Datum: 28.10.2026'));
    expect(mail.alsBrieftext, contains('Betreff: Ihr Steuerbescheid für 2025'));
  });

  test('Nur HTML, Latin-1', () {
    final mail = emlLesen(_eml('From: Inkasso <info@inkasso.example>\n'
        'Subject: Mahnung\n'
        'Content-Type: text/html; charset=iso-8859-1\n'
        '\n'
        '<html><head><style>p{color:red}</style></head><body>'
        '<p>Sehr geehrte Damen und Herren,</p><p>bitte zahlen Sie 50,00 &euro; bis zum 01.12.2026.<br>Gr\xfc\xdfe</p>'
        '</body></html>\n'));
    expect(mail.text, contains('bitte zahlen Sie 50,00 € bis zum 01.12.2026.\nGrüße'));
    expect(mail.text, isNot(contains('color')));
    expect(mail.anhaenge, isEmpty);
  });

  test('Dateiart erkennen', () {
    expect(dateiArt('Bescheid.PDF', null), DateiArt.pdf);
    expect(dateiArt('x.eml', 'application/octet-stream'), DateiArt.email);
    expect(dateiArt('foto', 'image/jpeg'), DateiArt.bild);
    expect(dateiArt('a.zip', 'application/zip'), DateiArt.unbekannt);
  });
}
