import 'package:flutter/material.dart';

import '../../data/geschaeft.dart';
import '../../data/models.dart';
import '../../logic/export.dart';
import '../../logic/projekte.dart';
import '../../logic/rechnungen.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'geschaeft.dart';
import 'baustelle.dart';

double? _zahl(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim());
String _h(double h) => h.toStringAsFixed(h == h.roundToDouble() ? 0 : 2).replaceAll('.', ',');

/// Alle Projekte und Anfragen, nach Status.
class ProjekteScreen extends StatefulWidget {
  const ProjekteScreen({super.key});

  @override
  State<ProjekteScreen> createState() => _ProjekteScreenState();
}

class _ProjekteScreenState extends State<ProjekteScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final alle = [...store.projekte]..sort((a, b) => b.erstellt.compareTo(a.erstellt));
    final liste = _status == null ? alle.where((p) => p.status != 'Abgerechnet').toList() : alle.where((p) => p.status == _status).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projekte'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (w) async {
              final heute = DateTime.now();
              if (w == 'woche') {
                final von = DateTime(heute.year, heute.month, heute.day - (heute.weekday - 1));
                final bis = DateTime(von.year, von.month, von.day + 6);
                await textTeilen(taetigkeitsnachweis(store.projekte, {for (final k in store.kunden) k.id: k.name},
                    von: von, bis: bis));
              } else if (w == 'monat') {
                await textTeilen(taetigkeitsnachweis(store.projekte, {for (final k in store.kunden) k.id: k.name},
                    von: DateTime(heute.year, heute.month, 1), bis: DateTime(heute.year, heute.month + 1, 0)));
              } else if (w == 'bestellung') {
                final t = bestellliste(store.projekte);
                if (t.isEmpty) {
                  if (context.mounted) zeigeHinweis(context, 'Kein offenes Material.');
                } else {
                  await textTeilen(t);
                }
              } else if (w == 'vorlagen') {
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VorlagenScreen()));
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'woche', child: Text('Wochenbericht teilen')),
              PopupMenuItem(value: 'monat', child: Text('Tätigkeitsnachweis Monat')),
              PopupMenuItem(value: 'bestellung', child: Text('Bestellliste Material')),
              PopupMenuItem(value: 'vorlagen', child: Text('Ablauf-Vorlagen')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _neu(context),
        icon: const Icon(Icons.add),
        label: const Text('Projekt / Anfrage'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ChoiceChip(label: const Text('Laufend'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
              for (final s in projektStatus)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$s (${alle.where((p) => p.status == s).length})'),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          if (liste.isEmpty)
            const LeerHinweis(
                icon: Icons.work_outline,
                text: 'Leg Anfragen und Aufträge als Projekt an: Zeiten, Material, Aufgaben und Besprechungen an einem Ort – '
                    'und am Ende die Rechnung mit einem Tipp.')
          else
            for (final p in liste)
              PTKarte(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjektDetail(projektId: p.id))),
                child: Row(children: [
                  const IconKachel(Icons.work_outline),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          store.kundeMitId(p.kundeId)?.name ?? 'ohne Kunde',
                          if (p.zeiten.isNotEmpty) '${_h(stundenVon(p))} Std.',
                          if (p.aufgaben.any((a) => !a.erledigt)) '${p.aufgaben.where((a) => !a.erledigt).length} offen',
                        ].join(' · '),
                        style: const TextStyle(color: PT.grau, fontSize: 13),
                      ),
                    ]),
                  ),
                  Etikett(p.status, farbe: PT.orangeDunkel, hintergrund: PT.orangeHell),
                ]),
              ),
        ],
      ),
    );
  }

  Future<void> _neu(BuildContext context) async {
    final store = StoreScope.of(context);
    final name = TextEditingController();
    String? kunde;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: const Text('Neues Projekt'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, decoration: feld(labelText: 'Name', hintText: 'z. B. Bad Meier')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: kunde,
              decoration: feld(labelText: 'Kunde'),
              items: [for (final k in store.kunden) DropdownMenuItem(value: k.id, child: Text(k.name))],
              onChanged: (v) => setze(() => kunde = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Anlegen')),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    name.dispose();
    if (ok != true || n.isEmpty) return;
    final p = Projekt(id: neueId(), name: n, kundeId: kunde ?? '');
    await store.projektSpeichern(p);
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjektDetail(projektId: p.id)));
    }
  }
}

