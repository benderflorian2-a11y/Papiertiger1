import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../data/alltag.dart';
import '../../logic/alltag.dart';
import '../../logic/export.dart';
import '../../logic/ki.dart';
import '../../logic/texterkennung.dart';
import '../../logic/video_link.dart';
import '../app.dart';
import '../ki_einrichten.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tiger.dart';

/// Rezeptsammlung: Screenshot (TikTok, YouTube, Instagram …) rein, Rezept wird gespeichert,
/// Zutaten kommen auf die Einkaufsliste.
class RezepteScreen extends StatelessWidget {
  const RezepteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final liste = store.alltag.rezepte;
    return Scaffold(
      appBar: AppBar(title: const Text('Rezepte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          FilledButton.icon(
            onPressed: () => _ausScreenshot(context),
            icon: const Icon(Icons.screenshot_outlined),
            label: const Text('Screenshot einlesen'),
          ),
          TextButton.icon(
            onPressed: () => _ausText(context),
            icon: const Icon(Icons.content_paste),
            label: const Text('Rezepttext einfügen'),
          ),
          const SizedBox(height: 8),
          if (liste.isEmpty)
            const LeerHinweis(
                icon: Icons.menu_book_outlined,
                text: 'Noch kein Rezept. Mach in TikTok, YouTube oder Instagram einen Screenshot und lies ihn hier ein.'),
          for (final r in liste.reversed)
            PTKarte(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([
                  '${r.zutaten.length} Zutaten',
                  if (r.zeit.isNotEmpty) '${r.zeit} Min.',
                  if (r.quelle.isNotEmpty) r.quelle,
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RezeptDetailScreen(rezept: r))),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool> _kiBereit(BuildContext context) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Das Einlesen klappt nur in der Handy-App.')));
    return false;
  }
  if (await Ki.istInstalliert()) return true;
  if (!context.mounted) return false;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const KiEinrichtenScreen()));
  return ok == true;
}

Future<void> _ausScreenshot(BuildContext context) async {
  if (!await _kiBereit(context) || !context.mounted) return;
  final pfad = await Texterkennung.bildHolen(kamera: false);
  if (pfad == null || !context.mounted) return;
  await _verarbeiten(context, () async {
    var text = await Texterkennung.textErkennen([pfad]);
    // Wenig Text erkannt (z. B. Rezept nur im Video eingeblendet): die KI schaut selbst aufs Bild
    if (text.trim().length < 40) text = await Ki.bildLesen([pfad]);
    return text;
  }, quelle: 'Screenshot');
}

/// Geteilter Link aus TikTok, YouTube oder Instagram: Beschreibung holen und zum Rezept machen.
Future<void> rezeptAusLink(BuildContext context, String link) async {
  if (!await _kiBereit(context) || !context.mounted) return;
  await _verarbeiten(context, () async {
    final text = await videoText(link);
    if (text.trim().length < 40) {
      throw 'Zu dem Link habe ich keine Beschreibung gefunden. Oft steht das Rezept nur im Video. '
          'Mach dann einen Screenshot und lies ihn bei „Rezepte“ ein.';
    }
    return text;
  }, quelle: 'Link');
}

Future<void> _ausText(BuildContext context) async {
  if (!await _kiBereit(context) || !context.mounted) return;
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Rezepttext einfügen'),
      content: TextField(
          controller: c,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          decoration: feld(hintText: 'Text aus der Videobeschreibung oder Beschreibung einfügen')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Weiter')),
      ],
    ),
  );
  final t = c.text.trim();
  c.dispose();
  if (ok != true || t.isEmpty || !context.mounted) return;
  await _verarbeiten(context, () async => t, quelle: 'Text eingefügt');
}

/// Text holen, von der KI in ein Rezept umwandeln lassen, dann zur Kontrolle zeigen.
Future<void> _verarbeiten(BuildContext context, Future<String> Function() textHolen, {required String quelle}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          Tiger(size: 40),
          SizedBox(width: 12),
          Expanded(child: Text('Der Tiger liest das Rezept … Das kann bis zu 2 Minuten dauern.')),
        ]),
      ),
    ),
  );
  Rezept? rezept;
  String? fehler;
  try {
    final text = await textHolen();
    final antwort = StringBuffer();
    await for (final s in Ki.text(rezeptAusTextAnfrage(text), maxAusgabe: 1200, temperatur: 0.1)) {
      antwort.write(s);
    }
    rezept = rezeptLesen(antwort.toString(), quelle: quelle);
  } catch (e) {
    fehler = '$e';
  }
  nav.pop();
  if (!context.mounted) return;
  final f = fehler;
  if (rezept == null) {
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(f == null || f.startsWith('Zu dem Link') ? 'Kein Rezept erkannt' : 'Das hat nicht geklappt'),
        content: Text(f != null && f.startsWith('Zu dem Link')
            ? f
            : f ??
                'Ich habe kein Rezept mit Zutaten gefunden. Oft steht es in der Videobeschreibung: '
                    'Kopiere sie und füge sie als Text ein.'),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
      ),
    );
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RezeptPruefenScreen(rezept: rezept!)));
}

