import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/export.dart';
import '../logic/ki.dart';
import '../logic/ki_anfragen.dart';
import 'app.dart';
import 'ki_einrichten.dart';
import 'theme.dart';
import 'vorlage_screen.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

/// Zeigt die Antwort der KI auf eine Anfrage, Stück für Stück.
class KiTextScreen extends StatefulWidget {
  const KiTextScreen({
    super.key,
    required this.titel,
    required this.anfrage,
    this.alsBrief = false,
    this.hinweis,
    this.brief,
  });

  final String titel;
  final String anfrage;

  /// Ergebnis ist ein Brief, der bearbeitet werden kann.
  final bool alsBrief;
  final String? hinweis;

  /// Brief, auf den geantwortet wird.
  final Brief? brief;

  @override
  State<KiTextScreen> createState() => _KiTextScreenState();
}

class _KiTextScreenState extends State<KiTextScreen> {
  final _text = StringBuffer();
  bool? _installiert;
  bool _laeuft = false;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    Ki.istInstalliert().then((ok) {
      if (!mounted) return;
      setState(() => _installiert = ok);
      if (ok) _start();
    });
  }

  Future<void> _start() async {
    setState(() {
      _text.clear();
      _laeuft = true;
      _fehler = null;
    });
    try {
      await for (final stueck in Ki.text(widget.anfrage, maxAusgabe: 1000, temperatur: 0.3)) {
        if (!mounted) return;
        setState(() => _text.write(stueck));
      }
    } catch (e) {
      if (mounted) setState(() => _fehler = '$e');
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  String get _ergebnis => _text.toString().replaceAll('**', '').trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_installiert == false)
            PTKarte(
              farbe: PT.orangeHell,
              onTap: () async {
                final ok = await Navigator.of(context)
                    .push<bool>(MaterialPageRoute(builder: (_) => const KiEinrichtenScreen()));
                if (ok == true && mounted) {
                  setState(() => _installiert = true);
                  _start();
                }
              },
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: PT.orangeDunkel),
                  SizedBox(width: 12),
                  Expanded(child: Text('Dafür braucht der Tiger die KI. Tippe hier, um sie einzurichten.')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          if (_laeuft)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Tiger(size: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Der Tiger denkt nach … Das kann bis zu 2 Minuten dauern.',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          if (_laeuft) const LinearProgressIndicator(backgroundColor: PT.sand, color: PT.orange),
          if (_fehler != null)
            PTKarte(
              farbe: PT.rotHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Das hat nicht geklappt: $_fehler'),
                  TextButton(onPressed: _start, child: const Text('Nochmal versuchen')),
                ],
              ),
            ),
          if (_ergebnis.isNotEmpty) ...[
            const SizedBox(height: 12),
            PTKarte(child: SelectableText(_ergebnis, style: const TextStyle(fontSize: 15, height: 1.5))),
          ],
          if (widget.hinweis != null && !_laeuft && _ergebnis.isNotEmpty)
            Text(widget.hinweis!, style: const TextStyle(color: PT.grau, fontSize: 12, height: 1.4)),
        ],
      ),
      bottomNavigationBar: _laeuft || _ergebnis.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Neu'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => textTeilen(_ergebnis),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Teilen'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          if (widget.alsBrief) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => VorlageScreen(titel: widget.titel, text: _ergebnis, brief: widget.brief)));
                          } else {
                            Clipboard.setData(ClipboardData(text: _ergebnis));
                            zeigeHinweis(context, 'Kopiert');
                          }
                        },
                        icon: Icon(widget.alsBrief ? Icons.edit_outlined : Icons.copy),
                        label: Text(widget.alsBrief ? 'Bearbeiten' : 'Kopieren'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Fragt Ziel und Ton ab und lässt die KI einen Antwortbrief schreiben.
class KiAntwortScreen extends StatefulWidget {
  const KiAntwortScreen({super.key, required this.brief});

  final Brief brief;

  @override
  State<KiAntwortScreen> createState() => _KiAntwortScreenState();
}

class _KiAntwortScreenState extends State<KiAntwortScreen> {
  String _ziel = antwortZiele.first;
  String _ton = antwortToene.first;
  String _sprache = 'Deutsch';
  final _inhalt = TextEditingController();

  @override
  void dispose() {
    _inhalt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profil = StoreScope.of(context).profil;
    return Scaffold(
      appBar: AppBar(title: const Text('Antwort mit KI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Was willst du erreichen?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final z in antwortZiele)
              ChoiceChip(label: Text(z), selected: _ziel == z, onSelected: (_) => setState(() => _ziel = z)),
          ]),
          const SizedBox(height: 16),
          const Text('Wie soll der Brief klingen?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final t in antwortToene)
              ChoiceChip(label: Text(t), selected: _ton == t, onSelected: (_) => setState(() => _ton = t)),
          ]),
          const SizedBox(height: 16),
          const Text('Sprache', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final s in const ['Deutsch', 'Englisch', 'Türkisch', 'Arabisch', 'Ukrainisch'])
              ChoiceChip(label: Text(s), selected: _sprache == s, onSelected: (_) => setState(() => _sprache = s)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _inhalt,
            minLines: 3,
            maxLines: 6,
            decoration: feld(
                labelText: 'Was soll drinstehen? (optional)',
                hintText: 'z. B. Ich habe die Rechnung schon am 3. Oktober bezahlt.'),
          ),
          const SizedBox(height: 12),
          if (_ziel.startsWith('Widerspruch'))
            const PTKarte(
              farbe: PT.gelbHell,
              child: Text(
                  'Ein Widerspruch hat rechtliche Folgen. Nutze den Entwurf als Grundlage und lass ihn im Zweifel prüfen, '
                  'z. B. bei einer Beratungsstelle, der Verbraucherzentrale oder einem Anwalt.'),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Brief schreiben lassen'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => KiTextScreen(
                titel: _ziel,
                alsBrief: true,
                brief: widget.brief,
                anfrage: antwortAnfrage(widget.brief, profil,
                    ziel: _ziel, ton: _ton, inhalt: _inhalt.text, sprache: _sprache),
                hinweis: 'Entwurf der KI. Prüfe alle Angaben, bevor du ihn verschickst.',
              ),
            )),
          ),
        ),
      ),
    );
  }
}
