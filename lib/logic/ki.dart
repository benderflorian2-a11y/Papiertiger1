import 'dart:async';

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
  static Future<void>? _start;
  static InferenceModel? _modell;
  static bool? _cpuGeladen;

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
    if (m != null) {
      try {
        await m.close();
      } catch (_) {}
    }
  }

  static Future<InferenceModel> _laden() async {
    await starten();
    final cpu = await nutztProzessor();
    if (_modell != null && _cpuGeladen == cpu && !_modell!.isClosed) return _modell!;
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
    );
    _cpuGeladen = cpu;
    return _modell!;
  }

  /// Lässt die KI den Brief lesen. Liefert den Antworttext Stück für Stück.
  static Stream<String> lesen(String brieftext) async* {
    final p = await _prefs;
    await p.setBool('kiLaeuft', true);
    try {
      final modell = await _laden();
      final sitzung = await modell.createSession(temperature: 0.2, maxOutputTokens: 700);
      try {
        await sitzung.addQueryChunk(Message(text: kiAnfrage(brieftext), isUser: true));
        yield* sitzung.getResponseAsync();
      } finally {
        await sitzung.close();
      }
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
