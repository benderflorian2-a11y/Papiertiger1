import 'package:flutter/material.dart';

import '../../data/alltag.dart';
import '../../data/models.dart';
import '../../logic/alltag.dart';
import '../../logic/export.dart';
import '../../logic/ordnung.dart';
import '../app.dart';
import '../brief_detail.dart';
import '../ki_text.dart';
import '../termine.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<String?> _eingabe(BuildContext context, String titel, {String start = '', String? hint, int zeilen = 1}) async {
  final c = TextEditingController(text: start);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titel),
      content: TextField(
          controller: c, autofocus: true, minLines: zeilen, maxLines: zeilen == 1 ? 1 : 12, decoration: feld(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('OK')),
      ],
    ),
  );
  final t = c.text.trim();
  c.dispose();
  return ok == true && t.isNotEmpty ? t : null;
}

// ---------------------------------------------------------------- Einkauf

class EinkaufScreen extends StatelessWidget {
  const EinkaufScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = store.alltag.einkauf;
    final gruppen = einkaufNachKategorie(l);
    final erledigt = l.where((e) => e.erledigt).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufsliste'),
        actions: [
          IconButton(
              tooltip: 'Teilen', icon: const Icon(Icons.share_outlined), onPressed: () => textTeilen(einkaufAlsText(l))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final t = await _eingabe(context, 'Hinzufügen', hint: 'z. B. Milch');
          if (t == null) return;
          l.addAll(einkaufAusText(t, vorhanden: l));
          await store.geaendert();
        },
        icon: const Icon(Icons.add),
        label: const Text('Artikel'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(
              avatar: const Icon(Icons.content_paste, size: 18),
              label: const Text('Aus Rezept oder Nachricht'),
              onPressed: () async {
                final t = await _eingabe(context, 'Text einfügen',
                    hint: 'Zutatenliste, WhatsApp-Nachricht oder Notiz – eine Zeile pro Artikel', zeilen: 8);
                if (t == null) return;
                final neu = einkaufAusText(t, vorhanden: l);
                l.addAll(neu);
                await store.geaendert();
                if (context.mounted) zeigeHinweis(context, '${neu.length} Artikel übernommen');
              },
            ),
            if (erledigt.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.done_all, size: 18),
                label: const Text('Einkauf abschließen'),
                onPressed: () {
                  einkaufAbschliessen(l);
                  store.geaendert();
                },
              ),
          ]),
          if (gruppen.isEmpty && erledigt.isEmpty)
            const LeerHinweis(icon: Icons.shopping_cart_outlined, text: 'Die Liste ist leer. Füge Artikel hinzu oder füge ein Rezept ein.'),
          for (final (k, items) in gruppen) ...[
            Abschnitt(k),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(children: [
                for (final e in items)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: e.erledigt,
                    title: Text(e.text),
                    secondary: IconButton(
                      tooltip: e.immer ? 'Wiederkehrend' : 'Immer wieder kaufen',
                      icon: Icon(e.immer ? Icons.repeat_on : Icons.repeat, size: 20, color: e.immer ? PT.orangeDunkel : PT.grau),
                      onPressed: () {
                        e.immer = !e.immer;
                        store.geaendert();
                      },
                    ),
                    onChanged: (v) {
                      e.erledigt = v ?? false;
                      store.geaendert();
                    },
                  ),
              ]),
            ),
          ],
          if (erledigt.isNotEmpty) ...[
            Abschnitt('Im Wagen (${erledigt.length})'),
            for (final e in erledigt)
              ListTile(
                dense: true,
                leading: const Icon(Icons.check, color: PT.gruen),
                title: Text(e.text, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                onTap: () {
                  e.erledigt = false;
                  store.geaendert();
                },
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Vorräte

class VorraeteScreen extends StatelessWidget {
  const VorraeteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = [...store.alltag.vorraete]
      ..sort((a, b) => (a.ablauf ?? DateTime(9999)).compareTo(b.ablauf ?? DateTime(9999)));
    final bald = laeuftBaldAb(l, heute: DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Vorräte')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _vorrat(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Vorrat'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (bald.isNotEmpty)
            PTKarte(
              farbe: PT.gelbHell,
              child: Text('Bald ablaufen: ${bald.map((v) => v.name).join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          if (l.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => KiTextScreen(
                  titel: 'Was kann ich kochen?',
                  anfrage: rezeptAnfrage(l, heute: DateTime.now()),
                  hinweis: 'Rezeptideen der KI. Achte auf Allergien und Haltbarkeit.',
                ),
              )),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Rezepte aus meinen Vorräten'),
            ),
          if (l.isEmpty)
            const LeerHinweis(
                icon: Icons.kitchen_outlined, text: 'Trag ein, was du im Kühlschrank und Vorrat hast – mit Haltbarkeitsdatum.'),
          for (final v in l)
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => _vorrat(context, v),
              child: Row(children: [
                Icon(
                    v.ort == 'Kühlschrank'
                        ? Icons.kitchen_outlined
                        : v.ort == 'Tiefkühler'
                            ? Icons.ac_unit
                            : Icons.inventory_2_outlined,
                    color: PT.orangeDunkel),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${v.name}${v.menge.isEmpty ? '' : ' · ${v.menge}'}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (v.ablauf != null) FristEtikett(v.ablauf!),
                IconButton(
                  tooltip: 'Aufgebraucht – auf die Einkaufsliste',
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  onPressed: () {
                    store.alltag.vorraete.remove(v);
                    store.alltag.einkauf.add(Einkauf(text: v.name));
                    store.geaendert();
                  },
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Future<void> _vorrat(BuildContext context, Vorrat? v) async {
    final store = StoreScope.of(context);
    final name = TextEditingController(text: v?.name ?? '');
    final menge = TextEditingController(text: v?.menge ?? '');
    var ort = v?.ort ?? 'Vorrat';
    DateTime? ablauf = v?.ablauf;
    final ok = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text(v == null ? 'Neuer Vorrat' : 'Vorrat'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: v == null, decoration: feld(labelText: 'Was?')),
              const SizedBox(height: 8),
              TextField(controller: menge, decoration: feld(labelText: 'Menge (optional)')),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final o in const ['Kühlschrank', 'Tiefkühler', 'Vorrat'])
                  ChoiceChip(label: Text(o), selected: ort == o, onSelected: (_) => setze(() => ort = o)),
              ]),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ablauf == null ? 'Haltbar bis (optional)' : 'Haltbar bis ${datumKurz(ablauf!)}'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final x = await datumWaehlen(d, start: ablauf ?? DateTime.now());
                  if (x != null) setze(() => ablauf = x);
                },
              ),
            ]),
          ),
          actions: [
            if (v != null) TextButton(onPressed: () => Navigator.pop(d, 'weg'), child: const Text('Löschen')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final n = name.text.trim(), m = menge.text.trim();
    name.dispose();
    menge.dispose();
    if (ok == 'weg' && v != null) {
      store.alltag.vorraete.remove(v);
    } else if (ok == 'ok' && n.isNotEmpty) {
      final x = v ?? Vorrat(name: n);
      x
        ..name = n
        ..menge = m
        ..ort = ort
        ..ablauf = ablauf;
      if (v == null) store.alltag.vorraete.add(x);
    } else {
      return;
    }
    await store.geaendert();
  }
}

