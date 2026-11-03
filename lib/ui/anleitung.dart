import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../logic/benachrichtigungen.dart';
import '../logic/ki.dart';
import 'app.dart';
import 'bankkonto.dart';
import 'fristen.dart';
import 'ki_einrichten.dart';
import 'kontoauszug.dart';
import 'module/vertraege.dart';
import 'postfach.dart';
import 'scan.dart';
import 'sicherheit.dart';
import 'sicherung.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Ein Schritt der Einrichtung: erledigt? und wohin.
class _Schritt {
  const _Schritt(this.titel, this.text, this.icon, this.erledigt, this.los);

  final String titel;
  final String text;
  final IconData icon;
  final bool erledigt;
  final Future<void> Function(BuildContext) los;
}

Future<void> _oeffne(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

/// „Erste Schritte“ auf der Startseite: kurze Checkliste für neue Nutzer, hakt sich selbst ab.
class ErsteSchritteKarte extends StatelessWidget {
  const ErsteSchritteKarte({super.key});

  static const ausgeblendet = 'start:ausgeblendet';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.checklisten[ausgeblendet] == true) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: kIsWeb ? Future.value(true) : Ki.istInstalliert(),
      builder: (context, ki) {
        final schritte = <_Schritt>[
          _Schritt('Ersten Brief scannen', 'Foto machen – der Tiger erklärt ihn dir', Icons.document_scanner_outlined,
              store.briefe.isNotEmpty,
              (c) => _oeffne(c, kIsWeb ? const TextEinfuegenScreen() : const ScanScreen(mitKamera: true))),
          if (!kIsWeb)
            _Schritt('KI einrichten', 'Liest jeden Brief komplett und fasst ihn zusammen (2,6 GB, im WLAN)',
                Icons.auto_awesome_outlined, ki.data == true, (c) => _oeffne(c, const KiEinrichtenScreen())),
          if (!kIsWeb)
            _Schritt('Erinnerungen erlauben', 'Damit du keine Frist verpasst', Icons.notifications_active_outlined,
                store.checklisten['start:erinnerungen'] == true, (c) async {
              await Benachrichtigungen.erlaubnisAnfragen();
              store.checklisten['start:erinnerungen'] = true;
              await store.geaendert();
            }),
          if (!kIsWeb)
            _Schritt('E-Mail-Postfach verbinden', 'Rechnungen und Behördenpost per Mail werden gemeldet',
                Icons.alternate_email, store.postfach.konto != null, (c) => _oeffne(c, const PostfachScreen())),
          _Schritt('Verträge und Abos eintragen', 'Der Tiger sagt dir, bis wann du kündigen kannst',
              Icons.description_outlined, store.vertraege.isNotEmpty, (c) => _oeffne(c, const VertraegeScreen())),
          // „Daten sichern“ erinnert die Startseite schon unter „Heute erledigen“
          _Schritt('App-Sperre einschalten', 'PIN oder Fingerabdruck – niemand liest deine Post mit', Icons.lock_outline,
              sperreAn(store), (c) => _oeffne(c, const SicherheitScreen())),
        ];
        final fertig = schritte.where((s) => s.erledigt).length;
        if (fertig == schritte.length) return const SizedBox.shrink();
        return PTKarte(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                child: Text('Erste Schritte', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Text('$fertig von ${schritte.length}', style: const TextStyle(color: PT.grau, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: fertig / schritte.length, minHeight: 6, backgroundColor: PT.sand, color: PT.orange),
            ),
            const SizedBox(height: 6),
            for (final s in schritte)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(s.erledigt ? Icons.check_circle : s.icon, color: s.erledigt ? PT.gruen : PT.orangeDunkel),
                title: Text(s.titel,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: s.erledigt ? TextDecoration.lineThrough : null,
                        color: s.erledigt ? PT.grau : PT.tinte)),
                subtitle: s.erledigt ? null : Text(s.text),
                trailing: s.erledigt ? null : const Icon(Icons.chevron_right, color: PT.grau),
                onTap: s.erledigt ? null : () => s.los(context),
              ),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                onPressed: () => _oeffne(context, const AnleitungScreen()),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Anleitung'),
              ),
              TextButton(
                onPressed: () async {
                  store.checklisten[ausgeblendet] = true;
                  await store.geaendert();
                },
                child: const Text('Ausblenden'),
              ),
            ]),
          ]),
        );
      },
    );
  }
}

class _Thema {
  const _Thema(this.titel, this.icon, this.text, {this.tipps = const [], this.knopf, this.ziel});

