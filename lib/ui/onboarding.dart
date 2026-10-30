import 'package:flutter/material.dart';

import '../logic/benachrichtigungen.dart';
import '../logic/lebenslage.dart';
import 'app.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/tiger.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _seiten = PageController();
  final _name = TextEditingController();
  int _index = 0;
  final Set<String> _lagen = {};

  static const _inhalte = [
    (
      titel: 'Keine Angst vor Post.',
      text:
          'Fotografiere einen Brief, und der Papiertiger erklärt dir in einfachen Worten, worum es geht.',
      icon: Icons.mail_outline,
    ),
    (
      titel: 'Nie wieder eine Frist verpassen.',
      text:
          'Fristen, Beträge und Aufgaben werden automatisch erkannt und übersichtlich gesammelt.',
      icon: Icons.event_available_outlined,
    ),
    (
      titel: 'Deine Daten bleiben bei dir.',
      text:
          'Texterkennung und Speicherung passieren direkt auf deinem Handy. Nichts wird ins Internet geschickt.',
      icon: Icons.lock_outline,
    ),
  ];

  @override
  void dispose() {
    _seiten.dispose();
    _name.dispose();
    super.dispose();
  }

  void _weiter() {
    if (_index < _inhalte.length) {
      _seiten.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      final store = StoreScope.of(context);
      store.lebenslagenSetzen(_lagen);
      store.onboardingAbschliessen(_name.text);
      Benachrichtigungen.erlaubnisAnfragen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final letzte = _index == _inhalte.length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _seiten,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final s in _inhalte)
                    _Seite(
                      kopf: s == _inhalte.first
                          ? const Tiger(size: 160)
                          : _IconKreis(s.icon),
                      titel: s.titel,
                      text: s.text,
                    ),
                  _NameSeite(
                    controller: _name,
                    lagen: _lagen,
                    umschalten: (l) => setState(() => _lagen.contains(l) ? _lagen.remove(l) : _lagen.add(l)),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i <= _inhalte.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? PT.orange : PT.sand,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('onboarding-weiter'),
                  onPressed: _weiter,
                  child: Text(letzte ? 'Los geht\'s' : 'Weiter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seite extends StatelessWidget {
  const _Seite({required this.kopf, required this.titel, required this.text});

  final Widget kopf;
  final String titel;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          kopf,
          const SizedBox(height: 40),
          Text(titel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: PT.tinte)),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.45, color: PT.grau)),
        ],
      ),
    );
  }
}

class _IconKreis extends StatelessWidget {
  const _IconKreis(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: const BoxDecoration(color: PT.orangeHell, shape: BoxShape.circle),
      child: Icon(icon, size: 72, color: PT.orangeDunkel),
    );
  }
}

class _NameSeite extends StatelessWidget {
  const _NameSeite({
    required this.controller,
    required this.lagen,
    required this.umschalten,
  });

  final TextEditingController controller;
  final Set<String> lagen;
  final void Function(String lage) umschalten;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          const Tiger(size: 120),
          const SizedBox(height: 32),
          const Text('Wie heißt du?',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: PT.tinte)),
          const SizedBox(height: 12),
          const Text(
            'Dein Name kommt in deine Antwort-Briefe. Du kannst ihn auch später eintragen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.45, color: PT.grau),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: feld(hintText: 'Vor- und Nachname'),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Was passt zu dir? (mehreres möglich)',
                style: TextStyle(fontWeight: FontWeight.w700, color: PT.tinte)),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in lebenslagen)
              FilterChip(
                label: Text(l.titel),
                tooltip: l.text,
                selected: lagen.contains(l.key),
                onSelected: (_) => umschalten(l.key),
              ),
          ]),
          const SizedBox(height: 8),
          const Text('Der Tiger zeigt dann nur, was zu dir passt. Nichts gewählt = alles sichtbar.',
              style: TextStyle(color: PT.grau, fontSize: 12)),
          const Text('Lässt sich jederzeit unter „Mehr“ ändern.', style: TextStyle(color: PT.grau, fontSize: 12)),
        ],
      ),
    );
  }
}
