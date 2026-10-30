/// Daten für Selbstständige: Firmenangaben, Kunden, Rechnungen und Angebote.
library;

DateTime? _datum(Object? v) => v is String ? DateTime.tryParse(v) : null;
double _zahl(Object? v) => v is num ? v.toDouble() : 0;

class Firma {
  Firma({
    this.name = '',
    this.adresse = '',
    this.steuernummer = '',
    this.ustId = '',
    this.kleinunternehmer = false,
    this.iban = '',
    this.bank = '',
    this.bic = '',
    this.email = '',
    this.telefon = '',
    this.zahlungszielTage = 14,
    this.stundensatz = 0,
  });

  /// Lohn pro Stunde (netto) für die Kalkulation.
  double stundensatz;

  String name;
  String adresse;
  String steuernummer;
  String ustId;

  /// Kleinunternehmerregelung (§ 19 UStG): keine Umsatzsteuer auf Rechnungen.
  bool kleinunternehmer;
  String iban;
  String bank;
  String bic;
  String email;
  String telefon;
  int zahlungszielTage;

  bool get leer => name.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'name': name,
        'adresse': adresse,
        'steuernummer': steuernummer,
        'ustId': ustId,
        'kleinunternehmer': kleinunternehmer,
        'iban': iban,
        'bank': bank,
        'bic': bic,
        'email': email,
        'telefon': telefon,
        'zahlungszielTage': zahlungszielTage,
        'stundensatz': stundensatz,
      };

  factory Firma.fromJson(Map<String, dynamic> j) => Firma(
        name: j['name'] as String? ?? '',
        adresse: j['adresse'] as String? ?? '',
        steuernummer: j['steuernummer'] as String? ?? '',
        ustId: j['ustId'] as String? ?? '',
        kleinunternehmer: j['kleinunternehmer'] == true,
        iban: j['iban'] as String? ?? '',
        bank: j['bank'] as String? ?? '',
        bic: j['bic'] as String? ?? '',
        email: j['email'] as String? ?? '',
        telefon: j['telefon'] as String? ?? '',
        zahlungszielTage: (j['zahlungszielTage'] as num?)?.toInt() ?? 14,
        stundensatz: _zahl(j['stundensatz']),
      );
}

class Kunde {
  Kunde({required this.id, required this.name, this.adresse = '', this.email = '', this.notiz = ''});

  final String id;
  String name;
  String adresse;
  String email;
  String notiz;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'adresse': adresse, 'email': email, 'notiz': notiz};

  factory Kunde.fromJson(Map<String, dynamic> j) => Kunde(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        adresse: j['adresse'] as String? ?? '',
        email: j['email'] as String? ?? '',
        notiz: j['notiz'] as String? ?? '',
      );
}

/// Eine Zeile im Aufmaß: Anzahl × Länge × Breite × Höhe (leere Maße zählen nicht).
/// [abzug] = Öffnungen wie Fenster und Türen, werden abgezogen.
class AufmassZeile {
  AufmassZeile({this.text = '', this.anzahl = 1, this.laenge, this.breite, this.hoehe, this.abzug = false});

  String text;
  double anzahl;
  double? laenge;
  double? breite;
  double? hoehe;
  bool abzug;

  double get wert {
    var x = anzahl;
    for (final m in [laenge, breite, hoehe]) {
      if (m != null) x *= m;
    }
    return (abzug ? -x : x);
  }

  Map<String, dynamic> toJson() =>
      {'text': text, 'anzahl': anzahl, 'laenge': laenge, 'breite': breite, 'hoehe': hoehe, 'abzug': abzug};

  factory AufmassZeile.fromJson(Map<String, dynamic> j) => AufmassZeile(
        text: j['text'] as String? ?? '',
        anzahl: (j['anzahl'] as num?)?.toDouble() ?? 1,
        laenge: (j['laenge'] as num?)?.toDouble(),
        breite: (j['breite'] as num?)?.toDouble(),
        hoehe: (j['hoehe'] as num?)?.toDouble(),
        abzug: j['abzug'] == true,
      );
}

