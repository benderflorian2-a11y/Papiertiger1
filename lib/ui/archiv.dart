import 'package:flutter/material.dart';

import '../logic/brief_analyse.dart';
import 'app.dart';
import 'brief_detail.dart';
import 'theme.dart';
import 'widgets/brief_teile.dart';
import 'widgets/common.dart';

class ArchivScreen extends StatefulWidget {
  const ArchivScreen({super.key});

  @override
  State<ArchivScreen> createState() => _ArchivScreenState();
}

class _ArchivScreenState extends State<ArchivScreen> {
  String _suche = '';
  String? _kategorie;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final vorhanden = <String>{for (final b in store.briefe) b.kategorie}.toList();
    final q = _suche.toLowerCase();
    final liste = store.briefe.where((b) {
      if (_kategorie != null && b.kategorie != _kategorie) return false;
      if (q.isEmpty) return true;
      return b.text.toLowerCase().contains(q) ||
          (b.absenderName ?? '').toLowerCase().contains(q) ||
          kategorieFuer(b.kategorie).name.toLowerCase().contains(q) ||
          (b.aktenzeichen ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Archiv')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          TextField(
            decoration: feld(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Briefe durchsuchen',
            ),
            onChanged: (v) => setState(() => _suche = v),
          ),
          if (vorhanden.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Alle'),
                      selected: _kategorie == null,
                      onSelected: (_) => setState(() => _kategorie = null),
                    ),
                  ),
                  for (final k in vorhanden)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(kategorieFuer(k).name),
                        selected: _kategorie == k,
                        onSelected: (_) => setState(() => _kategorie = k),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (store.briefe.isEmpty)
            const LeerHinweis(
                icon: Icons.inventory_2_outlined,
                text: 'Hier landen alle Briefe, die du scannst.')
          else if (liste.isEmpty)
            const LeerHinweis(icon: Icons.search_off, text: 'Nichts gefunden.')
          else
            for (final b in liste)
              BriefZeile(
                brief: b,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id))),
              ),
          if (liste.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${liste.length} ${liste.length == 1 ? 'Brief' : 'Briefe'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PT.grau, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