class ProjektDetail extends StatelessWidget {
  const ProjektDetail({super.key, required this.projektId});

  final String projektId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.projekte.where((x) => x.id == projektId).firstOrNull;
    if (p == null) return Scaffold(appBar: AppBar(), body: const LeerHinweis(icon: Icons.work_outline, text: 'Gelöscht.'));
    final nk = nachkalkulation(p, store.rechnungen, belege: store.belege, kleinunternehmer: store.firma.kleinunternehmer);
    final angebote = store.rechnungen.where((r) => r.istAngebot && (p.kundeId.isEmpty || r.kundeId == p.kundeId)).toList();
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.name),
          actions: [
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                Navigator.of(context).pop();
                store.projektLoeschen(p);
              },
            ),
          ],
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Übersicht'),
            Tab(text: 'Zeiten'),
            Tab(text: 'Material'),
            Tab(text: 'Aufgaben'),
            Tab(text: 'Baustelle'),
          ]),
        ),
        body: TabBarView(children: [
          // Übersicht
          ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in projektStatus)
                ChoiceChip(
                  label: Text(s),
                  selected: p.status == s,
                  onSelected: (_) {
                    p.status = s;
                    store.geaendert();
                  },
                ),
            ]),
            const SizedBox(height: 12),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                ListTile(
                  title: const Text('Stundensatz netto'),
                  trailing: Text(p.stundensatz == 0 ? 'festlegen' : euro(p.stundensatz)),
                  onTap: () async {
                    final w = await _zahlAbfragen(context, 'Stundensatz netto', p.stundensatz);
                    if (w == null) return;
                    p.stundensatz = w;
                    await store.geaendert();
                  },
                ),
                ListTile(
                  title: const Text('Angebot'),
                  trailing: SizedBox(
                    width: 170,
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: angebote.any((r) => r.id == p.angebotId) ? p.angebotId : null,
                      hint: const Text('keins'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('keins')),
                        for (final r in angebote) DropdownMenuItem(value: r.id, child: Text(r.nummer)),
                      ],
                      onChanged: (v) {
                        p.angebotId = v;
                        store.geaendert();
                      },
                    ),
                  ),
                ),
              ]),
            ),
            const Abschnitt('Nachkalkulation'),
            PTKarte(
              farbe: (nk.abweichung ?? 0) > 0 ? PT.rotHell : PT.orangeHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('Zeit (${_h(stundenVon(p))} Std.)')), Text(euro(nk.zeit))]),
                Row(children: [const Expanded(child: Text('Material')), Text(euro(nk.material))]),
                if (nk.eingang > 0)
                  Row(children: [const Expanded(child: Text('Eingangsrechnungen (netto)')), Text(euro(nk.eingang))]),
                const Divider(),
                Row(children: [
                  const Expanded(child: Text('Kosten bisher', style: TextStyle(fontWeight: FontWeight.w800))),
                  Text(euro(nk.kosten), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                if (nk.angebot != null) ...[
                  Row(children: [const Expanded(child: Text('Angebot netto')), Text(euro(nk.angebot!))]),
                  Text(
                    nk.abweichung! > 0
                        ? 'Schon ${euro(nk.abweichung!)} (${_h(nk.abweichungProzent!)} %) über dem Angebot.'
                        : 'Noch ${euro(-nk.abweichung!)} unter dem Angebot.',
                    style: TextStyle(fontWeight: FontWeight.w700, color: nk.abweichung! > 0 ? PT.rot : PT.gruen),
                  ),
                ] else
                  const Text('Verknüpfe ein Angebot, um geplante und tatsächliche Kosten zu vergleichen.',
                      style: TextStyle(fontSize: 12, color: PT.grau)),
              ]),
            ),
            FilledButton.icon(
              onPressed: p.zeiten.isEmpty && p.material.isEmpty
                  ? null
                  : () async {
                      final r = rechnungAusProjekt(p, store.rechnungen,
                          id: neueId(),
                          datum: DateTime.now(),
                          zahlungszielTage: store.firma.zahlungszielTage,
                          ustSatz: store.firma.kleinunternehmer ? 0 : 19);
                      await store.rechnungSpeichern(r);
                      if (context.mounted) {
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => RechnungFormular(art: 'rechnung', rechnung: r)));
                      }
                    },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Rechnung aus Zeiten und Material'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                final alle = p.zeiten.map((z) => z.datum).toList()..sort();
                if (alle.isEmpty) return;
                textTeilen(taetigkeitsnachweis([p], {for (final k in store.kunden) k.id: k.name},
                    von: alle.first, bis: alle.last));
              },
              icon: const Icon(Icons.summarize_outlined),
              label: const Text('Tätigkeitsnachweis teilen'),
            ),
            const Abschnitt('Besprechungen'),
            for (final b in [...p.protokolle]..sort((a, b) => b.datum.compareTo(a.datum)))
              PTKarte(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${datumKurz(b.datum)}${b.teilnehmer.isEmpty ? '' : ' · ${b.teilnehmer}'}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(b.text),
                ]),
              ),
            OutlinedButton.icon(
              onPressed: () => _protokoll(context, p),
              icon: const Icon(Icons.edit_note),
              label: const Text('Besprechung protokollieren'),
            ),
          ]),
          // Zeiten
          ListView(padding: const EdgeInsets.all(16), children: [
            FilledButton.icon(
              onPressed: () => _zeit(context, p),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Zeit eintragen'),
            ),
            const SizedBox(height: 8),
            Text('Gesamt: ${_h(stundenVon(p))} Stunden', style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final z in [...p.zeiten]..sort((a, b) => b.datum.compareTo(a.datum)))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${datumKurz(z.datum)} · ${_h(z.stunden)} Std.${z.person.isEmpty ? '' : ' · ${z.person}'}'),
                subtitle: z.text.isEmpty ? null : Text(z.text),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () {
                    p.zeiten.remove(z);
                    store.geaendert();
                  },
                ),
              ),
          ]),
          // Material
          ListView(padding: const EdgeInsets.all(16), children: [
            FilledButton.icon(
              onPressed: () => _material(context, p),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Material hinzufügen'),
            ),
            for (final m in p.material)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: m.bestellt,
                title: Text('${_h(m.menge)} ${m.einheit} ${m.text}'),
                subtitle: Text('${euro(m.summe)}${m.bestellt ? ' · bestellt' : ' · noch bestellen'}'),
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () {
                    p.material.remove(m);
                    store.geaendert();
                  },
                ),
                onChanged: (v) {
                  m.bestellt = v ?? false;
                  store.geaendert();
                },
              ),
          ]),
          // Aufgaben
          ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: () => _aufgabe(context, p),
                icon: const Icon(Icons.add_task),
                label: const Text('Aufgabe'),
              ),
              OutlinedButton.icon(
                onPressed: () => _vorlageAnwenden(context, p),
                icon: const Icon(Icons.playlist_add),
                label: const Text('Aus Vorlage'),
              ),
            ]),
            for (final a in p.aufgaben)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: a.erledigt,
                title: Text(a.text, style: TextStyle(decoration: a.erledigt ? TextDecoration.lineThrough : null)),
                subtitle: a.person.isEmpty ? null : Text('→ ${a.person}'),
                onChanged: (v) {
                  a.erledigt = v ?? false;
                  store.geaendert();
                },
              ),
          ]),
          BaustelleTab(projekt: p),
        ]),
      ),
    );
  }

  Future<double?> _zahlAbfragen(BuildContext context, String titel, double start) async {
    final c = TextEditingController(text: start == 0 ? '' : start.toStringAsFixed(2).replaceAll('.', ','));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(titel),
        content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(suffixText: '€')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('OK')),
        ],
      ),
    );
    final w = _zahl(c.text);
    c.dispose();
    return ok == true ? w : null;
  }

  Future<void> _zeit(BuildContext context, Projekt p) async {
    final store = StoreScope.of(context);
    final stunden = TextEditingController();
    final person = TextEditingController(text: store.notizen['projekt:person'] ?? '');
    final text = TextEditingController();
    var datum = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: const Text('Zeit eintragen'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(datumKurz(datum)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final x = await datumWaehlen(d, start: datum);
                  if (x != null) setze(() => datum = x);
                },
              ),
              TextField(
                  controller: stunden,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: feld(labelText: 'Stunden', hintText: 'z. B. 2,5')),
              const SizedBox(height: 8),
              TextField(controller: person, decoration: feld(labelText: 'Wer? (optional)')),
              const SizedBox(height: 8),
              TextField(controller: text, decoration: feld(labelText: 'Was wurde gemacht?')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final h = _zahl(stunden.text);
    final wer = person.text.trim(), was = text.text.trim();
    stunden.dispose();
    person.dispose();
    text.dispose();
    if (ok != true || h == null || h <= 0) return;
    p.zeiten.add(Zeiteintrag(datum: datum, stunden: h, person: wer, text: was));
    if (wer.isNotEmpty) store.notizen['projekt:person'] = wer;
    if (p.status == 'Auftrag' || p.status == 'Anfrage' || p.status == 'Angebot') p.status = 'In Arbeit';
    await store.geaendert();
  }

  Future<void> _material(BuildContext context, Projekt p) async {
    final store = StoreScope.of(context);
    final text = TextEditingController();
    final menge = TextEditingController(text: '1');
    final einheit = TextEditingController(text: 'Stück');
    final preis = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Material'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: text, autofocus: true, decoration: feld(labelText: 'Was?')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: menge,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: feld(labelText: 'Menge'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: einheit, decoration: feld(labelText: 'Einheit'))),
            ]),
            const SizedBox(height: 8),
            TextField(
                controller: preis,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: feld(labelText: 'Preis pro Einheit netto', suffixText: '€')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Speichern')),
        ],
      ),
    );
    final m = Materialposten(
        text: text.text.trim(),
        menge: _zahl(menge.text) ?? 1,
        einheit: einheit.text.trim().isEmpty ? 'Stück' : einheit.text.trim(),
        preis: _zahl(preis.text) ?? 0);
    for (final c in [text, menge, einheit, preis]) {
      c.dispose();
    }
    if (ok != true || m.text.isEmpty) return;
    p.material.add(m);
    await store.geaendert();
  }

  Future<void> _aufgabe(BuildContext context, Projekt p) async {
    final store = StoreScope.of(context);
    final text = TextEditingController();
    final person = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Aufgabe'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: text, autofocus: true, decoration: feld(labelText: 'Was ist zu tun?')),
          const SizedBox(height: 8),
          TextField(controller: person, decoration: feld(labelText: 'Wer? (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Speichern')),
        ],
      ),
    );
    final t = text.text.trim(), wer = person.text.trim();
    text.dispose();
    person.dispose();
    if (ok != true || t.isEmpty) return;
    p.aufgaben.add(ProjektAufgabe(text: t, person: wer));
    await store.geaendert();
  }

  Future<void> _protokoll(BuildContext context, Projekt p) async {
    final store = StoreScope.of(context);
    final text = TextEditingController();
    final teilnehmer = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Besprechung'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: teilnehmer, decoration: feld(labelText: 'Wer war dabei?')),
            const SizedBox(height: 8),
            TextField(
              controller: text,
              minLines: 5,
              maxLines: 10,
              decoration: feld(
                  labelText: 'Notizen',
                  hintText: 'Aufgaben mit „- “ beginnen, z. B.\n- @Anna Fliesen bestellen\n- Kunde: Farbe aussuchen'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Speichern')),
        ],
      ),
    );
    final t = text.text.trim(), wer = teilnehmer.text.trim();
    text.dispose();
    teilnehmer.dispose();
    if (ok != true || t.isEmpty) return;
    p.protokolle.add(Protokoll(datum: DateTime.now(), text: t, teilnehmer: wer));
    final neu = aufgabenAusProtokoll(t);
    p.aufgaben.addAll(neu);
    await store.geaendert();
    if (context.mounted && neu.isNotEmpty) {
      zeigeHinweis(context, '${neu.length} ${neu.length == 1 ? 'Aufgabe' : 'Aufgaben'} aus der Besprechung übernommen.');
    }
  }

  Future<void> _vorlageAnwenden(BuildContext context, Projekt p) async {
    final store = StoreScope.of(context);
    final vorlagen = {...standardVorlagen, ...ablaufVorlagen(store.notizen)};
    final wahl = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: const Text('Vorlage wählen'),
        children: [
          for (final n in vorlagen.keys) SimpleDialogOption(onPressed: () => Navigator.pop(d, n), child: Text(n)),
        ],
      ),
    );
    if (wahl == null) return;
    p.aufgaben.addAll([for (final t in vorlagen[wahl]!) ProjektAufgabe(text: t)]);
    await store.geaendert();
  }
}

