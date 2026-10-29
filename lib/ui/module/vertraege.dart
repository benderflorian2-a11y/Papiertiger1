import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/vertrag_logik.dart';
import '../../logic/vorlagen.dart';
import '../app.dart';
import '../brief_detail.dart';
import '../theme.dart';
import '../vorlage_screen.dart';
import '../widgets/brief_teile.dart';
import '../widgets/common.dart';

Vertrag? _finde(List<Vertrag> l, String id) {
  for (final v in l) {
    if (v.id == id) return v;
  }
  return null;
}

String zahlweiseName(int m) => zahlweisen.firstWhere((z) => z.$1 == m, orElse: () => (m, '')).$2;

IconData vertragIcon(Vertrag v) => switch (v.art) {
      'Handy' => Icons.smartphone_outlined,
      'Internet' => Icons.wifi,
      'Strom' => Icons.bolt_outlined,
      'Gas' => Icons.local_fire_department_outlined,
      'Fitnessstudio' => Icons.fitness_center_outlined,
      'Streaming' => Icons.live_tv_outlined,
      'Versicherung' => Icons.shield_outlined,
      'Zeitschrift' => Icons.newspaper_outlined,
      _ => Icons.description_outlined,
    };

class VertraegeScreen extends StatelessWidget {
  const VertraegeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final aktiv = store.vertraege.where((v) => !v.gekuendigt).toList()
      ..sort((a, b) => kuendigungsInfo(a).kuendigenBis.compareTo(kuendigungsInfo(b).kuendigenBis));
    final gekuendigt = store.vertraege.where((v) => v.gekuendigt).toList();
    final kosten = kostenUebersicht(store.vertraege);
    final versicherungen = aktiv.where((v) => v.art == 'Versicherung').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Verträge & Abos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VertragFormular())),
        icon: const Icon(Icons.add),
        label: const Text('Vertrag'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (store.vertraege.isEmpty)
            const LeerHinweis(
                icon: Icons.description_outlined,
                text: 'Trag deine Verträge ein – Handy, Strom, Versicherungen, Fitnessstudio. '
                    'Oder öffne einen Brief deines Anbieters und tippe auf „Als Vertrag speichern“. '
                    'Der Tiger sagt dir, bis wann du kündigen musst.')
          else ...[
            if (kosten.monat > 0)
              PTKarte(
                farbe: PT.orangeHell,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Laufende Kosten', style: TextStyle(color: PT.grau)),
                    Text('${euro(kosten.monat)} im Monat',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('${euro(kosten.jahr)} im Jahr', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (kosten.nachArt.length > 1) ...[
                      const SizedBox(height: 10),
                      for (final (art, betrag) in kosten.nachArt)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            Expanded(child: Text(art)),
                            Text('${euro(betrag)} / Monat', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                        ),
                    ],
                  ],
                ),
              ),
            if (versicherungen.isNotEmpty || aktiv.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const VersicherungsUeberblick())),
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: Text('Versicherungen im Überblick (${versicherungen.length})'),
                ),
              ),
            for (final v in aktiv) VertragZeile(v),
            if (gekuendigt.isNotEmpty) ...[
              const Abschnitt('Gekündigt'),
              for (final v in gekuendigt) VertragZeile(v),
            ],
          ],
        ],
      ),
    );
  }
}

class VertragZeile extends StatelessWidget {
  const VertragZeile(this.v, {super.key});

  final Vertrag v;

