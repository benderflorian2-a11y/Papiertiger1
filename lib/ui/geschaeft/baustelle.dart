import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/geschaeft.dart';
import '../../data/models.dart';
import '../../logic/android_kanal.dart';
import '../../logic/export.dart';
import '../../logic/projekte.dart';
import '../../logic/rechnungen.dart';
import '../../logic/texterkennung.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/unterschrift.dart';
import 'geschaeft.dart';

/// Tab „Baustelle“ im Projekt: Adresse, Fotos, Bautagebuch, Regieberichte und Abnahme.
class BaustelleTab extends StatelessWidget {
  const BaustelleTab({super.key, required this.projekt});

  final Projekt projekt;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = projekt;
    final k = store.kundeMitId(p.kundeId);
    final offen = offeneRegieberichte(p);
    final fotos = [...p.fotos]..sort((a, b) => b.datum.compareTo(a.datum));
    final tage = [...p.tagebuch]..sort((a, b) => b.datum.compareTo(a.datum));
    final berichte = [...p.berichte]..sort((a, b) => b.datum.compareTo(a.datum));
    void oeffne(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return ListView(padding: const EdgeInsets.all(16), children: [
      PTKarte(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: const Icon(Icons.place_outlined, color: PT.orangeDunkel),
          title: Text(p.adresse.isEmpty ? 'Adresse der Baustelle eintragen' : p.adresse),
          trailing: p.adresse.isEmpty
              ? const Icon(Icons.edit_outlined)
              : IconButton(
                  tooltip: 'Navigation',
                  icon: const Icon(Icons.directions_outlined),
                  onPressed: () => AndroidKanal.oeffnen(Uri.parse('geo:0,0?q=${Uri.encodeComponent(p.adresse)}')),
                ),
          onTap: () async {
            final t = await _eingabe(context, 'Adresse der Baustelle', start: p.adresse.isEmpty ? (k?.adresse ?? '') : p.adresse);
            if (t == null) return;
            p.adresse = t.replaceAll('\n', ', ');
            await store.geaendert();
          },
        ),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final kandidaten = store.rechnungen
              .where((r) => !r.storniert && (r.id == p.angebotId || r.projektId == p.id) && !r.istRechnung)
              .toList()
            ..sort((a, b) => (a.art == 'auftragsbestaetigung' ? 0 : 1).compareTo(b.art == 'auftragsbestaetigung' ? 0 : 1));
          final d = await arbeitsauftragAlsPdf(p, store.firma, k,
              einsaetze: store.einsaetze, auftrag: kandidaten.firstOrNull);
          await dateiTeilen(d.path, mimeType: 'application/pdf', text: 'Arbeitsauftrag ${p.name}');
        },
        icon: const Icon(Icons.assignment_outlined),
        label: const Text('Arbeitsauftrag fürs Team (PDF)'),
      ),
      // ------------------------------------------------ Fotos
      Row(children: [
        Expanded(child: Abschnitt('Fotos (${p.fotos.length})')),
        TextButton.icon(
          onPressed: () async {
            final pfad = await Texterkennung.bildHolen(kamera: true);
            if (pfad == null || !context.mounted) return;
            final text = await _eingabe(context, 'Beschreibung (optional)', erlaubtLeer: true);
            p.fotos.add(Baufoto(pfad: pfad, datum: DateTime.now(), text: text ?? ''));
            await store.geaendert();
          },
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: const Text('Foto'),
        ),
      ]),
      if (fotos.isEmpty)
        const Text('Vorher-, Zwischen- und Nachher-Fotos – sie kommen automatisch ins Bautagebuch.',
            style: TextStyle(color: PT.grau, fontSize: 13))
      else
        SizedBox(
          height: 96,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final f in fotos)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _fotoZeigen(context, p, f),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: File(f.pfad).existsSync()
                        ? Image.file(File(f.pfad), width: 96, height: 96, fit: BoxFit.cover, cacheWidth: 300)
                        : Container(width: 96, height: 96, color: PT.sand, child: const Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
          ]),
        ),
      // ------------------------------------------------ Bautagebuch
      Row(children: [
        const Expanded(child: Abschnitt('Bautagebuch')),
        if (tage.isNotEmpty)
          IconButton(
            tooltip: 'Als PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              final d = await bautagebuchAlsPdf(p, store.firma, k);
              await dateiTeilen(d.path, mimeType: 'application/pdf');
            },
          ),
        TextButton.icon(
          onPressed: () => oeffne(TagesberichtScreen(projekt: p)),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Heute'),
        ),
      ]),
      for (final t in tage.take(10))
        PTKarte(
          padding: const EdgeInsets.all(12),
          onTap: () => oeffne(TagesberichtScreen(projekt: p, bericht: t)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${datumKurz(t.datum)}${t.wetter.isEmpty ? '' : ' · ${t.wetter}'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (t.arbeiten.isNotEmpty) Text(t.arbeiten, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (t.personen.isNotEmpty) Text(t.personen, style: const TextStyle(color: PT.grau, fontSize: 13)),
          ]),
        ),
      // ------------------------------------------------ Berichte
      const Abschnitt('Regieberichte und Abnahme'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(
          avatar: const Icon(Icons.more_time, size: 18),
          label: const Text('Regiebericht'),
          onPressed: () => oeffne(BauberichtScreen(projekt: p, art: 'regie')),
        ),
        ActionChip(
          avatar: const Icon(Icons.task_alt, size: 18),
          label: const Text('Abnahmeprotokoll'),
          onPressed: () => oeffne(BauberichtScreen(projekt: p, art: 'abnahme')),
        ),
      ]),
      const SizedBox(height: 8),
      for (final b in berichte)
        PTKarte(
          padding: const EdgeInsets.all(12),
          onTap: () => oeffne(BauberichtScreen(projekt: p, art: b.art, bericht: b)),
          child: Row(children: [
            Icon(b.art == 'abnahme' ? Icons.task_alt : Icons.more_time, color: PT.orangeDunkel),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b.titel} ${datumKurz(b.datum)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  [
                    if (b.art == 'regie' && b.stunden > 0) '${b.stunden.toStringAsFixed(b.stunden == b.stunden.roundToDouble() ? 0 : 2).replaceAll('.', ',')} Std.',
                    b.unterschrift == null ? 'nicht unterschrieben' : 'unterschrieben von ${b.unterschriftName}',
                    if (b.art == 'regie') b.abgerechnet ? 'abgerechnet' : 'noch nicht abgerechnet',
                  ].join(' · '),
                  style: const TextStyle(color: PT.grau, fontSize: 13),
                ),
              ]),
            ),
          ]),
        ),
      if (offen.isNotEmpty)
        FilledButton.icon(
          onPressed: () async {
            final f = store.firma;
            final r = Rechnung(
              id: neueId(),
              art: 'rechnung',
              nummer: naechsteNummer(store.rechnungen, art: 'rechnung', jahr: DateTime.now().year),
              kundeId: p.kundeId,
              datum: DateTime.now(),
              leistungVon: offen.first.datum,
              leistungBis: offen.last.datum,
              zahlungszielTage: f.zahlungszielTage,
              projektId: p.id,
              positionen: regiePositionen(offen,
                  stundensatz: p.stundensatz > 0 ? p.stundensatz : f.stundensatz, ustSatz: f.kleinunternehmer ? 0 : 19),
            );
            for (final b in offen) {
              b.abgerechnet = true;
            }
            await store.rechnungSpeichern(r);
            if (context.mounted) oeffne(RechnungFormular(art: 'rechnung', rechnung: r));
          },
          icon: const Icon(Icons.receipt_outlined),
          label: Text('${offen.length} Regiebericht${offen.length == 1 ? '' : 'e'} abrechnen'),
        ),
    ]);
  }

  Future<void> _fotoZeigen(BuildContext context, Projekt p, Baufoto f) => showDialog<void>(
        context: context,
        builder: (d) => Dialog(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (File(f.pfad).existsSync()) Image.file(File(f.pfad)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${datumKurz(f.datum)}${f.text.isEmpty ? '' : ' · ${f.text}'}'),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () {
                  p.fotos.remove(f);
                  StoreScope.of(context).geaendert();
                  Navigator.pop(d);
                },
                child: const Text('Löschen'),
              ),
              TextButton(onPressed: () => dateiTeilen(f.pfad, mimeType: 'image/jpeg'), child: const Text('Teilen')),
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Schließen')),
            ]),
          ]),
        ),
      );
}

