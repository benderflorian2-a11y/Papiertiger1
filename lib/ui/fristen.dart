import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/datum.dart';
import '../logic/zeitplan.dart';
import 'abwesenheit.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'kalender.dart';
import 'module/belege.dart';
import 'module/vertraege.dart';
import 'termine.dart';
import 'theme.dart';
import 'widgets/common.dart';

class FristEintrag {
  FristEintrag(this.f, this.icon, this.oeffnen);

  final Faelligkeit f;
  final IconData icon;
  final Widget Function() oeffnen;

  DateTime get datum => f.datum;
  String get titel => f.titel;
  String get untertitel => f.text;
}

List<Faelligkeit> faelligkeitenVon(AppStore s) => faelligkeiten(
    briefe: s.briefe, vertraege: s.vertraege, belege: s.belege, termine: s.termine);

/// Alle offenen Fristen und Termine, nach Datum.
List<FristEintrag> alleFristen(AppStore s) => [
      for (final f in faelligkeitenVon(s))
        switch (f.art) {
          FaelligArt.brief => FristEintrag(f, Icons.mail_outline, () => BriefDetail(briefId: f.refId)),
          FaelligArt.nachfassen =>
            FristEintrag(f, Icons.forward_to_inbox_outlined, () => BriefDetail(briefId: f.refId)),
          FaelligArt.vertrag =>
            FristEintrag(f, Icons.description_outlined, () => VertragDetail(vertragId: f.refId)),
          FaelligArt.garantie =>
            FristEintrag(f, Icons.receipt_long_outlined, () => BelegDetail(belegId: f.refId)),
          FaelligArt.termin => FristEintrag(f, Icons.event_outlined, () => TerminFormular(terminId: f.refId)),
        }
    ];

class FristZeile extends StatelessWidget {
  const FristZeile(this.eintrag, {super.key});

  final FristEintrag eintrag;

  @override
  Widget build(BuildContext context) {
    final f = eintrag.f;
    return PTKarte(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => eintrag.oeffnen())),
      child: Row(
        children: [
          IconKachel(eintrag.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eintrag.titel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: PT.tinte)),
                const SizedBox(height: 2),
                Text('${eintrag.untertitel} · ${datumKurz(eintrag.datum)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PT.grau, fontSize: 13)),
                if (f.unsicher)
                  const Text('Frist bitte im Brief prüfen', style: TextStyle(color: PT.gelb, fontSize: 12)),
              ],
            ),
          ),
          FristEtikett(eintrag.datum),
          IconButton(
            tooltip: 'In Kalender eintragen',
            icon: const Icon(Icons.edit_calendar_outlined, size: 20, color: PT.grau),
            onPressed: () => inKalender(context, f.titel, f.datum, beschreibung: f.text),
          ),
        ],
      ),
    );
  }
}

enum _Zeitraum { woche, monat, alle }

class FristenScreen extends StatefulWidget {
  const FristenScreen({super.key});

  @override
  State<FristenScreen> createState() => _FristenScreenState();
}

class _FristenScreenState extends State<FristenScreen> {
  _Zeitraum _zeitraum = _Zeitraum.alle;

  @override
  Widget build(BuildContext context) {
    final alle = alleFristen(StoreScope.of(context));
    final heute = nurTag(DateTime.now());
    final grenze = switch (_zeitraum) {
      _Zeitraum.woche => heute.add(const Duration(days: 7)),
      _Zeitraum.monat => heute.add(const Duration(days: 31)),
      _Zeitraum.alle => null,
    };
    final fristen = grenze == null ? alle : alle.where((f) => !nurTag(f.datum).isAfter(grenze)).toList();
    final ueberfaellig = fristen.where((f) => tageBis(f.datum) < 0).toList();
    final heuteListe = fristen.where((f) => tageBis(f.datum) == 0).toList();
    final woche = fristen.where((f) => tageBis(f.datum) > 0 && tageBis(f.datum) <= 7).toList();
    final spaeter = fristen.where((f) => tageBis(f.datum) > 7).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fristen & Termine'),
        actions: [
          IconButton(
            tooltip: 'Abwesenheit planen',
            icon: const Icon(Icons.beach_access_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AbwesenheitScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TerminFormular())),
        icon: const Icon(Icons.add),
        label: const Text('Termin'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          SegmentedButton<_Zeitraum>(
            segments: const [
              ButtonSegment(value: _Zeitraum.woche, label: Text('7 Tage')),
              ButtonSegment(value: _Zeitraum.monat, label: Text('Monat')),
              ButtonSegment(value: _Zeitraum.alle, label: Text('Alle')),
            ],
            selected: {_zeitraum},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _zeitraum = s.first),
          ),
          const SizedBox(height: 8),
          if (fristen.isEmpty)
            const LeerHinweis(
                icon: Icons.event_available_outlined,
                text: 'Keine offenen Fristen in diesem Zeitraum. Der Tiger passt auf.')
          else ...[
            if (ueberfaellig.isNotEmpty) ...[
              const Abschnitt('Überfällig'),
              for (final f in ueberfaellig) FristZeile(f),
            ],
            if (heuteListe.isNotEmpty) ...[
              const Abschnitt('Heute'),
              for (final f in heuteListe) FristZeile(f),
            ],
            if (woche.isNotEmpty) ...[
              const Abschnitt('Nächste 7 Tage'),
              for (final f in woche) FristZeile(f),
            ],
            if (spaeter.isNotEmpty) ...[
              const Abschnitt('Später'),
              for (final f in spaeter) FristZeile(f),
            ],
          ],
          const SizedBox(height: 8),
          const Text(
            'Fristen sind automatisch erkannt. Maßgeblich ist immer das Datum im Original-Schreiben.',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
