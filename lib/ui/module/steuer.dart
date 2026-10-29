import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/brief_analyse.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

class _Posten {
  _Posten(this.datum, this.titel, this.kategorie, this.betrag);

  final DateTime datum;
  final String titel;
  final String kategorie;
  final double? betrag;
}

class SteuerScreen extends StatefulWidget {
  const SteuerScreen({super.key});

  @override
  State<SteuerScreen> createState() => _SteuerScreenState();
}

class _SteuerScreenState extends State<SteuerScreen> {
  int _jahr = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final alle = <_Posten>[
      for (final b in store.belege)
        if (b.steuerKategorie != null)
          _Posten(b.datum, b.haendler.isEmpty ? 'Beleg' : b.haendler, b.steuerKategorie!, b.betrag),
      for (final b in store.briefe)
        if (b.steuerKategorie != null)
          _Posten(b.briefDatum ?? b.erstellt, b.absenderName ?? kategorieFuer(b.kategorie).name,
              b.steuerKategorie!, b.guthaben ? null : b.betrag),
    ];
    final jahre = <int>{DateTime.now().year, for (final p in alle) p.datum.year}.toList()
      ..sort((a, b) => b.compareTo(a));
    final posten = alle.where((p) => p.datum.year == _jahr).toList()
      ..sort((a, b) => a.datum.compareTo(b.datum));
    final summen = <String, double>{};
    for (final p in posten) {
      summen[p.kategorie] = (summen[p.kategorie] ?? 0) + (p.betrag ?? 0);
    }
    final gesamt = summen.values.fold<double>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Steuer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
              'Markiere Belege und Briefe als steuerlich relevant. Hier siehst du alles gesammelt für deine Steuererklärung.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final j in jahre)
                ChoiceChip(
                  label: Text('$j'),
                  selected: _jahr == j,
                  onSelected: (_) => setState(() => _jahr = j),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PTKarte(
            farbe: PT.orangeHell,
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: PT.orangeDunkel),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${posten.length} Posten · ${euro(gesamt)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
          ),
          if (posten.isEmpty)
            const LeerHinweis(
                icon: Icons.calculate_outlined,
                text: 'Noch nichts für dieses Jahr markiert.')
          else ...[
            const Abschnitt('Nach Kategorie'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in summen.entries)
                    ListTile(title: Text(e.key), trailing: Text(euro(e.value))),
                ],
              ),
            ),
            const Abschnitt('Alle Posten'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final p in posten)
                    ListTile(
                      title: Text(p.titel, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${datumKurz(p.datum)} · ${p.kategorie}'),
                      trailing: Text(p.betrag != null ? euro(p.betrag!) : '–'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                final csv = StringBuffer('Datum;Beschreibung;Kategorie;Betrag\n');
                for (final p in posten) {
                  final betrag = p.betrag?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
                  final titel = p.titel.replaceAll(';', ',');
                  csv.writeln('${datumKurz(p.datum)};$titel;${p.kategorie};$betrag');
                }
                Clipboard.setData(ClipboardData(text: csv.toString()));
                zeigeHinweis(context, 'Liste kopiert – z. B. in eine E-Mail oder Tabelle einfügen.');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Liste kopieren (für Tabelle)'),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Keine Steuerberatung. Ob etwas absetzbar ist, hängt von deiner Situation ab.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}
