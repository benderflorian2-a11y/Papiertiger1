import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/android_kanal.dart';
import '../logic/export.dart';
import '../logic/kommunikation.dart';
import '../logic/ordnung.dart';
import '../logic/vorlagen.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'theme.dart';
import 'vorlage_screen.dart';
import 'widgets/common.dart';
import 'diktat.dart';

const _sendungsverfolgung = 'https://www.deutschepost.de/de/s/sendungsverfolgung.html';

IconData verlaufIcon(Eintrag e) => switch (e.art) {
      'gesendet' => switch (e.weg) {
          'E-Mail' => Icons.alternate_email,
          'Fax' => Icons.fax_outlined,
          'Einschreiben' => Icons.verified_outlined,
          'Online-Portal' => Icons.language,
          'Persönlich abgegeben' => Icons.front_hand_outlined,
          _ => Icons.outgoing_mail,
        },
      'erhalten' => Icons.mark_email_read_outlined,
      'anruf' => Icons.call_outlined,
      _ => Icons.sticky_note_2_outlined,
    };

/// Fragt, wie die Antwort verschickt wurde, und plant das Nachfassen.
Future<bool> versandVermerken(BuildContext context, Brief b, {String weg = 'Post', String text = ''}) async {
  final store = StoreScope.of(context);
  var gewaehlt = weg;
  var datum = DateTime.now();
  final nummer = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setze) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wie hast du geantwortet?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final w in versandWege)
                ChoiceChip(label: Text(w), selected: gewaehlt == w, onSelected: (_) => setze(() => gewaehlt = w)),
            ]),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text('Verschickt am ${datumKurz(datum)}'),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () async {
                final d = await datumWaehlen(c, start: datum);
                if (d != null) setze(() => datum = d);
              },
            ),
            if (gewaehlt == 'Einschreiben')
              TextField(
                controller: nummer,
                decoration: feld(labelText: 'Sendungsnummer (optional)', hintText: 'z. B. RT 1234 5678 9DE'),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Vermerken')),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true) {
    nummer.dispose();
    return false;
  }
  antwortVermerken(b, weg: gewaehlt, am: datum, text: text, sendungsnummer: nummer.text);
  nummer.dispose();
  await store.geaendert();
  if (context.mounted) {
    zeigeHinweis(context, 'Vermerkt. Kommt bis ${datumKurz(b.nachfassenAm!)} keine Antwort, erinnert dich der Tiger.');
  }
  return true;
}

/// Telefonnotiz oder freie Notiz zum Brief.
class NotizScreen extends StatefulWidget {
  const NotizScreen({super.key, required this.brief, this.anruf = false, this.nummer});

  final Brief brief;
  final bool anruf;
  final String? nummer;

  @override
  State<NotizScreen> createState() => _NotizScreenState();
}

class _NotizScreenState extends State<NotizScreen> {
  final _person = TextEditingController();
  final _text = TextEditingController();
  DateTime _datum = DateTime.now();
  bool _alsAufgabe = false;

