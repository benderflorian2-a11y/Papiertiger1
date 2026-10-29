import 'package:flutter/material.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = StoreScope.of(context).profil;
    _name ??= TextEditingController(text: p.name);
    _adresse ??= TextEditingController(text: p.adresse);
  }

  @override
  void dispose() {
    _name?.dispose();
    _adresse?.dispose();
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
            decoration: feld(
                labelText: 'Adresse', hintText: 'Straße Hausnummer\nPLZ Ort'),
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