Future<String?> _eingabe(BuildContext context, String titel, {String start = '', bool erlaubtLeer = false}) async {
  final c = TextEditingController(text: start);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titel),
      content: TextField(controller: c, autofocus: true, minLines: 1, maxLines: 3, decoration: feld()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('OK')),
      ],
    ),
  );
  final t = c.text.trim();
  c.dispose();
  if (ok != true) return null;
  return t.isEmpty && !erlaubtLeer ? null : t;
}

/// Ein Tag im Bautagebuch.
class TagesberichtScreen extends StatefulWidget {
  const TagesberichtScreen({super.key, required this.projekt, this.bericht});

  final Projekt projekt;
  final Tagesbericht? bericht;

  @override
  State<TagesberichtScreen> createState() => _TagesberichtScreenState();
}

class _TagesberichtScreenState extends State<TagesberichtScreen> {
  late DateTime _datum = widget.bericht?.datum ?? DateTime.now();
  late final _wetter = TextEditingController(text: widget.bericht?.wetter ?? '');
  late final _personen = TextEditingController(
      text: widget.bericht?.personen ??
          {for (final z in widget.projekt.zeiten) if (_gleicherTag(z.datum, DateTime.now()) && z.person.isNotEmpty) z.person}
              .join(', '));
  late final _arbeiten = TextEditingController(text: widget.bericht?.arbeiten ?? '');
  late final _material = TextEditingController(text: widget.bericht?.material ?? '');
  late final _besonders = TextEditingController(text: widget.bericht?.besonderheiten ?? '');

