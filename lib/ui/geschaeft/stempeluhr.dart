import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/geschaeft.dart';
import '../../logic/arbeitszeit.dart';
import '../../logic/export.dart';
import '../../logic/plantafel.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

String _dauer(int minuten) => '${minuten ~/ 60}:${(minuten % 60).toString().padLeft(2, '0')} Std.';

/// Stempeluhr: Arbeits- und Fahrtzeit je Person auf ein Projekt buchen.
class StempeluhrScreen extends StatefulWidget {
  const StempeluhrScreen({super.key});

  @override
  State<StempeluhrScreen> createState() => _StempeluhrScreenState();
}

class _StempeluhrScreenState extends State<StempeluhrScreen> {
  Timer? _takt;

  @override
  void initState() {
    super.initState();
    _takt = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _takt?.cancel();
    super.dispose();
  }

  List<String> _personen() {
    final store = StoreScope.of(context);
    if (store.mitarbeiter.isNotEmpty) return store.mitarbeiter;
    final ich = store.profil.vorname;
    return [ich.isEmpty ? 'Ich' : ich];
  }

  Future<void> _starten(String person, {required bool fahrt}) async {
    final store = StoreScope.of(context);
    final offen = store.projekte.where((p) => p.status != 'Abgerechnet').toList();
    if (offen.isEmpty) {
      zeigeHinweis(context, 'Leg zuerst ein Projekt an.');
      return;
    }
    // Vorschlag: Einsatz laut Plantafel
    final geplant = einsatzVon(store.einsaetze, person, DateTime.now())?.projektId;
    final id = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(fahrt ? 'Fahrt zu welchem Projekt?' : 'Auf welches Projekt?'),
        children: [
          for (final p in offen)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(d, p.id),
              child: Text(p.id == geplant ? '${p.name}  (laut Plantafel)' : p.name,
                  style: TextStyle(fontWeight: p.id == geplant ? FontWeight.w700 : FontWeight.normal)),
            ),
        ],
      ),
    );
    if (id == null) return;
    store.stempel.add(Stempel(person: person, projektId: id, start: DateTime.now(), fahrt: fahrt));
    await store.geaendert();
  }

  Future<void> _beenden(Stempel s) async {
    final store = StoreScope.of(context);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${s.person}: ${_dauer(laufendeMinuten(s, DateTime.now()))}'),
        content: TextField(controller: c, decoration: feld(labelText: 'Was wurde gemacht? (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Weiter arbeiten')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Beenden')),
        ],
      ),
    );
    final text = c.text.trim();
    c.dispose();
    if (ok != true) return;
    final z = stempelBeenden(s, DateTime.now(), text: text);
    final p = store.projekte.where((x) => x.id == s.projektId).firstOrNull;
    p?.zeiten.add(z);
    store.stempel.remove(s);
    await store.geaendert();
    if (!mounted) return;
    final (h, pause) = tagesZeit(store.projekte, s.person, DateTime.now());
    final hinweise = arbeitszeitHinweise(h, pause);
    zeigeHinweis(context,
        '${z.stunden.toStringAsFixed(2).replaceAll('.', ',')} Std. auf ${p?.name ?? 'Projekt'} gebucht${hinweise.isEmpty ? '' : '. ${hinweise.first}'}');
  }

  Future<void> _stundenliste() async {
    final store = StoreScope.of(context);
    final jetzt = DateTime.now();
    final monat = await showDialog<DateTime>(
      context: context,
      builder: (d) => SimpleDialog(
        title: const Text('Stundenliste für'),
        children: [
          for (var i = 0; i < 3; i++)
            Builder(builder: (_) {
              final m = DateTime(jetzt.year, jetzt.month - i);
              return SimpleDialogOption(onPressed: () => Navigator.pop(d, m), child: Text('${m.month}/${m.year}'));
            }),
        ],
      ),
    );
    if (monat == null) return;
    final datei = await textDatei('Stundenliste ${monat.month}-${monat.year}.csv',
        stundenliste(store.projekte, jahr: monat.year, monat: monat.month));
    await dateiTeilen(datei.path, mimeType: 'text/csv');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final jetzt = DateTime.now();
    final namen = {for (final p in store.projekte) p.id: p.name};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stempeluhr'),
        actions: [
          IconButton(tooltip: 'Stundenliste für den Lohn', icon: const Icon(Icons.table_chart_outlined), onPressed: _stundenliste),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final person in _personen())
          Builder(builder: (_) {
            final s = store.stempel.where((x) => x.person == person).firstOrNull;
            final (h, pause) = tagesZeit(store.projekte, person, jetzt);
            final laufend = s == null ? 0 : laufendeMinuten(s, jetzt);
            final hinweise = arbeitszeitHinweise(h + laufend / 60, pause + (s?.pauseMinuten ?? 0));
            return PTKarte(
              farbe: s == null ? Colors.white : (s.pauseSeit != null ? PT.gelbHell : PT.gruenHell),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(person, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  Text('heute ${_dauer((h * 60).round() + laufend)}', style: const TextStyle(color: PT.grau)),
                ]),
                if (s != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${s.fahrt ? 'Fahrt' : 'Arbeit'} · ${namen[s.projektId] ?? '?'} · seit ${s.start.hour}:${s.start.minute.toString().padLeft(2, '0')}'
                    '${s.pauseSeit != null ? ' · Pause' : ''}',
                  ),
                  Text(_dauer(laufend), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ],
                for (final x in hinweise) Text(x, style: const TextStyle(color: PT.rot, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if (s == null) ...[
                    FilledButton.icon(
                      onPressed: () => _starten(person, fahrt: false),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Arbeit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _starten(person, fahrt: true),
                      icon: const Icon(Icons.directions_car_outlined),
                      label: const Text('Fahrt'),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        pauseUmschalten(s, DateTime.now());
                        store.geaendert();
                      },
                      icon: Icon(s.pauseSeit == null ? Icons.coffee_outlined : Icons.play_arrow),
                      label: Text(s.pauseSeit == null ? 'Pause' : 'Weiter'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _beenden(s),
                      icon: const Icon(Icons.stop),
                      label: const Text('Feierabend / Wechsel'),
                    ),
                  ],
                ]),
              ]),
            );
          }),
        const Text(
          'Die Zeiten landen im Projekt (Reiter „Zeiten“) und zählen für Nachkalkulation, Tätigkeitsnachweis und Rechnung. '
          'Die Stundenliste oben rechts kannst du deiner Lohnabrechnung geben.',
          style: TextStyle(color: PT.grau, fontSize: 12),
        ),
      ]),
    );
  }
}
