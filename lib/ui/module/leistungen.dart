import 'package:flutter/material.dart';

import '../../logic/inhalte.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tiger.dart';

class LeistungenScreen extends StatefulWidget {
  const LeistungenScreen({super.key});

  @override
  State<LeistungenScreen> createState() => _LeistungenScreenState();
}

class _LeistungenScreenState extends State<LeistungenScreen> {
  final Map<String, bool> _antworten = {};

  @override
  Widget build(BuildContext context) {
    final treffer = leistungen.where((l) => l.bedingung(_antworten)).toList();
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
                    value: _antworten[f.key] == true,
                    onChanged: (v) => setState(() => _antworten[f.key] = v),
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
