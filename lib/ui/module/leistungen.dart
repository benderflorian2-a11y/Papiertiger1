import 'package:flutter/material.dart';

import '../../logic/android_kanal.dart';
import '../../logic/inhalte.dart';
import '../app.dart';
import 'antraege.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tiger.dart';

class LeistungenScreen extends StatelessWidget {
  const LeistungenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // Antworten bleiben gespeichert, damit du nicht jedes Mal neu anfangen musst.
    final antworten = {for (final f in leistungsFragen) f.key: store.checklisten['leistung:${f.key}'] == true};
    final treffer = leistungen.where((l) => l.bedingung(antworten)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Was steht mir zu?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const PTKarte(
            farbe: PT.orangeHell,
            child: Row(
              children: [
                Tiger(size: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Beantworte ein paar Fragen. Der Tiger zeigt dir, welche Leistungen du prüfen solltest.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final f in leistungsFragen)
                  SwitchListTile(
                    title: Text(f.text, style: const TextStyle(fontSize: 15)),
                    value: antworten[f.key] == true,
                    onChanged: (v) => store.checklistePunkt('leistung:${f.key}', v),
                  ),
              ],
            ),
          ),
          Abschnitt(treffer.isEmpty
              ? 'Mögliche Leistungen'
              : '${treffer.length} mögliche ${treffer.length == 1 ? 'Leistung' : 'Leistungen'}'),
          if (treffer.isEmpty)
            const PTKarte(
              child: Text('Beantworte die Fragen oben, dann erscheinen hier passende Leistungen.',
                  style: TextStyle(color: PT.grau)),
            )
          else
            for (final l in treffer)
              PTKarte(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.titel,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(l.text, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16, color: PT.orangeDunkel),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(l.stelle,
                              style: const TextStyle(color: PT.grau, fontSize: 13)),
                        ),
                      ],
                    ),
                    Wrap(spacing: 4, children: [
                      if (l.antrag != null && antragMitKey(l.antrag!) != null)
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => AntragScreen(antrag: antragMitKey(l.antrag!)!))),
                          icon: const Icon(Icons.assignment_outlined, size: 18),
                          label: const Text('Antrag vorbereiten'),
                        ),
                      if (l.link != null)
                        TextButton.icon(
                          onPressed: () => AndroidKanal.oeffnen(Uri.parse(l.link!)),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Offizielle Infos'),
                        ),
                    ]),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          const Text(
            'Nur eine erste Orientierung, keine Garantie. Ob du einen Anspruch hast, entscheidet die zuständige Stelle. '
            'Kostenlose Hilfe gibt es bei Sozialberatungsstellen, z. B. von Caritas, Diakonie oder der Verbraucherzentrale.',
            style: TextStyle(color: PT.grau, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