/// Eigene Vorlagen für wiederkehrende Abläufe.
class VorlagenScreen extends StatelessWidget {
  const VorlagenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final eigene = ablaufVorlagen(store.notizen);
    return Scaffold(
      appBar: AppBar(title: const Text('Ablauf-Vorlagen')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _bearbeiten(context, null, const []),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const Text('Checklisten für Abläufe, die immer gleich sind. In jedem Projekt mit einem Tipp einfügen.',
              style: TextStyle(color: PT.grau)),
          const Abschnitt('Mitgeliefert'),
          for (final e in standardVorlagen.entries)
            PTKarte(child: Text('${e.key} · ${e.value.length} Schritte', style: const TextStyle(fontWeight: FontWeight.w700))),
          const Abschnitt('Deine Vorlagen'),
          if (eigene.isEmpty) const Text('Noch keine eigenen Vorlagen.', style: TextStyle(color: PT.grau)),
          for (final e in eigene.entries)
            PTKarte(
              onTap: () => _bearbeiten(context, e.key, e.value),
              child: Text('${e.key} · ${e.value.length} Schritte', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Future<void> _bearbeiten(BuildContext context, String? name, List<String> schritte) async {
    final store = StoreScope.of(context);
    final n = TextEditingController(text: name ?? '');
    final t = TextEditingController(text: schritte.join('\n'));
    final ok = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(name == null ? 'Neue Vorlage' : 'Vorlage'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: n, decoration: feld(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: t, minLines: 5, maxLines: 12, decoration: feld(labelText: 'Ein Schritt pro Zeile')),
          ]),
        ),
        actions: [
          if (name != null) TextButton(onPressed: () => Navigator.pop(d, 'loeschen'), child: const Text('Löschen')),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('Speichern')),
        ],
      ),
    );
    final neuerName = n.text.trim(), inhalt = t.text.trim();
    n.dispose();
    t.dispose();
    if (ok == null) return;
    if (name != null) store.notizen.remove('vorlage:$name');
    if (ok == 'ok' && neuerName.isNotEmpty && inhalt.isNotEmpty) store.notizen['vorlage:$neuerName'] = inhalt;
    await store.geaendert();
  }
}
