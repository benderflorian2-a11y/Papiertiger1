import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/android_kanal.dart';
import '../logic/export.dart';
import '../logic/protokoll.dart';
import '../logic/tresor.dart';
import 'app.dart';
import 'sicherung.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

// Einstellungen liegen in checklisten/notizen (werden verschlüsselt gespeichert).
bool sperreAn(AppStore s) => s.checklisten['sicher:sperre'] == true && (s.notizen['sicher:pin'] ?? '').isNotEmpty;
bool bildschirmschutzAn(AppStore s) => s.checklisten['sicher:bildschirm'] == true;
int sperrMinuten(AppStore s) => int.tryParse(s.notizen['sicher:minuten'] ?? '') ?? 1;

/// Legt sich über die ganze App, solange sie gesperrt ist.
class AppSperre extends StatefulWidget {
  const AppSperre({super.key, required this.store, required this.child});

  final AppStore store;
  final Widget child;

  @override
  State<AppSperre> createState() => _AppSperreState();
}

class _AppSperreState extends State<AppSperre> with WidgetsBindingObserver {
  late bool _gesperrt = sperreAn(widget.store);
  DateTime? _weg;

  /// Während die Displaysperre des Handys abgefragt wird, nicht neu sperren.
  bool _systemDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    bildschirmschutz(bildschirmschutzAn(widget.store));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _weg ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final weg = _weg;
      _weg = null;
      if (_systemDialog || weg == null || !sperreAn(widget.store)) return;
      final grenze = Duration(minutes: sperrMinuten(widget.store));
      // „Sofort“ heißt: nach 5 Sekunden, damit kurzes Teilen oder Fotografieren nicht stört
      final dauer = DateTime.now().difference(weg);
      if (dauer >= (grenze == Duration.zero ? const Duration(seconds: 5) : grenze)) setState(() => _gesperrt = true);
    }
  }

  Future<void> _mitGeraet() async {
    _systemDialog = true;
    final ok = await geraetEntsperren();
    _systemDialog = false;
    if (ok && mounted) _entsperrt();
  }

  void _entsperrt() {
    widget.store.notizen.remove('sicher:fehl');
    widget.store.geaendert();
    setState(() => _gesperrt = false);
  }

  @override
  Widget build(BuildContext context) {
    final aktiv = _gesperrt && sperreAn(widget.store);
    return Stack(children: [
      // Inhalt bleibt im Speicher, ist aber nicht sichtbar und nicht bedienbar
      Offstage(offstage: aktiv, child: TickerMode(enabled: !aktiv, child: widget.child)),
      if (aktiv)
        Positioned.fill(
          child: _SperrBildschirm(store: widget.store, entsperrt: _entsperrt, mitGeraet: _mitGeraet),
        ),
    ]);
  }
}

class _SperrBildschirm extends StatefulWidget {
  const _SperrBildschirm({required this.store, required this.entsperrt, required this.mitGeraet});

  final AppStore store;
  final VoidCallback entsperrt;
  final Future<void> Function() mitGeraet;

  @override
  State<_SperrBildschirm> createState() => _SperrBildschirmState();
}

class _SperrBildschirmState extends State<_SperrBildschirm> {
  bool _geraet = false;
  String? _fehler;
  bool _prueft = false;
  DateTime? _bis;

  @override
  void initState() {
    super.initState();
    geraetGesichert().then((g) {
      if (mounted) setState(() => _geraet = g);
    });
  }

  int get _fehlversuche => int.tryParse(widget.store.notizen['sicher:fehl'] ?? '') ?? 0;

