import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/brief_analyse.dart';
import '../logic/ordnung.dart';
import '../logic/pdf_import.dart';
import '../logic/texterkennung.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

/// Erstellt aus erkanntem Text einen gespeicherten Brief und öffnet ihn.
Future<void> briefAnlegen(BuildContext context, String text, List<String> bilder,
    {String? pdfPfad}) async {
  final store = StoreScope.of(context);
  final a = analysiereBrief(text);
  final brief = Brief(
    id: neueId(),
    erstellt: DateTime.now(),
    kategorie: a.kategorie.key,
    typ: a.typ.key,
    absenderName: a.absenderName,
    text: text,
    erklaerung: a.erklaerung,
    bilder: bilder,
    frist: a.frist,
    fristUnsicher: a.fristUnsicher,
    betrag: a.betrag,
    guthaben: a.istGuthaben,
    aktenzeichen: a.aktenzeichen,
    briefDatum: a.briefDatum,
    aufgaben: a.aufgaben.map(Aufgabe.new).toList(),
    fakten: a.fakten,
    bedeutung: a.bedeutung,
    pdfPfad: pdfPfad,
    unterlagen: unterlagenFinden(text).map(Aufgabe.new).toList(),
  );
  await store.briefHinzufuegen(brief);
  if (!context.mounted) return;
  await Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => BriefDetail(briefId: brief.id, neu: true)));
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.mitKamera});

  final bool mitKamera;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<String> _seiten = [];
  bool _liest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seiteHolen(widget.mitKamera));
  }

  Future<void> _seiteHolen(bool kamera) async {
    try {
      final pfad = await Texterkennung.bildHolen(kamera: kamera);
      if (pfad != null && mounted) setState(() => _seiten.add(pfad));
    } catch (e) {
      if (mounted) {
        _fehler(kamera ? 'Die Kamera konnte nicht geöffnet werden.' : 'Das Bild konnte nicht geladen werden.', e);
      }
    }
  }

  /// Zeigt einen Fehler mit technischen Details, damit man ihn melden kann.
  void _fehler(String text, Object e) {
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Das hat nicht geklappt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              const SizedBox(height: 12),
              const Text('Technische Details:', style: TextStyle(fontWeight: FontWeight.w700)),
              SelectableText('$e', style: const TextStyle(fontSize: 12, color: PT.grau)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(d);
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const TextEinfuegenScreen()));
            },
            child: const Text('Text einfügen'),
          ),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _auswerten() async {
    setState(() => _liest = true);
    try {
      final text = await Texterkennung.textErkennen(_seiten);
      if (!mounted) return;
      if (text.trim().length < 20) {
        setState(() => _liest = false);
        zeigeHinweis(context,
            'Der Tiger konnte kaum Text erkennen. Fotografiere den Brief bei gutem Licht und von oben.');
        return;
      }
      await briefAnlegen(context, text, List.of(_seiten));
    } catch (e) {
      if (!mounted) return;
      setState(() => _liest = false);
      _fehler('Beim Lesen des Briefs ist ein Fehler passiert.', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_liest) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tiger(size: 120),
              SizedBox(height: 24),
              Text('Der Tiger liest deinen Brief …',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              SizedBox(width: 180, child: LinearProgressIndicator()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Brief scannen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_seiten.isEmpty)
            const LeerHinweis(
              icon: Icons.document_scanner_outlined,
              text: 'Fotografiere jede Seite des Briefs gerade von oben, bei gutem Licht.',
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
              children: [
                for (var i = 0; i < _seiten.length; i++)
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_seiten[i]), fit: BoxFit.cover),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Etikett('Seite ${i + 1}',
                            farbe: Colors.white, hintergrund: PT.tinte.withAlpha(180)),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: IconButton.filledTonal(
                          iconSize: 18,
                          onPressed: () => setState(() => _seiten.removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _seiteHolen(true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_seiten.isEmpty ? 'Seite fotografieren' : 'Weitere Seite fotografieren'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _seiteHolen(false),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Aus Galerie hinzufügen'),
          ),
        ],
      ),
      bottomNavigationBar: _seiten.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _auswerten,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(_seiten.length == 1
                      ? 'Brief auswerten'
                      : 'Brief auswerten (${_seiten.length} Seiten)'),
                ),
              ),
            ),
    );
  }
}

/// Für Briefe, die als E-Mail oder PDF kommen: Text einfügen.
class TextEinfuegenScreen extends StatefulWidget {
  const TextEinfuegenScreen({super.key});

  @override
  State<TextEinfuegenScreen> createState() => _TextEinfuegenScreenState();
}

class _TextEinfuegenScreenState extends State<TextEinfuegenScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text einfügen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Kopiere den Text aus einer E-Mail oder einem PDF und füge ihn hier ein.',
            style: TextStyle(color: PT.grau),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('text-einfuegen'),
            controller: _text,
            minLines: 10,
            maxLines: 20,
            decoration: feld(hintText: 'Brieftext hier einfügen …'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const ValueKey('text-auswerten'),
            onPressed: () {
              if (_text.text.trim().length < 20) {
                zeigeHinweis(context, 'Bitte füge den ganzen Brieftext ein.');
                return;
              }
              briefAnlegen(context, _text.text, const []);
            },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Brief auswerten'),
          ),
        ),
      ),
    );
  }
}

/// Wählt ein PDF, liest es und legt den Brief an.
class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({super.key});

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  String _stand = 'PDF auswählen …';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _los());
  }

  Future<void> _los() async {
    try {
      final pfad = await PdfImport.waehlen();
      if (!mounted) return;
      if (pfad == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _stand = 'Der Tiger liest das PDF …');
      final ergebnis = await PdfImport.lesen(pfad, fortschritt: (s, von) {
        if (mounted) setState(() => _stand = 'Der Tiger liest Seite $s von $von …');
      });
      if (!mounted) return;
      if (ergebnis.text.trim().length < 20) {
        zeigeHinweis(context, 'In diesem PDF konnte der Tiger keinen Text finden.');
        Navigator.of(context).pop();
        return;
      }
      if (ergebnis.seiten > PdfImport.maxSeiten) {
        zeigeHinweis(context,
            'Das PDF hat ${ergebnis.seiten} Seiten. Der Tiger hat die ersten ${PdfImport.maxSeiten} gelesen.');
      }
      await briefAnlegen(context, ergebnis.text, ergebnis.bilder, pdfPfad: ergebnis.pdfPfad);
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Das PDF konnte nicht gelesen werden'),
          content: SelectableText('$e', style: const TextStyle(fontSize: 12, color: PT.grau)),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Tiger(size: 120),
            const SizedBox(height: 24),
            Text(_stand, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const SizedBox(width: 180, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
