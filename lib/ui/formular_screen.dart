import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/formular.dart';
import '../logic/ki.dart';
import 'app.dart';
import 'module/profil.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

/// Zeigt zu einem Formular, was wo eingetragen werden muss.
class FormularScreen extends StatefulWidget {
  const FormularScreen({super.key, required this.brief});

  final Brief brief;

  @override
  State<FormularScreen> createState() => _FormularScreenState();
}

class _FormularScreenState extends State<FormularScreen> {
  FormularHilfe? _hilfe;
  bool _kiLaeuft = false;
  bool _kiDa = false;
  bool _vonKi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hilfe ??= formularErkennen(widget.brief.text, StoreScope.of(context).profil);
  }

  @override
  void initState() {
    super.initState();
    Ki.istInstalliert().then((ok) {
      if (mounted) setState(() => _kiDa = ok);
    });
  }

  Future<void> _mitKi() async {
    final profil = StoreScope.of(context).profil;
    setState(() => _kiLaeuft = true);
    try {
      final antwort = StringBuffer();
      await for (final s in Ki.text(formularAnfrage(widget.brief.text, profil), maxAusgabe: 1200, temperatur: 0.1)) {
        antwort.write(s);
      }
      final h = formularAntwortLesen(antwort.toString());
      if (!mounted) return;
      if (h.felder.isEmpty) {
        zeigeHinweis(context, 'Die KI hat keine Felder gefunden.');
      } else {
        setState(() {
          _hilfe = h;
          _vonKi = true;
        });
      }
    } catch (e) {
      if (mounted) zeigeHinweis(context, 'Die KI konnte das Formular nicht lesen: $e');
    } finally {
      if (mounted) setState(() => _kiLaeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _hilfe!;
    return Scaffold(
      appBar: AppBar(title: const Text('Formular ausfüllen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PTKarte(
            farbe: PT.orangeHell,
            child: Row(
              children: [
                const Tiger(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    h.felder.isEmpty
                        ? 'Der Tiger hat keine Formularfelder erkannt.'
                        : 'Der Tiger hat ${h.felder.length} Felder gefunden. Werte aus deinem Profil stehen daneben – zum Abschreiben oder Kopieren.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (_kiDa && !_vonKi)
            OutlinedButton.icon(
              onPressed: _kiLaeuft ? null : _mitKi,
              icon: _kiLaeuft
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_kiLaeuft ? 'Die KI liest das Formular …' : 'Genauer mit KI auswerten'),
            ),
          if (h.felder.isNotEmpty) ...[
            const Abschnitt('Felder'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final f in h.felder)
                    ListTile(
                      title: Text(f.label, style: const TextStyle(color: PT.grau, fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.wert ?? 'fehlt noch',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: f.wert == null ? PT.rot : PT.tinte)),
                          if (f.hinweis.isNotEmpty)
                            Text(f.hinweis, style: const TextStyle(fontSize: 12, color: PT.grau)),
                        ],
                      ),
                      trailing: f.wert == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: f.wert!));
                                zeigeHinweis(context, '${f.label} kopiert');
                              },
                            ),
                    ),
                ],
              ),
            ),
          ],
          if (h.unterschriften.isNotEmpty) ...[
            const Abschnitt('Hier unterschreiben'),
            PTKarte(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final u in h.unterschriften)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.draw_outlined, color: PT.orangeDunkel, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(u)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (h.fehlt.isNotEmpty) ...[
            const Abschnitt('Fehlt noch'),
            PTKarte(
              farbe: PT.gelbHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in h.fehlt) Text('• $f', style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ProfilScreen()))
                        .then((_) {
                      if (mounted) {
                        setState(() => _hilfe = formularErkennen(
                            widget.brief.text, StoreScope.of(context).profil));
                        _vonKi = false;
                      }
                    }),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Angaben im Profil ergänzen'),
                  ),
                ],
              ),
            ),
          ],
          const Text('Prüfe alle Werte, bevor du das Formular abgibst.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}
