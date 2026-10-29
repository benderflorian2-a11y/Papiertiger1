import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/brief_analyse.dart';
import '../logic/vorlagen.dart';
import 'app.dart';
import 'theme.dart';
import 'vorlage_screen.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';
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
    final k = kategorieFuer(b.kategorie);
    final t = typFuer(b.typ);

    return Scaffold(
      appBar: AppBar(
        title: Text(k.name),
        actions: [
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
                      Text(b.absenderName ?? k.name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: PT.tinte)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Etikett(t.name, farbe: PT.orangeDunkel, hintergrund: PT.orangeHell),
                        if (b.erledigt)
                          const Etikett('Erledigt', farbe: PT.gruen, hintergrund: PT.gruenHell)
                        else if (b.frist != null)
                          FristEtikett(b.frist!),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Abschnitt('Einfach erklärt'),
          PTKarte(
            child: Text(b.erklaerung,
                style: const TextStyle(fontSize: 16, height: 1.5, color: PT.tinte)),
          ),

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

Future<String?> _textAbfragen(BuildContext context, String titel) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titel),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Hinzufügen')),
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
