import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/alltag.dart';
import '../logic/android_kanal.dart';
import '../logic/eingang.dart';
import '../logic/sprachbefehl.dart';
import '../logic/finanzen.dart';
import '../logic/zahlung.dart';
import '../logic/heute.dart';
import '../logic/kommunikation.dart';
import '../logic/ordnung.dart';
import '../logic/postfach_pruefung.dart' show mailArten;
import 'app.dart';
import 'archiv.dart';
import 'brief_detail.dart';
import 'finanzen.dart';
import 'fristen.dart';
import 'geschaeft/stempeluhr.dart';
import 'haushalt/alltag.dart';
import 'karriere/karriere.dart';
import 'kommunikation.dart';
import 'module/angebote_vergleichen.dart';
import 'module/module_liste.dart';
import 'postfach.dart';
import 'scan.dart';
import 'sicherung.dart';
import 'theme.dart';
import 'ueberweisung.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.zuTab});

  final void Function(int tab) zuTab;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final fristen = alleFristen(store);
    final offen = store.briefe.where((b) => !b.erledigt).length;
    final dringend =
        store.briefe.where((b) => dringlichkeit(b) == Dringlichkeit.hoch).toList();
    final name = store.profil.name.split(' ').first;
    final zahlungen = offeneZahlungen(store.briefe);
    final warten = wartetAufAntwort(store.briefe);
    final jetzt = DateTime.now();
    final in3 = DateTime(jetzt.year, jetzt.month, jetzt.day + 3, 23, 59);
    final hinweise = heuteHinweise(
      alltag: store.alltag,
      karriere: store.karriere,
      stempel: store.stempel,
      letzteSicherung: letzteSicherung(store.notizen),
      hatDaten: store.briefe.isNotEmpty || store.rechnungen.isNotEmpty || store.vertraege.isNotEmpty,
      jetzt: jetzt,
    );
    final eingang = posteingang(store.briefe, heute: jetzt);
    final heuteZahl = fristen.where((f) => !f.datum.isAfter(in3)).length + hinweise.length;

    void oeffne(Widget seite) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => seite));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              const Tiger(size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Hallo!' : 'Hallo $name!',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800, color: PT.tinte)),
                    const Text('Keine Angst vor Post.',
                        style: TextStyle(color: PT.grau, fontSize: 15)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Sag dem Tiger, was du willst',
                iconSize: 28,
                onPressed: () => _sprechen(context, zuTab),
                icon: const Icon(Icons.mic),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Wichtige E-Mails aus dem verknüpften Postfach
          if (store.postfach.neue.isNotEmpty) ...[
            PTKarte(
              farbe: PT.orangeHell,
              onTap: () => oeffne(const PostfachScreen()),
              child: Row(children: [
                IconKachel(mailSymbol(store.postfach.neue.last.art), farbe: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        store.postfach.neue.length == 1
                            ? 'Wichtige E-Mail'
                            : '${store.postfach.neue.length} wichtige E-Mails',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    for (final h in store.postfach.neue.reversed.take(2))
                      Text(
                          h.art == 'briefankuendigung'
                              ? 'Die Post kündigt einen Brief an'
                              : '${mailArten[h.art]} · ${h.absender}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: PT.tinte, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // Hauptaktion
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PT.orange,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Neuer Brief?',
                    style: TextStyle(
                        color: PT.tinte, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Foto machen, und der Tiger erklärt dir, was drinsteht.',
                    style: TextStyle(color: PT.tinte, fontSize: 15, height: 1.35)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('brief-scannen'),
                    style: FilledButton.styleFrom(
                        backgroundColor: PT.tinte, foregroundColor: Colors.white),
                    onPressed: () => kIsWeb ? _nurInDerApp(context) : oeffne(const ScanScreen(mitKamera: true)),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Brief fotografieren'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Quelle(
                      icon: Icons.photo_library_outlined,
                      text: 'Galerie',
                      onTap: () => kIsWeb ? _nurInDerApp(context) : oeffne(const ScanScreen(mitKamera: false)),
                    ),
                    _Quelle(
                      key: const ValueKey('pdf-import-start'),
                      icon: Icons.upload_file_outlined,
                      text: 'PDF / E-Mail',
                      onTap: () => kIsWeb ? _nurInDerApp(context) : oeffne(const DateiImportScreen()),
                    ),
                    _Quelle(
                      key: const ValueKey('text-einfuegen-start'),
                      icon: Icons.content_paste,
                      text: 'Text',
                      onTap: () => oeffne(const TextEinfuegenScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(child: Abschnitt(heuteZahl > 0 ? 'Heute erledigen' : 'Als Nächstes fällig')),
              if (fristen.length + hinweise.length > 3)
                TextButton(onPressed: () => zuTab(1), child: const Text('Alle')),
            ],
          ),
          if (fristen.isEmpty && hinweise.isEmpty)
            const PTKarte(
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: PT.gruen),
                  SizedBox(width: 12),
                  Expanded(child: Text('Nichts offen. Der Tiger schläft entspannt.')),
                ],
              ),
            )
          else ...[
            // Dringendes zuerst: Fristen der nächsten 3 Tage, dann Hinweise, dann spätere Fristen
            for (final f in fristen.where((f) => !f.datum.isAfter(in3)).take(3)) FristZeile(f),
            for (final h in hinweise.take((3 - fristen.where((f) => !f.datum.isAfter(in3)).length).clamp(0, 3)))
              PTKarte(
                padding: const EdgeInsets.all(12),
                onTap: () => oeffne(_hinweisZiel(h)),
                child: Row(children: [
                  IconKachel(_hinweisIcon(h.art)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(h.text, style: const TextStyle(color: PT.grau, fontSize: 13)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: PT.grau),
                ]),
              ),
            if (heuteZahl == 0)
              for (final f in fristen.take(3)) FristZeile(f),
          ],

          if (dringend.isNotEmpty) ...[
            const Abschnitt('Dringend'),
            for (final b in dringend.take(3))
              BriefZeile(
                brief: b,
                onTap: () => oeffne(BriefDetail(briefId: b.id)),
              ),
          ],

          if (zahlungen.isNotEmpty || warten.isNotEmpty) const SizedBox(height: 8),
          if (zahlungen.isNotEmpty)
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => oeffne(const FinanzenScreen()),
              child: Row(children: [
                const IconKachel(Icons.euro),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                      '${zahlungen.length} offene ${zahlungen.length == 1 ? 'Zahlung' : 'Zahlungen'}: ${euro(summe(zahlungen))}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ]),
            ),
          if (warten.isNotEmpty)
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => oeffne(const KommunikationScreen()),
              child: Row(children: [
                const IconKachel(Icons.hourglass_top_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                      'Du wartest auf ${warten.length} ${warten.length == 1 ? 'Antwort' : 'Antworten'}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ]),
            ),

          if (eingang.isNotEmpty) ...[
            const Abschnitt('Neue Post – ein Tipp genügt'),
            for (final b in eingang.take(3))
              Builder(builder: (context) {
                final sch = naechsterSchritt(b);
                return PTKarte(
                  padding: const EdgeInsets.all(12),
                  onTap: () => oeffne(BriefDetail(briefId: b.id)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(titelVon(b), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(sch.text, style: const TextStyle(color: PT.grau, fontSize: 13)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () => _schrittAusfuehren(context, b, sch),
                      child: Text(sch.label),
                    ),
                  ]),
                );
              }),
            if (eingang.length > 3)
              TextButton(onPressed: () => zuTab(2), child: Text('${eingang.length - 3} weitere im Archiv')),
          ],
          Row(
            children: [
              const Expanded(child: Abschnitt('Deine Post')),
              TextButton(onPressed: () => zuTab(2), child: const Text('Archiv')),
            ],
          ),
          PTKarte(
            onTap: () => zuTab(2),
            child: Row(
              children: [
                const IconKachel(Icons.inventory_2_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    store.briefe.isEmpty
                        ? 'Noch keine Briefe gespeichert'
                        : '${store.briefe.length} ${store.briefe.length == 1 ? 'Brief' : 'Briefe'}, davon $offen offen',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),

          const Abschnitt('Alle Module'),
          const ModulRaster(),
        ],
      ),
    );
  }
}

/// Sprachbefehl: z. B. „Milch und Eier auf die Einkaufsliste“, „Was muss ich bezahlen?“, „Such Mietvertrag“.
Future<void> _sprechen(BuildContext context, void Function(int) zuTab) async {
  final store = StoreScope.of(context);
  String? text;
  try {
    text = await diktieren();
  } on StateError catch (e) {
    if (context.mounted) zeigeHinweis(context, e.message);
    return;
  }
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  final b = befehlVerstehen(text);
  void oeffne(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
  switch (b.art) {
    case BefehlArt.einkauf:
      final neu = einkaufAusText(b.rest, vorhanden: store.alltag.einkauf);
      store.alltag.einkauf.addAll(neu);
      await store.geaendert();
      if (context.mounted) zeigeHinweis(context, '${neu.map((e) => e.text).join(', ')} auf der Einkaufsliste');
    case BefehlArt.zahlungen:
      final z = offeneZahlungen(store.briefe);
      zeigeHinweis(context, z.isEmpty ? 'Keine offenen Zahlungen.' : '${z.length} offen, zusammen ${euro(summe(z))}.');
      oeffne(const FinanzenScreen());
    case BefehlArt.fristen || BefehlArt.termine:
      zuTab(1);
    case BefehlArt.suche:
      oeffne(ArchivScreen(startSuche: b.rest));
    case BefehlArt.scannen:
      oeffne(const ScanScreen(mitKamera: true));
    case BefehlArt.unbekannt:
      zeigeHinweis(context, '„$text“ – das habe ich nicht verstanden. Versuch z. B. „Was muss ich bezahlen?“');
  }
}

/// Führt den vorgeschlagenen Schritt aus: Bezahlen öffnet die Überweisung, Ablegen erledigt sofort.
void _schrittAusfuehren(BuildContext context, Brief b, Schritt sch) {
  final store = StoreScope.of(context);
  switch (sch.art) {
    case 'bezahlen':
      final u = ueberweisungFinden(b.text, empfaenger: b.absenderName, betrag: b.betrag, eigeneIban: store.profil.extra['iban']);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UeberweisungScreen(
          auftrag: Zahlauftrag(
            empfaenger: u.empfaenger ?? b.absenderName ?? '',
            iban: u.iban ?? '',
            bic: u.bic ?? '',
            betrag: b.betrag,
            zweck: u.zweck ?? b.aktenzeichen ?? '',
          ),
          beiFreigabe: (am) {
            alsBezahltMarkieren(b, am);
            store.geaendert();
          },
        ),
      ));
    case 'vergleichen':
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AngeboteVergleichenScreen(vorauswahl: b.id)));
    case 'ablegen':
      b.erledigt = true;
      store.geaendert();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('„${titelVon(b)}“ abgelegt'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () {
            b.erledigt = false;
            store.geaendert();
          },
        ),
      ));
    default:
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id)));
  }
}

