import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/vertrag_logik.dart';
import '../../logic/vorlagen.dart';
import '../app.dart';
import '../theme.dart';
import '../vorlage_screen.dart';
import '../widgets/common.dart';

Vertrag? _finde(List<Vertrag> l, String id) {
  for (final v in l) {
    if (v.id == id) return v;
  }
  return null;
}

class VertraegeScreen extends StatelessWidget {
  const VertraegeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final aktiv = store.vertraege.where((v) => !v.gekuendigt).toList()
      ..sort((a, b) =>
          kuendigungsInfo(a).kuendigenBis.compareTo(kuendigungsInfo(b).kuendigenBis));
    final gekuendigt = store.vertraege.where((v) => v.gekuendigt).toList();
    final summe = aktiv.fold<double>(0, (s, v) => s + (v.kostenMonat ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Verträge & Abos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const VertragFormular())),
        icon: const Icon(Icons.add),
        label: const Text('Vertrag'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (store.vertraege.isEmpty)
            const LeerHinweis(
                icon: Icons.description_outlined,
                text:
                    'Trag deine Verträge ein – Handy, Strom, Fitnessstudio. Der Tiger sagt dir, bis wann du kündigen musst.')
          else ...[
            if (summe > 0)
              PTKarte(
                farbe: PT.orangeHell,
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: PT.orangeDunkel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Laufende Kosten: ${euro(summe)} pro Monat',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            for (final v in aktiv) _VertragZeile(v),
            if (gekuendigt.isNotEmpty) ...[
              const Abschnitt('Gekündigt'),
              for (final v in gekuendigt) _VertragZeile(v),
            ],
          ],
        ],
      ),
    );
  }
}

class _VertragZeile extends StatelessWidget {
  const _VertragZeile(this.v);

  final Vertrag v;

  @override
  Widget build(BuildContext context) {
    final info = kuendigungsInfo(v);
    return PTKarte(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => VertragDetail(vertragId: v.id))),
      child: Row(
        children: [
          const IconKachel(Icons.description_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.anbieter,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(
                  v.gekuendigt
                      ? '${v.art} · gekündigt'
                      : '${v.art} · kündigen bis ${datumKurz(info.kuendigenBis)}',
                  style: const TextStyle(color: PT.grau, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!v.gekuendigt) FristEtikett(info.kuendigenBis),
        ],
      ),
    );
  }
}

class VertragDetail extends StatelessWidget {
  const VertragDetail({super.key, required this.vertragId});

  final String vertragId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = _finde(store.vertraege, vertragId);
    if (v == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const LeerHinweis(icon: Icons.description_outlined, text: 'Gelöscht.'));
    }
    final info = kuendigungsInfo(v);
    return Scaffold(
      appBar: AppBar(
        title: Text(v.anbieter),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => VertragFormular(vertrag: v))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Löschen',
            onPressed: () {
              Navigator.of(context).pop();
              store.vertragLoeschen(v);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PTKarte(
            farbe: v.gekuendigt ? PT.gruenHell : PT.orangeHell,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.gekuendigt ? 'Gekündigt' : 'Spätestens kündigen bis',
                  style: const TextStyle(color: PT.grau),
                ),
                const SizedBox(height: 4),
                if (!v.gekuendigt)
                  Text(datumLang(info.kuendigenBis),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Der Vertrag endet dann am ${datumLang(info.endetAm)}.'),
                const SizedBox(height: 8),
                Text(info.hinweis, style: const TextStyle(color: PT.grau, fontSize: 13)),
              ],
            ),
          ),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(title: const Text('Art'), trailing: Text(v.art)),
                ListTile(title: const Text('Beginn'), trailing: Text(datumKurz(v.beginn))),
                ListTile(
                    title: const Text('Mindestlaufzeit'),
                    trailing: Text(v.laufzeitMonate == 0 ? 'keine' : '${v.laufzeitMonate} Monate')),
                ListTile(
                    title: const Text('Kündigungsfrist'),
                    trailing: Text('${v.fristWert} ${v.fristInWochen ? 'Wochen' : (v.fristWert == 1 ? 'Monat' : 'Monate')}')),
                if (v.kostenMonat != null)
                  ListTile(title: const Text('Kosten'), trailing: Text('${euro(v.kostenMonat!)} / Monat')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VorlageScreen(
                titel: 'Kündigung',
                text: kuendigungText(v, store.profil, zum: info.endetAm),
              ),
            )),
            icon: const Icon(Icons.edit_note),
            label: const Text('Kündigungsschreiben erstellen'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              v.gekuendigt = !v.gekuendigt;
              store.geaendert();
            },
            child: Text(v.gekuendigt ? 'Doch nicht gekündigt' : 'Als gekündigt markieren'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Die Berechnung folgt den üblichen Regeln. Maßgeblich sind immer die Bedingungen in deinem Vertrag.',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class VertragFormular extends StatefulWidget {
  const VertragFormular({super.key, this.vertrag});

  final Vertrag? vertrag;

  @override
  State<VertragFormular> createState() => _VertragFormularState();
}

