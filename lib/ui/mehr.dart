import 'package:flutter/material.dart';

import 'app.dart';
import 'module/module_liste.dart';
import 'erinnerungen_einstellungen.dart';
import 'diktat.dart';
import 'kommunikation.dart';
import 'ki_einstellungen.dart';
import 'termine.dart';
import 'module/profil.dart';
import '../logic/lebenslage.dart';
import 'sicherheit.dart';
import 'sicherung.dart';
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
          const Abschnitt('Meine Lebenslage'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in lebenslagen)
              FilterChip(
                label: Text(l.titel),
                tooltip: l.text,
                selected: store.lebenslagen.contains(l.key),
                onSelected: (v) {
                  final neu = {...store.lebenslagen};
                  v ? neu.add(l.key) : neu.remove(l.key);
                  store.lebenslagenSetzen(neu);
                },
              ),
          ]),
          const SizedBox(height: 4),
          const Text('Der Tiger zeigt nur, was zu dir passt. Nichts gewählt = alles sichtbar.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
          const SizedBox(height: 8),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.translate, color: PT.orangeDunkel),
                title: const Text('Meine Sprache', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text((store.notizen['ansicht:sprache'] ?? '').isEmpty
                    ? 'Briefe nur auf Deutsch erklären'
                    : 'Briefe zusätzlich auf ${store.notizen['ansicht:sprache']} erklären'),
                onTap: () async {
                  final x = await showDialog<String>(
                    context: context,
                    builder: (d) => SimpleDialog(title: const Text('Erklärungen zusätzlich auf …'), children: [
                      for (final sp in const ['nur Deutsch', 'Englisch', 'Türkisch', 'Arabisch', 'Ukrainisch', 'Russisch', 'Polnisch', 'Rumänisch', 'Persisch'])
                        SimpleDialogOption(onPressed: () => Navigator.pop(d, sp), child: Text(sp)),
                    ]),
                  );
                  if (x == null) return;
                  if (x == 'nur Deutsch') {
                    store.notizen.remove('ansicht:sprache');
                  } else {
                    store.notizen['ansicht:sprache'] = x;
                  }
                  await store.geaendert();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.text_increase, color: PT.orangeDunkel),
                title: const Text('Große Schrift', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Alles größer und leichter zu lesen'),
                value: store.grossschrift,
                onChanged: (v) => store.checklistePunkt('ansicht:grossschrift', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.storefront_outlined, color: PT.orangeDunkel),
                title: const Text('Selbstständig', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Rechnungen, Kunden, Einnahmen, Marketing'),
                value: store.bereichAktiv('selbststaendig'),
                onChanged: (v) => store.checklistePunkt('bereich:selbststaendig', v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.home_outlined, color: PT.orangeDunkel),
                title: const Text('Haushalt', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Zählerstände, Inventar, Notfallmappe'),
                value: store.bereichAktiv('haushalt'),
                onChanged: (v) => store.checklistePunkt('bereich:haushalt', v),
              ),
            ]),
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
          PTKarte(
            padding: const EdgeInsets.all(12),
            onTap: () => oeffne(const DiktatScreen()),
            child: const Row(
              children: [
                IconKachel(Icons.mic),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diktieren', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Sprechen statt tippen – der Tiger macht einen Brief daraus',
                          style: TextStyle(color: PT.grau, fontSize: 13)),
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
          PTKarte(
            onTap: () => oeffne(const SicherheitScreen()),
            child: Row(children: [
              const IconKachel(Icons.shield_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sicherheit', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    [
                      if (store.verschluesselt) 'verschlüsselt',
                      sperreAn(store) ? 'App-Sperre an' : 'App-Sperre aus',
                      '${store.protokoll.length} Protokolleinträge',
                    ].join(' · '),
                    style: const TextStyle(color: PT.grau, fontSize: 13),
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right, color: PT.grau),
            ]),
          ),
          PTKarte(
            onTap: () => oeffne(const SicherungScreen()),
            child: Row(children: [
              const IconKachel(Icons.cloud_upload_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Datensicherung', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    letzteSicherung(store.notizen) == null
                        ? 'Noch nie gesichert – jetzt verschlüsselt sichern'
                        : 'Zuletzt ${datumKurz(letzteSicherung(store.notizen)!)}',
                    style: const TextStyle(color: PT.grau, fontSize: 13),
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right, color: PT.grau),
            ]),
          ),
          const PTKarte(
            child: Text(
              'Texterkennung, KI und Speicherung laufen nur auf deinem Handy. '
              'Briefe, Fotos und Angaben werden nicht ins Internet geschickt. '
              'Wenn du die App löschst, sind die Daten weg – außer du hast eine Datensicherung.',
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
