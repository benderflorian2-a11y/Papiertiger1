import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' show CancelToken;

import '../logic/ki.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

/// Lädt das KI-Modell einmalig herunter.
class KiEinrichtenScreen extends StatefulWidget {
  const KiEinrichtenScreen({super.key});

  @override
  State<KiEinrichtenScreen> createState() => _KiEinrichtenScreenState();
}

enum _Stand { pruefen, bereit, laedt, fertig, fehler }

class _KiEinrichtenScreenState extends State<KiEinrichtenScreen> {
  _Stand _stand = _Stand.pruefen;
  int _prozent = 0;
  String _fehler = '';
  CancelToken? _abbruch;

  @override
  void initState() {
    super.initState();
    Ki.istInstalliert().then((ok) {
      if (mounted) setState(() => _stand = ok ? _Stand.fertig : _Stand.bereit);
    });
  }

  Future<void> _laden() async {
    final abbruch = CancelToken();
    setState(() {
      _abbruch = abbruch;
      _stand = _Stand.laedt;
      _prozent = 0;
    });
    try {
      await Ki.herunterladen((p) {
        if (mounted) setState(() => _prozent = p);
      }, abbruch);
      if (mounted) setState(() => _stand = _Stand.fertig);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stand = _Stand.fehler;
        _fehler = CancelToken.isCancel(e) ? 'Download abgebrochen.' : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KI einrichten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: Tiger(size: 96)),
          const SizedBox(height: 16),
          const Text('Der Tiger liest jeden Brief komplett',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: PT.tinte)),
          const SizedBox(height: 12),
          const Text(
            'Mit der KI fasst Papiertiger jeden Brief in einfachen Worten zusammen, '
            'erklärt, was er für dich bedeutet, und sagt dir, was zu tun ist.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.45, color: PT.grau),
          ),
          const SizedBox(height: 20),
          const PTKarte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Punkt(Icons.lock_outline, 'Läuft komplett auf deinem Handy. Deine Briefe verlassen nie das Gerät.'),
                _Punkt(Icons.download_outlined, 'Einmaliger Download von ${Ki.groesse}. Am besten im WLAN.'),
                _Punkt(Icons.sd_storage_outlined, 'Braucht etwa 3 GB freien Speicher.'),
                _Punkt(Icons.timer_outlined, 'Ein Brief dauert je nach Handy etwa 20 Sekunden bis 2 Minuten.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          switch (_stand) {
            _Stand.pruefen => const Center(child: CircularProgressIndicator()),
            _Stand.bereit => FilledButton.icon(
                key: const ValueKey('ki-laden'),
                onPressed: _laden,
                icon: const Icon(Icons.download),
                label: const Text('KI herunterladen (${Ki.groesse})'),
              ),
            _Stand.laedt => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Wird heruntergeladen … $_prozent %',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _prozent / 100,
                      minHeight: 10,
                      backgroundColor: PT.sand,
                      color: PT.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Du kannst die App dabei offen lassen. Der Download läuft auch weiter, wenn der Bildschirm ausgeht.',
                      style: TextStyle(color: PT.grau, fontSize: 13)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _abbruch?.cancel('Abgebrochen'),
                    child: const Text('Abbrechen'),
                  ),
                ],
              ),
            _Stand.fertig => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PTKarte(
                    farbe: PT.gruenHell,
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: PT.gruen),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Die KI ist bereit. Öffne einen Brief, und der Tiger liest ihn komplett.',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Fertig'),
                  ),
                ],
              ),
            _Stand.fehler => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PTKarte(
                    farbe: PT.rotHell,
                    child: Text('Der Download hat nicht geklappt.\n\n$_fehler',
                        style: const TextStyle(color: PT.tinte)),
                  ),
                  FilledButton(onPressed: _laden, child: const Text('Nochmal versuchen')),
                ],
              ),
          },
        ],
      ),
    );
  }
}

class _Punkt extends StatelessWidget {
  const _Punkt(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: PT.orangeDunkel, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
