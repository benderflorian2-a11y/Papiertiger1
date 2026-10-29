import 'package:flutter/material.dart';

import '../../logic/inhalte.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

class EreignisseScreen extends StatelessWidget {
  const EreignisseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lebens-Ereignisse')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Wähle aus, was ansteht. Der Tiger sagt dir, was zu erledigen ist.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          for (final e in lebensEreignisse)
            Builder(builder: (context) {
              final fertig = [
                for (var i = 0; i < e.punkte.length; i++)
                  if (store.checklisten['${e.key}:$i'] == true) i
              ].length;
              return PTKarte(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChecklisteScreen(ereignis: e))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconKachel(_icon(e.key)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.titel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 16)),
                              Text(e.untertitel,
                                  style: const TextStyle(color: PT.grau, fontSize: 13)),
                            ],
                          ),
                        ),
                        Text('$fertig/${e.punkte.length}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fertig / e.punkte.length,
                        minHeight: 6,
                        backgroundColor: PT.sand,
                        color: PT.orange,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

IconData _icon(String key) {
  switch (key) {
    case 'umzug':
      return Icons.local_shipping_outlined;
    case 'job':
      return Icons.work_outline;
    case 'hochzeit':
      return Icons.favorite_outline;
    case 'baby':
      return Icons.child_friendly_outlined;
  }
  return Icons.checklist;
}

class ChecklisteScreen extends StatelessWidget {
  const ChecklisteScreen({super.key, required this.ereignis});

  final Ereignis ereignis;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ereignis.titel)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < ereignis.punkte.length; i++)
                  CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    value: store.checklisten['${ereignis.key}:$i'] == true,
                    title: Text(ereignis.punkte[i]),
                    onChanged: (v) => store.checklistePunkt('${ereignis.key}:$i', v ?? false),
                  ),
              ],
            ),
          ),
          const Text('Allgemeine Checkliste ohne Gewähr. Fristen können je nach Bundesland abweichen.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}
