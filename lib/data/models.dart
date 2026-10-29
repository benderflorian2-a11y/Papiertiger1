/// Datenmodelle der App. Alles wird als JSON auf dem Handy gespeichert.
library;

import '../logic/rente.dart' show Fakt;

export '../logic/rente.dart' show Fakt;

DateTime? _datum(Object? v) => v is String ? DateTime.tryParse(v) : null;
double? _zahl(Object? v) => v is num ? v.toDouble() : null;
String neueId() => DateTime.now().microsecondsSinceEpoch.toString();

class Aufgabe {
  Aufgabe(this.text, {this.erledigt = false});

  String text;
  bool erledigt;

  Map<String, dynamic> toJson() => {'text': text, 'erledigt': erledigt};

  factory Aufgabe.fromJson(Map<String, dynamic> j) =>
      Aufgabe(j['text'] as String? ?? '', erledigt: j['erledigt'] == true);
}

/// Ein Eintrag im Schriftverkehr zu einem Brief: gesendet, erhalten, Anruf, Notiz.
class Eintrag {
  Eintrag({
    required this.id,
    required this.datum,
    required this.art,
    this.weg = '',
    this.text = '',
    this.sendungsnummer,
    this.person,
  });

  final String id;
  DateTime datum;

  /// gesendet, erhalten, anruf, notiz
  String art;

  /// Post, Einschreiben, E-Mail, Fax, Online-Portal, Persönlich abgegeben, Telefon
  String weg;
  String text;
  String? sendungsnummer;

  /// Ansprechpartner, z. B. bei einem Anruf.
  String? person;

  Map<String, dynamic> toJson() => {
        'id': id,
        'datum': datum.toIso8601String(),
        'art': art,
        'weg': weg,
        'text': text,
        'sendungsnummer': sendungsnummer,
        'person': person,
      };

  factory Eintrag.fromJson(Map<String, dynamic> j) => Eintrag(
        id: j['id'] as String? ?? neueId(),
        datum: _datum(j['datum']) ?? DateTime.now(),
        art: j['art'] as String? ?? 'notiz',
        weg: j['weg'] as String? ?? '',
        text: j['text'] as String? ?? '',
        sendungsnummer: j['sendungsnummer'] as String?,
        person: j['person'] as String?,
      );
}

class Brief {
  Brief({
    required this.id,
    required this.erstellt,
    required this.kategorie,
    required this.typ,
    required this.text,
    required this.erklaerung,
    this.absenderName,
    this.bilder = const [],
    this.frist,
    this.fristUnsicher = false,
    this.betrag,
    this.guthaben = false,
    this.aktenzeichen,
    this.briefDatum,
    List<Aufgabe>? aufgaben,
    this.erledigt = false,
    this.steuerKategorie,
    List<Fakt>? fakten,
    List<String>? bedeutung,
    this.kiFertig = false,
    this.kiArt,
    this.titel,
    this.pdfPfad,
    this.duplikatVon,
    this.kiDringlichkeit,
    this.person,
    List<Aufgabe>? unterlagen,
    List<String>? hinweise,
    this.antwortGesendet,
    this.nachfassenAm,
    List<Eintrag>? verlauf,
    this.bezahltAm,
  })  : verlauf = verlauf ?? [],
        unterlagen = unterlagen ?? [],
        hinweise = hinweise ?? [],
        aufgaben = aufgaben ?? [],
        fakten = fakten ?? [],
        bedeutung = bedeutung ?? [];

  final String id;
  final DateTime erstellt;
  String kategorie;
  String typ;
  String? absenderName;
  String text;
  String erklaerung;
  List<String> bilder;
  DateTime? frist;
  bool fristUnsicher;
  double? betrag;
  bool guthaben;
  String? aktenzeichen;
  DateTime? briefDatum;
  List<Aufgabe> aufgaben;
  bool erledigt;
  String? steuerKategorie;

  /// „Das steht drin“: wichtige Angaben aus dem Brief.
  List<Fakt> fakten;

  /// „Was heißt das für dich?“
  List<String> bedeutung;

  /// Hat die KI den ganzen Brief schon gelesen?
  bool kiFertig;

  /// Art des Briefs laut KI, z. B. „Renteninformation“.
  String? kiArt;

  /// Eigener Titel; null = automatischer Titel.
  String? titel;

  /// Original-PDF, falls als PDF importiert.
  String? pdfPfad;

  /// Id des Briefs, von dem dieser vermutlich ein Duplikat ist.
  String? duplikatVon;

  /// Dringlichkeit laut KI: 0 niedrig, 1 mittel, 2 hoch.
  int? kiDringlichkeit;

  /// An wen der Brief gerichtet ist.
  String? person;

  /// Unterlagen, die der Absender verlangt (abhakbar).
  List<Aufgabe> unterlagen;

