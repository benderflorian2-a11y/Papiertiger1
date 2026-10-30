import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/karriere.dart';
import '../../data/models.dart';
import '../../logic/android_kanal.dart';
import '../../logic/export.dart';
import '../../logic/karriere.dart';
import '../../logic/ordnung.dart';
import '../../logic/texterkennung.dart';
import '../app.dart';
import '../brief_detail.dart';
import '../ki_text.dart';
import '../module/profil.dart';
import '../theme.dart';
import '../vorlage_screen.dart';
import '../widgets/common.dart';

Future<String?> _eingabe(BuildContext context, String titel, {String start = '', String? hint, int zeilen = 1}) async {
  final c = TextEditingController(text: start);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titel),
      content: TextField(
          controller: c, autofocus: true, minLines: zeilen, maxLines: zeilen == 1 ? 1 : 14, decoration: feld(hintText: hint)),
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

Widget _kachel(BuildContext context, IconData icon, String titel, String text, Widget ziel) => PTKarte(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ziel)),
      child: Row(children: [
        IconKachel(icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(text, style: const TextStyle(color: PT.grau, fontSize: 13)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: PT.grau),
      ]),
    );

/// Übersicht Job, Karriere und Weiterbildung.
class KarriereScreen extends StatelessWidget {
  const KarriereScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final k = store.karriere;
    final offen = k.bewerbungen.where((b) => b.status != 'Absage' && b.status != 'Zusage').length;
    final nachfassen = k.bewerbungen.where((b) => nachfassenFaellig(b, heute: DateTime.now())).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Job & Karriere')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        _kachel(context, Icons.badge_outlined, 'Lebenslauf',
            k.lebenslauf.stationen.isEmpty ? 'Einmal anlegen, für jede Bewerbung nutzen' : '${k.lebenslauf.stationen.length} Stationen · als PDF',
            const LebenslaufScreen()),
        _kachel(context, Icons.work_outline, 'Bewerbungen',
            k.bewerbungen.isEmpty
                ? 'Anzeige auswerten, Anschreiben, Unterlagen prüfen'
                : '$offen laufend${nachfassen == 0 ? '' : ' · $nachfassen zum Nachfassen'}',
            const BewerbungenScreen()),
        _kachel(context, Icons.payments_outlined, 'Gehaltsabrechnungen',
            'Netto im Verlauf, Auffälligkeiten, Prüfung per KI', const GehaltScreen()),
        _kachel(context, Icons.workspace_premium_outlined, 'Arbeitszeugnis verstehen', 'Zeugnissprache in Klartext',
            const ZeugnisScreen()),
        _kachel(context, Icons.school_outlined, 'Weiterbildung',
            k.weiterbildungen.isEmpty ? 'Kurse, Kosten, Fristen und Förderung' : '${k.weiterbildungen.length} Weiterbildungen',
            const WeiterbildungScreen()),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Lebenslauf