/// Artikel oder Leistung im Katalog, mit Kalkulation aus Einkauf, Aufschlag und Arbeitszeit.
class Artikel {
  Artikel({
    required this.id,
    required this.text,
    this.nummer = '',
    this.einheit = 'Stück',
    this.einkauf = 0,
    this.aufschlagProzent = 0,
    this.minuten = 0,
    this.festpreis,
    this.ustSatz = 19,
    this.gruppe = '',
  });

  final String id;
  String text;
  String nummer;
  String einheit;

  /// Einkaufspreis netto je Einheit (Material).
  double einkauf;
  double aufschlagProzent;

  /// Arbeitszeit je Einheit in Minuten (Lohn kommt über den Stundensatz dazu).
  double minuten;

  /// Fester Verkaufspreis netto; überschreibt die Kalkulation.
  double? festpreis;
  int ustSatz;
  String gruppe;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'nummer': nummer,
        'einheit': einheit,
        'einkauf': einkauf,
        'aufschlagProzent': aufschlagProzent,
        'minuten': minuten,
        'festpreis': festpreis,
        'ustSatz': ustSatz,
        'gruppe': gruppe,
      };

  factory Artikel.fromJson(Map<String, dynamic> j) => Artikel(
        id: j['id'] as String,
        text: j['text'] as String? ?? '',
        nummer: j['nummer'] as String? ?? '',
        einheit: j['einheit'] as String? ?? 'Stück',
        einkauf: _zahl(j['einkauf']),
        aufschlagProzent: _zahl(j['aufschlagProzent']),
        minuten: _zahl(j['minuten']),
        festpreis: (j['festpreis'] as num?)?.toDouble(),
        ustSatz: (j['ustSatz'] as num?)?.toInt() ?? 19,
        gruppe: j['gruppe'] as String? ?? '',
      );
}

class Position {
  Position({
    required this.text,
    this.menge = 1,
    this.einheit = 'Stück',
    this.preis = 0,
    this.ustSatz = 19,
    List<AufmassZeile>? aufmass,
    this.einkauf = 0,
    this.minuten = 0,
  }) : aufmass = aufmass ?? [];

  /// Aufmaß, aus dem die Menge berechnet wurde (leer = Menge von Hand).
  List<AufmassZeile> aufmass;

  /// Für die Nachkalkulation: Material-Einkauf und Arbeitszeit je Einheit.
  double einkauf;
  double minuten;

  String text;
  double menge;
  String einheit;

  /// Einzelpreis netto.
  double preis;

  /// 19, 7 oder 0 Prozent.
  int ustSatz;

  double get netto => (menge * preis * 100).round() / 100;

  Map<String, dynamic> toJson() => {
        'text': text,
        'menge': menge,
        'einheit': einheit,
        'preis': preis,
        'ustSatz': ustSatz,
        if (aufmass.isNotEmpty) 'aufmass': aufmass.map((a) => a.toJson()).toList(),
        if (einkauf != 0) 'einkauf': einkauf,
        if (minuten != 0) 'minuten': minuten,
      };

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        text: j['text'] as String? ?? '',
        menge: _zahl(j['menge']),
        einheit: j['einheit'] as String? ?? 'Stück',
        preis: _zahl(j['preis']),
        ustSatz: (j['ustSatz'] as num?)?.toInt() ?? 19,
        aufmass: (j['aufmass'] as List?)?.whereType<Map<String, dynamic>>().map(AufmassZeile.fromJson).toList(),
        einkauf: _zahl(j['einkauf']),
        minuten: _zahl(j['minuten']),
      );
}

/// Alle Belegarten im Gewerbe.
const belegArten = ['angebot', 'kostenvoranschlag', 'auftragsbestaetigung', 'lieferschein', 'abschlag', 'rechnung', 'schluss'];

String belegArtName(String art) => switch (art) {
      'angebot' => 'Angebot',
      'kostenvoranschlag' => 'Kostenvoranschlag',
      'auftragsbestaetigung' => 'Auftragsbestätigung',
      'lieferschein' => 'Lieferschein',
      'abschlag' => 'Abschlagsrechnung',
      'schluss' => 'Schlussrechnung',
      _ => 'Rechnung',
    };

