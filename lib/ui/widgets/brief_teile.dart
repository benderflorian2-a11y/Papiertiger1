import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/ordnung.dart';
import '../theme.dart';
import 'common.dart';

IconData kategorieIcon(String key) {
  switch (key) {
    case 'finanzamt':
      return Icons.account_balance_outlined;
    case 'familienkasse':
      return Icons.family_restroom_outlined;
    case 'jobcenter':
    case 'arbeitsagentur':
      return Icons.work_outline;
    case 'rente':
      return Icons.elderly_outlined;
    case 'krankenkasse':
      return Icons.local_hospital_outlined;
    case 'inkasso':
      return Icons.warning_amber_outlined;
    case 'gericht':
      return Icons.gavel_outlined;
    case 'bussgeld':
      return Icons.directions_car_outlined;
    case 'rundfunk':
      return Icons.radio_outlined;
    case 'vermieter':
      return Icons.home_outlined;
    case 'energie':
      return Icons.bolt_outlined;
    case 'telefon':
      return Icons.phone_android_outlined;
    case 'versicherung':
      return Icons.shield_outlined;
    case 'stadt':
      return Icons.location_city_outlined;
    case 'bank':
      return Icons.credit_card_outlined;
  }
  return Icons.mail_outline;
}

/// Etikett für die Dringlichkeit eines Briefs.
class DringlichkeitEtikett extends StatelessWidget {
  const DringlichkeitEtikett(this.stufe, {super.key});

  final Dringlichkeit stufe;

  @override
  Widget build(BuildContext context) {
    return switch (stufe) {
      Dringlichkeit.hoch => const Etikett('Dringend', farbe: PT.rot, hintergrund: PT.rotHell),
      Dringlichkeit.mittel => const Etikett('Zu erledigen', farbe: PT.gelb, hintergrund: PT.gelbHell),
      Dringlichkeit.niedrig => const Etikett('Info', farbe: PT.gruen, hintergrund: PT.gruenHell),
    };
  }
}

/// Zeile für einen Brief in Listen.
class BriefZeile extends StatelessWidget {
  const BriefZeile({super.key, required this.brief, required this.onTap});

  final Brief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stufe = dringlichkeit(brief);
    return PTKarte(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconKachel(kategorieIcon(brief.kategorie),
              farbe: stufe == Dringlichkeit.hoch ? PT.rotHell : PT.orangeHell,
              iconFarbe: stufe == Dringlichkeit.hoch ? PT.rot : PT.orangeDunkel),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titelVon(brief),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: PT.tinte),
                ),
                const SizedBox(height: 2),
                Text(
                  '${datumKurz(brief.briefDatum ?? brief.erstellt)} · ${ordnerFuer(brief).name}'
                  '${brief.pdfPfad != null ? ' · PDF' : ''}',
                  style: const TextStyle(color: PT.grau, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (brief.erledigt)
            const Etikett('Erledigt', farbe: PT.gruen, hintergrund: PT.gruenHell)
          else if (brief.frist != null)
            FristEtikett(brief.frist!)
          else
            DringlichkeitEtikett(stufe),
        ],
      ),
    );
  }
}
