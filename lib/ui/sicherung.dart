import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../logic/export.dart';
import '../logic/sicherung.dart';
import 'app.dart';
import 'theme.dart';
import 'widgets/common.dart';

// Läuft in einem eigenen Isolate (keine Ruckler bei vielen Fotos). Nur einfache Werte übergeben.
Future<Uint8List> _erstellenIsoliert((Map<String, Object?>, String, String) a) async {
  final (werte, basis, pw) = a;
  final dateien = await dateienSammeln(Directory(basis));
  return verschluesseln(sicherungPacken(werte, basis, dateien), pw);
}

Future<SicherungsInhalt> _oeffnenIsoliert((Uint8List, String) a) async => sicherungEntpacken(await entschluesseln(a.$1, a.$2));

/// Wann zuletzt gesichert wurde (null = nie).
DateTime? letzteSicherung(Map<String, String> notizen) => DateTime.tryParse(notizen['sicherung:zuletzt'] ?? '');

class SicherungScreen extends StatefulWidget {
  const SicherungScreen({super.key});

  @override
  State<SicherungScreen> createState() => _SicherungScreenState();
}

class _SicherungScreenState extends State<SicherungScreen> {
  String? _laeuft;

  Future<String?> _passwort({required bool neu}) async {
    final a = TextEditingController(), b = TextEditingController();
    String? fehler;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setze) => AlertDialog(
          title: Text(neu ? 'Passwort für die Sicherung' : 'Passwort der Sicherung'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: a, obscureText: true, autofocus: true, decoration: feld(labelText: 'Passwort')),
            if (neu) ...[
              const SizedBox(height: 8),
              TextField(controller: b, obscureText: true, decoration: feld(labelText: 'Passwort wiederholen')),
              const SizedBox(height: 8),
              const Text('Schreib es dir auf! Ohne Passwort kann niemand die Sicherung öffnen – auch der Tiger nicht.',
                  style: TextStyle(color: PT.rot, fontSize: 12)),
            ],
            if (fehler != null) Text(fehler!, style: const TextStyle(color: PT.rot)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            TextButton(
              onPressed: () {
                if (a.text.length < 8) return setze(() => fehler = 'Mindestens 8 Zeichen.');
                if (neu && a.text != b.text) return setze(() => fehler = 'Die Passwörter sind verschieden.');
                Navigator.pop(d, true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    final p = a.text;
    a.dispose();
    b.dispose();
    return ok == true ? p : null;
  }

  Future<void> _erstellen() async {
    final store = StoreScope.of(context);
    final pw = await _passwort(neu: true);
    if (pw == null) return;
    setState(() => _laeuft = 'Sicherung wird erstellt …');
    try {
      final werte = store.alleWerte();
      final basis = (await getApplicationDocumentsDirectory()).path;
      final daten = await compute(_erstellenIsoliert, (werte, basis, pw));
      final heute = DateTime.now();
      final ordner = await getTemporaryDirectory();
      final datei = File('${ordner.path}/Papiertiger-Sicherung-${heute.year}-${heute.month.toString().padLeft(2, '0')}-'
          '${heute.day.toString().padLeft(2, '0')}.ptsich');
      await datei.writeAsBytes(daten);
      store.notizen['sicherung:zuletzt'] = heute.toIso8601String();
      await store.geaendert();
      if (!mounted) return;
      setState(() => _laeuft = null);
      await dateiTeilen(datei.path,
          mimeType: 'application/octet-stream',
          text: 'Papiertiger-Sicherung – z. B. in Google Drive oder „Eigene Dateien“ speichern.');
    } catch (e) {
      if (mounted) {
        setState(() => _laeuft = null);
        zeigeHinweis(context, 'Sicherung fehlgeschlagen: $e');
      }
    }
  }

  Future<void> _zurueckspielen() async {
    final store = StoreScope.of(context);
    final f = await openFile();
    if (f == null) return;
    final pw = await _passwort(neu: false);
    if (pw == null || !mounted) return;
    setState(() => _laeuft = 'Sicherung wird geöffnet …');
    try {
      final roh = await f.readAsBytes();
      final inhalt = await compute(_oeffnenIsoliert, (roh, pw));
      if (!mounted) return;
      setState(() => _laeuft = null);
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Sicherung zurückspielen?'),
          content: Text('Sicherung vom ${inhalt.erstellt == null ? '?' : datumKurz(inhalt.erstellt!)} mit '
              '${inhalt.dateien.length} Dateien.\n\nAlles, was jetzt in der App ist, wird dadurch ersetzt.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ersetzen')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => _laeuft = 'Daten werden zurückgespielt …');
      final basis = (await getApplicationDocumentsDirectory()).path;
      for (final (rel, bytes) in inhalt.dateien) {
        final ziel = File('$basis/$rel');
        await ziel.parent.create(recursive: true);
        await ziel.writeAsBytes(bytes);
      }
      await store.werteErsetzen(pfadeAnpassen(inhalt.prefs, inhalt.basis, basis));
      if (!mounted) return;
      setState(() => _laeuft = null);
      zeigeHinweis(context, 'Fertig – deine Daten sind wieder da.');
    } on SicherungsFehler catch (e) {
      if (mounted) {
        setState(() => _laeuft = null);
        zeigeHinweis(context, e.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _laeuft = null);
        zeigeHinweis(context, 'Zurückspielen fehlgeschlagen: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final zuletzt = letzteSicherung(store.notizen);
    return Scaffold(
      appBar: AppBar(title: const Text('Datensicherung')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PTKarte(
          farbe: zuletzt == null || DateTime.now().difference(zuletzt).inDays > 30 ? PT.gelbHell : PT.gruenHell,
          child: Text(
            zuletzt == null ? 'Noch nie gesichert.' : 'Zuletzt gesichert am ${datumKurz(zuletzt)}.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const Text(
          'Deine Daten liegen nur auf diesem Handy. Geht es verloren, ist alles weg – außer du hast eine Sicherung. '
          'Die Sicherung enthält alle Briefe, Fotos, Verträge, Rechnungen und Einstellungen, verschlüsselt mit deinem Passwort. '
          'Speichere sie z. B. in Google Drive oder auf dem PC.',
        ),
        const SizedBox(height: 16),
        if (_laeuft != null)
          Row(children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 12),
            Expanded(child: Text(_laeuft!)),
          ])
        else ...[
          FilledButton.icon(
            onPressed: _erstellen,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Sicherung erstellen'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _zurueckspielen,
            icon: const Icon(Icons.restore),
            label: const Text('Sicherung zurückspielen (neues Handy)'),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Das KI-Modell wird nicht mitgesichert – es lässt sich jederzeit neu laden.',
            style: TextStyle(color: PT.grau, fontSize: 12)),
      ]),
    );
  }
}