IconData _hinweisIcon(String art) => switch (art) {
      'vorrat' => Icons.kitchen_outlined,
      'hausaufgabe' => Icons.cleaning_services_outlined,
      'bewerbung' || 'bewerbungsfrist' => Icons.work_outline,
      'weiterbildung' => Icons.school_outlined,
      'stempel' => Icons.timer_outlined,
      'sicherung' => Icons.cloud_upload_outlined,
      _ => Icons.info_outline,
    };

Widget _hinweisZiel(Hinweis h) => switch (h.art) {
      'vorrat' => const VorraeteScreen(),
      'hausaufgabe' => const HausaufgabenScreen(),
      'bewerbung' || 'bewerbungsfrist' => BewerbungDetail(bewerbungId: h.ref),
      'weiterbildung' => const WeiterbildungScreen(),
      'stempel' => const StempeluhrScreen(),
      _ => const SicherungScreen(),
    };

class _Quelle extends StatelessWidget {
  const _Quelle({super.key, required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: PT.tinte),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: PT.tinte, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}


/// Browser-Version: Fotos und PDFs liest der Tiger nur in der App auf dem Handy.
void _nurInDerApp(BuildContext context) => showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Nur in der App'),
        content: const Text('Fotos und PDFs liest der Tiger mit der Texterkennung auf dem Handy. '
            'Im Browser kopierst du den Text des Briefs und fügst ihn über „Text“ ein.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              Navigator.pop(d);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TextEinfuegenScreen()));
            },
            child: const Text('Text einfügen'),
          ),
        ],
      ),
    );
