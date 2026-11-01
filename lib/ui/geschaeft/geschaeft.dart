import 'package:flutter/material.dart';

import '../../data/geschaeft.dart';
import '../../data/models.dart';
import '../../logic/android_kanal.dart';
import '../../logic/datev.dart';
import '../../logic/erechnung.dart';
import '../../logic/export.dart';
import '../../logic/kalkulation.dart';
import '../../logic/lebenslage.dart';
import '../../logic/kommunikation.dart';
import '../../logic/marketing.dart';
import '../../logic/rechnungen.dart';
import '../app.dart';
import '../theme.dart';
import '../vorlage_screen.dart';
import '../widgets/common.dart';
import 'katalog.dart';
import 'marketing.dart';
import 'plantafel.dart';
import 'stempeluhr.dart';
import 'projekte.dart';
import '../ki_text.dart';
import '../kontoauszug.dart';
import '../ueberweisung.dart';

Rechnung? _rechnung(List<Rechnung> l, String id) {
  for (final r in l) {
    if (r.id == id) return r;
  }
  return null;
}

double? _zahl(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim());
String _feld(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

/// Startseite für Selbstständige.
class GeschaeftScreen extends StatelessWidget {
  const GeschaeftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = store.firma;
    final jahr = DateTime.now().year;
    final u = ueberschuss(
        z: Zeitraum.jahr(jahr), rechnungen: store.rechnungen, belege: store.belege, kleinunternehmer: f.kleinunternehmer);
    final liste = [...store.rechnungen]..sort((a, b) {
        final oa = istOffen(a) ? 0 : 1, ob = istOffen(b) ? 0 : 1;
        if (oa != ob) return oa.compareTo(ob);
        return b.datum.compareTo(a.datum);
      });
    void oeffne(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(title: Text(f.leer ? 'Mein Gewerbe' : f.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => oeffne(const RechnungFormular(art: 'rechnung')),
        icon: const Icon(Icons.add),
        label: const Text('Rechnung'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (f.leer)
            PTKarte(
              farbe: PT.orangeHell,
              onTap: () => oeffne(const FirmaScreen()),
              child: const Row(children: [
                Icon(Icons.storefront_outlined, color: PT.orangeDunkel),
                SizedBox(width: 12),
                Expanded(child: Text('Trag zuerst deine Firmendaten ein – sie stehen dann auf jeder Rechnung.')),
                Icon(Icons.chevron_right),
              ]),
            ),
          PTKarte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$jahr bisher', style: const TextStyle(color: PT.grau)),
                const SizedBox(height: 6),
                _kennzahl('Einnahmen (netto, bezahlt)', euro(u.einnahmenNetto)),
                if (!f.kleinunternehmer) _kennzahl('Eingenommene Umsatzsteuer', euro(u.ustEingenommen)),
                _kennzahl('Geschäftliche Ausgaben', euro(u.ausgaben)),
                const Divider(),
                _kennzahl('Überschuss (vor Steuern)', euro(u.gewinnVorSteuer), fett: true),
                if (u.offen > 0) _kennzahl('Noch offen', euro(u.offen)),
              ],
            ),
          ),
          if (ruecklageVorschlag(u).gesamt > 0)
            PTKarte(
              farbe: PT.gelbHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Für Steuern zurücklegen: ca. ${euro(ruecklageVorschlag(u).gesamt)}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                    '${f.kleinunternehmer ? '' : 'Umsatzsteuer ${euro(ruecklageVorschlag(u).umsatzsteuer)} + '}'
                    '30 % vom Überschuss ${euro(ruecklageVorschlag(u).einkommensteuer)}. Faustregel – den genauen Betrag kennt deine Steuerberatung.',
                    style: const TextStyle(fontSize: 13)),
                TextButton.icon(
                  onPressed: () async {
                    final ziel = ruecklageVorschlag(u).gesamt;
                    final vorhanden = store.sparziele.where((z) => z.name == 'Steuer-Rücklage $jahr').firstOrNull;
                    if (vorhanden != null) {
                      vorhanden.ziel = ziel;
                    } else {
                      store.sparziele.add(Sparziel(id: neueId(), name: 'Steuer-Rücklage $jahr', ziel: ziel, bis: DateTime(jahr + 1, 5, 31)));
                    }
                    await store.geaendert();
                    if (context.mounted) zeigeHinweis(context, 'Als Sparziel unter Finanzen gespeichert.');
                  },
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: const Text('Als Sparziel anlegen'),
                ),
              ]),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(
                avatar: const Icon(Icons.request_quote_outlined, size: 18),
                label: const Text('Angebot'),
                onPressed: () => oeffne(const RechnungFormular(art: 'angebot'))),
            ActionChip(
                avatar: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Kostenvoranschlag'),
                onPressed: () => oeffne(const RechnungFormular(art: 'kostenvoranschlag'))),
            ActionChip(
                avatar: const Icon(Icons.work_outline, size: 18),
                label: const Text('Projekte'),
                onPressed: () => oeffne(const ProjekteScreen())),
            if (handwerkSichtbar(store.lebenslagen))
            ActionChip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text(store.stempel.isEmpty ? 'Stempeluhr' : 'Stempeluhr (${store.stempel.length} läuft)'),
                onPressed: () => oeffne(const StempeluhrScreen())),
            if (handwerkSichtbar(store.lebenslagen))
            ActionChip(
                avatar: const Icon(Icons.calendar_view_week_outlined, size: 18),
                label: const Text('Plantafel'),
                onPressed: () => oeffne(const PlantafelScreen())),
            ActionChip(
                avatar: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Katalog'),
                onPressed: () => oeffne(const KatalogScreen())),
            ActionChip(
                avatar: const Icon(Icons.people_outline, size: 18),
                label: const Text('Kunden'),
                onPressed: () => oeffne(const KundenScreen())),
            ActionChip(
                avatar: const Icon(Icons.price_check, size: 18),
                label: const Text('Zahlungseingänge'),
                onPressed: () => oeffne(const ZahlungseingaengeScreen())),
            ActionChip(
                avatar: const Icon(Icons.bar_chart, size: 18),
                label: const Text('Einnahmen & Ausgaben'),
                onPressed: () => oeffne(const EuerScreen())),
            ActionChip(
                avatar: const Icon(Icons.campaign_outlined, size: 18),
                label: const Text('Marketing'),
                onPressed: () => oeffne(const MarketingScreen())),
            ActionChip(
                avatar: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Firmendaten'),
                onPressed: () => oeffne(const FirmaScreen())),
          ]),
          const Abschnitt('Rechnungen und Angebote'),
          if (liste.isEmpty)
            const LeerHinweis(
                icon: Icons.receipt_outlined,
                text: 'Noch keine Rechnung. Tippe auf „Rechnung“ – der Tiger setzt Nummer, Datum und Summen.')
          else
            for (final r in liste) RechnungZeile(r),
          const SizedBox(height: 8),
          const Text(
            'Vereinfachte Übersicht nach Zahlungseingang, keine Buchhaltung im Sinne der GoBD und keine Steuerberatung. '
            'Ab 2027/2028 müssen viele Firmen E-Rechnungen (XRechnung/ZUGFeRD) verschicken – frag dazu deine Steuerberatung.',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _kennzahl(String a, String b, {bool fett = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(fontWeight: fett ? FontWeight.w800 : FontWeight.w400))),
          Text(b, style: TextStyle(fontWeight: fett ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

class RechnungZeile extends StatelessWidget {
  const RechnungZeile(this.r, {super.key});

  final Rechnung r;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final k = store.kundeMitId(r.kundeId);
    final s = zuZahlen(r, store.rechnungen, kleinunternehmer: store.firma.kleinunternehmer);
    final (text, farbe, grund) = r.storniert
        ? ('storniert', PT.grau, PT.sand)
        : !r.istRechnung
            ? (r.artName, PT.orangeDunkel, PT.orangeHell)
            : r.bezahltAm != null
                ? ('bezahlt', PT.gruen, PT.gruenHell)
                : ueberfaellig(r)
                    ? ('überfällig', PT.rot, PT.rotHell)
                    : ('offen', PT.gelb, PT.gelbHell);
    return PTKarte(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RechnungDetail(rechnungId: r.id))),
      child: Row(children: [
        IconKachel(r.istRechnung ? Icons.receipt_outlined : Icons.request_quote_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.nummer} · ${k?.name ?? 'ohne Kunde'}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${datumKurz(r.datum)} · ${euro(s.brutto)}', style: const TextStyle(color: PT.grau, fontSize: 13)),
          ]),
        ),
        Etikett(text, farbe: farbe, hintergrund: grund),
      ]),
    );
  }
}

