import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/export.dart';
import '../../logic/steuer.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Werbungskosten aus gespeicherten Angaben und markierten Posten.
Werbungskosten werbungskostenFuer(int jahr, Map<String, String> notizen, List<SteuerPosten> posten) {
  int zahl(String k) => int.tryParse(notizen['steuer:$jahr:$k'] ?? '') ?? 0;
  return Werbungskosten(
    fahrt: entfernungspauschale(km: zahl('km'), tage: zahl('arbeitstage'), jahr: jahr),
    homeoffice: homeofficePauschale(zahl('homeoffice')),
    weitere: posten
        .where((p) => p.kategorie == 'Arbeitsmittel' || p.kategorie == 'Fortbildung' || p.kategorie == 'Fahrtkosten')
        .fold(0.0, (s, p) => s + (p.betrag ?? 0)),
  );
}

class SteuerScreen extends StatefulWidget {
  const SteuerScreen({super.key});

  @override
  State<SteuerScreen> createState() => _SteuerScreenState();
}

class _SteuerScreenState extends State<SteuerScreen> {
  int _jahr = DateTime.now().year - 1;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final posten = steuerPosten(jahr: _jahr, briefe: store.briefe, belege: store.belege, vertraege: store.vertraege);
    final summen = summenNachKategorie(posten);
    final gesamt = summen.values.fold<double>(0, (a, b) => a + b);
    final werbung = werbungskostenFuer(_jahr, store.notizen, posten);
    final jetzt = DateTime.now().year;
    final jahre = [for (var j = jetzt; j >= jetzt - 4; j--) j];
    final frist = abgabefrist(_jahr);
    final checkErledigt = [
      for (var i = 0; i < steuerCheckliste.length; i++)
        if (store.checklisten['steuer:$_jahr:$i'] == true) i
    ].length;