  final String titel;
  final IconData icon;
  final String text;
  final List<String> tipps;
  final String? knopf;
  final Widget Function()? ziel;
}

final _themen = <_Thema>[
  _Thema(
    'Briefe scannen',
    Icons.document_scanner_outlined,
    'Tippe auf „Brief fotografieren“. Der Scanner findet die Ränder selbst, richtet den Brief gerade aus und entfernt Schatten. '
        'Mehrere Seiten nimmst du nacheinander auf (unten rechts „+“).',
    tipps: [
      'Brief flach auf einen dunklen Tisch legen, gutes Licht, keine Schatten.',
      'Briefe, die schon als PDF oder E-Mail auf dem Handy sind: „PDF / E-Mail“ – das ist genauer als ein Foto vom Bildschirm.',
      'Aus anderen Apps: Datei oder E-Mail öffnen → Teilen → Papiertiger.',
    ],
    knopf: 'Brief scannen',
    ziel: () => kIsWeb ? const TextEinfuegenScreen() : const ScanScreen(mitKamera: true),
  ),
  const _Thema(
    'Was auf der Briefseite steht',
    Icons.article_outlined,
    '„Kurz gesagt“ erklärt den Brief in einfachen Worten. Darunter „Das Wichtigste“: Frist, Betrag, Aktenzeichen – '
        'und bei Rechnungen die fertige Überweisung. „Deine Aufgaben“ sagt, was zu tun ist. '
        'Alle weiteren Angaben (Nummern, IBAN, Kontakt) findest du unter „Das steht im Brief“ – antippen kopiert sie.',
    tipps: [
      'Stimmt etwas nicht? Frist und Betrag lassen sich mit dem Stift-Symbol korrigieren.',
      '„Brief ist erledigt“ einschalten, wenn alles getan ist – dann verschwindet er aus den Aufgaben.',
    ],
  ),
  _Thema(
    'KI auf dem Handy',
    Icons.auto_awesome_outlined,
    'Ohne KI erkennt der Tiger Briefe über Stichworte – schnell, aber manchmal ungenau. Mit KI liest er jeden Brief '
        'komplett, schreibt eine eigene Zusammenfassung und prüft Fristen und Beträge. Die KI läuft nur auf deinem Handy, '
        'deine Briefe gehen nirgendwohin.',
    tipps: [
      'Einmalig 2,6 GB herunterladen – am besten im WLAN und mit Ladekabel.',
      'Pro Brief dauert es ein bis zwei Minuten. Du kannst die App verlassen, der Tiger meldet sich, wenn er fertig ist.',
    ],
    knopf: kIsWeb ? null : 'KI einrichten',
    ziel: kIsWeb ? null : () => const KiEinrichtenScreen(),
  ),
  _Thema(
    'Fristen und Erinnerungen',
    Icons.event_outlined,
    'Jede erkannte Frist landet im Tab „Fristen“. Der Tiger erinnert dich rechtzeitig per Benachrichtigung. '
        'Mit dem Kalender-Symbol trägst du eine Frist in deinen Handy-Kalender ein.',
    tipps: ['Wann und wie oft erinnert wird, stellst du unter „Mehr → Erinnerungen“ ein.'],
    knopf: 'Fristen ansehen',
    ziel: () => const FristenScreen(),
  ),
  const _Thema(
    'Bezahlen',
    Icons.euro,
    'Bei Rechnungen bereitet der Tiger die Überweisung vor: Empfänger, IBAN, Betrag und Verwendungszweck zum Kopieren '
        'oder als GiroCode. Bezahlen und freigeben tust du immer selbst in deiner Banking-App – der Tiger zahlt nie.',
    tipps: ['Danach auf „Bezahlt“ tippen, dann verschwindet die Zahlung aus den offenen Posten.'],
  ),
  const _Thema(
    'Antworten und Widerspruch',
    Icons.edit_note_outlined,
    'Unter „Antwort schreiben“ auf der Briefseite gibt es fertige Vorlagen: Rückfrage, Fristverlängerung, Ratenzahlung, '
        'Widerspruch und mehr. Mit KI wird daraus ein fertiger Brief. Verschicken tust du ihn selbst.',
  ),
  _Thema(
    'E-Mail-Postfach',
    Icons.alternate_email,
    'Verbinde dein Postfach (WEB.DE, GMX, Gmail, T-Online …). Der Tiger meldet sich bei Rechnungen, Mahnungen, '
        'Behördenpost und der Briefankündigung der Deutschen Post. Er liest nur – er löscht und verschickt nichts.',
    tipps: [
      'WEB.DE und GMX: vorher im Postfach unter Einstellungen „POP3/IMAP Abruf“ erlauben.',
      'Gmail, iCloud, Yahoo: dort ein App-Passwort erstellen und das verwenden.',
    ],
    knopf: kIsWeb ? null : 'Postfach verbinden',
    ziel: kIsWeb ? null : () => const PostfachScreen(),
  ),
  _Thema(
    'Verträge, Abos und Kontoauszug',
    Icons.description_outlined,
    'Trag deine Verträge ein oder lass sie aus dem Kontoauszug finden. Der Tiger zeigt, was dich jeden Monat kostet, '
        'bis wann du kündigen kannst, und erstellt das Kündigungsschreiben.',
    tipps: ['Kontoauszug als PDF aus der Banking-App teilen – der Tiger findet regelmäßige Abbuchungen und doppelte Lastschriften.'],
    knopf: 'Abos finden',
    ziel: () => const KontoauszugScreen(),
  ),
  _Thema(
    'Bankkonto verbinden',
    Icons.account_balance_outlined,
    'Mit deinem Online-Banking verbunden (nur lesen) holt der Tiger die Umsätze selbst und findet Abos automatisch. '
        'Die PIN wird nicht gespeichert, überweisen kann der Zugang nicht.',
    knopf: kIsWeb ? null : 'Bankkonto',
    ziel: kIsWeb ? null : () => const BankkontoScreen(),
  ),
  _Thema(
    'Sicherheit und Datensicherung',
    Icons.shield_outlined,
    'Alle Daten liegen verschlüsselt nur auf deinem Handy. Mit einer App-Sperre (PIN oder Fingerabdruck) kommt niemand '
        'ohne dich hinein. Mach regelmäßig eine Datensicherung – sonst ist bei einem neuen Handy alles weg.',
    knopf: 'Daten sichern',
    ziel: () => const SicherungScreen(),
  ),
  const _Thema(
    'Häufige Fragen',
    Icons.help_outline,
    'Was, wenn der Tiger sich irrt? Er sagt dir immer, wo er unsicher ist – maßgeblich ist das Original. '
        'Rechtliche und steuerliche Hinweise sind allgemein und keine Beratung.\n\n'
        'Gehen meine Briefe ins Internet? Nein. Texterkennung, KI und Speicherung laufen auf dem Handy. '
        'Nur wenn du ein E-Mail-Postfach oder Bankkonto verbindest, spricht die App direkt mit deinem Anbieter.\n\n'
        'Wo finde ich alles andere? Unter „Mehr“: Steuer, Anträge, Leistungen, Lebens-Ereignisse, Haushalt und mehr.',
  ),
];