// ---------------------------------------------------------------- Essensplan

class EssensplanScreen extends StatelessWidget {
  const EssensplanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plan = store.alltag.essensplan;
    return Scaffold(
      appBar: AppBar(title: const Text('Essensplan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          FilledButton.icon(
            onPressed: () async {
              final wunsch = await _eingabe(context, 'Wünsche für die Woche',
                  hint: 'z. B. vegetarisch, schnell, kindertauglich – oder einfach „egal“');
              if (wunsch == null || !context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => KiTextScreen(
                  titel: 'Essensplan',
                  anfrage: essensplanAnfrage(wunsch: wunsch, vorraete: store.alltag.vorraete),
                  uebernehmen: (
                    'Übernehmen',
                    (text) {
                      store.alltag.essensplan.addAll(essensplanLesen(text));
                      store.alltag.einkauf.addAll(einkaufAusEssensplan(text));
                      store.geaendert();
                    }
                  ),
                ),
              ));
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Woche mit KI planen'),
          ),
          const SizedBox(height: 8),
          for (var i = 1; i <= 7; i++)
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                title: Text(wochentage[i - 1], style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(plan['$i'] ?? 'noch frei – tippen'),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () async {
                  final t = await _eingabe(context, wochentage[i - 1], start: plan['$i'] ?? '');
                  if (t == null) return;
                  plan['$i'] = t;
                  await store.geaendert();
                },
              ),
            ),
          TextButton.icon(
            onPressed: () {
              plan.clear();
              store.geaendert();
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Woche leeren'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Haushaltsaufgaben

class HausaufgabenScreen extends StatelessWidget {
  const HausaufgabenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final heute = DateTime.now();
    final l = [...store.alltag.hausaufgaben]
      ..sort((a, b) => (naechstesMal(a) ?? DateTime(0)).compareTo(naechstesMal(b) ?? DateTime(0)));
    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben im Haushalt')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bearbeiten(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Aufgabe'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (l.isEmpty)
            const LeerHinweis(
                icon: Icons.cleaning_services_outlined,
                text: 'Müll rausbringen, Bad putzen, Wäsche … Trag ein, wer sich abwechselt – der Tiger sagt, wer dran ist.'),
          for (final a in l)
            PTKarte(
              farbe: hausaufgabeFaellig(a, heute: heute) ? PT.orangeHell : Colors.white,
              padding: const EdgeInsets.all(12),
              onTap: () => _bearbeiten(context, a),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.text, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        if (werIstDran(a) != null) 'dran: ${werIstDran(a)}',
                        'alle ${a.alleTage} Tage',
                        if (naechstesMal(a) != null) 'nächstes Mal ${datumKurz(naechstesMal(a)!)}',
                      ].join(' · '),
                      style: const TextStyle(color: PT.grau, fontSize: 13),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: 'Erledigt',
                  icon: const Icon(Icons.check_circle_outline, color: PT.gruen),
                  onPressed: () {
                    hausaufgabeErledigt(a, DateTime.now());
                    store.geaendert();
                  },
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Future<void> _bearbeiten(BuildContext context, Hausaufgabe? a) async {
    final store = StoreScope.of(context);
    final text = TextEditingController(text: a?.text ?? '');
    final personen = TextEditingController(text: a?.personen.join(', ') ?? '');
    var tage = a?.alleTage ?? 7;
    final ok = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text(a == null ? 'Neue Aufgabe' : 'Aufgabe'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: text, decoration: feld(labelText: 'Was?', hintText: 'z. B. Bad putzen')),
              const SizedBox(height: 8),
              TextField(controller: personen, decoration: feld(labelText: 'Wer wechselt sich ab?', hintText: 'Mia, Tom, Papa')),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final (t, n) in const [(1, 'täglich'), (7, 'wöchentlich'), (14, 'alle 2 Wochen'), (30, 'monatlich')])
                  ChoiceChip(label: Text(n), selected: tage == t, onSelected: (_) => setze(() => tage = t)),
              ]),
            ]),
          ),
          actions: [
            if (a != null) TextButton(onPressed: () => Navigator.pop(d, 'weg'), child: const Text('Löschen')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final t = text.text.trim();
    final p = personen.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    text.dispose();
    personen.dispose();
    if (ok == 'weg' && a != null) {
      store.alltag.hausaufgaben.remove(a);
    } else if (ok == 'ok' && t.isNotEmpty) {
      final x = a ?? Hausaufgabe(text: t);
      x
        ..text = t
        ..personen = p
        ..alleTage = tage;
      if (a == null) store.alltag.hausaufgaben.add(x);
    } else {
      return;
    }
    await store.geaendert();
  }
}

