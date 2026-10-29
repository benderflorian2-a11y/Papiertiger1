import 'package:flutter/material.dart';

import '../logic/ordnung.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'fristen.dart';
import 'module/module_liste.dart';
import 'scan.dart';
import 'theme.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.zuTab});

  final void Function(int tab) zuTab;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final fristen = alleFristen(store);
    final offen = store.briefe.where((b) => !b.erledigt).length;
    final dringend =
        store.briefe.where((b) => dringlichkeit(b) == Dringlichkeit.hoch).toList();
    final name = store.profil.name.split(' ').first;

    void oeffne(Widget seite) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => seite));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              const Tiger(size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Hallo!' : 'Hallo $name!',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800, color: PT.tinte)),
                    const Text('Keine Angst vor Post.',
                        style: TextStyle(color: PT.grau, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Hauptaktion
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PT.orange,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Neuer Brief?',
                    style: TextStyle(
                        color: PT.tinte, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Foto machen, und der Tiger erklärt dir, was drinsteht.',
                    style: TextStyle(color: PT.tinte, fontSize: 15, height: 1.35)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('brief-scannen'),
                    style: FilledButton.styleFrom(
                        backgroundColor: PT.tinte, foregroundColor: Colors.white),
                    onPressed: () => oeffne(const ScanScreen(mitKamera: true)),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Brief fotografieren'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Quelle(
                      icon: Icons.photo_library_outlined,
                      text: 'Galerie',
                      onTap: () => oeffne(const ScanScreen(mitKamera: false)),
                    ),
                    _Quelle(
                      key: const ValueKey('pdf-import-start'),
                      icon: Icons.picture_as_pdf_outlined,
                      text: 'PDF',
                      onTap: () => oeffne(const PdfImportScreen()),
                    ),
                    _Quelle(
                      key: const ValueKey('text-einfuegen-start'),
                      icon: Icons.content_paste,
                      text: 'Text',
                      onTap: () => oeffne(const TextEinfuegenScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              const Expanded(child: Abschnitt('Als Nächstes fällig')),
              if (fristen.length > 3)
                TextButton(onPressed: () => zuTab(1), child: const Text('Alle')),
            ],
          ),
          if (fristen.isEmpty)
            const PTKarte(
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: PT.gruen),
                  SizedBox(width: 12),
                  Expanded(child: Text('Nichts offen. Der Tiger schläft entspannt.')),
                ],
              ),
            )
          else
            for (final f in fristen.take(3)) FristZeile(f),

          if (dringend.isNotEmpty) ...[
            const Abschnitt('Dringend'),
            for (final b in dringend.take(3))
              BriefZeile(
                brief: b,
                onTap: () => oeffne(BriefDetail(briefId: b.id)),
              ),
          ],

          Row(
            children: [
              const Expanded(child: Abschnitt('Deine Post')),
              TextButton(onPressed: () => zuTab(2), child: const Text('Archiv')),
            ],
          ),
          PTKarte(
            onTap: () => zuTab(2),
            child: Row(
              children: [
                const IconKachel(Icons.inventory_2_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    store.briefe.isEmpty
                        ? 'Noch keine Briefe gespeichert'
                        : '${store.briefe.length} ${store.briefe.length == 1 ? 'Brief' : 'Briefe'}, davon $offen offen',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),

          const Abschnitt('Alle Module'),
          const ModulRaster(),
        ],
      ),
    );
  }
}

class _Quelle extends StatelessWidget {
  const _Quelle({super.key, required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: PT.tinte),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: PT.tinte, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
