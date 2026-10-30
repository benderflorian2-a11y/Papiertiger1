import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/eingang.dart';
import '../logic/finanzen.dart';
import '../logic/zahlung.dart';
import '../logic/heute.dart';
import '../logic/kommunikation.dart';
import '../logic/ordnung.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'finanzen.dart';
import 'fristen.dart';
import 'geschaeft/stempeluhr.dart';
import 'haushalt/alltag.dart';
import 'karriere/karriere.dart';
import 'kommunikation.dart';
import 'module/module_liste.dart';
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
            ],
          ),
          const SizedBox(height: 20),

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
                    onPressed: () => oeffne(const ScanScreen(mitKamera: true)),
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
                      onTap: () => oeffne(const ScanScreen(mitKamera: false)),
                    ),
                    _Quelle(
                      key: const ValueKey('pdf-import-start'),
                      icon: Icons.upload_file_outlined,
                      text: 'PDF / E-Mail',
                      onTap: () => oeffne(const DateiImportScreen()),
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