  Future<void> _pruefen(String pin) async {
    final warte = _bis;
    if (warte != null && DateTime.now().isBefore(warte)) return;
    setState(() => _prueft = true);
    final ok = await pinPruefen(pin, widget.store.notizen['sicher:pin'] ?? '');
    if (!mounted) return;
    if (ok) {
      widget.entsperrt();
      return;
    }
    final n = _fehlversuche + 1;
    widget.store.notizen['sicher:fehl'] = '$n';
    await widget.store.geaendert();
    final w = pinWartezeit(n);
    setState(() {
      _prueft = false;
      _bis = w == Duration.zero ? null : DateTime.now().add(w);
      _fehler = w == Duration.zero
          ? 'Falsche PIN ($n. Versuch)'
          : 'Falsche PIN. Bitte ${w.inSeconds >= 60 ? '${w.inMinutes} Minuten' : '${w.inSeconds} Sekunden'} warten.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PT.sand,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Tiger(size: 72),
              const SizedBox(height: 12),
              const Text('Papiertiger ist gesperrt', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              PinTastatur(
                key: ValueKey(_fehler),
                aktiv: !_prueft,
                fehler: _fehler,
                fertig: _pruefen,
              ),
              if (_geraet) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: widget.mitGeraet,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Mit Fingerabdruck oder Handy-PIN'),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Ziffernfeld ohne Systemtastatur. Ruft [fertig] mit „OK“ auf.
class PinTastatur extends StatefulWidget {
  const PinTastatur({super.key, required this.fertig, this.aktiv = true, this.fehler, this.hinweis = 'PIN eingeben'});

  final void Function(String pin) fertig;
  final bool aktiv;
  final String? fehler;
  final String hinweis;

  @override
  State<PinTastatur> createState() => _PinTastaturState();
}

class _PinTastaturState extends State<PinTastatur> {
  String _pin = '';

  Widget _taste(String t, {VoidCallback? tap, IconData? icon}) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 72,
          height: 60,
          child: FilledButton.tonal(
            onPressed: widget.aktiv ? (tap ?? () => setState(() => _pin.length < 12 ? _pin += t : null)) : null,
            child: icon != null ? Icon(icon) : Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.fehler ?? widget.hinweis,
          style: TextStyle(color: widget.fehler != null ? PT.rot : PT.grau, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Text(_pin.isEmpty ? ' ' : '●' * _pin.length, style: const TextStyle(fontSize: 26, letterSpacing: 6)),
      const SizedBox(height: 10),
      for (final reihe in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ])
        Row(mainAxisSize: MainAxisSize.min, children: [for (final t in reihe) _taste(t)]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _taste('', icon: Icons.backspace_outlined, tap: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1))),
        _taste('0'),
        _taste('', icon: Icons.check, tap: _pin.length >= 6 ? () => widget.fertig(_pin) : () {}),
      ]),
    ]);
  }
}

/// Neue PIN zweimal eingeben. Liefert die PIN oder null.
class PinFestlegen extends StatefulWidget {
  const PinFestlegen({super.key});

  @override
  State<PinFestlegen> createState() => _PinFestlegenState();
}