/// Rechnung, Angebot oder ein anderer Beleg aus [belegArten].
class Rechnung {
  Rechnung({
    required this.id,
    required this.art,
    required this.nummer,
    required this.kundeId,
    required this.datum,
    this.leistungVon,
    this.leistungBis,
    List<Position>? positionen,
    this.zahlungszielTage = 14,
    this.bezahltAm,
    this.notiz = '',
    this.gemahntAm,
    this.storniert = false,
    this.wiederholungMonate = 0,
    this.projektId,
    this.rabattProzent = 0,
    this.rabattBetrag = 0,
    this.bezugId,
    this.mahnstufe = 0,
    this.versendetAm,
  }) : positionen = positionen ?? [];

  /// Rabatt auf die Zwischensumme (netto): Prozent und/oder fester Betrag.
  double rabattProzent;
  double rabattBetrag;

  /// Auftrag bzw. Angebot, auf das sich Abschlags- und Schlussrechnungen beziehen.
  String? bezugId;

  /// 0 = nicht gemahnt, 1 = Zahlungserinnerung, 2 = 1. Mahnung, 3 = letzte Mahnung.
  int mahnstufe;

  /// Wann an den Kunden verschickt (von dir vermerkt).
  DateTime? versendetAm;

  /// Wiederkehrende Rechnung: alle n Monate neu (0 = einmalig).
  int wiederholungMonate;

  /// Zugehöriges Projekt.
  String? projektId;

  final String id;

  /// Siehe [belegArten].
  String art;
  String nummer;
  String kundeId;
  DateTime datum;
  DateTime? leistungVon;
  DateTime? leistungBis;
  List<Position> positionen;
  int zahlungszielTage;
  DateTime? bezahltAm;
  String notiz;
  DateTime? gemahntAm;
  bool storniert;

  /// Angebot oder Kostenvoranschlag (noch keine Rechnung).
  bool get istAngebot => art == 'angebot' || art == 'kostenvoranschlag';

  /// Zahlbare Rechnung (normale, Abschlags- oder Schlussrechnung).
  bool get istRechnung => art == 'rechnung' || art == 'abschlag' || art == 'schluss';

  String get artName => belegArtName(art);

  Map<String, dynamic> toJson() => {
        'id': id,
        'art': art,
        'nummer': nummer,
        'kundeId': kundeId,
        'datum': datum.toIso8601String(),
        'leistungVon': leistungVon?.toIso8601String(),
        'leistungBis': leistungBis?.toIso8601String(),
        'positionen': positionen.map((p) => p.toJson()).toList(),
        'zahlungszielTage': zahlungszielTage,
        'bezahltAm': bezahltAm?.toIso8601String(),
        'notiz': notiz,
        'gemahntAm': gemahntAm?.toIso8601String(),
        'storniert': storniert,
        'wiederholungMonate': wiederholungMonate,
        'projektId': projektId,
        'rabattProzent': rabattProzent,
        'rabattBetrag': rabattBetrag,
        'bezugId': bezugId,
        'mahnstufe': mahnstufe,
        'versendetAm': versendetAm?.toIso8601String(),
      };

  factory Rechnung.fromJson(Map<String, dynamic> j) => Rechnung(
        id: j['id'] as String,
        art: j['art'] as String? ?? 'rechnung',
        nummer: j['nummer'] as String? ?? '',
        kundeId: j['kundeId'] as String? ?? '',
        datum: _datum(j['datum']) ?? DateTime.now(),
        leistungVon: _datum(j['leistungVon']),
        leistungBis: _datum(j['leistungBis']),
        positionen: (j['positionen'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Position.fromJson)
                .toList() ??
            [],
        zahlungszielTage: (j['zahlungszielTage'] as num?)?.toInt() ?? 14,
        bezahltAm: _datum(j['bezahltAm']),
        notiz: j['notiz'] as String? ?? '',
        gemahntAm: _datum(j['gemahntAm']),
        storniert: j['storniert'] == true,
        wiederholungMonate: (j['wiederholungMonate'] as num?)?.toInt() ?? 0,
        projektId: j['projektId'] as String?,
        rabattProzent: _zahl(j['rabattProzent']),
        rabattBetrag: _zahl(j['rabattBetrag']),
        bezugId: j['bezugId'] as String?,
        mahnstufe: (j['mahnstufe'] as num?)?.toInt() ?? (j['gemahntAm'] != null ? 1 : 0),
        versendetAm: _datum(j['versendetAm']),
      );
}


// ---------------------------------------------------------------- Baustelle

class Baufoto {
  Baufoto({required this.pfad, required this.datum, this.text = ''});

