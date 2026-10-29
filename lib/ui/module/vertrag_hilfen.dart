import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/vertrag_logik.dart';
import '../../logic/vorlagen.dart';
import '../app.dart';
import '../haushalt/haushalt.dart';
import '../theme.dart';
import '../vorlage_screen.dart';
import '../widgets/common.dart';

double? _zahl(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim());

/// Schadensmeldung: Checkliste der Unterlagen und fertiger Meldebrief.
class SchadenScreen extends StatefulWidget {
  const SchadenScreen({super.key, required this.vertrag});

  final Vertrag vertrag;

  @override
  State<SchadenScreen> createState() => _SchadenScreenState();
}

class _SchadenScreenState extends State<SchadenScreen> {
  final _was = TextEditingController();
  final _wo = TextEditingController();
  final _hoehe = TextEditingController();
  final _az = TextEditingController();
  DateTime? _wann;

  @override
  void dispose() {
    for (final c in [_was, _wo, _hoehe, _az]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = widget.vertrag;
    final liste = schadenUnterlagen(v.versicherungsArt);
    return Scaffold(
      appBar: AppBar(title: const Text('Schaden melden')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const PTKarte(
            farbe: PT.gelbHell,
            child: Text('Melde Schäden so schnell wie möglich. Viele Versicherungen verlangen eine „unverzügliche“ Meldung – '
                'wer zu lange wartet, riskiert die Leistung.'),
          ),
          const Abschnitt('Diese Unterlagen brauchst du'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < liste.length; i++)
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: store.checklisten['schaden:${v.id}:$i'] == true,
                  title: Text(liste[i]),
                  onChanged: (x) => store.checklistePunkt('schaden:${v.id}:$i', x ?? false),
                ),
            ]),
          ),
          if (v.versicherungsArt == 'Hausrat')
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventarScreen())),
              icon: const Icon(Icons.chair_outlined),
              label: const Text('Inventarliste öffnen'),
            ),
          const Abschnitt('Was ist passiert?'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_wann == null ? 'Wann? (tippen)' : 'Am ${datumKurz(_wann!)}'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await datumWaehlen(context, start: _wann);
              if (d != null) setState(() => _wann = d);
            },
          ),
          TextField(controller: _wo, decoration: feld(labelText: 'Wo?')),
          const SizedBox(height: 12),
          TextField(
              controller: _was,
              minLines: 3,
              maxLines: 6,
              decoration: feld(labelText: 'Was ist passiert?', hintText: 'Kurz und sachlich, ohne Schuld einzugestehen')),
          const SizedBox(height: 12),
          TextField(
              controller: _hoehe,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: feld(labelText: 'Geschätzte Schadenshöhe (optional)', suffixText: '€')),
          const SizedBox(height: 12),
          TextField(controller: _az, decoration: feld(labelText: 'Polizei-Aktenzeichen (falls vorhanden)')),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.edit_note),
            label: const Text('Schadensmeldung erstellen'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VorlageScreen(
                titel: 'Schadensmeldung',
                text: schadenText(v, store.profil,
                    was: _was.text, wann: _wann, wo: _wo.text.trim(), hoehe: _zahl(_hoehe.text), aktenzeichen: _az.text.trim()),
              ),
            )),
          ),
        ),
      ),
    );
  }
}

/// Anbieterwechsel Schritt für Schritt.
class WechselScreen extends StatelessWidget {
  const WechselScreen({super.key, required this.vertrag});

  final Vertrag vertrag;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final schritte = wechselSchritte(vertrag);
    return Scaffold(
      appBar: AppBar(title: Text('${vertrag.anbieter} wechseln')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (var i = 0; i < schritte.length; i++)
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: store.checklisten['wechsel:${vertrag.id}:$i'] == true,
                  title: Text('${i + 1}. ${schritte[i]}'),
                  onChanged: (x) => store.checklistePunkt('wechsel:${vertrag.id}:$i', x ?? false),
                ),
            ]),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => TarifVergleichScreen(aktuell: vertrag))),
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Tarife vergleichen'),
          ),
          const SizedBox(height: 8),
          if (vertrag.art != 'Strom' && vertrag.art != 'Gas')
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VorlageScreen(
                  titel: 'Kündigung',
                  text: kuendigungText(vertrag, store.profil, zum: kuendigungsInfo(vertrag).endetAm),
                ),
              )),
              icon: const Icon(Icons.edit_note),
              label: const Text('Kündigung schreiben'),
            ),
        ],
      ),
    );
  }
}

