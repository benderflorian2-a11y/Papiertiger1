import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../data/geschaeft.dart';
import '../../data/models.dart';
import '../../logic/kalkulation.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

double? _zahl(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim());
String _feld(double? v) =>
    v == null || v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ','));

/// Artikel- und Leistungskatalog. Mit [auswahl] liefert ein Tipp den Artikel zurück.
class KatalogScreen extends StatefulWidget {
  const KatalogScreen({super.key, this.auswahl = false});

  final bool auswahl;

  @override
  State<KatalogScreen> createState() => _KatalogScreenState();
}

class _KatalogScreenState extends State<KatalogScreen> {
  String _suche = '';

  Future<void> _importieren() async {
    final store = StoreScope.of(context);
    String? text;
    final wahl = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('Datei wählen'),
            subtitle: const Text('DATANORM vom Großhändler oder CSV aus Excel'),
            onTap: () => Navigator.pop(c, 'datei'),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: const Text('Tabelle einfügen'),
            subtitle: const Text('Zeilen aus Excel oder Google Tabellen kopieren'),
            onTap: () => Navigator.pop(c, 'text'),
          ),
        ]),
      ),
    );
    if (wahl == 'datei') {
      final f = await openFile(acceptedTypeGroups: [
        const XTypeGroup(label: 'Tabelle oder DATANORM', extensions: ['csv', 'txt', '001', '002', '003', 'dat', 'wrg'])
      ]);
      if (f == null) return;
      text = textAusBytes(await f.readAsBytes());
    } else if (wahl == 'text') {
      if (!mounted) return;
      final c = TextEditingController();
      text = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Tabelle einfügen'),
          content: TextField(
            controller: c,
            minLines: 8,
            maxLines: 14,
            decoration: feld(hintText: 'Nummer; Bezeichnung; Einheit; Einkaufspreis\n4711; Fliesenkleber 25 kg; Sack; 12,50'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Importieren')),
          ],
        ),
      );
      c.dispose();
    }
    if (text == null || text.trim().isEmpty || !mounted) return;
    final datanorm = istDatanorm(text);
    var rabatt = 0.0;
    if (datanorm) {
      final r = await _zahlFragen('Dein Rabatt beim Großhändler', 'auf den Listenpreis', '0');
      if (r == null) return;
      rabatt = r;
    }
    final aufschlag = await _aufschlagFragen();
    if (aufschlag == null) return;
    final neu = datanorm
        ? katalogAusDatanorm(text, neueId: neueId, rabattProzent: rabatt, aufschlag: aufschlag)
        : katalogAusCsv(text, neueId: neueId, aufschlag: aufschlag);
    // gleiche Artikelnummer: vorhandenen Artikel aktualisieren statt doppelt anlegen
    for (final a in neu.where((a) => a.nummer.isNotEmpty)) {
      final alt = store.artikel.where((x) => x.nummer == a.nummer).firstOrNull;
      if (alt != null) {
        alt
          ..text = a.text
          ..einkauf = a.einkauf
          ..einheit = a.einheit;
      }
    }
    neu.removeWhere((a) => a.nummer.isNotEmpty && store.artikel.any((x) => x.nummer == a.nummer));
    store.artikel.addAll(neu);
    await store.geaendert();
    if (mounted) zeigeHinweis(context, '${neu.length} Artikel importiert');
  }

  Future<double?> _zahlFragen(String titel, String label, String start) async {
    final c = TextEditingController(text: start);
    final x = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(titel),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: feld(labelText: label, suffixText: '%'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d, _zahl(c.text) ?? 0), child: const Text('OK'))],
      ),
    );
    c.dispose();
    return x;
  }

  Future<double?> _aufschlagFragen() async {
    final c = TextEditingController(text: '20');
    final x = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Aufschlag auf den Einkauf'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: feld(labelText: 'Materialaufschlag', suffixText: '%'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d, _zahl(c.text) ?? 0), child: const Text('OK'))],
      ),
    );
    c.dispose();
    return x;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = katalogSuchen(store.artikel, _suche)..sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.auswahl ? 'Artikel wählen' : 'Katalog'),
        actions: [
          IconButton(tooltip: 'Importieren', icon: const Icon(Icons.upload_file), onPressed: _importieren),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final a = await Navigator.of(context).push<Artikel>(MaterialPageRoute(builder: (_) => const ArtikelFormular()));
          if (a != null && widget.auswahl && context.mounted) Navigator.of(context).pop(a);
        },
        icon: const Icon(Icons.add),
        label: const Text('Artikel / Leistung'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          TextField(
            decoration: feld(hintText: 'Suchen nach Name oder Nummer', prefixIcon: const Icon(Icons.search)),
            onChanged: (v) => setState(() => _suche = v),
          ),
          const SizedBox(height: 8),
          if (store.firma.stundensatz == 0)
            const Text('Tipp: Trag in den Firmendaten deinen Stundensatz ein, dann rechnet der Tiger den Lohn mit ein.',
                style: TextStyle(color: PT.grau, fontSize: 12)),
          if (store.artikel.isEmpty)
            const LeerHinweis(
              icon: Icons.menu_book_outlined,
              text: 'Leg deine Leistungen und dein Material an – oder importiere die Preisliste vom Großhändler als CSV.',
            ),
          for (final a in l)
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => widget.auswahl
                  ? Navigator.of(context).pop(a)
                  : Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtikelFormular(artikel: a))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.text, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        if (a.nummer.isNotEmpty) 'Nr. ${a.nummer}',
                        if (a.einkauf > 0) 'EK ${euro(a.einkauf)}',
                        if (a.minuten > 0) '${_feld(a.minuten)} Min.',
                      ].join(' · '),
                      style: const TextStyle(color: PT.grau, fontSize: 13),
                    ),
                  ]),
                ),
                Text('${euro(vkPreis(a, stundensatz: store.firma.stundensatz))}\n/ ${a.einheit}',
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
        ],
      ),
    );
  }
}