/// Anleitung & Hilfe: jede Funktion kurz erklärt, mit Tipps und Knopf zum Öffnen.
class AnleitungScreen extends StatelessWidget {
  const AnleitungScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Anleitung & Hilfe')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        const Text('Tippe auf ein Thema. Mit dem Knopf darunter kommst du direkt zur Funktion.',
            style: TextStyle(color: PT.grau)),
        const SizedBox(height: 8),
        for (final t in _themen)
          PTKarte(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: IconKachel(t.icon),
                title: Text(t.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.text, style: const TextStyle(height: 1.45)),
                  for (final tipp in t.tipps)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 8),
                          child: Icon(Icons.lightbulb_outline, size: 18, color: PT.orangeDunkel),
                        ),
                        Expanded(child: Text(tipp, style: const TextStyle(color: PT.grau, height: 1.4))),
                      ]),
                    ),
                  if (t.knopf != null && t.ziel != null) ...[
                    const SizedBox(height: 10),
                    FilledButton.tonal(onPressed: () => _oeffne(context, t.ziel!()), child: Text(t.knopf!)),
                  ],
                ],
              ),
            ),
          ),
        if (store.checklisten[ErsteSchritteKarte.ausgeblendet] == true)
          TextButton.icon(
            onPressed: () async {
              store.checklisten.remove(ErsteSchritteKarte.ausgeblendet);
              await store.geaendert();
              if (context.mounted) zeigeHinweis(context, '„Erste Schritte“ wird wieder auf der Startseite gezeigt.');
            },
            icon: const Icon(Icons.checklist),
            label: const Text('„Erste Schritte“ wieder anzeigen'),
          ),
      ]),
    );
  }
}