  static bool _gleicherTag(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    for (final c in [_wetter, _personen, _arbeiten, _material, _besonders]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    Widget f(TextEditingController c, String label, {int zeilen = 1, String? hint}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: c, minLines: zeilen, maxLines: zeilen + 3, decoration: feld(labelText: label, hintText: hint)),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bautagebuch'),
        actions: [
          if (widget.bericht != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                widget.projekt.tagebuch.remove(widget.bericht);
                store.geaendert();
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(datumLang(_datum)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final d = await datumWaehlen(context, start: _datum);
            if (d != null) setState(() => _datum = d);
          },
        ),
        Wrap(spacing: 6, children: [
          for (final w in const ['sonnig', 'bewölkt', 'Regen', 'Frost', 'Sturm'])
            ChoiceChip(
              label: Text(w),
              selected: _wetter.text.contains(w),
              onSelected: (_) => setState(() => _wetter.text = w),
            ),
        ]),
        const SizedBox(height: 8),
        f(_wetter, 'Wetter / Temperatur', hint: 'z. B. Regen, 8 °C'),
        f(_personen, 'Anwesend', hint: 'Namen oder Anzahl'),
        f(_arbeiten, 'Ausgeführte Arbeiten', zeilen: 3),
        f(_material, 'Material geliefert / verbraucht', zeilen: 2),
        f(_besonders, 'Besonderheiten, Behinderungen, Anweisungen', zeilen: 2),
        const Text('Fotos von heute aus dem Projekt kommen automatisch mit ins PDF.',
            style: TextStyle(color: PT.grau, fontSize: 12)),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              final t = widget.bericht ?? Tagesbericht(datum: _datum);
              t
                ..datum = _datum
                ..wetter = _wetter.text.trim()
                ..personen = _personen.text.trim()
                ..arbeiten = _arbeiten.text.trim()
                ..material = _material.text.trim()
                ..besonderheiten = _besonders.text.trim();
              if (widget.bericht == null) widget.projekt.tagebuch.add(t);
              await store.geaendert();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Speichern'),
          ),
        ),
      ),
    );
  }
}

/// Regiebericht oder Abnahmeprotokoll, mit Unterschrift des Kunden auf dem Handy.
class BauberichtScreen extends StatefulWidget {
  const BauberichtScreen({super.key, required this.projekt, required this.art, this.bericht});

  final Projekt projekt;
  final String art;
  final Baubericht? bericht;

  @override
  State<BauberichtScreen> createState() => _BauberichtScreenState();
}

