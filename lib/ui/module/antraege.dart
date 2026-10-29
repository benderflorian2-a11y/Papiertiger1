import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/inhalte.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AntraegeScreen extends StatelessWidget {
  const AntraegeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Anträge')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
              'Der Tiger bereitet deinen Antrag vor: was gefragt wird, welche Unterlagen du brauchst und wo du ihn stellst.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          for (final a in antraege)
            Builder(builder: (context) {
              final fertig = [
                for (var i = 0; i < a.unterlagen.length; i++)
                  if (store.checklisten['antrag:${a.key}:$i'] == true) i
              ].length;
              return PTKarte(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => AntragScreen(antrag: a))),
                child: Row(
                  children: [
                    IconKachel(a.key == 'kindergeld'
                        ? Icons.child_care_outlined
                        : Icons.house_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.titel,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(a.untertitel,
                              style: const TextStyle(color: PT.grau, fontSize: 13)),
                        ],
                      ),
                    ),
                    Text('$fertig/${a.unterlagen.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class AntragScreen extends StatefulWidget {
  const AntragScreen({super.key, required this.antrag});

  final AntragsHelfer antrag;

  @override
  State<AntragScreen> createState() => _AntragScreenState();
}

class _AntragScreenState extends State<AntragScreen> {
  late final _felder = [
    for (final _ in widget.antrag.fragen) TextEditingController(),
  ];

  @override
  void dispose() {
    for (final f in _felder) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.antrag;
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(a.titel)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          PTKarte(
            farbe: PT.orangeHell,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wo stellst du den Antrag?', style: TextStyle(color: PT.grau)),
                const SizedBox(height: 4),
                Text(a.stelle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text(a.wo, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
          const Abschnitt('1. Diese Unterlagen brauchst du'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < a.unterlagen.length; i++)
                  CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    value: store.checklisten['antrag:${a.key}:$i'] == true,
                    title: Text(a.unterlagen[i]),
                    onChanged: (v) => store.checklistePunkt('antrag:${a.key}:$i', v ?? false),
                  ),
              ],
            ),
          ),
          const Abschnitt('2. Diese Fragen kommen im Antrag'),
          const Text('Trag deine Antworten hier vor. So hast du alles beisammen, wenn du das Formular ausfüllst.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          for (var i = 0; i < a.fragen.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _felder[i],
                decoration: feld(labelText: a.fragen[i]),
              ),
            ),
          const Abschnitt('3. Antrag stellen'),
          FilledButton.icon(
            onPressed: () {
              final text = StringBuffer('${a.titel} – meine Angaben\n\n');
              for (var i = 0; i < a.fragen.length; i++) {
                text.writeln('${a.fragen[i]}\n${_felder[i].text}\n');
              }
              Clipboard.setData(ClipboardData(text: text.toString()));
              zeigeHinweis(context, 'Deine Angaben sind kopiert.');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Meine Angaben kopieren'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Allgemeine Hinweise ohne Gewähr. Maßgeblich ist das offizielle Formular der zuständigen Stelle.',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
