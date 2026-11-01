// Rundgang durch die ganze App: öffnet jeden Bildschirm mit Beispieldaten, sammelt Fehler
// (Abstürze, überlaufende Zeilen) und speichert Bildschirmfotos und alle PDFs nach build/rundgang/.
// Der Build packt den Ordner als rundgang.zip in die Veröffentlichung.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papiertiger/data/geschaeft.dart';
import 'package:papiertiger/data/store.dart';
import 'package:papiertiger/logic/android_kanal.dart';
import 'package:papiertiger/logic/benachrichtigungen.dart';
import 'package:papiertiger/logic/export.dart';
import 'package:papiertiger/logic/formular_eintrag.dart';
import 'package:papiertiger/logic/inhalte.dart';
import 'package:papiertiger/logic/ki.dart';
import 'package:papiertiger/logic/marketing.dart';
import 'package:papiertiger/logic/ordnung.dart';
import 'package:papiertiger/logic/steuer.dart';
import 'package:papiertiger/logic/zahlung.dart';
import 'package:papiertiger/ui/abwesenheit.dart';
import 'package:papiertiger/ui/akten.dart';
import 'package:papiertiger/ui/app.dart';
import 'package:papiertiger/ui/archiv.dart';
import 'package:papiertiger/ui/brief_detail.dart';
import 'package:papiertiger/ui/diktat.dart';
import 'package:papiertiger/ui/dokument_frage.dart';
import 'package:papiertiger/ui/erinnerungen_einstellungen.dart';
import 'package:papiertiger/ui/familie/familie.dart';
import 'package:papiertiger/ui/finanzen.dart';
import 'package:papiertiger/ui/formular_pdf_screen.dart';
import 'package:papiertiger/ui/formular_screen.dart';
import 'package:papiertiger/ui/fristen.dart';
import 'package:papiertiger/ui/geschaeft/geschaeft.dart';
import 'package:papiertiger/ui/geschaeft/katalog.dart';
import 'package:papiertiger/ui/geschaeft/marketing.dart';
import 'package:papiertiger/ui/geschaeft/plantafel.dart';
import 'package:papiertiger/ui/geschaeft/projekte.dart';
import 'package:papiertiger/ui/geschaeft/stempeluhr.dart';
import 'package:papiertiger/ui/geschaeft/baustelle.dart';
import 'package:papiertiger/ui/haushalt/alltag.dart';
import 'package:papiertiger/ui/haushalt/haushalt.dart';
import 'package:papiertiger/ui/karriere/karriere.dart';
import 'package:papiertiger/ui/ki_einstellungen.dart';
import 'package:papiertiger/ui/kommunikation.dart';
import 'package:papiertiger/ui/kontoauszug.dart';
import 'package:papiertiger/ui/mehr.dart';
import 'package:papiertiger/ui/module/angebote_vergleichen.dart';
import 'package:papiertiger/ui/module/antraege.dart';
import 'package:papiertiger/ui/module/behoerdengaenge.dart';
import 'package:papiertiger/ui/module/belege.dart';
import 'package:papiertiger/ui/module/ereignisse.dart';
import 'package:papiertiger/ui/module/leistungen.dart';
import 'package:papiertiger/ui/module/profil.dart';
import 'package:papiertiger/ui/module/steuer.dart';
import 'package:papiertiger/ui/module/vertrag_hilfen.dart';
import 'package:papiertiger/ui/module/vertraege.dart';
import 'package:papiertiger/ui/onboarding.dart';
import 'package:papiertiger/ui/shell.dart';
import 'package:papiertiger/ui/sicherheit.dart';
import 'package:papiertiger/ui/sicherung.dart';
import 'package:papiertiger/ui/termine.dart';
import 'package:papiertiger/ui/textvergleich.dart';
import 'package:papiertiger/ui/theme.dart';
import 'package:papiertiger/ui/ueberweisung.dart';
import 'package:papiertiger/ui/vermietung/vermietung.dart';
import 'package:papiertiger/ui/vorlage_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hilfe/beispieldaten.dart';

final _ziel = Directory('build/rundgang');
final _fehler = <String>[];
final _bilder = <String>[];

Directory? _schriftOrdner() {
  var d = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    for (final p in ['${d.path}/material_fonts', '${d.path}/artifacts/material_fonts', '${d.path}/cache/artifacts/material_fonts']) {
      if (File('$p/MaterialIcons-Regular.otf').existsSync()) return Directory(p);
    }
    d = d.parent;
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final p = Directory('$root/bin/cache/artifacts/material_fonts');
    if (p.existsSync()) return p;
  }
  return null;
}