// ---------------------------------------------------------------- Geschenke und Anschaffungen

class GeschenkeScreen extends StatelessWidget {
  const GeschenkeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final offen = store.alltag.geschenke.where((g) => !g.erledigt).toList()
      ..sort((a, b) => (a.datum ?? DateTime(9999)).compareTo(b.datum ?? DateTime(9999)));
    final summe = offen.fold(0.0, (s, g) => s + (g.preis ?? 0));
    final geburtstage = store.termine.where((t) => t.art == 'Geburtstag' && !t.erledigt).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Geschenke & Anschaffungen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bearbeiten(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Idee'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (summe > 0)
            PTKarte(farbe: PT.orangeHell, child: Text('Geplant: ${euro(summe)}', style: const TextStyle(fontWeight: FontWeight.w700))),
          if (offen.isEmpty)
            const LeerHinweis(icon: Icons.card_giftcard, text: 'Sammle Geschenkideen und geplante Anschaffungen mit Preis und Termin.'),
          for (final g in offen)
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => _bearbeiten(context, g),
              child: Row(children: [
                const Icon(Icons.card_giftcard, color: PT.orangeDunkel),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.idee, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [if (g.fuer.isNotEmpty) 'für ${g.fuer}', if (g.anlass.isNotEmpty) g.anlass, if (g.datum != null) datumKurz(g.datum!), if (g.preis != null) euro(g.preis!)]
                          .join(' · '),
                      style: const TextStyle(color: PT.grau, fontSize: 13),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: 'Besorgt',
                  icon: const Icon(Icons.check_circle_outline, color: PT.gruen),
                  onPressed: () {
                    g.erledigt = true;
                    store.geaendert();
                  },
                ),
              ]),
            ),
          if (geburtstage.isNotEmpty) ...[
            const Abschnitt('Geburtstage'),
            for (final t in geburtstage)
              ListTile(
                leading: const Icon(Icons.cake_outlined, color: PT.orangeDunkel),
                title: Text(t.titel),
                subtitle: Text(t.notiz.isEmpty ? 'noch keine Geschenkidee' : t.notiz),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TerminFormular(terminId: t.id))),
              ),
          ],
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TerminFormular(vorlage: Termin(id: neueId(), titel: 'Geburtstag ', datum: DateTime.now(), art: 'Geburtstag', wiederholungMonate: 12)))),
            icon: const Icon(Icons.cake_outlined),
            label: const Text('Geburtstag eintragen'),
          ),
        ],
      ),
    );
  }

  Future<void> _bearbeiten(BuildContext context, Geschenk? g) async {
    final store = StoreScope.of(context);
    final idee = TextEditingController(text: g?.idee ?? '');
    final fuer = TextEditingController(text: g?.fuer ?? '');
    final anlass = TextEditingController(text: g?.anlass ?? '');
    final preis = TextEditingController(text: g?.preis == null ? '' : g!.preis!.toStringAsFixed(2).replaceAll('.', ','));
    DateTime? datum = g?.datum;
    final ok = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text(g == null ? 'Neue Idee' : 'Idee'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: idee, decoration: feld(labelText: 'Was?', hintText: 'z. B. Fahrradhelm, neue Waschmaschine')),
              const SizedBox(height: 8),
              TextField(controller: fuer, decoration: feld(labelText: 'Für wen? (optional)')),
              const SizedBox(height: 8),
              TextField(controller: anlass, decoration: feld(labelText: 'Anlass (optional)', hintText: 'Geburtstag, Weihnachten …')),
              const SizedBox(height: 8),
              TextField(
                  controller: preis,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: feld(labelText: 'Preis ca.', suffixText: '€')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(datum == null ? 'Bis wann? (optional)' : 'Bis ${datumKurz(datum!)}'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final x = await datumWaehlen(d, start: datum);
                  if (x != null) setze(() => datum = x);
                },
              ),
            ]),
          ),
          actions: [
            if (g != null) TextButton(onPressed: () => Navigator.pop(d, 'weg'), child: const Text('Löschen')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final i = idee.text.trim(), f = fuer.text.trim(), a = anlass.text.trim();
    final p = double.tryParse(preis.text.replaceAll('.', '').replaceAll(',', '.'));
    for (final c in [idee, fuer, anlass, preis]) {
      c.dispose();
    }
    if (ok == 'weg' && g != null) {
      store.alltag.geschenke.remove(g);
    } else if (ok == 'ok' && i.isNotEmpty) {
      final x = g ?? Geschenk(idee: i);
      x
        ..idee = i
        ..fuer = f
        ..anlass = a
        ..preis = p
        ..datum = datum;
      if (g == null) store.alltag.geschenke.add(x);
    } else {
      return;
    }
    await store.geaendert();
  }
}

