import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/postfach.dart';
import 'package:papiertiger/logic/email.dart';
import 'package:papiertiger/logic/imap.dart';
import 'package:papiertiger/logic/postfach_pruefung.dart';

String _mail(String von, String betreff, String text, {String? anhang}) {
  final kopf = 'From: $von\r\nTo: florian@web.de\r\nSubject: $betreff\r\nDate: Sun, 1 Nov 2026 09:12:00 +0100\r\n';
  if (anhang == null) return '${kopf}Content-Type: text/plain; charset=utf-8\r\n\r\n$text\r\n';
  return '${kopf}Content-Type: multipart/mixed; boundary="xx"\r\n\r\n'
      '--xx\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n$text\r\n'
      '--xx\r\nContent-Type: application/pdf; name="$anhang"\r\nContent-Disposition: attachment; filename="$anhang"\r\n'
      'Content-Transfer-Encoding: base64\r\n\r\nJVBERi0xLjQK\r\n--xx--\r\n';
}

Mail _lesen(String roh) => emlLesen(Uint8List.fromList(utf8.encode(roh)));

/// Ein winziger IMAP-Server zum Testen (ohne TLS). Merkt sich alle Befehle.
class _TestServer {
  _TestServer(this.mails, {this.passwort = 'geheim', this.validity = 7});

  final Map<int, String> mails;
  final String passwort;
  final int validity;
  final befehle = <String>[];
  late ServerSocket _server;

  int get port => _server.port;

  Future<void> starten() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((s) {
      s.add(utf8.encode('* OK Test bereit\r\n'));
      var puffer = '';
      s.listen((d) {
        puffer += utf8.decode(d);
        while (puffer.contains('\r\n')) {
          final i = puffer.indexOf('\r\n');
          final z = puffer.substring(0, i);
          puffer = puffer.substring(i + 2);
          _antworten(s, z);
        }
      });
    });
  }

  void _antworten(Socket s, String z) {
    final teile = z.split(' ');
    final tag = teile.first;
    final befehl = teile.skip(1).join(' ');
    befehle.add(befehl);
    void ok([String text = 'OK fertig']) => s.add(utf8.encode('$tag $text\r\n'));
    if (befehl.startsWith('LOGIN')) {
      befehl.contains('"$passwort"') ? ok() : ok('NO [AUTHENTICATIONFAILED] falsch');
    } else if (befehl.startsWith('EXAMINE')) {
      s.add(utf8.encode('* ${mails.length} EXISTS\r\n* OK [UIDVALIDITY $validity] uids\r\n'));
      ok('OK [READ-ONLY] fertig');
    } else if (befehl.startsWith('UID SEARCH UID')) {
      final ab = int.parse(befehl.split(' ').last.split(':').first);
      final treffer = mails.keys.where((u) => u >= ab).toList();
      // Wie echte Server: bei „n:*“ kommt die letzte Nachricht auch, wenn n größer ist
      if (treffer.isEmpty && mails.isNotEmpty) treffer.add(mails.keys.last);
      s.add(utf8.encode('* SEARCH ${treffer.join(' ')}\r\n'));
      ok();
    } else if (befehl.startsWith('UID SEARCH')) {
      s.add(utf8.encode('* SEARCH ${mails.keys.join(' ')}\r\n'));
      ok();
    } else if (befehl.startsWith('UID FETCH')) {
      final uid = int.parse(teile[3]);
      final m = utf8.encode(mails[uid]!);
      if (befehl.contains('RFC822.SIZE')) {
        s.add(utf8.encode('* 1 FETCH (UID $uid RFC822.SIZE ${m.length})\r\n'));
      } else {
        s.add(utf8.encode('* 1 FETCH (UID $uid BODY[] {${m.length}}\r\n'));
        s.add(m);
        s.add(utf8.encode(')\r\n'));
      }
      ok();
    } else if (befehl.startsWith('LOGOUT')) {
      s.add(utf8.encode('* BYE\r\n'));
      ok();
      s.close();
    } else {
      ok('BAD unbekannt');
    }
  }

  Future<void> stoppen() => _server.close();
}