class ArtikelFormular extends StatefulWidget {
  const ArtikelFormular({super.key, this.artikel});

  final Artikel? artikel;

  @override
  State<ArtikelFormular> createState() => _ArtikelFormularState();
}

class _ArtikelFormularState extends State<ArtikelFormular> {
  late final _text = TextEditingController(text: widget.artikel?.text ?? '');
  late final _nummer = TextEditingController(text: widget.artikel?.nummer ?? '');
  late final _einheit = TextEditingController(text: widget.artikel?.einheit ?? 'Stück');
  late final _einkauf = TextEditingController(text: _feld(widget.artikel?.einkauf));
  late final _aufschlag = TextEditingController(text: _feld(widget.artikel?.aufschlagProzent));
  late final _minuten = TextEditingController(text: _feld(widget.artikel?.minuten));
  late final _fest = TextEditingController(text: _feld(widget.artikel?.festpreis));
  late int _ust = widget.artikel?.ustSatz ?? 19;

  @override
  void dispose() {
    for (final c in [_text, _nummer, _einheit, _einkauf, _aufschlag, _minuten, _fest]) {
      c.dispose();
    }
    super.dispose();
  }

  Artikel _bauen(String id) => Artikel(
        id: id,
        text: _text.text.trim(),
        nummer: _nummer.text.trim(),
        einheit: _einheit.text.trim().isEmpty ? 'Stück' : _einheit.text.trim(),
        einkauf: _zahl(_einkauf.text) ?? 0,
        aufschlagProzent: _zahl(_aufschlag.text) ?? 0,
        minuten: _zahl(_minuten.text) ?? 0,
        festpreis: _zahl(_fest.text),
        ustSatz: _ust,
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final vorschau = _bauen('');
    Widget f(TextEditingController c, String label, {bool zahl = false, String? suffix}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            keyboardType: zahl ? const TextInputType.numberWithOptions(decimal: true) : null,
            decoration: feld(labelText: label, suffixText: suffix),
            onChanged: (_) => setState(() {}),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artikel == null ? 'Neuer Artikel' : 'Artikel'),
        actions: [
          if (widget.artikel != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                store.artikel.removeWhere((x) => x.id == widget.artikel!.id);
                store.geaendert();
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          f(_text, 'Bezeichnung'),
          Row(children: [
            Expanded(child: f(_nummer, 'Nummer (optional)')),
            const SizedBox(width: 8),
            Expanded(child: f(_einheit, 'Einheit')),
          ]),
          const Abschnitt('Kalkulation'),
          Row(children: [
            Expanded(child: f(_einkauf, 'Einkauf netto', zahl: true, suffix: '€')),
            const SizedBox(width: 8),
            Expanded(child: f(_aufschlag, 'Aufschlag', zahl: true, suffix: '%')),
          ]),
          f(_minuten, 'Arbeitszeit je Einheit', zahl: true, suffix: 'Min.'),
          f(_fest, 'oder fester Verkaufspreis netto', zahl: true, suffix: '€'),
          Wrap(spacing: 8, children: [
            for (final u in const [19, 7, 0])
              ChoiceChip(label: Text('$u % USt'), selected: _ust == u, onSelected: (_) => setState(() => _ust = u)),
          ]),
          const SizedBox(height: 12),
          PTKarte(
            farbe: PT.orangeHell,
            child: Row(children: [
              const Expanded(child: Text('Verkaufspreis netto', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('${euro(vkPreis(vorschau, stundensatz: store.firma.stundensatz))} / ${vorschau.einheit}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _text.text.trim().isEmpty
                ? null
                : () async {
                    final a = _bauen(widget.artikel?.id ?? neueId());
                    store.artikel.removeWhere((x) => x.id == a.id);
                    store.artikel.add(a);
                    await store.geaendert();
                    if (context.mounted) Navigator.of(context).pop(a);
                  },
            child: const Text('Speichern'),
          ),
        ),
      ),
    );
  }
}

/// Aufmaß: Maße eingeben, die Menge wird berechnet. Abzüge (Fenster, Türen) werden abgezogen.
class AufmassScreen extends StatefulWidget {
  const AufmassScreen({super.key, required this.titel, required this.zeilen});

  final String titel;
  final List<AufmassZeile> zeilen;

  @override
  State<AufmassScreen> createState() => _AufmassScreenState();
}

class _AufmassZeileFelder {
  _AufmassZeileFelder(AufmassZeile a)
      : text = TextEditingController(text: a.text),
        anzahl = TextEditingController(text: a.anzahl == 1 ? '' : _feld(a.anzahl)),
        laenge = TextEditingController(text: _feld(a.laenge)),
        breite = TextEditingController(text: _feld(a.breite)),
        hoehe = TextEditingController(text: _feld(a.hoehe)),
        abzug = a.abzug;

  final TextEditingController text, anzahl, laenge, breite, hoehe;
  bool abzug;

  AufmassZeile get zeile => AufmassZeile(
        text: text.text.trim(),
        anzahl: _zahl(anzahl.text) ?? 1,
        laenge: _zahl(laenge.text),
        breite: _zahl(breite.text),
        hoehe: _zahl(hoehe.text),
        abzug: abzug,
      );

  void dispose() {
    for (final c in [text, anzahl, laenge, breite, hoehe]) {
      c.dispose();
    }
  }
}

class _AufmassScreenState extends State<AufmassScreen> {
  late final List<_AufmassZeileFelder> _z = [
    for (final a in widget.zeilen) _AufmassZeileFelder(a),
    if (widget.zeilen.isEmpty) _AufmassZeileFelder(AufmassZeile()),
  ];

  @override
  void dispose() {
    for (final z in _z) {
      z.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zeilen = [for (final z in _z) z.zeile];
    final summe = aufmassMenge(zeilen);
    Widget zahl(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: label),
            onChanged: (_) => setState(() {}),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(widget.titel.isEmpty ? 'Aufmaß' : 'Aufmaß: ${widget.titel}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Maße in Metern. Nur die nötigen Felder ausfüllen: Länge für m, Länge × Breite für m², '
              'dazu Höhe für m³ bzw. Wandflächen.',
              style: TextStyle(color: PT.grau, fontSize: 13)),
          const SizedBox(height: 8),
          for (var i = 0; i < _z.length; i++)
            PTKarte(
              farbe: _z[i].abzug ? PT.rotHell : Colors.white,
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _z[i].text,
                      decoration: feld(labelText: _z[i].abzug ? 'Abzug (z. B. Fenster)' : 'Bereich (z. B. Wand Nord)'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Löschen',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _z.removeAt(i).dispose()),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  zahl(_z[i].anzahl, 'Anzahl'),
                  const SizedBox(width: 6),
                  zahl(_z[i].laenge, 'Länge'),
                  const SizedBox(width: 6),
                  zahl(_z[i].breite, 'Breite'),
                  const SizedBox(width: 6),
                  zahl(_z[i].hoehe, 'Höhe'),
                ]),
                Row(children: [
                  Switch(value: _z[i].abzug, onChanged: (v) => setState(() => _z[i].abzug = v)),
                  const Text('abziehen'),
                  const Spacer(),
                  Text('= ${_feld(_z[i].zeile.wert.abs())}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          Wrap(spacing: 8, children: [
            TextButton.icon(
              onPressed: () => setState(() => _z.add(_AufmassZeileFelder(AufmassZeile()))),
              icon: const Icon(Icons.add),
              label: const Text('Bereich'),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _z.add(_AufmassZeileFelder(AufmassZeile(abzug: true)))),
              icon: const Icon(Icons.remove),
              label: const Text('Abzug'),
            ),
          ]),
          PTKarte(
            farbe: PT.orangeHell,
            child: Row(children: [
              const Expanded(child: Text('Menge', style: TextStyle(fontWeight: FontWeight.w800))),
              Text(_feld(summe).isEmpty ? '0' : _feld(summe), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop([for (final z in _z) z.zeile]),
            child: const Text('Menge übernehmen'),
          ),
        ),
      ),
    );
  }
}