class _PinFestlegenState extends State<PinFestlegen> {
  String? _erste;
  String? _fehler;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN festlegen')),
      body: Center(
        child: SingleChildScrollView(
          child: PinTastatur(
            key: ValueKey('$_erste$_fehler'),
            hinweis: _erste == null ? 'Neue PIN (6 bis 12 Ziffern)' : 'PIN wiederholen',
            fehler: _fehler,
            fertig: (pin) {
              if (_erste == null) {
                final schwach = pinSchwach(pin);
                setState(() {
                  if (schwach == null) {
                    _erste = pin;
                    _fehler = null;
                  } else {
                    _fehler = schwach;
                  }
                });
              } else if (pin == _erste) {
                Navigator.pop(context, pin);
              } else {
                setState(() {
                  _erste = null;
                  _fehler = 'Die PINs waren verschieden. Bitte noch einmal.';
                });
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Mehr → Sicherheit: Überblick und Einstellungen.
class SicherheitScreen extends StatelessWidget {
  const SicherheitScreen({super.key});

  Future<void> _sperreUmschalten(BuildContext context, AppStore store, bool an) async {
    if (an) {
      final pin = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const PinFestlegen()));
      if (pin == null) return;
      store.notizen['sicher:pin'] = await pinSpeicherform(pin);
      store.checklisten['sicher:sperre'] = true;
      await store.protokollNotiz('App-Sperre eingeschaltet');
    } else {
      store.checklisten['sicher:sperre'] = false;
      store.notizen.remove('sicher:pin');
      await store.protokollNotiz('App-Sperre ausgeschaltet');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sperre = sperreAn(store);
    final bruch = protokollBruch(store.protokoll);
    Widget status(bool ok, String titel, String text) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? PT.gruen : PT.orangeDunkel),
          title: Text(titel, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(text),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Sicherheit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Abschnitt('So sind deine Daten geschützt'),
          status(true, 'Nur auf diesem Handy', 'Kein Konto, kein Server. Briefe, Rechnungen und Fotos werden nirgends hochgeladen.'),
          status(store.verschluesselt, 'Daten verschlüsselt',
              store.verschluesselt
                  ? 'Angaben, Briefe, Rechnungen und Notizen sind mit AES-256 verschlüsselt. Der Schlüssel liegt im Sicherheitschip des Handys.'
                  : 'Verschlüsselung ist nicht aktiv${store.schluesselFehler ? ' – der Sicherheitschip hat nicht geantwortet' : ''}.'),
          status(true, 'Keine Google-Cloud-Sicherung',
              'Die App-Daten gehen nicht automatisch in die Cloud oder auf ein neues Handy. Sichern nur über deine eigene, verschlüsselte Datensicherung.'),
          status(sperre, 'App-Sperre', sperre ? 'PIN beim Öffnen' : 'Aus – wer dein entsperrtes Handy hat, kann alles sehen.'),
          status(bruch == null, 'Änderungsprotokoll',
              bruch == null
                  ? '${store.protokoll.length} Einträge, lückenlos'
                  : 'Eintrag ${bruch + 1} passt nicht zur Kette – das Protokoll wurde verändert.'),
          const Text(
              'Fotos und PDF-Dateien liegen im geschützten App-Ordner und sind durch die Verschlüsselung des Handys geschützt, '
              'solange es gesperrt ist.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
          const Abschnitt('Einstellungen'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('App-Sperre mit PIN'),
            subtitle: const Text('Zusätzlich geht Entsperren mit Fingerabdruck oder Handy-PIN.'),
            value: sperre,
            onChanged: (v) => _sperreUmschalten(context, store, v),
          ),
          if (sperre) ...[
            const Text('Sperren, wenn die App so lange im Hintergrund war:'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final (m, t) in const [(0, 'sofort'), (1, '1 Minute'), (5, '5 Minuten'), (15, '15 Minuten')])
                ChoiceChip(
                  label: Text(t),
                  selected: sperrMinuten(store) == m,
                  onSelected: (_) {
                    store.notizen['sicher:minuten'] = '$m';
                    store.geaendert();
                  },
                ),
            ]),
            TextButton.icon(
              onPressed: () async {
                final pin = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const PinFestlegen()));
                if (pin == null) return;
                store.notizen['sicher:pin'] = await pinSpeicherform(pin);
                await store.protokollNotiz('PIN geändert');
                if (context.mounted) zeigeHinweis(context, 'Neue PIN gespeichert');
              },
              icon: const Icon(Icons.password),
              label: const Text('PIN ändern'),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bildschirmschutz'),
            subtitle: const Text('Keine Bildschirmfotos, keine Vorschau im App-Wechsler.'),
            value: bildschirmschutzAn(store),
            onChanged: (v) async {
              store.checklisten['sicher:bildschirm'] = v;
              await bildschirmschutz(v);
              await store.protokollNotiz(v ? 'Bildschirmschutz eingeschaltet' : 'Bildschirmschutz ausgeschaltet');
            },
          ),
          const Abschnitt('Änderungsprotokoll'),
          const Text(
              'Jede neue, geänderte, verschickte, bezahlte oder stornierte Rechnung wird mit Zeit vermerkt. '
              'Verschickte Rechnungen sind festgeschrieben: ändern geht nur über Storno und neue Rechnung.',
              style: TextStyle(fontSize: 13)),
          for (final e in store.protokoll.reversed.take(30))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e.art == 'warnung' ? Icons.warning_amber : (e.art == 'sicherheit' ? Icons.shield_outlined : Icons.receipt_long_outlined),
                color: e.art == 'warnung' ? PT.rot : PT.grau,
              ),
              title: Text('${e.objekt}: ${e.text}'),
              subtitle: Text('${datumKurz(e.zeit)} ${e.zeit.hour.toString().padLeft(2, '0')}:${e.zeit.minute.toString().padLeft(2, '0')}'),
            ),
          if (store.protokoll.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () async {
                final d = await textDatei('Änderungsprotokoll.csv', protokollCsv(store.protokoll));
                await dateiTeilen(d.path, mimeType: 'text/csv', text: 'Änderungsprotokoll Papiertiger');
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Ganzes Protokoll als CSV teilen'),
            ),
        ],
      ),
    );
  }
}

/// Wird angezeigt, wenn die gespeicherten Daten nicht entschlüsselt werden konnten.
class DatenGesperrt extends StatelessWidget {
  const DatenGesperrt({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Tiger(size: 72),
              const SizedBox(height: 16),
              const Text('Deine Daten lassen sich gerade nicht öffnen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text(
                'Der Schlüssel im Sicherheitschip des Handys hat nicht geantwortet. Es wurde nichts gelöscht oder überschrieben. '
                'Starte das Handy neu und öffne die App noch einmal. Hilft das nicht, kannst du eine Datensicherung einspielen.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SicherungScreen())),
                icon: const Icon(Icons.restore),
                label: const Text('Datensicherung einspielen'),
              ),
            ]),
          ),
        ),
      );
}
