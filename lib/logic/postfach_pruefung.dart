/// Postfach-Verknüpfung: Server erkennen, wichtige E-Mails erkennen (Rechnung, Mahnung, Behörde,
/// Vertragsänderung, Briefankündigung der Deutschen Post) und neue davon melden.
/// Es wird nur gelesen – nichts gelöscht, verschoben, als gelesen markiert oder verschickt.
library;

import 'dart:typed_data';

import '../data/postfach.dart';
import 'brief_analyse.dart';
import 'email.dart';
import 'imap.dart';

class MailServer {
  const MailServer(this.server, {this.port = 993, this.name = '', this.hinweis = '', this.moeglich = true});

  final String server;
  final int port;
  final String name;

  /// Was man vorher im Postfach einstellen muss.
  final String hinweis;

  /// false = dieser Anbieter lässt Apps nicht mit Passwort hinein.
  final bool moeglich;
}

const _unitedInternet =
    'Einmal im Postfach einschalten: Einstellungen → POP3/IMAP Abruf → „Zugriff über POP3 und IMAP erlauben“. '
    'Mit Zwei-Faktor-Anmeldung brauchst du dort ein „anwendungsspezifisches Passwort“.';

/// Bekannte Anbieter nach dem Teil hinter dem @.
const mailAnbieter = <String, MailServer>{
  'web.de': MailServer('imap.web.de', name: 'WEB.DE', hinweis: _unitedInternet),
  'gmx.de': MailServer('imap.gmx.net', name: 'GMX', hinweis: _unitedInternet),
  'gmx.net': MailServer('imap.gmx.net', name: 'GMX', hinweis: _unitedInternet),
  'gmx.at': MailServer('imap.gmx.net', name: 'GMX', hinweis: _unitedInternet),
  'gmx.ch': MailServer('imap.gmx.net', name: 'GMX', hinweis: _unitedInternet),
  'gmail.com': MailServer('imap.gmail.com',
      name: 'Gmail',
      hinweis: 'Google braucht ein App-Passwort: Google-Konto → Sicherheit → Bestätigung in zwei Schritten → App-Passwörter.'),
  'googlemail.com': MailServer('imap.gmail.com',
      name: 'Gmail',
      hinweis: 'Google braucht ein App-Passwort: Google-Konto → Sicherheit → Bestätigung in zwei Schritten → App-Passwörter.'),
  't-online.de': MailServer('secureimap.t-online.de',
      name: 'Telekom', hinweis: 'Nimm das „E-Mail-Passwort“ aus dem Telekom-Kundencenter, nicht dein Login-Passwort.'),
  'magenta.de': MailServer('secureimap.t-online.de',
      name: 'Telekom', hinweis: 'Nimm das „E-Mail-Passwort“ aus dem Telekom-Kundencenter, nicht dein Login-Passwort.'),
  'icloud.com': MailServer('imap.mail.me.com',
      name: 'iCloud', hinweis: 'Apple braucht ein app-spezifisches Passwort (account.apple.com → Anmelden und Sicherheit).'),
  'me.com': MailServer('imap.mail.me.com',
      name: 'iCloud', hinweis: 'Apple braucht ein app-spezifisches Passwort (account.apple.com → Anmelden und Sicherheit).'),
  'yahoo.com': MailServer('imap.mail.yahoo.com', name: 'Yahoo', hinweis: 'Yahoo braucht ein App-Passwort (Kontosicherheit).'),
  'yahoo.de': MailServer('imap.mail.yahoo.com', name: 'Yahoo', hinweis: 'Yahoo braucht ein App-Passwort (Kontosicherheit).'),
  'freenet.de': MailServer('mx.freenet.de', name: 'freenet'),
  'posteo.de': MailServer('posteo.de', name: 'Posteo'),
  'mailbox.org': MailServer('imap.mailbox.org', name: 'mailbox.org'),
  'outlook.com': MailServer('outlook.office365.com', name: 'Outlook', moeglich: false),
  'outlook.de': MailServer('outlook.office365.com', name: 'Outlook', moeglich: false),
  'hotmail.com': MailServer('outlook.office365.com', name: 'Outlook', moeglich: false),
  'hotmail.de': MailServer('outlook.office365.com', name: 'Outlook', moeglich: false),
  'live.de': MailServer('outlook.office365.com', name: 'Outlook', moeglich: false),
  'live.com': MailServer('outlook.office365.com', name: 'Outlook', moeglich: false),
};