  final String pfad;
  final DateTime datum;
  String text;

  Map<String, dynamic> toJson() => {'pfad': pfad, 'datum': datum.toIso8601String(), 'text': text};

  factory Baufoto.fromJson(Map<String, dynamic> j) =>
      Baufoto(pfad: j['pfad'] as String? ?? '', datum: _datum(j['datum']) ?? DateTime.now(), text: j['text'] as String? ?? '');
}

/// Ein Tag im Bautagebuch.
class Tagesbericht {
  Tagesbericht({
    required this.datum,
    this.wetter = '',
    this.personen = '',
    this.arbeiten = '',
    this.material = '',
    this.besonderheiten = '',
  });

  DateTime datum;
  String wetter;
  String personen;
  String arbeiten;
  String material;
  String besonderheiten;

  Map<String, dynamic> toJson() => {
        'datum': datum.toIso8601String(),
        'wetter': wetter,
        'personen': personen,
        'arbeiten': arbeiten,
        'material': material,
        'besonderheiten': besonderheiten,
      };

  factory Tagesbericht.fromJson(Map<String, dynamic> j) => Tagesbericht(
        datum: _datum(j['datum']) ?? DateTime.now(),
        wetter: j['wetter'] as String? ?? '',
        personen: j['personen'] as String? ?? '',
        arbeiten: j['arbeiten'] as String? ?? '',
        material: j['material'] as String? ?? '',
        besonderheiten: j['besonderheiten'] as String? ?? '',
      );
}

/// Regiebericht (Zusatzarbeiten) oder Abnahmeprotokoll, auf Wunsch vom Kunden unterschrieben.
class Baubericht {
  Baubericht({
    required this.id,
    required this.art,
    required this.datum,
    this.text = '',
    this.stunden = 0,
    this.personen = '',
    this.material = '',
    this.maengel = '',
    this.unterschrift,
    this.unterschriftName = '',
    this.unterschriebenAm,
    this.abgerechnet = false,
  });

  final String id;

  /// 'regie' oder 'abnahme'
  final String art;
  DateTime datum;

  /// Regie: ausgeführte Zusatzarbeiten. Abnahme: abgenommene Leistung.
  String text;
  double stunden;
  String personen;
  String material;

  /// Abnahme: festgestellte Mängel (leer = keine).
  String maengel;

  /// Bild der Unterschrift (PNG).
  String? unterschrift;
  String unterschriftName;
  DateTime? unterschriebenAm;

  /// Regie: schon in eine Rechnung übernommen.
  bool abgerechnet;

  String get titel => art == 'abnahme' ? 'Abnahmeprotokoll' : 'Regiebericht';

  Map<String, dynamic> toJson() => {
        'id': id,
        'art': art,
        'datum': datum.toIso8601String(),
        'text': text,
        'stunden': stunden,
        'personen': personen,
        'material': material,
        'maengel': maengel,
        'unterschrift': unterschrift,
        'unterschriftName': unterschriftName,
        'unterschriebenAm': unterschriebenAm?.toIso8601String(),
        'abgerechnet': abgerechnet,
      };

