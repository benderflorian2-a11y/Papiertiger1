import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/finanzen.dart';
import '../logic/vorlagen.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'module/vertraege.dart';
import 'theme.dart';
import 'vorlage_screen.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';

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
            child: Text('Kopiere die Angaben in deine Banking-App und prüfe sie dort. Der Tiger bezahlt nie selbst.',
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final offen = offeneZahlungen(store.briefe);
    final gut = erwarteteGutschriften(store.briefe);
    final m = monatsUeberblick(briefe: store.briefe, vertraege: store.vertraege, belege: store.belege, monat: _monat);
    void oeffnen(Brief b) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id)));

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
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _monat = DateTime(_monat.year, _monat.month - 1)),
            ),
            Expanded(
              child: Text('${_monate[_monat.month - 1]} ${_monat.year}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _monat = DateTime(_monat.year, _monat.month + 1)),
            ),
          ]),
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
