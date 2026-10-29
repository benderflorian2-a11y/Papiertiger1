import 'package:flutter/material.dart';

import '../data/models.dart';
import '../logic/datum.dart';
import '../logic/zeitplan.dart';
import 'app.dart';
import 'kalender.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Termin anlegen oder bearbeiten (TÜV, Wartung, Versicherung …).
class TerminFormular extends StatefulWidget {
  const TerminFormular({super.key, this.terminId, this.vorlage});

  final String? terminId;

  /// Vorbelegung für neue Termine, z. B. aus einem Brief.
  final Termin? vorlage;

  @override
  State<TerminFormular> createState() => _TerminFormularState();
}

class _TerminFormularState extends State<TerminFormular> {
  Termin? _termin;
  final _titel = TextEditingController();
  final _notiz = TextEditingController();
  DateTime _datum = DateTime.now().add(const Duration(days: 7));
  int _wiederholung = 0;
  String _art = terminArten.last;
  bool _mitUhrzeit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_termin != null) return;
    final store = StoreScope.of(context);
    final vorhanden = widget.terminId == null
        ? null
        : store.termine.where((t) => t.id == widget.terminId).firstOrNull;
    final t = vorhanden ?? widget.vorlage ?? Termin(id: neueId(), titel: '', datum: _datum);
    _termin = t;
    _titel.text = t.titel;
    _notiz.text = t.notiz;
    _datum = t.datum;
    _wiederholung = t.wiederholungMonate;
    _art = terminArten.contains(t.art) ? t.art : terminArten.last;
    _mitUhrzeit = t.datum.hour != 0 || t.datum.minute != 0;
  }

  @override
  void dispose() {
    _titel.dispose();
    _notiz.dispose();
    super.dispose();
  }

  bool get _neu => !StoreScope.of(context).termine.any((t) => t.id == _termin!.id);

  Future<void> _speichern() async {
    if (_titel.text.trim().isEmpty) {
      zeigeHinweis(context, 'Bitte einen Titel eintragen.');
      return;
    }
    final t = _termin!
      ..titel = _titel.text.trim()
      ..notiz = _notiz.text.trim()
      ..datum = _datum
      ..wiederholungMonate = _wiederholung
      ..art = _art;
    await StoreScope.of(context).terminSpeichern(t);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = _termin!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_neu ? 'Neuer Termin' : 'Termin'),
        actions: [
          if (!_neu)
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                Navigator.of(context).pop();
                store.terminLoeschen(t);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _titel, decoration: feld(labelText: 'Titel', hintText: 'z. B. TÜV Golf')),
          const SizedBox(height: 16),
          const Text('Art', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in terminArten)
              ChoiceChip(label: Text(a), selected: _art == a, onSelected: (_) => setState(() {
                    _art = a;
                    if (a == 'TÜV / Auto' && _wiederholung == 0) _wiederholung = 24;
                    if ((a == 'Wartung' || a == 'Versicherung') && _wiederholung == 0) _wiederholung = 12;
                  })),
          ]),
          const SizedBox(height: 16),
          PTKarte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Datum'),
                  subtitle: Text(datumLang(_datum)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final d = await datumWaehlen(context, start: _datum);
                    if (d != null) setState(() => _datum = DateTime(d.year, d.month, d.day, _datum.hour, _datum.minute));
                  },
                ),
                SwitchListTile(
                  title: const Text('Mit Uhrzeit'),
                  value: _mitUhrzeit,
                  onChanged: (v) async {
                    if (!v) {
                      setState(() {
                        _mitUhrzeit = false;
                        _datum = DateTime(_datum.year, _datum.month, _datum.day);
                      });
                      return;
                    }
                    final zeit = await showTimePicker(
                        context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
                    if (zeit != null) {
                      setState(() {
                        _mitUhrzeit = true;
                        _datum = DateTime(_datum.year, _datum.month, _datum.day, zeit.hour, zeit.minute);
                      });
                    }
                  },
                ),
                if (_mitUhrzeit)
                  ListTile(
                    title: const Text('Uhrzeit'),
                    subtitle: Text(
                        '${_datum.hour.toString().padLeft(2, '0')}:${_datum.minute.toString().padLeft(2, '0')} Uhr'),
                  ),
              ],
            ),
          ),
          const Text('Wiederholen', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (m, label) in const [
              (0, 'Einmalig'),
              (1, 'Monatlich'),
              (3, 'Vierteljährlich'),
              (12, 'Jährlich'),
              (24, 'Alle 2 Jahre')
            ])
              ChoiceChip(
                  label: Text(label),
                  selected: _wiederholung == m,
                  onSelected: (_) => setState(() => _wiederholung = m)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _notiz, minLines: 2, maxLines: 4, decoration: feld(labelText: 'Notiz (optional)')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => inKalender(context, _titel.text.isEmpty ? 'Termin' : _titel.text,
                naechstesTermindatum(Termin(id: 'x', titel: '', datum: _datum, wiederholungMonate: _wiederholung)),
                beschreibung: _notiz.text, mitUhrzeit: _mitUhrzeit),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('In Kalender eintragen'),
          ),
          if (!_neu && _wiederholung > 0) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final n = plusMonate(naechstesTermindatum(t), t.wiederholungMonate);
                t.datum = DateTime(n.year, n.month, n.day, t.datum.hour, t.datum.minute);
                await store.geaendert();
                if (context.mounted) {
                  zeigeHinweis(context, 'Erledigt. Nächster Termin: ${datumKurz(t.datum)}');
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Erledigt – nächsten Termin planen'),
            ),
          ] else if (!_neu) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                t.erledigt = true;
                await store.geaendert();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check),
              label: const Text('Erledigt'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _speichern, child: const Text('Speichern')),
        ),
      ),
    );
  }
}

/// Liste aller eigenen Termine.
class TermineListe extends StatelessWidget {
  const TermineListe({super.key});

  @override
  Widget build(BuildContext context) {
    final termine = [...StoreScope.of(context).termine.where((t) => !t.erledigt)]
      ..sort((a, b) => naechstesTermindatum(a).compareTo(naechstesTermindatum(b)));
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Termine')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TerminFormular())),
        icon: const Icon(Icons.add),
        label: const Text('Termin'),
      ),
      body: termine.isEmpty
          ? const LeerHinweis(
              icon: Icons.event_repeat_outlined,
              text: 'Trag wiederkehrende Termine ein: TÜV, Heizungswartung, Versicherungs-Verlängerung …')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                for (final t in termine)
                  PTKarte(
                    padding: const EdgeInsets.all(14),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => TerminFormular(terminId: t.id))),
                    child: Row(
                      children: [
                        const IconKachel(Icons.event_repeat_outlined),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                  '${t.art} · ${datumKurz(naechstesTermindatum(t))}'
                                  '${t.wiederholungMonate > 0 ? ' · alle ${t.wiederholungMonate} Monate' : ''}',
                                  style: const TextStyle(color: PT.grau, fontSize: 13)),
                            ],
                          ),
                        ),
                        FristEtikett(naechstesTermindatum(t)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
