import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../logic/brief_analyse.dart';
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

/// Zeile für einen Brief in Listen.
class BriefZeile extends StatelessWidget {
  const BriefZeile({super.key, required this.brief, required this.onTap});

  final Brief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = kategorieFuer(brief.kategorie);
    final t = typFuer(brief.typ);
    return PTKarte(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconKachel(kategorieIcon(brief.kategorie)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brief.absenderName ?? k.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15, color: PT.tinte),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.name} · ${datumKurz(brief.briefDatum ?? brief.erstellt)}',
                  style: const TextStyle(color: PT.grau, fontSize: 13),
                ),
              ],
            ),
          ),
          if (brief.erledigt)
            const Etikett('Erledigt', farbe: PT.gruen, hintergrund: PT.gruenHell)
          else if (brief.frist != null)
            FristEtikett(brief.frist!),
        ],
      ),
    );
  }
}