  /// „Bitte prüfen“: Widersprüche oder fehlende Angaben laut KI.
  List<String> hinweise;

  /// Wann der Nutzer geantwortet bzw. Unterlagen geschickt hat.
  DateTime? antwortGesendet;

  /// Ab wann nachgefasst werden soll, wenn keine Antwort kommt.
  DateTime? nachfassenAm;

  /// Schriftverkehr: gesendete Antworten, Anrufe, Notizen.
  List<Eintrag> verlauf;

  /// Wann du den Betrag bezahlt hast (von dir vermerkt).
  DateTime? bezahltAm;

  Map<String, dynamic> toJson() => {
        'id': id,
        'erstellt': erstellt.toIso8601String(),
        'kategorie': kategorie,
        'typ': typ,
        'absenderName': absenderName,
        'text': text,
        'erklaerung': erklaerung,
        'bilder': bilder,
        'frist': frist?.toIso8601String(),
        'fristUnsicher': fristUnsicher,
        'betrag': betrag,
        'guthaben': guthaben,
        'aktenzeichen': aktenzeichen,
        'briefDatum': briefDatum?.toIso8601String(),
        'aufgaben': aufgaben.map((a) => a.toJson()).toList(),
        'erledigt': erledigt,
        'steuerKategorie': steuerKategorie,
        'fakten': fakten.map((f) => f.toJson()).toList(),
        'bedeutung': bedeutung,
        'kiFertig': kiFertig,
        'kiArt': kiArt,
        'titel': titel,
        'pdfPfad': pdfPfad,
        'duplikatVon': duplikatVon,
        'kiDringlichkeit': kiDringlichkeit,
        'person': person,
        'unterlagen': unterlagen.map((a) => a.toJson()).toList(),
        'hinweise': hinweise,
        'antwortGesendet': antwortGesendet?.toIso8601String(),
        'nachfassenAm': nachfassenAm?.toIso8601String(),
        'verlauf': verlauf.map((e) => e.toJson()).toList(),
        'bezahltAm': bezahltAm?.toIso8601String(),
      };

