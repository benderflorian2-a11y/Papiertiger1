import 'package:flutter/material.dart';

import '../../data/familie.dart';
import '../../data/models.dart';
import '../../logic/android_kanal.dart';
import '../../logic/export.dart';
import '../../logic/familie.dart';
import '../../logic/ordnung.dart';
import '../app.dart';
import '../brief_detail.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<String?> _eingabe(BuildContext context, String titel, {String start = '', String? hint, int zeilen = 1}) async {
  final c = TextEditingController(text: start);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titel),
      content: TextField(
          controller: c, autofocus: true, minLines: zeilen, maxLines: zeilen == 1 ? 1 : 8, decoration: feld(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('OK')),
      ],
    ),
  );
  final t = c.text.trim();
  c.dispose();
  return ok == true ? t : null;
}

// ---------------------------------------------------------------- Kinder

class KinderScreen extends StatelessWidget {
  const KinderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final heute = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Kinder')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _eingabe(context, 'Name des Kindes');
          if (name == null || name.isEmpty || !context.mounted) return;
          final geb = await datumWaehlen(context, start: DateTime(heute.year - 3));
          final k = Kind(id: neueId(), name: name, geburt: geb);
          store.familie.kinder.add(k);
          await store.geaendert();
          if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => KindDetail(kindId: k.id)));
        },
        icon: const Icon(Icons.add),
        label: const Text('Kind'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
        if (store.familie.kinder.isEmpty)
          const LeerHinweis(
            icon: Icons.child_care,
            text: 'Untersuchungen beim Kinderarzt, Kita und Schule, Kindergeld und alle Dokumente – je Kind an einem Ort.',
          ),
        for (final k in store.familie.kinder)
          PTKarte(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => KindDetail(kindId: k.id))),
            child: Row(children: [
              const IconKachel(Icons.child_care),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(k.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(
                    [
                      if (k.geburt != null) '${alterInJahren(k.geburt!, heute)} Jahre',
                      if (k.einrichtung.isNotEmpty) k.einrichtung,
                      if (naechsteUntersuchung(k, heute: heute) != null) 'nächste: ${naechsteUntersuchung(k, heute: heute)!.$1}',
                    ].join(' · '),
                    style: const TextStyle(color: PT.grau, fontSize: 13),
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right, color: PT.grau),
            ]),
          ),
      ]),
    );
  }
}

class KindDetail extends StatelessWidget {
  const KindDetail({super.key, required this.kindId});

