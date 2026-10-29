import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../logic/android_kanal.dart';
import '../logic/export.dart';
import '../logic/kommunikation.dart';
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
      await dateiTeilen(datei.path, mimeType: 'application/pdf');
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