class RechnungDetail extends StatelessWidget {
  const RechnungDetail({super.key, required this.rechnungId});

  final String rechnungId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = _rechnung(store.rechnungen, rechnungId);
    if (r == null) return Scaffold(appBar: AppBar(), body: const LeerHinweis(icon: Icons.receipt_outlined, text: 'Gelöscht.'));
    final f = store.firma;
    final k = store.kundeMitId(r.kundeId);
    final s = summenVon(r, kleinunternehmer: f.kleinunternehmer);
    final zahlen = zuZahlen(r, store.rechnungen, kleinunternehmer: f.kleinunternehmer);
    final abschlaege = r.art == 'schluss' ? abschlaegeZu(r, store.rechnungen) : <Rechnung>[];
    final fehlt = fehlendeAngaben(r, f, k);
    final titel = r.artName;
    final qr = r.istRechnung && zahlen.brutto > 0
        ? giroCode(name: f.name, iban: f.iban, bic: f.bic, betrag: zahlen.brutto, zweck: '$titel ${r.nummer}')
        : '';

    // Sobald ein PDF die App verlässt, ist die Rechnung festgeschrieben (GoBD).
    Future<void> festschreiben() async {
      if (r.istRechnung && r.festAm == null) {
        r.festAm = DateTime.now();
        await store.geaendert();
      }
    }

