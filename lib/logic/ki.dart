import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'ki_auswertung.dart';

/// Die KI auf dem Handy: Googles Gemma 4 E2B, läuft komplett offline.
class Ki {
  static const modellUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';
  static const modellDatei = 'gemma-4-E2B-it.litertlm';
  static const groesse = '2,6 GB';

  static bool _gestartet = false;

  /// In automatischen Tests gibt es keine KI.
  static bool deaktiviert = false;
  static Future<void>? _start;
  static InferenceModel? _modell;
  static bool? _cpuGeladen;
  static bool _bildGeladen = false;

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<void> starten() {
    return _start ??= () async {
      await FlutterEdgeAi.initialize(inferenceEngines: [LiteRtLmEngine()]);
      final p = await _prefs;
      // Ist die App während einer KI-Auswertung abgestürzt (meist zu wenig
      // Speicher auf dem Grafikchip), nehmen wir ab jetzt den Prozessor.
      if (p.getBool('kiLaeuft') == true) {
        await p.setBool('kiCpu', true);
        await p.setBool('kiLaeuft', false);
        await p.setBool('kiAbsturzHinweis', true);
      }
      _gestartet = true;
    }();
  }

  static Future<bool> istInstalliert() async {
    if (deaktiviert) return false;
    try {
      await starten();
      return await FlutterEdgeAi.isModelInstalled(modellDatei);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> nutztProzessor() async => (await _prefs).getBool('kiCpu') ?? false;

  static Future<void> setzeProzessor(bool cpu) async {
    await (await _prefs).setBool('kiCpu', cpu);
    await _schliessen();
  }

  /// Zeigt einmal an, dass nach einem Absturz auf den Prozessor gewechselt wurde.
  static Future<bool> absturzHinweisAbholen() async {
    if (deaktiviert) return false;
    final p = await _prefs;
    final da = p.getBool('kiAbsturzHinweis') ?? false;
    if (da) await p.setBool('kiAbsturzHinweis', false);
    return da;
  }

  static Future<void> herunterladen(void Function(int prozent) fortschritt, CancelToken abbruch) async {
    await starten();
    await FlutterEdgeAi.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm)
        .fromNetwork(modellUrl, foreground: true)
        .withCancelToken(abbruch)
        .withProgress(fortschritt)
        .install();
  }

  static Future<void> loeschen() async {
    await _schliessen();
    await starten();
    await FlutterEdgeAi.uninstallModel(modellDatei);
  }

  static Future<void> _schliessen() async {
    final m = _modell;
    _modell = null;
    _cpuGeladen = null;
    _bildGeladen = false;
    if (m != null) {
      try {
        await m.close();
      } catch (_) {}
    }
  }

  static Future<InferenceModel> _laden({bool bild = false}) async {
    await starten();
    final cpu = await nutztProzessor();
    if (_modell != null && _cpuGeladen == cpu && !_modell!.isClosed && (_bildGeladen || !bild)) {
      return _modell!;
    }
    if (!FlutterEdgeAi.hasActiveModel()) {
      // Schon installiert: aktiviert die Datei ohne neuen Download.
      await FlutterEdgeAi.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm)
          .fromNetwork(modellUrl)
          .install();
    }
    _modell = await FlutterEdgeAi.getActiveModel(
      maxTokens: 4096,
      preferredBackend: cpu ? PreferredBackend.cpu : PreferredBackend.gpu,
      // Volle Genauigkeit, damit Zahlen und Daten nicht verfälscht werden.
      activationDataType: ActivationDataType.float32,
      supportImage: bild ? true : null,
    );
    _cpuGeladen = cpu;
    _bildGeladen = bild;
    return _modell!;
  }

  /// Schickt eine beliebige Anfrage an die KI und liefert die Antwort Stück für Stück.
  static Stream<String> text(String anfrage, {int maxAusgabe = 900, double temperatur = 0.2}) async* {
    final p = await _prefs;
    await p.setBool('kiLaeuft', true);
    try {
      final modell = await _laden();
      final sitzung = await modell.createSession(temperature: temperatur, maxOutputTokens: maxAusgabe);
      try {
        await sitzung.addQueryChunk(Message(text: anfrage, isUser: true));
        yield* sitzung.getResponseAsync();
      } finally {
        await sitzung.close();
      }
    } finally {
      await p.setBool('kiLaeuft', false);
    }
  }

  /// Lässt die KI den Brief lesen. Liefert den Antworttext Stück für Stück.
  static Stream<String> lesen(String brieftext) => text(kiAnfrage(brieftext), maxAusgabe: 900);

  /// Liest Text aus einem Foto, auch Handschrift (Bilderkennung der KI).
  static Future<String> bildLesen(List<String> pfade) async {
    final p = await _prefs;
    await p.setBool('kiLaeuft', true);
    try {
      final modell = await _laden(bild: true);
      final teile = <String>[];
      for (final pfad in pfade) {
        final sitzung = await modell.createSession(
            temperature: 0.1, maxOutputTokens: 1500, enableVisionModality: true);
        try {
          await sitzung.addQueryChunk(Message(
            text: 'Lies den gesamten Text auf diesem Bild ab, auch Handschrift. '
                'Gib nur den Text wieder, Zeile für Zeile, ohne Kommentar und ohne Erklärung.',
            isUser: true,
            imageBytes: await File(pfad).readAsBytes(),
          ));
          teile.add(await sitzung.getResponse());
        } finally {
          await sitzung.close();
        }
      }
      return teile.join('\n\n');
    } finally {
      await p.setBool('kiLaeuft', false);
    }
  }

  static bool get bereitGestartet => _gestartet;
}

/// Verwaltet laufende KI-Auswertungen, damit sie weiterlaufen,
/// auch wenn man die Seite verlässt.
class KiAuftraege extends ChangeNotifier {
  KiAuftraege._();
  static final instanz = KiAuftraege._();

  final Map<String, String> _text = {};
  final Map<String, String> _fehler = {};

  bool laeuft(String briefId) => _text.containsKey(briefId);
  String zwischenstand(String briefId) => _text[briefId] ?? '';
  String? fehler(String briefId) => _fehler[briefId];

  Future<void> starten(AppStore store, Brief brief) async {
    if (laeuft(brief.id)) return;
    _fehler.remove(brief.id);
    _text[brief.id] = '';
    notifyListeners();
    final antwort = StringBuffer();
    try {
      await for (final stueck in Ki.lesen(brief.text)) {
        antwort.write(stueck);
        _text[brief.id] = antwort.toString();
        notifyListeners();
      }
      final ergebnis = kiAntwortLesen(antwort.toString());
      if (ergebnis.brauchbar) {
        kiUebernehmen(brief, ergebnis);
        await store.geaendert();
      } else {
        _fehler[brief.id] = 'Die KI hat keine verwertbare Antwort gegeben. Versuch es bitte noch einmal.';
      }
    } catch (e) {
      _fehler[brief.id] = 'Die KI konnte den Brief nicht lesen: $e';
    } finally {
      _text.remove(brief.id);
      notifyListeners();
    }
  }
}
