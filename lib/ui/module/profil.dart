import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  TextEditingController? _name;
  TextEditingController? _adresse;
  final Map<String, TextEditingController> _extra = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = StoreScope.of(context).profil;
    _name ??= TextEditingController(text: p.name);
    _adresse ??= TextEditingController(text: p.adresse);
    for (final (k, _) in profilFelder) {
      _extra.putIfAbsent(k, () => TextEditingController(text: p.extra[k] ?? ''));
    }
  }

  @override
  void dispose() {
    _name?.dispose();
    _adresse?.dispose();
    for (final c in _extra.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mein Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Diese Angaben stehen automatisch in deinen Antwort-Briefen.',
              style: TextStyle(color: PT.grau)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: feld(labelText: 'Vor- und Nachname'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adresse,
            minLines: 2,
            maxLines: 3,
            decoration: feld(labelText: 'Adresse', hintText: 'Straße Hausnummer\nPLZ Ort'),
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Weitere Angaben für Formulare (freiwillig)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Bleiben nur auf deinem Handy.', style: TextStyle(color: PT.grau)),
              children: [
                for (final (k, label) in profilFelder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(controller: _extra[k], decoration: feld(labelText: label)),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              store.profil.name = _name!.text.trim();
              store.profil.adresse = _adresse!.text.trim();
              for (final e in _extra.entries) {
                final v = e.value.text.trim();
                if (v.isEmpty) {
                  store.profil.extra.remove(e.key);
                } else {
                  store.profil.extra[e.key] = v;
                }
              }
              await store.geaendert();
              if (context.mounted) {
                zeigeHinweis(context, 'Gespeichert');
                Navigator.of(context).pop();
              }
            },
            child: const Text('Speichern'),
          ),
        ),
      ),
    );
  }
}
