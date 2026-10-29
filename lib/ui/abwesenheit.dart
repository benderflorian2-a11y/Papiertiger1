import 'package:flutter/material.dart';

import '../logic/datum.dart';
import '../logic/zeitplan.dart';
import 'app.dart';
import 'fristen.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Was wird während Urlaub, Krankheit oder Abwesenheit fällig?
class AbwesenheitScreen extends StatefulWidget {
  const AbwesenheitScreen({super.key});

  @override
  State<AbwesenheitScreen> createState() => _AbwesenheitScreenState();
}

class _AbwesenheitScreenState extends State<AbwesenheitScreen> {
  DateTimeRange? _zeitraum;

  Future<void> _waehlen() async {
    final jetzt = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: nurTag(jetzt),
      lastDate: DateTime(jetzt.year + 2),
      helpText: 'Wann bist du weg?',
      saveText: 'Übernehmen',
    );
    if (r != null) setState(() => _zeitraum = r);
  }

  String _tipp(FristEintrag e) => switch (e.f.art) {
        FaelligArt.brief => 'Vorher erledigen oder per Antwort um Fristverlängerung bitten.',
        FaelligArt.vertrag => 'Vor der Abreise kündigen, sonst verlängert sich der Vertrag.',
        FaelligArt.garantie => 'Mängel vorher beim Händler melden.',
        FaelligArt.termin => 'Termin verschieben oder vorziehen.',
        FaelligArt.nachfassen => 'Vor der Abreise nachfragen.',
        FaelligArt.rechnung => 'Zahlungseingang nach der Rückkehr prüfen.',
      };

  @override
  Widget build(BuildContext context) {
    final r = _zeitraum;
    // Auch eine Woche nach der Rückkehr zählt: Dann fehlt oft Zeit zum Reagieren.
    final betroffen = r == null
        ? <FristEintrag>[]
        : alleFristen(StoreScope.of(context))
            .where((e) =>
                !nurTag(e.datum).isBefore(nurTag(r.start)) &&
                !nurTag(e.datum).isAfter(nurTag(r.end).add(const Duration(days: 7))))
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Abwesenheit planen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
              'Urlaub, Krankenhaus oder Dienstreise? Der Tiger zeigt dir, was in dieser Zeit und eine Woche danach fällig wird.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _waehlen,
            icon: const Icon(Icons.date_range),
            label: Text(r == null ? 'Zeitraum wählen' : '${datumKurz(r.start)} bis ${datumKurz(r.end)}'),
          ),
          if (r != null) ...[
            Abschnitt(betroffen.isEmpty
                ? 'Nichts betroffen'
                : '${betroffen.length} ${betroffen.length == 1 ? 'Sache wird' : 'Sachen werden'} fällig'),
            if (betroffen.isEmpty)
              const PTKarte(child: Text('In dieser Zeit ist nichts fällig. Gute Reise!'))
            else
              for (final e in betroffen) ...[
                FristZeile(e),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 16, color: PT.orangeDunkel),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_tipp(e), style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ],
          ],
        ],
      ),
    );
  }
}
