import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'module/profil.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Zeigt ein Musterschreiben zum Bearbeiten und Kopieren.
class VorlageScreen extends StatefulWidget {
  const VorlageScreen({super.key, required this.titel, required this.text});

  final String titel;
  final String text;

  @override
  State<VorlageScreen> createState() => _VorlageScreenState();
}

class _VorlageScreenState extends State<VorlageScreen> {
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profil = StoreScope.of(context).profil;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (profil.name.isEmpty || profil.adresse.isEmpty)
            PTKarte(
              farbe: PT.gelbHell,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfilScreen())),
              child: const Row(
                children: [
                  Icon(Icons.person_outline, color: PT.gelb),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Trag deinen Namen und deine Adresse ein, dann stehen sie automatisch im Brief.'),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          const Text(
            'Ersetze die Stellen in [eckigen Klammern] und prüfe den Text, bevor du ihn verschickst.',
            style: TextStyle(color: PT.grau),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 14,
            maxLines: null,
            style: const TextStyle(height: 1.45),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _text.text));
              zeigeHinweis(context, 'Text kopiert – jetzt in E-Mail oder Textprogramm einfügen.');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Text kopieren'),
          ),
        ),
      ),
    );
  }
}
