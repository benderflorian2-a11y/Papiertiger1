import 'package:flutter/material.dart';

import '../../logic/steuer.dart';
import '../../logic/steuer_hilfe.dart';
import '../app.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'steuer.dart' show werbungskostenFuer;

/// Kleiner Steuer-Berater: schätzt Steuer und Ersparnis und gibt Tipps aus den gesammelten Belegen.
class SteuerBeraterScreen extends StatefulWidget {
  const SteuerBeraterScreen({super.key, required this.jahr});

  final int jahr;

  @override
  State<SteuerBeraterScreen> createState() => _SteuerBeraterState();
}

class _SteuerBeraterState extends State<SteuerBeraterScreen> {
  final _betrag = TextEditingController();
  bool _selbst = false;
  bool _geladen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_geladen) return;
    _geladen = true;
    final n = StoreScope.of(context).notizen;
    _selbst = n['steuer:berater:modus'] == 'selbst';
    _betrag.text = n[_schluessel] ?? '';
  }

  String get _schluessel => _selbst ? 'steuer:berater:gewinn' : 'steuer:berater:brutto';

  @override
  void dispose() {
    _betrag.dispose();
    super.dispose();
  }

  void _speichern() {
    final store = StoreScope.of(context);
    store.notizen[_schluessel] = _betrag.text.trim();
    store.notizen['steuer:berater:modus'] = _selbst ? 'selbst' : 'angestellt';
    store.geaendert();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final posten = steuerPosten(jahr: widget.jahr, briefe: store.briefe, belege: store.belege, vertraege: store.vertraege);
    final summen = summenNachKategorie(posten);
    final werbung = werbungskostenFuer(widget.jahr, store.notizen, posten);
    final eingabe = zahlAusText(_betrag.text);
    final zvE = eingabe == null ? null : (_selbst ? (eingabe * 0.90 - 36).clamp(0.0, double.infinity) : zveAusBrutto(eingabe));
    final steuer = zvE == null ? null : einkommensteuer(zvE);
    final grenz = zvE == null ? null : grenzsteuersatz(zvE);
    final tipps = steuerTipps(zvE: zvE ?? 0, werbung: werbung, summen: summen, selbststaendig: _selbst);

    return Scaffold(
      appBar: AppBar(title: const Text('Steuer-Berater')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('Angestellt'),
              selected: !_selbst,
              onSelected: (_) => setState(() {
                _selbst = false;
                _betrag.text = store.notizen['steuer:berater:brutto'] ?? '';
                _speichern();
              }),
            ),
            ChoiceChip(
              label: const Text('Selbstständig / Gewerbe'),
              selected: _selbst,
              onSelected: (_) => setState(() {
                _selbst = true;
                _betrag.text = store.notizen['steuer:berater:gewinn'] ?? '';
                _speichern();
              }),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _betrag,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: feld(
              labelText: _selbst ? 'Gewinn im Jahr (Einnahmen minus Ausgaben)' : 'Bruttogehalt im Jahr',
              suffixText: '€',
              hintText: _selbst ? 'z. B. 35000' : 'z. B. 42000',
            ),
            onChanged: (_) {
              setState(() {});
              _speichern();
            },
          ),
          const SizedBox(height: 12),
          if (steuer == null)
            const PTKarte(
              farbe: PT.orangeHell,
              child: Text('Gib oben einen Betrag ein. Dann schätzt der Tiger deine Steuer und zeigt, was dir Abzüge bringen.'),
            )
          else ...[
            PTKarte(
              farbe: PT.orangeHell,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Geschätzte Einkommensteuer', style: TextStyle(color: PT.grau)),
                Text('${euroGlatt(steuer)} im Jahr', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Für jeden Euro, den du absetzen kannst, sparst du etwa ${grenz!.round()} Cent. '
                  'Eine Ausgabe von 100 € bringt dir also ungefähr ${euroGlatt(grenz)} zurück.',
                  style: const TextStyle(height: 1.4),
                ),
                if (_selbst) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Lege mindestens ${euroGlatt(steuer)} (${eingabe! > 0 ? (steuer / eingabe * 100).round() : 0} % vom Gewinn) für die Einkommensteuer beiseite. '
                    'Dazu kommen Kranken- und Pflegeversicherung, Rente und gegebenenfalls Gewerbe- und Umsatzsteuer.',
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ]),
            ),
          ],
          const Abschnitt('Tipps für dich'),
          for (final t in tipps)
            PTKarte(
              farbe: t.wichtig ? PT.gruenHell : Colors.white,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(t.text, style: const TextStyle(height: 1.4)),
                if (t.ersparnis != null && t.ersparnis! >= 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Geschätzte Ersparnis: ca. ${euroGlatt(t.ersparnis!)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: PT.gruen)),
                  ),
              ]),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => AbsetzenScreen(jahr: widget.jahr, selbststaendig: _selbst))),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Was kann ich alles absetzen?'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Grobe Schätzung nach dem Einkommensteuertarif 2026 (ohne Solidaritätszuschlag und Kirchensteuer). '
            'Deine echte Steuer hängt von Familienstand, Kindern, Krankenkasse und weiteren Dingen ab. '
            'Keine Steuerberatung, ohne Gewähr. Bei Fragen helfen Steuerberater oder ein Lohnsteuerhilfeverein.',
            style: TextStyle(color: PT.grau, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Katalog: Was kann ein Normalverbraucher, was ein Selbstständiger absetzen?
class AbsetzenScreen extends StatefulWidget {
  const AbsetzenScreen({super.key, required this.jahr, this.selbststaendig = false});

  final int jahr;
  final bool selbststaendig;

  @override
  State<AbsetzenScreen> createState() => _AbsetzenState();
}

class _AbsetzenState extends State<AbsetzenScreen> {
  late bool _selbst = widget.selbststaendig;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final posten = steuerPosten(jahr: widget.jahr, briefe: store.briefe, belege: store.belege, vertraege: store.vertraege);
    final summen = summenNachKategorie(posten);
    final liste = _selbst ? absetzenGewerbe : absetzenPrivat;
    return Scaffold(
      appBar: AppBar(title: const Text('Was kann ich absetzen?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Privat / Angestellt'), selected: !_selbst, onSelected: (_) => setState(() => _selbst = false)),
            ChoiceChip(label: const Text('Selbstständig / Gewerbe'), selected: _selbst, onSelected: (_) => setState(() => _selbst = true)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Absetzen heißt: Du gibst Kosten in der Steuererklärung an, und das Finanzamt rechnet sie dir zu Gute. '
            'Foto vom Beleg im Papiertiger machen und „Für die Steuer“ markieren – der Rest sammelt sich von selbst.',
            style: TextStyle(color: PT.grau, height: 1.4),
          ),
          const SizedBox(height: 8),
          for (final p in liste)
            PTKarte(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(p.titel, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(p.kurz),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.details, style: const TextStyle(height: 1.45)),
                  if (p.wo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Steht in der Steuererklärung: ${p.wo}', style: const TextStyle(color: PT.grau, fontSize: 12)),
                    ),
                  if (p.kategorie != null && (summen[p.kategorie] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Bei dir gesammelt (${widget.jahr}): ${euroGlatt(summen[p.kategorie]!)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: PT.gruen)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text('Stand 2026, allgemeine Hinweise ohne Gewähr. Keine Steuerberatung.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}