    return Scaffold(
      appBar: AppBar(title: const Text('Steuer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Wrap(spacing: 8, children: [
            for (final j in jahre)
              ChoiceChip(label: Text('$j'), selected: _jahr == j, onSelected: (_) => setState(() => _jahr = j)),
          ]),
          const SizedBox(height: 12),
          if (_jahr < jetzt)
            PTKarte(
              farbe: PT.orangeHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Steuererklärung $_jahr', style: const TextStyle(color: PT.grau)),
                  Text('Abgabe bis ${datumLang(frist)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(
                      'Gilt, wenn du eine Erklärung abgeben musst (ohne Steuerberater). Freiwillig geht es bis '
                      '${datumKurz(freiwilligBis(_jahr))} – oft gibt es Geld zurück.',
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  if (!frist.isBefore(DateTime.now()))
                    TextButton.icon(
                      onPressed: () async {
                        final id = 'steuer-$_jahr';
                        await store.terminSpeichern(Termin(
                          id: id,
                          titel: 'Steuererklärung $_jahr abgeben',
                          datum: frist,
                          art: 'Behörde',
                          notiz: 'Abgabefrist ohne Steuerberater. Unterlagen findest du im Papiertiger unter Steuer.',
                        ));
                        if (context.mounted) zeigeHinweis(context, 'Der Tiger erinnert dich rechtzeitig.');
                      },
                      icon: const Icon(Icons.add_alarm_outlined, size: 18),
                      label: Text(store.termine.any((t) => t.id == 'steuer-$_jahr')
                          ? 'Erinnerung ist eingetragen'
                          : 'Erinnerung anlegen'),
                    ),
                ],
              ),
            ),
          PTKarte(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => WerbungskostenScreen(jahr: _jahr))),
            child: Row(
              children: [
                const IconKachel(Icons.work_outline),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Werbungskosten-Rechner', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        werbung.summe == 0
                            ? 'Fahrten, Homeoffice, Arbeitsmittel'
                            : '${euro(werbung.summe)} · ${werbung.ueberPauschale ? '${euro(werbung.mehrAlsPauschale)} über der Pauschale' : 'unter der Pauschale von ${euro(arbeitnehmerPauschbetrag)}'}',
                        style: const TextStyle(color: PT.grau, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),
          PTKarte(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => SteuerCheckliste(jahr: _jahr))),
            child: Row(
              children: [
                const IconKachel(Icons.checklist),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Unterlagen-Checkliste', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('$checkErledigt/${steuerCheckliste.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          PTKarte(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => SteuerFragen(jahr: _jahr))),
            child: Row(
              children: [
                const IconKachel(Icons.help_outline),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    (store.notizen['steuer:$_jahr:fragen'] ?? '').trim().isEmpty
                        ? 'Fragen an die Steuerberatung sammeln'
                        : '${(store.notizen['steuer:$_jahr:fragen'] ?? '').trim().split('\n').length} Fragen an die Steuerberatung',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),
          if (store.belege.any((b) => b.steuerKategorie != null && b.datum.year == _jahr))
            OutlinedButton.icon(
              onPressed: () async {
                final l = store.belege.where((b) => b.steuerKategorie != null && b.datum.year == _jahr).toList()
                  ..sort((a, b) => a.datum.compareTo(b.datum));
                final f = await belegeAlsPdf('Steuer-Belege $_jahr', l);
                await dateiTeilen(f.path, mimeType: 'application/pdf');
              },
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Belege mit Fotos als PDF'),
            ),
          const Abschnitt('Gesammelt'),
          PTKarte(
            farbe: PT.orangeHell,
            child: Text('${posten.length} Posten · ${euro(gesamt)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          if (posten.isEmpty)
            const LeerHinweis(
                icon: Icons.calculate_outlined,
                text: 'Noch nichts für dieses Jahr. Markiere Belege und Briefe unter „Für die Steuer“ – '
                    'der Tiger macht oft einen Vorschlag.')
          else ...[
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final e in summen.entries) ListTile(dense: true, title: Text(e.key), trailing: Text(euro(e.value))),
              ]),
            ),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final p in posten)
                  ListTile(
                    dense: true,
                    title: Text(p.titel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${datumKurz(p.datum)} · ${p.kategorie}${p.vorschlag ? ' · Vorschlag aus ${p.quelle}' : ''}'),
                    trailing: Text(p.betrag != null ? euro(p.betrag!) : '–'),
                  ),
              ]),
            ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final f = await textDatei('Papiertiger Steuer $_jahr.csv', steuerCsv(posten));
                    await dateiTeilen(f.path, mimeType: 'text/csv');
                  },
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Tabelle'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final f = await steuerAlsPdf(_jahr, posten, werbung: werbung.summe > 0 ? werbung : null);
                    await dateiTeilen(f.path, mimeType: 'application/pdf');
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          const Text(
              'Keine Steuerberatung. Pauschalen Stand 2026, ohne Gewähr. Ob etwas absetzbar ist, hängt von deiner Situation ab – '
              'Hilfe gibt es z. B. bei Lohnsteuerhilfevereinen.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}

class WerbungskostenScreen extends StatefulWidget {
  const WerbungskostenScreen({super.key, required this.jahr});

  final int jahr;

  @override
  State<WerbungskostenScreen> createState() => _WerbungskostenScreenState();
}

class _WerbungskostenScreenState extends State<WerbungskostenScreen> {
  final _c = <String, TextEditingController>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = StoreScope.of(context).notizen;
    for (final k in const ['km', 'arbeitstage', 'homeoffice']) {
      _c.putIfAbsent(k, () => TextEditingController(text: n['steuer:${widget.jahr}:$k'] ?? (k == 'arbeitstage' ? '220' : '')));
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setze(String k) {
    final store = StoreScope.of(context);
    store.notizen['steuer:${widget.jahr}:$k'] = _c[k]!.text.trim();
    store.geaendert();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final posten = steuerPosten(jahr: widget.jahr, briefe: store.briefe, belege: store.belege, vertraege: store.vertraege);
    final w = werbungskostenFuer(widget.jahr, store.notizen, posten);
    Widget eingabe(String k, String label, {String? suffix, String? hint}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _c[k],
            keyboardType: TextInputType.number,
            decoration: feld(labelText: label, suffixText: suffix, hintText: hint),
            onChanged: (_) => _setze(k),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text('Werbungskosten ${widget.jahr}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          eingabe('km', 'Einfache Entfernung zur Arbeit', suffix: 'km'),
          eingabe('arbeitstage', 'Tage im Büro', suffix: 'Tage', hint: 'meist 200–230'),
          eingabe('homeoffice', 'Tage im Homeoffice', suffix: 'Tage'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(title: const Text('Fahrten zur Arbeit'), trailing: Text(euro(w.fahrt))),
              ListTile(title: const Text('Homeoffice-Pauschale'), trailing: Text(euro(w.homeoffice))),
              ListTile(
                  title: const Text('Arbeitsmittel, Fortbildung, Fahrtkosten'),
                  subtitle: const Text('aus deinen markierten Belegen und Briefen'),
                  trailing: Text(euro(w.weitere))),
              const Divider(height: 1),
              ListTile(
                title: const Text('Zusammen', style: TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text(euro(w.summe), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          PTKarte(
            farbe: w.ueberPauschale ? PT.gruenHell : PT.orangeHell,
            child: Text(
              w.ueberPauschale
                  ? 'Du liegst ${euro(w.mehrAlsPauschale)} über dem Arbeitnehmer-Pauschbetrag von ${euro(arbeitnehmerPauschbetrag)}. '
                      'Es kann sich lohnen, die Werbungskosten einzeln anzugeben.'
                  : 'Unter ${euro(arbeitnehmerPauschbetrag)} zieht das Finanzamt automatisch den Pauschbetrag ab. '
                      'Einzelne Angaben bringen dann meist nichts extra.',
            ),
          ),
          Text(
            widget.jahr >= 2026
                ? 'Gerechnet mit 38 Cent pro Kilometer ab dem ersten Kilometer und 6 € pro Homeoffice-Tag (höchstens 1.260 €).'
                : 'Gerechnet mit 30 Cent für die ersten 20 km, danach 38 Cent, und 6 € pro Homeoffice-Tag (höchstens 1.260 €). '
                    'An einem Tag zählt entweder Fahrt oder Homeoffice.',
            style: const TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class SteuerCheckliste extends StatelessWidget {
  const SteuerCheckliste({super.key, required this.jahr});

  final int jahr;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Unterlagen $jahr')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Was du für die Steuererklärung meist brauchst. Nicht alles betrifft jeden.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < steuerCheckliste.length; i++)
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: store.checklisten['steuer:$jahr:$i'] == true,
                  title: Text(steuerCheckliste[i]),
                  onChanged: (v) => store.checklistePunkt('steuer:$jahr:$i', v ?? false),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class SteuerFragen extends StatefulWidget {
  const SteuerFragen({super.key, required this.jahr});

  final int jahr;

  @override
  State<SteuerFragen> createState() => _SteuerFragenState();
}

class _SteuerFragenState extends State<SteuerFragen> {
  TextEditingController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= TextEditingController(text: StoreScope.of(context).notizen['steuer:${widget.jahr}:fragen'] ?? '');
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    const vorschlaege = [
      'Lohnt sich für mich eine Steuererklärung?',
      'Kann ich Homeoffice und Fahrten gleichzeitig angeben?',
      'Welche Belege muss ich aufheben und wie lange?',
      'Muss ich Vorauszahlungen leisten?',
      'Lohnt sich die Kleinunternehmerregelung für mich?',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Fragen ${widget.jahr}'),
        actions: [
          IconButton(
            tooltip: 'Teilen',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => textTeilen('Fragen zur Steuer ${widget.jahr}:\n\n${_c!.text.trim()}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Schreib auf, was du deine Steuerberatung oder den Lohnsteuerhilfeverein fragen willst – eine Frage pro Zeile.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            minLines: 6,
            maxLines: 14,
            decoration: feld(hintText: 'Eine Frage pro Zeile'),
            onChanged: (v) {
              store.notizen['steuer:${widget.jahr}:fragen'] = v;
              store.geaendert();
            },
          ),
          const Abschnitt('Häufige Fragen'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final v in vorschlaege)
              ActionChip(
                label: Text(v),
                onPressed: () {
                  final t = _c!.text.trim();
                  _c!.text = t.isEmpty ? v : '$t\n$v';
                  store.notizen['steuer:${widget.jahr}:fragen'] = _c!.text;
                  store.geaendert();
                },
              ),
          ]),
        ],
      ),
    );
  }
}
