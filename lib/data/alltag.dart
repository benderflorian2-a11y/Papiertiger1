/// Daten für den privaten Alltag: Einkauf, Vorräte, Essensplan, Haushaltsaufgaben,
/// Geschenke und Reisen. Alles in einem Objekt, gespeichert als ein JSON.
library;

DateTime? _datum(Object? v) => v is String ? DateTime.tryParse(v) : null;
double? _zahl(Object? v) => v is num ? v.toDouble() : null;
List<T> _liste<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    (v as List?)?.whereType<Map<String, dynamic>>().map(f).toList() ?? <T>[];

class Einkauf {
  Einkauf({required this.text, this.kategorie, this.erledigt = false, this.immer = false});

  String text;

  /// null = automatisch.
  String? kategorie;
  bool erledigt;

  /// Wiederkehrend: kommt nach dem Einkauf automatisch wieder auf die Liste.
  bool immer;

  Map<String, dynamic> toJson() => {'text': text, 'kategorie': kategorie, 'erledigt': erledigt, 'immer': immer};

  factory Einkauf.fromJson(Map<String, dynamic> j) => Einkauf(
        text: j['text'] as String? ?? '',
        kategorie: j['kategorie'] as String?,
        erledigt: j['erledigt'] == true,
        immer: j['immer'] == true,
      );
}

class Vorrat {
  Vorrat({required this.name, this.menge = '', this.ablauf, this.ort = 'Vorrat'});

  String name;
  String menge;
  DateTime? ablauf;

  /// Kühlschrank, Tiefkühler, Vorrat
  String ort;

  Map<String, dynamic> toJson() => {'name': name, 'menge': menge, 'ablauf': ablauf?.toIso8601String(), 'ort': ort};

  factory Vorrat.fromJson(Map<String, dynamic> j) => Vorrat(
        name: j['name'] as String? ?? '',
        menge: j['menge'] as String? ?? '',
        ablauf: _datum(j['ablauf']),
        ort: j['ort'] as String? ?? 'Vorrat',
      );
}

class Hausaufgabe {
  Hausaufgabe({required this.text, this.personen = const [], this.alleTage = 7, this.zuletzt, this.zuletztVon = 0});

  String text;

  /// Wer sich abwechselt (leer = niemand Bestimmtes).
  List<String> personen;
  int alleTage;
  DateTime? zuletzt;

  /// Index der Person, die zuletzt dran war.
  int zuletztVon;

  Map<String, dynamic> toJson() => {
        'text': text,
        'personen': personen,
        'alleTage': alleTage,
        'zuletzt': zuletzt?.toIso8601String(),
        'zuletztVon': zuletztVon,
      };

  factory Hausaufgabe.fromJson(Map<String, dynamic> j) => Hausaufgabe(
        text: j['text'] as String? ?? '',
        personen: (j['personen'] as List?)?.whereType<String>().toList() ?? [],
        alleTage: (j['alleTage'] as num?)?.toInt() ?? 7,
        zuletzt: _datum(j['zuletzt']),
        zuletztVon: (j['zuletztVon'] as num?)?.toInt() ?? 0,
      );
}

class Geschenk {
  Geschenk({required this.idee, this.fuer = '', this.anlass = '', this.datum, this.preis, this.erledigt = false});

  String idee;
  String fuer;
  String anlass;
  DateTime? datum;
  double? preis;
  bool erledigt;

  Map<String, dynamic> toJson() => {
        'idee': idee,
        'fuer': fuer,
        'anlass': anlass,
        'datum': datum?.toIso8601String(),
        'preis': preis,
        'erledigt': erledigt,
      };

  factory Geschenk.fromJson(Map<String, dynamic> j) => Geschenk(
        idee: j['idee'] as String? ?? '',
        fuer: j['fuer'] as String? ?? '',
        anlass: j['anlass'] as String? ?? '',
        datum: _datum(j['datum']),
        preis: _zahl(j['preis']),
        erledigt: j['erledigt'] == true,
      );
}

class PackStueck {
  PackStueck(this.text, {this.eingepackt = false});

  String text;
  bool eingepackt;

  Map<String, dynamic> toJson() => {'text': text, 'eingepackt': eingepackt};

  factory PackStueck.fromJson(Map<String, dynamic> j) =>
      PackStueck(j['text'] as String? ?? '', eingepackt: j['eingepackt'] == true);
}

class Reise {
  Reise({
    required this.id,
    required this.ziel,
    this.von,
    this.bis,
    this.art = 'Sommer',
    this.plan = '',
    List<PackStueck>? packliste,
    List<String>? briefIds,
  })  : packliste = packliste ?? [],
        briefIds = briefIds ?? [];

  final String id;
  String ziel;
  DateTime? von;
  DateTime? bis;

  /// Sommer, Winter, Städtereise, Geschäftsreise
  String art;
  String plan;
  List<PackStueck> packliste;

  /// Reiseunterlagen aus dem Archiv (Buchung, Tickets, Versicherung …).
  List<String> briefIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ziel': ziel,
        'von': von?.toIso8601String(),
        'bis': bis?.toIso8601String(),
        'art': art,
        'plan': plan,
        'packliste': packliste.map((p) => p.toJson()).toList(),
        'briefIds': briefIds,
      };

  factory Reise.fromJson(Map<String, dynamic> j) => Reise(
        id: j['id'] as String,
        ziel: j['ziel'] as String? ?? '',
        von: _datum(j['von']),
        bis: _datum(j['bis']),
        art: j['art'] as String? ?? 'Sommer',
        plan: j['plan'] as String? ?? '',
        packliste: _liste(j['packliste'], PackStueck.fromJson),
        briefIds: (j['briefIds'] as List?)?.whereType<String>().toList() ?? [],
      );
}

class Alltag {
  Alltag({
    List<Einkauf>? einkauf,
    List<Vorrat>? vorraete,
    Map<String, String>? essensplan,
    List<Hausaufgabe>? hausaufgaben,
    List<Geschenk>? geschenke,
    List<Reise>? reisen,
  })  : einkauf = einkauf ?? [],
        vorraete = vorraete ?? [],
        essensplan = essensplan ?? {},
        hausaufgaben = hausaufgaben ?? [],
        geschenke = geschenke ?? [],
        reisen = reisen ?? [];

  List<Einkauf> einkauf;
  List<Vorrat> vorraete;

  /// Wochentag (1 = Montag … 7 = Sonntag) → Gericht.
  Map<String, String> essensplan;
  List<Hausaufgabe> hausaufgaben;
  List<Geschenk> geschenke;
  List<Reise> reisen;

  Map<String, dynamic> toJson() => {
        'einkauf': einkauf.map((e) => e.toJson()).toList(),
        'vorraete': vorraete.map((e) => e.toJson()).toList(),
        'essensplan': essensplan,
        'hausaufgaben': hausaufgaben.map((e) => e.toJson()).toList(),
        'geschenke': geschenke.map((e) => e.toJson()).toList(),
        'reisen': reisen.map((e) => e.toJson()).toList(),
      };

  factory Alltag.fromJson(Map<String, dynamic> j) => Alltag(
        einkauf: _liste(j['einkauf'], Einkauf.fromJson),
        vorraete: _liste(j['vorraete'], Vorrat.fromJson),
        essensplan: (j['essensplan'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {},
        hausaufgaben: _liste(j['hausaufgaben'], Hausaufgabe.fromJson),
        geschenke: _liste(j['geschenke'], Geschenk.fromJson),
        reisen: _liste(j['reisen'], Reise.fromJson),
      );
}
