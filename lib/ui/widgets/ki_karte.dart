import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/ki.dart';
import '../../logic/ki_auswertung.dart';
import '../app.dart';
import '../ki_einrichten.dart';
import '../theme.dart';
import 'common.dart';
import 'tiger.dart';

/// Startet die KI für einen Brief und zeigt den Fortschritt.
class KiKarte extends StatefulWidget {
  const KiKarte({super.key, required this.brief});

  final Brief brief;

  @override
  State<KiKarte> createState() => _KiKarteState();
}

class _KiKarteState extends State<KiKarte> {
  bool? _installiert;
  bool _autoGestartet = false;

  @override
  void initState() {
    super.initState();
    _pruefen();
  }

  Future<void> _pruefen() async {
    final ok = await Ki.istInstalliert();
    if (!mounted) return;
    setState(() => _installiert = ok);
    if (ok && !widget.brief.kiFertig && !_autoGestartet) {
      _autoGestartet = true;
      _starten();
    }
    if (await Ki.absturzHinweisAbholen() && mounted) {
      zeigeHinweis(context,
          'Beim letzten Mal ist die KI abgestürzt. Der Tiger rechnet jetzt mit dem Prozessor – langsamer, aber stabiler.');
    }
  }

  void _starten() {
    if (widget.brief.text.trim().length < 20) return;
    KiAuftraege.instanz.starten(StoreScope.of(context), widget.brief);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: KiAuftraege.instanz,
      builder: (context, _) {
        final auftraege = KiAuftraege.instanz;
        final id = widget.brief.id;

        if (auftraege.laeuft(id)) {
          final roh = auftraege.zwischenstand(id);
          final zwischen = kiAntwortLesen(roh).kurzfassung;
          return PTKarte(
            farbe: PT.orangeHell,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Tiger(size: 40),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Der Tiger liest den ganzen Brief …',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const LinearProgressIndicator(backgroundColor: PT.sand, color: PT.orange),
                const SizedBox(height: 8),
                Text(
                  zwischen.isNotEmpty
                      ? zwischen
                      : roh.isEmpty
                          ? 'Das kann je nach Handy bis zu 2 Minuten dauern. Du kannst die Seite verlassen.'
                          : 'Schreibt die Erklärung …',
                  style: const TextStyle(color: PT.tinte, height: 1.4),
                ),
              ],
            ),
          );
        }

        final fehler = auftraege.fehler(id);
        if (fehler != null) {
          return PTKarte(
            farbe: PT.rotHell,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fehler, style: const TextStyle(color: PT.tinte)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _starten,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nochmal versuchen'),
                ),
              ],
            ),
          );
        }

        if (_installiert == false) {
          // Im Browser gibt es die KI auf dem Gerät nicht
          if (kIsWeb) return const SizedBox.shrink();
          return PTKarte(
            onTap: () async {
              final ok = await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(builder: (_) => const KiEinrichtenScreen()));
              if (ok == true && mounted) {
                _autoGestartet = false;
                _pruefen();
              }
            },
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: PT.orangeDunkel),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ausführliche Erklärung: Lass den Tiger den ganzen Brief lesen. KI einmalig einrichten.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          );
        }

        if (_installiert == true && widget.brief.kiFertig) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _starten,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Nochmal vom Tiger lesen lassen'),
            ),
          );
        }

        if (_installiert == true && !widget.brief.kiFertig) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _starten,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Ganzen Brief vom Tiger lesen lassen'),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
