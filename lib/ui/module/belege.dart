import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/brief_analyse.dart';
import '../../logic/texterkennung.dart';
import '../app.dart';
import '../brief_detail.dart';
import '../theme.dart';
import '../widgets/common.dart';

Beleg? _finde(List<Beleg> l, String id) {
  for (final b in l) {
    if (b.id == id) return b;
  }
  return null;
}

class BelegeScreen extends StatelessWidget {
  const BelegeScreen({super.key});

  Future<void> _neu(BuildContext context, {required bool? kamera}) async {
    String? bild;
    String text = '';
    if (kamera != null) {
      try {
        bild = await Texterkennung.bildHolen(kamera: kamera);
        if (bild == null) return;
        text = await Texterkennung.textErkennen([bild]);
      } catch (_) {
        if (context.mounted) zeigeHinweis(context, 'Das Foto konnte nicht gelesen werden.');
      }
    }
    final beleg = Beleg(
      id: neueId(),
      haendler: ersteZeile(text),
      datum: erstesDatum(text) ?? DateTime.now(),
      betrag: summeFinden(text),
      bild: bild,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BelegFormular(beleg: beleg, neu: true)));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Belege & Garantien')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (s) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Kassenbon fotografieren'),
                  onTap: () {
                    Navigator.pop(s);
                    _neu(context, kamera: true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Aus Galerie'),
                  onTap: () {
                    Navigator.pop(s);
                    _neu(context, kamera: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Ohne Foto eintragen'),
                  onTap: () {
                    Navigator.pop(s);
                    _neu(context, kamera: null);
                  },
                ),
              ],
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Beleg'),
      ),
      body: store.belege.isEmpty
          ? const LeerHinweis(
              icon: Icons.receipt_long_outlined,
              text:
                  'Fotografiere Kassenbons von größeren Käufen. Der Tiger erinnert dich, bevor die Garantie abläuft.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                for (final b in store.belege)
                  PTKarte(
                    padding: const EdgeInsets.all(14),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => BelegDetail(belegId: b.id))),
                    child: Row(
                      children: [
                        const IconKachel(Icons.receipt_long_outlined),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.haendler.isEmpty ? 'Beleg' : b.haendler,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${datumKurz(b.datum)}${b.betrag != null ? ' · ${euro(b.betrag!)}' : ''}',
                                style: const TextStyle(color: PT.grau, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (b.garantieMonate > 0 && tageBis(b.garantieEnde) >= 0)
                          FristEtikett(b.garantieEnde),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class BelegDetail extends StatelessWidget {
  const BelegDetail({super.key, required this.belegId});

  final String belegId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = _finde(store.belege, belegId);
    if (b == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const LeerHinweis(icon: Icons.receipt_long_outlined, text: 'Gelöscht.'));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(b.haendler.isEmpty ? 'Beleg' : b.haendler),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => BelegFormular(beleg: b))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Löschen',
            onPressed: () {
              Navigator.of(context).pop();
              store.belegLoeschen(b);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (b.garantieMonate > 0)
            PTKarte(
              farbe: tageBis(b.garantieEnde) < 0 ? PT.sand : PT.orangeHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tageBis(b.garantieEnde) < 0 ? 'Garantie abgelaufen am' : 'Garantie bis',
                      style: const TextStyle(color: PT.grau)),
                  const SizedBox(height: 4),
                  Text(datumLang(b.garantieEnde),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(title: const Text('Kaufdatum'), trailing: Text(datumKurz(b.datum))),
                if (b.betrag != null)
                  ListTile(title: const Text('Betrag'), trailing: Text(euro(b.betrag!))),
                ListTile(
                    title: const Text('Für die Steuer'),
                    trailing: Text(b.steuerKategorie ?? 'Nein')),
                if (b.notiz.isNotEmpty) ListTile(title: const Text('Notiz'), subtitle: Text(b.notiz)),
              ],
            ),
          ),
          if (b.bild != null)
            GestureDetector(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => BildAnsicht(pfad: b.bild!))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(b.bild!),
                    height: 320, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
        ],
      ),
    );
  }
}

class BelegFormular extends StatefulWidget {
  const BelegFormular({super.key, required this.beleg, this.neu = false});

  final Beleg beleg;
  final bool neu;

  @override
  State<BelegFormular> createState() => _BelegFormularState();
}

class _BelegFormularState extends State<BelegFormular> {
  late final _haendler = TextEditingController(text: widget.beleg.haendler);
  late final _betrag = TextEditingController(
      text: widget.beleg.betrag?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
  late final _notiz = TextEditingController(text: widget.beleg.notiz);
  late DateTime _datum = widget.beleg.datum;
  late int _garantie = widget.beleg.garantieMonate;
  late String? _steuer = widget.beleg.steuerKategorie;

  @override
  void dispose() {
    _haendler.dispose();
    _betrag.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final store = StoreScope.of(context);
    final b = widget.beleg
      ..haendler = _haendler.text.trim()
      ..datum = _datum
      ..betrag = double.tryParse(_betrag.text.replaceAll('.', '').replaceAll(',', '.'))
      ..garantieMonate = _garantie
      ..steuerKategorie = _steuer
      ..notiz = _notiz.text.trim();
    await store.belegSpeichern(b);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.neu ? 'Neuer Beleg' : 'Beleg bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.neu && widget.beleg.bild != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Der Tiger hat den Bon gelesen. Bitte prüfe die Angaben.',
                  style: TextStyle(color: PT.grau)),
            ),
          TextField(
            controller: _haendler,
            decoration: feld(labelText: 'Händler oder Produkt'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _betrag,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Betrag', suffixText: '€'),
          ),
          const SizedBox(height: 12),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: const Text('Kaufdatum'),
              subtitle: Text(datumLang(_datum)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final d = await datumWaehlen(context, start: _datum);
                if (d != null) setState(() => _datum = d);
              },
            ),
          ),
          const Text('Garantie', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const [0, 12, 24, 36, 60])
                ChoiceChip(
                  label: Text(m == 0 ? 'Keine' : '${m ~/ 12} ${m == 12 ? 'Jahr' : 'Jahre'}'),
                  selected: _garantie == m,
                  onSelected: (_) => setState(() => _garantie = m),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Gesetzliche Gewährleistung beim Händler: meist 2 Jahre.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
          const SizedBox(height: 16),
          const Text('Für die Steuer', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          PTKarte(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _steuer,
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Nicht steuerlich relevant')),
                  for (final s in steuerKategorien)
                    DropdownMenuItem<String?>(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _steuer = v),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notiz,
            decoration: feld(labelText: 'Notiz (optional)'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _speichern, child: const Text('Speichern')),
        ),
      ),
    );
  }
}
