import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/export.dart';
import '../logic/formular_eintrag.dart';
import '../logic/ordnung.dart';
import 'app.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/unterschrift.dart';

/// Formular direkt ausfüllen: auf die Seite tippen, Text oder Unterschrift setzen, als PDF teilen.
class FormularPdfScreen extends StatefulWidget {
  const FormularPdfScreen({super.key, required this.brief});

  final Brief brief;

  @override
  State<FormularPdfScreen> createState() => _FormularPdfScreenState();
}

class _FormularPdfScreenState extends State<FormularPdfScreen> {
  late List<FormularEintrag> _eintraege;
  final _seitenGroesse = <int, Size>{};
  bool _geladen = false;
  bool _arbeitet = false;

  List<String> get _seiten => widget.brief.bilder.where((p) => File(p).existsSync()).toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_geladen) return;
    _geladen = true;
    _eintraege = formularLaden(StoreScope.of(context).notizen, widget.brief.id);
    for (var i = 0; i < _seiten.length; i++) {
      _groesseLesen(i, _seiten[i]);
    }
  }

  Future<void> _groesseLesen(int i, String pfad) async {
    final bild = await decodeImageFromList(await File(pfad).readAsBytes());
    if (mounted) setState(() => _seitenGroesse[i] = Size(bild.width.toDouble(), bild.height.toDouble()));
    bild.dispose();
  }

  void _speichern() {
    final store = StoreScope.of(context);
    formularSpeichern(store.notizen, widget.brief.id, _eintraege);
    store.geaendert();
  }

  Future<void> _neu(int seite, double x, double y) async {
    final store = StoreScope.of(context);
    final ergebnis = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TextWahl(vorschlaege: formularVorschlaege(store.profil)),
    );
    if (!mounted || ergebnis == null) return;
    if (ergebnis == _unterschrift) {
      final u = await Navigator.of(context).push<(String, String)>(MaterialPageRoute(
        builder: (_) => const UnterschriftScreen(titel: 'Unterschrift', durchsichtig: true),
      ));
      if (u == null) return;
      setState(() => _eintraege.add(FormularEintrag(seite: seite, x: x, y: y, bild: u.$1, groesse: 0.02)));
    } else if (ergebnis is String && ergebnis.trim().isNotEmpty) {
      setState(() => _eintraege.add(FormularEintrag(seite: seite, x: x, y: y, text: ergebnis.trim())));
    } else {
      return;
    }
    _speichern();
  }

  Future<void> _bearbeiten(FormularEintrag e) async {
    final c = TextEditingController(text: e.text);
    final aktion = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(e.bild != null ? 'Unterschrift' : 'Eintrag'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (e.bild == null) TextField(controller: c, autofocus: true, decoration: feld()),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Größe'),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => setD(() => e.groesse = (e.groesse * 0.85).clamp(0.008, 0.08)),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setD(() => e.groesse = (e.groesse * 1.15).clamp(0.008, 0.08)),
              ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, 'weg'), child: const Text('Löschen', style: TextStyle(color: PT.rot))),
            TextButton(onPressed: () => Navigator.pop(d, 'ok'), child: const Text('OK')),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (aktion == 'weg') {
        _eintraege.remove(e);
      } else if (e.bild == null && c.text.trim().isNotEmpty) {
        e.text = c.text.trim();
      }
    });
    c.dispose();
    _speichern();
  }

  Future<void> _pdf() async {
    setState(() => _arbeitet = true);
    try {
      final datei = await formularAlsPdf(_seiten, _eintraege, titel: titelVon(widget.brief));
      await dateiTeilen(datei.path, text: titelVon(widget.brief), mimeType: 'application/pdf');
    } catch (e) {
      if (mounted) zeigeHinweis(context, 'PDF konnte nicht erstellt werden: $e');
    } finally {
      if (mounted) setState(() => _arbeitet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seiten = _seiten;
    return Scaffold(
      appBar: AppBar(title: const Text('Direkt ins Formular schreiben'), actions: [
        IconButton(
          tooltip: 'Als PDF teilen',
          onPressed: _arbeitet || seiten.isEmpty ? null : _pdf,
          icon: _arbeitet
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined),
        ),
      ]),
      body: seiten.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Zu diesem Schreiben gibt es kein Seitenbild. Fotografiere das Formular oder importiere es als PDF, '
                  'dann kannst du direkt hineinschreiben.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                const Text(
                  'Tippe auf die Stelle, wo etwas hin soll. Antippen eines Eintrags: ändern oder löschen. '
                  'Ziehen: verschieben. Oben rechts als PDF teilen.',
                  style: TextStyle(color: PT.grau, fontSize: 13),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < seiten.length; i++) ...[
                  if (seiten.length > 1) Text('Seite ${i + 1}', style: const TextStyle(color: PT.grau)),
                  _seite(i, seiten[i]),
                  const SizedBox(height: 12),
                ],
                const Text('Prüfe alles, bevor du das Formular abgibst. Manche Stellen verlangen eine Unterschrift von Hand.',
                    style: TextStyle(color: PT.grau, fontSize: 12)),
              ],
            ),
    );
  }

  Widget _seite(int i, String pfad) {
    final g = _seitenGroesse[i];
    if (g == null) return const AspectRatio(aspectRatio: 0.707, child: Center(child: CircularProgressIndicator()));
    return AspectRatio(
      aspectRatio: g.width / g.height,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return GestureDetector(
          onTapUp: (d) => _neu(i, d.localPosition.dx / w, d.localPosition.dy / h),
          child: Stack(children: [
            Positioned.fill(child: Image.file(File(pfad), fit: BoxFit.fill)),
            for (final e in _eintraege.where((e) => e.seite == i))
              Positioned(
                left: e.x * w,
                top: e.y * h,
                child: GestureDetector(
                  onTap: () => _bearbeiten(e),
                  onPanUpdate: (d) => setState(() {
                    e.x = (e.x + d.delta.dx / w).clamp(0.0, 0.98);
                    e.y = (e.y + d.delta.dy / h).clamp(0.0, 0.98);
                  }),
                  onPanEnd: (_) => _speichern(),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: PT.orange.withValues(alpha: 0.5))),
                    child: e.bild != null
                        ? Image.file(File(e.bild!), height: e.groesse * w * 3)
                        : Text(e.text,
                            style: TextStyle(fontSize: e.groesse * w, color: const Color(0xFF0D2A6B), height: 1.0)),
                  ),
                ),
              ),
          ]),
        );
      }),
    );
  }
}

const _unterschrift = Object();

class _TextWahl extends StatefulWidget {
  const _TextWahl({required this.vorschlaege});

  final List<(String, String)> vorschlaege;

  @override
  State<_TextWahl> createState() => _TextWahlState();
}

class _TextWahlState extends State<_TextWahl> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Was soll hier stehen?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: _c,
          decoration: feld(hintText: 'Eigener Text'),
          onSubmitted: (t) => Navigator.pop(context, t),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ActionChip(
            avatar: const Icon(Icons.draw_outlined, size: 18),
            label: const Text('Unterschrift'),
            onPressed: () => Navigator.pop(context, _unterschrift),
          ),
          for (final (label, wert) in widget.vorschlaege)
            ActionChip(
              label: Text(label == 'Kreuz' ? 'X ankreuzen' : '$label: ${wert.length > 22 ? '${wert.substring(0, 22)}…' : wert}'),
              onPressed: () => Navigator.pop(context, wert),
            ),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('Eintragen')),
        ),
      ]),
    );
  }
}