// ---------------------------------------------------------------- Reisen

class ReisenScreen extends StatelessWidget {
  const ReisenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = [...store.alltag.reisen]..sort((a, b) => (a.von ?? DateTime(9999)).compareTo(b.von ?? DateTime(9999)));
    return Scaffold(
      appBar: AppBar(title: const Text('Reisen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ziel = await _eingabe(context, 'Wohin geht die Reise?');
          if (ziel == null) return;
          final r = Reise(id: neueId(), ziel: ziel, packliste: packliste('Sommer'));
          store.alltag.reisen.add(r);
          await store.geaendert();
          if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReiseDetail(reiseId: r.id)));
        },
        icon: const Icon(Icons.add),
        label: const Text('Reise'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (l.isEmpty)
            const LeerHinweis(icon: Icons.luggage_outlined, text: 'Packliste, Reiseplan und alle Unterlagen für deine Reise an einem Ort.'),
          for (final r in l)
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReiseDetail(reiseId: r.id))),
              child: Row(children: [
                const IconKachel(Icons.luggage_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.ziel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${r.von == null ? 'Datum offen' : '${datumKurz(r.von!)}${r.bis == null ? '' : ' – ${datumKurz(r.bis!)}'}'} · '
                      '${r.packliste.isEmpty ? 'Packliste noch leer' : '${r.packliste.where((p) => p.eingepackt).length}/${r.packliste.length} eingepackt'}',
                      style: const TextStyle(color: PT.grau, fontSize: 13),
                    ),
                  ]),
                ),
                if (r.von != null) FristEtikett(r.von!),
              ]),
            ),
        ],
      ),
    );
  }
}

