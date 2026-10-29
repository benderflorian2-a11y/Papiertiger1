import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/ordnung.dart';
import 'models.dart';

/// Hält alle Daten der App und speichert sie auf dem Handy.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs) {
    _laden();
  }

  final SharedPreferences _prefs;

  List<Brief> briefe = [];
  List<Vertrag> vertraege = [];
  List<Beleg> belege = [];
  Profil profil = Profil();
  Map<String, bool> checklisten = {};
  bool onboardingFertig = false;

  static Future<AppStore> oeffnen() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore(prefs);
  }

  List<Map<String, dynamic>> _liste(String key) {
    final roh = _prefs.getString(key);
    if (roh == null) return [];
    try {
      final daten = jsonDecode(roh);
      if (daten is List) return daten.whereType<Map<String, dynamic>>().toList();
    } catch (_) {}
    return [];
  }

  void _laden() {
    briefe = _liste('briefe').map(Brief.fromJson).toList();
    vertraege = _liste('vertraege').map(Vertrag.fromJson).toList();
    belege = _liste('belege').map(Beleg.fromJson).toList();
    final p = _prefs.getString('profil');
    if (p != null) {
      try {
        profil = Profil.fromJson(jsonDecode(p) as Map<String, dynamic>);
      } catch (_) {}
    }
    final c = _prefs.getString('checklisten');
    if (c != null) {
      try {
        checklisten = (jsonDecode(c) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v == true));
      } catch (_) {}
    }
    onboardingFertig = _prefs.getBool('onboardingFertig') ?? false;
    _sortieren();
  }

  void _sortieren() {
    briefe.sort((a, b) => b.erstellt.compareTo(a.erstellt));
    belege.sort((a, b) => b.datum.compareTo(a.datum));
  }

  Future<void> _speichern() async {
    _sortieren();
    await _prefs.setString(
        'briefe', jsonEncode(briefe.map((b) => b.toJson()).toList()));
    await _prefs.setString(
        'vertraege', jsonEncode(vertraege.map((v) => v.toJson()).toList()));
    await _prefs.setString(
        'belege', jsonEncode(belege.map((b) => b.toJson()).toList()));
    await _prefs.setString('profil', jsonEncode(profil.toJson()));
    await _prefs.setString('checklisten', jsonEncode(checklisten));
    await _prefs.setBool('onboardingFertig', onboardingFertig);
    notifyListeners();
  }

  /// Nach jeder Änderung an einem Objekt aufrufen.
  Future<void> geaendert() => _speichern();

  Future<void> onboardingAbschliessen(String name) {
    onboardingFertig = true;
    if (name.trim().isNotEmpty) profil.name = name.trim();
    return _speichern();
  }

  Future<void> briefHinzufuegen(Brief b) {
    b.duplikatVon = duplikatFinden(b, briefe)?.id;
    briefe.add(b);
    return _speichern();
  }

  Future<void> briefLoeschen(Brief b) {
    briefe.removeWhere((x) => x.id == b.id);
    for (final x in briefe) {
      if (x.duplikatVon == b.id) x.duplikatVon = null;
    }
    _dateienLoeschen([...b.bilder, if (b.pdfPfad != null) b.pdfPfad!]);
    return _speichern();
  }

  Future<void> vertragSpeichern(Vertrag v) {
    if (!vertraege.any((x) => x.id == v.id)) vertraege.add(v);
    return _speichern();
  }

  Future<void> vertragLoeschen(Vertrag v) {
    vertraege.removeWhere((x) => x.id == v.id);
    return _speichern();
  }

  Future<void> belegSpeichern(Beleg b) {
    if (!belege.any((x) => x.id == b.id)) belege.add(b);
    return _speichern();
  }

  Future<void> belegLoeschen(Beleg b) {
    belege.removeWhere((x) => x.id == b.id);
    if (b.bild != null) _dateienLoeschen([b.bild!]);
    return _speichern();
  }

  Future<void> checklistePunkt(String key, bool wert) {
    checklisten[key] = wert;
    return _speichern();
  }

  /// Löscht alle Daten und Bilder der App.
  Future<void> allesLoeschen() async {
    for (final b in briefe) {
      _dateienLoeschen([...b.bilder, if (b.pdfPfad != null) b.pdfPfad!]);
    }
    for (final b in belege) {
      if (b.bild != null) _dateienLoeschen([b.bild!]);
    }
    briefe = [];
    vertraege = [];
    belege = [];
    profil = Profil();
    checklisten = {};
    onboardingFertig = false;
    await _prefs.clear();
    notifyListeners();
  }

  void _dateienLoeschen(List<String> pfade) {
    for (final p in pfade) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }
}
