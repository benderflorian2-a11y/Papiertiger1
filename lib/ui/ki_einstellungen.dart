import 'package:flutter/material.dart';

import '../logic/ki.dart';
import 'ki_einrichten.dart';
import 'theme.dart';
import 'widgets/common.dart';

class KiEinstellungenScreen extends StatefulWidget {
  const KiEinstellungenScreen({super.key});

  @override
  State<KiEinstellungenScreen> createState() => _KiEinstellungenScreenState();
}

class _KiEinstellungenScreenState extends State<KiEinstellungenScreen> {
  bool? _installiert;
  bool _cpu = false;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final ok = await Ki.istInstalliert();
    final cpu = await Ki.nutztProzessor();
    if (mounted) {
      setState(() {
        _installiert = ok;
        _cpu = cpu;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KI-Tiger')),
      body: _installiert == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PTKarte(
                  farbe: _installiert! ? PT.gruenHell : PT.orangeHell,
                  child: Row(
                    children: [
                      Icon(_installiert! ? Icons.check_circle : Icons.download_outlined,
                          color: _installiert! ? PT.gruen : PT.orangeDunkel),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _installiert!
                              ? 'Die KI ist installiert und liest neue Briefe automatisch.'
                              : 'Die KI ist noch nicht installiert.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_installiert!)
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const KiEinrichtenScreen()));
                      _laden();
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('KI einrichten (${Ki.groesse})'),
                  )
                else ...[
                  PTKarte(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SwitchListTile(
                      title: const Text('Stabiler Modus'),
                      subtitle: const Text(
                          'Rechnet mit dem Prozessor statt dem Grafikchip. Langsamer, aber sicherer auf älteren Handys.'),
                      value: _cpu,
                      onChanged: (v) async {
                        await Ki.setzeProzessor(v);
                        setState(() => _cpu = v);
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('KI löschen?'),
                          content: const Text(
                              'Das gibt ${Ki.groesse} Speicher frei. Deine Briefe bleiben erhalten. Du kannst die KI später wieder herunterladen.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(d, false),
                                child: const Text('Abbrechen')),
                            TextButton(
                                onPressed: () => Navigator.pop(d, true),
                                child: const Text('Löschen')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await Ki.loeschen();
                        _laden();
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('KI vom Handy löschen'),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Die KI ist Googles Sprachmodell Gemma 4 und läuft komplett offline auf deinem Handy. '
                  'Sie kann sich irren. Fristen und Beträge prüft der Tiger zusätzlich mit dem Brieftext – '
                  'kontrolliere wichtige Angaben trotzdem immer im Original.',
                  style: TextStyle(color: PT.grau, fontSize: 13, height: 1.45),
                ),
              ],
            ),
    );
  }
}
