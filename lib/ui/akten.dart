import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/export.dart';
import '../logic/ki_anfragen.dart';
import '../logic/ordnung.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'ki_text.dart';
import 'theme.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';

IconData ordnerIcon(String key) {
  switch (key) {
    case 'steuern':
      return Icons.account_balance_outlined;
    case 'rente':
      return Icons.elderly_outlined;
    case 'familie':
      return Icons.family_restroom_outlined;
    case 'arbeit':
      return Icons.work_outline;
    case 'gesundheit':
      return Icons.local_hospital_outlined;
    case 'wohnen':
      return Icons.home_outlined;
    case 'vertraege':
      return Icons.shield_outlined;
    case 'geld':
      return Icons.euro;
    case 'recht':
      return Icons.gavel_outlined;
  }
  return Icons.folder_outlined;
}

void _oeffneBrief(BuildContext context, Brief b) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id)));

/// Alle Briefe eines Ordners.
class OrdnerScreen extends StatelessWidget {
  const OrdnerScreen({super.key, required this.ordnerKey});

  final String ordnerKey;

  @override
  Widget build(BuildContext context) {
    final o = ordnerMitKey(ordnerKey);
    final briefe = StoreScope.of(context).briefe.where((b) => ordnerFuer(b).key == o.key).toList();
    return Scaffold(
      appBar: AppBar(title: Text(o.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PTKarte(
            farbe: PT.orangeHell,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.inventory_outlined, color: PT.orangeDunkel),
                const SizedBox(width: 12),
                Expanded(child: Text('${o.aufbewahrungText} (Empfehlung, ohne Gewähr)')),
              ],
            ),
          ),
          if (briefe.isEmpty)
            const LeerHinweis(icon: Icons.folder_open_outlined, text: 'Dieser Ordner ist leer.')
          else
            for (final b in briefe) BriefZeile(brief: b, onTap: () => _oeffneBrief(context, b)),
        ],
      ),
    );
  }
}

/// Ein Vorgang: alle Dokumente mit gleichem Aktenzeichen bzw. Absender.
class AkteScreen extends StatelessWidget {
  const AkteScreen({super.key, required this.schluessel});

  final String schluessel;

  @override
  Widget build(BuildContext context) {
    final akten = aktenBilden(StoreScope.of(context).briefe).where((a) => a.schluessel == schluessel);
    if (akten.isEmpty) {
      return Scaffold(
          appBar: AppBar(),
          body: const LeerHinweis(icon: Icons.layers_outlined, text: 'Dieser Vorgang ist leer.'));
    }
    final akte = akten.first;
    final offen = akte.briefe.where((b) => !b.erledigt).length;
    final fristen = akte.briefe.where((b) => !b.erledigt && b.frist != null).toList()
      ..sort((a, b) => a.frist!.compareTo(b.frist!));
    return Scaffold(
      appBar: AppBar(title: const Text('Vorgang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PTKarte(
            farbe: PT.orangeHell,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(akte.titel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${akte.briefe.length} Dokumente · $offen offen'
                    '${fristen.isNotEmpty ? ' · nächste Frist ${datumKurz(fristen.first.frist!)}' : ''}'),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => KiTextScreen(
                      titel: 'Vorgang zusammengefasst',
                      anfrage: akteAnfrage(akte),
                      hinweis: 'Zusammenfassung der KI aus den gespeicherten Erklärungen.',
                    ),
                  )),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Zusammenfassen'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final datei = await akteAlsPdf(akte);
                      await dateiTeilen(datei.path);
                    } catch (e) {
                      if (context.mounted) zeigeHinweis(context, 'PDF konnte nicht erstellt werden: $e');
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Als PDF'),
                ),
              ),
            ],
          ),
          const Abschnitt('Verlauf (neueste zuerst)'),
          for (final b in akte.briefe) BriefZeile(brief: b, onTap: () => _oeffneBrief(context, b)),
        ],
      ),
    );
  }
}
