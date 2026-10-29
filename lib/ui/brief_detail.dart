import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/brief_analyse.dart';
import '../logic/export.dart';
import '../logic/ki_anfragen.dart';
import '../logic/ordnung.dart';
import '../logic/zeitplan.dart';
import '../logic/vorlagen.dart';
import 'akten.dart';
import 'app.dart';
import 'finanzen.dart';
import 'formular_screen.dart';
import 'kalender.dart';
import 'kommunikation.dart';
import 'module/vertraege.dart';
import 'rechtsbehelf_karte.dart';
import 'termine.dart';
import 'ki_text.dart';
import 'theme.dart';
import 'vorlage_screen.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';
import 'widgets/ki_karte.dart';
import 'widgets/tiger.dart';

Brief? _finde(List<Brief> liste, String id) {
  for (final b in liste) {
    if (b.id == id) return b;
  }
  return null;
}

class BriefDetail extends StatelessWidget {
  const BriefDetail({super.key, required this.briefId, this.neu = false});

  final String briefId;
  final bool neu;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = _finde(store.briefe, briefId);
    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const LeerHinweis(icon: Icons.mail_outline, text: 'Dieser Brief wurde gelöscht.'),
      );
    }
    final t = typFuer(b.typ);
    final duplikat = b.duplikatVon == null ? null : _finde(store.briefe, b.duplikatVon!);
    final akte = aktenBilden(store.briefe).firstWhere((a) => a.briefe.any((x) => x.id == b.id));
    final ablage = aufbewahrung(b);

    return Scaffold(
      appBar: AppBar(
        title: Text(ordnerFuer(b).name),
        actions: [
          IconButton(
            tooltip: 'Teilen',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _teilenMenue(context, b),
          ),
          IconButton(
            tooltip: 'Umbenennen',
            icon: const Icon(Icons.drive_file_rename_outline),
            onPressed: () async {
              final neuerTitel = await _textAbfragen(context, 'Titel ändern',
                  start: titelVon(b), knopf: 'Speichern');
              if (neuerTitel != null) {
                b.titel = neuerTitel.trim().isEmpty ? null : neuerTitel.trim();
                await store.geaendert();
              }
            },
          ),
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Brief löschen?'),
                  content: const Text('Der Brief und seine Fotos werden vom Handy gelöscht.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Abbrechen')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Löschen')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.of(context).pop();
                await store.briefLoeschen(b);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (neu)
            PTKarte(
              farbe: PT.orangeHell,
              child: Row(
                children: [
                  const Tiger(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      b.frist != null && !b.erledigt
                          ? 'Fertig! Achte auf die Frist am ${datumKurz(b.frist!)}.'
                          : 'Fertig! Das hat der Tiger verstanden.',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: PT.tinte),
                    ),
                  ),
                ],
              ),
            ),

          if (duplikat != null)
            PTKarte(
              farbe: PT.gelbHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.copy_all_outlined, color: PT.gelb),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Diesen Brief hast du vermutlich schon gespeichert.',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BriefDetail(briefId: duplikat.id))),
                      child: const Text('Original ansehen'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await store.briefLoeschen(b);
                      },
                      child: const Text('Duplikat löschen'),
                    ),
                    TextButton(
                      onPressed: () {
                        b.duplikatVon = null;
                        store.geaendert();
                      },
                      child: const Text('Behalten'),
                    ),
                  ]),
                ],
              ),
            ),

          // Kopf
          PTKarte(
            child: Row(
              children: [
                IconKachel(kategorieIcon(b.kategorie)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titelVon(b),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: PT.tinte)),
                      if (b.person != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('An: ${b.person}',
                              style: const TextStyle(color: PT.grau, fontSize: 13)),
                        ),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (b.erledigt)
                          const Etikett('Erledigt', farbe: PT.gruen, hintergrund: PT.gruenHell)
                        else ...[
                          DringlichkeitEtikett(dringlichkeit(b)),
                          if (b.frist != null) FristEtikett(b.frist!),
                        ],
                        Etikett(b.kiArt ?? t.name, farbe: PT.orangeDunkel, hintergrund: PT.orangeHell),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Abschnitt('Einfach erklärt'),
          PTKarte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.erklaerung,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: PT.tinte)),
                if (b.kiFertig) ...[
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: PT.grau),
                      SizedBox(width: 6),
                      Text('Vom Tiger komplett gelesen',
                          style: TextStyle(color: PT.grau, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          KiKarte(brief: b),

          if (b.fakten.isNotEmpty) ...[
            const Abschnitt('Das steht drin'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final f in b.fakten)
                    ListTile(
                      title: Text(f.label, style: const TextStyle(color: PT.grau, fontSize: 13)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.wert,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: PT.tinte)),
                          if (f.hinweis.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(f.hinweis,
                                  style: const TextStyle(fontSize: 13, height: 1.35, color: PT.grau)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          if (b.hinweise.isNotEmpty) ...[
            const Abschnitt('Bitte prüfen'),
            PTKarte(
              farbe: PT.gelbHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final h in b.hinweise)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.report_problem_outlined, size: 18, color: PT.gelb),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(h, style: const TextStyle(height: 1.4))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text('Hinweise der KI – sie kann sich irren.',
                      style: TextStyle(color: PT.grau, fontSize: 12)),
                ],
              ),
            ),
          ],

          if (b.bedeutung.isNotEmpty) ...[
            const Abschnitt('Was heißt das für dich?'),
            PTKarte(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final z in b.bedeutung)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(Icons.lightbulb_outline, size: 18, color: PT.orangeDunkel),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(z, style: const TextStyle(height: 1.45))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const Abschnitt('Das Wichtigste'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.event_outlined, color: PT.orangeDunkel),
                  title: const Text('Frist'),
                  subtitle: Text(b.frist == null
                      ? 'Keine gefunden – tippen zum Eintragen'
                      : '${datumLang(b.frist!)}${b.fristUnsicher ? ' (bitte prüfen)' : ''}'),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () async {
                    final d = await datumWaehlen(context, start: b.frist);
                    if (d != null) {
                      b.frist = d;
                      b.fristUnsicher = false;
                      await store.geaendert();
                    }
                  },
                ),
                if (b.betrag != null)
                  ListTile(
                    leading: Icon(b.guthaben ? Icons.savings_outlined : Icons.euro,
                        color: PT.orangeDunkel),
                    title: Text(b.guthaben ? 'Guthaben / Erstattung' : 'Betrag'),
                    subtitle: Text(euro(b.betrag!)),
                  ),
                if (b.aktenzeichen != null)
                  ListTile(
                    leading: const Icon(Icons.tag, color: PT.orangeDunkel),
                    title: Text(b.aktenzeichen!.split(': ').first),
                    subtitle: Text(b.aktenzeichen!.split(': ').last),
                    trailing: const Icon(Icons.copy, size: 20),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: b.aktenzeichen!.split(': ').last));
                      zeigeHinweis(context, 'Kopiert');
                    },
                  ),
                if (b.briefDatum != null)
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined, color: PT.orangeDunkel),
                    title: const Text('Datum des Briefs'),
                    subtitle: Text(datumLang(b.briefDatum!)),
                  ),
              ],
            ),
          ),

          RechtsbehelfKarte(brief: b),
          ZahlungKarte(brief: b),
          if (b.unterlagen.isNotEmpty) ...[
            Abschnitt('Diese Unterlagen werden verlangt '
                '(${b.unterlagen.where((u) => u.erledigt).length}/${b.unterlagen.length})'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final u in b.unterlagen)
                    CheckboxListTile(
                      value: u.erledigt,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(u.text,
                          style: TextStyle(
                              decoration: u.erledigt ? TextDecoration.lineThrough : null)),
                      onChanged: (v) {
                        u.erledigt = v ?? false;
                        store.geaendert();
                        if (b.unterlagen.every((x) => x.erledigt) && b.antwortGesendet == null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 8),
                            content: const Text('Alles beisammen. Unterlagen verschickt?'),
                            action: SnackBarAction(
                              label: 'Ja, erinnern',
                              onPressed: () => versandVermerken(context, b, text: 'Unterlagen nachgereicht'),
                            ),
                          ));
                        }
                      },
                    ),
                ],
              ),
            ),
          ],

          const Abschnitt('Deine Aufgaben'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final a in b.aufgaben)
                  CheckboxListTile(
                    value: a.erledigt,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(a.text,
                        style: TextStyle(
                            decoration: a.erledigt ? TextDecoration.lineThrough : null)),
                    onChanged: (v) {
                      a.erledigt = v ?? false;
                      if (b.aufgaben.every((x) => x.erledigt)) b.erledigt = true;
                      store.geaendert();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.add, color: PT.orangeDunkel),
                  title: const Text('Aufgabe hinzufügen'),
                  onTap: () async {
                    final text = await _textAbfragen(context, 'Neue Aufgabe');
                    if (text != null && text.trim().isNotEmpty) {
                      b.aufgaben.add(Aufgabe(text.trim()));
                      b.erledigt = false;
                      await store.geaendert();
                    }
                  },
                ),
              ],
            ),
          ),
          const Abschnitt('Schriftverkehr'),
          VerlaufKarte(brief: b),
          const SizedBox(height: 12),
          for (final t in termineFinden(b.text))
            PTKarte(
              child: Row(
                children: [
                  const Icon(Icons.event_available_outlined, color: PT.orangeDunkel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Termin erkannt: ${datumKurz(t.zeit)}, ${t.zeit.hour.toString().padLeft(2, '0')}:${t.zeit.minute.toString().padLeft(2, '0')} Uhr',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'In Kalender',
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: () => inKalender(context, titelVon(b), t.zeit,
                        beschreibung: t.ausschnitt, mitUhrzeit: true),
                  ),
                  IconButton(
                    tooltip: 'Als Termin speichern',
                    icon: const Icon(Icons.add_alarm_outlined),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TerminFormular(
                          vorlage: Termin(
                              id: neueId(),
                              titel: titelVon(b),
                              datum: t.zeit,
                              art: 'Behörde',
                              notiz: t.ausschnitt,
                              briefId: b.id)),
                    )),
                  ),
                ],
              ),
            ),
          if (b.frist != null && !b.erledigt)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => inKalender(context, 'Frist: ${titelVon(b)}', b.frist!,
                    beschreibung: b.erklaerung),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Frist in Kalender eintragen'),
              ),
            ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Brief ist erledigt',
                style: TextStyle(fontWeight: FontWeight.w600)),
            value: b.erledigt,
            onChanged: (v) {
              b.erledigt = v;
              store.geaendert();
            },
          ),

          const Abschnitt('Antwort schreiben'),
          KontaktKarte(brief: b),
          FilledButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => KiAntwortScreen(brief: b))),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Antwort mit KI schreiben'),
          ),
          const SizedBox(height: 12),
          const Text('Oder eine feste Vorlage:', style: TextStyle(color: PT.grau)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 0,
            crossAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: [
              for (final v in briefVorlagen)
                PTKarte(
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VorlageScreen(
                      titel: v.titel,
                      text: vorlageText(v.key, b, store.profil),
                      brief: b,
                    ),
                  )),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(v.titel,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: PT.tinte)),
                      const SizedBox(height: 2),
                      Text(v.beschreibung,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: PT.grau, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => FormularScreen(brief: b))),
            icon: const Icon(Icons.edit_document),
            label: const Text('Ist das ein Formular? Ausfüllhilfe'),
          ),
          if (store.briefe.length > 1) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _vergleichen(context, b, store.briefe),
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Mit anderem Dokument vergleichen'),
            ),
          ],

          const Abschnitt('Ablage'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_outlined, color: PT.orangeDunkel),
                  title: const Text('Ordner'),
                  subtitle: Text(ordnerFuer(b).name),
                ),
                if (akte.briefe.length > 1)
                  ListTile(
                    leading: const Icon(Icons.layers_outlined, color: PT.orangeDunkel),
                    title: const Text('Vorgang'),
                    subtitle: Text('${akte.titel} · ${akte.briefe.length} Dokumente'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AkteScreen(schluessel: akte.schluessel))),
                  ),
                ListTile(
                  leading: const Icon(Icons.inventory_outlined, color: PT.orangeDunkel),
                  title: Text(ablage.bis == null
                      ? 'Aufbewahren: dauerhaft bzw. nach Bedarf'
                      : 'Aufbewahren bis mindestens ${datumKurz(ablage.bis!)}'),
                  subtitle: Text('${ablage.text} (Empfehlung, ohne Gewähr)'),
                ),
                if (b.pdfPfad != null)
                  const ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined, color: PT.orangeDunkel),
                    title: Text('Original-PDF ist gespeichert'),
                  ),
              ],
            ),
          ),
          BriefVertragKarte(brief: b),

          const Abschnitt('Für die Steuer'),
          PTKarte(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: b.steuerKategorie,
                hint: const Text('Nicht steuerlich relevant'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Nicht steuerlich relevant')),
                  for (final s in steuerKategorien)
                    DropdownMenuItem<String?>(value: s, child: Text(s)),
                ],
                onChanged: (v) {
                  b.steuerKategorie = v;
                  store.geaendert();
                },
              ),
            ),
          ),

          if (b.bilder.isNotEmpty) ...[
            const Abschnitt('Fotos'),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: b.bilder.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => BildAnsicht(pfad: b.bilder[i]))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(b.bilder[i]),
                        width: 100, height: 140, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 100, color: PT.sand,
                            child: const Icon(Icons.broken_image_outlined))),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Erkannter Text',
                  style: TextStyle(fontWeight: FontWeight.w700, color: PT.tinte)),
              children: [
                PTKarte(child: SelectableText(b.text, style: const TextStyle(height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Der Papiertiger erklärt Schreiben automatisch und kann sich irren. '
            'Er ersetzt keine Rechts- oder Steuerberatung. Prüfe wichtige Angaben immer im Original.',
            style: TextStyle(color: PT.grau, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

void _teilenMenue(BuildContext context, Brief b) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Als PDF mit Erklärung teilen'),
            onTap: () async {
              Navigator.pop(s);
              try {
                final datei = await briefAlsPdf(b);
                await dateiTeilen(datei.path);
              } catch (e) {
                if (context.mounted) zeigeHinweis(context, 'PDF konnte nicht erstellt werden: $e');
              }
            },
          ),
          if (b.pdfPfad != null)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Original-PDF teilen'),
              onTap: () {
                Navigator.pop(s);
                dateiTeilen(b.pdfPfad!);
              },
            ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: const Text('Zusammenfassung als Text teilen'),
            onTap: () {
              Navigator.pop(s);
              final teile = [
                titelVon(b),
                b.erklaerung,
                if (b.frist != null) 'Frist: ${datumKurz(b.frist!)}',
                if (b.aufgaben.isNotEmpty) 'Zu tun:\n${b.aufgaben.map((a) => '- ${a.text}').join('\n')}',
              ];
              textTeilen(teile.join('\n\n'));
            },
          ),
        ],
      ),
    ),
  );
}

