import 'package:flutter/material.dart';

import '../logic/android_kanal.dart';
import '../logic/ki_anfragen.dart';
import 'app.dart';
import 'ki_text.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Sprechen statt tippen: Diktat sammeln, dann macht die KI daraus einen Brief oder eine E-Mail.
class DiktatScreen extends StatefulWidget {
  const DiktatScreen({super.key});

  @override
  State<DiktatScreen> createState() => _DiktatScreenState();
}

class _DiktatScreenState extends State<DiktatScreen> {
  final _text = TextEditingController();
  String _art = 'Brief';
  bool _hoert = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _sprechen() async {
    setState(() => _hoert = true);
    try {
      final t = await diktieren();
      if (t != null && t.trim().isNotEmpty) {
        final alt = _text.text.trimRight();
        _text.text = alt.isEmpty ? t.trim() : '$alt ${t.trim()}';
      }
    } on StateError catch (e) {
      if (mounted) zeigeHinweis(context, e.message);
    } finally {
      if (mounted) setState(() => _hoert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = StoreScope.of(context).profil;
    return Scaffold(
      appBar: AppBar(title: const Text('Diktieren')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sag einfach, worum es geht – z. B. „An die Hausverwaltung: Die Heizung ist seit Montag kaputt, '
            'bitte schnell einen Handwerker schicken.“ Du kannst mehrmals sprechen, der Text wird angehängt.',
            style: TextStyle(color: PT.grau),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const CircleBorder()),
                onPressed: _hoert ? null : _sprechen,
                child: Icon(_hoert ? Icons.hearing : Icons.mic, size: 44),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(_hoert ? 'Ich höre zu …' : 'Tippen und sprechen', style: const TextStyle(color: PT.grau))),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            minLines: 6,
            maxLines: null,
            decoration: feld(labelText: 'Dein Diktat (du kannst es auch tippen oder korrigieren)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Brief', label: Text('Brief'), icon: Icon(Icons.mail_outline)),
              ButtonSegment(value: 'E-Mail', label: Text('E-Mail'), icon: Icon(Icons.alternate_email)),
            ],
            selected: {_art},
            onSelectionChanged: (s) => setState(() => _art = s.first),
          ),
          const SizedBox(height: 8),
          const Text('Sprachnachrichten aus WhatsApp kann der Tiger noch nicht abhören – spiel sie ab und sprich '
              'das Wichtigste hier nach.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _text.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => KiTextScreen(
                        titel: _art == 'Brief' ? 'Brief aus Diktat' : 'E-Mail aus Diktat',
                        anfrage: diktatAnfrage(_text.text, profil, art: _art),
                        alsBrief: true,
                        hinweis: 'Prüfe den Text, bevor du ihn verschickst. Fehlende Angaben stehen in [Klammern].',
                      ),
                    )),
            icon: const Icon(Icons.auto_awesome),
            label: Text('Daraus ${_art == 'Brief' ? 'einen Brief' : 'eine E-Mail'} machen'),
          ),
        ),
      ),
    );
  }
}