class LebenslaufScreen extends StatelessWidget {
  const LebenslaufScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = store.karriere.lebenslauf;
    final p = store.profil;
    final luecken = lebenslaufLuecken(l.stationen);
    String m(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lebenslauf'),
        actions: [
          IconButton(
            tooltip: 'Als PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              final d = await lebenslaufAlsPdf(l, p);
              await dateiTeilen(d.path, mimeType: 'application/pdf');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _station(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Station'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
        PTKarte(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilScreen())),
          child: Row(children: [
            GestureDetector(
              onTap: () async {
                final pfad = await Texterkennung.bildHolen(kamera: false);
                if (pfad == null) return;
                l.foto = pfad;
                await store.geaendert();
              },
              child: CircleAvatar(
                radius: 30,
                backgroundColor: PT.sand,
                backgroundImage: l.foto != null && File(l.foto!).existsSync() ? FileImage(File(l.foto!)) : null,
                child: l.foto == null ? const Icon(Icons.add_a_photo_outlined) : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name.isEmpty ? 'Name im Profil eintragen' : p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(p.adresse.isEmpty ? 'Adresse fehlt' : p.adresse.replaceAll('\n', ', '),
                    style: const TextStyle(color: PT.grau, fontSize: 13)),
              ]),
            ),
          ]),
        ),
        Row(children: [
          Expanded(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Telefon'),
              subtitle: Text(l.telefon.isEmpty ? 'tippen' : l.telefon),
              onTap: () async {
                final t = await _eingabe(context, 'Telefon', start: l.telefon);
                if (t == null) return;
                l.telefon = t;
                await store.geaendert();
              },
            ),
          ),
          Expanded(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('E-Mail'),
              subtitle: Text(l.email.isEmpty ? 'tippen' : l.email, overflow: TextOverflow.ellipsis),
              onTap: () async {
                final t = await _eingabe(context, 'E-Mail', start: l.email);
                if (t == null) return;
                l.email = t;
                await store.geaendert();
              },
            ),
          ),
        ]),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kurzprofil (optional)'),
          subtitle: Text(l.kurzprofil.isEmpty ? 'Zwei, drei Sätze: wer du bist und was du kannst' : l.kurzprofil),
          onTap: () async {
            final t = await _eingabe(context, 'Kurzprofil', start: l.kurzprofil, zeilen: 4);
            if (t == null) return;
            l.kurzprofil = t;
            await store.geaendert();
          },
        ),
        if (luecken.isNotEmpty)
          PTKarte(
            farbe: PT.gelbHell,
            child: Text('Lücke im Lebenslauf: ${luecken.map((x) => '${m(x.$1)} – ${m(x.$2)}').join(', ')}. '
                'Kurz erklären (z. B. Elternzeit, Weiterbildung, Jobsuche) wirkt besser als nichts.'),
          ),
        for (final art in stationsArten)
          if (l.stationen.any((s) => s.art == art)) ...[
            Abschnitt(art == 'Beruf' ? 'Berufserfahrung' : art),
            for (final s in (l.stationen.where((s) => s.art == art).toList()
              ..sort((a, b) => (b.von ?? DateTime(0)).compareTo(a.von ?? DateTime(0)))))
              PTKarte(
                padding: const EdgeInsets.all(12),
                onTap: () => _station(context, s),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${s.von == null ? '' : '${m(s.von!)} – ${s.bis == null ? 'heute' : m(s.bis!)}'}${s.ort.isEmpty ? '' : ' · ${s.ort}'}',
                    style: const TextStyle(color: PT.grau, fontSize: 13),
                  ),
                ]),
              ),
          ],
        const Abschnitt('Kenntnisse und Sprachen'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kenntnisse'),
          subtitle: Text(l.kenntnisse.isEmpty ? 'z. B. Excel, Staplerschein, SAP' : l.kenntnisse.join(', ')),
          onTap: () async {
            final t = await _eingabe(context, 'Kenntnisse (mit Komma trennen)', start: l.kenntnisse.join(', '), zeilen: 3);
            if (t == null) return;
            l.kenntnisse = t.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
            await store.geaendert();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sprachen'),
          subtitle: Text(l.sprachen.isEmpty ? 'z. B. Deutsch – Muttersprache, Englisch – gut' : l.sprachen.join(', ')),
          onTap: () async {
            final t = await _eingabe(context, 'Sprachen (mit Komma trennen)', start: l.sprachen.join(', '), zeilen: 2);
            if (t == null) return;
            l.sprachen = t.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
            await store.geaendert();
          },
        ),
        const Text('Foto und Geburtsdatum sind in Deutschland freiwillig.', style: TextStyle(color: PT.grau, fontSize: 12)),
      ]),
    );
  }

  Future<void> _station(BuildContext context, Station? s) async {
    final store = StoreScope.of(context);
    final titel = TextEditingController(text: s?.titel ?? '');
    final ort = TextEditingController(text: s?.ort ?? '');
    final text = TextEditingController(text: s?.text ?? '');
    var art = s?.art ?? 'Beruf';
    DateTime? von = s?.von, bis = s?.bis;
    final ok = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text(s == null ? 'Neue Station' : 'Station'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [
                for (final a in stationsArten) ChoiceChip(label: Text(a), selected: art == a, onSelected: (_) => setze(() => art = a)),
              ]),
              const SizedBox(height: 8),
              TextField(controller: titel, decoration: feld(labelText: art == 'Beruf' ? 'Position' : 'Abschluss bzw. Kurs')),
              const SizedBox(height: 8),
              TextField(controller: ort, decoration: feld(labelText: art == 'Beruf' ? 'Firma, Ort' : 'Schule bzw. Anbieter, Ort')),
              const SizedBox(height: 8),
              TextField(controller: text, minLines: 2, maxLines: 5, decoration: feld(labelText: 'Aufgaben bzw. Schwerpunkte')),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final x = await datumWaehlen(d, start: von);
                      if (x != null) setze(() => von = x);
                    },
                    child: Text(von == null ? 'von …' : 'von ${von!.month}/${von!.year}'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final x = await datumWaehlen(d, start: bis);
                      setze(() => bis = x);
                    },
                    child: Text(bis == null ? 'bis heute' : 'bis ${bis!.month}/${bis!.year}'),
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            if (s != null) TextButton(onPressed: () => Navigator.pop(d, 'weg'), child: const Text('Löschen')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final t = titel.text.trim(), o = ort.text.trim(), x = text.text.trim();
    for (final c in [titel, ort, text]) {
      c.dispose();
    }
    final l = store.karriere.lebenslauf;
    if (ok == 'weg' && s != null) {
      l.stationen.remove(s);
    } else if (ok == 'ok' && t.isNotEmpty) {
      final st = s ?? Station(art: art, titel: t);
      st
        ..art = art
        ..titel = t
        ..ort = o
        ..text = x
        ..von = von
        ..bis = bis;
      if (s == null) l.stationen.add(st);
    } else {
      return;
    }
    await store.geaendert();
  }
}

