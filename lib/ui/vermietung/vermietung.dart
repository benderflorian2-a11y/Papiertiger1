import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/vermietung.dart';
import '../../logic/kontoauszug.dart';
import '../../logic/vermietung.dart';
import '../app.dart';
import '../kontoauszug.dart';
import '../theme.dart';
import '../vorlage_screen.dart';
import '../widgets/common.dart';

double? _zahl(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim());
String _feld(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ','));

Future<String?> _eingabe(BuildContext context, String titel, {String start = '', bool zahl = false, String? hint}) async {
  final c = TextEditingController(text: start);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titel),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: zahl ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: feld(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('OK')),
      ],
    ),
  );
  final t = c.text.trim();
  c.dispose();
  return ok == true ? t : null;
}

class VermietungScreen extends StatelessWidget {
  const VermietungScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vermietung;
    final summe = v.mieter.where((m) => m.auszug == null).fold(0.0, (s, m) => s + m.warmmiete);
    void oeffne(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('Vermietung')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final a = await _eingabe(context, 'Adresse des Hauses');
          if (a == null || a.isEmpty) return;
          v.objekte.add(Mietobjekt(id: neueId(), adresse: a));
          await store.geaendert();
        },
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('Objekt'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
        if (v.objekte.isEmpty)
          const LeerHinweis(
            icon: Icons.apartment_outlined,
            text: 'Leg dein Haus bzw. deine Wohnung an, dann die Mieter – der Tiger prüft Mieteingänge, erinnert an '
                'Mieterhöhungen und erstellt die Nebenkostenabrechnung.',
          ),
        if (summe > 0) Text('Soll-Miete im Monat: ${euro(summe)} warm', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (v.mieter.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => oeffne(const MieteingaengeScreen()),
            icon: const Icon(Icons.price_check),
            label: const Text('Mieteingänge prüfen (Kontoauszug)'),
          ),
        for (final o in v.objekte) ...[
          Row(children: [
            Expanded(child: Abschnitt(o.adresse)),
            PopupMenuButton<String>(
              onSelected: (w) async {
                if (w == 'flaeche') {
                  final t = await _eingabe(context, 'Wohnfläche aller Wohnungen (m²)', start: _feld(o.gesamtflaeche), zahl: true);
                  if (t != null) o.gesamtflaeche = _zahl(t) ?? 0;
                } else if (w == 'einheiten') {
                  final t = await _eingabe(context, 'Anzahl Wohnungen', start: '${o.einheiten}', zahl: true);
                  if (t != null) o.einheiten = int.tryParse(t) ?? 1;
                } else if (w == 'loeschen') {
                  v.objekte.remove(o);
                  v.mieter.removeWhere((m) => m.objektId == o.id);
                }
                await store.geaendert();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'flaeche', child: Text('Gesamtfläche: ${_feld(o.gesamtflaeche)} m²')),
                PopupMenuItem(value: 'einheiten', child: Text('Wohnungen: ${o.einheiten}')),
                const PopupMenuItem(value: 'loeschen', child: Text('Objekt löschen')),
              ],
            ),
          ]),
          for (final m in v.mieter.where((m) => m.objektId == o.id))
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => oeffne(MieterScreen(mieterId: m.id)),
              child: Row(children: [
                const IconKachel(Icons.person_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m.name}${m.wohnung.isEmpty ? '' : ' · ${m.wohnung}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${euro(m.kaltmiete)} kalt + ${euro(m.nebenkosten)} NK${m.auszug != null ? ' · ausgezogen' : ''}',
                        style: const TextStyle(color: PT.grau, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          Wrap(spacing: 8, children: [
            TextButton.icon(
              onPressed: () async {
                final n = await _eingabe(context, 'Name des Mieters');
                if (n == null || n.isEmpty) return;
                final m = Mieter(id: neueId(), objektId: o.id, name: n);
                v.mieter.add(m);
                await store.geaendert();
                if (context.mounted) oeffne(MieterScreen(mieterId: m.id));
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Mieter'),
            ),
            TextButton.icon(
              onPressed: () => oeffne(NebenkostenScreen(objektId: o.id, jahr: DateTime.now().year - 1)),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text('Nebenkosten ${DateTime.now().year - 1}'),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        const Text('Allgemeine Hinweise zum Mietrecht, keine Rechtsberatung. Bei Fragen: Haus & Grund oder Fachanwalt.',
            style: TextStyle(color: PT.grau, fontSize: 12)),
      ]),
    );
  }
}

class MieterScreen extends StatelessWidget {
  const MieterScreen({super.key, required this.mieterId});

  final String mieterId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final m = store.vermietung.mieter.where((x) => x.id == mieterId).firstOrNull;
    if (m == null) return Scaffold(appBar: AppBar(), body: const LeerHinweis(icon: Icons.person_outline, text: 'Gelöscht.'));
    final (verlangen, wirksam, hinweis) = mieterhoehungMoeglich(m);
    Widget zeile(String titel, String wert, Future<void> Function() bearbeiten) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(titel),
          subtitle: Text(wert.isEmpty ? 'eintragen' : wert),
          trailing: const Icon(Icons.edit_outlined, size: 18),
          onTap: () async {
            await bearbeiten();
            await store.geaendert();
          },
        );
    Future<void> zahl(String titel, double start, void Function(double) setzen) async {
      final t = await _eingabe(context, titel, start: _feld(start), zahl: true);
      if (t != null) setzen(_zahl(t) ?? 0);
    }

    Future<void> text(String titel, String start, void Function(String) setzen) async {
      final t = await _eingabe(context, titel, start: start);
      if (t != null) setzen(t);
    }

    Future<void> datum(DateTime? start, void Function(DateTime?) setzen) async {
      final d = await datumWaehlen(context, start: start);
      if (d != null) setzen(d);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(m.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.of(context).pop();
              store.vermietung.mieter.remove(m);
              store.geaendert();
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        zeile('Name', m.name, () => text('Name', m.name, (t) => m.name = t)),
        zeile('Wohnung', m.wohnung, () => text('Wohnung (z. B. 2. OG links)', m.wohnung, (t) => m.wohnung = t)),
        zeile('E-Mail', m.email, () => text('E-Mail', m.email, (t) => m.email = t)),
        zeile('Kaltmiete', m.kaltmiete == 0 ? '' : euro(m.kaltmiete), () => zahl('Kaltmiete (€)', m.kaltmiete, (x) => m.kaltmiete = x)),
        zeile('Nebenkosten-Vorauszahlung', m.nebenkosten == 0 ? '' : euro(m.nebenkosten),
            () => zahl('Vorauszahlung im Monat (€)', m.nebenkosten, (x) => m.nebenkosten = x)),
        zeile('Wohnfläche', m.flaeche == 0 ? '' : '${_feld(m.flaeche)} m²', () => zahl('Wohnfläche (m²)', m.flaeche, (x) => m.flaeche = x)),
        zeile('Personen in der Wohnung', '${m.personen}', () => zahl('Personen', m.personen.toDouble(), (x) => m.personen = x.round())),
        zeile('Kaution', m.kaution == 0 ? '' : euro(m.kaution), () => zahl('Kaution (€)', m.kaution, (x) => m.kaution = x)),
        zeile('Einzug', m.einzug == null ? '' : datumKurz(m.einzug!), () => datum(m.einzug, (d) => m.einzug = d)),
        zeile('Letzte Mieterhöhung', m.letzteErhoehung == null ? '' : datumKurz(m.letzteErhoehung!),
            () => datum(m.letzteErhoehung, (d) => m.letzteErhoehung = d)),
        zeile('Auszug', m.auszug == null ? '' : datumKurz(m.auszug!), () => datum(m.auszug, (d) => m.auszug = d)),
        const Abschnitt('Schreiben'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (art, titel) in mieterSchreiben)
            ActionChip(
              label: Text(titel),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VorlageScreen(
                  titel: titel,
                  text: mieterSchreibenText(art, m, store.vermietung.objekte.where((o) => o.id == m.objektId).firstOrNull,
                      vermieter: store.profil.name, adresse: store.profil.adresse),
                ),
              )),
            ),
        ]),
        const Text('Allgemeine Muster, keine Rechtsberatung. Prüfe Beträge und Fristen.',
            style: TextStyle(color: PT.grau, fontSize: 12)),
        const SizedBox(height: 8),
        if (m.kaltmiete > 0 && m.auszug == null)
          PTKarte(
            farbe: verlangen.isBefore(DateTime.now()) ? PT.orangeHell : Colors.white,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                verlangen.isBefore(DateTime.now())
                    ? 'Mieterhöhung wäre möglich (wirksam frühestens ${datumKurz(wirksam.isBefore(DateTime.now()) ? DateTime.now() : wirksam)})'
                    : 'Mieterhöhung frühestens verlangen ab ${datumKurz(verlangen)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(hinweis, style: const TextStyle(fontSize: 13)),
              const Text('Quelle: §§ 558, 558b BGB. Bei Index- oder Staffelmiete gelten andere Regeln.',
                  style: TextStyle(color: PT.grau, fontSize: 12)),
            ]),
          ),
      ]),
    );
  }
}

