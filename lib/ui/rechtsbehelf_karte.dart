import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/behoerden.dart';
import '../logic/vorlagen.dart';
import 'app.dart';
import 'theme.dart';
import 'vorlage_screen.dart';
import 'widgets/common.dart';

/// Zeigt die Widerspruchs- bzw. Einspruchsfrist eines Bescheids – mit Quelle
/// aus dem Brief und dem Rechenweg. Immer als „bitte prüfen“ markiert.
class RechtsbehelfKarte extends StatelessWidget {
  const RechtsbehelfKarte({super.key, required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = brief;
    final zugangText = store.notizen['zugang:${b.id}'];
    final zugang = zugangText == null ? null : DateTime.tryParse(zugangText);
    final r = rechtsbehelfFinden(b.text, briefDatum: b.briefDatum, zugang: zugang);
    if (r == null || b.erledigt) return const SizedBox.shrink();
    final ende = r.fristEnde;
    final uebernommen = ende != null && b.frist != null && nurTagGleich(b.frist!, ende);
    return PTKarte(
      farbe: PT.gelbHell,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.art}sfrist', style: const TextStyle(color: PT.grau)),
          Text(
            ende == null ? '1 Monat ab Bekanntgabe' : 'ungefähr bis ${datumLang(ende)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Laut Brief: „${r.quelle}“', style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4)),
          const SizedBox(height: 6),
          if (r.bekanntgabe != null)
            Text(
              '${zugang != null && zugang == r.bekanntgabe ? 'Zugang am ${datumKurz(zugang)}' : 'Briefdatum + ${bekanntgabeTage(b.briefDatum!)} Tage = Bekanntgabe am ${datumKurz(r.bekanntgabe!)}'}'
              ', plus 1 Monat${r.verschoben ? ', verschoben auf den nächsten Werktag' : ''}. '
              'Kam der Brief später an, zählt meist der Tag des Zugangs. Im Zweifel lieber früher handeln.',
              style: const TextStyle(fontSize: 13, color: PT.grau, height: 1.4),
            ),
          Wrap(spacing: 4, children: [
            if (ende != null && !uebernommen)
              TextButton(
                onPressed: () {
                  b.frist = ende;
                  b.fristUnsicher = true;
                  store.geaendert();
                  zeigeHinweis(context, 'Als Frist übernommen – der Tiger erinnert dich rechtzeitig.');
                },
                child: const Text('Als Frist übernehmen'),
              ),
            TextButton(
              onPressed: () async {
                final d = await datumWaehlen(context, start: zugang ?? DateTime.now());
                if (d == null) return;
                store.notizen['zugang:${b.id}'] = d.toIso8601String();
                await store.geaendert();
              },
              child: const Text('Brief kam an am …'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VorlageScreen(
                  titel: r.art,
                  text: rechtsbehelfText(b, store.profil, r.art == 'Klage' ? 'Widerspruch' : r.art),
                  brief: b,
                ),
              )),
              child: Text('${r.art == 'Klage' ? 'Widerspruch' : r.art} vorbereiten'),
            ),
          ]),
          const Text(
            'Ob ein Widerspruch sinnvoll ist, kann der Tiger nicht beurteilen. Kostenlose Hilfe: Sozialberatung, '
            'Verbraucherzentrale, Lohnsteuerhilfeverein (Steuer) oder Mieterverein.',
            style: TextStyle(fontSize: 12, color: PT.grau, height: 1.4),
          ),
        ],
      ),
    );
  }
}

bool nurTagGleich(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