class _TarifFelder {
  final name = TextEditingController();
  final monat = TextEditingController();
  final einmalig = TextEditingController();
  final bonus = TextEditingController();

  void dispose() {
    for (final c in [name, monat, einmalig, bonus]) {
      c.dispose();
    }
  }

  Tarif? get tarif {
    final m = _zahl(monat.text);
    if (m == null) return null;
    return Tarif(
        name: name.text.trim().isEmpty ? 'Angebot' : name.text.trim(),
        monat: m,
        einmalig: _zahl(einmalig.text) ?? 0,
        bonus: _zahl(bonus.text) ?? 0);
  }
}

/// Vergleicht bis zu drei Angebote mit dem aktuellen Vertrag über 24 Monate.
class TarifVergleichScreen extends StatefulWidget {
  const TarifVergleichScreen({super.key, this.aktuell});

  final Vertrag? aktuell;

  @override
  State<TarifVergleichScreen> createState() => _TarifVergleichScreenState();
}

class _TarifVergleichScreenState extends State<TarifVergleichScreen> {
  final _felder = [_TarifFelder(), _TarifFelder(), _TarifFelder()];
  int _monate = 24;

  @override
  void dispose() {
    for (final f in _felder) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.aktuell;
    final tarife = [
      if (a?.kostenMonat != null) Tarif(name: '${a!.anbieter} (aktuell)', monat: a.kostenMonat!),
      for (final f in _felder)
        if (f.tarif != null) f.tarif!,
    ];
    final ergebnis = tarifeVergleichen(tarife, monate: _monate);
    return Scaffold(
      appBar: AppBar(title: const Text('Tarife vergleichen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Trag bis zu drei Angebote ein. Der Tiger rechnet die Gesamtkosten inklusive Anschlussgebühr und Bonus.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final m in const [12, 24])
              ChoiceChip(label: Text('über $m Monate'), selected: _monate == m, onSelected: (_) => setState(() => _monate = m)),
          ]),
          for (var i = 0; i < _felder.length; i++)
            PTKarte(
              child: Column(children: [
                TextField(
                    controller: _felder[i].name,
                    decoration: feld(labelText: 'Angebot ${i + 1}', hintText: 'Anbieter und Tarif'),
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                        controller: _felder[i].monat,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: feld(labelText: 'pro Monat', suffixText: '€'),
                        onChanged: (_) => setState(() {})),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                        controller: _felder[i].einmalig,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: feld(labelText: 'einmalig', suffixText: '€'),
                        onChanged: (_) => setState(() {})),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                        controller: _felder[i].bonus,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: feld(labelText: 'Bonus', suffixText: '€'),
                        onChanged: (_) => setState(() {})),
                  ),
                ]),
              ]),
            ),
          if (ergebnis.length > 1) ...[
            const Abschnitt('Ergebnis'),
            for (var i = 0; i < ergebnis.length; i++)
              PTKarte(
                farbe: i == 0 ? PT.gruenHell : Colors.white,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ergebnis[i].tarif.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('effektiv ${euro(ergebnis[i].effektivMonat)} im Monat',
                          style: const TextStyle(color: PT.grau, fontSize: 13)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(euro(ergebnis[i].gesamt), style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (i > 0)
                      Text('+${euro(ergebnis[i].gesamt - ergebnis[0].gesamt)}',
                          style: const TextStyle(color: PT.rot, fontSize: 12)),
                  ]),
                ]),
              ),
          ],
          const SizedBox(height: 8),
          const Text('Nur ein Preisvergleich. Achte auch auf Leistung, Laufzeit und Preisgarantie.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}
