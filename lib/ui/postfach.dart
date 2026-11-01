import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/postfach.dart';
import '../logic/android_kanal.dart' show Geteilt;
import '../logic/benachrichtigungen.dart';
import '../logic/postfach_dienst.dart';
import '../logic/postfach_pruefung.dart';
import 'app.dart';
import 'scan.dart';
import 'theme.dart';
import 'widgets/common.dart';

IconData mailSymbol(String art) => switch (art) {
      'mahnung' => Icons.warning_amber_rounded,
      'rechnung' => Icons.receipt_long_outlined,
      'behoerde' => Icons.account_balance_outlined,
      'vertrag' => Icons.description_outlined,
      'briefankuendigung' => Icons.local_post_office_outlined,
      _ => Icons.mail_outline,
    };

String _datum(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

String _zeit(DateTime d) {
  final h = DateTime.now();
  final uhr = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == h.year && d.month == h.month && d.day == h.day) return 'heute $uhr';
  return '${_datum(d)} $uhr';
}

/// E-Mail-Postfach verknüpfen und gemeldete wichtige E-Mails ansehen.
class PostfachScreen extends StatefulWidget {
  const PostfachScreen({super.key});

  @override
  State<PostfachScreen> createState() => _PostfachScreenState();
}

class _PostfachScreenState extends State<PostfachScreen> {
  bool _sieht = false;

  Future<void> _nachsehen() async {
    final store = StoreScope.of(context);
    setState(() => _sieht = true);
    try {
      final neu = await PostfachDienst.jetzt(store);
      if (!mounted) return;
      final f = store.postfach.konto?.fehler;
      zeigeHinweis(context, f ?? (neu.isEmpty ? 'Nichts Neues, das wichtig ist.' : '${neu.length} wichtige E-Mail${neu.length == 1 ? '' : 's'} gefunden.'));
    } finally {
      if (mounted) setState(() => _sieht = false);
    }
  }

