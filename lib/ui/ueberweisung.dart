import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../logic/android_kanal.dart';
import '../logic/export.dart';
import '../logic/zahlung.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// GiroCode zum Scannen mit einer Banking-App.
class GiroCodeAnzeige extends StatelessWidget {
  const GiroCodeAnzeige(this.daten, {super.key, this.groesse = 220});

  final String daten;
  final double groesse;

  @override
  // Feste Größe: der QR-Baustein kann in Dialogen sonst nicht vermessen werden
  Widget build(BuildContext context) => SizedBox.square(
        dimension: groesse + 16,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: QrImageView(data: daten, size: groesse, errorCorrectionLevel: QrErrorCorrectLevel.M),
        ),
      );
}

/// GiroCode als PNG-Datei, z. B. für die Foto-Überweisung der Banking-App.
Future<File> giroCodeAlsBild(String daten, String name) async {
  final painter = QrPainter(
    data: daten,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
  );
  // Weißer Hintergrund mit Rand, damit Scanner den Code sicher erkennen
  const groesse = 900.0, rand = 80.0;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(const Rect.fromLTWH(0, 0, groesse + 2 * rand, groesse + 2 * rand), Paint()..color = Colors.white);
  canvas.translate(rand, rand);
  painter.paint(canvas, const Size(groesse, groesse));
  final bild = await rec.endRecording().toImage((groesse + 2 * rand).toInt(), (groesse + 2 * rand).toInt());
  final bytes = await bild.toByteData(format: ui.ImageByteFormat.png);
  final ordner = await getTemporaryDirectory();
  final datei = File('${ordner.path}/GiroCode_${name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.png');
  await datei.writeAsBytes(bytes!.buffer.asUint8List());
  return datei;
}

/// Kunde zahlt vor Ort: GiroCode groß zeigen.
Future<void> giroCodeZeigen(BuildContext context, String daten, String titel) => showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(titel),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          GiroCodeAnzeige(daten, groesse: (MediaQuery.of(d).size.width - 160).clamp(160.0, 260.0)),
          const SizedBox(height: 8),
          const Text('Mit der Banking-App scannen („Foto-Überweisung“ bzw. „QR-Code scannen“).',
              textAlign: TextAlign.center, style: TextStyle(color: PT.grau, fontSize: 13)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Fertig'))],
      ),
    );

/// Überweisung vorbereiten, prüfen und zur Freigabe in die Banking-App geben.
class UeberweisungScreen extends StatefulWidget {
  const UeberweisungScreen({super.key, required this.auftrag, this.beiFreigabe});

  final Zahlauftrag auftrag;

  /// Wird aufgerufen, wenn du bestätigst, dass du die Zahlung freigegeben hast.
  final void Function(DateTime am)? beiFreigabe;

  @override
  State<UeberweisungScreen> createState() => _UeberweisungScreenState();
}

class _UeberweisungScreenState extends State<UeberweisungScreen> {
  late final _empfaenger = TextEditingController(text: widget.auftrag.empfaenger);
  late final _iban = TextEditingController(text: widget.auftrag.iban);
  late final _bic = TextEditingController(text: widget.auftrag.bic);
  late final _betrag = TextEditingController(
      text: widget.auftrag.betrag == null ? '' : widget.auftrag.betrag!.toStringAsFixed(2).replaceAll('.', ','));
  late final _zweck = TextEditingController(text: widget.auftrag.zweck);
  bool _geoeffnet = false;

  @override
  void dispose() {
    for (final c in [_empfaenger, _iban, _bic, _betrag, _zweck]) {
      c.dispose();
    }
    super.dispose();
  }

  Zahlauftrag get _z => Zahlauftrag(
        empfaenger: _empfaenger.text.trim(),
        iban: _iban.text.replaceAll(' ', '').toUpperCase(),
        bic: _bic.text.trim(),
        betrag: double.tryParse(_betrag.text.replaceAll('.', '').replaceAll(',', '.').replaceAll('€', '').trim()),
        zweck: _zweck.text.trim(),
      );

  Future<void> _zurFreigabe() async {
    final z = _z;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Überweisung prüfen'),
        content: Text('${z.alsText()}\n\nDu gibst die Zahlung gleich in deiner Banking-App per pushTAN frei. '
            'Ohne deine Freigabe passiert nichts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Stimmt – weiter')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Noch keine direkte Bankverbindung (siehe bankDirektVerbunden): Daten mitnehmen und Banking-App öffnen.
    await Clipboard.setData(ClipboardData(text: z.alsText()));
    final bild = await giroCodeAlsBild(z.giroCodeText, z.zweck);
    final offen = await bankingAppOeffnen();
    if (!mounted) return;
    setState(() => _geoeffnet = true);
    if (!offen) {
      await dateiTeilen(bild.path, mimeType: 'image/png', text: z.alsText());
      if (mounted) zeigeHinweis(context, 'Sparkassen-App nicht gefunden – GiroCode-Bild zum Speichern geteilt.');
    } else {
      zeigeHinweis(context, 'Angaben kopiert. In der App: Überweisung → Foto-Überweisung oder einfügen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = _z;
    final fehler = zahlauftragPruefen(z);
    Widget feldZeile(TextEditingController c, String label, {TextInputType? typ, String? hint}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            keyboardType: typ,
            decoration: feld(labelText: label, hintText: hint),
            onChanged: (_) => setState(() {}),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Überweisung vorbereiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          feldZeile(_empfaenger, 'Empfänger'),
          feldZeile(_iban, 'IBAN', hint: 'DE..'),
          feldZeile(_bic, 'BIC (optional)'),
          feldZeile(_betrag, 'Betrag in €', typ: const TextInputType.numberWithOptions(decimal: true)),
          feldZeile(_zweck, 'Verwendungszweck', hint: 'Rechnungs- oder Kundennummer'),
          if (fehler.isNotEmpty)
            PTKarte(
              farbe: PT.gelbHell,
              child: Text(fehler.join('\n')),
            )
          else ...[
            Center(child: GiroCodeAnzeige(z.giroCodeText, groesse: 200)),
            const SizedBox(height: 6),
            const Text(
              'Der Tiger überweist nie selbst. Du gibst die Zahlung in deiner Sparkassen-App per S-pushTAN frei.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PT.grau, fontSize: 12),
            ),
          ],
          if (_geoeffnet) ...[
            const SizedBox(height: 12),
            PTKarte(
              farbe: PT.orangeHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('In der Banking-App freigegeben?', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: () {
                    widget.beiFreigabe?.call(DateTime.now());
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Ja, freigegeben – als bezahlt vermerken'),
                ),
              ]),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: fehler.isEmpty ? _zurFreigabe : null,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Zur Freigabe an die Bank'),
          ),
        ),
      ),
    );
  }
}