/// Schritt-für-Schritt-Hilfe zu einem Anbieter mit Direktlinks.
class AnbieterHilfe {
  const AnbieterHilfe(this.name, this.domain, this.schritte, this.links, {this.moeglich = true});

  final String name;

  /// Beispiel-Endung der Adresse (für die Vorauswahl).
  final String domain;
  final List<String> schritte;

  /// (Beschriftung, Adresse) – öffnet die passende Seite direkt.
  final List<(String, String)> links;
  final bool moeglich;
}

const anbieterHilfen = <AnbieterHilfe>[
  AnbieterHilfe('Gmail', 'gmail.com', [
    'Tippe unten auf „Zwei-Schritt-Bestätigung“ und schalte sie ein (falls noch nicht geschehen).',
    'Tippe auf „App-Passwort erstellen“, gib einen Namen wie „Papiertiger“ ein und kopiere das 16-stellige Passwort.',
    'Komm hierher zurück, tippe bei „Passwort“ auf das Einfügen-Symbol und dann auf Verknüpfen.',
  ], [
    ('Zwei-Schritt-Bestätigung einschalten', 'https://myaccount.google.com/signinoptions/twosv'),
    ('App-Passwort erstellen', 'https://myaccount.google.com/apppasswords'),
  ]),
  AnbieterHilfe('GMX', 'gmx.de', [
    'Melde dich bei GMX an und erlaube unter E-Mail › Einstellungen › POP3/IMAP Abruf den Zugriff über IMAP.',
    'Hast du die Zwei-Faktor-Anmeldung an, erstelle dort ein „anwendungsspezifisches Passwort“. Sonst genügt dein normales Passwort.',
    'Komm zurück, trag Adresse und Passwort ein und tippe auf Verknüpfen.',
  ], [
    ('GMX öffnen', 'https://www.gmx.net'),
    ('Anleitung von GMX: IMAP einschalten', 'https://hilfe.gmx.net/pop-imap/einschalten.html'),
  ]),
  AnbieterHilfe('WEB.DE', 'web.de', [
    'Melde dich bei WEB.DE an und erlaube unter E-Mail › Einstellungen › POP3/IMAP Abruf den Zugriff über IMAP.',
    'Hast du die Zwei-Faktor-Anmeldung an, erstelle dort ein „anwendungsspezifisches Passwort“. Sonst genügt dein normales Passwort.',
    'Komm zurück, trag Adresse und Passwort ein und tippe auf Verknüpfen.',
  ], [
    ('WEB.DE öffnen', 'https://web.de'),
    ('Anleitung von WEB.DE: IMAP einschalten', 'https://hilfe.web.de/pop-imap/einschalten.html'),
  ]),
  AnbieterHilfe('Telekom / T-Online', 't-online.de', [
    'Öffne das E-Mail-Center der Telekom und melde dich an.',
    'Lege im Kundencenter ein eigenes „E-Mail-Passwort“ fest. Das normale Login-Passwort funktioniert hier nicht.',
    'Komm zurück, trag Adresse und dieses E-Mail-Passwort ein und tippe auf Verknüpfen.',
  ], [
    ('E-Mail-Center öffnen', 'https://email.t-online.de'),
  ]),
  AnbieterHilfe('iCloud', 'icloud.com', [
    'Melde dich bei deinem Apple-Konto an und öffne „Anmelden und Sicherheit“ › „App-spezifische Passwörter“.',
    'Erstelle ein Passwort mit dem Namen „Papiertiger“ und kopiere es.',
    'Komm zurück, füge es bei „Passwort“ ein und tippe auf Verknüpfen.',
  ], [
    ('Apple-Konto öffnen', 'https://account.apple.com/account/manage'),
  ]),
  AnbieterHilfe('Yahoo', 'yahoo.de', [
    'Öffne die Kontosicherheit bei Yahoo und wähle „App-Passwort generieren“.',
    'Kopiere das Passwort, komm zurück und füge es ein.',
  ], [
    ('Yahoo-Kontosicherheit öffnen', 'https://login.yahoo.com/account/security'),
  ]),
  AnbieterHilfe('Outlook / Hotmail', 'outlook.de', [
    'Microsoft erlaubt fremden Apps keinen Zugriff mit Passwort. Das kann Papiertiger noch nicht.',
    'So geht es trotzdem: Öffne eine wichtige E-Mail in Outlook, tippe auf Teilen und wähle Papiertiger.',
  ], [], moeglich: false),
  AnbieterHilfe('Anderer Anbieter', '', [
    'Such in der Hilfe deines Anbieters nach „IMAP“ und „App-Passwort“.',
    'Trag dann unten Adresse und Passwort ein. Den Server schlägt Papiertiger vor, du kannst ihn ändern.',
  ], []),
];

