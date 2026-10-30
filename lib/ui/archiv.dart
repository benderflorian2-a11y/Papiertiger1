import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/brief_analyse.dart';
import '../logic/export.dart';
import '../logic/ordnung.dart';
import 'akten.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'theme.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';

enum _Ansicht { ordner, vorgaenge, alle }

class ArchivScreen extends StatefulWidget {
  const ArchivScreen({super.key, this.startSuche = ''});

  /// Suchbegriff beim Öffnen (z. B. per Sprachbefehl).
  final String startSuche;

  @override
  State<ArchivScreen> createState() => _ArchivScreenState();
}

class _ArchivScreenState extends State<ArchivScreen> {
  late String _suche = widget.startSuche;
  late final _sucheFeld = TextEditingController(text: widget.startSuche);
  _Ansicht _ansicht = _Ansicht.ordner;
  String? _person;

  @override
  void dispose() {
    _sucheFeld.dispose();
    super.dispose();
  }

  void _oeffne(Widget seite) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => seite));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _suche.toLowerCase().trim();
    final personen = {for (final b in store.briefe) if (b.person != null) b.person!}.toList()..sort();
    if (_person != null && !personen.contains(_person)) _person = null;
    final suchtreffer = store.briefe.where((b) {
      if (_person != null && b.person != _person) return false;
      if (q.isEmpty) return true;
      return b.text.toLowerCase().contains(q) ||
          titelVon(b).toLowerCase().contains(q) ||
          (b.absenderName ?? '').toLowerCase().contains(q) ||
          kategorieFuer(b.kategorie).name.toLowerCase().contains(q) ||
          (b.aktenzeichen ?? '').toLowerCase().contains(q) ||
          (b.person ?? '').toLowerCase().contains(q);
    }).toList();
    final ansicht = q.isNotEmpty || _person != null ? _Ansicht.alle : _ansicht;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archiv'),
        actions: [
          if (store.briefe.isNotEmpty)
            IconButton(
              tooltip: 'Als Tabelle exportieren',
              icon: const Icon(Icons.table_view_outlined),
              onPressed: () async {
                try {
                  final datei = await archivAlsTabelle(store.briefe);
                  await dateiTeilen(datei.path);
                } catch (e) {
                  if (context.mounted) zeigeHinweis(context, 'Export fehlgeschlagen: $e');
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextField(
            controller: _sucheFeld,
            decoration: feld(prefixIcon: const Icon(Icons.search), hintText: 'Alle Dokumente durchsuchen'),
            onChanged: (v) => setState(() => _suche = v),
          ),
          if (personen.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final p in personen)
                FilterChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(p),
                  selected: _person == p,
                  onSelected: (an) => setState(() => _person = an ? p : null),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          if (q.isEmpty && _person == null)
            SegmentedButton<_Ansicht>(
              segments: const [
                ButtonSegment(value: _Ansicht.ordner, label: Text('Ordner'), icon: Icon(Icons.folder_outlined)),
                ButtonSegment(value: _Ansicht.vorgaenge, label: Text('Vorgänge'), icon: Icon(Icons.layers_outlined)),
                ButtonSegment(value: _Ansicht.alle, label: Text('Alle'), icon: Icon(Icons.list)),
              ],
              selected: {_ansicht},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _ansicht = s.first),
            ),
          const SizedBox(height: 12),
          if (store.briefe.isEmpty)
            const LeerHinweis(
                icon: Icons.inventory_2_outlined,
                text: 'Hier landen alle Dokumente, die du scannst oder als PDF importierst.')
          else
            ...switch (ansicht) {
              _Ansicht.ordner => _ordner(store.briefe),
              _Ansicht.vorgaenge => _vorgaenge(store.briefe),
              _Ansicht.alle => _alle(suchtreffer),
            },
        ],
      ),
    );
  }

  List<Widget> _ordner(List<Brief> briefe) {
    final anzahl = <String, int>{};
    final dringend = <String, int>{};
    for (final b in briefe) {
      final k = ordnerFuer(b).key;
      anzahl[k] = (anzahl[k] ?? 0) + 1;
      if (dringlichkeit(b) == Dringlichkeit.hoch) dringend[k] = (dringend[k] ?? 0) + 1;
    }
    return [
      for (final o in alleOrdner)
        if ((anzahl[o.key] ?? 0) > 0)
          PTKarte(
            padding: const EdgeInsets.all(14),
            onTap: () => _oeffne(OrdnerScreen(ordnerKey: o.key)),
            child: Row(
              children: [
                IconKachel(ordnerIcon(o.key)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(o.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                if ((dringend[o.key] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Etikett('${dringend[o.key]} dringend', farbe: PT.rot, hintergrund: PT.rotHell),
                  ),
                Text('${anzahl[o.key]}', style: const TextStyle(color: PT.grau, fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),
    ];
  }

  List<Widget> _vorgaenge(List<Brief> briefe) {
    final akten = aktenBilden(briefe);
    return [
      for (final a in akten)
        PTKarte(
          padding: const EdgeInsets.all(14),
          onTap: a.briefe.length == 1
              ? () => _oeffne(BriefDetail(briefId: a.neuester.id))
              : () => _oeffne(AkteScreen(schluessel: a.schluessel)),
          child: Row(
            children: [
              IconKachel(a.briefe.length > 1 ? Icons.layers_outlined : kategorieIcon(a.neuester.kategorie)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.titel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      '${a.briefe.length} ${a.briefe.length == 1 ? 'Dokument' : 'Dokumente'} · '
                      'zuletzt ${datumKurz(a.neuester.briefDatum ?? a.neuester.erstellt)}',
                      style: const TextStyle(color: PT.grau, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PT.grau),
            ],
          ),
        ),
    ];
  }

  List<Widget> _alle(List<Brief> treffer) {
    if (treffer.isEmpty) {
      return const [LeerHinweis(icon: Icons.search_off, text: 'Nichts gefunden.')];
    }
    return [
      for (final b in treffer) BriefZeile(brief: b, onTap: () => _oeffne(BriefDetail(briefId: b.id))),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('${treffer.length} ${treffer.length == 1 ? 'Dokument' : 'Dokumente'}',
            textAlign: TextAlign.center, style: const TextStyle(color: PT.grau, fontSize: 13)),
      ),
    ];
  }

}