    Future<void> korrigieren() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Rechnung ist festgeschrieben'),
          content: Text('Rechnung ${r.nummer} wurde schon erzeugt oder verschickt. Nach den GoBD darfst du sie nicht mehr '
              'ändern. Der Tiger storniert sie und legt eine neue Rechnung mit neuer Nummer an, die du bearbeiten kannst.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Stornieren und neu')),
          ],
        ),
      );
      if (ok != true) return;
      r.storniert = true;
      final neu = Rechnung.fromJson({
        ...r.toJson(),
        'id': neueId(),
        'nummer': naechsteNummer(store.rechnungen, art: r.art, jahr: DateTime.now().year),
        'datum': DateTime.now().toIso8601String(),
        'bezahltAm': null,
        'gemahntAm': null,
        'mahnstufe': 0,
        'versendetAm': null,
        'festAm': null,
        'storniert': false,
        'notiz': 'Ersetzt Rechnung ${r.nummer}.${r.notiz.isEmpty ? '' : ' ${r.notiz}'}',
      });
      await store.rechnungSpeichern(neu);
      if (context.mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RechnungFormular(art: neu.art, rechnung: neu)));
      }
    }

    Future<void> pdfTeilen() async {
      final datei = await rechnungAlsPdf(r, f, k, alle: store.rechnungen);
      await festschreiben();
      await dateiTeilen(datei.path,
          mimeType: 'application/pdf', text: '$titel ${r.nummer} über ${euro(zahlen.brutto)}');
    }

    final eFehlt = eRechnungFehlt(r, f, k);

    Future<String> xmlDatei() async =>
        (await textDatei('XRechnung ${r.nummer}.xml', xRechnung(r, f, k!, alle: store.rechnungen))).path;

    Future<void> senden() async {
      final datei = await rechnungAlsPdf(r, f, k, alle: store.rechnungen);
      await festschreiben();
      final ok = await mailMitAnhang(
        an: k?.email ?? '',
        betreff: '$titel ${r.nummer}${f.name.isEmpty ? '' : ' – ${f.name}'}',
        text: begleitText(r, f, k, zahlen),
        pfade: [datei.path, if (r.istRechnung && eFehlt.isEmpty) await xmlDatei()],
      );
      if (!context.mounted) return;
      if (!ok) {
        zeigeHinweis(context, 'Keine E-Mail-App gefunden – das PDF wird zum Teilen angeboten.');
        await pdfTeilen();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 15),
        content: const Text('In der E-Mail-App abgeschickt?'),
        action: SnackBarAction(
          label: 'Ja, vermerken',
          onPressed: () {
            r.versendetAm = DateTime.now();
            store.geaendert();
          },
        ),
      ));
    }

    Future<void> neuerBeleg(Rechnung neu) async {
      await store.rechnungSpeichern(neu);
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RechnungFormular(art: neu.art, rechnung: neu)));
      }
    }

    Future<void> abschlagErstellen() async {
      final c = TextEditingController(text: '30');
      final pz = await showDialog<double>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Abschlagsrechnung'),
          content: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(labelText: 'Wie viel Prozent der Auftragssumme?', suffixText: '%'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, double.tryParse(c.text.replaceAll(',', '.'))), child: const Text('Erstellen')),
          ],
        ),
      );
      c.dispose();
      if (pz == null || pz <= 0 || pz > 100) return;
      await neuerBeleg(abschlagAus(r, store.rechnungen,
          id: neueId(), datum: DateTime.now(), prozent: pz, zahlungszielTage: f.zahlungszielTage));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$titel ${r.nummer}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
            onPressed: r.festgeschrieben
                ? (r.storniert ? null : korrigieren)
                : () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => RechnungFormular(art: r.art, rechnung: r))),
          ),
          PopupMenuButton<String>(
            onSelected: (w) async {
              if (w == 'kopie') {
                final neu = Rechnung.fromJson({
                  ...r.toJson(),
                  'id': neueId(),
                  'nummer': naechsteNummer(store.rechnungen, art: r.art, jahr: DateTime.now().year),
                  'datum': DateTime.now().toIso8601String(),
                  'bezahltAm': null,
                  'gemahntAm': null,
                  'mahnstufe': 0,
                  'versendetAm': null,
                  'festAm': null,
                  'storniert': false,
                });
                await store.rechnungSpeichern(neu);
                if (context.mounted) {
                  Navigator.of(context)
                      .pushReplacement(MaterialPageRoute(builder: (_) => RechnungDetail(rechnungId: neu.id)));
                }
              } else if (w == 'storno') {
                r.storniert = !r.storniert;
                await store.geaendert();
              } else if (w == 'fest') {
                await festschreiben();
              } else if (w == 'loeschen') {
                Navigator.of(context).pop();
                await store.rechnungLoeschen(r);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'kopie', child: Text('Kopie als neue(s) $titel')),
              if (r.istRechnung && !(r.storniert && r.festgeschrieben))
                PopupMenuItem(value: 'storno', child: Text(r.storniert ? 'Storno aufheben' : 'Stornieren')),
              if (r.istRechnung && !r.festgeschrieben) const PopupMenuItem(value: 'fest', child: Text('Festschreiben')),
              if (!r.festgeschrieben) const PopupMenuItem(value: 'loeschen', child: Text('Löschen')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (fehlt.isNotEmpty)
            PTKarte(
              farbe: PT.gelbHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Es fehlen noch Angaben', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final x in fehlt) Text('• $x'),
              ]),
            ),
          PTKarte(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k?.name ?? 'Kein Kunde gewählt', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('Datum ${datumKurz(r.datum)}${!r.istRechnung ? '' : ' · fällig ${datumKurz(faelligAm(r))}'}',
                  style: const TextStyle(color: PT.grau)),
              const Divider(),
              for (final p in r.positionen)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${_feld(p.menge)} ${p.einheit} ${p.text}')),
                    Text(euro(p.netto)),
                  ]),
                ),
              const Divider(),
              if (s.rabatt > 0) ...[
                Row(children: [const Expanded(child: Text('Zwischensumme')), Text(euro(s.zwischensumme))]),
                Row(children: [const Expanded(child: Text('Rabatt')), Text('-${euro(s.rabatt)}')]),
              ],
              if (!f.kleinunternehmer) ...[
                Row(children: [const Expanded(child: Text('Netto')), Text(euro(s.netto))]),
                for (final e in s.ust.entries)
                  Row(children: [Expanded(child: Text('USt ${e.key} %')), Text(euro(e.value))]),
              ],
              Row(children: [
                const Expanded(child: Text('Gesamt', style: TextStyle(fontWeight: FontWeight.w800))),
                Text(euro(s.brutto), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              for (final a in abschlaege)
                Row(children: [
                  Expanded(child: Text('abzgl. Abschlag ${a.nummer}${a.bezahltAm == null ? ' (noch offen)' : ''}')),
                  Text('-${euro(summenVon(a, kleinunternehmer: f.kleinunternehmer).brutto)}'),
                ]),
              if (abschlaege.isNotEmpty)
                Row(children: [
                  const Expanded(child: Text('Noch zu zahlen', style: TextStyle(fontWeight: FontWeight.w800))),
                  Text(euro(zahlen.brutto), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              if (r.festgeschrieben && r.versendetAm == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Festgeschrieben${r.festAm == null ? '' : ' am ${datumKurz(r.festAm!)}'} – ändern nur über Storno',
                      style: const TextStyle(color: PT.grau, fontSize: 13)),
                ),
              if (r.versendetAm != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Verschickt am ${datumKurz(r.versendetAm!)}', style: const TextStyle(color: PT.gruen)),
                ),
            ]),
          ),
          if (r.istRechnung && !r.storniert)
            PTKarte(
              farbe: r.bezahltAm != null ? PT.gruenHell : (ueberfaellig(r) ? PT.rotHell : Colors.white),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                title: Text(r.bezahltAm != null ? 'Bezahlt am ${datumKurz(r.bezahltAm!)}' : 'Noch nicht bezahlt',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: r.bezahltAm == null && ueberfaellig(r) ? const Text('Seit dem Fälligkeitsdatum überfällig') : null,
                value: r.bezahltAm != null,
                onChanged: (v) async {
                  if (v) {
                    final d = await datumWaehlen(context, start: DateTime.now());
                    if (d == null) return;
                    r.bezahltAm = d;
                    final rl = ruecklageFuer(r, store.rechnungen, kleinunternehmer: f.kleinunternehmer);
                    if (context.mounted && rl > 0) {
                      zeigeHinweis(context, 'Bezahlt! Leg davon etwa ${euro(rl)} für die Steuer zurück (Faustregel).');
                    }
                  } else {
                    r.bezahltAm = null;
                  }
                  await store.geaendert();
                },
              ),
            ),
          if (naechsteWiederholung(r, store.rechnungen) != null)
            PTKarte(
              farbe: PT.orangeHell,
              child: Row(children: [
                const Icon(Icons.repeat, color: PT.orangeDunkel),
                const SizedBox(width: 12),
                Expanded(child: Text('Nächste Rechnung am ${datumKurz(naechsteWiederholung(r, store.rechnungen)!)}')),
                TextButton(
                  onPressed: () async {
                    final neu = folgeRechnung(r, store.rechnungen,
                        id: neueId(), datum: naechsteWiederholung(r, store.rechnungen)!);
                    await store.rechnungSpeichern(neu);
                    if (context.mounted) {
                      Navigator.of(context)
                          .pushReplacement(MaterialPageRoute(builder: (_) => RechnungDetail(rechnungId: neu.id)));
                    }
                  },
                  child: const Text('Jetzt erstellen'),
                ),
              ]),
            ),
          FilledButton.icon(
            onPressed: senden,
            icon: const Icon(Icons.send_outlined),
            label: Text(k != null && k.email.isNotEmpty ? '$titel per E-Mail senden' : '$titel per E-Mail senden (Adresse fehlt)'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pdfTeilen,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF teilen'),
              ),
            ),
            if (qr.isNotEmpty && istOffen(r)) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => giroCodeZeigen(context, qr, 'Jetzt bezahlen: ${euro(zahlen.brutto)}'),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('GiroCode zeigen'),
                ),
              ),
            ],
          ]),
          if (r.istRechnung && !r.storniert)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: eFehlt.isEmpty
                  ? Row(children: [
                      const Icon(Icons.verified_outlined, color: PT.gruen, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('E-Rechnung (XRechnung) wird mitgeschickt.', style: TextStyle(fontSize: 13))),
                      TextButton(
                        onPressed: () async => dateiTeilen(await xmlDatei(), mimeType: 'application/xml'),
                        child: const Text('XML teilen'),
                      ),
                    ])
                  : ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('E-Rechnung noch nicht möglich', style: TextStyle(fontSize: 14)),
                      subtitle: Text('Es fehlen ${eFehlt.length} Angaben', style: const TextStyle(fontSize: 12, color: PT.grau)),
                      children: [
                        for (final x in eFehlt)
                          Align(alignment: Alignment.centerLeft, child: Text('• $x', style: const TextStyle(fontSize: 13))),
                        const SizedBox(height: 4),
                        const Text('Zwischen Firmen wird die E-Rechnung ab 2027/2028 schrittweise Pflicht. An Privatkunden reicht das PDF.',
                            style: TextStyle(color: PT.grau, fontSize: 12)),
                      ],
                    ),
            ),
          if (r.istRechnung && f.iban.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Trag in den Firmendaten deine IBAN ein, dann kommt ein GiroCode auf die Rechnung.',
                  style: TextStyle(color: PT.grau, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          if (!r.storniert && r.art != 'lieferschein') ...[
            const Abschnitt('Weiter mit …'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (r.istAngebot)
                ActionChip(
                  avatar: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('Auftragsbestätigung'),
                  onPressed: () => neuerBeleg(umwandeln(r, store.rechnungen,
                      art: 'auftragsbestaetigung', id: neueId(), datum: DateTime.now(), zahlungszielTage: f.zahlungszielTage)),
                ),
              if (!r.istRechnung)
                ActionChip(
                  avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Lieferschein'),
                  onPressed: () => neuerBeleg(umwandeln(r, store.rechnungen,
                      art: 'lieferschein', id: neueId(), datum: DateTime.now(), zahlungszielTage: f.zahlungszielTage)),
                ),
              if (!r.istRechnung)
                ActionChip(
                  avatar: const Icon(Icons.percent, size: 18),
                  label: const Text('Abschlagsrechnung'),
                  onPressed: abschlagErstellen,
                ),
              if (!r.istRechnung)
                ActionChip(
                  avatar: const Icon(Icons.receipt_outlined, size: 18),
                  label: Text(store.rechnungen.any((x) => x.art == 'abschlag' && x.bezugId == (r.bezugId ?? r.id))
                      ? 'Schlussrechnung'
                      : 'Rechnung'),
                  onPressed: () {
                    final hatAbschlag = store.rechnungen.any((x) => x.art == 'abschlag' && x.bezugId == (r.bezugId ?? r.id) && !x.storniert);
                    neuerBeleg(hatAbschlag
                        ? schlussAus(r, store.rechnungen, id: neueId(), datum: DateTime.now(), zahlungszielTage: f.zahlungszielTage)
                        : umwandeln(r, store.rechnungen,
                            art: 'rechnung', id: neueId(), datum: DateTime.now(), zahlungszielTage: f.zahlungszielTage));
                  },
                ),
            ]),
            const SizedBox(height: 8),
          ],
          if (k != null && k.email.isNotEmpty && r.bezahltAm != null)
            OutlinedButton.icon(
              onPressed: () => AndroidKanal.oeffnen(
                  mailtoLink(an: k.email, betreff: 'Danke für Ihren Auftrag', text: bewertungsText(f, k))),
              icon: const Icon(Icons.star_outline),
              label: const Text('Um eine Bewertung bitten'),
            ),
          if (k != null && istOffen(r) && ueberfaellig(r))
            PTKarte(
              farbe: PT.rotHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    r.mahnstufe == 0
                        ? 'Überfällig seit ${datumKurz(faelligAm(r))}'
                        : 'Zuletzt: ${mahnstufenNamen[r.mahnstufe.clamp(1, 3)]} am ${r.gemahntAm == null ? '?' : datumKurz(r.gemahntAm!)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (var stufe = 1; stufe <= 3; stufe++)
                    if (stufe >= r.mahnstufe)
                      OutlinedButton(
                        onPressed: () async {
                          var gebuehr = 0.0;
                          if (stufe >= 2) {
                            final c = TextEditingController(text: '5,00');
                            final g = await showDialog<double>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('Mahngebühr'),
                                content: Column(mainAxisSize: MainAxisSize.min, children: [
                                  TextField(
                                      controller: c,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: feld(labelText: 'Betrag (0 = keine)', suffixText: '€')),
                                  const SizedBox(height: 8),
                                  const Text('Mahngebühren dürfen nur die tatsächlichen Kosten decken (Porto, Papier). '
                                      'Allgemeine Info, keine Rechtsberatung.',
                                      style: TextStyle(color: PT.grau, fontSize: 12)),
                                ]),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(d, double.tryParse(c.text.replaceAll(',', '.')) ?? 0),
                                      child: const Text('Weiter')),
                                ],
                              ),
                            );
                            c.dispose();
                            if (g == null) return;
                            gebuehr = g;
                          }
                          r
                            ..mahnstufe = stufe
                            ..gemahntAm = DateTime.now();
                          await store.geaendert();
                          if (!context.mounted) return;
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => VorlageScreen(
                                  titel: mahnstufenNamen[stufe],
                                  text: mahnText(r, f, k, zahlen, stufe: stufe, gebuehr: gebuehr))));
                        },
                        child: Text(mahnstufenNamen[stufe]),
                      ),
                ]),
              ]),
            ),
        ],
      ),
    );
  }
}

