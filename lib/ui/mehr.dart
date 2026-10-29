import 'package:flutter/material.dart';

import 'app.dart';
import 'module/module_liste.dart';
import 'erinnerungen_einstellungen.dart';
import 'kommunikation.dart';
import 'ki_einstellungen.dart';
import 'termine.dart';
import 'module/profil.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

class MehrScreen extends StatelessWidget {
  const MehrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    void oeffne(Widget s) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          PTKarte(
            onTap: () => oeffne(const ProfilScreen()),
            child: Row(
              children: [
                const IconKachel(Icons.person_outline),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.profil.name.isEmpty ? 'Mein Profil' : store.profil.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const Text('Name und Adresse für Antwort-Briefe',
                          style: TextStyle(color: PT.grau, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),
          const Abschnitt('Module'),
          for (final m in module)
            PTKarte(
              padding: const EdgeInsets.all(12),
              onTap: () => oeffne(m.seite()),
              child: Row(
                children: [
                  IconKachel(m.icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(m.untertitel,
                            style: const TextStyle(color: PT.grau, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: PT.grau),
                ],
              ),
            ),
          const Abschnitt('Schriftverkehr'),
          PTKarte(
            padding: const EdgeInsets.all(12),
            onTap: () => oeffne(const KommunikationScreen()),
            child: const Row(
              children: [
                IconKachel(Icons.forum_outlined),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Antworten und Verlauf', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Worauf du wartest, was du verschickt hast', style: TextStyle(color: PT.grau, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),
          const PTKarte(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                IconKachel(Icons.mark_email_unread_outlined),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'E-Mails und PDFs übernehmen: In der E-Mail- oder Datei-App auf „Teilen“ tippen und „Papiertiger“ wählen.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Abschnitt('Fristen & Termine'),
          PTKarte(
            padding: const EdgeInsets.all(12),
            onTap: () => oeffne(const ErinnerungenEinstellungen()),
            child: const Row(
              children: [
                IconKachel(Icons.notifications_active_outlined),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Erinnerungen', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Wann und wie oft der Tiger erinnert', style: TextStyle(color: PT.grau, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),
          PTKarte(
            padding: const EdgeInsets.all(12),
            onTap: () => oeffne(const TermineListe()),
            child: const Row(
              children: [
                IconKachel(Icons.event_repeat_outlined),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Meine Termine', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('TÜV, Wartung, Versicherung und mehr', style: TextStyle(color: PT.grau, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),
          const Abschnitt('KI auf dem Handy'),
          PTKarte(
            onTap: () => oeffne(const KiEinstellungenScreen()),
            child: const Row(
              children: [
                IconKachel(Icons.auto_awesome),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KI-Tiger', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Liest jeden Brief komplett – offline',
                          style: TextStyle(color: PT.grau, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: PT.grau),
              ],
            ),
          ),
          const Abschnitt('Papiertiger Plus'),
          const PTKarte(
            farbe: PT.orangeHell,
            child: Row(
              children: [
                Tiger(size: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'In der Testphase sind alle Funktionen kostenlos und unbegrenzt.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Abschnitt('Datenschutz'),
          const PTKarte(
            child: Text(
              'Texterkennung, KI und Speicherung laufen nur auf deinem Handy. '
              'Briefe, Fotos und Angaben werden nicht ins Internet geschickt. '
              'Wenn du die App löschst, sind auch alle Daten weg.',
              style: TextStyle(height: 1.45),
            ),
          ),
          PTKarte(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Alle Daten löschen?'),
                  content: const Text(
                      'Alle Briefe, Fotos, Verträge, Belege und dein Profil werden endgültig gelöscht.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Abbrechen')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Alles löschen',
                            style: TextStyle(color: PT.rot))),
                  ],
                ),
              );
              if (ok == true) await store.allesLoeschen();
            },
            child: const Row(
              children: [
                Icon(Icons.delete_forever_outlined, color: PT.rot),
                SizedBox(width: 12),
                Text('Alle Daten löschen',
                    style: TextStyle(color: PT.rot, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Papiertiger 1.0 · Der Papiertiger erklärt Schreiben und hilft beim Organisieren. '
            'Er ersetzt keine Rechts-, Steuer- oder Sozialberatung.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PT.grau, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
