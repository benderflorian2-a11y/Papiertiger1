import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/haushalt.dart';
import '../../data/models.dart';
import '../../logic/export.dart';
import '../../logic/alltag.dart';
import '../../logic/haushalt.dart';
import '../../logic/texterkennung.dart';
import '../app.dart';
import '../termine.dart';
import '../theme.dart';
import '../finanzen.dart';
import '../widgets/common.dart';
import 'alltag.dart';

double? _zahl(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim());
String _feld(double? v) => v == null ? '' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',');
String _menge(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ',');

IconData zaehlerIcon(String art) => switch (art) {
      'Strom' => Icons.bolt_outlined,
      'Gas' => Icons.local_fire_department_outlined,
      'Wasser' || 'Warmwasser' => Icons.water_drop_outlined,
      _ => Icons.thermostat_outlined,
    };

class HaushaltScreen extends StatelessWidget {
  const HaushaltScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final notfall = [for (var i = 0; i < notfallDokumente.length; i++) if (store.checklisten['notfall:$i'] == true) i].length;
    final heute = DateTime.now();
    final offenEinkauf = store.alltag.einkauf.where((e) => !e.erledigt).length;
    final bald = laeuftBaldAb(store.alltag.vorraete, heute: heute).length;
    final faellig = store.alltag.hausaufgaben.where((a) => hausaufgabeFaellig(a, heute: heute)).length;
    void oeffne(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    Widget kachel(IconData icon, String titel, String text, Widget ziel) => PTKarte(
          onTap: () => oeffne(ziel),
          child: Row(children: [
            IconKachel(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(text, style: const TextStyle(color: PT.grau, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: PT.grau),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Haushalt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Abschnitt('Alltag'),
          kachel(Icons.shopping_cart_outlined, 'Einkaufsliste',
              offenEinkauf == 0 ? 'Nach Abteilungen sortiert, auch aus Rezepten' : '$offenEinkauf Artikel offen',
              const EinkaufScreen()),
          kachel(Icons.kitchen_outlined, 'Vorräte',
              bald == 0 ? 'Haltbarkeit im Blick, Rezepte aus Resten' : '$bald laufen bald ab', const VorraeteScreen()),
          kachel(Icons.restaurant_menu, 'Essensplan', 'Woche planen, Zutaten auf die Einkaufsliste', const EssensplanScreen()),
          kachel(Icons.cleaning_services_outlined, 'Aufgaben im Haushalt',
              faellig == 0 ? 'Wer ist dran? Putzplan, Müll, Wäsche' : '$faellig fällig', const HausaufgabenScreen()),
          kachel(Icons.card_giftcard, 'Geschenke & Anschaffungen', 'Ideen, Geburtstage, geplante Käufe', const GeschenkeScreen()),
          kachel(Icons.luggage_outlined, 'Reisen', 'Packliste, Unterlagen, Reiseplan', const ReisenScreen()),
          kachel(Icons.savings_outlined, 'Haushaltsbudget', 'Ausgaben nach Kategorie, Budgets, Sparziele', const FinanzenScreen()),
          kachel(Icons.key_outlined, 'Wohnungsübergabe', 'Checkliste für Auszug und Einzug', const WohnungsuebergabeScreen()),
          const Abschnitt('Wohnung'),
          kachel(Icons.speed_outlined, 'Zählerstände',
              store.zaehler.isEmpty ? 'Strom, Gas, Wasser – Nachzahlung früh erkennen' : '${store.zaehler.length} Zähler',
              const ZaehlerScreen()),
          kachel(Icons.chair_outlined, 'Inventar',
              store.inventar.isEmpty
                  ? 'Was du besitzt – wichtig für die Hausratversicherung'
                  : '${anzahl(store.inventar.length, 'Gegenstand', 'Gegenstände')} · ${euro(inventarWert(store.inventar))}',
              const InventarScreen()),
          kachel(Icons.folder_special_outlined, 'Notfallmappe',
              '$notfall von ${notfallDokumente.length} Dokumenten erfasst', const NotfallScreen()),
          kachel(Icons.build_circle_outlined, 'Wiederkehrende Aufgaben', 'Rauchmelder, Heizung, Filter …',
              const HaushaltsTermine()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Zähler

class ZaehlerScreen extends StatelessWidget {
  const ZaehlerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Zählerstände')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ZaehlerFormular())),
        icon: const Icon(Icons.add),
        label: const Text('Zähler'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (store.zaehler.isEmpty)
            const LeerHinweis(
                icon: Icons.speed_outlined,
                text: 'Leg deine Zähler an und trag regelmäßig den Stand ein. Der Tiger rechnet hoch, '
                    'ob dein Abschlag reicht.'),
          for (final z in store.zaehler)
            Builder(builder: (context) {
              final v = verbrauchVon(z);
              final c = abschlagPruefen(z);
              return PTKarte(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ZaehlerDetail(zaehlerId: z.id))),
                child: Row(children: [
                  IconKachel(zaehlerIcon(z.art)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${z.art}${z.nummer.isEmpty ? '' : ' · ${z.nummer}'}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        v == null ? 'Noch zu wenige Ablesungen' : 'ca. ${_menge(v.proJahr)} ${z.einheit} im Jahr',
                        style: const TextStyle(color: PT.grau, fontSize: 13),
                      ),
                    ]),
                  ),
                  if (c != null)
                    Etikett(
                      c.differenz > 0 ? '+${euro(c.differenz)}' : euro(-c.differenz),
                      farbe: c.differenz > 0 ? PT.rot : PT.gruen,
                      hintergrund: c.differenz > 0 ? PT.rotHell : PT.gruenHell,
                    ),
                ]),
              );
            }),
        ],
      ),
    );
  }
}