const outlookHinweis = 'Microsoft lässt fremde Apps nur noch mit Microsoft-Anmeldung ins Postfach, nicht mit Passwort. '
    'Das kann Papiertiger noch nicht. Bis dahin: E-Mail in Outlook öffnen → Teilen → Papiertiger.';

/// Server zu einer Adresse; für eigene Domains ein Vorschlag „imap.<domain>“.
MailServer serverFuer(String adresse) {
  final at = adresse.trim().toLowerCase().lastIndexOf('@');
  if (at < 0) return const MailServer('');
  final domain = adresse.trim().toLowerCase().substring(at + 1);
  return mailAnbieter[domain] ?? MailServer('imap.$domain', hinweis: 'Server bitte prüfen – er steht meist in der Hilfe deines Anbieters.');
}

const mailArten = <String, String>{
  'mahnung': 'Mahnung',
  'rechnung': 'Rechnung',
  'behoerde': 'Behördenpost',
  'vertrag': 'Vertragsänderung',
  'briefankuendigung': 'Briefankündigung',
};

class MailEinordnung {
  MailEinordnung(this.art, {this.betrag, this.frist});

  final String art;
  final double? betrag;
  final DateTime? frist;
}

bool _hat(String text, List<String> woerter) => woerter.any(text.contains);

/// Name aus „Name <adresse>“, sonst die Adresse.
String absenderName(String von) {
  final m = RegExp(r'^\s*"?([^"<]*?)"?\s*<([^>]+)>').firstMatch(von);
  if (m != null) return m[1]!.trim().isEmpty ? m[2]!.trim() : m[1]!.trim();
  return von.trim();
}

/// Ist diese E-Mail wichtig? null = nicht melden (Newsletter, Privates, Werbung …).
MailEinordnung? mailEinordnen(Mail m, {DateTime? heute}) {
  final von = m.von.toLowerCase();
  final betreff = m.betreff.toLowerCase();
  final anhaenge = m.anhaenge.map((a) => a.name.toLowerCase()).join(' ');

  if (_hat(von, ['deutschepost', 'deutsche post', 'briefankuendigung']) ||
      _hat(betreff, ['briefankündigung', 'briefankuendigung'])) {
    return MailEinordnung('briefankuendigung');
  }

  String? art;
  if (_hat(betreff, ['mahnung', 'zahlungserinnerung', 'letzte erinnerung', 'inkasso', 'zahlungsrückstand', 'offener betrag', 'offene rechnung', 'überfällig'])) {
    art = 'mahnung';
  } else if (_hat(von, ['finanzamt', 'elster', 'arbeitsagentur', 'jobcenter', 'rentenversicherung', 'familienkasse', 'bund.de', 'zoll.de', 'rundfunkbeitrag', 'beitragsservice', 'bzst', 'landratsamt', 'kreisverwaltung', 'buergeramt', 'bürgeramt']) ||
      _hat(betreff, ['bescheid', 'elster', 'finanzamt', 'jobcenter', 'familienkasse'])) {
    art = 'behoerde';
  } else if (_hat(betreff, ['newsletter', '% rabatt', 'gutschein', 'angebot der woche'])) {
    return null;
  } else if (_hat(betreff, ['rechnung', 'invoice', 'abrechnung', 'zahlungsaufforderung', 'beitragsrechnung', 'lastschriftankündigung']) ||
      _hat(anhaenge, ['rechnung', 'invoice', 'xrechnung', 'zugferd'])) {
    art = 'rechnung';
  } else if (_hat(betreff, ['preisanpassung', 'preiserhöhung', 'preisänderung', 'vertragsänderung', 'beitragsanpassung', 'kündigung', 'neue preise', 'änderung ihres vertrags', 'agb-änderung'])) {
    art = 'vertrag';
  }
  if (art == null) return null;
  final a = analysiereBrief(m.alsBrieftext, heute: heute);
  return MailEinordnung(art, betrag: a.istGuthaben ? null : a.betrag, frist: a.frist);
}

/// So verbindet sich Papiertiger mit dem Server (im Test ein Ersatz).
typedef Verbinder = Future<ImapVerbindung> Function(PostfachKonto k);

Future<ImapVerbindung> standardVerbinder(PostfachKonto k) => ImapVerbindung.verbinden(k.server, k.port);

