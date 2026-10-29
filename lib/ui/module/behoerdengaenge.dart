import 'package:flutter/material.dart';

import '../../logic/behoerden.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

class BehoerdengaengeScreen extends StatelessWidget {
  const BehoerdengaengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Behördengänge')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Checklisten zum Abhaken: was du mitbringen musst und welche Fristen gelten.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          for (final c in behoerdenChecklisten)
            PTKarte(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BehoerdenChecklisteScreen(c))),
              child: Row(children: [
                const IconKachel(Icons.account_balance_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${c.kurz} · ${[for (var i = 0; i < c.punkte.length; i++) if (store.checklisten['behoerde:${c.key}:$i'] == true) i].length}'
                      '/${c.punkte.length} erledigt',
                      style: const TextStyle(color: PT.grau, fontSize: 13),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ]),
            ),
          const Text(behoerdenHinweis, style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}

class BehoerdenChecklisteScreen extends StatelessWidget {
  const BehoerdenChecklisteScreen(this.c, {super.key});

  final BehoerdenCheckliste c;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    Widget punkt(int i, String text) => CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          value: store.checklisten['behoerde:${c.key}:$i'] == true,
          title: Text(text),
          onChanged: (v) => store.checklistePunkt('behoerde:${c.key}:$i', v ?? false),
        );
    final u = c.unterlagen.length;
    return Scaffold(
      appBar: AppBar(title: Text(c.titel)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (c.frist.isNotEmpty)
            PTKarte(
              farbe: PT.orangeHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Frist: ${c.frist}', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (c.quelle.isNotEmpty)
                  Text('Quelle: ${c.quelle}', style: const TextStyle(color: PT.grau, fontSize: 13)),
              ]),
            ),
          const Abschnitt('Das brauchst du'),
          for (var i = 0; i < u; i++) punkt(i, c.unterlagen[i]),
          const Abschnitt('Schritte'),
          for (var i = 0; i < c.schritte.length; i++) punkt(u + i, c.schritte[i]),
          const SizedBox(height: 12),
          const PTKarte(
            farbe: PT.gelbHell,
            child: Text(behoerdenHinweis, style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