  Future<void> _uebernehmen(MailHinweis h) async {
    final store = StoreScope.of(context);
    final k = store.postfach.konto;
    if (k == null) return;
    setState(() => _sieht = true);
    try {
      final roh = await mailLaden(k, h.uid);
      if (!mounted) return;
      if (roh == null) {
        zeigeHinweis(context, 'Die E-Mail ist nicht mehr im Posteingang.');
        return;
      }
      final datei = File('${(await getTemporaryDirectory()).path}/postfach_${h.uid}.eml');
      await datei.writeAsBytes(roh);
      await store.postfachNeuLaden();
      for (final x in store.postfach.hinweise) {
        if (x.uid == h.uid) x.status = 'uebernommen';
      }
      await store.geaendert();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DateiImportScreen(geteilt: [Geteilt(pfad: datei.path, name: 'mail.eml', mime: 'message/rfc822')])));
    } catch (e) {
      if (mounted) zeigeHinweis(context, 'Laden fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _sieht = false);
    }
  }

  Future<void> _ausblenden(MailHinweis h) async {
    final store = StoreScope.of(context);
    await store.postfachNeuLaden();
    for (final x in store.postfach.hinweise) {
      if (x.uid == h.uid) x.status = 'ignoriert';
    }
    await store.geaendert();
  }

  Future<void> _trennen() async {
    final store = StoreScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Verknüpfung trennen?'),
        content: const Text('Zugangsdaten und die gemeldeten E-Mails werden aus Papiertiger gelöscht. '
            'In deinem Postfach ändert sich nichts. Schon übernommene Briefe bleiben.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Trennen')),
        ],
      ),
    );
    if (ok != true) return;
    await PostfachDienst.trennen(store);
    await store.protokollNotiz('E-Mail-Postfach getrennt');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final k = store.postfach.konto;
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail-Postfach')),
      body: !PostfachDienst.verfuegbar
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Das Postfach lässt sich nur in der Handy-App verknüpfen. Der Browser darf sich nicht mit E-Mail-Servern verbinden.'),
            )
          : k == null
              ? const _Einrichten()
              : _uebersicht(store.postfach, k),
    );
  }

  Widget _uebersicht(Postfach p, PostfachKonto k) {
    final store = StoreScope.of(context);
    final neue = p.neue.reversed.toList();
    final erledigt = p.hinweise.where((h) => h.status != 'neu').toList().reversed.take(20).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      PTKarte(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconKachel(Icons.alternate_email),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.adresse, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(k.zuletzt == null ? 'Noch nicht nachgesehen' : 'Zuletzt nachgesehen: ${_zeit(k.zuletzt!)}',
                    style: const TextStyle(color: PT.grau, fontSize: 13)),
              ]),
            ),
          ]),
          if (k.fehler != null) ...[
            const SizedBox(height: 10),
            Text(k.fehler!, style: const TextStyle(color: PT.rot, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sieht ? null : _nachsehen,
              icon: _sieht
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: const Text('Jetzt nachsehen'),
            ),
          ),
          if (Platform.isAndroid)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatisch melden'),
              subtitle: const Text('Etwa alle 30 Minuten im Hintergrund nachsehen'),
              value: k.automatisch,
              onChanged: (v) async {
                k.automatisch = v;
                await store.geaendert();
                await PostfachDienst.planen(store);
              },
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Papiertiger sieht nach, wenn du die App öffnest.', style: TextStyle(color: PT.grau, fontSize: 13)),
            ),
        ]),
      ),
      const Abschnitt('Neu'),
      if (neue.isEmpty)
        const LeerHinweis(
          icon: Icons.mark_email_read_outlined,
          text: 'Nichts Wichtiges. Rechnungen, Mahnungen, Behördenpost, Vertragsänderungen und Briefankündigungen erscheinen hier.',
        ),
      for (final h in neue) _HinweisKarte(h, onUebernehmen: _sieht ? null : () => _uebernehmen(h), onAusblenden: () => _ausblenden(h)),
      if (erledigt.isNotEmpty) ...[
        const Abschnitt('Erledigt'),
        for (final h in erledigt)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(mailSymbol(h.art), color: PT.grau),
            title: Text(h.betreff.isEmpty ? mailArten[h.art] ?? '' : h.betreff, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${h.absender} · ${h.status == 'uebernommen' ? 'übernommen' : 'ausgeblendet'}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      const SizedBox(height: 16),
      const Text(
        'Papiertiger liest nur. In deinem Postfach wird nichts gelöscht, verschoben, als gelesen markiert oder verschickt.',
        style: TextStyle(color: PT.grau, fontSize: 13),
      ),
      TextButton.icon(
        onPressed: _trennen,
        style: TextButton.styleFrom(foregroundColor: PT.rot),
        icon: const Icon(Icons.link_off),
        label: const Text('Verknüpfung trennen'),
      ),
    ]);
  }
}

class _HinweisKarte extends StatelessWidget {
  const _HinweisKarte(this.h, {required this.onUebernehmen, required this.onAusblenden});

  final MailHinweis h;
  final VoidCallback? onUebernehmen;
  final VoidCallback onAusblenden;

  @override
  Widget build(BuildContext context) {
    final dringend = h.art == 'mahnung';
    final post = h.art == 'briefankuendigung';
    return PTKarte(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconKachel(mailSymbol(h.art),
              farbe: dringend ? PT.rotHell : PT.orangeHell, iconFarbe: dringend ? PT.rot : PT.orangeDunkel),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post ? 'Die Post kündigt einen Brief an' : '${mailArten[h.art]} · ${h.absender}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (h.betreff.isNotEmpty)
                Text(h.betreff, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PT.grau, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (h.betrag != null) Etikett(euro(h.betrag!), farbe: PT.tinte, hintergrund: PT.sand),
                if (h.frist != null) Etikett('bis ${_datum(h.frist!)}', farbe: PT.gelb, hintergrund: PT.gelbHell),
                if (h.anhaenge > 0) Etikett('${h.anhaenge} PDF', farbe: PT.grau, hintergrund: PT.sand),
                if (h.datum != null) Etikett(_datum(h.datum!), farbe: PT.grau, hintergrund: PT.sand),
              ]),
            ]),
          ),
        ]),
        if (post)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Wenn der Brief im Kasten liegt: fotografieren, der Tiger erklärt ihn dir.',
                style: TextStyle(color: PT.grau, fontSize: 13)),
          ),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
          TextButton(onPressed: onAusblenden, child: Text(post ? 'Erledigt' : 'Ausblenden')),
          if (!post)
            FilledButton.tonalIcon(
              onPressed: onUebernehmen,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Als Brief übernehmen'),
            ),
        ]),
      ]),
    );
  }
}

class _Einrichten extends StatefulWidget {
  const _Einrichten();

