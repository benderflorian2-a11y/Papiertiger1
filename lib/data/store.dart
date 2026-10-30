import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/ordnung.dart';
import 'alltag.dart';
import 'familie.dart';
import 'karriere.dart';
import 'vermietung.dart';
import 'geschaeft.dart';
import 'haushalt.dart';
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

  /// Freie Texte, z. B. vorbereitete Antrags-Angaben ('antrag:<key>:<nr>').
  Map<String, String> notizen = {};
  bool onboardingFertig = false;
  List<Termin> termine = [];

  // Selbstständige
  Firma firma = Firma();
  List<Kunde> kunden = [];
  List<Rechnung> rechnungen = [];
  List<Projekt> projekte = [];

  List<Sparziel> sparziele = [];

  // Haushalt
  List<Zaehler> zaehler = [];
  List<Artikel> artikel = [];
  List<Einsatz> einsaetze = [];
  List<Stempel> stempel = [];

  /// Mitarbeiter bzw. Kolonnen für die Plantafel (Namen).
  List<String> mitarbeiter = [];
  List<Gegenstand> inventar = [];
  Alltag alltag = Alltag();
  Karriere karriere = Karriere();
  Familie familie = Familie();
  Vermietung vermietung = Vermietung();

  /// Zuschaltbare Bereichsgruppen: 'selbststaendig', 'haushalt'.
  bool bereichAktiv(String gruppe) => checklisten['bereich:$gruppe'] == true;

  /// Gewählte Lebenslagen (siehe logic/lebenslage.dart).
  Set<String> get lebenslagen => {
        for (final e in checklisten.entries)
          if (e.key.startsWith('lage:') && e.value) e.key.substring(5),
      };

  /// Lebenslagen setzen; schaltet die passenden Bereiche mit.
  Future<void> lebenslagenSetzen(Set<String> lagen) {
    checklisten.removeWhere((k, _) => k.startsWith('lage:'));
    for (final l in lagen) {
      checklisten['lage:$l'] = true;
    }
    if (lagen.isNotEmpty) {
      checklisten['bereich:selbststaendig'] = lagen.contains('selbststaendig') || lagen.contains('handwerk');
      checklisten['bereich:haushalt'] = lagen.contains('familie') || lagen.contains('senior') || lagen.contains('vermieter');
    }
    if (lagen.contains('senior')) checklisten['ansicht:grossschrift'] = true;
    return _speichern();
  }

  bool get grossschrift => checklisten['ansicht:grossschrift'] == true;
  ErinnerungsEinstellungen erinnerungen = ErinnerungsEinstellungen();

  static Future<AppStore> oeffnen() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore(prefs);
  }

  /// Alle gespeicherten Werte (für die Datensicherung).
  Map<String, Object?> alleWerte() => {for (final k in _prefs.getKeys()) k: _prefs.get(k)};

  /// Ersetzt alle gespeicherten Werte (Datensicherung zurückspielen) und lädt neu.
  Future<void> werteErsetzen(Map<String, Object?> werte) async {
    await _prefs.clear();
    for (final e in werte.entries) {
      final v = e.value;
      if (v is String) {
        await _prefs.setString(e.key, v);
      } else if (v is bool) {
        await _prefs.setBool(e.key, v);
      } else if (v is int) {
        await _prefs.setInt(e.key, v);
      } else if (v is double) {
        await _prefs.setDouble(e.key, v);
      } else if (v is List) {
        await _prefs.setStringList(e.key, [for (final x in v) '$x']);
      }
    }
    _leeren();
    _laden();
    notifyListeners();
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
    termine = _liste('termine').map(Termin.fromJson).toList();
    kunden = _liste('kunden').map(Kunde.fromJson).toList();
    rechnungen = _liste('rechnungen').map(Rechnung.fromJson).toList();
    projekte = _liste('projekte').map(Projekt.fromJson).toList();
    zaehler = _liste('zaehler').map(Zaehler.fromJson).toList();
    artikel = _liste('artikel').map(Artikel.fromJson).toList();
    einsaetze = _liste('einsaetze').map(Einsatz.fromJson).toList();
    stempel = _liste('stempel').map(Stempel.fromJson).toList();
    mitarbeiter = _prefs.getStringList('mitarbeiter') ?? [];
    sparziele = _liste('sparziele').map(Sparziel.fromJson).toList();
    final a = _prefs.getString('alltag');
    if (a != null) {
      try {
        alltag = Alltag.fromJson(jsonDecode(a) as Map<String, dynamic>);
      } catch (_) {}
    }
    final fa = _prefs.getString('familie');
    if (fa != null) {
      try {
        familie = Familie.fromJson(jsonDecode(fa) as Map<String, dynamic>);
      } catch (_) {}
    }
    final vm = _prefs.getString('vermietung');
    if (vm != null) {
      try {
        vermietung = Vermietung.fromJson(jsonDecode(vm) as Map<String, dynamic>);
      } catch (_) {}
    }
    final kr = _prefs.getString('karriere');
    if (kr != null) {
      try {
        karriere = Karriere.fromJson(jsonDecode(kr) as Map<String, dynamic>);
      } catch (_) {}
    }
    inventar = _liste('inventar').map(Gegenstand.fromJson).toList();
    final f = _prefs.getString('firma');
    if (f != null) {
      try {
        firma = Firma.fromJson(jsonDecode(f) as Map<String, dynamic>);
      } catch (_) {}
    }
    final e = _prefs.getString('erinnerungen');
    if (e != null) {
      try {
        erinnerungen = ErinnerungsEinstellungen.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {}
    }
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
    final n = _prefs.getString('notizen');
    if (n != null) {
      try {
        notizen = (jsonDecode(n) as Map<String, dynamic>).map((k, v) => MapEntry(k, '$v'));
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
    await _prefs.setString('notizen', jsonEncode(notizen));
    await _prefs.setString('firma', jsonEncode(firma.toJson()));
    await _prefs.setString('kunden', jsonEncode(kunden.map((k) => k.toJson()).toList()));
    await _prefs.setString('rechnungen', jsonEncode(rechnungen.map((r) => r.toJson()).toList()));
    await _prefs.setString('projekte', jsonEncode(projekte.map((p) => p.toJson()).toList()));
    await _prefs.setString('zaehler', jsonEncode(zaehler.map((z) => z.toJson()).toList()));
    await _prefs.setString('artikel', jsonEncode(artikel.map((a) => a.toJson()).toList()));
    await _prefs.setString('einsaetze', jsonEncode(einsaetze.map((e) => e.toJson()).toList()));
    await _prefs.setString('stempel', jsonEncode(stempel.map((e) => e.toJson()).toList()));
    await _prefs.setStringList('mitarbeiter', mitarbeiter);
    await _prefs.setString('sparziele', jsonEncode(sparziele.map((z) => z.toJson()).toList()));
    await _prefs.setString('alltag', jsonEncode(alltag.toJson()));
    await _prefs.setString('karriere', jsonEncode(karriere.toJson()));
    await _prefs.setString('familie', jsonEncode(familie.toJson()));
    await _prefs.setString('vermietung', jsonEncode(vermietung.toJson()));
    await _prefs.setString('inventar', jsonEncode(inventar.map((g) => g.toJson()).toList()));
    await _prefs.setBool('onboardingFertig', onboardingFertig);
    await _prefs.setString('termine', jsonEncode(termine.map((t) => t.toJson()).toList()));
    await _prefs.setString('erinnerungen', jsonEncode(erinnerungen.toJson()));
    notifyListeners();
  }

  Future<void> terminSpeichern(Termin t) {
    if (!termine.any((x) => x.id == t.id)) termine.add(t);
    return _speichern();
  }

  Future<void> terminLoeschen(Termin t) {
    termine.removeWhere((x) => x.id == t.id);
    return _speichern();
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

  Future<void> kundeSpeichern(Kunde k) {
    if (!kunden.any((x) => x.id == k.id)) kunden.add(k);
    return _speichern();
  }

  Future<void> rechnungSpeichern(Rechnung r) {
    if (!rechnungen.any((x) => x.id == r.id)) rechnungen.add(r);
    return _speichern();
  }

  Future<void> rechnungLoeschen(Rechnung r) {
    rechnungen.removeWhere((x) => x.id == r.id);
    return _speichern();
  }

  Future<void> zaehlerSpeichern(Zaehler z) {
    if (!zaehler.any((x) => x.id == z.id)) zaehler.add(z);
    return _speichern();
  }

  Future<void> zaehlerLoeschen(Zaehler z) {
    zaehler.removeWhere((x) => x.id == z.id);
    return _speichern();
  }

  Future<void> gegenstandSpeichern(Gegenstand g) {
    if (!inventar.any((x) => x.id == g.id)) inventar.add(g);
    return _speichern();
  }

  Future<void> gegenstandLoeschen(Gegenstand g) {
    inventar.removeWhere((x) => x.id == g.id);
    if (g.bild != null) _dateienLoeschen([g.bild!]);
    return _speichern();
  }

  Future<void> projektSpeichern(Projekt p) {
    if (!projekte.any((x) => x.id == p.id)) projekte.add(p);
    return _speichern();
  }

  Future<void> projektLoeschen(Projekt p) {
    projekte.removeWhere((x) => x.id == p.id);
    return _speichern();
  }

  Kunde? kundeMitId(String id) {
    for (final k in kunden) {
      if (k.id == id) return k;
    }
    return null;
  }

  Future<void> checklistePunkt(String key, bool wert) {
    checklisten[key] = wert;
    return _speichern();
  }

  /// Löscht alle Daten und Bilder der App.
  void _leeren() {
    briefe = [];
    vertraege = [];
    belege = [];
    termine = [];
    erinnerungen = ErinnerungsEinstellungen();
    profil = Profil();
    checklisten = {};
    notizen = {};
    firma = Firma();
    kunden = [];
    rechnungen = [];
    projekte = [];
    zaehler = [];
    artikel = [];
    einsaetze = [];
    stempel = [];
    mitarbeiter = [];
    inventar = [];
    sparziele = [];
    alltag = Alltag();
    karriere = Karriere();
    familie = Familie();
    vermietung = Vermietung();
    onboardingFertig = false;
  }

  Future<void> allesLoeschen() async {
    for (final b in briefe) {
      _dateienLoeschen([...b.bilder, if (b.pdfPfad != null) b.pdfPfad!]);
    }
    for (final b in belege) {
      if (b.bild != null) _dateienLoeschen([b.bild!]);
    }
    for (final g in inventar) {
      if (g.bild != null) _dateienLoeschen([g.bild!]);
    }
    _leeren();
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