class RechnungFormular extends StatefulWidget {
  const RechnungFormular({super.key, required this.art, this.rechnung});

  final String art;
  final Rechnung? rechnung;

  @override
  State<RechnungFormular> createState() => _RechnungFormularState();
}

class _PosFelder {
  _PosFelder(Position p)
      : text = TextEditingController(text: p.text),
        menge = TextEditingController(text: _feld(p.menge)),
        einheit = TextEditingController(text: p.einheit),
        preis = TextEditingController(text: p.preis == 0 ? '' : p.preis.toStringAsFixed(2).replaceAll('.', ',')),
        ust = p.ustSatz,
        aufmass = [for (final a in p.aufmass) AufmassZeile.fromJson(a.toJson())],
        einkauf = p.einkauf,
        minuten = p.minuten;

  final TextEditingController text, menge, einheit, preis;
  int ust;
  List<AufmassZeile> aufmass;
  double einkauf, minuten;

  Position get position => Position(
      text: text.text.trim(),
      menge: _zahl(menge.text) ?? 1,
      einheit: einheit.text.trim().isEmpty ? 'Stück' : einheit.text.trim(),
      preis: _zahl(preis.text) ?? 0,
      ustSatz: ust,
      aufmass: aufmass,
      einkauf: einkauf,
      minuten: minuten);

