import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/brief_analyse.dart';
import '../logic/vertrag_logik.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'module/belege.dart';
import 'module/vertraege.dart';
import 'theme.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';

class FristEintrag {
  FristEintrag(this.datum, this.titel, this.untertitel, this.icon, this.oeffnen);

  final DateTime datum;
  final String titel;
  final String untertitel;
  final IconData icon;
  final Widget Function() oeffnen;
}

/// Alle offenen Fristen aus Briefen, Verträgen und Garantien, nach Datum.
List<FristEintrag> alleFristen(AppStore s) {
  final liste = <FristEintrag>[];
  for (final b in s.briefe) {
    if (b.erledigt || b.frist == null) continue;
    liste.add(FristEintrag(
      b.frist!,
      b.absenderName ?? kategorieFuer(b.kategorie).name,
      typFuer(b.typ).name,
      kategorieIcon(b.kategorie),
      () => BriefDetail(briefId: b.id),
    ));
  }
  for (final v in s.vertraege) {
    if (v.gekuendigt) continue;
    final info = kuendigungsInfo(v);
    if (tageBis(info.kuendigenBis) > 120) continue;
    liste.add(FristEintrag(
      info.kuendigenBis,
      v.anbieter,
      'Kündigen bis ${datumKurz(info.kuendigenBis)}',
      Icons.description_outlined,
      () => VertragDetail(vertragId: v.id),
    ));
  }
  for (final b in s.belege) {
    if (b.garantieMonate <= 0) continue;
    final tage = tageBis(b.garantieEnde);
    if (tage < 0 || tage > 60) continue;
    liste.add(FristEintrag(
      b.garantieEnde,
      b.haendler.isEmpty ? 'Beleg' : b.haendler,
      'Garantie endet',
      Icons.receipt_long_outlined,
      () => BelegDetail(belegId: b.id),
    ));
  }
  liste.sort((a, b) => a.datum.compareTo(b.datum));
  return liste;
}

class FristZeile extends StatelessWidget {
  const FristZeile(this.eintrag, {super.key});

  final FristEintrag eintrag;

  @override
  Widget build(BuildContext context) {
    return PTKarte(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => eintrag.oeffnen())),
      child: Row(
        children: [
          IconKachel(eintrag.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eintrag.titel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15, color: PT.tinte)),
                const SizedBox(height: 2),
                Text('${eintrag.untertitel} · ${datumKurz(eintrag.datum)}',
                    style: const TextStyle(color: PT.grau, fontSize: 13)),
              ],
            ),
          ),
          FristEtikett(eintrag.datum),
        ],
      ),
    );
  }
}

class FristenScreen extends StatelessWidget {
  const FristenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fristen = alleFristen(StoreScope.of(context));
    final ueberfaellig = fristen.where((f) => tageBis(f.datum) < 0).toList();
    final woche =
        fristen.where((f) => tageBis(f.datum) >= 0 && tageBis(f.datum) <= 7).toList();
    final spaeter = fristen.where((f) => tageBis(f.datum) > 7).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Fristen')),
      body: fristen.isEmpty
          ? const LeerHinweis(
              icon: Icons.event_available_outlined,
              text: 'Keine offenen Fristen. Der Tiger passt auf, sobald du Briefe oder Verträge hinzufügst.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (ueberfaellig.isNotEmpty) ...[
                  const Abschnitt('Überfällig'),
                  for (final f in ueberfaellig) FristZeile(f),
                ],
                if (woche.isNotEmpty) ...[
                  const Abschnitt('Diese Woche'),
                  for (final f in woche) FristZeile(f),
                ],
                if (spaeter.isNotEmpty) ...[
                  const Abschnitt('Später'),
                  for (final f in spaeter) FristZeile(f),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Tipp: Trag wichtige Fristen zusätzlich in deinen Kalender ein.',
                  style: TextStyle(color: PT.grau, fontSize: 13),
                ),
              ],
            ),
    );
  }
}