// ---------------------------------------------------------------- Bewerbungen

class BewerbungenScreen extends StatelessWidget {
  const BewerbungenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = store.karriere.bewerbungen;
    final heute = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Bewerbungen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final anzeige = await _eingabe(context, 'Stellenanzeige einfügen',
              hint: 'Den Text der Anzeige hier hineinkopieren (oder leer lassen)', zeilen: 8);
          if (anzeige == null || !context.mounted) return;
          final firma = await _eingabe(context, 'Firma');
          if (firma == null || firma.isEmpty || !context.mounted) return;
          final stelle = await _eingabe(context, 'Stelle', hint: 'z. B. Bürokauffrau (m/w/d)');
          if (stelle == null || stelle.isEmpty) return;
          final info = anzeigeAuswerten(anzeige);
          final b = Bewerbung(
            id: neueId(),
            firma: firma,
            stelle: stelle,
            anzeige: anzeige,
            frist: info.frist,
            email: info.email ?? '',
            kontakt: info.ansprechpartner ?? '',
          );
          l.add(b);
          await store.geaendert();
          if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => BewerbungDetail(bewerbungId: b.id)));
        },
        icon: const Icon(Icons.add),
        label: const Text('Stelle'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
        if (l.isEmpty)
          const LeerHinweis(
            icon: Icons.work_outline,
            text: 'Füge eine Stellenanzeige ein – der Tiger zeigt, was verlangt wird, hilft beim Anschreiben und prüft die Unterlagen.',
          ),
        for (final st in bewerbungsStatus)
          if (l.any((b) => b.status == st)) ...[
            Abschnitt(st),
            for (final b in l.where((b) => b.status == st))
              PTKarte(
                padding: const EdgeInsets.all(12),
                farbe: nachfassenFaellig(b, heute: heute) ? PT.orangeHell : Colors.white,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BewerbungDetail(bewerbungId: b.id))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.stelle, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          b.firma,
                          if (b.beworbenAm != null) 'beworben ${datumKurz(b.beworbenAm!)}',
                          if (b.gespraechAm != null && b.gespraechAm!.isAfter(heute)) 'Gespräch ${datumKurz(b.gespraechAm!)}',
                          if (nachfassenFaellig(b, heute: heute)) 'nachfragen?',
                        ].join(' · '),
                        style: const TextStyle(color: PT.grau, fontSize: 13),
                      ),
                    ]),
                  ),
                  if (b.frist != null && b.beworbenAm == null) FristEtikett(b.frist!),
                ]),
              ),
          ],
      ]),
    );
  }
}