  void dispose() {
    text.dispose();
    menge.dispose();
    einheit.dispose();
    preis.dispose();
  }
}

class _RechnungFormularState extends State<RechnungFormular> {
  String? _kundeId;
  late DateTime _datum;
  DateTime? _von, _bis;
  late int _ziel;
  int _wiederholung = 0;
  final _notiz = TextEditingController();
  final _rabattPz = TextEditingController();
  final _rabattEur = TextEditingController();
  final _pos = <_PosFelder>[];
  bool _bereit = false;

  bool get _istRechnung => const ['rechnung', 'abschlag', 'schluss'].contains(widget.art);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bereit) return;
    _bereit = true;
    final store = StoreScope.of(context);
    final r = widget.rechnung;
    _kundeId = r?.kundeId.isEmpty ?? true ? null : r!.kundeId;
    _datum = r?.datum ?? DateTime.now();
    _von = r?.leistungVon ?? (_istRechnung ? DateTime.now() : null);
    _rabattPz.text = (r?.rabattProzent ?? 0) == 0 ? '' : _feld(r!.rabattProzent);
    _rabattEur.text = (r?.rabattBetrag ?? 0) == 0 ? '' : r!.rabattBetrag.toStringAsFixed(2).replaceAll('.', ',');
    _bis = r?.leistungBis;
    _ziel = r?.zahlungszielTage ?? store.firma.zahlungszielTage;
    _wiederholung = r?.wiederholungMonate ?? 0;
    _notiz.text = r?.notiz ?? '';
    for (final p in r?.positionen ?? [Position(text: '', ustSatz: store.firma.kleinunternehmer ? 0 : 19)]) {
      _pos.add(_PosFelder(p));
    }
  }

  @override
  void dispose() {
    _notiz.dispose();
    _rabattPz.dispose();
    _rabattEur.dispose();
    for (final p in _pos) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _speichern() async {
    final store = StoreScope.of(context);
    if (widget.rechnung?.festgeschrieben == true) {
      zeigeHinweis(context, 'Diese Rechnung ist festgeschrieben. Ändern geht nur über Storno und neue Rechnung.');
      return;
    }
    final r = widget.rechnung ??
        Rechnung(
          id: neueId(),
          art: widget.art,
          nummer: naechsteNummer(store.rechnungen, art: widget.art, jahr: _datum.year),
          kundeId: '',
          datum: _datum,
        );
    r
      ..kundeId = _kundeId ?? ''
      ..datum = _datum
      ..leistungVon = _von
      ..leistungBis = _bis
      ..zahlungszielTage = _ziel
      ..wiederholungMonate = widget.art == 'rechnung' ? _wiederholung : 0
      ..notiz = _notiz.text.trim()
      ..rabattProzent = _zahl(_rabattPz.text) ?? 0
      ..rabattBetrag = _zahl(_rabattEur.text) ?? 0
      ..positionen = [for (final p in _pos) if (p.text.text.trim().isNotEmpty || (_zahl(p.preis.text) ?? 0) > 0) p.position];
    await store.rechnungSpeichern(r);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (widget.rechnung == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RechnungDetail(rechnungId: r.id)));
    }
  }

  Future<void> _ausKatalog() async {
    final store = StoreScope.of(context);
    final a = await Navigator.of(context)
        .push<Artikel>(MaterialPageRoute(builder: (_) => const KatalogScreen(auswahl: true)));
    if (a == null || !mounted) return;
    final p = positionAusArtikel(a, stundensatz: store.firma.stundensatz, kleinunternehmer: store.firma.kleinunternehmer);
    setState(() {
      // leere Startzeile ersetzen
      if (_pos.length == 1 && _pos.first.text.text.trim().isEmpty && (_zahl(_pos.first.preis.text) ?? 0) == 0) {
        _pos.removeAt(0).dispose();
      }
      _pos.add(_PosFelder(p));
    });
  }

  Future<void> _aufmass(int i) async {
    final l = await Navigator.of(context).push<List<AufmassZeile>>(MaterialPageRoute(
        builder: (_) => AufmassScreen(titel: _pos[i].text.text, zeilen: _pos[i].aufmass)));
    if (l == null || !mounted) return;
    setState(() {
      _pos[i].aufmass = l;
      if (l.isNotEmpty) _pos[i].menge.text = _feld(aufmassMenge(l));
    });
  }

  Future<void> _kiAngebot() async {
    final store = StoreScope.of(context);
    final c = TextEditingController();
    final notizen = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Angebot per KI'),
        content: TextField(
          controller: c,
          minLines: 6,
          maxLines: 12,
          decoration: feld(
              hintText: 'Notizen vom Termin, z. B.\nBad 2,5 × 3 m Boden fliesen, Wände 2 m hoch, alte Fliesen raus, Silikon neu'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Weiter')),
        ],
      ),
    );
    c.dispose();
    if (notizen == null || notizen.trim().isEmpty || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KiTextScreen(
        titel: 'Angebotsentwurf',
        anfrage: angebotAnfrage(notizen, store.artikel, stundensatz: store.firma.stundensatz),
        hinweis: 'Entwurf der KI: Mengen prüfen. Preise kommen aus deinem Katalog, fehlende bitte ergänzen.',
        uebernehmen: (
          'Positionen übernehmen',
          (text) {
            final neu = angebotLesen(text, store.artikel,
                stundensatz: store.firma.stundensatz, kleinunternehmer: store.firma.kleinunternehmer);
            if (!mounted) return;
            setState(() {
              if (_pos.length == 1 && _pos.first.text.text.trim().isEmpty) _pos.removeAt(0).dispose();
              _pos.addAll(neu.map(_PosFelder.new));
            });
          }
        ),
      ),
    ));
  }

  Future<void> _neuerKunde() async {
    final k = await Navigator.of(context).push<Kunde>(MaterialPageRoute(builder: (_) => const KundeFormular()));
    if (k != null) setState(() => _kundeId = k.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ku = store.firma.kleinunternehmer;
    final vorschau = Rechnung(
        id: '',
        art: widget.art,
        nummer: '',
        kundeId: '',
        datum: _datum,
        rabattProzent: _zahl(_rabattPz.text) ?? 0,
        rabattBetrag: _zahl(_rabattEur.text) ?? 0,
        positionen: [for (final p in _pos) p.position]);
    final s = summenVon(vorschau, kleinunternehmer: ku);
    final titel = belegArtName(widget.art);
    return Scaffold(
      appBar: AppBar(title: Text(widget.rechnung == null ? '$titel (neu)' : '$titel ${widget.rechnung!.nummer}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                value: store.kunden.any((k) => k.id == _kundeId) ? _kundeId : null,
                decoration: feld(labelText: 'Kunde'),
                items: [
                  for (final k in store.kunden) DropdownMenuItem(value: k.id, child: Text(k.name)),
                ],
                onChanged: (v) => setState(() => _kundeId = v),
              ),
            ),
            IconButton(onPressed: _neuerKunde, icon: const Icon(Icons.person_add_alt), tooltip: 'Neuer Kunde'),
          ]),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Datum'),
            subtitle: Text(datumLang(_datum)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await datumWaehlen(context, start: _datum);
              if (d != null) setState(() => _datum = d);
            },
          ),
          if (_istRechnung)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Leistung erbracht'),
              subtitle: Text(_von == null
                  ? 'bitte wählen'
                  : _bis == null || _bis == _von
                      ? 'am ${datumKurz(_von!)}'
                      : '${datumKurz(_von!)} bis ${datumKurz(_bis!)}'),
              trailing: const Icon(Icons.date_range_outlined),
              onTap: () async {
                final jetzt = DateTime.now();
                final z = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(jetzt.year - 5),
                  lastDate: DateTime(jetzt.year + 2),
                  helpText: 'Leistungszeitraum',
                  initialDateRange: _von == null ? null : DateTimeRange(start: _von!, end: _bis ?? _von!),
                );
                if (z != null) {
                  setState(() {
                    _von = z.start;
                    _bis = z.end;
                  });
                }
              },
            ),
          Row(children: [
            const Expanded(child: Abschnitt('Positionen')),
            if (!_istRechnung)
              TextButton.icon(
                onPressed: _kiAngebot,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Per KI'),
              ),
          ]),
          for (var i = 0; i < _pos.length; i++)
            PTKarte(
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _pos[i].text,
                      decoration: feld(labelText: 'Leistung oder Artikel'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_pos.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _pos.removeAt(i).dispose()),
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _pos[i].menge,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: feld(labelText: 'Menge'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _pos[i].einheit, decoration: feld(labelText: 'Einheit'))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _pos[i].preis,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: feld(labelText: ku ? 'Preis' : 'Preis netto', suffixText: '€'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
                if (handwerkSichtbar(store.lebenslagen))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _aufmass(i),
                    icon: const Icon(Icons.straighten, size: 18),
                    label: Text(_pos[i].aufmass.isEmpty ? 'Aufmaß' : 'Aufmaß: ${aufmassText(_pos[i].aufmass)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (!ku) ...[
                  Wrap(spacing: 8, children: [
                    for (final u in const [19, 7, 0])
                      ChoiceChip(
                          label: Text('$u % USt'),
                          selected: _pos[i].ust == u,
                          onSelected: (_) => setState(() => _pos[i].ust = u)),
                  ]),
                ],
              ]),
            ),
          Wrap(spacing: 8, children: [
            TextButton.icon(
              onPressed: () => setState(() => _pos.add(_PosFelder(Position(text: '', ustSatz: ku ? 0 : 19)))),
              icon: const Icon(Icons.add),
              label: const Text('Position'),
            ),
            TextButton.icon(
              onPressed: _ausKatalog,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Aus Katalog'),
            ),
          ]),
          if (_pos.any((p) => p.einkauf > 0 || p.minuten > 0))
            Builder(builder: (_) {
              final kal = kalkulationVon(vorschau, stundensatz: store.firma.stundensatz, netto: s.netto);
              return PTKarte(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kalkulation', style: TextStyle(fontWeight: FontWeight.w700)),
                  Row(children: [const Expanded(child: Text('Material (Einkauf)')), Text(euro(kal.material))]),
                  Row(children: [
                    Expanded(child: Text('Lohn (${_feld(kal.stunden)} Std.)')),
                    Text(store.firma.stundensatz == 0 ? 'Stundensatz fehlt' : euro(kal.lohn)),
                  ]),
                  Row(children: [
                    const Expanded(child: Text('Bleibt für Gemeinkosten und Gewinn', style: TextStyle(fontWeight: FontWeight.w700))),
                    Text('${euro(kal.rohertrag)}${kal.rohertragProzent == null ? '' : ' (${_feld(kal.rohertragProzent!)} %)'}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: kal.rohertrag < 0 ? PT.rot : PT.tinte)),
                  ]),
                ]),
              );
            }),
          if (widget.art != 'lieferschein')
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _rabattPz,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: feld(labelText: 'Rabatt', suffixText: '%'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _rabattEur,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: feld(labelText: 'oder pauschal', suffixText: '€'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          const SizedBox(height: 12),
          PTKarte(
            farbe: PT.orangeHell,
            child: Column(children: [
              if (s.rabatt > 0) Row(children: [const Expanded(child: Text('Rabatt')), Text('-${euro(s.rabatt)}')]),
              if (!ku) Row(children: [const Expanded(child: Text('Netto')), Text(euro(s.netto))]),
              if (!ku)
                for (final e in s.ust.entries) Row(children: [Expanded(child: Text('USt ${e.key} %')), Text(euro(e.value))]),
              Row(children: [
                const Expanded(child: Text('Gesamt', style: TextStyle(fontWeight: FontWeight.w800))),
                Text(euro(s.brutto), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              if (ku) const Text(kleinunternehmerHinweis, style: TextStyle(fontSize: 12, color: PT.grau)),
            ]),
          ),
          if (_istRechnung) ...[
            const Text('Zahlungsziel', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final t in {7, 14, 30, _ziel})
                ChoiceChip(label: Text('$t Tage'), selected: _ziel == t, onSelected: (_) => setState(() => _ziel = t)),
            ]),
            if (widget.art == 'rechnung') ...[
              const SizedBox(height: 12),
              const Text('Wiederholen', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final (m, t) in const [(0, 'Einmalig'), (1, 'Monatlich'), (3, 'Vierteljährlich'), (12, 'Jährlich')])
                  ChoiceChip(label: Text(t), selected: _wiederholung == m, onSelected: (_) => setState(() => _wiederholung = m)),
              ]),
            ],
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _notiz,
            minLines: 2,
            maxLines: 4,
            decoration: feld(labelText: 'Hinweis auf dem Dokument (optional)'),
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

class KundenScreen extends StatelessWidget {
  const KundenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final kunden = [...store.kunden]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('Kunden')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KundeFormular())),
        child: const Icon(Icons.person_add_alt),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (kunden.isEmpty) const LeerHinweis(icon: Icons.people_outline, text: 'Noch keine Kunden.'),
          for (final k in kunden)
            Builder(builder: (context) {
              final rs = store.rechnungen.where((r) => r.kundeId == k.id && r.istRechnung && !r.storniert);
              final umsatz = rs.fold(0.0, (s, r) => s + zuZahlen(r, store.rechnungen, kleinunternehmer: store.firma.kleinunternehmer).brutto);
              return PTKarte(
                padding: const EdgeInsets.all(14),
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => KundeFormular(kunde: k))),
                child: Row(children: [
                  const IconKachel(Icons.person_outline),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${anzahl(rs.length, 'Rechnung', 'Rechnungen')} · ${euro(umsatz)}', style: const TextStyle(color: PT.grau, fontSize: 13)),
                    ]),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }
}

