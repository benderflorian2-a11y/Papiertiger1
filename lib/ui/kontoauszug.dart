import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/rechnungen.dart';
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

/// Auswahl der Quelle: Kontoauszüge aus dem Archiv und/oder eingefügter Text.
mixin AuszugQuelle<T extends StatefulWidget> on State<T> {
  final Set<String> gewaehlt = {};
  String eingefuegt = '';

  bool get hatQuelle => gewaehlt.isNotEmpty || eingefuegt.isNotEmpty;

  String auszugText(List<Brief> briefe) =>
      [for (final b in briefe) if (gewaehlt.contains(b.id)) b.text, eingefuegt].join('\n');

  Future<void> umsaetzeEinfuegen() async {
    final c = TextEditingController(text: eingefuegt);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Umsätze einfügen'),
        content: TextField(
          controller: c,
          minLines: 8,
          maxLines: 14,
          decoration: feld(hintText: 'Aus dem Online-Banking kopieren: Datum, Name, Betrag je Zeile'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) setState(() => eingefuegt = c.text);
    c.dispose();
  }

  List<Widget> quelleAuswahl(List<Brief> briefe) {
    final auszuege = briefe
        .where((b) => RegExp(r'kontoauszug|umsätze|umsatzliste|kontostand', caseSensitive: false)
            .hasMatch('${b.titel ?? ''} ${b.kiArt ?? ''} ${b.text.length > 600 ? b.text.substring(0, 600) : b.text}'))
        .toList();
    return [
      const Abschnitt('Kontoauszüge'),
      if (auszuege.isEmpty)
        const Text(
            'Im Archiv ist noch kein Kontoauszug. Importiere das PDF über „Datei importieren“ '
            'oder teile es aus der Banking-App mit dem Papiertiger.',
            style: TextStyle(fontSize: 13)),
      for (final b in auszuege)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: gewaehlt.contains(b.id),
          title: Text(titelVon(b)),
          subtitle: Text(datumKurz(b.briefDatum ?? b.erstellt)),
          onChanged: (v) => setState(() => v == true ? gewaehlt.add(b.id) : gewaehlt.remove(b.id)),
        ),
      TextButton.icon(
        onPressed: umsaetzeEinfuegen,
        icon: const Icon(Icons.content_paste),
        label: Text(eingefuegt.isEmpty ? 'Umsätze einfügen' : 'Eingefügte Umsätze bearbeiten'),
      ),
    ];
  }
}

class _KontoauszugScreenState extends State<KontoauszugScreen> with AuszugQuelle<KontoauszugScreen> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final buchungen = abbuchungenLesen(auszugText(store.briefe));
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
          ...quelleAuswahl(store.briefe),
          if (hatQuelle) ...[
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


/// Zahlungseingänge aus dem Kontoauszug offenen Rechnungen zuordnen. Du bestätigst jede Zuordnung.
class ZahlungseingaengeScreen extends StatefulWidget {
  const ZahlungseingaengeScreen({super.key});

  @override
  State<ZahlungseingaengeScreen> createState() => _ZahlungseingaengeScreenState();
}

class _ZahlungseingaengeScreenState extends State<ZahlungseingaengeScreen> with AuszugQuelle<ZahlungseingaengeScreen> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final eingaenge = gutschriftenLesen(auszugText(store.briefe));
    final treffer = zahlungenZuordnen(store.rechnungen, eingaenge, kleinunternehmer: store.firma.kleinunternehmer);
    final offen = store.rechnungen.where(istOffen).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Zahlungseingänge zuordnen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('${anzahl(offen, 'offene Rechnung', 'offene Rechnungen')}. Der Tiger sucht im Kontoauszug nach der Rechnungsnummer oder dem genauen Betrag. '
              'Du bestätigst jede Zahlung selbst.',
              style: const TextStyle(color: PT.grau)),
          ...quelleAuswahl(store.briefe),
          if (hatQuelle) ...[
            Text('${eingaenge.length} Zahlungseingänge gelesen', style: const TextStyle(color: PT.grau, fontSize: 13)),
            Abschnitt(treffer.isEmpty ? 'Keine passenden Zahlungen' : 'Passt zusammen'),
            for (final (r, g, grund) in treffer)
              PTKarte(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rechnung ${r.nummer} · ${store.kundeMitId(r.kundeId)?.name ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${euro(g.betrag)} am ${datumKurz(g.datum)} von ${g.von} – $grund',
                      style: const TextStyle(color: PT.grau, fontSize: 13)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () {
                        r.bezahltAm = g.datum;
                        store.geaendert();
                        zeigeHinweis(context, 'Rechnung ${r.nummer} als bezahlt vermerkt');
                      },
                      child: const Text('Als bezahlt vermerken'),
                    ),
                  ),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}