  @override
  Widget build(BuildContext context) {
    final info = kuendigungsInfo(v);
    final pruefen = bestaetigungPruefenAb(v);
    return PTKarte(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VertragDetail(vertragId: v.id))),
      child: Row(
        children: [
          IconKachel(vertragIcon(v)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.anbieter, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(
                  [
                    v.versicherungsArt ?? v.art,
                    if (v.kostenMonat != null) '${euro(v.kostenMonat!)}/Monat',
                    if (v.gekuendigt)
                      v.bestaetigt ? 'gekündigt, bestätigt' : 'gekündigt, Bestätigung fehlt'
                    else
                      'kündigen bis ${datumKurz(info.kuendigenBis)}',
                  ].join(' · '),
                  style: const TextStyle(color: PT.grau, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!v.gekuendigt)
            FristEtikett(info.kuendigenBis)
          else if (pruefen != null)
            const Etikett('Bestätigung?', farbe: PT.gelb, hintergrund: PT.gelbHell),
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
      return Scaffold(appBar: AppBar(), body: const LeerHinweis(icon: Icons.description_outlined, text: 'Gelöscht.'));
    }
    final info = kuendigungsInfo(v);
    final briefe = store.briefe.where((b) => vertragZuBrief(b, [v]) != null).toList()
      ..sort((a, b) => (b.briefDatum ?? b.erstellt).compareTo(a.briefDatum ?? a.erstellt));
    final erhoehung = [
      for (final b in briefe)
        if (preisaenderungFinden(b.text) case final p?) (b, p),
    ].firstOrNull;
    final widerruf = v.gekuendigt ? null : widerrufBis(v);

    void vorlage(String titel, String text) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => VorlageScreen(titel: titel, text: text)));

    return Scaffold(
      appBar: AppBar(
        title: Text(v.anbieter),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => VertragFormular(vertrag: v))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Löschen',
            onPressed: () async {
              final ja = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text('${v.anbieter} löschen?'),
                  content: const Text('Die Briefe bleiben im Archiv.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
                    TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Löschen')),
                  ],
                ),
              );
              if (ja != true || !context.mounted) return;
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
                if (v.gekuendigt) ...[
                  Text(v.gekuendigtAm != null ? 'Gekündigt am ${datumKurz(v.gekuendigtAm!)}' : 'Gekündigt',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Der Vertrag endet voraussichtlich am ${datumLang(info.endetAm)}.'),
                ] else ...[
                  const Text('Spätestens kündigen bis', style: TextStyle(color: PT.grau)),
                  const SizedBox(height: 4),
                  Text(datumLang(info.kuendigenBis),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Der Vertrag endet dann am ${datumLang(info.endetAm)}.'),
                  const SizedBox(height: 8),
                  Text(info.hinweis, style: const TextStyle(color: PT.grau, fontSize: 13)),
                ],
              ],
            ),
          ),
          if (v.gekuendigt)
            PTKarte(
              farbe: v.bestaetigt ? Colors.white : PT.gelbHell,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                title: const Text('Kündigungsbestätigung erhalten', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: v.bestaetigt
                    ? null
                    : Text(bestaetigungPruefenAb(v) == null
                        ? 'Bewahre die Bestätigung gut auf.'
                        : 'Kommt bis ${datumKurz(bestaetigungPruefenAb(v)!)} keine Bestätigung, erinnert dich der Tiger.'),
                value: v.bestaetigt,
                onChanged: (x) {
                  v.bestaetigt = x;
                  store.geaendert();
                },
              ),
            ),
          if (erhoehung != null && !v.gekuendigt)
            PTKarte(
              farbe: PT.gelbHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preis- oder Beitragserhöhung angekündigt',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text([
                    if (erhoehung.$2.alt != null && erhoehung.$2.neu != null)
                      'Von ${euro(erhoehung.$2.alt!)} auf ${euro(erhoehung.$2.neu!)}.',
                    if (erhoehung.$2.ab != null) 'Gilt ab ${datumKurz(erhoehung.$2.ab!)}.',
                    'Bei einer Erhöhung gibt es oft ein Sonderkündigungsrecht. Ob und bis wann, steht meist im Schreiben – bitte dort prüfen.',
                  ].join(' ')),
                  TextButton(
                    onPressed: () => vorlage(
                        'Sonderkündigung',
                        sonderkuendigungText(v, store.profil,
                            ab: erhoehung.$2.ab, schreibenVom: erhoehung.$1.briefDatum)),
                    child: const Text('Sonderkündigung schreiben'),
                  ),
                ],
              ),
            ),
          if (widerruf != null)
            PTKarte(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gerade erst abgeschlossen?', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('Verträge, die du online, am Telefon oder an der Haustür abgeschlossen hast, kannst du meist '
                      '14 Tage ab Vertragsschluss widerrufen – hier ungefähr bis ${datumKurz(widerruf)}.'),
                  TextButton(
                    onPressed: () => vorlage('Widerruf', widerrufText(v, store.profil)),
                    child: const Text('Widerruf schreiben'),
                  ),
                ],
              ),
            ),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(title: const Text('Art'), trailing: Text(v.versicherungsArt ?? v.art)),
                if (v.nummer != null && v.nummer!.isNotEmpty)
                  ListTile(title: const Text('Nummer'), trailing: SelectableText(v.nummer!)),
                ListTile(title: const Text('Beginn'), trailing: Text(datumKurz(v.beginn))),
                ListTile(
                    title: const Text('Mindestlaufzeit'),
                    trailing: Text(v.laufzeitMonate == 0 ? 'keine' : '${v.laufzeitMonate} Monate')),
                ListTile(
                    title: const Text('Kündigungsfrist'),
                    trailing: Text(
                        '${v.fristWert} ${v.fristInWochen ? 'Wochen' : (v.fristWert == 1 ? 'Monat' : 'Monate')}')),
                if (v.kostenMonat != null)
                  ListTile(
                    title: const Text('Kosten'),
                    trailing: Text(v.zahlweiseMonate == 1
                        ? '${euro(v.kostenMonat!)} / Monat'
                        : '${euro(v.betragProZahlung!)} ${zahlweiseName(v.zahlweiseMonate)}'),
                    subtitle: v.zahlweiseMonate == 1 ? null : Text('entspricht ${euro(v.kostenMonat!)} im Monat'),
                  ),
                if (v.notiz.isNotEmpty) ListTile(title: const Text('Notiz'), subtitle: Text(v.notiz)),
              ],
            ),
          ),
          if (!v.gekuendigt) ...[
            FilledButton.icon(
              onPressed: () => vorlage('Kündigung', kuendigungText(v, store.profil, zum: info.endetAm)),
              icon: const Icon(Icons.edit_note),
              label: const Text('Kündigungsschreiben erstellen'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await datumWaehlen(context, start: DateTime.now());
                if (d == null) return;
                v
                  ..gekuendigt = true
                  ..gekuendigtAm = d
                  ..bestaetigt = false;
                await store.geaendert();
                if (context.mounted) {
                  zeigeHinweis(context, 'Vermerkt. Der Tiger erinnert dich, falls keine Bestätigung kommt.');
                }
              },
              icon: const Icon(Icons.outgoing_mail),
              label: const Text('Kündigung verschickt'),
            ),
          ] else
            OutlinedButton(
              onPressed: () {
                v
                  ..gekuendigt = false
                  ..gekuendigtAm = null
                  ..bestaetigt = false;
                store.geaendert();
              },
              child: const Text('Doch nicht gekündigt'),
            ),
          if (briefe.isNotEmpty) ...[
            const Abschnitt('Briefe zu diesem Vertrag'),
            for (final b in briefe)
              BriefZeile(
                brief: b,
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id))),
              ),
          ],
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

