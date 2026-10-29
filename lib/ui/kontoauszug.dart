import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/kontoauszug.dart';
import '../logic/ordnung.dart';
import 'app.dart';
import 'module/vertraege.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Kontoauszug auswerten: aus einem importierten PDF oder eingefügtem Text.
/// Es gibt keinen Bankzugang – nur das, was du selbst hineingibst.
class KontoauszugScreen extends StatefulWidget {
  const KontoauszugScreen({super.key});

  @override
  State<KontoauszugScreen> createState() => _KontoauszugScreenState();
}

class _KontoauszugScreenState extends State<KontoauszugScreen> {
  final Set<String> _gewaehlt = {};
  String _eingefuegt = '';

  String _text(List<Brief> briefe) =>
      [for (final b in briefe) if (_gewaehlt.contains(b.id)) b.text, _eingefuegt].join('\n');

  Future<void> _einfuegen() async {
    final c = TextEditingController(text: _eingefuegt);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Umsätze einfügen'),
        content: TextField(
          controller: c,
          minLines: 8,
          maxLines: 14,
          decoration: feld(hintText: 'Aus dem Online-Banking kopieren: Datum, Empfänger, Betrag je Zeile'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) setState(() => _eingefuegt = c.text);
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final auszuege = store.briefe
        .where((b) => RegExp(r'kontoauszug|umsätze|umsatzliste|kontostand', caseSensitive: false).hasMatch('${b.titel ?? ''} ${b.kiArt ?? ''} ${b.text.length > 600 ? b.text.substring(0, 600) : b.text}'))
        .toList();
    final buchungen = abbuchungenLesen(_text(store.briefe));
    final wieder = wiederkehrendeAbbuchungen(buchungen, vertraege: store.vertraege);
    final doppelt = doppelteAbbuchungen(buchungen);
    final proMonat = wieder.fold(0.0, (s, w) => s + w.proMonat);
    return Scaffold(
      appBar: AppBar(title: const Text('Kontoauszug prüfen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
            'Wähle Kontoauszüge aus deinem Archiv (mehrere Monate sind besser) oder füge Umsätze aus dem '
            'Online-Banking ein. Der Tiger liest nur – er hat keinen Zugang zu deinem Konto.',
            style: TextStyle(color: PT.grau),
          ),
          const Abschnitt('Kontoauszüge'),
          if (auszuege.isEmpty)
            const Text('Im Archiv ist noch kein Kontoauszug. Importiere das PDF über „Datei importieren“ '
                'oder teile es aus der Banking-App mit dem Papiertiger.',
                style: TextStyle(fontSize: 13)),
          for (final b in auszuege)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _gewaehlt.contains(b.id),
              title: Text(titelVon(b)),
              subtitle: Text(datumKurz(b.briefDatum ?? b.erstellt)),
              onChanged: (v) => setState(() => v == true ? _gewaehlt.add(b.id) : _gewaehlt.remove(b.id)),
            ),
          TextButton.icon(
            onPressed: _einfuegen,
            icon: const Icon(Icons.content_paste),
            label: Text(_eingefuegt.isEmpty ? 'Umsätze einfügen' : 'Eingefügte Umsätze bearbeiten'),
          ),
          if (_gewaehlt.isNotEmpty || _eingefuegt.isNotEmpty) ...[
            Text('${buchungen.length} Abbuchungen gelesen', style: const TextStyle(color: PT.grau, fontSize: 13)),
            if (doppelt.isNotEmpty) ...[
              const Abschnitt('Vielleicht doppelt abgebucht'),
              for (final (a, b) in doppelt)
                PTKarte(
                  farbe: PT.gelbHell,
                  child: Text('${a.empfaenger}: ${euro(a.betrag)} am ${datumKurz(a.datum)} und ${datumKurz(b.datum)}. '
                      'Prüfe das – eine doppelte Lastschrift kannst du bei der Bank zurückgeben lassen.'),
                ),
            ],
            Abschnitt(wieder.isEmpty ? 'Regelmäßige Abbuchungen' : 'Regelmäßig: ca. ${euro(proMonat)} im Monat'),
            if (wieder.isEmpty)
              const Text('Nichts Regelmäßiges gefunden. Dafür braucht der Tiger mindestens zwei Monate.',
                  style: TextStyle(fontSize: 13)),
            for (final w in wieder)
              PTKarte(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.empfaenger, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${euro(w.letzterBetrag)} ${w.rhythmus} · ${w.buchungen.length}× gesehen'
                        '${w.preisGeaendert ? ' · Betrag hat sich geändert' : ''}',
                        style: TextStyle(color: w.preisGeaendert ? PT.orangeDunkel : PT.grau, fontSize: 13),
                      ),
                      if (w.vertrag != null)
                        Text('Vertrag erfasst: ${w.vertrag!.anbieter}', style: const TextStyle(color: PT.gruen, fontSize: 13)),
                    ]),
                  ),
                  if (w.vertrag == null)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => VertragFormular(
                          vorschlag: Vertrag(
                            id: neueId(),
                            anbieter: w.empfaenger,
                            art: 'Sonstiges',
                            beginn: w.buchungen.first.datum,
                            kostenMonat: w.rhythmusMonate > 0 ? w.letzterBetrag / w.rhythmusMonate : null,
                            zahlweiseMonate: w.rhythmusMonate > 0 ? w.rhythmusMonate : 1,
                          ),
                        ),
                      )),
                      child: const Text('Als Vertrag'),
                    ),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}
