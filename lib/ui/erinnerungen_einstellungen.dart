import 'package:flutter/material.dart';

import '../logic/benachrichtigungen.dart';
import '../logic/handykalender.dart';
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
                  title: const Text('Im Handykalender eintragen'),
                  subtitle: const Text('Fristen, Kündigungen, Garantien und Termine kommen automatisch in deinen Kalender'),
                  value: e.kalenderSync,
                  onChanged: (v) async {
                    if (v) {
                      final ok = await Handykalender.erlaubnis();
                      if (!ok) {
                        if (context.mounted) {
                          zeigeHinweis(context, 'Ohne Erlaubnis kann der Tiger nichts in den Kalender eintragen. '
                              'Du kannst sie in den Handy-Einstellungen unter Apps › Papiertiger erteilen.');
                        }
                        return;
                      }
                      aendern(() => e.kalenderSync = true);
                      final n = await Handykalender.abgleichen(store);
                      if (context.mounted) {
                        zeigeHinweis(context, n == 0 ? 'Eingestellt. Es steht gerade nichts Neues an.' : '$n Einträge im Kalender angelegt.');
                      }
                    } else {
                      aendern(() => e.kalenderSync = false);
                      await Handykalender.alleEntfernen();
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Wochenüberblick'),
                  subtitle: const Text('Montags – nur, wenn in der Woche wirklich etwas ansteht'),
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