class NebenkostenScreen extends StatelessWidget {
  const NebenkostenScreen({super.key, required this.objektId, required this.jahr});

  final String objektId;
  final int jahr;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.vermietung;
    final o = v.objekte.where((x) => x.id == objektId).firstOrNull;
    if (o == null) return Scaffold(appBar: AppBar(), body: const SizedBox());
    var j = v.nebenkosten.where((n) => n.objektId == objektId && n.jahr == jahr).firstOrNull;
    if (j == null) {
      j = Nebenkostenjahr(objektId: objektId, jahr: jahr);
      v.nebenkosten.add(j);
    }
    final jj = j;
    final mieter = v.mieter.where((m) => m.objektId == objektId && bewohnteTage(m, jahr) > 0).toList();
    final gesamt = jj.posten.fold(0.0, (s, p) => s + p.betrag);
    final frist = abrechnungsfrist(jahr);
    return Scaffold(
      appBar: AppBar(
        title: Text('Nebenkosten $jahr'),
        actions: [
          IconButton(
            tooltip: 'Vorjahr',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (_) => NebenkostenScreen(objektId: objektId, jahr: jahr - 1))),
          ),
          IconButton(
            tooltip: 'Folgejahr',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (_) => NebenkostenScreen(objektId: objektId, jahr: jahr + 1))),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PTKarte(
          farbe: PT.orangeHell,
          child: Text('Die Abrechnung muss bis ${datumKurz(frist)} beim Mieter sein – sonst sind Nachforderungen meist '
              'ausgeschlossen (§ 556 Abs. 3 BGB).'),
        ),
        Text(o.adresse, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('Gesamtfläche ${_feld(o.gesamtflaeche)} m² · ${o.einheiten} Wohnungen', style: const TextStyle(color: PT.grau)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Personen im ganzen Haus'),
          subtitle: Text(jj.gesamtpersonen == 0 ? 'nur nötig bei Umlage nach Personen' : '${jj.gesamtpersonen}'),
          onTap: () async {
            final t = await _eingabe(context, 'Personen im Haus', start: '${jj.gesamtpersonen}', zahl: true);
            if (t == null) return;
            jj.gesamtpersonen = int.tryParse(t) ?? 0;
            await store.geaendert();
          },
        ),
        Abschnitt('Kosten des Hauses: ${euro(gesamt)}'),
        for (final p in jj.posten)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.art),
            subtitle: Text(umlageSchluessel[p.schluessel] ?? p.schluessel),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(euro(p.betrag)),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  jj.posten.remove(p);
                  store.geaendert();
                },
              ),
            ]),
          ),
        TextButton.icon(
          onPressed: () async {
            final art = await showDialog<String>(
              context: context,
              builder: (d) => SimpleDialog(title: const Text('Kostenart'), children: [
                for (final a in betriebskostenArten.where((a) => !jj.posten.any((p) => p.art == a)))
                  SimpleDialogOption(onPressed: () => Navigator.pop(d, a), child: Text(a)),
              ]),
            );
            if (art == null || !context.mounted) return;
            final betrag = await _eingabe(context, '$art: Kosten im Jahr $jahr (€)', zahl: true);
            if (betrag == null || !context.mounted) return;
            final schl = await showDialog<String>(
              context: context,
              builder: (d) => SimpleDialog(title: const Text('Wie verteilen?'), children: [
                for (final e in umlageSchluessel.entries)
                  SimpleDialogOption(onPressed: () => Navigator.pop(d, e.key), child: Text(e.value)),
              ]),
            );
            jj.posten.add(Kostenposten(art: art, betrag: _zahl(betrag) ?? 0, schluessel: schl ?? 'flaeche'));
            await store.geaendert();
          },
          icon: const Icon(Icons.add),
          label: const Text('Kosten hinzufügen'),
        ),
        const Text('Heizkosten müssen meist zu 50–70 % nach Verbrauch abgerechnet werden (Heizkostenverordnung) – '
            'trag dafür den Anteil laut Messdienst-Abrechnung je Mieter separat ein.',
            style: TextStyle(color: PT.grau, fontSize: 12)),
        const Abschnitt('Ergebnis je Mieter'),
        if (gesamt == 0)
          const Text('Trag zuerst die Kosten des Hauses ein (Grundsteuer, Wasser, Müll, Versicherung …), '
              'dann rechnet der Tiger Nachzahlung oder Guthaben je Mieter aus.',
              style: TextStyle(color: PT.grau)),
        if (gesamt > 0)
        for (final m in mieter)
          Builder(builder: (_) {
            final r = nebenkostenFuer(m, jj, o);
            return PTKarte(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Kosten ${euro(r.kosten)} − Vorauszahlungen ${euro(r.vorauszahlungen)}'
                    '${r.tage < r.tageImJahr ? ' (${r.tage} Tage)' : ''}'),
                Text(r.saldo >= 0 ? 'Nachzahlung ${euro(r.saldo)}' : 'Guthaben ${euro(-r.saldo)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: r.saldo >= 0 ? PT.orangeDunkel : PT.gruen)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VorlageScreen(
                        titel: 'Betriebskostenabrechnung $jahr',
                        text: abrechnungText(m, jj, o, r, vermieter: store.profil.name, adresse: store.profil.adresse),
                      ),
                    )),
                    child: const Text('Als Brief'),
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