class ReiseDetail extends StatelessWidget {
  const ReiseDetail({super.key, required this.reiseId});

  final String reiseId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = store.alltag.reisen.where((x) => x.id == reiseId).firstOrNull;
    if (r == null) return Scaffold(appBar: AppBar(), body: const LeerHinweis(icon: Icons.luggage_outlined, text: 'Gelöscht.'));
    final unterlagen = store.briefe.where((b) => r.briefIds.contains(b.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(r.ziel),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.of(context).pop();
              store.alltag.reisen.remove(r);
              store.geaendert();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.date_range_outlined, color: PT.orangeDunkel),
            title: Text(r.von == null ? 'Reisedaten festlegen' : '${datumKurz(r.von!)} – ${r.bis == null ? '?' : datumKurz(r.bis!)}'),
            onTap: () async {
              final jetzt = DateTime.now();
              final z = await showDateRangePicker(
                  context: context, firstDate: DateTime(jetzt.year - 1), lastDate: DateTime(jetzt.year + 3), helpText: 'Reisezeitraum');
              if (z == null) return;
              r
                ..von = z.start
                ..bis = z.end;
              await store.geaendert();
            },
          ),
          Wrap(spacing: 6, children: [
            for (final a in reiseArten)
              ChoiceChip(
                label: Text(a),
                selected: r.art == a,
                onSelected: (_) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: Text('Packliste für „$a“?'),
                      content: const Text('Die bisherige Packliste wird ersetzt.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Nein')),
                        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ja')),
                      ],
                    ),
                  );
                  r.art = a;
                  if (ok == true) r.packliste = packliste(a);
                  await store.geaendert();
                },
              ),
          ]),
          const Abschnitt('Unterlagen'),
          for (final b in unterlagen)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined, color: PT.orangeDunkel),
              title: Text(titelVon(b)),
              trailing: IconButton(
                icon: const Icon(Icons.link_off, size: 20),
                onPressed: () {
                  r.briefIds.remove(b.id);
                  store.geaendert();
                },
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id))),
            ),
          TextButton.icon(
            onPressed: () async {
              final kandidaten = store.briefe.where((b) => !r.briefIds.contains(b.id)).take(40).toList();
              final id = await showDialog<String>(
                context: context,
                builder: (d) => SimpleDialog(
                  title: const Text('Dokument aus dem Archiv'),
                  children: [
                    for (final b in kandidaten)
                      SimpleDialogOption(onPressed: () => Navigator.pop(d, b.id), child: Text(titelVon(b))),
                  ],
                ),
              );
              if (id == null) return;
              r.briefIds.add(id);
              await store.geaendert();
            },
            icon: const Icon(Icons.attach_file),
            label: const Text('Buchung, Tickets, Versicherung hinzufügen'),
          ),
          const Text('Tipp: Buchungs-E-Mails mit „Teilen → Papiertiger“ ins Archiv holen, dann hier verknüpfen.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
          Abschnitt('Packliste (${r.packliste.where((p) => p.eingepackt).length}/${r.packliste.length})'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(children: [
              for (final p in r.packliste)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: p.eingepackt,
                  title: Text(p.text),
                  onChanged: (v) {
                    p.eingepackt = v ?? false;
                    store.geaendert();
                  },
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add),
                title: const Text('Eigenen Punkt hinzufügen'),
                onTap: () async {
                  final t = await _eingabe(context, 'Packliste');
                  if (t == null) return;
                  r.packliste.add(PackStueck(t));
                  await store.geaendert();
                },
              ),
            ]),
          ),
          const Abschnitt('Reiseplan'),
          PTKarte(
            onTap: () async {
              final t = await _eingabe(context, 'Reiseplan', start: r.plan, zeilen: 8);
              if (t == null) return;
              r.plan = t;
              await store.geaendert();
            },
            child: Text(r.plan.isEmpty ? 'Noch kein Plan – tippen zum Schreiben' : r.plan),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => KiTextScreen(
                titel: 'Reiseplan',
                anfrage: reiseplanAnfrage(r),
                hinweis: 'Vorschläge der KI. Öffnungszeiten und Preise bitte vor Ort prüfen.',
                uebernehmen: (
                  'Als Reiseplan übernehmen',
                  (text) {
                    r.plan = text;
                    store.geaendert();
                  }
                ),
              ),
            )),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Reiseplan mit KI vorschlagen'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Wohnungsübergabe

class WohnungsuebergabeScreen extends StatelessWidget {
  const WohnungsuebergabeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wohnungsübergabe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Für Auszug und Einzug. Hake ab, was erledigt ist.', style: TextStyle(color: PT.grau)),
          const SizedBox(height: 8),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(children: [
              for (var i = 0; i < wohnungsuebergabe.length; i++)
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: store.checklisten['uebergabe:$i'] == true,
                  title: Text(wohnungsuebergabe[i]),
                  onChanged: (v) => store.checklistePunkt('uebergabe:$i', v ?? false),
                ),
            ]),
          ),
          const Text('Die Zählerstände kannst du direkt unter Haushalt → Zählerstände eintragen.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}