class _BauberichtScreenState extends State<BauberichtScreen> {
  late final Baubericht _b =
      widget.bericht ?? Baubericht(id: neueId(), art: widget.art, datum: DateTime.now());
  late final _text = TextEditingController(text: _b.text);
  late final _stunden = TextEditingController(
      text: _b.stunden == 0 ? '' : _b.stunden.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ','));
  late final _personen = TextEditingController(text: _b.personen);
  late final _material = TextEditingController(text: _b.material);
  late final _maengel = TextEditingController(text: _b.maengel);

  @override
  void dispose() {
    for (final c in [_text, _stunden, _personen, _material, _maengel]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _regie => _b.art == 'regie';

  Future<void> _uebernehmen() async {
    final store = StoreScope.of(context);
    _b
      ..text = _text.text.trim()
      ..stunden = double.tryParse(_stunden.text.replaceAll(',', '.')) ?? 0
      ..personen = _personen.text.trim()
      ..material = _material.text.trim()
      ..maengel = _maengel.text.trim();
    if (!widget.projekt.berichte.contains(_b)) widget.projekt.berichte.add(_b);
    await store.geaendert();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final k = store.kundeMitId(widget.projekt.kundeId);
    final unterschrieben = _b.unterschrift != null;
    Widget f(TextEditingController c, String label, {int zeilen = 1, bool zahl = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            enabled: !unterschrieben,
            minLines: zeilen,
            maxLines: zeilen + 4,
            keyboardType: zahl ? const TextInputType.numberWithOptions(decimal: true) : null,
            decoration: feld(labelText: label),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(_b.titel),
        actions: [
          if (widget.bericht != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                widget.projekt.berichte.remove(_b);
                store.geaendert();
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${widget.projekt.name} · ${datumLang(_b.datum)}', style: const TextStyle(color: PT.grau)),
        const SizedBox(height: 10),
        if (_regie) ...[
          f(_text, 'Ausgeführte Zusatzarbeiten', zeilen: 3),
          Row(children: [
            Expanded(child: f(_stunden, 'Stunden', zahl: true)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: f(_personen, 'Ausgeführt von')),
          ]),
          f(_material, 'Material', zeilen: 2),
        ] else ...[
          f(_text, 'Abgenommene Leistung', zeilen: 3),
          f(_maengel, 'Mängel (leer lassen, wenn keine)', zeilen: 2),
          const Text('Mit der Abnahme beginnt die Gewährleistung. Allgemeine Info, keine Rechtsberatung.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        if (unterschrieben)
          PTKarte(
            farbe: PT.gruenHell,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Unterschrieben von ${_b.unterschriftName} am ${datumKurz(_b.unterschriebenAm!)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (File(_b.unterschrift!).existsSync()) Image.file(File(_b.unterschrift!), height: 80),
            ]),
          )
        else
          OutlinedButton.icon(
            onPressed: () async {
              await _uebernehmen();
              if (!context.mounted) return;
              final e = await Navigator.of(context).push<(String, String)>(MaterialPageRoute(
                  builder: (_) => UnterschriftScreen(
                        titel: 'Unterschrift Auftraggeber',
                        hinweis: _regie
                            ? 'Hiermit bestätige ich die aufgeführten Zusatzarbeiten.'
                            : 'Hiermit nehme ich die Leistung ${_maengel.text.trim().isEmpty ? 'ohne Mängel' : 'mit den genannten Mängeln'} ab.',
                      )));
              if (e == null) return;
              _b
                ..unterschrift = e.$1
                ..unterschriftName = e.$2
                ..unterschriebenAm = DateTime.now();
              await store.geaendert();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.draw_outlined),
            label: const Text('Kunde unterschreibt auf dem Handy'),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _uebernehmen();
                  final d = await berichtAlsPdf(_b, widget.projekt, store.firma, k);
                  if (k != null && k.email.isNotEmpty) {
                    await mailMitAnhang(
                      an: k.email,
                      betreff: '${_b.titel} ${widget.projekt.name}',
                      text: 'Guten Tag,\n\nanbei das ${_b.titel} vom ${datumKurz(_b.datum)}.\n\nMit freundlichen Grüßen\n${store.firma.name}',
                      pfade: [d.path],
                    );
                  } else {
                    await dateiTeilen(d.path, mimeType: 'application/pdf');
                  }
                },
                icon: const Icon(Icons.send_outlined),
                label: const Text('PDF senden'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  await _uebernehmen();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Speichern'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
