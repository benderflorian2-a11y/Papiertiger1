import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/store.dart';
import 'onboarding.dart';
import 'shell.dart';
import 'theme.dart';

/// Macht den Datenspeicher überall in der App erreichbar.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class PapiertigerApp extends StatelessWidget {
  const PapiertigerApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Papiertiger',
        debugShowCheckedModeBanner: false,
        theme: papiertigerTheme(),
        locale: const Locale('de', 'DE'),
        supportedLocales: const [Locale('de', 'DE')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Große Schrift (Mehr → Große Schrift): alles 25 % größer, zusätzlich zur Systemeinstellung
        builder: (context, child) {
          final gross = StoreScope.of(context).grossschrift;
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: gross ? mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * 1.25)) : mq,
            child: child!,
          );
        },
        home: const _Start(),
      ),
    );
  }
}

class _Start extends StatelessWidget {
  const _Start();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return store.onboardingFertig ? const Shell() : const Onboarding();
  }
}
