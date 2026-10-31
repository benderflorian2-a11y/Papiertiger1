import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/angebotsvergleich.dart';
import '../../logic/ordnung.dart';
import '../app.dart';
import '../ki_text.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Angebote von Handwerkern, Lieferanten oder Versicherungen nebeneinanderlegen.
class AngeboteVergleichenScreen extends StatefulWidget {
  const AngeboteVergleichenScreen({super.key, this.vorauswahl});

  final String? vorauswahl;

  @override
  State<AngeboteVergleichenScreen> createState() => _AngeboteVergleichenScreenState();
}

class _AngeboteVergleichenScreenState extends State<AngeboteVergleichenScreen> {
  final _gewaehlt = <String>{};
  bool _alle = false;

  @override
  void initState() {
    super.initState();
    if (widget.vorauswahl != null) _gewaehlt.add(widget.vorauswahl!);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final kandidaten = store.briefe.where((b) => _alle || istAngebot(b) || _gewaehlt.contains(b.id)).toList()
      ..sort((a, b) => (b.briefDatum ?? b.erstellt).compareTo(a.briefDatum ?? a.erstellt));
    final auswahl = store.briefe.where((b) => _gewaehlt.contains(b.id)).toList();
    final vergleich = angeboteVergleichen(auswahl);
    return Scaffold(
      appBar: AppBar(title: const Text('Angebote vergleichen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Wähle zwei bis vier Angebote aus deinem Archiv. Der Tiger liest Endbetrag, Gültigkeit und Skonto.',
              style: TextStyle(color: PT.grau)),
          if (vergleich.length >= 2) ...[
            const Abschnitt('Vergleich'),
            for (final (i, a) in vergleich.indexed)
              PTKarte(
                farbe: i == 0 && a.summe != null ? PT.gruenHell : Colors.white,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.anbieter, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if (a.gueltigBis != null) 'gültig bis ${datumKurz(a.gueltigBis!)}',
                          if (a.skonto != null) '${a.skonto!.toStringAsFixed(a.skonto! % 1 == 0 ? 0 : 1)} % Skonto',
                          if (a.zahlungsziel != null) 'zahlbar in ${a.zahlungsziel} Tagen',
                        ].join(' · '),
                        style: const TextStyle(color: PT.grau, fontSize: 13),
                      ),
                    ]),
                  ),
                  Text(a.summe == null ? '?' : euro(a.summe!),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ]),
              ),
            for (final h in vergleichHinweise(vergleich))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• $h', style: const TextStyle(fontSize: 13)),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => KiTextScreen(
                  titel: 'Leistungsumfang vergleichen',
                  anfrage: angebotsvergleichAnfrage(auswahl),
                  hinweis: 'Die KI liest die Angebote. Prüfe Beträge im Original. Das ist keine Beratung.',
                ),
              )),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Was ist enthalten? Mit KI vergleichen'),
            ),
          ],
          Abschnitt(_alle ? 'Alle Schreiben' : 'Angebote im Archiv'),
          if (kandidaten.isEmpty)
            const Text('Kein Angebot gefunden. Fotografiere oder importiere die Angebote zuerst.', style: TextStyle(fontSize: 13)),
          for (final b in kandidaten.take(60))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _gewaehlt.contains(b.id),
              title: Text(titelVon(b)),
              subtitle: Text(datumKurz(b.briefDatum ?? b.erstellt)),
              onChanged: (v) => setState(() {
                if (v == true) {
                  if (_gewaehlt.length >= 4) {
                    zeigeHinweis(context, 'Höchstens vier Angebote auf einmal');
                  } else {
                    _gewaehlt.add(b.id);
                  }
                } else {
                  _gewaehlt.remove(b.id);
                }
              }),
            ),
          TextButton(
            onPressed: () => setState(() => _alle = !_alle),
            child: Text(_alle ? 'Nur Angebote zeigen' : 'Angebot nicht dabei? Alle Schreiben zeigen'),
          ),
        ],
      ),
    );
  }
}