class KundeFormular extends StatefulWidget {
  const KundeFormular({super.key, this.kunde});

  final Kunde? kunde;

  @override
  State<KundeFormular> createState() => _KundeFormularState();
}

class _KundeFormularState extends State<KundeFormular> {
  late final _name = TextEditingController(text: widget.kunde?.name ?? '');
  late final _adresse = TextEditingController(text: widget.kunde?.adresse ?? '');
  late final _email = TextEditingController(text: widget.kunde?.email ?? '');
  late final _notiz = TextEditingController(text: widget.kunde?.notiz ?? '');
  late final _leitweg = TextEditingController(text: widget.kunde?.leitwegId ?? '');

  @override
  void dispose() {
    for (final c in [_name, _adresse, _email, _notiz, _leitweg]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.kunde == null ? 'Neuer Kunde' : 'Kunde')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: feld(labelText: 'Name oder Firma')),
          const SizedBox(height: 12),
          TextField(
              controller: _adresse,
              minLines: 2,
              maxLines: 4,
              decoration: feld(labelText: 'Anschrift', hintText: 'Straße Hausnummer\nPLZ Ort')),
          const SizedBox(height: 12),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: feld(labelText: 'E-Mail (optional)')),
          const SizedBox(height: 12),
          TextField(controller: _notiz, minLines: 2, maxLines: 4, decoration: feld(labelText: 'Notiz (optional)')),
          const SizedBox(height: 12),
          TextField(
              controller: _leitweg,
              decoration: feld(labelText: 'Leitweg-ID (nur bei Behörden, für die E-Rechnung)')),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty) {
                zeigeHinweis(context, 'Bitte einen Namen eintragen.');
                return;
              }
              final k = widget.kunde ?? Kunde(id: neueId(), name: '');
              k
                ..name = _name.text.trim()
                ..adresse = _adresse.text.trim()
                ..email = _email.text.trim()
                ..notiz = _notiz.text.trim()
                ..leitwegId = _leitweg.text.trim();
              await store.kundeSpeichern(k);
              if (context.mounted) Navigator.of(context).pop(k);
            },
            child: const Text('Speichern'),
          ),
        ),
      ),
    );
  }
}