/// Anmeldung prüfen (beim Einrichten).
Future<void> postfachTesten(PostfachKonto k, {Verbinder verbinder = standardVerbinder}) async {
  final v = await verbinder(k);
  try {
    await v.anmelden(k.benutzer, k.passwort);
    await v.posteingang();
  } finally {
    await v.abmelden();
  }
}

/// Größere E-Mails werden nur mit Kopfzeilen gelesen (Betreff und Absender reichen zum Erkennen).
const maxVollLaden = 2 * 1024 * 1024;

/// Höchstens so viele neue E-Mails pro Durchgang ansehen.
const maxProDurchgang = 40;

/// Sieht neue E-Mails an und hängt wichtige an [p.hinweise] an. Liefert die neu gemeldeten.
/// Beim ersten Mal werden nur die letzten 7 Tage angesehen.
Future<List<MailHinweis>> postfachPruefen(Postfach p, {Verbinder verbinder = standardVerbinder, DateTime? jetzt}) async {
  final k = p.konto;
  if (k == null) return [];
  final zeit = jetzt ?? DateTime.now();
  final neu = <MailHinweis>[];
  ImapVerbindung? v;
  try {
    v = await verbinder(k);
    await v.anmelden(k.benutzer, k.passwort);
    final validity = await v.posteingang();
    if (validity != k.uidValidity) {
      k.uidValidity = validity;
      k.letzteUid = 0;
    }
    var uids = k.letzteUid == 0 ? await v.seit(zeit.subtract(const Duration(days: 7))) : await v.nach(k.letzteUid);
    if (uids.length > maxProDurchgang) uids = uids.sublist(uids.length - maxProDurchgang);
    final bekannt = {for (final h in p.hinweise) h.uid};
    for (final uid in uids) {
      if (!bekannt.contains(uid)) {
        final g = await v.groesse(uid);
        final roh = await v.laden(uid, nurKopf: g != null && g > maxVollLaden);
        if (roh != null) {
          final mail = emlLesen(roh);
          final e = mailEinordnen(mail, heute: zeit);
          if (e != null) {
            final h = MailHinweis(
              uid: uid,
              art: e.art,
              absender: absenderName(mail.von),
              betreff: mail.betreff,
              datum: mail.datum,
              betrag: e.betrag,
              frist: e.frist,
              anhaenge: mail.anhaenge.where((a) => a.istPdf).length,
            );
            p.hinweise.add(h);
            neu.add(h);
          }
        }
      }
      if (uid > k.letzteUid) k.letzteUid = uid;
    }
    k.fehler = null;
  } on ImapFehler catch (e) {
    k.fehler = e.anmeldung ? 'Anmeldung abgelehnt – Passwort prüfen.' : e.text;
  } catch (e) {
    k.fehler = 'Nachsehen fehlgeschlagen: $e';
  } finally {
    await v?.abmelden();
  }
  k.zuletzt = zeit;
  // Alte Hinweise nicht ewig aufheben
  if (p.hinweise.length > 200) p.hinweise.removeRange(0, p.hinweise.length - 200);
  return neu;
}

/// Eine gemeldete E-Mail vollständig laden (zum Übernehmen als Brief).
Future<Uint8List?> mailLaden(PostfachKonto k, int uid, {Verbinder verbinder = standardVerbinder}) async {
  final v = await verbinder(k);
  try {
    await v.anmelden(k.benutzer, k.passwort);
    await v.posteingang();
    return await v.laden(uid);
  } finally {
    await v.abmelden();
  }
}

/// Text für die Benachrichtigung.
(String, String) hinweisText(List<MailHinweis> neu) {
  String d(DateTime x) => '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.';
  String eine(MailHinweis h) {
    if (h.art == 'briefankuendigung') return 'Die Post kündigt einen Brief an';
    final teile = [
      '${mailArten[h.art]} von ${h.absender}',
      if (h.betrag != null) '${h.betrag!.toStringAsFixed(2).replaceAll('.', ',')} €',
      if (h.frist != null) 'bis ${d(h.frist!)}',
    ];
    return teile.join(' · ');
  }

  if (neu.length == 1) {
    final h = neu.first;
    return (h.art == 'briefankuendigung' ? 'Heute kommt Post' : 'Neu im Postfach: ${mailArten[h.art]}', eine(h));
  }
  return ('${neu.length} wichtige E-Mails', neu.take(3).map(eine).join('\n'));
}
