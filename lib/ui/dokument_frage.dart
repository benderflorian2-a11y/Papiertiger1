import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/dokument_frage.dart';
import '../logic/ki_anfragen.dart';
import 'ki_text.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Eine Frage an ein Dokument stellen, z. B. „Wie entkalke ich die Maschine?“ an die Bedienungsanleitung.
class DokumentFrageScreen extends StatefulWidget {
  const DokumentFrageScreen({super.key, required this.brief});

  final Brief brief;

  @override
  State<DokumentFrageScreen> createState() => _DokumentFrageScreenState();
}

class _DokumentFrageScreenState extends State<DokumentFrageScreen> {
  final _c = TextEditingController();
  String _frage = '';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stellen = _frage.isEmpty ? <String>[] : textstellenFinden(widget.brief.text, _frage);
    return Scaffold(
      appBar: AppBar(title: const Text('Frag das Dokument')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Zum Beispiel: „Wie entkalke ich das Gerät?“, „Wann endet die Garantie?“, „Was kostet die Kündigung?“',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 8),
          TextField(
            controller: _c,
            textInputAction: TextInputAction.search,
            decoration: feld(hintText: 'Deine Frage', prefixIcon: const Icon(Icons.help_outline)),
            onSubmitted: (t) => setState(() => _frage = t.trim()),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _frage = _c.text.trim()),
                icon: const Icon(Icons.search),
                label: const Text('Stellen suchen'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _c.text.trim().isEmpty && _frage.isEmpty
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => KiTextScreen(
                            titel: 'Antwort aus dem Dokument',
                            anfrage: dokumentFrageAnfrage(widget.brief, _c.text.trim()),
                            hinweis: 'Die KI antwortet nur aus diesem Dokument. Prüfe die zitierte Stelle.',
                          ),
                        )),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('KI fragen'),
              ),
            ),
          ]),
          if (_frage.isNotEmpty) ...[
            Abschnitt(stellen.isEmpty ? 'Keine passende Stelle gefunden' : 'Passende Stellen'),
            for (final s in stellen) PTKarte(padding: const EdgeInsets.all(12), child: SelectableText(s)),
            if (stellen.isEmpty)
              const Text('Versuch andere Wörter oder frag die KI.', style: TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