void _vergleichen(BuildContext context, Brief b, List<Brief> alle) {
  final akteKey = akteSchluessel(b);
  final andere = alle.where((x) => x.id != b.id).toList()
    ..sort((x, y) {
      int rang(Brief z) => akteSchluessel(z) == akteKey ? 0 : (ordnerFuer(z).key == ordnerFuer(b).key ? 1 : 2);
      final r = rang(x).compareTo(rang(y));
      return r != 0 ? r : (y.briefDatum ?? y.erstellt).compareTo(x.briefDatum ?? x.erstellt);
    });
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (s) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(s).size.height * 0.7,
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Womit vergleichen?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final x in andere)
              ListTile(
                title: Text(titelVon(x), maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(datumKurz(x.briefDatum ?? x.erstellt)),
                trailing: akteSchluessel(x) == akteKey ? const Icon(Icons.layers_outlined, size: 18) : null,
                onTap: () {
                  Navigator.pop(s);
                  final xa = x.briefDatum ?? x.erstellt, ba = b.briefDatum ?? b.erstellt;
                  final alt = xa.isBefore(ba) ? x : b;
                  final neu = identical(alt, x) ? b : x;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => KiTextScreen(
                      titel: 'Vergleich',
                      anfrage: vergleichAnfrage(alt, neu),
                      hinweis: 'Vergleich durch die KI. Prüfe wichtige Werte im Original.',
                    ),
                  ));
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _textAbfragen(BuildContext context, String titel,
    {String start = '', String knopf = 'Hinzufügen'}) {
  final c = TextEditingController(text: start);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titel),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(d, c.text), child: Text(knopf)),
      ],
    ),
  );
}

class BildAnsicht extends StatelessWidget {
  const BildAnsicht({super.key, required this.pfad});

  final String pfad;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: InteractiveViewer(maxScale: 5, child: Image.file(File(pfad))),
      ),
    );
  }
}
