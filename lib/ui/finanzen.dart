import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/export.dart';
import '../logic/finanzen.dart';
import '../logic/kostenplan.dart';
import '../logic/texterkennung.dart';
import '../logic/vorlagen.dart';
import '../logic/zahlung.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'kontoauszug.dart';
import 'module/vertraege.dart';
import 'theme.dart';
import 'ueberweisung.dart';
import 'vorlage_screen.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';
import 'widgets/kosten_kreis.dart';

const _monate = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Im Brief: Überweisungsdaten zum Kopieren und „bezahlt“ vermerken. Bezahlt wird nur in deiner Bank-App.
class ZahlungKarte extends StatelessWidget {
  const ZahlungKarte({super.key, required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = brief;
    if (b.betrag == null || b.guthaben) return const SizedBox.shrink();
    final u = ueberweisungFinden(b.text,
        empfaenger: b.absenderName, betrag: b.betrag, eigeneIban: store.profil.extra['iban']);

    Widget zeile(String label, String? wert, {String? kopie}) => ListTile(
          dense: true,
          title: Text(label, style: const TextStyle(color: PT.grau, fontSize: 13)),
          subtitle: Text(wert ?? 'nicht gefunden',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: wert == null ? PT.grau : PT.tinte)),
          trailing: wert == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: kopie ?? wert));
                    zeigeHinweis(context, '$label kopiert');
                  },
                ),
        );

    if (b.bezahltAm != null) {
      return PTKarte(
        farbe: PT.gruenHell,
        child: Row(children: [
          const Icon(Icons.check_circle, color: PT.gruen),
          const SizedBox(width: 12),
          Expanded(child: Text('${euro(b.betrag!)} bezahlt am ${datumKurz(b.bezahltAm!)}')),
          if (b.zahlungsnachweis != null && File(b.zahlungsnachweis!).existsSync())
            IconButton(
              tooltip: 'Zahlungsnachweis teilen',
              icon: const Icon(Icons.receipt_outlined),
              onPressed: () => dateiTeilen(b.zahlungsnachweis!),
            )
          else
            IconButton(
              tooltip: 'Zahlungsnachweis hinzufügen (Screenshot aus der Banking-App)',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () async {
                final pfad = await Texterkennung.bildHolen(kamera: false);
                if (pfad == null) return;
                b.zahlungsnachweis = pfad;
                await store.geaendert();
              },
            ),
          TextButton(
            onPressed: () {
              bezahltZuruecknehmen(b);
              store.geaendert();
            },
            child: const Text('Rückgängig'),
          ),
        ]),
      );
    }

    return PTKarte(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text('Überweisung', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          zeile('Empfänger', u.empfaenger),
          zeile('IBAN', u.iban == null ? null : ibanLesbar(u.iban!), kopie: u.iban),
          if (u.bic != null) zeile('BIC', u.bic),
          zeile('Betrag', euro(b.betrag!), kopie: b.betrag!.toStringAsFixed(2).replaceAll('.', ',')),
          zeile('Verwendungszweck', u.zweck),
          if (u.iban == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Keine gültige IBAN gefunden. Steht sie auf einem beiliegenden Überweisungsträger oder auf der Rückseite?',
                  style: TextStyle(color: PT.grau, fontSize: 13)),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Der Tiger bereitet die Überweisung vor – freigeben musst du sie in deiner Banking-App. Er bezahlt nie selbst.',
                style: TextStyle(color: PT.grau, fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              FilledButton.icon(
                onPressed: () async {
                  final d = await datumWaehlen(context, start: DateTime.now());
                  if (d == null) return;
                  alsBezahltMarkieren(b, d);
                  await store.geaendert();
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Bezahlt'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UeberweisungScreen(
                    auftrag: Zahlauftrag(
                      empfaenger: u.empfaenger ?? b.absenderName ?? '',
                      iban: u.iban ?? '',
                      bic: u.bic ?? '',
                      betrag: b.betrag,
                      zweck: u.zweck ?? b.aktenzeichen ?? '',
                    ),
                    beiFreigabe: (am) {
                      alsBezahltMarkieren(b, am);
                      store.geaendert();
                    },
                  ),
                )),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Überweisen (mit Freigabe)'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => RatenRechner(brief: b, betrag: b.betrag))),
                icon: const Icon(Icons.calendar_view_month_outlined, size: 18),
                label: const Text('In Raten?'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Rechnet einen Ratenplan aus und bereitet die Anfrage beim Gläubiger vor.
class RatenRechner extends StatefulWidget {
  const RatenRechner({super.key, this.brief, this.betrag});

  final Brief? brief;
  final double? betrag;

  @override
  State<RatenRechner> createState() => _RatenRechnerState();
}

class _RatenRechnerState extends State<RatenRechner> {
  late final _gesamt = TextEditingController(text: widget.betrag?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
  final _rate = TextEditingController();
  DateTime _erste = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);

  double? _zahl(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim());

  @override
  void dispose() {
    _gesamt.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final gesamt = _zahl(_gesamt.text) ?? 0;
    final rate = _zahl(_rate.text) ?? 0;
    final plan = ratenplan(gesamt, rate, _erste);
    return Scaffold(
      appBar: AppBar(title: const Text('Ratenplan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _gesamt,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Gesamtbetrag', suffixText: '€'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Was kannst du im Monat zahlen?', suffixText: '€'),
            onChanged: (_) => setState(() {}),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Erste Rate'),
            subtitle: Text(datumLang(_erste)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await datumWaehlen(context, start: _erste);
              if (d != null) setState(() => _erste = d);
            },
          ),
          if (plan.isNotEmpty) ...[
            PTKarte(
              farbe: PT.orangeHell,
              child: Text(
                '${plan.length} ${plan.length == 1 ? 'Rate' : 'Raten'}, letzte Rate am ${datumKurz(plan.last.datum)}'
                '${plan.last.betrag != rate ? ' (${euro(plan.last.betrag)})' : ''}.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final r in plan.take(24))
                  ListTile(
                    dense: true,
                    leading: Text('${r.nummer}.', style: const TextStyle(fontWeight: FontWeight.w700)),
                    title: Text('${datumKurz(r.datum)}: ${euro(r.betrag)}'),
                    trailing: Text('Rest ${euro(r.rest)}', style: const TextStyle(color: PT.grau)),
                  ),
                if (plan.length > 24) Text('… und ${plan.length - 24} weitere', style: const TextStyle(color: PT.grau)),
              ]),
            ),
            if (widget.brief != null)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VorlageScreen(
                    titel: 'Ratenzahlung',
                    text: vorlageText('raten', widget.brief!, store.profil)
                        .replaceFirst('[Betrag]', rate.toStringAsFixed(2).replaceAll('.', ','))
                        .replaceFirst('[Datum]', datumKurz(_erste)),
                    brief: widget.brief,
                  ),
                )),
                icon: const Icon(Icons.edit_note),
                label: const Text('Ratenzahlung anfragen'),
              ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Ohne Zinsen und Gebühren gerechnet. Ob Raten möglich sind, entscheidet der Gläubiger. '
            'Bei Schulden hilft eine kostenlose Schuldnerberatung (z. B. Caritas, Diakonie, Verbraucherzentrale).',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Finanz-Überblick: Monat, offene Zahlungen, erwartetes Geld.
class FinanzenScreen extends StatefulWidget {
  const FinanzenScreen({super.key});

  @override
  State<FinanzenScreen> createState() => _FinanzenScreenState();
}

class _FinanzenScreenState extends State<FinanzenScreen> {
  DateTime _monat = DateTime(DateTime.now().year, DateTime.now().month);

  double? _zahl(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim());

  Future<void> _budgetSetzen(BuildContext context, String kategorie) async {
    final store = StoreScope.of(context);
    final c = TextEditingController(text: store.notizen['budget:$kategorie'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Budget für $kategorie'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: feld(labelText: 'Pro Monat', suffixText: '€', hintText: 'leer = kein Budget'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Speichern')),
        ],
      ),
    );
    final wert = _zahl(c.text);
    c.dispose();
    if (ok != true) return;
    if (wert == null || wert <= 0) {
      store.notizen.remove('budget:$kategorie');
    } else {
      store.notizen['budget:$kategorie'] = wert.toString();
    }
    await store.geaendert();
  }

  Future<void> _sparziel(BuildContext context, Sparziel? z) async {
    final store = StoreScope.of(context);
    final name = TextEditingController(text: z?.name ?? '');
    final ziel = TextEditingController(text: z == null ? '' : z.ziel.toStringAsFixed(2).replaceAll('.', ','));
    final gespart = TextEditingController(text: z == null ? '' : z.gespart.toStringAsFixed(2).replaceAll('.', ','));
    DateTime? bis = z?.bis;
    final ergebnis = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text(z == null ? 'Neues Sparziel' : 'Sparziel'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: feld(labelText: 'Wofür?', hintText: 'z. B. Steuer-Rücklage, Urlaub')),
              const SizedBox(height: 8),
              TextField(
                  controller: ziel,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: feld(labelText: 'Zielbetrag', suffixText: '€')),
              const SizedBox(height: 8),
              TextField(
                  controller: gespart,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: feld(labelText: 'Schon zurückgelegt', suffixText: '€')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(bis == null ? 'Bis wann? (optional)' : 'Bis ${datumKurz(bis!)}'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final x = await datumWaehlen(d, start: bis);
                  if (x != null) setze(() => bis = x);
                },
              ),
            ]),
          ),
          actions: [
            if (z != null) TextButton(onPressed: () => Navigator.pop(d, 'loeschen'), child: const Text('Löschen')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final n = name.text.trim(), zz = _zahl(ziel.text), g = _zahl(gespart.text) ?? 0;
    name.dispose();
    ziel.dispose();
    gespart.dispose();
    if (ergebnis == 'loeschen' && z != null) {
      store.sparziele.removeWhere((x) => x.id == z.id);
    } else if (ergebnis == 'ok' && n.isNotEmpty && zz != null && zz > 0) {
      final x = z ?? Sparziel(id: neueId(), name: n, ziel: zz);
      x
        ..name = n
        ..ziel = zz
        ..gespart = g
        ..bis = bis;
      if (z == null) store.sparziele.add(x);
    } else {
      return;
    }
    await store.geaendert();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final offen = offeneZahlungen(store.briefe);
    final gut = erwarteteGutschriften(store.briefe);
    final m = monatsUeberblick(briefe: store.briefe, vertraege: store.vertraege, belege: store.belege, monat: _monat);
    void oeffnen(Brief b) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id)));
    final kat = ausgabenNachKategorie(belege: store.belege, vertraege: store.vertraege, monat: _monat);
    final budgetListe = budgets(store.notizen, kat);
    final budgetMap = {for (final b in budgetListe) b.kategorie: b};
    final auffaellig = auffaelligeRechnungen(store.briefe);
    final plan = kostenplan(briefe: store.briefe, vertraege: store.vertraege, belege: store.belege, monat: _monat);
    final hinweise = sparpotenziale(vertraege: store.vertraege, briefe: store.briefe, budgets: budgetListe);

    Widget posten(String text, double betrag, {VoidCallback? onTap}) => ListTile(
          dense: true,
          title: Text(text),
          trailing: Text(euro(betrag), style: const TextStyle(fontWeight: FontWeight.w700)),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Finanzen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(color: PT.sand.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(30)),
            child: Row(children: [
              IconButton(
                tooltip: 'Monat zurück',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _monat = DateTime(_monat.year, _monat.month - 1)),
              ),
              Expanded(
                child: Text('${_monate[_monat.month - 1]} ${_monat.year}',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: 'Monat vor',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _monat = DateTime(_monat.year, _monat.month + 1)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          PTKarte(
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Finanzplanung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Text('Tippe auf eine Farbe, um die einzelnen Posten zu sehen.',
                  style: TextStyle(color: PT.grau, fontSize: 12.5)),
              const SizedBox(height: 14),
              KostenKreis(plan: plan, monatName: _monate[_monat.month - 1]),
            ]),
          ),
          Row(children: [
            Expanded(
              child: _Kachel(
                icon: Icons.trending_up,
                titel: 'Nächster Monat',
                wert: 'ca. ${euro(prognoseNaechsterMonat(briefe: store.briefe, vertraege: store.vertraege, belege: store.belege, heute: DateTime.now()))}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Kachel(
                icon: Icons.check_circle_outline,
                titel: 'Schon bezahlt',
                wert: euro(m.bezahlt),
                farbe: PT.gruenHell,
              ),
            ),
          ]),
          if (plan.demnaechst.isNotEmpty) ...[
            const Abschnitt('Demnächst fällig'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (final b in plan.demnaechst.take(5)) _FaelligZeile(brief: b, onTap: () => oeffnen(b)),
                if (plan.demnaechst.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('und ${plan.demnaechst.length - 5} weitere unten bei „Offene Zahlungen“',
                        style: const TextStyle(color: PT.grau, fontSize: 12.5)),
                  ),
              ]),
            ),
          ],
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Monat im Detail', style: TextStyle(fontWeight: FontWeight.w700)),
            children: [
              PTKarte(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  posten('Verträge und Abos (pro Monat)', m.fixkosten,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VertraegeScreen()))),
                  posten('Offene Zahlungen bis Monatsende', m.faellig),
                  posten('Als bezahlt vermerkt', m.bezahlt),
                  posten('Kassenbons und Belege', m.ausgaben),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Zusammen', style: TextStyle(fontWeight: FontWeight.w800)),
                    trailing: Text(euro(m.gesamt), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ]),
              ),
            ],
          ),
          const Abschnitt('Budgets je Kategorie'),
          if (kat.isEmpty)
            const PTKarte(child: Text('Noch keine Ausgaben in diesem Monat. Kassenbons und Verträge zählen hier mit.'))
          else
            PTKarte(
              child: Column(children: [
                for (final (k, betrag) in kat)
                  InkWell(
                    onTap: () => _budgetSetzen(context, k),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(euro(betrag)),
                          if (budgetMap[k] != null)
                            Text(' / ${euro(budgetMap[k]!.budget)}', style: const TextStyle(color: PT.grau)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: budgetMap[k] != null
                                ? budgetMap[k]!.anteil.clamp(0.0, 1.0)
                                : (betrag / kat.first.$2).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: PT.sand,
                            color: budgetMap[k]?.ueberschritten == true ? PT.rot : PT.orange,
                          ),
                        ),
                      ]),
                    ),
                  ),
                const SizedBox(height: 4),
                const Text('Tippe auf eine Kategorie, um ein Monatsbudget festzulegen.',
                    style: TextStyle(color: PT.grau, fontSize: 12)),
              ]),
            ),
          if (hinweise.isNotEmpty || auffaellig.isNotEmpty) ...[
            const Abschnitt('Hinweise'),
            for (final a in auffaellig)
              PTKarte(
                farbe: PT.gelbHell,
                onTap: () {
                  final b = store.briefe.where((x) => x.id == a.briefIds.last).firstOrNull;
                  if (b != null) oeffnen(b);
                },
                child: Row(children: [
                  const Icon(Icons.report_outlined, color: PT.gelb),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.text)),
                ]),
              ),
            for (final h in hinweise)
              PTKarte(
                child: Row(children: [
                  const Icon(Icons.savings_outlined, color: PT.orangeDunkel),
                  const SizedBox(width: 12),
                  Expanded(child: Text(h)),
                ]),
              ),
          ],
          PTKarte(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KontoauszugScreen())),
            child: const Row(children: [
              IconKachel(Icons.repeat),
              SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kontoauszug prüfen', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('Abos und regelmäßige Abbuchungen finden, doppelte Abbuchungen erkennen',
                      style: TextStyle(color: PT.grau, fontSize: 13)),
                ]),
              ),
              Icon(Icons.chevron_right, color: PT.grau),
            ]),
          ),
          Row(children: [
            const Expanded(child: Abschnitt('Sparziele und Rücklagen')),
            TextButton.icon(
              onPressed: () => _sparziel(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Neu'),
            ),
          ]),
          if (store.sparziele.isEmpty)
            const PTKarte(
                child: Text('Leg Rücklagen an, z. B. für die Steuernachzahlung, ein neues Auto oder den Urlaub. '
                    'Der Tiger rechnet aus, wie viel du dafür im Monat zur Seite legen solltest.'))
          else
            for (final z in store.sparziele)
              PTKarte(
                onTap: () => _sparziel(context, z),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(z.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${euro(z.gespart)} / ${euro(z.ziel)}'),
                  ]),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: z.ziel <= 0 ? 0 : (z.gespart / z.ziel).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: PT.sand,
                    color: PT.gruen,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    switch (sparrateProMonat(z, heute: DateTime.now())) {
                      null => 'Ohne Zieldatum',
                      final double r when r <= 0 => 'Ziel erreicht!',
                      final double r => '${euro(r)} im Monat bis ${datumKurz(z.bis!)}',
                    },
                    style: const TextStyle(color: PT.grau, fontSize: 13),
                  ),
                ]),
              ),
          Abschnitt(offen.isEmpty ? 'Offene Zahlungen' : 'Offene Zahlungen: ${euro(summe(offen))}'),
          if (offen.isEmpty)
            const PTKarte(child: Text('Nichts offen. Sobald ein Brief einen Betrag fordert, steht er hier.'))
          else
            for (final b in offen) BriefZeile(brief: b, onTap: () => oeffnen(b)),
          if (gut.isNotEmpty) ...[
            Abschnitt('Geld, das du bekommst: ${euro(summe(gut))}'),
            for (final b in gut) BriefZeile(brief: b, onTap: () => oeffnen(b)),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RatenRechner())),
            icon: const Icon(Icons.calendar_view_month_outlined),
            label: const Text('Ratenplan ausrechnen'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ohne Bankzugang: Der Tiger kennt nur, was in deinen Briefen, Verträgen und Belegen steht.',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}


class _Kachel extends StatelessWidget {
  const _Kachel({required this.icon, required this.titel, required this.wert, this.farbe = PT.orangeHell});

  final IconData icon;
  final String titel;
  final String wert;
  final Color farbe;

  @override
  Widget build(BuildContext context) => PTKarte(
        farbe: farbe,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: PT.tinte),
            const SizedBox(width: 6),
            Expanded(child: Text(titel, style: const TextStyle(fontSize: 12.5, color: PT.tinte))),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(wert, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

/// Zahlung mit Datumskästchen links: wann, wer, wie viel.
class _FaelligZeile extends StatelessWidget {
  const _FaelligZeile({required this.brief, required this.onTap});

  final Brief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = brief.frist!;
    final heute = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tage = DateTime(f.year, f.month, f.day).difference(heute).inDays;
    final ueberfaellig = tage < 0;
    const monate = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: ueberfaellig ? PT.rotHell : PT.orangeHell,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text('${f.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ueberfaellig ? PT.rot : PT.tinte)),
              Text(monate[f.month - 1], style: TextStyle(fontSize: 11, color: ueberfaellig ? PT.rot : PT.grau)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(brief.absenderName ?? brief.titel ?? 'Zahlung',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                ueberfaellig ? 'seit ${-tage} ${-tage == 1 ? 'Tag' : 'Tagen'} überfällig' : (tage == 0 ? 'heute' : 'in $tage ${tage == 1 ? 'Tag' : 'Tagen'}'),
                style: TextStyle(color: ueberfaellig ? PT.rot : PT.grau, fontSize: 12.5),
              ),
            ]),
          ),
          Text(euro(brief.betrag ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