  @override
  void dispose() {
    _person.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.anruf ? 'Telefonat notieren' : 'Notiz')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(titelVon(widget.brief), style: const TextStyle(color: PT.grau)),
          const SizedBox(height: 12),
          if (widget.anruf) ...[
            TextField(
              controller: _person,
              textCapitalization: TextCapitalization.words,
              decoration: feld(labelText: 'Gesprächspartner', hintText: 'z. B. Frau Meier, Sachbearbeitung'),
            ),
            const SizedBox(height: 12),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(datumKurz(_datum)),
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: () async {
              final d = await datumWaehlen(context, start: _datum);
              if (d != null) setState(() => _datum = d);
            },
          ),
          TextField(
            controller: _text,
            minLines: 5,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: feld(
              labelText: widget.anruf ? 'Was wurde besprochen und vereinbart?' : 'Notiz',
              hintText: widget.anruf ? 'z. B. Frist bis 30.11. verlängert, Bestätigung kommt per Post.' : null,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _alsAufgabe,
            title: const Text('Als Aufgabe übernehmen'),
            subtitle: const Text('Steht dann unter „Deine Aufgaben“ und zählt, bis du sie abhakst.'),
            onChanged: (v) => setState(() => _alsAufgabe = v ?? false),
          ),
          if (widget.anruf)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                  'Tipp: Wichtige Zusagen am Telefon lieber schriftlich bestätigen lassen.',
                  style: TextStyle(color: PT.grau, fontSize: 13)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              if (_text.text.trim().isEmpty && _person.text.trim().isEmpty) {
                zeigeHinweis(context, 'Bitte schreib kurz auf, worum es ging.');
                return;
              }
              widget.brief.verlauf.add(Eintrag(
                id: neueId(),
                datum: _datum,
                art: widget.anruf ? 'anruf' : 'notiz',
                weg: widget.anruf ? 'Telefon' : '',
                text: _text.text.trim(),
                person: _person.text.trim().isEmpty ? null : _person.text.trim(),
              ));
              if (_alsAufgabe && _text.text.trim().isNotEmpty) {
                widget.brief.aufgaben.add(Aufgabe(_text.text.trim().split('\n').first));
                widget.brief.erledigt = false;
              }
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

/// Kontaktdaten des Absenders aus dem Brief: E-Mail, Telefon, Fax, Anschrift.
class KontaktKarte extends StatelessWidget {
  const KontaktKarte({super.key, required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final k = kontaktVon(brief, store.profil);
    if (k.leer) return const SizedBox.shrink();
    final betreff = [
      if (brief.aktenzeichen != null) brief.aktenzeichen!,
      'Ihr Schreiben${brief.briefDatum != null ? ' vom ${datumKurz(brief.briefDatum!)}' : ''}',
    ].join(' – ');
    return PTKarte(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final e in k.emails)
            ListTile(
              leading: const Icon(Icons.alternate_email, color: PT.orangeDunkel),
              title: Text(e),
              subtitle: const Text('E-Mail schreiben'),
              onTap: () async {
                final ok = await AndroidKanal.oeffnen(mailtoLink(an: e, betreff: betreff));
                if (!ok && context.mounted) zeigeHinweis(context, 'Keine E-Mail-App gefunden.');
              },
            ),
          for (final t in k.telefon)
            ListTile(
              leading: const Icon(Icons.call_outlined, color: PT.orangeDunkel),
              title: Text(t),
              subtitle: const Text('Anrufen – danach Gespräch notieren'),
              onTap: () async {
                final ok = await AndroidKanal.oeffnen(Uri.parse('tel:${nummerWaehlbar(t)}'));
                if (!context.mounted) return;
                if (!ok) {
                  zeigeHinweis(context, 'Telefon-App konnte nicht geöffnet werden.');
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 12),
                  content: const Text('Gespräch notieren?'),
                  action: SnackBarAction(
                    label: 'Notieren',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NotizScreen(brief: brief, anruf: true, nummer: t))),
                  ),
                ));
              },
            ),
          for (final f in k.fax)
            ListTile(
              leading: const Icon(Icons.fax_outlined, color: PT.orangeDunkel),
              title: Text(f),
              subtitle: const Text('Fax – tippen zum Kopieren'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: f));
                zeigeHinweis(context, 'Faxnummer kopiert');
              },
            ),
          if (k.adresse != null)
            ListTile(
              leading: const Icon(Icons.location_on_outlined, color: PT.orangeDunkel),
              title: Text(k.adresse!),
              subtitle: const Text('Anschrift – tippen zum Kopieren'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: k.adresse!));
                zeigeHinweis(context, 'Anschrift kopiert');
              },
            ),
        ],
      ),
    );
  }
}

/// Schriftverkehr zu einem Brief mit Aktionen.
class VerlaufKarte extends StatelessWidget {
  const VerlaufKarte({super.key, required this.brief});

