import 'package:flutter/material.dart';

import '../logic/benachrichtigungen.dart';
import 'app.dart';
import 'theme.dart';
import 'widgets/common.dart';

class ErinnerungenEinstellungen extends StatelessWidget {
  const ErinnerungenEinstellungen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = store.erinnerungen;
    void aendern(VoidCallback f) {
      f();
      store.geaendert();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Erinnerungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push-Erinnerungen'),
                  subtitle: const Text('Vor Fristen, Kündigungen, Garantien und Terminen'),
                  value: e.aktiv,
                  onChanged: (v) async {
                    if (v) await Benachrichtigungen.erlaubnisAnfragen();
                    aendern(() => e.aktiv = v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Wochenüberblick'),
                  subtitle: const Text('Jeden Montag: Was steht diese Woche an?'),
                  value: e.wochenueberblick,
                  onChanged: e.aktiv ? (v) => aendern(() => e.wochenueberblick = v) : null,
                ),
              ],
            ),
          ),
          const Abschnitt('Wann erinnern?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (t, label) in const [(14, '14 Tage vorher'), (7, '7 Tage'), (3, '3 Tage'), (1, '1 Tag'), (0, 'Am Tag')])
              FilterChip(
                label: Text(label),
                selected: e.tageVorher.contains(t),
                onSelected: e.aktiv
                    ? (an) => aendern(() {
                          if (an) {
                            e.tageVorher.add(t);
                          } else if (e.tageVorher.length > 1) {
                            e.tageVorher.remove(t);
                          }
                        })
                    : null,
              ),
          ]),
          const Abschnitt('Uhrzeit'),
          Wrap(spacing: 8, children: [
            for (final h in const [7, 9, 12, 18, 20])
              ChoiceChip(
                label: Text('$h Uhr'),
                selected: e.stunde == h,
                onSelected: e.aktiv ? (_) => aendern(() => e.stunde = h) : null,
              ),
          ]),
          const SizedBox(height: 16),
          const Text(
            'Die Erinnerungen werden auf deinem Handy geplant, ohne Internet. '
            'Sie kommen ungefähr zur gewählten Uhrzeit, Android kann sie um einige Minuten verschieben.',
            style: TextStyle(color: PT.grau, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