class BewerbungDetail extends StatelessWidget {
  const BewerbungDetail({super.key, required this.bewerbungId});

  final String bewerbungId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = store.karriere.bewerbungen.where((x) => x.id == bewerbungId).firstOrNull;
    if (b == null) return Scaffold(appBar: AppBar(), body: const LeerHinweis(icon: Icons.work_outline, text: 'Gelöscht.'));
    final l = store.karriere.lebenslauf;
    final p = store.profil;
    final info = anzeigeAuswerten(b.anzeige);
    final anlagen = store.briefe.where((x) => b.briefIds.contains(x.id)).toList();
    final fehlt = bewerbungPruefen(b, l, p, anlagen: anlagen.length);
    void oeffne(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    Future<void> senden() async {
      final dateien = <String>[];
      if (b.anschreiben.trim().isNotEmpty) {
        dateien.add((await antwortAlsPdf(b.anschreiben, titel: 'Anschreiben ${b.firma}')).path);
      }
      dateien.add((await lebenslaufAlsPdf(l, p)).path);
      for (final a in anlagen) {
        if (a.pdfPfad != null && File(a.pdfPfad!).existsSync()) {
          dateien.add(a.pdfPfad!);
        } else {
          dateien.addAll(a.bilder.where((x) => File(x).existsSync()));
        }
      }
      final ok = await mailMitAnhang(
        an: b.email.isNotEmpty ? b.email : (info.email ?? ''),
        betreff: 'Bewerbung als ${b.stelle}',
        text: '${info.ansprechpartner != null ? 'Sehr geehrte${info.ansprechpartner!.startsWith('Herr') ? 'r' : ''} ${info.ansprechpartner},' : 'Sehr geehrte Damen und Herren,'}\n\n'
            'anbei sende ich Ihnen meine Bewerbungsunterlagen für die Stelle als ${b.stelle}.\n\n'
            'Mit freundlichen Grüßen\n${p.name}${l.telefon.isEmpty ? '' : '\n${l.telefon}'}',
        pfade: dateien,
      );
      if (!context.mounted) return;
      if (!ok) {
        await dateienTeilen(dateien, betreff: 'Bewerbung als ${b.stelle}');
        if (!context.mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 15),
        content: const Text('Abgeschickt?'),
        action: SnackBarAction(
          label: 'Ja, vermerken',
          onPressed: () {
            b
              ..status = 'Beworben'
              ..beworbenAm = DateTime.now();
            store.geaendert();
          },
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(b.firma),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.of(context).pop();
              store.karriere.bewerbungen.remove(b);
              store.geaendert();
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(b.stelle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final st in bewerbungsStatus)
            ChoiceChip(
              label: Text(st),
              selected: b.status == st,
              onSelected: (_) {
                b.status = st;
                if (st == 'Beworben') b.beworbenAm ??= DateTime.now();
                store.geaendert();
              },
            ),
        ]),
        // ------------------------------ Anzeige
        const Abschnitt('Stellenanzeige'),
        PTKarte(
          onTap: () async {
            final t = await _eingabe(context, 'Stellenanzeige', start: b.anzeige, zeilen: 10);
            if (t == null) return;
            b.anzeige = t;
            final i = anzeigeAuswerten(t);
            b.frist ??= i.frist;
            if (b.email.isEmpty) b.email = i.email ?? '';
            if (b.kontakt.isEmpty) b.kontakt = i.ansprechpartner ?? '';
            await store.geaendert();
          },
          child: b.anzeige.isEmpty
              ? const Text('Anzeige einfügen – tippen')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (info.frist != null) Text('Bewerbungsfrist: ${datumKurz(info.frist!)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (info.ansprechpartner != null) Text('Ansprechpartner: ${info.ansprechpartner}'),
                  if (info.email != null) Text('E-Mail: ${info.email}'),
                  if (info.arbeitszeit != null) Text('Arbeitszeit: ${info.arbeitszeit}${info.befristet ? ' · befristet' : ''}'),
                  if (info.gehaltsangabe != null) Text('Gehalt laut Anzeige: ${info.gehaltsangabe}'),
                  if (info.gehaltGewuenscht) const Text('Verlangt: Gehaltsvorstellung'),
                  if (info.eintrittGewuenscht) const Text('Verlangt: frühestmöglicher Eintritt'),
                  const SizedBox(height: 4),
                  Text(b.anzeige, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PT.grau, fontSize: 12)),
                ]),
        ),
        if (b.anzeige.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => oeffne(KiTextScreen(
              titel: 'Passt die Stelle?',
              anfrage: passungAnfrage(b.anzeige, l, p),
              hinweis: 'Einschätzung der KI – entscheide selbst.',
            )),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Passt die Stelle zu mir? (KI)'),
          ),
        // ------------------------------ Unterlagen
        const Abschnitt('Unterlagen'),
        PTKarte(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            ListTile(
              leading: Icon(b.anschreiben.isEmpty ? Icons.radio_button_unchecked : Icons.check_circle, color: PT.gruen),
              title: const Text('Anschreiben'),
              subtitle: Text(b.anschreiben.isEmpty ? 'noch keins' : b.anschreiben.split('\n').firstWhere((z) => z.startsWith('Betreff'), orElse: () => 'vorhanden')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (b.anschreiben.isNotEmpty) {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _AnschreibenScreen(bewerbung: b)));
                  return;
                }
                final notiz = await _eingabe(context, 'Was soll unbedingt rein? (optional)',
                    hint: 'z. B. Umzug nach München, Staplerschein, Teilzeit 30 Std.', zeilen: 3);
                if (notiz == null || !context.mounted) return;
                oeffne(KiTextScreen(
                  titel: 'Anschreiben',
                  anfrage: anschreibenAnfrage(b, l, p, eigeneNotizen: notiz),
                  hinweis: 'Entwurf der KI – prüfe jeden Satz, ersetze [Klammern].',
                  uebernehmen: (
                    'Als Anschreiben übernehmen',
                    (text) {
                      b.anschreiben = text;
                      store.geaendert();
                    }
                  ),
                ));
              },
            ),
            ListTile(
              leading: Icon(l.stationen.isEmpty ? Icons.radio_button_unchecked : Icons.check_circle, color: PT.gruen),
              title: const Text('Lebenslauf'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => oeffne(const LebenslaufScreen()),
            ),
            for (final a in anlagen)
              ListTile(
                leading: const Icon(Icons.attach_file, color: PT.orangeDunkel),
                title: Text(titelVon(a)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    b.briefIds.remove(a.id);
                    store.geaendert();
                  },
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add, color: PT.orangeDunkel),
              title: const Text('Zeugnis oder Zertifikat aus dem Archiv'),
              onTap: () async {
                final kand = store.briefe.where((x) => !b.briefIds.contains(x.id)).take(60).toList();
                final id = await showDialog<String>(
                  context: context,
                  builder: (d) => SimpleDialog(title: const Text('Anlage wählen'), children: [
                    for (final x in kand) SimpleDialogOption(onPressed: () => Navigator.pop(d, x.id), child: Text(titelVon(x))),
                  ]),
                );
                if (id == null) return;
                b.briefIds.add(id);
                await store.geaendert();
              },
            ),
            for (final u in info.unterlagen.where((u) => !['Anschreiben', 'Lebenslauf', 'Zeugnisse'].contains(u)))
              CheckboxListTile(
                value: b.erledigt.contains(u),
                title: Text(u),
                subtitle: const Text('wird in der Anzeige verlangt'),
                onChanged: (v) {
                  v == true ? b.erledigt.add(u) : b.erledigt.remove(u);
                  store.geaendert();
                },
              ),
          ]),
        ),
        PTKarte(
          farbe: fehlt.isEmpty ? PT.gruenHell : PT.gelbHell,
          child: fehlt.isEmpty
              ? const Text('Vollständig – alles dabei, was die Anzeige verlangt.', style: TextStyle(fontWeight: FontWeight.w700))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Noch offen', style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final x in fehlt) Text('• $x'),
                ]),
        ),
        FilledButton.icon(
          onPressed: senden,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Bewerbung per E-Mail senden'),
        ),
        // ------------------------------ Danach
        const Abschnitt('Danach'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined, color: PT.orangeDunkel),
          title: Text(b.gespraechAm == null ? 'Termin fürs Vorstellungsgespräch eintragen' : 'Gespräch am ${datumLang(b.gespraechAm!)}'),
          onTap: () async {
            final d = await datumWaehlen(context, start: b.gespraechAm ?? DateTime.now().add(const Duration(days: 7)));
            if (d == null) return;
            b
              ..gespraechAm = d
              ..status = 'Gespräch';
            store.termine.removeWhere((t) => t.id == 'bew-${b.id}');
            await store.terminSpeichern(Termin(id: 'bew-${b.id}', titel: 'Vorstellungsgespräch ${b.firma}', datum: d));
          },
        ),
        OutlinedButton.icon(
          onPressed: () => oeffne(KiTextScreen(titel: 'Gespräch vorbereiten', anfrage: gespraechAnfrage(b, l, p))),
          icon: const Icon(Icons.record_voice_over_outlined),
          label: const Text('Vorstellungsgespräch vorbereiten (KI)'),
        ),
        if (b.status == 'Beworben')
          OutlinedButton.icon(
            onPressed: () => oeffne(VorlageScreen(
              titel: 'Nachfrage',
              text: '${b.kontakt.isEmpty ? 'Sehr geehrte Damen und Herren,' : 'Guten Tag ${b.kontakt},'}\n\n'
                  'am ${b.beworbenAm == null ? '[Datum]' : datumKurz(b.beworbenAm!)} habe ich mich bei Ihnen als ${b.stelle} beworben. '
                  'Die Stelle interessiert mich weiterhin sehr. Darf ich fragen, wie der aktuelle Stand ist?\n\n'
                  'Mit freundlichen Grüßen\n${p.name}',
            )),
            icon: const Icon(Icons.mark_email_unread_outlined),
            label: const Text('Freundlich nachfragen'),
          ),
      ]),
    );
  }
}