class _VertragFormularState extends State<VertragFormular> {
  late final _anbieter = TextEditingController(text: widget.vertrag?.anbieter ?? '');
  late final _kosten = TextEditingController(
      text: widget.vertrag?.kostenMonat?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
  late String _art = widget.vertrag?.art ?? vertragsArten.first;
  late DateTime _beginn = widget.vertrag?.beginn ?? DateTime.now();
  late int _laufzeit = widget.vertrag?.laufzeitMonate ?? 24;
  late int _fristWert = widget.vertrag?.fristWert ?? 1;
  late bool _wochen = widget.vertrag?.fristInWochen ?? false;

  @override
  void dispose() {
    _anbieter.dispose();
    _kosten.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    if (_anbieter.text.trim().isEmpty) {
      zeigeHinweis(context, 'Bitte einen Anbieter eintragen.');
      return;
    }
    final store = StoreScope.of(context);
    final v = widget.vertrag ??
        Vertrag(id: neueId(), anbieter: '', art: _art, beginn: _beginn);
    v
      ..anbieter = _anbieter.text.trim()
      ..art = _art
      ..beginn = _beginn
      ..laufzeitMonate = _laufzeit
      ..fristWert = _fristWert
      ..fristInWochen = _wochen
      ..kostenMonat = double.tryParse(_kosten.text.replaceAll('.', '').replaceAll(',', '.'));
    await store.vertragSpeichern(v);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.vertrag == null ? 'Neuer Vertrag' : 'Vertrag bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _anbieter,
            textCapitalization: TextCapitalization.words,
            decoration: feld(labelText: 'Anbieter', hintText: 'z. B. Vodafone'),
          ),
          const SizedBox(height: 16),
          const Text('Art', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in vertragsArten)
                ChoiceChip(
                  label: Text(a),
                  selected: _art == a,
                  onSelected: (_) => setState(() => _art = a),
                ),
            ],
          ),
          const SizedBox(height: 16),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: const Text('Vertragsbeginn'),
              subtitle: Text(datumLang(_beginn)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final d = await datumWaehlen(context, start: _beginn);
                if (d != null) setState(() => _beginn = d);
              },
            ),
          ),
          const Text('Mindestlaufzeit', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [0, 1, 12, 24])
                ChoiceChip(
                  label: Text(m == 0 ? 'Keine' : '$m ${m == 1 ? 'Monat' : 'Monate'}'),
                  selected: _laufzeit == m,
                  onSelected: (_) => setState(() => _laufzeit = m),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Kündigungsfrist', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in const [(2, true), (4, true), (1, false), (3, false)])
                ChoiceChip(
                  label: Text('${f.$1} ${f.$2 ? 'Wochen' : (f.$1 == 1 ? 'Monat' : 'Monate')}'),
                  selected: _fristWert == f.$1 && _wochen == f.$2,
                  onSelected: (_) => setState(() {
                    _fristWert = f.$1;
                    _wochen = f.$2;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _kosten,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Kosten pro Monat (optional)', suffixText: '€'),
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
