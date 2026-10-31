import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/android_kanal.dart';
import '../logic/ordnung.dart';
import '../logic/protokoll.dart';
import '../logic/tresor.dart';
import 'alltag.dart';
import 'familie.dart';
import 'karriere.dart';
import 'vermietung.dart';
import 'geschaeft.dart';
import 'haushalt.dart';
import 'models.dart';

/// Hält alle Daten der App und speichert sie auf dem Handy.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs, {Tresor? tresor, this.schluesselFehler = false}) : _tresor = tresor {
    _laden();
    if (_umstellen && !lesefehler) Future.microtask(_speichern);
  }

  final SharedPreferences _prefs;

  /// Verschlüsselt die gespeicherten Daten (Schlüssel aus dem Android-Keystore). null = unverschlüsselt.
  final Tresor? _tresor;
  bool get verschluesselt => _tresor != null;

  /// Der Schlüssel konnte nicht geholt werden.
  final bool schluesselFehler;

  /// Gespeicherte Daten ließen sich nicht entschlüsseln. Dann wird nichts überschrieben.
  bool lesefehler = false;

  /// Zuletzt geschriebener Klartext je Schlüssel – unveränderte Werte werden nicht neu verschlüsselt.
  final Map<String, String> _zuletzt = {};
  bool _umstellen = false;

  /// Änderungsprotokoll (Rechnungen, Sicherheit).
  List<ProtokollEintrag> protokoll = [];
  Map<String, String> _rechnungStand = {};

  /// Werte, die nicht verschlüsselt werden (liest die Android-Seite bzw. andere Teile direkt).
  static bool _klartext(String key) => key.startsWith('widget_') || key.startsWith('ki');

  String? _get(String key) {
    final roh = _prefs.getString(key);
    if (roh == null) return null;
    if (!istVerschluesselt(roh)) {
      if (_tresor != null && !_klartext(key)) {
        _umstellen = true;
      } else {
        _zuletzt[key] = roh;
      }
      return roh;
    }
    if (_tresor == null) {
      lesefehler = true;
      return null;
    }
    try {
      final klar = _tresor.entschluesseln(roh);
      _zuletzt[key] = klar;
      return klar;
    } catch (_) {
      lesefehler = true;
      return null;
    }
  }

  Future<void> _set(String key, String wert) async {
    if (lesefehler) return;
    if (_zuletzt[key] == wert) return;
    final t = _tresor;
    await _prefs.setString(key, t == null || _klartext(key) ? wert : t.verschluesseln(wert));
    _zuletzt[key] = wert;
  }

  /// Sicherheits-Vorgang ins Protokoll schreiben (z. B. App-Sperre eingeschaltet).
  Future<void> protokollNotiz(String text, {String art = 'sicherheit', String objekt = 'App'}) {
    protokollieren(protokoll, art: art, objekt: objekt, text: text);
    return _speichern();
  }

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
    try {
      final k = await datenschluesselHolen();
      return AppStore(prefs, tresor: k == null ? null : Tresor(base64Decode(k)));
    } catch (_) {
      return AppStore(prefs, schluesselFehler: true);
    }
  }

  /// Text fürs Startbildschirm-Widget (liest die Android-Seite direkt).
  Future<void> widgetSetzen(String titel, String text) async {
    await _prefs.setString('widget_titel', titel);
    await _prefs.setString('widget_text', text);
  }

  /// Alle gespeicherten Werte (für die Datensicherung).
  /// Strings kommen entschlüsselt zurück, damit die Sicherung auf jedem Handy lesbar ist
  /// (die Sicherungsdatei selbst ist mit deinem Passwort verschlüsselt).
  Map<String, Object?> alleWerte() => {
        for (final k in _prefs.getKeys())
          k: switch (_prefs.get(k)) {
            final String v when istVerschluesselt(v) && _tresor != null => _tresor!.entschluesseln(v),
            final v => v,
          },
      };

  /// Ersetzt alle gespeicherten Werte (Datensicherung zurückspielen) und lädt neu.
  Future<void> werteErsetzen(Map<String, Object?> werte) async {
    if (lesefehler && _tresor == null) return;
    await _prefs.clear();
    _zuletzt.clear();
    lesefehler = false;
    for (final e in werte.entries) {
      final v = e.value;
      if (v is String) {
        await _prefs.setString(e.key, _tresor == null || _klartext(e.key) || istVerschluesselt(v) ? v : _tresor.verschluesseln(v));
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
    final roh = _get(key);
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
    final a = _get('alltag');
    if (a != null) {
      try {
        alltag = Alltag.fromJson(jsonDecode(a) as Map<String, dynamic>);
      } catch (_) {}
    }
    final fa = _get('familie');
    if (fa != null) {
      try {
        familie = Familie.fromJson(jsonDecode(fa) as Map<String, dynamic>);
      } catch (_) {}
    }
    final vm = _get('vermietung');
    if (vm != null) {
      try {
        vermietung = Vermietung.fromJson(jsonDecode(vm) as Map<String, dynamic>);
      } catch (_) {}
    }
    final kr = _get('karriere');
    if (kr != null) {
      try {
        karriere = Karriere.fromJson(jsonDecode(kr) as Map<String, dynamic>);
      } catch (_) {}
    }
    inventar = _liste('inventar').map(Gegenstand.fromJson).toList();
    final f = _get('firma');
    if (f != null) {
      try {
        firma = Firma.fromJson(jsonDecode(f) as Map<String, dynamic>);
      } catch (_) {}
    }
    final e = _get('erinnerungen');
    if (e != null) {
      try {
        erinnerungen = ErinnerungsEinstellungen.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {}
    }
    final p = _get('profil');
    if (p != null) {
      try {
        profil = Profil.fromJson(jsonDecode(p) as Map<String, dynamic>);
      } catch (_) {}
    }
    final c = _get('checklisten');
    if (c != null) {
      try {
        checklisten = (jsonDecode(c) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v == true));
      } catch (_) {}
    }
    final n = _get('notizen');
    if (n != null) {
      try {
        notizen = (jsonDecode(n) as Map<String, dynamic>).map((k, v) => MapEntry(k, '$v'));
      } catch (_) {}
    }
    onboardingFertig = _prefs.getBool('onboardingFertig') ?? false;
    protokoll = _liste('protokoll').map(ProtokollEintrag.fromJson).toList();
    _rechnungStand = {for (final r in rechnungen) r.id: jsonEncode(r.toJson())};
    _sortieren();
  }

  void _sortieren() {
    briefe.sort((a, b) => b.erstellt.compareTo(a.erstellt));
    belege.sort((a, b) => b.datum.compareTo(a.datum));
  }

  Future<void> _speichern() async {
    if (lesefehler) {
      notifyListeners();
      return;
    }
    _sortieren();
    final aenderungen = rechnungsAenderungen(_rechnungStand, rechnungen);
    for (final (art, objekt, text) in aenderungen) {
      protokollieren(protokoll, art: art, objekt: objekt, text: text);
    }
    if (aenderungen.isNotEmpty) _rechnungStand = {for (final r in rechnungen) r.id: jsonEncode(r.toJson())};
    await _set('protokoll', jsonEncode(protokoll.map((e) => e.toJson()).toList()));
    await _set('briefe', jsonEncode(briefe.map((b) => b.toJson()).toList()));
    await _set('vertraege', jsonEncode(vertraege.map((v) => v.toJson()).toList()));
    await _set('belege', jsonEncode(belege.map((b) => b.toJson()).toList()));
    await _set('profil', jsonEncode(profil.toJson()));
    await _set('checklisten', jsonEncode(checklisten));
    await _set('notizen', jsonEncode(notizen));
    await _set('firma', jsonEncode(firma.toJson()));
    await _set('kunden', jsonEncode(kunden.map((k) => k.toJson()).toList()));
    await _set('rechnungen', jsonEncode(rechnungen.map((r) => r.toJson()).toList()));
    await _set('projekte', jsonEncode(projekte.map((p) => p.toJson()).toList()));
    await _set('zaehler', jsonEncode(zaehler.map((z) => z.toJson()).toList()));
    await _set('artikel', jsonEncode(artikel.map((a) => a.toJson()).toList()));
    await _set('einsaetze', jsonEncode(einsaetze.map((e) => e.toJson()).toList()));
    await _set('stempel', jsonEncode(stempel.map((e) => e.toJson()).toList()));
    await _prefs.setStringList('mitarbeiter', mitarbeiter);
    await _set('sparziele', jsonEncode(sparziele.map((z) => z.toJson()).toList()));
    await _set('alltag', jsonEncode(alltag.toJson()));
    await _set('karriere', jsonEncode(karriere.toJson()));
    await _set('familie', jsonEncode(familie.toJson()));
    await _set('vermietung', jsonEncode(vermietung.toJson()));
    await _set('inventar', jsonEncode(inventar.map((g) => g.toJson()).toList()));
    await _prefs.setBool('onboardingFertig', onboardingFertig);
    await _set('termine', jsonEncode(termine.map((t) => t.toJson()).toList()));
    await _set('erinnerungen', jsonEncode(erinnerungen.toJson()));
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

  /// Festgeschriebene Rechnungen lassen sich nicht löschen, nur stornieren (GoBD).
  Future<void> rechnungLoeschen(Rechnung r) {
    if (r.festgeschrieben) throw StateError('Festgeschriebene Rechnung ${r.nummer} kann nicht gelöscht werden');
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
    protokoll = [];
    _rechnungStand = {};
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
    _zuletzt.clear();
    lesefehler = false;
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