  @override
  State<_Einrichten> createState() => _EinrichtenState();
}

class _EinrichtenState extends State<_Einrichten> {
  final _adresse = TextEditingController();
  final _passwort = TextEditingController();
  final _server = TextEditingController();
  final _port = TextEditingController(text: '993');
  final _benutzer = TextEditingController();
  bool _serverGeaendert = false;
  bool _laeuft = false;
  bool _zeigen = false;
  String? _fehler;

  MailServer get _anbieter => serverFuer(_adresse.text);

  @override
  void dispose() {
    for (final c in [_adresse, _passwort, _server, _port, _benutzer]) {
      c.dispose();
    }
    super.dispose();
  }

  void _adresseGeaendert(String _) {
    if (!_serverGeaendert) {
      _server.text = _anbieter.server;
      _port.text = '${_anbieter.port}';
    }
    setState(() => _fehler = null);
  }

  Future<void> _verknuepfen() async {
    final store = StoreScope.of(context);
    final adresse = _adresse.text.trim();
    if (!adresse.contains('@') || _passwort.text.isEmpty) {
      setState(() => _fehler = 'Bitte E-Mail-Adresse und Passwort eingeben.');
      return;
    }
    if (!_anbieter.moeglich && !_serverGeaendert) {
      setState(() => _fehler = outlookHinweis);
      return;
    }
    final k = PostfachKonto(
      adresse: adresse,
      benutzer: _benutzer.text.trim().isEmpty ? adresse : _benutzer.text.trim(),
      passwort: _passwort.text,
      server: _server.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 993,
    );
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    try {
      await postfachTesten(k);
      store.postfach = Postfach(konto: k);
      await store.geaendert();
      await store.protokollNotiz('E-Mail-Postfach verknüpft ($adresse)');
      await Benachrichtigungen.erlaubnisAnfragen();
      await PostfachDienst.planen(store);
      await PostfachDienst.jetzt(store);
    } catch (e) {
      if (mounted) setState(() => _fehler = '$e');
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _anbieter;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      const PTKarte(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Papiertiger meldet sich, wenn wichtige Post per E-Mail kommt',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          SizedBox(height: 6),
          Text('Rechnungen, Mahnungen, Behördenpost, Vertragsänderungen und die Briefankündigung der Deutschen Post. '
              'Mit einem Tipp übernimmst du die E-Mail samt PDF als Brief.'),
          SizedBox(height: 8),
          Text('Papiertiger liest nur: nichts wird gelöscht, verschoben, als gelesen markiert oder verschickt. '
              'Dein Passwort bleibt verschlüsselt auf diesem Handy.',
              style: TextStyle(color: PT.grau, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _adresse,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'E-Mail-Adresse', prefixIcon: Icon(Icons.alternate_email)),
        onChanged: _adresseGeaendert,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _passwort,
        obscureText: !_zeigen,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: 'Passwort',
          prefixIcon: const Icon(Icons.key_outlined),
          suffixIcon: IconButton(
            tooltip: _zeigen ? 'Verbergen' : 'Anzeigen',
            icon: Icon(_zeigen ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _zeigen = !_zeigen),
          ),
        ),
      ),
      if (_adresse.text.contains('@')) ...[
        const SizedBox(height: 12),
        if (!a.moeglich)
          const Text(outlookHinweis, style: TextStyle(color: PT.rot))
        else if (a.hinweis.isNotEmpty)
          Text('${a.name.isEmpty ? '' : '${a.name}: '}${a.hinweis}', style: const TextStyle(color: PT.grau, fontSize: 13)),
      ],
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Server selbst eintragen', style: TextStyle(fontSize: 14)),
        children: [
          TextField(
            controller: _server,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'IMAP-Server'),
            onChanged: (_) => _serverGeaendert = true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Port (SSL/TLS)'),
            onChanged: (_) => _serverGeaendert = true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _benutzer,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Benutzername (leer = E-Mail-Adresse)'),
          ),
          const SizedBox(height: 8),
        ],
      ),
      if (_fehler != null) ...[
        const SizedBox(height: 8),
        Text(_fehler!, style: const TextStyle(color: PT.rot, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _laeuft ? null : _verknuepfen,
        icon: _laeuft
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.link),
        label: Text(_laeuft ? 'Verbinde …' : 'Verknüpfen'),
      ),
    ]);
  }
}