class ZaehlerDetail extends StatelessWidget {
  const ZaehlerDetail({super.key, required this.zaehlerId});

  final String zaehlerId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final z = store.zaehler.where((x) => x.id == zaehlerId).firstOrNull;
    if (z == null) return Scaffold(appBar: AppBar(), body: const LeerHinweis(icon: Icons.speed_outlined, text: 'Gelöscht.'));
    final v = verbrauchVon(z);
    final c = abschlagPruefen(z);
    final l = [...z.ablesungen]..sort((a, b) => b.datum.compareTo(a.datum));
    return Scaffold(
      appBar: AppBar(
        title: Text(z.art),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ZaehlerFormular(zaehler: z))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.of(context).pop();
              store.zaehlerLoeschen(z);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ablesen(context, z),
        icon: const Icon(Icons.add),
        label: const Text('Stand eintragen'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (v != null)
            PTKarte(
              farbe: PT.orangeHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_menge(v.menge)} ${z.einheit} in ${v.tage} Tagen', style: const TextStyle(color: PT.grau)),
                Text('ca. ${_menge(v.proJahr)} ${z.einheit} im Jahr',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                if (c != null) ...[
                  const SizedBox(height: 6),
                  Text('Hochgerechnete Kosten: ${euro(c.kostenJahr)} im Jahr, Abschläge: ${euro(c.abschlaegeJahr)}.'),
                  Text(
                    c.differenz > 0
                        ? 'Voraussichtlich Nachzahlung von etwa ${euro(c.differenz)}. Ein höherer Abschlag kann helfen.'
                        : 'Voraussichtlich Guthaben von etwa ${euro(-c.differenz)}.',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.differenz > 0 ? PT.rot : PT.gruen),
                  ),
                ] else if (z.preis == null || z.abschlagMonat == null)
                  const Text('Trag Preis und Abschlag ein (Stift oben), dann prüft der Tiger, ob der Abschlag reicht.',
                      style: TextStyle(fontSize: 13)),
              ]),
            ),
          const Abschnitt('Ablesungen'),
          if (l.isEmpty)
            const PTKarte(child: Text('Noch keine Ablesung.'))
          else
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final a in l)
                  ListTile(
                    dense: true,
                    title: Text('${_menge(a.stand)} ${z.einheit}'),
                    subtitle: Text(datumKurz(a.datum)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        z.ablesungen.remove(a);
                        store.geaendert();
                      },
                    ),
                  ),
              ]),
            ),
          const Text('Hochrechnung aus deinen Ablesungen. Im Winter wird mehr geheizt – je länger der Zeitraum, desto genauer.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _ablesen(BuildContext context, Zaehler z) async {
    final store = StoreScope.of(context);
    final c = TextEditingController();
    var datum = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text('${z.art}-Zähler ablesen'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: feld(labelText: 'Zählerstand', suffixText: z.einheit),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(datumKurz(datum)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final x = await datumWaehlen(d, start: datum);
                if (x != null) setze(() => datum = x);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final stand = _zahl(c.text);
    c.dispose();
    if (ok != true || stand == null) return;
    final fehler = ablesungPruefen(z, stand, datum);
    if (fehler != null && context.mounted) {
      zeigeHinweis(context, fehler);
      return;
    }
    z.ablesungen.add(Ablesung(datum, stand));
    await store.geaendert();
  }
}

class ZaehlerFormular extends StatefulWidget {
  const ZaehlerFormular({super.key, this.zaehler});

  final Zaehler? zaehler;

  @override
  State<ZaehlerFormular> createState() => _ZaehlerFormularState();
}

class _ZaehlerFormularState extends State<ZaehlerFormular> {
  late String _art = widget.zaehler?.art ?? zaehlerArten.first;
  late final _nummer = TextEditingController(text: widget.zaehler?.nummer ?? '');
  late final _preis = TextEditingController(text: _feld(widget.zaehler?.preis));
  late final _grund = TextEditingController(text: _feld(widget.zaehler?.grundpreisMonat));
  late final _abschlag = TextEditingController(text: _feld(widget.zaehler?.abschlagMonat));

  @override
  void dispose() {
    for (final c in [_nummer, _preis, _grund, _abschlag]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final einheit = Zaehler(id: '', art: _art).einheit;
    return Scaffold(
      appBar: AppBar(title: Text(widget.zaehler == null ? 'Neuer Zähler' : 'Zähler bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in zaehlerArten)
              ChoiceChip(label: Text(a), selected: _art == a, onSelected: (_) => setState(() => _art = a)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _nummer, decoration: feld(labelText: 'Zählernummer (optional)')),
          const SizedBox(height: 12),
          TextField(
            controller: _preis,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Arbeitspreis pro $einheit (brutto)', suffixText: '€', hintText: 'steht auf der Abrechnung'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _grund,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Grundpreis pro Monat (optional)', suffixText: '€'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _abschlag,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Monatlicher Abschlag', suffixText: '€'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              final z = widget.zaehler ?? Zaehler(id: neueId(), art: _art);
              z
                ..art = _art
                ..nummer = _nummer.text.trim()
                ..preis = _zahl(_preis.text)
                ..grundpreisMonat = _zahl(_grund.text)
                ..abschlagMonat = _zahl(_abschlag.text);
              await store.zaehlerSpeichern(z);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Speichern'),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Inventar

class InventarScreen extends StatelessWidget {
  const InventarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = [...store.inventar]..sort((a, b) => '${a.raum}${a.name}'.compareTo('${b.raum}${b.name}'));
    final nachRaum = wertNachRaum(l);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventar'),
        actions: [
          if (l.isNotEmpty)
            IconButton(
              tooltip: 'Als PDF teilen',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () async {
                final f = await inventarAlsPdf(l);
                await dateiTeilen(f.path, mimeType: 'application/pdf');
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GegenstandFormular())),
        icon: const Icon(Icons.add),
        label: const Text('Gegenstand'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (l.isEmpty)
            const LeerHinweis(
                icon: Icons.chair_outlined,
                text: 'Fotografiere wertvolle Dinge mit Preis. Nach einem Einbruch oder Wasserschaden hast du alles '
                    'für die Hausratversicherung beisammen.')
          else ...[
            PTKarte(
              farbe: PT.orangeHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Gesamtwert ${euro(inventarWert(l))}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                for (final e in nachRaum.entries)
                  Row(children: [Expanded(child: Text(e.key)), Text(euro(e.value))]),
                const SizedBox(height: 6),
                const Text('Vergleiche den Wert mit der Versicherungssumme deiner Hausratversicherung.',
                    style: TextStyle(fontSize: 12, color: PT.grau)),
              ]),
            ),
            for (final g in l)
              PTKarte(
                padding: const EdgeInsets.all(12),
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GegenstandFormular(gegenstand: g))),
                child: Row(children: [
                  if (g.bild != null && File(g.bild!).existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(g.bild!), width: 44, height: 44, fit: BoxFit.cover),
                    )
                  else
                    const IconKachel(Icons.chair_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text([if (g.raum.isNotEmpty) g.raum, if (g.kaufdatum != null) datumKurz(g.kaufdatum!)].join(' · '),
                          style: const TextStyle(color: PT.grau, fontSize: 13)),
                    ]),
                  ),
                  if (g.preis != null) Text(euro(g.preis!), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
          if (store.belege.any((b) => (b.betrag ?? 0) >= 100 && !store.inventar.any((g) => g.belegId == b.id)))
            TextButton.icon(
              onPressed: () => _ausBelegen(context),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Aus Kassenbons übernehmen'),
            ),
        ],
      ),
    );
  }

  Future<void> _ausBelegen(BuildContext context) async {
    final store = StoreScope.of(context);
    final kandidaten = store.belege
        .where((b) => (b.betrag ?? 0) >= 100 && !store.inventar.any((g) => g.belegId == b.id))
        .toList();
    final gewaehlt = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: const Text('Belege ab 100 €'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(shrinkWrap: true, children: [
              for (final b in kandidaten)
                CheckboxListTile(
                  value: gewaehlt.contains(b.id),
                  title: Text(b.haendler.isEmpty ? 'Beleg' : b.haendler),
                  subtitle: Text('${datumKurz(b.datum)} · ${euro(b.betrag ?? 0)}'),
                  onChanged: (v) => setze(() => v == true ? gewaehlt.add(b.id) : gewaehlt.remove(b.id)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Übernehmen')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    for (final b in kandidaten.where((b) => gewaehlt.contains(b.id))) {
      store.inventar.add(gegenstandAusBeleg(b, neueId()));
    }
    await store.geaendert();
  }
}

class GegenstandFormular extends StatefulWidget {
  const GegenstandFormular({super.key, this.gegenstand});

  final Gegenstand? gegenstand;

  @override
  State<GegenstandFormular> createState() => _GegenstandFormularState();
}

class _GegenstandFormularState extends State<GegenstandFormular> {
  late final _name = TextEditingController(text: widget.gegenstand?.name ?? '');
  late final _preis = TextEditingController(text: _feld(widget.gegenstand?.preis));
  late final _serie = TextEditingController(text: widget.gegenstand?.seriennummer ?? '');
  late String _raum = widget.gegenstand?.raum ?? '';
  late DateTime? _kauf = widget.gegenstand?.kaufdatum;
  late String? _bild = widget.gegenstand?.bild;

  @override
  void dispose() {
    for (final c in [_name, _preis, _serie]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gegenstand == null ? 'Neuer Gegenstand' : 'Gegenstand'),
        actions: [
          if (widget.gegenstand != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                store.gegenstandLoeschen(widget.gegenstand!);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () async {
              final pfad = await Texterkennung.bildHolen(kamera: true);
              if (pfad != null) setState(() => _bild = pfad);
            },
            child: Container(
              height: 160,
              decoration: BoxDecoration(color: PT.sand, borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: _bild != null && File(_bild!).existsSync()
                  ? Image.file(File(_bild!), fit: BoxFit.cover)
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.photo_camera_outlined, size: 36, color: PT.grau),
                      Text('Foto aufnehmen', style: TextStyle(color: PT.grau)),
                    ]),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: feld(labelText: 'Was ist es?', hintText: 'z. B. Fernseher, Fahrrad')),
          const SizedBox(height: 12),
          TextField(
            controller: _preis,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Kaufpreis', suffixText: '€'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _serie, decoration: feld(labelText: 'Seriennummer (optional)')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kaufdatum'),
            subtitle: Text(_kauf == null ? 'unbekannt' : datumLang(_kauf!)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await datumWaehlen(context, start: _kauf);
              if (d != null) setState(() => _kauf = d);
            },
          ),
          const Text('Raum', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in raeume)
              ChoiceChip(label: Text(r), selected: _raum == r, onSelected: (_) => setState(() => _raum = r)),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty) {
                zeigeHinweis(context, 'Bitte einen Namen eintragen.');
                return;
              }
              final g = widget.gegenstand ?? Gegenstand(id: neueId(), name: '');
              g
                ..name = _name.text.trim()
                ..preis = _zahl(_preis.text)
                ..seriennummer = _serie.text.trim()
                ..raum = _raum
                ..kaufdatum = _kauf
                ..bild = _bild;
              await store.gegenstandSpeichern(g);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Speichern'),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Notfallmappe

class NotfallScreen extends StatefulWidget {
  const NotfallScreen({super.key});

  @override
  State<NotfallScreen> createState() => _NotfallScreenState();
}

class _NotfallScreenState extends State<NotfallScreen> {
  final _orte = <int, TextEditingController>{};
  final _kontakte = TextEditingController();
  bool _bereit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bereit) return;
    _bereit = true;
    final n = StoreScope.of(context).notizen;
    for (var i = 0; i < notfallDokumente.length; i++) {
      _orte[i] = TextEditingController(text: n['notfall:$i'] ?? '');
    }
    _kontakte.text = n['notfall:kontakte'] ?? '';
  }

  @override
  void dispose() {
    for (final c in _orte.values) {
      c.dispose();
    }
    _kontakte.dispose();
    super.dispose();
  }

  void _setze(String k, String v) {
    final store = StoreScope.of(context);
    if (v.trim().isEmpty) {
      store.notizen.remove(k);
    } else {
      store.notizen[k] = v.trim();
    }
    store.geaendert();
  }

  String _alsText() {
    final store = StoreScope.of(context);
    final z = StringBuffer('Notfallmappe von ${store.profil.name}\n\n');
    if (_kontakte.text.trim().isNotEmpty) z.writeln('Notfallkontakte:\n${_kontakte.text.trim()}\n');
    z.writeln('Wo liegt was?');
    for (var i = 0; i < notfallDokumente.length; i++) {
      final ort = _orte[i]!.text.trim();
      if (ort.isNotEmpty || store.checklisten['notfall:$i'] == true) {
        z.writeln('• ${notfallDokumente[i]}: ${ort.isEmpty ? 'vorhanden' : ort}');
      }
    }
    final vers = store.vertraege.where((v) => v.art == 'Versicherung' && !v.gekuendigt);
    if (vers.isNotEmpty) {
      z.writeln('\nVersicherungen:');
      for (final v in vers) {
        z.writeln('• ${v.versicherungsArt ?? 'Versicherung'}: ${v.anbieter}${v.nummer == null ? '' : ', Nr. ${v.nummer}'}');
      }
    }
    final andere = store.vertraege.where((v) => v.art != 'Versicherung' && !v.gekuendigt);
    if (andere.isNotEmpty) {
      z.writeln('\nVerträge:');
      for (final v in andere) {
        z.writeln('• ${v.art}: ${v.anbieter}${v.nummer == null ? '' : ', Nr. ${v.nummer}'}');
      }
    }
    return z.toString();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notfallmappe'),
        actions: [
          IconButton(tooltip: 'Teilen', icon: const Icon(Icons.share_outlined), onPressed: () => textTeilen(_alsText())),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
              'Damit Angehörige im Notfall wissen, wo wichtige Unterlagen liegen. Trag nur den Ort ein, keine Passwörter oder PINs.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          TextField(
            controller: _kontakte,
            minLines: 2,
            maxLines: 5,
            decoration: feld(labelText: 'Notfallkontakte', hintText: 'Name, Beziehung, Telefon'),
            onChanged: (v) => _setze('notfall:kontakte', v),
          ),
          const Abschnitt('Dokumente'),
          for (var i = 0; i < notfallDokumente.length; i++)
            PTKarte(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
              child: Column(children: [
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: store.checklisten['notfall:$i'] == true,
                  title: Text(notfallDokumente[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                  onChanged: (v) => store.checklistePunkt('notfall:$i', v ?? false),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: TextField(
                    controller: _orte[i],
                    decoration: feld(hintText: 'Wo liegt es? z. B. Ordner im Schlafzimmerschrank'),
                    onChanged: (v) => _setze('notfall:$i', v),
                  ),
                ),
              ]),
            ),
          const Text('Verträge und Versicherungen aus dem Papiertiger werden beim Teilen automatisch aufgelistet.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Wiederkehrende Aufgaben

class HaushaltsTermine extends StatelessWidget {
  const HaushaltsTermine({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wiederkehrende Aufgaben')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Mit einem Tipp eintragen – der Tiger erinnert dich dann regelmäßig.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          for (final v in haushaltsTermine)
            Builder(builder: (context) {
              final da = store.termine.any((t) => t.titel == v.titel && !t.erledigt);
              return PTKarte(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(v.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('alle ${v.monate == 1 ? 'Monat' : '${v.monate} Monate'}${v.notiz.isEmpty ? '' : ' · ${v.notiz}'}'),
                  trailing: da
                      ? const Icon(Icons.check_circle, color: PT.gruen)
                      : IconButton(
                          icon: const Icon(Icons.add_alarm_outlined),
                          onPressed: () async {
                            final d = await datumWaehlen(context, start: DateTime.now());
                            if (d == null) return;
                            await store.terminSpeichern(terminAusVorlage(v, id: neueId(), start: d));
                          },
                        ),
                ),
              );
            }),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermineListe())),
            icon: const Icon(Icons.event_repeat_outlined),
            label: const Text('Alle meine Termine'),
          ),
        ],
      ),
    );
  }
}