  factory Brief.fromJson(Map<String, dynamic> j) => Brief(
        id: j['id'] as String,
        erstellt: _datum(j['erstellt']) ?? DateTime.now(),
        kategorie: j['kategorie'] as String? ?? 'sonstiges',
        typ: j['typ'] as String? ?? 'schreiben',
        absenderName: j['absenderName'] as String?,
        text: j['text'] as String? ?? '',
        erklaerung: j['erklaerung'] as String? ?? '',
        bilder: (j['bilder'] as List?)?.whereType<String>().toList() ?? [],
        frist: _datum(j['frist']),
        fristUnsicher: j['fristUnsicher'] == true,
        betrag: _zahl(j['betrag']),
        guthaben: j['guthaben'] == true,
        aktenzeichen: j['aktenzeichen'] as String?,
        briefDatum: _datum(j['briefDatum']),
        aufgaben: (j['aufgaben'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Aufgabe.fromJson)
                .toList() ??
            [],
        erledigt: j['erledigt'] == true,
        steuerKategorie: j['steuerKategorie'] as String?,
        fakten: (j['fakten'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Fakt.fromJson)
                .toList() ??
            [],
        bedeutung: (j['bedeutung'] as List?)?.whereType<String>().toList() ?? [],
        kiFertig: j['kiFertig'] == true,
        kiArt: j['kiArt'] as String?,
        titel: j['titel'] as String?,
        pdfPfad: j['pdfPfad'] as String?,
        duplikatVon: j['duplikatVon'] as String?,
        kiDringlichkeit: (j['kiDringlichkeit'] as num?)?.toInt(),
        person: j['person'] as String?,
        unterlagen: (j['unterlagen'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Aufgabe.fromJson)
                .toList() ??
            [],
        hinweise: (j['hinweise'] as List?)?.whereType<String>().toList() ?? [],
        antwortGesendet: _datum(j['antwortGesendet']),
        nachfassenAm: _datum(j['nachfassenAm']),
        verlauf: (j['verlauf'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Eintrag.fromJson)
                .toList() ??
            [],
        bezahltAm: _datum(j['bezahltAm']),
      );
}

class Vertrag {
  Vertrag({
    required this.id,
    required this.anbieter,
    required this.art,
    required this.beginn,
    this.laufzeitMonate = 24,
    this.fristWert = 1,
    this.fristInWochen = false,
    this.kostenMonat,
    this.gekuendigt = false,
    this.nummer,
    this.zahlweiseMonate = 1,
    this.versicherungsArt,
    this.notiz = '',
    this.gekuendigtAm,
    this.bestaetigt = false,
    List<String>? briefIds,
  }) : briefIds = briefIds ?? [];

  final String id;
  String anbieter;
  String art;
  DateTime beginn;
  int laufzeitMonate;
  int fristWert;
  bool fristInWochen;
  double? kostenMonat;
  bool gekuendigt;

  /// Vertrags-, Kunden- oder Versicherungsnummer.
  String? nummer;

  /// Wie oft gezahlt wird: 1 monatlich, 3 vierteljährlich, 6 halbjährlich, 12 jährlich.
  int zahlweiseMonate;

  /// Bei Versicherungen: z. B. Privathaftpflicht, Hausrat.
  String? versicherungsArt;
  String notiz;

  /// Wann die Kündigung verschickt wurde.
  DateTime? gekuendigtAm;

  /// Kündigungsbestätigung erhalten?
  bool bestaetigt;

  /// Briefe, die zu diesem Vertrag gehören.
  List<String> briefIds;

  /// Betrag pro Zahlung (z. B. Jahresbeitrag bei jährlicher Zahlung).
  double? get betragProZahlung => kostenMonat == null ? null : kostenMonat! * zahlweiseMonate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'anbieter': anbieter,
        'art': art,
        'beginn': beginn.toIso8601String(),
        'laufzeitMonate': laufzeitMonate,
        'fristWert': fristWert,
        'fristInWochen': fristInWochen,
        'kostenMonat': kostenMonat,
        'gekuendigt': gekuendigt,
        'nummer': nummer,
        'zahlweiseMonate': zahlweiseMonate,
        'versicherungsArt': versicherungsArt,
        'notiz': notiz,
        'gekuendigtAm': gekuendigtAm?.toIso8601String(),
        'bestaetigt': bestaetigt,
        'briefIds': briefIds,
      };

  factory Vertrag.fromJson(Map<String, dynamic> j) => Vertrag(
        id: j['id'] as String,
        anbieter: j['anbieter'] as String? ?? '',
        art: j['art'] as String? ?? 'Sonstiges',
        beginn: _datum(j['beginn']) ?? DateTime.now(),
        laufzeitMonate: (j['laufzeitMonate'] as num?)?.toInt() ?? 24,
        fristWert: (j['fristWert'] as num?)?.toInt() ?? 1,
        fristInWochen: j['fristInWochen'] == true,
        kostenMonat: _zahl(j['kostenMonat']),
        gekuendigt: j['gekuendigt'] == true,
        nummer: j['nummer'] as String?,
        zahlweiseMonate: (j['zahlweiseMonate'] as num?)?.toInt() ?? 1,
        versicherungsArt: j['versicherungsArt'] as String?,
        notiz: j['notiz'] as String? ?? '',
        gekuendigtAm: _datum(j['gekuendigtAm']),
        bestaetigt: j['bestaetigt'] == true,
        briefIds: (j['briefIds'] as List?)?.whereType<String>().toList() ?? [],
      );
}

class Beleg {
  Beleg({
    required this.id,
    required this.haendler,
    required this.datum,
    this.betrag,
    this.garantieMonate = 24,
    this.bild,
    this.steuerKategorie,
    this.notiz = '',
    this.geschaeftlich = false,
  });

  final String id;

  /// Betriebsausgabe (für Selbstständige).
  bool geschaeftlich;
  String haendler;
  DateTime datum;
  double? betrag;
  int garantieMonate;
  String? bild;
  String? steuerKategorie;
  String notiz;

  DateTime get garantieEnde => DateTime(
      datum.year, datum.month + garantieMonate, datum.day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'haendler': haendler,
        'datum': datum.toIso8601String(),
        'betrag': betrag,
        'garantieMonate': garantieMonate,
        'bild': bild,
        'steuerKategorie': steuerKategorie,
        'notiz': notiz,
        'geschaeftlich': geschaeftlich,
      };

  factory Beleg.fromJson(Map<String, dynamic> j) => Beleg(
        id: j['id'] as String,
        haendler: j['haendler'] as String? ?? '',
        datum: _datum(j['datum']) ?? DateTime.now(),
        betrag: _zahl(j['betrag']),
        garantieMonate: (j['garantieMonate'] as num?)?.toInt() ?? 24,
        bild: j['bild'] as String?,
        steuerKategorie: j['steuerKategorie'] as String?,
        notiz: j['notiz'] as String? ?? '',
        geschaeftlich: j['geschaeftlich'] == true,
      );
}

/// Ein eigener, ggf. wiederkehrender Termin (TÜV, Wartung, Versicherung …).
class Termin {
  Termin({
    required this.id,
    required this.titel,
    required this.datum,
    this.wiederholungMonate = 0,
    this.notiz = '',
    this.art = 'Sonstiges',
    this.erledigt = false,
    this.briefId,
  });

  final String id;
  String titel;
  DateTime datum;

  /// 0 = einmalig, sonst Abstand in Monaten (1, 3, 6, 12, 24).
  int wiederholungMonate;
  String notiz;
  String art;
  bool erledigt;

  /// Aus welchem Brief der Termin stammt.
  String? briefId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'titel': titel,
        'datum': datum.toIso8601String(),
        'wiederholungMonate': wiederholungMonate,
        'notiz': notiz,
        'art': art,
        'erledigt': erledigt,
        'briefId': briefId,
      };

  factory Termin.fromJson(Map<String, dynamic> j) => Termin(
        id: j['id'] as String,
        titel: j['titel'] as String? ?? '',
        datum: _datum(j['datum']) ?? DateTime.now(),
        wiederholungMonate: (j['wiederholungMonate'] as num?)?.toInt() ?? 0,
        notiz: j['notiz'] as String? ?? '',
        art: j['art'] as String? ?? 'Sonstiges',
        erledigt: j['erledigt'] == true,
        briefId: j['briefId'] as String?,
      );
}

const terminArten = ['TÜV / Auto', 'Wartung', 'Versicherung', 'Arzt', 'Behörde', 'Zahlung', 'Sonstiges'];

/// Einstellungen für Push-Erinnerungen.
class ErinnerungsEinstellungen {
  ErinnerungsEinstellungen({
    this.aktiv = true,
    List<int>? tageVorher,
    this.stunde = 9,
    this.wochenueberblick = true,
  }) : tageVorher = tageVorher ?? [7, 3, 1, 0];

  bool aktiv;
  List<int> tageVorher;
  int stunde;
  bool wochenueberblick;

  Map<String, dynamic> toJson() =>
      {'aktiv': aktiv, 'tageVorher': tageVorher, 'stunde': stunde, 'wochenueberblick': wochenueberblick};

  factory ErinnerungsEinstellungen.fromJson(Map<String, dynamic> j) => ErinnerungsEinstellungen(
        aktiv: j['aktiv'] != false,
        tageVorher: (j['tageVorher'] as List?)?.whereType<num>().map((n) => n.toInt()).toList(),
        stunde: (j['stunde'] as num?)?.toInt() ?? 9,
        wochenueberblick: j['wochenueberblick'] != false,
      );
}

/// Zusätzliche Profilangaben für die Formular-Ausfüllhilfe.
const profilFelder = <(String, String)>[
  ('geburtsdatum', 'Geburtsdatum'),
  ('geburtsort', 'Geburtsort'),
  ('familienstand', 'Familienstand'),
  ('staatsangehoerigkeit', 'Staatsangehörigkeit'),
  ('telefon', 'Telefon'),
  ('email', 'E-Mail'),
  ('iban', 'IBAN'),
  ('bank', 'Bank'),
  ('steuerid', 'Steuer-ID'),
  ('krankenkasse', 'Krankenkasse'),
  ('versichertennummer', 'Krankenversichertennummer'),
  ('rentenversicherungsnummer', 'Rentenversicherungsnummer'),
  ('arbeitgeber', 'Arbeitgeber'),
  ('beruf', 'Beruf'),
];

class Profil {
  Profil({this.name = '', this.adresse = '', Map<String, String>? extra}) : extra = extra ?? {};

  String name;
  String adresse;

  /// Weitere Angaben, Schlüssel aus [profilFelder].
  Map<String, String> extra;

  String get vorname => name.trim().split(RegExp(r'\s+')).first;
  String get nachname {
    final t = name.trim().split(RegExp(r'\s+'));
    return t.length > 1 ? t.sublist(1).join(' ') : '';
  }

  Map<String, dynamic> toJson() => {'name': name, 'adresse': adresse, 'extra': extra};

  factory Profil.fromJson(Map<String, dynamic> j) => Profil(
        name: j['name'] as String? ?? '',
        adresse: j['adresse'] as String? ?? '',
        extra: (j['extra'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {},
      );
}

const steuerKategorien = [
  'Arbeitsmittel',
  'Fahrtkosten',
  'Fortbildung',
  'Handwerkerleistungen',
  'Haushaltsnahe Dienstleistungen',
  'Krankheitskosten',
  'Spenden',
  'Versicherungen',
  'Sonstiges',
];

const vertragsArten = [
  'Handy',
  'Internet',
  'Strom',
  'Gas',
  'Fitnessstudio',
  'Streaming',
  'Versicherung',
  'Zeitschrift',
  'Sonstiges',
];

const zahlweisen = <(int, String)>[(1, 'monatlich'), (3, 'vierteljährlich'), (6, 'halbjährlich'), (12, 'jährlich')];

const versicherungsArten = [
  'Privathaftpflicht',
  'Hausrat',
  'Kfz',
  'Berufsunfähigkeit',
  'Kranken-Zusatz',
  'Rechtsschutz',
  'Wohngebäude',
  'Unfall',
  'Risikoleben',
  'Zahnzusatz',
  'Reise',
  'Tier',
  'Sonstige',
];