  factory Baubericht.fromJson(Map<String, dynamic> j) => Baubericht(
        id: j['id'] as String,
        art: j['art'] as String? ?? 'regie',
        datum: _datum(j['datum']) ?? DateTime.now(),
        text: j['text'] as String? ?? '',
        stunden: _zahl(j['stunden']),
        personen: j['personen'] as String? ?? '',
        material: j['material'] as String? ?? '',
        maengel: j['maengel'] as String? ?? '',
        unterschrift: j['unterschrift'] as String?,
        unterschriftName: j['unterschriftName'] as String? ?? '',
        unterschriebenAm: _datum(j['unterschriebenAm']),
        abgerechnet: j['abgerechnet'] == true,
      );
}

// ---------------------------------------------------------------- Projekte

const projektStatus = ['Anfrage', 'Angebot', 'Auftrag', 'In Arbeit', 'Fertig', 'Abgerechnet'];

class Zeiteintrag {
  Zeiteintrag({required this.datum, required this.stunden, this.person = '', this.text = ''});

  final DateTime datum;
  final double stunden;
  final String person;
  final String text;

  Map<String, dynamic> toJson() => {'datum': datum.toIso8601String(), 'stunden': stunden, 'person': person, 'text': text};

  factory Zeiteintrag.fromJson(Map<String, dynamic> j) => Zeiteintrag(
        datum: _datum(j['datum']) ?? DateTime.now(),
        stunden: _zahl(j['stunden']),
        person: j['person'] as String? ?? '',
        text: j['text'] as String? ?? '',
      );
}

class Materialposten {
  Materialposten({required this.text, this.menge = 1, this.einheit = 'Stück', this.preis = 0, this.bestellt = false});

  String text;
  double menge;
  String einheit;

  /// Einkaufspreis netto pro Einheit.
  double preis;
  bool bestellt;

  double get summe => (menge * preis * 100).round() / 100;

  Map<String, dynamic> toJson() => {'text': text, 'menge': menge, 'einheit': einheit, 'preis': preis, 'bestellt': bestellt};

  factory Materialposten.fromJson(Map<String, dynamic> j) => Materialposten(
        text: j['text'] as String? ?? '',
        menge: _zahl(j['menge']),
        einheit: j['einheit'] as String? ?? 'Stück',
        preis: _zahl(j['preis']),
        bestellt: j['bestellt'] == true,
      );
}

class ProjektAufgabe {
  ProjektAufgabe({required this.text, this.person = '', this.erledigt = false, this.bis});

  String text;
  String person;
  bool erledigt;
  DateTime? bis;

  Map<String, dynamic> toJson() => {'text': text, 'person': person, 'erledigt': erledigt, 'bis': bis?.toIso8601String()};

  factory ProjektAufgabe.fromJson(Map<String, dynamic> j) => ProjektAufgabe(
        text: j['text'] as String? ?? '',
        person: j['person'] as String? ?? '',
        erledigt: j['erledigt'] == true,
        bis: _datum(j['bis']),
      );
}

class Protokoll {
  Protokoll({required this.datum, required this.text, this.teilnehmer = ''});

  final DateTime datum;
  final String text;
  final String teilnehmer;

  Map<String, dynamic> toJson() => {'datum': datum.toIso8601String(), 'text': text, 'teilnehmer': teilnehmer};

  factory Protokoll.fromJson(Map<String, dynamic> j) => Protokoll(
        datum: _datum(j['datum']) ?? DateTime.now(),
        text: j['text'] as String? ?? '',
        teilnehmer: j['teilnehmer'] as String? ?? '',
      );
}

List<T> _liste<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    (v as List?)?.whereType<Map<String, dynamic>>().map(f).toList() ?? <T>[];

class Projekt {
  Projekt({
    required this.id,
    required this.name,
    this.kundeId = '',
    this.status = 'Anfrage',
    this.stundensatz = 0,
    this.angebotId,
    this.notiz = '',
    DateTime? erstellt,
    List<Zeiteintrag>? zeiten,
    List<Materialposten>? material,
    List<ProjektAufgabe>? aufgaben,
    List<Protokoll>? protokolle,
    List<Baufoto>? fotos,
    List<Tagesbericht>? tagebuch,
    List<Baubericht>? berichte,
    this.adresse = '',
  })  : fotos = fotos ?? [],
        tagebuch = tagebuch ?? [],
        berichte = berichte ?? [],
        erstellt = erstellt ?? DateTime.now(),
        zeiten = zeiten ?? [],
        material = material ?? [],
        aufgaben = aufgaben ?? [],
        protokolle = protokolle ?? [];

