import 'package:flutter/material.dart';

import '../../data/geschaeft.dart';
import '../../data/models.dart';
import '../../logic/export.dart';
import '../../logic/plantafel.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr'];

Color _farbe(Einsatz e) => switch (e.art) {
      'Urlaub' => PT.gruenHell,
      'Krank' => PT.rotHell,
      'Schlechtwetter' => PT.sand,
      'Schule' => PT.gelbHell,
      _ => PT.orangeHell,
    };

/// Plantafel: Mitarbeiter × Wochentage. Tippen auf ein Feld plant einen Einsatz oder eine Abwesenheit.
class PlantafelScreen extends StatefulWidget {
  const PlantafelScreen({super.key});

  @override
  State<PlantafelScreen> createState() => _PlantafelScreenState();
}

class _PlantafelScreenState extends State<PlantafelScreen> {
  DateTime _woche = wochenAnfang(DateTime.now());

  Future<void> _mitarbeiterHinzufuegen() async {
    final store = StoreScope.of(context);
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Mitarbeiter oder Kolonne'),
        content: TextField(controller: c, autofocus: true, decoration: feld(hintText: 'z. B. Anna oder Kolonne 1')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Hinzufügen')),
        ],
      ),
    );
    final n = c.text.trim();
    c.dispose();
    if (ok != true || n.isEmpty || store.mitarbeiter.contains(n)) return;
    store.mitarbeiter.add(n);
    await store.geaendert();
  }

  Future<void> _planen(String person, DateTime tag, Einsatz? vorhanden) async {
    final store = StoreScope.of(context);
    var art = vorhanden?.art ?? 'Projekt';
    String? projekt = vorhanden?.projektId ?? store.projekte.where((p) => p.status != 'Abgerechnet' && p.status != 'Fertig').firstOrNull?.id;
    var bis = vorhanden?.bis ?? tag;
    final personen = <String>{...?vorhanden?.personen, person};
    final notiz = TextEditingController(text: vorhanden?.notiz ?? '');
    final ergebnis = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text('${_tage[tag.weekday - 1]} ${datumKurz(tag)}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in einsatzArten)
                  ChoiceChip(label: Text(a), selected: art == a, onSelected: (_) => setze(() => art = a)),
              ]),
              if (art == 'Projekt') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: store.projekte.any((p) => p.id == projekt) ? projekt : null,
                  decoration: feld(labelText: 'Projekt'),
                  items: [for (final p in store.projekte) DropdownMenuItem(value: p.id, child: Text(p.name))],
                  onChanged: (v) => setze(() => projekt = v),
                ),
              ],
              const SizedBox(height: 8),
              const Text('Wer?', style: TextStyle(fontWeight: FontWeight.w700)),
              Wrap(spacing: 6, children: [
                for (final m in store.mitarbeiter)
                  FilterChip(
                    label: Text(m),
                    selected: personen.contains(m),
                    onSelected: (v) => setze(() => v ? personen.add(m) : personen.remove(m)),
                  ),
              ]),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('bis ${datumKurz(bis)}'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final x = await datumWaehlen(d, start: bis);
                  if (x != null && !x.isBefore(tag)) setze(() => bis = x);
                },
              ),
              TextField(controller: notiz, decoration: feld(labelText: 'Notiz (optional)')),
            ]),
          ),
          actions: [
            if (vorhanden != null) TextButton(onPressed: () => Navigator.pop(d, 'weg'), child: const Text('Entfernen')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final n = notiz.text.trim();
    notiz.dispose();
    if (ergebnis == 'weg' && vorhanden != null) {
      if (vorhanden.personen.length > 1) {
        vorhanden.personen.remove(person);
      } else {
        store.einsaetze.remove(vorhanden);
      }
    } else if (ergebnis == 'ok' && personen.isNotEmpty && (art != 'Projekt' || projekt != null)) {
      final e = vorhanden ?? Einsatz(id: neueId(), von: tag, bis: bis);
      e
        ..bis = bis
        ..art = art
        ..projektId = art == 'Projekt' ? projekt : null
        ..personen = personen.toList()
        ..notiz = n;
      if (vorhanden == null) store.einsaetze.add(e);
    } else {
      return;
    }
    await store.geaendert();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final namen = {for (final p in store.projekte) p.id: p.name};
    final fr = _woche.add(const Duration(days: 4));
    final kon = konflikte(store.einsaetze, von: _woche, bis: fr);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantafel'),
        actions: [
          IconButton(
            tooltip: 'Wochenplan teilen',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => textTeilen(wochenplanText(store.mitarbeiter, store.einsaetze, namen, _woche)),
          ),
          IconButton(tooltip: 'Mitarbeiter hinzufügen', icon: const Icon(Icons.person_add_alt), onPressed: _mitarbeiterHinzufuegen),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
        Row(children: [
          IconButton(
              onPressed: () => setState(() => _woche = _woche.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text('KW ${_kw(_woche)} · ${datumKurz(_woche)} – ${datumKurz(fr)}',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
              onPressed: () => setState(() => _woche = _woche.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right)),
        ]),
        if (kon.isNotEmpty)
          PTKarte(
            farbe: PT.rotHell,
            child: Text(
              'Doppelt verplant: ${kon.map((k) => '${k.$1} am ${_tage[k.$2.weekday - 1]}').toSet().join(', ')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (store.mitarbeiter.isEmpty)
          LeerHinweis(
            icon: Icons.groups_outlined,
            text: 'Leg deine Mitarbeiter oder Kolonnen an (oben rechts) – dann planst du hier, wer wann wo ist.',
          )
        else
          Table(
            columnWidths: const {0: FlexColumnWidth(1.3)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
                const SizedBox(),
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('${_tage[i]}\n${_woche.add(Duration(days: i)).day}.',
                        textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ]),
              for (final m in store.mitarbeiter)
                TableRow(children: [
                  GestureDetector(
                    onLongPress: () async {
                      store.mitarbeiter.remove(m);
                      await store.geaendert();
                    },
                    child: Text(m, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                  for (var i = 0; i < 5; i++)
                    Builder(builder: (_) {
                      final tag = _woche.add(Duration(days: i));
                      final e = einsatzVon(store.einsaetze, m, tag);
                      return Padding(
                        padding: const EdgeInsets.all(2),
                        child: InkWell(
                          onTap: () => _planen(m, tag, e),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: e == null ? Colors.white : _farbe(e),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: PT.sand),
                            ),
                            child: Text(
                              e == null ? '' : (e.art == 'Projekt' ? (namen[e.projektId] ?? '?') : e.art),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10.5),
                            ),
                          ),
                        ),
                      );
                    }),
                ]),
            ],
          ),
        const SizedBox(height: 8),
        if (store.mitarbeiter.isNotEmpty)
          const Text('Feld antippen zum Planen · Namen lange drücken zum Entfernen.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
      ]),
    );
  }
}

/// Kalenderwoche nach ISO 8601.
int _kw(DateTime d) {
  final donnerstag = d.add(Duration(days: 4 - d.weekday));
  final jan1 = DateTime(donnerstag.year, 1, 1);
  return 1 + donnerstag.difference(jan1).inDays ~/ 7;
}
