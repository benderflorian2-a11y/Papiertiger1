// Klicktest: tippt in jeder Kategorie jeden Knopf, jede Zeile und jeden Schalter einmal an
// (jeweils auf frischen Beispieldaten) und sammelt Abstürze und überlaufende Layouts.
// Ergebnis: build/klicktest.txt
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/store.dart';
import 'package:papiertiger/logic/android_kanal.dart';
import 'package:papiertiger/logic/benachrichtigungen.dart';
import 'package:papiertiger/logic/inhalte.dart';
import 'package:papiertiger/logic/ki.dart';
import 'package:papiertiger/ui/app.dart';
import 'package:papiertiger/ui/archiv.dart';
import 'package:papiertiger/ui/brief_detail.dart';
import 'package:papiertiger/ui/familie/familie.dart';
import 'package:papiertiger/ui/finanzen.dart';
import 'package:papiertiger/ui/fristen.dart';
import 'package:papiertiger/ui/geschaeft/geschaeft.dart';
import 'package:papiertiger/ui/geschaeft/katalog.dart';
import 'package:papiertiger/ui/geschaeft/plantafel.dart';
import 'package:papiertiger/ui/geschaeft/projekte.dart';
import 'package:papiertiger/ui/geschaeft/stempeluhr.dart';
import 'package:papiertiger/ui/haushalt/alltag.dart';
import 'package:papiertiger/ui/haushalt/haushalt.dart';
import 'package:papiertiger/ui/karriere/karriere.dart';
import 'package:papiertiger/ui/kontoauszug.dart';
import 'package:papiertiger/ui/mehr.dart';
import 'package:papiertiger/ui/module/angebote_vergleichen.dart';
import 'package:papiertiger/ui/module/antraege.dart';
import 'package:papiertiger/ui/module/behoerdengaenge.dart';
import 'package:papiertiger/ui/module/belege.dart';
import 'package:papiertiger/ui/module/ereignisse.dart';
import 'package:papiertiger/ui/module/leistungen.dart';
import 'package:papiertiger/ui/module/steuer.dart';
import 'package:papiertiger/ui/module/vertraege.dart';
import 'package:papiertiger/ui/shell.dart';
import 'package:papiertiger/ui/sicherheit.dart';
import 'package:papiertiger/ui/theme.dart';
import 'package:papiertiger/ui/vermietung/vermietung.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hilfe/beispieldaten.dart';

final _bericht = <String>[];
final _fehler = <String>[];

/// Fehler, die nur im Test entstehen (es gibt dort kein Android).
bool _nurTestumgebung(String e) =>
    e.contains('MissingPluginException') ||
    e.contains('No implementation found') ||
    e.contains('channel-error') ||
    e.contains('PlatformException') ||
    e.contains('Unable to establish connection on channel');

final _kategorien = <String, Map<String, Widget Function()>>{
  'Post & Dokumente': {
    'Start': () => const Shell(),
    'Archiv': () => const ArchivScreen(),
    'Fristen': () => const FristenScreen(),
    'Brief Steuerbescheid': () => const BriefDetail(briefId: 'b1'),
    'Brief Angebot': () => const BriefDetail(briefId: 'b2'),
    'Angebote vergleichen': () => const AngeboteVergleichenScreen(vorauswahl: 'b2'),
  },
  'Finanzen & Verträge': {
    'Finanzen': () => const FinanzenScreen(),
    'Kontoauszug': () => const KontoauszugScreen(),
    'Verträge': () => const VertraegeScreen(),
    'Vertrag Detail': () => const VertragDetail(vertragId: 'v1'),
    'Belege': () => const BelegeScreen(),
  },
  'Steuer & Behörden': {
    'Steuer': () => const SteuerScreen(),
    'Leistungen': () => const LeistungenScreen(),
    'Anträge': () => const AntraegeScreen(),
    'Antrag Kindergeld': () => AntragScreen(antrag: antraege.first),
    'Lebens-Ereignisse': () => const EreignisseScreen(),
    'Behördengänge': () => const BehoerdengaengeScreen(),
  },
  'Gewerbe': {
    'Gewerbe': () => const GeschaeftScreen(),
    'Rechnung': () => const RechnungDetail(rechnungId: 'r1'),
    'Angebot': () => const RechnungDetail(rechnungId: 'a1'),
    'Angebot neu': () => const RechnungFormular(art: 'angebot'),
    'Kunden': () => const KundenScreen(),
    'Firma': () => const FirmaScreen(),
    'EÜR': () => const EuerScreen(),
    'Katalog': () => const KatalogScreen(),
    'Projekte': () => const ProjekteScreen(),
    'Projekt': () => const ProjektDetail(projektId: 'p1'),
    'Plantafel': () => const PlantafelScreen(),
    'Stempeluhr': () => const StempeluhrScreen(),
    'Zahlungseingänge': () => const ZahlungseingaengeScreen(),
  },
  'Haushalt & Familie': {
    'Haushalt': () => const HaushaltScreen(),
    'Einkauf': () => const EinkaufScreen(),
    'Vorräte': () => const VorraeteScreen(),
    'Essensplan': () => const EssensplanScreen(),
    'Haushaltsaufgaben': () => const HausaufgabenScreen(),
    'Geschenke': () => const GeschenkeScreen(),
    'Reisen': () => const ReisenScreen(),
    'Reise': () => const ReiseDetail(reiseId: 'reise1'),
    'Zähler': () => const ZaehlerDetail(zaehlerId: 'z1'),
    'Inventar': () => const InventarScreen(),
    'Notfallmappe': () => const NotfallScreen(),
    'Kinder': () => const KinderScreen(),
    'Kind': () => const KindDetail(kindId: 'kind1'),
    'Vorsorgemappe': () => const VorsorgeScreen(),
  },
  'Karriere & Vermietung': {
    'Karriere': () => const KarriereScreen(),
    'Lebenslauf': () => const LebenslaufScreen(),
    'Bewerbung': () => const BewerbungDetail(bewerbungId: 'bw1'),
    'Weiterbildung': () => const WeiterbildungScreen(),
    'Vermietung': () => const VermietungScreen(),
    'Mieter': () => const MieterScreen(mieterId: 'm1'),
    'Nebenkosten': () => const NebenkostenScreen(objektId: 'o1', jahr: 2025),
  },
  'Einstellungen': {
    'Mehr': () => const MehrScreen(),
    'Sicherheit': () => const SicherheitScreen(),
  },
};