  final String id;
  String name;
  String kundeId;
  String status;

  /// Stundensatz netto für die Nachkalkulation und die Rechnung.
  double stundensatz;
  String? angebotId;
  String notiz;
  final DateTime erstellt;
  List<Zeiteintrag> zeiten;
  List<Materialposten> material;
  List<ProjektAufgabe> aufgaben;
  List<Protokoll> protokolle;
  List<Baufoto> fotos;
  List<Tagesbericht> tagebuch;
  List<Baubericht> berichte;

  /// Adresse der Baustelle bzw. des Einsatzorts.
  String adresse;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kundeId': kundeId,
        'status': status,
        'stundensatz': stundensatz,
        'angebotId': angebotId,
        'notiz': notiz,
        'erstellt': erstellt.toIso8601String(),
        'zeiten': zeiten.map((z) => z.toJson()).toList(),
        'material': material.map((m) => m.toJson()).toList(),
        'aufgaben': aufgaben.map((a) => a.toJson()).toList(),
        'protokolle': protokolle.map((p) => p.toJson()).toList(),
        'fotos': fotos.map((f) => f.toJson()).toList(),
        'tagebuch': tagebuch.map((t) => t.toJson()).toList(),
        'berichte': berichte.map((b) => b.toJson()).toList(),
        'adresse': adresse,
      };

  factory Projekt.fromJson(Map<String, dynamic> j) => Projekt(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        kundeId: j['kundeId'] as String? ?? '',
        status: j['status'] as String? ?? 'Anfrage',
        stundensatz: _zahl(j['stundensatz']),
        angebotId: j['angebotId'] as String?,
        notiz: j['notiz'] as String? ?? '',
        erstellt: _datum(j['erstellt']),
        zeiten: _liste(j['zeiten'], Zeiteintrag.fromJson),
        material: _liste(j['material'], Materialposten.fromJson),
        aufgaben: _liste(j['aufgaben'], ProjektAufgabe.fromJson),
        protokolle: _liste(j['protokolle'], Protokoll.fromJson),
        fotos: _liste(j['fotos'], Baufoto.fromJson),
        tagebuch: _liste(j['tagebuch'], Tagesbericht.fromJson),
        berichte: _liste(j['berichte'], Baubericht.fromJson),
        adresse: j['adresse'] as String? ?? '',
      );
}


// ---------------------------------------------------------------- Plantafel

/// Einsatz von Mitarbeitern auf einem Projekt – oder Abwesenheit (Urlaub, krank, Schlechtwetter).
class Einsatz {
  Einsatz({
    required this.id,
    required this.von,
    required this.bis,
    List<String>? personen,
    this.projektId,
    this.art = 'Projekt',
    this.notiz = '',
  }) : personen = personen ?? [];

  final String id;

  /// Erster und letzter Tag (einschließlich).
  DateTime von;
  DateTime bis;
  List<String> personen;

  /// Leer bei Abwesenheit.
  String? projektId;

  /// 'Projekt', 'Urlaub', 'Krank', 'Schlechtwetter', 'Schule'
  String art;
  String notiz;

  Map<String, dynamic> toJson() => {
        'id': id,
        'von': von.toIso8601String(),
        'bis': bis.toIso8601String(),
        'personen': personen,
        'projektId': projektId,
        'art': art,
        'notiz': notiz,
      };

  factory Einsatz.fromJson(Map<String, dynamic> j) => Einsatz(
        id: j['id'] as String,
        von: _datum(j['von']) ?? DateTime.now(),
        bis: _datum(j['bis']) ?? DateTime.now(),
        personen: (j['personen'] as List?)?.whereType<String>().toList(),
        projektId: j['projektId'] as String?,
        art: j['art'] as String? ?? 'Projekt',
        notiz: j['notiz'] as String? ?? '',
      );
}

const einsatzArten = ['Projekt', 'Urlaub', 'Krank', 'Schlechtwetter', 'Schule'];