  final Brief brief;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final b = brief;
    final eintraege = verlaufVon(b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (b.nachfassenAm != null)
          PTKarte(
            farbe: PT.orangeHell,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Du wartest auf eine Antwort', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Erinnerung zum Nachfassen am ${datumKurz(b.nachfassenAm!)}, falls nichts kommt.'),
                Wrap(spacing: 8, children: [
                  TextButton(
                    onPressed: () {
                      antwortErhalten(b);
                      store.geaendert();
                    },
                    child: const Text('Antwort ist da'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VorlageScreen(
                        titel: 'Nachfrage',
                        text: vorlageText('nachfrage', b, store.profil),
                        brief: b,
                      ),
                    )),
                    child: const Text('Nachfrage schreiben'),
                  ),
                ]),
              ],
            ),
          ),
        if (eintraege.isNotEmpty)
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final e in eintraege)
                  ListTile(
                    leading: Icon(verlaufIcon(e), color: PT.orangeDunkel),
                    title: Text(verlaufTitel(e), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      datumKurz(e.datum),
                      if (e.sendungsnummer != null) 'Sendungsnummer ${e.sendungsnummer}',
                      if (e.text.isNotEmpty) e.text,
                    ].join('\n')),
                    isThreeLine: e.text.isNotEmpty || e.sendungsnummer != null,
                    onTap: e.sendungsnummer == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: e.sendungsnummer!));
                            zeigeHinweis(context, 'Sendungsnummer kopiert – auf der Seite der Post einfügen.');
                            AndroidKanal.oeffnen(Uri.parse(_sendungsverfolgung));
                          },
                    onLongPress: e.id == 'alt'
                        ? null
                        : () async {
                            final weg = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('Eintrag löschen?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
                                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Löschen')),
                                ],
                              ),
                            );
                            if (weg == true) {
                              b.verlauf.removeWhere((x) => x.id == e.id);
                              await store.geaendert();
                            }
                          },
                  ),
              ],
            ),
          ),
        Wrap(spacing: 8, runSpacing: 4, children: [
          OutlinedButton.icon(
            onPressed: () => versandVermerken(context, b),
            icon: const Icon(Icons.outgoing_mail, size: 18),
            label: const Text('Antwort verschickt'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => NotizScreen(brief: b, anruf: true))),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: const Text('Telefonat'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotizScreen(brief: b))),
            icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
            label: const Text('Notiz'),
          ),
          if (eintraege.isNotEmpty)
            TextButton.icon(
              onPressed: () => textTeilen(verlaufAlsText(b)),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Verlauf teilen'),
            ),
        ]),
      ],
    );
  }
}

/// Überblick: worauf du wartest und was zuletzt verschickt wurde.
class KommunikationScreen extends StatelessWidget {
  const KommunikationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final warten = wartetAufAntwort(store.briefe);
    final verlauf = gesamtVerlauf(store.briefe).take(50).toList();
    void oeffnen(Brief b) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id)));
    return Scaffold(
      appBar: AppBar(title: const Text('Schriftverkehr')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiktatScreen())),
        icon: const Icon(Icons.mic),
        label: const Text('Diktieren'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (warten.isEmpty && verlauf.isEmpty)
            const LeerHinweis(
              icon: Icons.forum_outlined,
              text: 'Noch kein Schriftverkehr. Wenn du auf einen Brief antwortest, vermerkt der Tiger es hier '
                  'und erinnert dich, falls keine Antwort kommt.',
            ),
          if (warten.isNotEmpty) ...[
            const Abschnitt('Du wartest auf Antwort'),
            for (final b in warten)
              PTKarte(
                onTap: () => oeffnen(b),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const IconKachel(Icons.hourglass_top_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titelVon(b),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            'Geantwortet ${b.antwortGesendet != null ? 'am ${datumKurz(b.antwortGesendet!)}' : ''} · '
                            'nachfassen ab ${datumKurz(b.nachfassenAm!)}',
                            style: const TextStyle(color: PT.grau, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    FristEtikett(b.nachfassenAm!),
                  ],
                ),
              ),
          ],
          if (verlauf.isNotEmpty) ...[
            const Abschnitt('Verlauf'),
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final z in verlauf)
                    ListTile(
                      leading: Icon(verlaufIcon(z.eintrag), color: PT.orangeDunkel),
                      title: Text(titelVon(z.brief), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${datumKurz(z.eintrag.datum)} · ${verlaufTitel(z.eintrag)}'),
                      onTap: () => oeffnen(z.brief),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