Widget _app(AppStore store, Widget seite) => StoreScope(
      store: store,
      child: MaterialApp(
        key: UniqueKey(),
        theme: papiertigerTheme(),
        locale: const Locale('de', 'DE'),
        supportedLocales: const [Locale('de', 'DE')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: seite,
      ),
    );

Future<void> _ruhe(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

/// Alles, was man antippen kann und gerade sichtbar ist.
List<Element> _tippbar() => find
    .byWidgetPredicate((w) => w is InkResponse && w.onTap != null)
    .evaluate()
    .toList();

String _beschriftung(Element e) {
  final texte = <String>[];
  void sammeln(Element x) {
    final w = x.widget;
    if (w is Text && w.data != null) texte.add(w.data!);
    if (w is Tooltip && w.message != null) texte.add(w.message!);
    if (w is Icon && w.icon != null) texte.add('Symbol ${w.icon!.codePoint.toRadixString(16)}');
    if (texte.length < 2) x.visitChildren(sammeln);
  }

  sammeln(e);
  return texte.isEmpty ? 'ohne Beschriftung' : texte.take(2).join(' / ');
}

void _fehlerNehmen(WidgetTester t, String wo) {
  for (var i = 0; i < 10; i++) {
    final e = t.takeException();
    if (e == null) return;
    final text = '$e';
    if (_nurTestumgebung(text)) continue;
    _fehler.add('$wo: ${text.split('\n').take(4).join(' | ')}');
  }
}

Future<void> _kategoriePruefen(WidgetTester t, String kategorie, Map<String, Widget Function()> seiten) async {
  t.view.devicePixelRatio = 1.5;
  t.view.physicalSize = const Size(411 * 1.5, 2400 * 1.5);
  addTearDown(t.view.reset);
  var getippt = 0;
  for (final s in seiten.entries) {
    SharedPreferences.setMockInitialValues(beispielDaten());
    var store = AppStore(await SharedPreferences.getInstance());
    await t.pumpWidget(_app(store, s.value()));
    await _ruhe(t);
    _fehlerNehmen(t, '$kategorie › ${s.key} (Öffnen)');
    final anzahl = _tippbar().length.clamp(0, 40);
    for (var i = 0; i < anzahl; i++) {
      // Jedes Antippen auf frischen Daten, damit Löschen & Co. die nächsten Schritte nicht verfälschen
      SharedPreferences.setMockInitialValues(beispielDaten());
      store = AppStore(await SharedPreferences.getInstance());
      await t.pumpWidget(_app(store, s.value()));
      await _ruhe(t);
      while (t.takeException() != null) {}
      final liste = _tippbar();
      if (i >= liste.length) break;
      final ziel = liste[i];
      final name = _beschriftung(ziel);
      try {
        final box = ziel.renderObject;
        if (box is RenderBox && box.hasSize && box.attached) {
          await t.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
          getippt++;
        }
      } catch (e) {
        if (!_nurTestumgebung('$e')) _fehler.add('$kategorie › ${s.key} › „$name“: $e');
      }
      await _ruhe(t);
      _fehlerNehmen(t, '$kategorie › ${s.key} › „$name“');
    }
  }
  // Laufende Zeitgeber (Hinweise, Verzögerungen) ablaufen lassen
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(minutes: 2));
  _bericht.add('$kategorie: ${seiten.length} Seiten, $getippt Elemente angetippt');
}

void main() {
  Ki.deaktiviert = true;
  Benachrichtigungen.deaktiviert = true;
  sicherheitNativAus = true;

  tearDownAll(() {
    Directory('build').createSync(recursive: true);
    File('build/klicktest.txt').writeAsStringSync([
      ..._bericht,
      '',
      if (_fehler.isEmpty) 'Keine Fehler beim Antippen.' else ..._fehler,
    ].join('\n'));
  });

  for (final k in _kategorien.entries) {
    testWidgets('Klicktest: ${k.key}', (t) async {
      final vorher = _fehler.length;
      await _kategoriePruefen(t, k.key, k.value);
      final neu = _fehler.sublist(vorher);
      expect(neu, isEmpty, reason: neu.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 9)));
  }
}
