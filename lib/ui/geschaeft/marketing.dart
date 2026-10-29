import 'package:flutter/material.dart';

import '../../logic/android_kanal.dart';
import '../../logic/kommunikation.dart';
import '../../logic/marketing.dart';
import '../app.dart';
import '../ki_text.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'geschaeft.dart';

class MarketingScreen extends StatelessWidget {
  const MarketingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final heute = DateTime.now();
    final wieder = wiederAnsprechen(store.kunden, store.rechnungen, heute: heute);
    final angebote = angeboteNachfassen(store.rechnungen, heute: heute);
    return Scaffold(
      appBar: AppBar(title: const Text('Marketing')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Texte schreiben lassen', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          for (final a in marketingArten)
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MarketingText(art: a))),
              child: Row(children: [
                const IconKachel(Icons.auto_awesome),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(a.beschreibung, style: const TextStyle(color: PT.grau, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ]),
            ),
          if (angebote.isNotEmpty) ...[
            const Abschnitt('Angebote ohne Antwort'),
            for (final r in angebote) RechnungZeile(r),
          ],
          if (wieder.isNotEmpty) ...[
            const Abschnitt('Lange nichts gehört'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final (k, letzte) in wieder)
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: PT.orangeDunkel),
                    title: Text(k.name),
                    subtitle: Text('Letzter Auftrag ${datumKurz(letzte)}'),
                    trailing: k.email.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.alternate_email),
                            onPressed: () => AndroidKanal.oeffnen(mailtoLink(
                                an: k.email,
                                betreff: 'Gruß von ${store.firma.name}',
                                text: 'Hallo ${k.name},\n\n'
                                    'unser letzter Auftrag ist schon eine Weile her – ich hoffe, alles läuft gut. '
                                    'Wenn ich wieder helfen kann, melden Sie sich gern.\n\nViele Grüße\n${store.firma.name}')),
                          ),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Werbe-E-Mails nur an Kunden, die eingewilligt haben – oder an Bestandskunden für ähnliche Leistungen, '
            'wenn du sie auf ihr Widerspruchsrecht hingewiesen hast. Im Zweifel vorher fragen.',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class MarketingText extends StatefulWidget {
  const MarketingText({super.key, required this.art});

  final MarketingArt art;

  @override
  State<MarketingText> createState() => _MarketingTextState();
}

class _MarketingTextState extends State<MarketingText> {
  final _thema = TextEditingController();
  final _zielgruppe = TextEditingController();
  String _ton = marketingToene.first;

  @override
  void dispose() {
    _thema.dispose();
    _zielgruppe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final antwort = widget.art.key == 'antwort';
    return Scaffold(
      appBar: AppBar(title: Text(widget.art.titel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _thema,
            minLines: 3,
            maxLines: 8,
            decoration: feld(
              labelText: antwort ? 'Die Bewertung des Kunden' : 'Worum geht es?',
              hintText: antwort
                  ? 'Bewertung hier einfügen'
                  : 'z. B. Neue Öffnungszeiten ab Dezember, Termine für Fenster-Reinigung frei',
            ),
          ),
          const SizedBox(height: 12),
          if (!antwort)
            TextField(
              controller: _zielgruppe,
              decoration: feld(labelText: 'Für wen? (optional)', hintText: 'z. B. Familien im Stadtteil'),
            ),
          const SizedBox(height: 12),
          const Text('Ton', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final t in marketingToene)
              ChoiceChip(label: Text(t), selected: _ton == t, onSelected: (_) => setState(() => _ton = t)),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Text schreiben lassen'),
            onPressed: () {
              if (_thema.text.trim().isEmpty) {
                zeigeHinweis(context, 'Schreib kurz, worum es gehen soll.');
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => KiTextScreen(
                  titel: widget.art.titel,
                  anfrage: marketingAnfrage(widget.art, store.firma,
                      thema: _thema.text, zielgruppe: _zielgruppe.text, ton: _ton),
                  hinweis: 'Entwurf der KI. Prüfe Fakten, Preise und Rechte an Bildern, bevor du ihn veröffentlichst.',
                ),
              ));
            },
          ),
        ),
      ),
    );
  }
}