/// Welche Versicherungen eingetragen sind und was sie kosten. Keine Empfehlung.
class VersicherungsUeberblick extends StatelessWidget {
  const VersicherungsUeberblick({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final aktiv = store.vertraege.where((v) => v.art == 'Versicherung' && !v.gekuendigt).toList();
    final summe = aktiv.fold<double>(0, (s, v) => s + (v.kostenMonat ?? 0));
    final vorhanden = {for (final v in aktiv) v.versicherungsArt ?? 'Sonstige'};
    return Scaffold(
      appBar: AppBar(title: const Text('Versicherungen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PTKarte(
            farbe: PT.orangeHell,
            child: Text(
              aktiv.isEmpty
                  ? 'Noch keine Versicherung eingetragen.'
                  : '${aktiv.length} ${aktiv.length == 1 ? 'Versicherung' : 'Versicherungen'}'
                      '${summe > 0 ? ' · ${euro(summe)} im Monat · ${euro(summe * 12)} im Jahr' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final v in aktiv) VertragZeile(v),
          const Abschnitt('Übliche Versicherungsarten'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final a in versicherungsArten.where((a) => a != 'Sonstige'))
                  ListTile(
                    dense: true,
                    leading: Icon(vorhanden.contains(a) ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: vorhanden.contains(a) ? PT.gruen : PT.grau),
                    title: Text(a),
                    trailing: vorhanden.contains(a) ? const Text('eingetragen') : null,
                  ),
              ],
            ),
          ),
          const Text(
            'Nur ein Überblick über deine Einträge, keine Beratung. Welche Versicherung sinnvoll ist, hängt von deiner '
            'Lebenssituation ab – unabhängig informieren z. B. die Verbraucherzentralen.',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class VertragFormular extends StatefulWidget {
  const VertragFormular({super.key, this.vertrag, this.vorschlag, this.briefId});

  /// Bestehender Vertrag zum Bearbeiten.
  final Vertrag? vertrag;

  /// Neuer, vorausgefüllter Vertrag (z. B. aus einem Brief).
  final Vertrag? vorschlag;

  /// Brief, aus dem der Vertrag angelegt wird.
  final String? briefId;

  @override
  State<VertragFormular> createState() => _VertragFormularState();
}

class _VertragFormularState extends State<VertragFormular> {
  late final Vertrag? _start = widget.vertrag ?? widget.vorschlag;
  late final _anbieter = TextEditingController(text: _start?.anbieter ?? '');
  late final _nummer = TextEditingController(text: _start?.nummer ?? '');
  late final _notiz = TextEditingController(text: _start?.notiz ?? '');
  late final _betrag = TextEditingController(
      text: _start?.betragProZahlung?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
  late String _art = vertragsArten.contains(_start?.art) ? _start!.art : vertragsArten.first;
  late String? _versArt = _start?.versicherungsArt;
  late DateTime _beginn = _start?.beginn ?? DateTime.now();
  late int _laufzeit = _start?.laufzeitMonate ?? 24;
  late int _fristWert = _start?.fristWert ?? 1;
  late bool _wochen = _start?.fristInWochen ?? false;
  late int _zahlweise = _start?.zahlweiseMonate ?? 1;

  @override
  void dispose() {
    _anbieter.dispose();
    _nummer.dispose();
    _notiz.dispose();
    _betrag.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    if (_anbieter.text.trim().isEmpty) {
      zeigeHinweis(context, 'Bitte einen Anbieter eintragen.');
      return;
    }
    final store = StoreScope.of(context);
    final v = widget.vertrag ?? Vertrag(id: neueId(), anbieter: '', art: _art, beginn: _beginn);
    final betrag = double.tryParse(_betrag.text.replaceAll('.', '').replaceAll(',', '.'));
    v
      ..anbieter = _anbieter.text.trim()
      ..art = _art
      ..versicherungsArt = _art == 'Versicherung' ? _versArt : null
      ..beginn = _beginn
      ..laufzeitMonate = _laufzeit
      ..fristWert = _fristWert
      ..fristInWochen = _wochen
      ..zahlweiseMonate = _zahlweise
      ..kostenMonat = betrag == null ? null : (betrag / _zahlweise * 100).round() / 100
      ..nummer = _nummer.text.trim().isEmpty ? null : _nummer.text.trim()
      ..notiz = _notiz.text.trim();
    if (widget.briefId != null && !v.briefIds.contains(widget.briefId)) v.briefIds.add(widget.briefId!);
    await store.vertragSpeichern(v);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _chips<T>(List<(T, String)> werte, T gewaehlt, void Function(T) setzen) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (wert, name) in werte)
            ChoiceChip(label: Text(name), selected: gewaehlt == wert, onSelected: (_) => setState(() => setzen(wert))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final laufzeiten = {0, 1, 12, 24, _laufzeit}.toList()..sort();
    final fristen = {(2, true), (4, true), (1, false), (3, false), (_fristWert, _wochen)}.toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.vertrag == null ? 'Neuer Vertrag' : 'Vertrag bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.vorschlag != null)
            const PTKarte(
              farbe: PT.orangeHell,
              child: Text('Der Tiger hat die Angaben aus dem Brief übernommen. Bitte prüfen und ergänzen.'),
            ),
          TextField(
            controller: _anbieter,
            textCapitalization: TextCapitalization.words,
            decoration: feld(labelText: 'Anbieter', hintText: 'z. B. Vodafone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nummer,
            decoration: feld(labelText: 'Vertrags- oder Kundennummer (optional)'),
          ),
          const SizedBox(height: 16),
          const Text('Art', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _chips([for (final a in vertragsArten) (a, a)], _art, (a) => _art = a),
          if (_art == 'Versicherung') ...[
            const SizedBox(height: 16),
            const Text('Welche Versicherung?', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _chips<String?>([for (final a in versicherungsArten) (a, a)], _versArt, (a) => _versArt = a),
          ],
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
          _chips([for (final m in laufzeiten) (m, m == 0 ? 'Keine' : '$m ${m == 1 ? 'Monat' : 'Monate'}')], _laufzeit,
              (m) => _laufzeit = m),
          const SizedBox(height: 16),
          const Text('Kündigungsfrist', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _chips([
            for (final f in fristen) (f, '${f.$1} ${f.$2 ? 'Wochen' : (f.$1 == 1 ? 'Monat' : 'Monate')}'),
          ], (_fristWert, _wochen), (f) {
            _fristWert = f.$1;
            _wochen = f.$2;
          }),
          const SizedBox(height: 16),
          const Text('Zahlweise', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _chips(zahlweisen, _zahlweise, (z) => _zahlweise = z),
          const SizedBox(height: 12),
          TextField(
            controller: _betrag,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Betrag ${zahlweiseName(_zahlweise)} (optional)', suffixText: '€'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notiz,
            minLines: 2,
            maxLines: 4,
            decoration: feld(labelText: 'Notiz (optional)', hintText: 'z. B. Kundenkonto-Login, Ansprechpartner'),
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

/// Im Brief: zugehöriger Vertrag oder „Als Vertrag speichern“.
class BriefVertragKarte extends StatelessWidget {
  const BriefVertragKarte({super.key, required this.brief});

  final Brief brief;

  static const _vertragsKategorien = {'versicherung', 'telefon', 'energie'};

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = brief;
    final v = vertragZuBrief(b, store.vertraege);
    if (v != null) {
      final info = kuendigungsInfo(v);
      final erhoehung = v.gekuendigt ? null : preisaenderungFinden(b.text);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Icon(vertragIcon(v), color: PT.orangeDunkel),
              title: Text('Vertrag: ${v.anbieter}'),
              subtitle: Text(v.gekuendigt ? 'gekündigt' : 'kündigen bis ${datumKurz(info.kuendigenBis)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => VertragDetail(vertragId: v.id))),
            ),
          ),
          if (erhoehung != null)
            PTKarte(
              farbe: PT.gelbHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preiserhöhung: Sonderkündigung möglich?', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Text('Bei einer Erhöhung gibt es oft ein Sonderkündigungsrecht. '
                      'Ob und bis wann, steht meist im Schreiben – bitte dort prüfen.'),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VorlageScreen(
                        titel: 'Sonderkündigung',
                        text: sonderkuendigungText(v, store.profil, ab: erhoehung.ab, schreibenVom: b.briefDatum),
                        brief: b,
                      ),
                    )),
                    child: const Text('Sonderkündigung schreiben'),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    final vorschlag = vertragAusText(b.text);
    if (!vorschlag.gefunden && !_vertragsKategorien.contains(b.kategorie)) return const SizedBox.shrink();
    return PTKarte(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.add_card_outlined, color: PT.orangeDunkel),
        title: const Text('Als Vertrag speichern'),
        subtitle: const Text('Der Tiger behält Kündigungsfrist und Kosten im Blick.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VertragFormular(
            vorschlag: vorschlag.alsVertrag(
                id: neueId(), anbieter: b.absenderName ?? '', heute: b.briefDatum ?? b.erstellt),
            briefId: b.id,
          ),
        )),
      ),
    );
  }
}