/// Mieteingänge eines Monats mit dem Kontoauszug abgleichen.
class MieteingaengeScreen extends StatefulWidget {
  const MieteingaengeScreen({super.key});

  @override
  State<MieteingaengeScreen> createState() => _MieteingaengeScreenState();
}

class _MieteingaengeScreenState extends State<MieteingaengeScreen> with AuszugQuelle<MieteingaengeScreen> {
  DateTime _monat = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final eingaenge = gutschriftenLesen(auszugText(store.briefe));
    final l = mieteingaenge(store.vermietung.mieter, eingaenge, jahr: _monat.year, monat: _monat.month);
    return Scaffold(
      appBar: AppBar(title: const Text('Mieteingänge')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          IconButton(
              onPressed: () => setState(() => _monat = DateTime(_monat.year, _monat.month - 1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text('${_monat.month}/${_monat.year}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(
              onPressed: () => setState(() => _monat = DateTime(_monat.year, _monat.month + 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        ...quelleAuswahl(store.briefe),
        if (hatQuelle)
          for (final (m, g) in l)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(g == null ? Icons.error_outline : Icons.check_circle, color: g == null ? PT.rot : PT.gruen),
              title: Text(m.name),
              subtitle: Text(g == null
                  ? '${euro(m.warmmiete)} nicht gefunden'
                  : '${euro(g.betrag)} am ${datumKurz(g.datum)}'),
              trailing: g == null
                  ? TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => VorlageScreen(
                          titel: 'Zahlungserinnerung Miete',
                          text: '${store.profil.name}\n${store.profil.adresse}\n\n${m.name}\n${m.wohnung}\n\n'
                              'Betreff: Miete ${_monat.month}/${_monat.year}\n\nGuten Tag ${m.name},\n\n'
                              'die Miete für ${_monat.month}/${_monat.year} über ${euro(m.warmmiete)} ist bei mir noch nicht eingegangen. '
                              'Bitte überweisen Sie den Betrag bis zum [Datum]. Sollte sich Ihre Zahlung mit diesem Schreiben '
                              'überschnitten haben, betrachten Sie es bitte als gegenstandslos.\n\nMit freundlichen Grüßen\n\n${store.profil.name}',
                        ),
                      )),
                      child: const Text('Erinnern'),
                    )
                  : null,
            ),
      ]),
    );
  }
}