class FirmaScreen extends StatefulWidget {
  const FirmaScreen({super.key});

  @override
  State<FirmaScreen> createState() => _FirmaScreenState();
}

class _FirmaScreenState extends State<FirmaScreen> {
  final _c = <String, TextEditingController>{};
  late bool _ku;
  late int _ziel;
  bool _bereit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bereit) return;
    _bereit = true;
    final f = StoreScope.of(context).firma;
    final p = StoreScope.of(context).profil;
    final werte = {
      'name': f.name.isEmpty ? p.name : f.name,
      'adresse': f.adresse.isEmpty ? p.adresse : f.adresse,
      'steuernummer': f.steuernummer,
      'ustId': f.ustId,
      'iban': f.iban.isEmpty ? (p.extra['iban'] ?? '') : f.iban,
      'bank': f.bank.isEmpty ? (p.extra['bank'] ?? '') : f.bank,
      'bic': f.bic,
      'stundensatz': f.stundensatz == 0 ? '' : _feld(f.stundensatz),
      'email': f.email.isEmpty ? (p.extra['email'] ?? '') : f.email,
      'telefon': f.telefon.isEmpty ? (p.extra['telefon'] ?? '') : f.telefon,
    };
    werte.forEach((k, v) => _c[k] = TextEditingController(text: v));
    _ku = f.kleinunternehmer;
    _ziel = f.zahlungszielTage;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    Widget f(String k, String label, {int zeilen = 1, String? hint}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
              controller: _c[k], minLines: zeilen, maxLines: zeilen, decoration: feld(labelText: label, hintText: hint)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Firmendaten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          f('name', 'Name oder Firmenname'),
          f('adresse', 'Anschrift', zeilen: 2, hint: 'Straße Hausnummer\nPLZ Ort'),
          f('steuernummer', 'Steuernummer'),
          f('ustId', 'USt-IdNr. (falls vorhanden)'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kleinunternehmer (§ 19 UStG)', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Rechnungen ohne Umsatzsteuer, mit Hinweis auf § 19 UStG'),
            value: _ku,
            onChanged: (v) => setState(() => _ku = v),
          ),
          f('iban', 'IBAN für Zahlungen'),
          f('bank', 'Bank'),
          f('bic', 'BIC (optional)'),
          f('stundensatz', 'Stundensatz netto in € (für die Kalkulation)'),
          f('email', 'E-Mail'),
          f('telefon', 'Telefon'),
          const Text('Zahlungsziel', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final t in const [7, 14, 30])
              ChoiceChip(label: Text('$t Tage'), selected: _ziel == t, onSelected: (_) => setState(() => _ziel = t)),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              final x = store.firma;
              x
                ..name = _c['name']!.text.trim()
                ..adresse = _c['adresse']!.text.trim()
                ..steuernummer = _c['steuernummer']!.text.trim()
                ..ustId = _c['ustId']!.text.trim()
                ..iban = _c['iban']!.text.trim()
                ..bank = _c['bank']!.text.trim()
                ..bic = _c['bic']!.text.trim().toUpperCase()
                ..stundensatz = _zahl(_c['stundensatz']!.text) ?? 0
                ..email = _c['email']!.text.trim()
                ..telefon = _c['telefon']!.text.trim()
                ..kleinunternehmer = _ku
                ..zahlungszielTage = _ziel;
              await store.geaendert();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Speichern'),
          ),
        ),
      ),
    );
  }
}