class _AnschreibenScreen extends StatefulWidget {
  const _AnschreibenScreen({required this.bewerbung});

  final Bewerbung bewerbung;

  @override
  State<_AnschreibenScreen> createState() => _AnschreibenScreenState();
}

class _AnschreibenScreenState extends State<_AnschreibenScreen> {
  late final _c = TextEditingController(text: widget.bewerbung.anschreiben);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anschreiben'),
        actions: [
          IconButton(
            tooltip: 'Neu mit KI',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () {
              widget.bewerbung.anschreiben = '';
              store.geaendert();
              Navigator.of(context).pop();
            },
          ),
          IconButton(
            tooltip: 'Als PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              final d = await antwortAlsPdf(_c.text, titel: 'Anschreiben ${widget.bewerbung.firma}');
              await dateiTeilen(d.path, mimeType: 'application/pdf');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(controller: _c, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: feld()),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              widget.bewerbung.anschreiben = _c.text.trim();
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

// ---------------------------------------------------------------- Arbeitszeugnis

class ZeugnisScreen extends StatefulWidget {
  const ZeugnisScreen({super.key});

  @override
  State<ZeugnisScreen> createState() => _ZeugnisScreenState();
}

class _ZeugnisScreenState extends State<ZeugnisScreen> {
  String _text = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final formel = _text.isEmpty ? null : zeugnisFormel(_text);
    final kand = store.briefe.where((b) => RegExp('zeugnis', caseSensitive: false).hasMatch('${b.titel ?? ''} ${b.kiArt ?? ''} ${b.text}')).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Arbeitszeugnis verstehen')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Zeugnisse sind wohlwollend formuliert – die Note steckt in bestimmten Formulierungen.',
            style: TextStyle(color: PT.grau)),
        const Abschnitt('Zeugnis wählen'),
        for (final b in kand)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, color: PT.orangeDunkel),
            title: Text(titelVon(b)),
            onTap: () => setState(() => _text = b.text),
          ),
        TextButton.icon(
          onPressed: () async {
            final t = await _eingabe(context, 'Zeugnistext einfügen', start: _text, zeilen: 10);
            if (t != null) setState(() => _text = t);
          },
          icon: const Icon(Icons.content_paste),
          label: const Text('Text einfügen'),
        ),
        const Text('Tipp: Ein Papierzeugnis scannst du über „Brief scannen“ ins Archiv.', style: TextStyle(color: PT.grau, fontSize: 12)),
        if (_text.isNotEmpty) ...[
          const SizedBox(height: 8),
          PTKarte(
            farbe: formel == null ? PT.sand : (formel.$1 <= 2 ? PT.gruenHell : (formel.$1 <= 3 ? PT.gelbHell : PT.rotHell)),
            child: Text(
              formel == null
                  ? 'Keine typische Zufriedenheitsformel gefunden – die KI-Auswertung hilft weiter.'
                  : 'Zufriedenheitsformel entspricht etwa Note ${formel.$1} (${formel.$2}).',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => KiTextScreen(
                titel: 'Zeugnis in Klartext',
                anfrage: zeugnisAnfrage(_text),
                hinweis: 'Einschätzung, keine Rechtsberatung. Bei Streit über ein Zeugnis: Beratung (z. B. Gewerkschaft, Fachanwalt).',
              ),
            )),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ganzes Zeugnis übersetzen (KI)'),
          ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------- Weiterbildung

class WeiterbildungScreen extends StatelessWidget {
  const WeiterbildungScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = store.karriere.weiterbildungen;
    final summe = l.fold(0.0, (s, w) => s + (w.kosten ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('Weiterbildung')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bearbeiten(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Weiterbildung'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
        if (summe > 0) Text('Kosten gesamt: ${euro(summe)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final w in l)
          PTKarte(
            padding: const EdgeInsets.all(12),
            onTap: () => _bearbeiten(context, w),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    [
                      w.status,
                      if (w.anbieter.isNotEmpty) w.anbieter,
                      if (w.von != null) 'ab ${datumKurz(w.von!)}',
                      if (w.kosten != null) euro(w.kosten!),
                      if (w.foerderung.isNotEmpty) 'Förderung: ${w.foerderung}',
                    ].join(' · '),
                    style: const TextStyle(color: PT.grau, fontSize: 13),
                  ),
                ]),
              ),
              if (w.anmeldungBis != null && w.status == 'Geplant') FristEtikett(w.anmeldungBis!),
            ]),
          ),
        const Abschnitt('Wer bezahlt mit?'),
        for (final (titel, text) in foerderHinweise)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.savings_outlined, color: PT.orangeDunkel),
            title: Text(titel, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(text),
          ),
        const Text('Allgemeine Hinweise – die Bedingungen prüft die jeweilige Stelle.', style: TextStyle(color: PT.grau, fontSize: 12)),
      ]),
    );
  }

  Future<void> _bearbeiten(BuildContext context, Weiterbildung? w) async {
    final store = StoreScope.of(context);
    final titel = TextEditingController(text: w?.titel ?? '');
    final anbieter = TextEditingController(text: w?.anbieter ?? '');
    final kosten = TextEditingController(text: w?.kosten == null ? '' : w!.kosten!.toStringAsFixed(2).replaceAll('.', ','));
    final foerderung = TextEditingController(text: w?.foerderung ?? '');
    var status = w?.status ?? 'Geplant';
    DateTime? von = w?.von, anmeldung = w?.anmeldungBis;
    final ok = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text(w == null ? 'Neue Weiterbildung' : 'Weiterbildung'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titel, decoration: feld(labelText: 'Kurs bzw. Abschluss')),
              const SizedBox(height: 8),
              TextField(controller: anbieter, decoration: feld(labelText: 'Anbieter')),
              const SizedBox(height: 8),
              TextField(
                  controller: kosten,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: feld(labelText: 'Kosten', suffixText: '€')),
              const SizedBox(height: 8),
              TextField(controller: foerderung, decoration: feld(labelText: 'Förderung (z. B. Bildungsgutschein)')),
              Wrap(spacing: 6, children: [
                for (final s in weiterbildungsStatus)
                  ChoiceChip(label: Text(s), selected: status == s, onSelected: (_) => setze(() => status = s)),
              ]),
              TextButton(
                onPressed: () async {
                  final x = await datumWaehlen(d, start: anmeldung);
                  if (x != null) setze(() => anmeldung = x);
                },
                child: Text(anmeldung == null ? 'Anmeldeschluss …' : 'Anmeldung bis ${datumKurz(anmeldung!)}'),
              ),
              TextButton(
                onPressed: () async {
                  final x = await datumWaehlen(d, start: von);
                  if (x != null) setze(() => von = x);
                },
                child: Text(von == null ? 'Beginn …' : 'Beginn ${datumKurz(von!)}'),
              ),
            ]),
          ),
          actions: [
            if (w != null) TextButton(onPressed: () => Navigator.pop(d, 'weg'), child: const Text('Löschen')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final t = titel.text.trim(), a = anbieter.text.trim(), f = foerderung.text.trim();
    final k = double.tryParse(kosten.text.replaceAll('.', '').replaceAll(',', '.'));
    for (final c in [titel, anbieter, kosten, foerderung]) {
      c.dispose();
    }
    final l = store.karriere.weiterbildungen;
    if (ok == 'weg' && w != null) {
      l.remove(w);
    } else if (ok == 'ok' && t.isNotEmpty) {
      final x = w ?? Weiterbildung(id: neueId(), titel: t);
      x
        ..titel = t
        ..anbieter = a
        ..kosten = k
        ..foerderung = f
        ..status = status
        ..von = von
        ..anmeldungBis = anmeldung;
      if (w == null) l.add(x);
      if (anmeldung != null && status == 'Geplant') {
        store.termine.removeWhere((t) => t.id == 'wb-${x.id}');
        await store.terminSpeichern(Termin(id: 'wb-${x.id}', titel: 'Anmeldeschluss: $t', datum: anmeldung!));
        return;
      }
    } else {
      return;
    }
    await store.geaendert();
  }
}