void main() {
  group('Server erkennen', () {
    test('WEB.DE, GMX, Gmail, eigene Domain, Outlook', () {
      expect(serverFuer('bender-florian41@web.de').server, 'imap.web.de');
      expect(serverFuer('x@gmx.de').server, 'imap.gmx.net');
      expect(serverFuer('x@gmail.com').server, 'imap.gmail.com');
      expect(serverFuer('info@meine-firma.de').server, 'imap.meine-firma.de');
      expect(serverFuer('x@outlook.de').moeglich, isFalse);
    });
  });

  group('Wichtige E-Mails erkennen', () {
    final heute = DateTime(2026, 11, 1);
    test('Rechnung mit Betrag', () {
      final e = mailEinordnen(
          _lesen(_mail('Telekom <rechnung@telekom.de>', 'Ihre Rechnung für November',
              'Rechnungsbetrag: 49,99 € wird am 15.11.2026 abgebucht.')),
          heute: heute);
      expect(e?.art, 'rechnung');
      expect(e?.betrag, 49.99);
    });
    test('Rechnung nur am PDF-Namen erkannt', () {
      final e = mailEinordnen(
          _lesen(_mail('Shop <info@shop.de>', 'Ihre Bestellung 4711', 'Danke für Ihren Einkauf.', anhang: 'Rechnung_4711.pdf')),
          heute: heute);
      expect(e?.art, 'rechnung');
    });
    test('Mahnung, Behörde, Vertrag, Briefankündigung', () {
      expect(mailEinordnen(_lesen(_mail('a@b.de', '2. Mahnung', 'Bitte zahlen Sie 20,00 €')), heute: heute)?.art, 'mahnung');
      expect(mailEinordnen(_lesen(_mail('noreply@elster.de', 'Neue Nachricht in Ihrem Postfach', 'Bescheid liegt bereit')), heute: heute)?.art,
          'behoerde');
      expect(mailEinordnen(_lesen(_mail('Strom AG <a@strom.de>', 'Preisanpassung zum 01.01.2027', 'Neue Preise')), heute: heute)?.art,
          'vertrag');
      expect(
          mailEinordnen(_lesen(_mail('Deutsche Post <briefankuendigung@deutschepost.de>', 'Heute kommt Post', 'Bild')), heute: heute)?.art,
          'briefankuendigung');
    });
    test('Newsletter und Private werden nicht gemeldet', () {
      expect(mailEinordnen(_lesen(_mail('Shop <news@shop.de>', 'Newsletter: 20 % Rabatt', 'Jetzt kaufen'))), isNull);
      expect(mailEinordnen(_lesen(_mail('Oma <oma@web.de>', 'Sonntag Kuchen?', 'Kommst du?'))), isNull);
    });
    test('Absendername', () {
      expect(absenderName('"Telekom Deutschland" <rechnung@telekom.de>'), 'Telekom Deutschland');
      expect(absenderName('<a@b.de>'), 'a@b.de');
      expect(absenderName('a@b.de'), 'a@b.de');
    });
  });

  group('Postfach nachsehen (Test-Server)', () {
    late _TestServer server;
    setUp(() async {
      server = _TestServer({
        3: _mail('Oma <oma@web.de>', 'Sonntag', 'Kuchen?'),
        5: _mail('Telekom <rechnung@telekom.de>', 'Ihre Rechnung', 'Betrag: 49,99 €'),
        8: _mail('Inkasso <a@inkasso.de>', 'Letzte Mahnung', 'Offen: 120,00 €'),
      });
      await server.starten();
    });
    tearDown(() => server.stoppen());

    Future<ImapVerbindung> verbinder(PostfachKonto k) => ImapVerbindung.verbinden('127.0.0.1', server.port, tls: false);

    PostfachKonto konto({String passwort = 'geheim'}) =>
        PostfachKonto(adresse: 'f@web.de', benutzer: 'f@web.de', passwort: passwort, server: 'x');

    test('meldet nur Wichtiges, merkt sich den Stand, liest nur', () async {
      final p = Postfach(konto: konto());
      final neu = await postfachPruefen(p, verbinder: verbinder, jetzt: DateTime(2026, 11, 1));
      expect(neu.map((h) => h.art), ['rechnung', 'mahnung']);
      expect(neu.first.absender, 'Telekom');
      expect(neu.first.betrag, 49.99);
      expect(p.konto!.letzteUid, 8);
      expect(p.konto!.fehler, isNull);
      // Schreibgeschützt geöffnet und nur mit PEEK geladen
      expect(server.befehle.where((b) => b.startsWith('SELECT')), isEmpty);
      expect(server.befehle.where((b) => b.contains('FETCH') && !b.contains('PEEK') && !b.contains('SIZE')), isEmpty);
      expect(server.befehle.any((b) => b.contains('STORE') || b.contains('EXPUNGE') || b.contains('APPEND')), isFalse);

      // Zweiter Durchgang: nichts Neues, nichts doppelt
      final nochmal = await postfachPruefen(p, verbinder: verbinder, jetzt: DateTime(2026, 11, 1, 1));
      expect(nochmal, isEmpty);
      expect(p.hinweise.length, 2);

      // Ganze Mail zum Übernehmen
      final roh = await mailLaden(p.konto!, 5, verbinder: verbinder);
      expect(emlLesen(roh!).betreff, 'Ihre Rechnung');
    });

    test('falsches Passwort wird verständlich gemeldet', () async {
      final p = Postfach(konto: konto(passwort: 'falsch'));
      final neu = await postfachPruefen(p, verbinder: verbinder);
      expect(neu, isEmpty);
      expect(p.konto!.fehler, contains('Passwort'));
      await expectLater(postfachTesten(konto(passwort: 'falsch'), verbinder: verbinder), throwsA(isA<ImapFehler>()));
    });

    test('Speichern und Laden', () {
      final p = Postfach(konto: konto(), hinweise: [MailHinweis(uid: 5, art: 'rechnung', absender: 'T', betreff: 'R', betrag: 1.5)]);
      final q = Postfach.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(q.konto!.passwort, 'geheim');
      expect(q.neue.single.betrag, 1.5);
    });
  });

  test('Text der Benachrichtigung', () {
    final (t, x) = hinweisText([MailHinweis(uid: 1, art: 'rechnung', absender: 'Telekom', betreff: '', betrag: 49.99, frist: DateTime(2026, 11, 15))]);
    expect(t, 'Neu im Postfach: Rechnung');
    expect(x, 'Rechnung von Telekom · 49,99 € · bis 15.11.');
  });
}