/// Kontrolle vor dem Speichern: Name ändern, Zutaten abhaken.
class RezeptPruefenScreen extends StatefulWidget {
  const RezeptPruefenScreen({super.key, required this.rezept});
  final Rezept rezept;

  @override
  State<RezeptPruefenScreen> createState() => _RezeptPruefenState();
}

class _RezeptPruefenState extends State<RezeptPruefenScreen> {
  late final _name = TextEditingController(text: widget.rezept.name);
  late final Set<int> _gewaehlt = {
    for (var i = 0; i < widget.rezept.zutaten.length; i++)
      if (!istGrundzutat(widget.rezept.zutaten[i])) i
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _speichern({required bool einkauf}) async {
    final store = StoreScope.of(context);
    final r = widget.rezept..name = _name.text.trim().isEmpty ? widget.rezept.name : _name.text.trim();
    store.alltag.rezepte.add(r);
    var neu = 0;
    if (einkauf) {
      neu = zutatenAufEinkaufsliste([for (final i in _gewaehlt.toList()..sort()) r.zutaten[i]], store.alltag.einkauf).length;
    }
    await store.geaendert();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(einkauf ? 'Rezept gespeichert, $neu Zutaten auf der Einkaufsliste.' : 'Rezept gespeichert.')));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rezept;
    return Scaffold(
      appBar: AppBar(title: const Text('Rezept prüfen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: feld(labelText: 'Name')),
          const SizedBox(height: 12),
          const Text('Welche Zutaten sollen auf die Einkaufsliste?', style: TextStyle(fontWeight: FontWeight.w700)),
          const Text('Salz, Pfeffer, Wasser und Öl sind vorab abgewählt.', style: TextStyle(color: PT.grau, fontSize: 12)),
          for (var i = 0; i < r.zutaten.length; i++)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _gewaehlt.contains(i),
              title: Text(r.zutaten[i]),
              onChanged: (v) => setState(() => v == true ? _gewaehlt.add(i) : _gewaehlt.remove(i)),
            ),
          if (r.zubereitung.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Zubereitung', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(r.zubereitung, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 8),
          const Text('Von der KI gelesen – bitte kurz mit dem Original vergleichen.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _speichern(einkauf: true),
            child: Text('Speichern + ${_gewaehlt.length} Zutaten auf die Einkaufsliste'),
          ),
          TextButton(onPressed: () => _speichern(einkauf: false), child: const Text('Nur Rezept speichern')),
        ],
      ),
    );
  }
}

class RezeptDetailScreen extends StatelessWidget {
  const RezeptDetailScreen({super.key, required this.rezept});
  final Rezept rezept;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = rezept;
    return Scaffold(
      appBar: AppBar(title: Text(r.name), actions: [
        IconButton(tooltip: 'Teilen', icon: const Icon(Icons.share_outlined), onPressed: () => textTeilen(rezeptAlsText(r))),
        IconButton(
          tooltip: 'Löschen',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            store.alltag.rezepte.remove(r);
            await store.geaendert();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r.portionen.isNotEmpty || r.zeit.isNotEmpty)
            Text([if (r.portionen.isNotEmpty) '${r.portionen} Portionen', if (r.zeit.isNotEmpty) '${r.zeit} Min.'].join(' · '),
                style: const TextStyle(color: PT.grau)),
          const SizedBox(height: 8),
          const Text('Zutaten', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          for (final z in r.zutaten) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $z')),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              final neu = zutatenAufEinkaufsliste([for (final z in r.zutaten) if (!istGrundzutat(z)) z], store.alltag.einkauf);
              await store.geaendert();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('${neu.length} Zutaten auf der Einkaufsliste.')));
              }
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Zutaten auf die Einkaufsliste'),
          ),
          if (r.zubereitung.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Zubereitung', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(r.zubereitung, style: const TextStyle(height: 1.5)),
          ],
        ],
      ),
    );
  }
}