/// Einnahmen und Ausgaben je Jahr, Quartal oder Monat, mit Umsatzsteuer-Termin.
class EuerScreen extends StatefulWidget {
  const EuerScreen({super.key});

  @override
  State<EuerScreen> createState() => _EuerScreenState();
}

class _EuerScreenState extends State<EuerScreen> {
  int _jahr = DateTime.now().year;
  int _quartal = 0; // 0 = ganzes Jahr

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = store.firma;
    final z = _quartal == 0 ? Zeitraum.jahr(_jahr) : Zeitraum.quartal(_jahr, _quartal);
    final u = ueberschuss(z: z, rechnungen: store.rechnungen, belege: store.belege, kleinunternehmer: f.kleinunternehmer);
    final ausgaben = store.belege.where((b) => b.geschaeftlich && z.enthaelt(b.datum)).toList()
      ..sort((a, b) => a.datum.compareTo(b.datum));
    final einnahmen = store.rechnungen
        .where((r) => r.istRechnung && !r.storniert && r.bezahltAm != null && z.enthaelt(r.bezahltAm!))
        .toList()
      ..sort((a, b) => a.bezahltAm!.compareTo(b.bezahltAm!));

    String csv() {
      final b = StringBuffer('﻿Datum;Art;Beschreibung;Netto;USt;Brutto\n');
      String e(double x) => x.toStringAsFixed(2).replaceAll('.', ',');
      for (final r in einnahmen) {
        final s = zuZahlen(r, store.rechnungen, kleinunternehmer: f.kleinunternehmer);
        b.writeln('${datumKurz(r.bezahltAm!)};Einnahme;"${r.artName} ${r.nummer} ${store.kundeMitId(r.kundeId)?.name ?? ''}";'
            '${e(s.netto)};${e(s.ustGesamt)};${e(s.brutto)}');
      }
      for (final a in ausgaben) {
        b.writeln('${datumKurz(a.datum)};Ausgabe;"${a.haendler.replaceAll('"', "'")}";;;${e(a.betrag ?? 0)}');
      }
      return b.toString();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Einnahmen & Ausgaben')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Wrap(spacing: 8, children: [
            for (final j in [DateTime.now().year, DateTime.now().year - 1])
              ChoiceChip(label: Text('$j'), selected: _jahr == j, onSelected: (_) => setState(() => _jahr = j)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final q in const [0, 1, 2, 3, 4])
              ChoiceChip(
                  label: Text(q == 0 ? 'Jahr' : 'Q$q'),
                  selected: _quartal == q,
                  onSelected: (_) => setState(() => _quartal = q)),
          ]),
          const SizedBox(height: 12),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(title: const Text('Einnahmen netto'), trailing: Text(euro(u.einnahmenNetto))),
              if (!f.kleinunternehmer)
                ListTile(
                    title: const Text('Eingenommene Umsatzsteuer'),
                    subtitle: const Text('geht ans Finanzamt (Vorsteuer aus Belegen noch abziehen)'),
                    trailing: Text(euro(u.ustEingenommen))),
              ListTile(title: const Text('Ausgaben (Belege brutto)'), trailing: Text(euro(u.ausgaben))),
              const Divider(height: 1),
              ListTile(
                title: const Text('Überschuss', style: TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text(euro(u.gewinnVorSteuer), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          if (!f.kleinunternehmer && _quartal > 0)
            PTKarte(
              farbe: PT.orangeHell,
              child: Text('Umsatzsteuer-Voranmeldung für ${z.name}: meist bis ${datumKurz(ustVoranmeldungBis(z))} '
                  '(ohne Dauerfristverlängerung, über ELSTER).'),
            ),
          for (final l in buchhaltungsLuecken(z: z, belege: store.belege, rechnungen: store.rechnungen, heute: DateTime.now()))
            PTKarte(
              farbe: PT.gelbHell,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.report_outlined, color: PT.gelb),
                const SizedBox(width: 10),
                Expanded(child: Text(l)),
              ]),
            ),
          if (ausgaben.isNotEmpty)
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final e in () {
                  final m = <String, double>{};
                  for (final a in ausgaben) {
                    final k = a.kategorie != null && betriebsKategorien.contains(a.kategorie) ? a.kategorie! : 'Ohne Kategorie';
                    m[k] = (m[k] ?? 0) + (a.betrag ?? 0);
                  }
                  return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                }())
                  ListTile(dense: true, title: Text(e.key), trailing: Text(euro(e.value))),
              ]),
            ),
          if (ausgaben.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () async {
                final d = await belegeAlsPdf('Belege ${z.name}', ausgaben);
                await dateiTeilen(d.path, mimeType: 'application/pdf');
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Belege mit Fotos als PDF'),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await textDatei('Einnahmen Ausgaben ${z.name}.csv', csv());
              await dateiTeilen(d.path, mimeType: 'text/csv');
            },
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Als Tabelle für die Steuerberatung'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await textDatei(
                  'Buchungsliste DATEV ${z.name}.csv',
                  datevBuchungsliste(
                      z: z, rechnungen: store.rechnungen, belege: store.belege, kleinunternehmer: f.kleinunternehmer));
              await dateiTeilen(d.path, mimeType: 'text/csv');
            },
            icon: const Icon(Icons.account_balance_outlined),
            label: const Text('Buchungsliste im DATEV-Format (SKR03)'),
          ),
          const Text('Konten sind ein Vorschlag nach SKR03 – deine Steuerberatung prüft sie beim Import.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
          if (einnahmen.isNotEmpty) ...[
            const Abschnitt('Einnahmen'),
            for (final r in einnahmen) RechnungZeile(r),
          ],
          if (ausgaben.isNotEmpty) ...[
            const Abschnitt('Ausgaben'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final a in ausgaben)
                  ListTile(
                      dense: true,
                      title: Text(a.haendler.isEmpty ? 'Beleg' : a.haendler),
                      subtitle: Text(datumKurz(a.datum)),
                      trailing: Text(euro(a.betrag ?? 0))),
              ]),
            ),
          ] else
            const Text('Geschäftliche Ausgaben: Beleg öffnen und „Geschäftliche Ausgabe“ einschalten.',
                style: TextStyle(color: PT.grau, fontSize: 13)),
        ],
      ),
    );
  }
}