// ---------------------------------------------------------------- Gehaltsabrechnungen

class GehaltScreen extends StatelessWidget {
  const GehaltScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = gehaltsVerlauf(store.briefe);
    final auff = gehaltsAuffaelligkeiten(l);
    String e(double? x) => x == null ? '–' : euro(x);
    return Scaffold(
      appBar: AppBar(title: const Text('Gehaltsabrechnungen')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (l.isEmpty)
          const LeerHinweis(
            icon: Icons.payments_outlined,
            text: 'Scanne deine Lohn- oder Gehaltsabrechnungen wie einen Brief – der Tiger zeigt dann Brutto und Netto im Verlauf.',
          ),
        for (final a in auff) PTKarte(farbe: PT.gelbHell, child: Text(a)),
        for (final g in l.reversed)
          PTKarte(
            padding: const EdgeInsets.all(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: g.brief.id))),
            child: Row(children: [
              Expanded(child: Text('${g.monat.month}/${g.monat.year}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('Brutto ${e(g.brutto)}\nNetto ${e(g.netto)}', textAlign: TextAlign.right),
            ]),
          ),
        if (l.isNotEmpty)
          const Text('Tipp: In der Abrechnung unter „Genauer prüfen“ rechnet die KI Steuer und Abzüge nach.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
      ]),
    );
  }
}