Future<void> _schriftenLaden() async {
  Future<void> laden(String familie, List<String> dateien) async {
    final l = FontLoader(familie);
    for (final d in dateien) {
      if (File(d).existsSync()) l.addFont(Future.value(ByteData.sublistView(File(d).readAsBytesSync())));
    }
    await l.load();
  }

  final lib = [for (final s in ['Regular', 'Bold', 'Italic', 'BoldItalic']) 'assets/fonts/LiberationSans-$s.ttf'];
  // Auch als Testschrift laden: Texte ohne eigene Schriftfamilie (z. B. Knöpfe) sonst als schwarze Balken
  for (final f in ['Roboto', 'FlutterTest', 'Ahem']) {
    await laden(f, lib);
  }
  final icons = _schriftOrdner();
  if (icons != null) await laden('MaterialIcons', ['${icons.path}/MaterialIcons-Regular.otf']);
}

Future<void> _ruhe(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void _fehlerNehmen(WidgetTester t, String name) {
  for (var i = 0; i < 20; i++) {
    final e = t.takeException();
    if (e == null) return;
    final text = '$e'.split('\n').take(6).join(' | ');
    _fehler.add('$name: $text');
  }
}

String _datei(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüß_-]+'), '_');

Future<void> _foto(WidgetTester t, GlobalKey key, String name) async {
  // Hohe Ansicht, damit auch längere Seiten ganz zu sehen sind
  t.view.physicalSize = const Size(411 * 1.5, 1500 * 1.5);
  await _ruhe(t);
  final b = key.currentContext?.findRenderObject();
  if (b is RenderRepaintBoundary) {
    await t.runAsync(() async {
      final img = await b.toImage(pixelRatio: 1.5);
      final daten = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('${_ziel.path}/${(_bilder.length + 1).toString().padLeft(3, '0')}_${_datei(name)}.png');
      f.writeAsBytesSync(daten!.buffer.asUint8List());
      _bilder.add(f.path);
    });
  }
  t.view.physicalSize = const Size(411 * 1.5, 891 * 1.5);
  await _ruhe(t);
  // Fehler aus der hohen Ansicht zählen nicht
  while (t.takeException() != null) {}
}

Widget _app(AppStore store, Widget seite, GlobalKey key) => RepaintBoundary(
      key: key,
      child: StoreScope(
        store: store,
        child: MaterialApp(
          key: UniqueKey(),
          debugShowCheckedModeBanner: false,
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
      ),
    );

class _Pfade extends PathProviderPlatform {
  _Pfade(this.pfad);

  final String pfad;

  @override
  Future<String?> getTemporaryPath() async => pfad;

  @override
  Future<String?> getApplicationDocumentsPath() async => pfad;

  @override
  Future<String?> getApplicationSupportPath() async => pfad;
}

void main() {
  Ki.deaktiviert = true;
  Benachrichtigungen.deaktiviert = true;
  sicherheitNativAus = true;

  setUpAll(() {
    if (_ziel.existsSync()) _ziel.deleteSync(recursive: true);
    _ziel.createSync(recursive: true);
  });

  tearDownAll(() {
    File('${_ziel.path}/fehler.txt').writeAsStringSync(_fehler.isEmpty ? 'Keine Fehler.\n' : '${_fehler.join('\n')}\n');
  });

  testWidgets('Rundgang durch alle Bildschirme', (t) async {
    await _schriftenLaden();
    t.view.devicePixelRatio = 1.5;
    t.view.physicalSize = const Size(411 * 1.5, 891 * 1.5);
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues(beispielDaten());
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    final b1 = store.briefe.firstWhere((b) => b.id == 'b1');
    final b2 = store.briefe.firstWhere((b) => b.id == 'b2');
    final b4 = store.briefe.firstWhere((b) => b.id == 'b4');
    final v1 = store.vertraege.first;
    final p1 = store.projekte.first;

    final seiten = <String, Widget Function()>{
      'Start': () => const Shell(),
      'Archiv': () => const ArchivScreen(),
      'Fristen': () => const FristenScreen(),
      'Mehr': () => const MehrScreen(),
      'Brief Steuerbescheid': () => BriefDetail(briefId: b1.id),
      'Brief Angebot': () => BriefDetail(briefId: b2.id),
      'Formular Ausfüllhilfe': () => FormularScreen(brief: b1),
      'Formular direkt ins PDF': () => FormularPdfScreen(brief: b1),
      'Frag das Dokument': () => DokumentFrageScreen(brief: b4),
      'Textvergleich': () => TextVergleichScreen(alt: b2, neu: store.briefe.firstWhere((b) => b.id == 'b3')),
      'Angebote vergleichen': () => AngeboteVergleichenScreen(vorauswahl: b2.id),
      'Ordner Steuern': () => const OrdnerScreen(ordnerKey: 'steuern'),
      'Akte': () => AkteScreen(schluessel: akteSchluessel(b1)),
      'Vorlage Brief': () => const VorlageScreen(titel: 'Fristverlängerung', text: 'Sehr geehrte Damen und Herren,\n\nich bitte um mehr Zeit.'),
      'Kommunikation': () => const KommunikationScreen(),
      'Notiz zum Brief': () => NotizScreen(brief: b1),
      'Abwesenheit': () => const AbwesenheitScreen(),
      'Diktat': () => const DiktatScreen(),
      'Termine': () => const TermineListe(),
      'Termin neu': () => const TerminFormular(),
      'Erinnerungen': () => const ErinnerungenEinstellungen(),
      'KI-Einstellungen': () => const KiEinstellungenScreen(),
      'Profil': () => const ProfilScreen(),
      'Sicherheit': () => const SicherheitScreen(),
      'PIN festlegen': () => const PinFestlegen(),
      'Datensicherung': () => const SicherungScreen(),
      'Finanzen': () => const FinanzenScreen(),
      'Ratenrechner': () => const RatenRechner(betrag: 1234.56),
      'Kontoauszug prüfen': () => const KontoauszugScreen(),
      'Überweisung mit Freigabe': () => UeberweisungScreen(
          auftrag: Zahlauftrag(empfaenger: 'Finanzamt Musterstadt', iban: 'DE12345678901234567890', betrag: 1234.56, zweck: 'St-Nr 123/456/78901')),
      'Verträge': () => const VertraegeScreen(),
      'Vertrag Detail': () => VertragDetail(vertragId: v1.id),
      'Vertrag neu': () => const VertragFormular(),
      'Versicherungen': () => const VersicherungsUeberblick(),
      'Schaden melden': () => SchadenScreen(vertrag: store.vertraege.last),
      'Anbieterwechsel': () => WechselScreen(vertrag: v1),
      'Tarifvergleich': () => const TarifVergleichScreen(),
      'Belege': () => const BelegeScreen(),
      'Beleg Detail': () => const BelegDetail(belegId: 'bl1'),
      'Steuer': () => const SteuerScreen(),
      'Werbungskosten': () => const WerbungskostenScreen(jahr: 2026),
      'Steuer-Checkliste': () => const SteuerCheckliste(jahr: 2026),
      'Steuer-Fragen': () => const SteuerFragen(jahr: 2026),
      'Leistungen': () => const LeistungenScreen(),
      'Anträge': () => const AntraegeScreen(),
      'Antrag': () => AntragScreen(antrag: antraege.first),
      'Lebens-Ereignisse': () => const EreignisseScreen(),
      'Ereignis Umzug': () => ChecklisteScreen(ereignis: lebensEreignisse.first),
      'Behördengänge': () => const BehoerdengaengeScreen(),
      'Gewerbe Übersicht': () => const GeschaeftScreen(),
      'Rechnung Detail': () => const RechnungDetail(rechnungId: 'r1'),
      'Angebot Detail': () => const RechnungDetail(rechnungId: 'a1'),
      'Rechnung bearbeiten': () => RechnungFormular(art: 'rechnung', rechnung: store.rechnungen.firstWhere((r) => r.id == 'r1')),
      'Kunden': () => const KundenScreen(),
      'Kunde neu': () => const KundeFormular(),
      'Firma': () => const FirmaScreen(),
      'EÜR': () => const EuerScreen(),
      'Katalog': () => const KatalogScreen(),
      'Artikel neu': () => const ArtikelFormular(),
      'Aufmaß': () => AufmassScreen(titel: 'Wände streichen', zeilen: [AufmassZeile(text: 'Wand Nord', laenge: 4.5, breite: 2.6)]),
      'Projekte': () => const ProjekteScreen(),
      'Projekt Detail': () => ProjektDetail(projektId: p1.id),
      'Tagesbericht': () => TagesberichtScreen(projekt: p1),
      'Regiebericht': () => BauberichtScreen(projekt: p1, art: 'regie'),
      'Vorlagen Gewerbe': () => const VorlagenScreen(),
      'Plantafel': () => const PlantafelScreen(),
      'Stempeluhr': () => const StempeluhrScreen(),
      'Marketing': () => const MarketingScreen(),
      'Marketing-Text': () => MarketingText(art: marketingArten.first),
      'Zahlungseingänge': () => const ZahlungseingaengeScreen(),
      'Haushalt': () => const HaushaltScreen(),
      'Zähler': () => const ZaehlerScreen(),
      'Zähler Detail': () => const ZaehlerDetail(zaehlerId: 'z1'),
      'Inventar': () => const InventarScreen(),
      'Notfallmappe': () => const NotfallScreen(),
      'Einkauf': () => const EinkaufScreen(),
      'Vorräte': () => const VorraeteScreen(),
      'Essensplan': () => const EssensplanScreen(),
      'Haushaltsaufgaben': () => const HausaufgabenScreen(),
      'Geschenke': () => const GeschenkeScreen(),
      'Reisen': () => const ReisenScreen(),
      'Reise Detail': () => const ReiseDetail(reiseId: 'reise1'),
      'Wohnungsübergabe': () => const WohnungsuebergabeScreen(),
      'Karriere': () => const KarriereScreen(),
      'Lebenslauf': () => const LebenslaufScreen(),
      'Bewerbungen': () => const BewerbungenScreen(),
      'Bewerbung Detail': () => const BewerbungDetail(bewerbungId: 'bw1'),
      'Zeugnis': () => const ZeugnisScreen(),
      'Weiterbildung': () => const WeiterbildungScreen(),
      'Gehalt': () => const GehaltScreen(),
      'Kinder': () => const KinderScreen(),
      'Kind Detail': () => const KindDetail(kindId: 'kind1'),
      'Vorsorgemappe': () => const VorsorgeScreen(),
      'Vermietung': () => const VermietungScreen(),
      'Mieter': () => const MieterScreen(mieterId: 'm1'),
      'Nebenkosten': () => const NebenkostenScreen(objektId: 'o1', jahr: 2025),
      'Mieteingänge': () => const MieteingaengeScreen(),
    };

    for (final e in seiten.entries) {
      final key = GlobalKey();
      try {
        await t.pumpWidget(_app(store, e.value(), key));
        await _ruhe(t);
      } catch (x) {
        _fehler.add('${e.key}: $x');
      }
      _fehlerNehmen(t, e.key);
      await _foto(t, key, e.key);
    }

    // Ablauf: Angebot neu anlegen und Beträge prüfen
    final key = GlobalKey();
    await t.pumpWidget(_app(store, const RechnungFormular(art: 'angebot'), key));
    await _ruhe(t);
    final felder = find.byType(TextField);
    if (felder.evaluate().length >= 4) {
      await t.enterText(felder.at(0), 'Fassade streichen');
      await t.enterText(felder.at(1), '120');
      await t.enterText(felder.at(2), 'm²');
      await t.enterText(felder.at(3), '18,50');
      await _ruhe(t);
      final mitEuro = find.textContaining('€').evaluate().length;
      if (mitEuro == 0) _fehler.add('Angebot neu: keine Beträge mit € sichtbar');
      if (find.textContaining('2.220,00 €').evaluate().isEmpty) _fehler.add('Angebot neu: Summe 2.220,00 € fehlt');
    } else {
      _fehler.add('Angebot neu: Eingabefelder nicht gefunden');
    }
    _fehlerNehmen(t, 'Angebot neu');
    await _foto(t, key, 'Angebot neu ausgefüllt');

    // Onboarding und Sperrbildschirm
    final leer = AppStore(prefs)..onboardingFertig = false;
    final k2 = GlobalKey();
    await t.pumpWidget(_app(leer, const Onboarding(), k2));
    await _ruhe(t);
    _fehlerNehmen(t, 'Onboarding');
    await _foto(t, k2, 'Onboarding');

    SharedPreferences.setMockInitialValues(beispielDaten(sperre: true));
    final gesperrt = AppStore(await SharedPreferences.getInstance());
    final k3 = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: k3, child: PapiertigerApp(store: gesperrt)));
    await _ruhe(t);
    _fehlerNehmen(t, 'Sperrbildschirm');
    await _foto(t, k3, 'Sperrbildschirm');
    if (find.text('Papiertiger ist gesperrt').evaluate().isEmpty) _fehler.add('Sperrbildschirm: nicht angezeigt');

    // Fehler stehen in build/rundgang/fehler.txt und lassen den Test scheitern
    expect(_fehler, isEmpty, reason: _fehler.join('\n'));
  });

  test('Alle PDFs erzeugen', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _Pfade(_ziel.path);
    SharedPreferences.setMockInitialValues(beispielDaten());
    final store = AppStore(await SharedPreferences.getInstance());
    final f = store.firma;
    final k = store.kundeMitId('k1');
    final r = store.rechnungen.firstWhere((x) => x.id == 'r1');
    final a = store.rechnungen.firstWhere((x) => x.id == 'a1');
    final p = store.projekte.first;
    final bericht = p.berichte.first
      ..unterschrift = 'test/fixtures/unterschrift.png'
      ..unterschriftName = 'Familie Müller'
      ..unterschriebenAm = DateTime(2026, 10, 28);
    final klein = Firma.fromJson({...f.toJson(), 'kleinunternehmer': true, 'ustId': ''});
    final erzeugt = <String, Future<File> Function()>{
      'Rechnung': () => rechnungAlsPdf(r, f, k, alle: store.rechnungen),
      'Angebot': () => rechnungAlsPdf(a, f, k, alle: store.rechnungen),
      'Rechnung Kleinunternehmer': () => rechnungAlsPdf(r, klein, k, alle: store.rechnungen),
      'Auftragsbestätigung': () => rechnungAlsPdf(Rechnung.fromJson({...a.toJson(), 'id': 'ab', 'art': 'auftragsbestaetigung', 'nummer': 'AB-2026-001'}), f, k),
      'Lieferschein': () => rechnungAlsPdf(Rechnung.fromJson({...a.toJson(), 'id': 'ls', 'art': 'lieferschein', 'nummer': 'LS-2026-001'}), f, k),
      'Brief erklärt': () => briefAlsPdf(store.briefe.first),
      'Akte': () => akteAlsPdf(aktenBilden(store.briefe).first),
      'Antwortbrief': () => antwortAlsPdf('Erika Muster\nHauptstraße 5\n12345 Musterstadt\n\nFinanzamt Musterstadt\n\nBetreff: Einspruch – „Bescheid 2025“\n\n'
          'Sehr geehrte Damen und Herren,\nich lege Einspruch ein. Der Betrag von 1.234,56 € ist zu hoch.\n\nMit freundlichen Grüßen\nErika Muster',
          titel: 'Einspruch'),
      'Steuer': () => steuerAlsPdf(2026, [SteuerPosten(DateTime(2026, 3, 1), 'Fachbuch', 'Arbeitsmittel', 49.9)],
          werbung: Werbungskosten(fahrt: 1380, homeoffice: 600, weitere: 49.9)),
      'Inventar': () => inventarAlsPdf(store.inventar),
      'Belege': () => belegeAlsPdf('Belege 2026', store.belege),
      'Regiebericht': () => berichtAlsPdf(bericht, p, f, k),
      'Bautagebuch': () => bautagebuchAlsPdf(p, f, k),
      'Arbeitsauftrag': () => arbeitsauftragAlsPdf(p, f, k, einsaetze: store.einsaetze, auftrag: a),
      'Lebenslauf': () => lebenslaufAlsPdf(store.karriere.lebenslauf, store.profil),
      'Formular ausgefüllt': () => formularAlsPdf(['test/fixtures/formular.png'], [
            FormularEintrag(seite: 0, x: 0.36, y: 0.155, text: 'Muster'),
            FormularEintrag(seite: 0, x: 0.36, y: 0.218, text: 'Erika'),
            FormularEintrag(seite: 0, x: 0.56, y: 0.69, bild: 'test/fixtures/unterschrift.png', groesse: 0.02),
          ], titel: 'Antrag'),
    };
    final probleme = <String>[];
    for (final e in erzeugt.entries) {
      try {
        final d = await e.value();
        d.copySync('${_ziel.path}/pdf_${_datei(e.key)}.pdf');
      } catch (x) {
        probleme.add('${e.key}: $x');
      }
    }
    final thema = await pdfThema();
    if (thema.defaultTextStyle.font?.fontName.contains('Liberation') != true) probleme.add('PDF-Schrift nicht geladen');
    File('${_ziel.path}/pdf_fehler.txt').writeAsStringSync(probleme.isEmpty ? 'Keine Fehler.\n' : '${probleme.join('\n')}\n');
    expect(probleme, isEmpty, reason: probleme.join('\n'));
  });
}
