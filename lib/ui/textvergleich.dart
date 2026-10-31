import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/ki_anfragen.dart';
import '../logic/ordnung.dart';
import '../logic/textvergleich.dart';
import 'ki_text.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Zwei Dokumente nebeneinander: was ist weggefallen, was ist neu? Funktioniert auch ohne KI.
class TextVergleichScreen extends StatefulWidget {
  const TextVergleichScreen({super.key, required this.alt, required this.neu});

  final Brief alt;
  final Brief neu;

  @override
  State<TextVergleichScreen> createState() => _TextVergleichScreenState();
}

class _TextVergleichScreenState extends State<TextVergleichScreen> {
  bool _alles = false;

  @override
  Widget build(BuildContext context) {
    final d = textUnterschiede(widget.alt.text, widget.neu.text);
    final geaendert = d.where((e) => e.$1 != Aenderung.gleich).length;
    final wichtig = d.where((e) => e.$1 != Aenderung.gleich && enthaeltWerte(e.$2)).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Was hat sich geändert?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('Alt: ${titelVon(widget.alt)} (${datumKurz(widget.alt.briefDatum ?? widget.alt.erstellt)})\n'
              'Neu: ${titelVon(widget.neu)} (${datumKurz(widget.neu.briefDatum ?? widget.neu.erstellt)})',
              style: const TextStyle(color: PT.grau, fontSize: 13)),
          const SizedBox(height: 8),
          PTKarte(
            farbe: geaendert == 0 ? PT.gruenHell : PT.gelbHell,
            child: Text(geaendert == 0
                ? 'Der Text ist gleich geblieben.'
                : '$geaendert Stellen geändert${wichtig > 0 ? ', davon $wichtig mit Beträgen, Prozenten oder Daten' : ''}. '
                    'Rot ist weggefallen, grün ist neu.'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => KiTextScreen(
                titel: 'Vergleich',
                anfrage: vergleichAnfrage(widget.alt, widget.neu),
                hinweis: 'Vergleich durch die KI. Prüfe wichtige Werte im Original.',
              ),
            )),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Mit KI in einfachen Worten erklären'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Unveränderte Stellen zeigen'),
            value: _alles,
            onChanged: (v) => setState(() => _alles = v),
          ),
          for (final (art, satz) in d)
            if (_alles || art != Aenderung.gleich)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: switch (art) {
                    Aenderung.entfernt => const Color(0xFFFBE3E1),
                    Aenderung.neu => PT.gruenHell,
                    Aenderung.gleich => Colors.transparent,
                  },
                  borderRadius: BorderRadius.circular(6),
                  border: enthaeltWerte(satz) && art != Aenderung.gleich ? Border.all(color: PT.orangeDunkel) : null,
                ),
                child: Text(
                  '${switch (art) { Aenderung.entfernt => '− ', Aenderung.neu => '+ ', Aenderung.gleich => '' }}$satz',
                  style: TextStyle(
                    color: art == Aenderung.gleich ? PT.grau : PT.tinte,
                    decoration: art == Aenderung.entfernt ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