  final String kindId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final k = store.familie.kinder.where((x) => x.id == kindId).firstOrNull;
    if (k == null) return Scaffold(appBar: AppBar(), body: const LeerHinweis(icon: Icons.child_care, text: 'Gelöscht.'));
    final heute = DateTime.now();
    final hinweise = kindHinweise(k, heute: heute);
    final doks = store.briefe.where((b) => k.briefIds.contains(b.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(k.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.of(context).pop();
              store.familie.kinder.remove(k);
              store.geaendert();
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final h in hinweise) PTKarte(farbe: PT.orangeHell, child: Text(h)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Geburtstag'),
          subtitle: Text(k.geburt == null ? 'eintragen' : datumLang(k.geburt!)),
          onTap: () async {
            final d = await datumWaehlen(context, start: k.geburt);
            if (d == null) return;
            k.geburt = d;
            await store.geaendert();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kita / Schule'),
          subtitle: Text(k.einrichtung.isEmpty ? 'eintragen' : k.einrichtung),
          onTap: () async {
            final t = await _eingabe(context, 'Kita bzw. Schule und Klasse', start: k.einrichtung);
            if (t == null) return;
            k.einrichtung = t;
            await store.geaendert();
          },
        ),
        if (k.geburt != null) ...[
          const Abschnitt('Vorsorgeuntersuchungen'),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final u in uUntersuchungen)
                CheckboxListTile(
                  dense: true,
                  value: k.erledigt.contains(u.name),
                  title: Text('${u.name} · ${u.zeitraum}'),
                  subtitle: Text(
                      '${datumKurz(k.geburt!.add(u.von(k.geburt!)))} – ${datumKurz(k.geburt!.add(u.bis(k.geburt!)))}'),
                  onChanged: (v) {
                    v == true ? k.erledigt.add(u.name) : k.erledigt.remove(u.name);
                    store.geaendert();
                  },
                ),
            ]),
          ),
          TextButton.icon(
            onPressed: () async {
              final u = naechsteUntersuchung(k, heute: heute);
              if (u == null) return;
              final id = 'u-${k.id}-${u.$1}';
              store.termine.removeWhere((t) => t.id == id);
              await store.terminSpeichern(
                  Termin(id: id, titel: '${u.$1} für ${k.name} (Kinderarzt)', datum: u.$2, art: 'Arzt', person: k.name));
              if (context.mounted) zeigeHinweis(context, 'Erinnerung für die ${u.$1} eingetragen');
            },
            icon: const Icon(Icons.alarm_add),
            label: const Text('An die nächste Untersuchung erinnern'),
          ),
        ],
        const Abschnitt('Dokumente'),
        for (final b in doks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, color: PT.orangeDunkel),
            title: Text(titelVon(b)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BriefDetail(briefId: b.id))),
          ),
        TextButton.icon(
          onPressed: () async {
            final kand = store.briefe.where((b) => !k.briefIds.contains(b.id)).take(60).toList();
            final id = await showDialog<String>(
              context: context,
              builder: (d) => SimpleDialog(title: const Text('Dokument zuordnen'), children: [
                for (final b in kand) SimpleDialogOption(onPressed: () => Navigator.pop(d, b.id), child: Text(titelVon(b))),
              ]),
            );
            if (id == null) return;
            k.briefIds.add(id);
            final b = store.briefe.where((x) => x.id == id).firstOrNull;
            b?.person ??= k.name;
            await store.geaendert();
          },
          icon: const Icon(Icons.attach_file),
          label: const Text('Geburtsurkunde, Impfpass, Zeugnis … zuordnen'),
        ),
        const Text('Die U-Untersuchungen bezahlt die Krankenkasse. Zeiträume laut Kinder-Untersuchungsheft – '
            'im Zweifel fragt die Kinderarztpraxis.',
            style: TextStyle(color: PT.grau, fontSize: 12)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Vorsorgemappe

class VorsorgeScreen extends StatelessWidget {
  const VorsorgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.familie.vorsorge;
    final stand = vorsorgeStand(v);
    Future<void> feldSetzen(String titel, String start, void Function(String) setzen, {int zeilen = 1}) async {
      final t = await _eingabe(context, titel, start: start, zeilen: zeilen);
      if (t == null) return;
      setzen(t);
      await store.geaendert();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vorsorgemappe'),
        actions: [
          IconButton(
            tooltip: 'Notfallblatt teilen',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final d = await antwortAlsPdf(notfallblattText(v, store.profil), titel: 'Notfallblatt');
              await dateiTeilen(d.path, mimeType: 'application/pdf', text: notfallblattText(v, store.profil));
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PTKarte(
          farbe: stand >= 1 ? PT.gruenHell : PT.orangeHell,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${(stand * 100).round()} % ausgefüllt', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: stand),
            const SizedBox(height: 6),
            const Text('Damit deine Angehörigen im Notfall wissen, wen sie anrufen und wo die wichtigen Papiere liegen. '
                'Teile das Notfallblatt (oben rechts) mit einer Vertrauensperson.'),
          ]),
        ),
        const Abschnitt('Im Notfall anrufen'),
        for (final k in v.kontakte)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline, color: PT.orangeDunkel),
            title: Text('${k.name}${k.beziehung.isEmpty ? '' : ' (${k.beziehung})'}'),
            subtitle: Text(k.telefon),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (k.telefon.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => AndroidKanal.oeffnen(Uri.parse('tel:${k.telefon.replaceAll(' ', '')}')),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  v.kontakte.remove(k);
                  store.geaendert();
                },
              ),
            ]),
          ),
        TextButton.icon(
          onPressed: () async {
            final name = await _eingabe(context, 'Name');
            if (name == null || name.isEmpty || !context.mounted) return;
            final tel = await _eingabe(context, 'Telefon');
            if (!context.mounted) return;
            final bez = await _eingabe(context, 'Beziehung (optional)', hint: 'z. B. Tochter, Nachbar');
            v.kontakte.add(Notfallkontakt(name: name, telefon: tel ?? '', beziehung: bez ?? ''));
            await store.geaendert();
          },
          icon: const Icon(Icons.add),
          label: const Text('Kontakt hinzufügen'),
        ),
        const Abschnitt('Gesundheit'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hausarzt'),
          subtitle: Text(v.hausarzt.isEmpty ? 'Name, Telefon' : v.hausarzt),
          onTap: () => feldSetzen('Hausarzt', v.hausarzt, (t) => v.hausarzt = t),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Medikamente'),
          subtitle: Text(v.medikamente.isEmpty ? 'regelmäßig eingenommen' : v.medikamente),
          onTap: () => feldSetzen('Medikamente', v.medikamente, (t) => v.medikamente = t, zeilen: 3),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allergien und Unverträglichkeiten'),
          subtitle: Text(v.allergien.isEmpty ? 'eintragen' : v.allergien),
          onTap: () => feldSetzen('Allergien', v.allergien, (t) => v.allergien = t, zeilen: 2),
        ),
        const Abschnitt('Wo liegt was?'),
        for (final d in vorsorgeDokumente)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon((v.ablage[d] ?? '').isEmpty ? Icons.radio_button_unchecked : Icons.check_circle, color: PT.gruen),
            title: Text(d),
            subtitle: Text((v.ablage[d] ?? '').isEmpty ? 'tippen: wo liegt es?' : v.ablage[d]!),
            onTap: () => feldSetzen(d, v.ablage[d] ?? '', (t) => t.isEmpty ? v.ablage.remove(d) : v.ablage[d] = t,
                zeilen: 2),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Weitere Hinweise für Angehörige'),
          subtitle: Text(v.hinweise.isEmpty ? 'z. B. Schlüssel, Haustiere, wo die Passwörter liegen' : v.hinweise),
          onTap: () => feldSetzen('Hinweise', v.hinweise, (t) => v.hinweise = t, zeilen: 4),
        ),
        const Text(
          'Patientenverfügung und Vorsorgevollmacht: Vorlagen gibt es kostenlos beim Bundesjustizministerium. '
          'Bei Fragen helfen Hausarzt, Notar oder Betreuungsverein. Allgemeine Hinweise, keine Rechtsberatung.',
          style: TextStyle(color: PT.grau, fontSize: 12),
        ),
      ]),
    );
  }
}
