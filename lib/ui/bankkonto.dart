import 'dart:convert';

import 'package:fints/fints.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../logic/bankzugang.dart';
import 'app.dart';
import 'kontoauszug.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Gespeicherte Bankverbindung (ohne PIN) und abgerufene Umsätze stehen verschlüsselt in den Notizen.
const bankZugangSchluessel = 'bank:zugang';
const bankUmsaetzeSchluessel = 'bank:umsaetze';
const bankStandSchluessel = 'bank:stand';

/// Online-Banking verbinden (nur lesen).
class BankkontoScreen extends StatefulWidget {
  const BankkontoScreen({super.key});

  @override
  State<BankkontoScreen> createState() => _BankkontoScreenState();
}

class _BankkontoScreenState extends State<BankkontoScreen> {
  var _vorlage = bankVorlagen.first;
  final _iban = TextEditingController();
  final _url = TextEditingController();
  final _benutzer = TextEditingController();
  final _pin = TextEditingController();
  bool _laeuft = false;
  String? _fehler;
  String? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roh = StoreScope.of(context).notizen[bankZugangSchluessel];
      if (roh == null) return;
      try {
        final j = jsonDecode(roh) as Map<String, dynamic>;
        setState(() {
          _vorlage = bankVorlagen.firstWhere((v) => v.name == j['bank'], orElse: () => bankVorlagen.last);
          _iban.text = j['iban'] as String? ?? '';
          _url.text = j['url'] as String? ?? '';
          _benutzer.text = j['benutzer'] as String? ?? '';
          _state = j['state'] as String?;
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    for (final c in [_iban, _url, _benutzer, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<TanMethod?> _wahl(List<TanMethod> m) async {
    if (m.length == 1) return m.first;
    // App-Freigabe (pushTAN, SecureGo …) bevorzugen
    final app = m.where((x) => RegExp(r'push|app|secure|decoupled', caseSensitive: false).hasMatch('${x.name} ${x.dkMethod ?? ''}'));
    if (app.length == 1) return app.first;
    if (!mounted) return null;
    return showDialog<TanMethod>(
      context: context,
      builder: (d) => SimpleDialog(
        title: const Text('Wie gibst du frei?'),
        children: [for (final x in m) SimpleDialogOption(onPressed: () => Navigator.pop(d, x), child: Text(x.name))],
      ),
    );
  }

  Future<TanAnswer> _tan(TanChallenge c) async {
    if (!mounted) return TanAnswer.cancelled;
    final text = c.plainMessage ?? 'Bitte gib den Zugriff frei.';
    if (c.isDecoupled) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (d) => AlertDialog(
          title: const Text('In deiner Banking-App freigeben'),
          content: Text('$text\n\nÖffne deine Banking-App (z. B. S-pushTAN) und gib den Abruf frei. '
              'Es wird nur gelesen – keine Überweisung.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Ich habe freigegeben')),
          ],
        ),
      );
      return ok == true ? TanAnswer.approved : TanAnswer.cancelled;
    }
    final eingabe = TextEditingController();
    final tan = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: const Text('TAN eingeben'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text),
          if (c.image != null) ...[
            const SizedBox(height: 8),
            Image.memory(c.image!.bytes, height: 180),
          ],
          TextField(controller: eingabe, autofocus: true, decoration: const InputDecoration(labelText: 'TAN')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(d, eingabe.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    eingabe.dispose();
    return tan == null || tan.isEmpty ? TanAnswer.cancelled : TanAnswer.tan(tan);
  }

  Future<void> _abrufen() async {
    final store = StoreScope.of(context);
    final blz = blzAusIban(_iban.text);
    final url = _vorlage.url.isNotEmpty ? _vorlage.url : _url.text.trim();
    if (blz == null) return setState(() => _fehler = 'Bitte deine IBAN eingeben (DE…, 22 Stellen).');
    if (!url.startsWith('https://')) return setState(() => _fehler = 'Bitte die FinTS-Adresse deiner Bank eintragen (beginnt mit https://).');
    if (_benutzer.text.trim().isEmpty || _pin.text.isEmpty) {
      return setState(() => _fehler = 'Bitte Anmeldename und PIN deines Online-Bankings eingeben.');
    }
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    try {
      final r = await bankAbrufen(
        url: url,
        blz: blz,
        benutzer: _benutzer.text,
        pin: _pin.text,
        tan: _tan,
        wahl: _wahl,
        state: _state,
        iban: _iban.text,
      );
      _pin.clear();
      _state = r.state;
      store.notizen[bankZugangSchluessel] = jsonEncode({
        'bank': _vorlage.name,
        'iban': _iban.text.replaceAll(' ', '').toUpperCase(),
        'url': url,
        'benutzer': _benutzer.text.trim(),
        'state': r.state,
      });
      store.notizen[bankUmsaetzeSchluessel] = umsaetzeAlsText(r.umsaetze);
      store.notizen[bankStandSchluessel] = jsonEncode({
        'zeit': DateTime.now().toIso8601String(),
        'stand': r.kontostand,
        'anzahl': r.umsaetze.length,
      });
      await store.geaendert();
      await store.protokollNotiz('Umsätze vom Bankkonto abgerufen (nur lesen)');
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const KontoauszugScreen()));
    } catch (e) {
      if (mounted) setState(() => _fehler = bankFehlerText(e));
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  Future<void> _trennen() async {
    final store = StoreScope.of(context);
    store.notizen
      ..remove(bankZugangSchluessel)
      ..remove(bankUmsaetzeSchluessel)
      ..remove(bankStandSchluessel);
    await store.geaendert();
    await store.protokollNotiz('Bankverbindung getrennt');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final verbunden = store.notizen.containsKey(bankZugangSchluessel);
    Map<String, dynamic>? stand;
    try {
      stand = jsonDecode(store.notizen[bankStandSchluessel] ?? 'null') as Map<String, dynamic>?;
    } catch (_) {}
    return Scaffold(
      appBar: AppBar(title: const Text('Bankkonto verbinden')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        const PTKarte(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Abos und Verträge automatisch finden', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            SizedBox(height: 6),
            Text('Der Tiger holt die Umsätze der letzten 12 Monate und erkennt regelmäßige Abbuchungen, '
                'Preiserhöhungen und doppelte Lastschriften.'),
            SizedBox(height: 8),
            Text('Nur lesen: Überweisen kann der Tiger nicht. Die Verbindung geht direkt vom Handy zu deiner Bank, '
                'deine PIN wird nicht gespeichert.',
                style: TextStyle(color: PT.grau, fontSize: 13)),
          ]),
        ),
        if (kIsWeb)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Die Bankverbindung gibt es nur in der Handy-App.'),
          )
        else if (!bankzugangFreigeschaltet) ...[
          const PTKarte(
            farbe: PT.gelbHell,
            child: Text('Die Bankverbindung wird freigeschaltet, sobald die Registrierung bei der Deutschen Kreditwirtschaft '
                'abgeschlossen ist. Bis dahin: Kontoauszug als PDF aus der Banking-App teilen und unter „Kontoauszug prüfen“ auswerten.'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KontoauszugScreen())),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Kontoauszug prüfen'),
          ),
        ] else ...[
          if (verbunden && stand != null)
            PTKarte(
              farbe: PT.gruenHell,
              child: Text(
                  'Verbunden · zuletzt abgerufen: ${datumKurz(DateTime.tryParse(stand['zeit'] as String? ?? '') ?? DateTime.now())}'
                  '${stand['stand'] == null ? '' : ' · Kontostand ${euro((stand['stand'] as num).toDouble())}'}'),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<BankVorlage>(
            value: _vorlage,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Bank'),
            items: [for (final v in bankVorlagen) DropdownMenuItem(value: v, child: Text(v.name))],
            onChanged: (v) => setState(() => _vorlage = v ?? _vorlage),
          ),
          if (_vorlage.hinweis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_vorlage.hinweis, style: const TextStyle(color: PT.grau, fontSize: 13)),
            ),
          if (_vorlage.url.isEmpty) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'FinTS-Adresse (https://…)'),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _iban,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Deine IBAN', hintText: 'DE12 3456 …'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _benutzer,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Anmeldename / Legitimations-ID des Online-Bankings'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Online-Banking-PIN (wird nicht gespeichert)'),
          ),
          if (_fehler != null) ...[
            const SizedBox(height: 10),
            Text(_fehler!, style: const TextStyle(color: PT.rot, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _laeuft ? null : _abrufen,
            icon: _laeuft
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.account_balance_outlined),
            label: Text(_laeuft ? 'Verbinde mit der Bank …' : (verbunden ? 'Umsätze neu abrufen' : 'Verbinden und Umsätze holen')),
          ),
          if (verbunden)
            TextButton.icon(
              onPressed: _trennen,
              style: TextButton.styleFrom(foregroundColor: PT.rot),
              icon: const Icon(Icons.link_off),
              label: const Text('Verbindung trennen und Umsätze löschen'),
            ),
        ],
      ]),
    );
  }
}
