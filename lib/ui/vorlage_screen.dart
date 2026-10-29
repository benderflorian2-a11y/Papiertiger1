import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/android_kanal.dart';
import '../logic/export.dart';
import '../logic/kommunikation.dart';
import '../logic/ordnung.dart';
import 'app.dart';
import 'kommunikation.dart';
import 'module/profil.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Zeigt ein Musterschreiben zum Bearbeiten und Kopieren.
class VorlageScreen extends StatefulWidget {
  const VorlageScreen({super.key, required this.titel, required this.text, this.brief});

  final String titel;
  final String text;

  /// Brief, auf den geantwortet wird: für E-Mail-Adresse und Versand-Vermerk.
  final Brief? brief;

  @override
  State<VorlageScreen> createState() => _VorlageScreenState();
}

class _VorlageScreenState extends State<VorlageScreen> {
  late final _text = TextEditingController(text: widget.text);

  /// Dokumente aus dem Archiv, die mitgeschickt werden.
  final List<Brief> _anlagen = [];

  List<String> _anlagenDateien() => [
        for (final b in _anlagen)
          for (final p in (b.pdfPfad != null ? [b.pdfPfad!] : b.bilder))
            if (File(p).existsSync()) p,
      ];

  Future<void> _anlageWaehlen() async {
    final store = StoreScope.of(context);
    final kandidaten = store.briefe.where((b) => !_anlagen.contains(b) && b.id != widget.brief?.id).toList();
    if (kandidaten.isEmpty) {
      zeigeHinweis(context, 'Im Archiv sind noch keine Dokumente.');
      return;
    }
    final b = await showModalBottomSheet<Brief>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (c, scroll) => ListView(
          controller: scroll,
          children: [
            const ListTile(title: Text('Anlage aus dem Archiv', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final k in kandidaten)
              ListTile(
                leading: Icon(k.pdfPfad != null ? Icons.picture_as_pdf_outlined : Icons.description_outlined),
                title: Text(titelVon(k)),
                subtitle: Text(datumKurz(k.briefDatum ?? k.erstellt)),
                onTap: () => Navigator.pop(c, k),
              ),
          ],
        ),
      ),
    );
    if (b == null || !mounted) return;
    setState(() {
      _anlagen.add(b);
      _text.text = anlagenVermerk(_text.text, titelVon(b));
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profil = StoreScope.of(context).profil;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel),
        actions: [
          IconButton(
            tooltip: 'Als Word-Datei',
            icon: const Icon(Icons.article_outlined),
            onPressed: () async {
              final d = await alsWord(widget.titel, _text.text);
              await dateiTeilen(d.path, mimeType: 'application/rtf');
              _versandFragen('Post');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (profil.name.isEmpty || profil.adresse.isEmpty)
            PTKarte(
              farbe: PT.gelbHell,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfilScreen())),
              child: const Row(
                children: [
                  Icon(Icons.person_outline, color: PT.gelb),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Trag deinen Namen und deine Adresse ein, dann stehen sie automatisch im Brief.'),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          const Text(
            'Ersetze die Stellen in [eckigen Klammern] und prüfe den Text, bevor du ihn verschickst.',
            style: TextStyle(color: PT.grau),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 14,
            maxLines: null,
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final b in _anlagen)
              InputChip(
                avatar: const Icon(Icons.attach_file, size: 18),
                label: Text(titelVon(b)),
                onDeleted: () => setState(() => _anlagen.remove(b)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Anlage hinzufügen'),
              onPressed: _anlageWaehlen,
            ),
          ]),
          if (_anlagen.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('PDF und E-Mail werden mit den Anlagen geteilt. Wähle dann deine E-Mail-App.',
                  style: TextStyle(color: PT.grau, fontSize: 12)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _text.text));
                    zeigeHinweis(context, 'Text kopiert');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Kopieren'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _alsPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _perMail,
                  icon: const Icon(Icons.alternate_email, size: 18),
                  label: const Text('E-Mail'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Brief als PDF zum Drucken, Speichern oder Verschicken.
  Future<void> _alsPdf() async {
    try {
      final datei = await antwortAlsPdf(_text.text, titel: widget.titel);
      if (_anlagenDateien().isEmpty) {
        await dateiTeilen(datei.path, mimeType: 'application/pdf');
      } else {
        await dateienTeilen([datei.path, ..._anlagenDateien()], betreff: widget.titel);
      }
      _versandFragen('Post');
    } catch (e) {
      if (mounted) zeigeHinweis(context, 'PDF konnte nicht erstellt werden: $e');
    }
  }

  /// Öffnet die E-Mail-App mit Empfänger, Betreff und Text. Senden musst du dort selbst.
  Future<void> _perMail() async {
    final b = widget.brief;
    final an = b == null ? '' : (kontaktVon(b, StoreScope.of(context).profil).emails.firstOrNull ?? '');
    final betreff = betreffVon(_text.text);
    final dateien = _anlagenDateien();
    if (dateien.isNotEmpty) {
      // mailto: kann keine Anhänge – deshalb über „Teilen“ mit den Dateien.
      if (an.isNotEmpty) Clipboard.setData(ClipboardData(text: an));
      await dateienTeilen(dateien,
          text: mailInhalt(_text.text), betreff: betreff.isEmpty ? widget.titel : betreff);
      if (!mounted) return;
      if (an.isNotEmpty) zeigeHinweis(context, 'Empfänger $an ist kopiert – in der E-Mail-App einfügen.');
      _versandFragen('E-Mail');
      return;
    }
    final ok = await AndroidKanal.oeffnen(
        mailtoLink(an: an, betreff: betreff.isEmpty ? widget.titel : betreff, text: mailInhalt(_text.text)));
    if (!mounted) return;
    if (!ok) {
      zeigeHinweis(context, 'Keine E-Mail-App gefunden. Der Text ist kopiert.');
      Clipboard.setData(ClipboardData(text: _text.text));
      return;
    }
    if (an.isEmpty) zeigeHinweis(context, 'Im Brief stand keine E-Mail-Adresse. Bitte trag sie in der E-Mail-App ein.');
    _versandFragen('E-Mail');
  }

  void _versandFragen(String weg) {
    final b = widget.brief;
    if (b == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 15),
      content: const Text('Verschickt? Dann vermerkt der Tiger es und erinnert ans Nachfassen.'),
      action: SnackBarAction(
        label: 'Vermerken',
        onPressed: () {
          if (mounted) versandVermerken(context, b, weg: weg, text: widget.titel);
        },
      ),
    ));
  }
}
