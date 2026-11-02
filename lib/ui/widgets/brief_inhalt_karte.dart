import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/brief_inhalt.dart';
import '../theme.dart';
import 'common.dart';

IconData _gruppenSymbol(String g) => switch (g) {
      'Termine & Daten' => Icons.event_outlined,
      'Beträge' => Icons.euro,
      'Nummern' => Icons.tag,
      'Bankverbindung' => Icons.account_balance_outlined,
      'Kontakt' => Icons.contact_phone_outlined,
      'Anlagen' => Icons.attach_file,
      _ => Icons.info_outline,
    };

/// „Das steht im Brief“: Betreff, wichtigste Aussagen und alle erkannten Angaben.
/// Antippen einer Angabe kopiert sie (z. B. IBAN oder Aktenzeichen).
class BriefInhaltKarte extends StatelessWidget {
  const BriefInhaltKarte(this.inhalt, {super.key});

  final BriefInhalt inhalt;

  @override
  Widget build(BuildContext context) {
    if (inhalt.leer) return const SizedBox.shrink();
    final gruppen = inhalt.gruppen;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Abschnitt('Das steht im Brief'),
      PTKarte(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (inhalt.betreff != null) ...[
            const Text('Betreff', style: TextStyle(color: PT.grau, fontSize: 13)),
            Text(inhalt.betreff!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: PT.tinte)),
            const SizedBox(height: 10),
          ],
          for (final s in inhalt.kernaussagen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7, right: 10),
                  child: Icon(Icons.circle, size: 7, color: PT.orangeDunkel),
                ),
                Expanded(child: Text(s, style: const TextStyle(height: 1.45))),
              ]),
            ),
          if (gruppen.isNotEmpty) ...[
            if (inhalt.kernaussagen.isNotEmpty || inhalt.betreff != null) const Divider(height: 24),
            for (final g in gruppen.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Row(children: [
                  Icon(_gruppenSymbol(g.key), size: 16, color: PT.orangeDunkel),
                  const SizedBox(width: 6),
                  Text(g.key, style: const TextStyle(fontWeight: FontWeight.w700, color: PT.orangeDunkel, fontSize: 13)),
                ]),
              ),
              for (final p in g.value)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: p.wert));
                    if (context.mounted) zeigeHinweis(context, '${p.label} kopiert');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        flex: 4,
                        child: Text(p.label, style: const TextStyle(color: PT.grau, fontSize: 13.5)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: Text(p.wert,
                            textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: PT.tinte)),
                      ),
                    ]),
                  ),
                ),
            ],
            const SizedBox(height: 6),
            const Text('Antippen kopiert die Angabe. Automatisch erkannt – im Zweifel gilt das Original.',
                style: TextStyle(color: PT.grau, fontSize: 12)),
          ],
        ]),
      ),
    ]);
  }
}
