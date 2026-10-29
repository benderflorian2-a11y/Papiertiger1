import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/store.dart';
import '../../logic/android_kanal.dart';
import '../../logic/antrag_logik.dart';
import '../../logic/export.dart';
import '../../logic/inhalte.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

IconData antragIcon(String key) => switch (key) {
      'kindergeld' || 'kinderzuschlag' => Icons.child_care_outlined,
      'elterngeld' => Icons.stroller_outlined,
      'wohngeld' => Icons.house_outlined,
      'bafoeg' => Icons.school_outlined,
      'rundfunk' => Icons.radio_outlined,
      'buergergeld' => Icons.support_outlined,
      _ => Icons.assignment_outlined,
    };

class AntraegeScreen extends StatelessWidget {
  const AntraegeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Anträge')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
              'Der Tiger bereitet deinen Antrag vor: was gefragt wird, welche Unterlagen du brauchst und wo du ihn stellst. '
              'Einreichen tust du selbst.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          for (final a in antraege)
            Builder(builder: (context) {
              final fertig = [
                for (var i = 0; i < a.unterlagen.length; i++)
                  if (store.checklisten['antrag:${a.key}:$i'] == true) i
              ].length;
              final gestellt = DateTime.tryParse(store.notizen[antragGestelltSchluessel(a)] ?? '');
              return PTKarte(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AntragScreen(antrag: a))),
                child: Row(
                  children: [
                    IconKachel(antragIcon(a.key)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.titel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(gestellt != null ? 'Gestellt am ${datumKurz(gestellt)}' : a.untertitel,
                              style: const TextStyle(color: PT.grau, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (gestellt != null)
                      const Icon(Icons.check_circle, color: PT.gruen)
                    else
                      Text('$fertig/${a.unterlagen.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class AntragScreen extends StatefulWidget {
  const AntragScreen({super.key, required this.antrag});

  final AntragsHelfer antrag;

  @override
  State<AntragScreen> createState() => _AntragScreenState();
}

class _AntragScreenState extends State<AntragScreen> {
  List<TextEditingController>? _felder;
  late AppStore _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = _store = StoreScope.of(context);
    _felder ??= [
      for (var i = 0; i < widget.antrag.fragen.length; i++)
        TextEditingController(text: antragAntwort(widget.antrag, i, store.notizen, store.profil)),
    ];
  }

  @override
  void dispose() {
    for (final f in _felder ?? const <TextEditingController>[]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sichern() async {
    final store = _store;
    for (var i = 0; i < _felder!.length; i++) {
      final t = _felder![i].text.trim();
      final k = antragSchluessel(widget.antrag, i);
      if (t.isEmpty) {
        store.notizen.remove(k);
      } else {
        store.notizen[k] = t;
      }
    }
    await store.geaendert();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.antrag;
    final store = StoreScope.of(context);
    final gestellt = DateTime.tryParse(store.notizen[antragGestelltSchluessel(a)] ?? '');
    return PopScope(
      onPopInvokedWithResult: (_, __) => _sichern(),
      child: Scaffold(
        appBar: AppBar(title: Text(a.titel)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            PTKarte(
              farbe: PT.orangeHell,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Wo stellst du den Antrag?', style: TextStyle(color: PT.grau)),
                  const SizedBox(height: 4),
                  Text(a.stelle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(a.wo, style: const TextStyle(height: 1.4)),
                  if (a.link != null)
                    TextButton.icon(
                      onPressed: () => AndroidKanal.oeffnen(Uri.parse(a.link!)),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Offizielle Seite öffnen'),
                    ),
                ],
              ),
            ),
            const Abschnitt('1. Diese Unterlagen brauchst du'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < a.unterlagen.length; i++)
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      value: store.checklisten['antrag:${a.key}:$i'] == true,
                      title: Text(a.unterlagen[i]),
                      onChanged: (v) => store.checklistePunkt('antrag:${a.key}:$i', v ?? false),
                    ),
                ],
              ),
            ),
            const Abschnitt('2. Diese Fragen kommen im Antrag'),
            const Text(
                'Trag deine Antworten hier vor – sie werden gespeichert. Angaben zu dir übernimmt der Tiger aus deinem Profil.',
                style: TextStyle(color: PT.grau)),
            const SizedBox(height: 12),
            for (var i = 0; i < a.fragen.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _felder![i],
                  minLines: 1,
                  maxLines: 3,
                  decoration: feld(labelText: a.fragen[i]),
                  onEditingComplete: _sichern,
                ),
              ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _sichern();
                    Clipboard.setData(ClipboardData(text: antragAlsText(a, store.notizen, store.profil)));
                    if (context.mounted) zeigeHinweis(context, 'Deine Angaben sind kopiert.');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Kopieren'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _sichern();
                    await textTeilen(antragAlsText(a, store.notizen, store.profil));
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Teilen'),
                ),
              ),
            ]),
            const Abschnitt('3. Vollständig?'),
            Builder(builder: (context) {
              final st = antragPruefen(a, store.notizen, store.profil, store.checklisten);
              return PTKarte(
                farbe: st.vollstaendig ? PT.gruenHell : PT.gelbHell,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    st.vollstaendig
                        ? 'Alles beisammen. Du kannst den Antrag stellen.'
                        : '${st.offeneFragen.length} ${st.offeneFragen.length == 1 ? 'Frage' : 'Fragen'} offen, '
                            '${st.fehlendeUnterlagen.length} ${st.fehlendeUnterlagen.length == 1 ? 'Unterlage fehlt' : 'Unterlagen fehlen'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final f in st.offeneFragen) Text('• $f', style: const TextStyle(fontSize: 13)),
                  for (final u in st.fehlendeUnterlagen) Text('• $u', style: const TextStyle(fontSize: 13)),
                  if (!st.vollstaendig)
                    const Text('Antworten werden beim Verlassen der Seite gespeichert.',
                        style: TextStyle(fontSize: 12, color: PT.grau)),
                ]),
              );
            }),
            const Abschnitt('4. Antrag stellen'),
            if (gestellt == null)
              FilledButton.icon(
                onPressed: () async {
                  final d = await datumWaehlen(context, start: DateTime.now());
                  if (d == null) return;
                  await _sichern();
                  store.notizen[antragGestelltSchluessel(a)] = d.toIso8601String();
                  final t = antragNachfragen(a, d);
                  await store.terminSpeichern(t);
                  if (context.mounted) {
                    zeigeHinweis(context,
                        'Vermerkt. Kommt bis ${datumKurz(t.datum)} kein Bescheid, erinnert dich der Tiger ans Nachfragen.');
                  }
                },
                icon: const Icon(Icons.task_alt),
                label: const Text('Ich habe den Antrag gestellt'),
              )
            else
              PTKarte(
                farbe: PT.gruenHell,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: PT.gruen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Gestellt am ${datumKurz(gestellt)}. Den Bescheid kannst du später einfach scannen.'),
                    ),
                    TextButton(
                      onPressed: () {
                        store.notizen.remove(antragGestelltSchluessel(a));
                        store.termine.removeWhere((t) => t.id.startsWith('antrag-${a.key}-'));
                        store.geaendert();
                      },
                      child: const Text('Zurücksetzen'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Allgemeine Hinweise ohne Gewähr. Maßgeblich ist das offizielle Formular der zuständigen Stelle.',
              style: TextStyle(color: PT.grau, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
