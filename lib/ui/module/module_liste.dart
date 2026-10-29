import 'package:flutter/material.dart';

import '../app.dart';
import '../finanzen.dart';
import '../geschaeft/geschaeft.dart';
import '../haushalt/haushalt.dart';
import '../theme.dart';
import 'antraege.dart';
import 'behoerdengaenge.dart';
import 'belege.dart';
import 'ereignisse.dart';
import 'leistungen.dart';
import 'steuer.dart';
import 'vertraege.dart';

class ModulInfo {
  const ModulInfo(this.titel, this.untertitel, this.icon, this.seite);

  final String titel;
  final String untertitel;
  final IconData icon;
  final Widget Function() seite;
}

final module = <ModulInfo>[
  ModulInfo('Finanzen', 'Zahlungen und Monatsüberblick', Icons.account_balance_wallet_outlined,
      () => const FinanzenScreen()),
  ModulInfo('Verträge & Abos', 'Kündigungsfristen im Blick', Icons.description_outlined,
      () => const VertraegeScreen()),
  ModulInfo('Belege & Garantien', 'Kassenbons sicher aufheben', Icons.receipt_long_outlined,
      () => const BelegeScreen()),
  ModulInfo('Lebens-Ereignisse', 'Umzug, Job, Hochzeit, Baby', Icons.checklist,
      () => const EreignisseScreen()),
  ModulInfo('Steuer', 'Belege fürs Finanzamt', Icons.calculate_outlined,
      () => const SteuerScreen()),
  ModulInfo('Was steht mir zu?', 'Leistungen finden', Icons.volunteer_activism_outlined,
      () => const LeistungenScreen()),
  ModulInfo('Anträge', 'Kindergeld und Wohngeld', Icons.assignment_outlined,
      () => const AntraegeScreen()),
  ModulInfo('Behördengänge', 'Ummelden, Gewerbe, Ausweis', Icons.account_balance_outlined,
      () => const BehoerdengaengeScreen()),
];

class ModulRaster extends StatelessWidget {
  const ModulRaster({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final liste = [
      if (store.bereichAktiv('selbststaendig'))
        ModulInfo('Mein Gewerbe', 'Rechnungen, Kunden, Marketing', Icons.storefront_outlined,
            () => const GeschaeftScreen()),
      if (store.bereichAktiv('haushalt'))
        ModulInfo('Haushalt', 'Einkauf, Essen, Reisen, Zähler', Icons.home_outlined, () => const HaushaltScreen()),
      ...module,
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        for (final m in liste)
          Material(
            key: ValueKey('modul-${m.titel}'),
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => m.seite())),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PT.sand),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: PT.orangeHell, borderRadius: BorderRadius.circular(12)),
                      child: Icon(m.icon, color: PT.orangeDunkel, size: 22),
                    ),
                    const Spacer(),
                    Text(m.titel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15, color: PT.tinte)),
                    const SizedBox(height: 2),
                    Text(m.untertitel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: PT.grau, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
