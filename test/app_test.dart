import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/store.dart';
import 'package:papiertiger/logic/benachrichtigungen.dart';
import 'package:papiertiger/logic/ki.dart';
import 'package:papiertiger/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _neuerStore({bool onboardingFertig = false}) async {
  SharedPreferences.setMockInitialValues(
      onboardingFertig ? {'onboardingFertig': true} : <String, Object>{});
  return AppStore.oeffnen();
}

void main() {
  Ki.deaktiviert = true;
  Benachrichtigungen.deaktiviert = true;
  testWidgets('Onboarding führt zum Startbildschirm', (tester) async {
    final store = await _neuerStore();
    await tester.pumpWidget(PapiertigerApp(store: store));
    expect(find.text('Keine Angst vor Post.'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-weiter')));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField), 'Florian Muster');
    await tester.tap(find.byKey(const ValueKey('onboarding-weiter')));
    await tester.pumpAndSettle();

    expect(find.text('Hallo Florian!'), findsOneWidget);
    expect(find.text('Neuer Brief?'), findsOneWidget);
    expect(store.profil.name, 'Florian Muster');
  });

  testWidgets('Eingefügter Brief wird erklärt und gespeichert', (tester) async {
    final store = await _neuerStore(onboardingFertig: true);
    await tester.pumpWidget(PapiertigerApp(store: store));

    await tester.tap(find.byKey(const ValueKey('text-einfuegen-start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('text-einfuegen')),
        'Finanzamt Musterstadt\nSteuerbescheid\nNachzahlung: 120,00 €\nzahlbar bis zum 01.12.2099');
    await tester.tap(find.byKey(const ValueKey('text-auswerten')));
    await tester.pumpAndSettle();

    expect(find.text('Einfach erklärt'), findsOneWidget);
    expect(store.briefe.length, 1);
    expect(store.briefe.first.kategorie, 'finanzamt');
  });

  testWidgets('Alle Tabs lassen sich öffnen', (tester) async {
    final store = await _neuerStore(onboardingFertig: true);
    await tester.pumpWidget(PapiertigerApp(store: store));

    for (final tab in ['Fristen', 'Archiv', 'Mehr', 'Start']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Neuer Brief?'), findsOneWidget);
  });
}
