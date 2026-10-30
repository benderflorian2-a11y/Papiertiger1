/// Vermietung: Objekte, Mieter und Nebenkostenabrechnungen.
library;

DateTime? _datum(Object? v) => v is String ? DateTime.tryParse(v) : null;
double _zahl(Object? v) => v is num ? v.toDouble() : 0;

class Mietobjekt {
  Mietobjekt({required this.id, required this.adresse, this.gesamtflaeche = 0, this.einheiten = 1});

  final String id;
  String adresse;

  /// Wohnfläche aller Einheiten (m²) – für die Umlage nach Fläche.
  double gesamtflaeche;
  int einheiten;

  Map<String, dynamic> toJson() => {'id': id, 'adresse': adresse, 'gesamtflaeche': gesamtflaeche, 'einheiten': einheiten};

  factory Mietobjekt.fromJson(Map<String, dynamic> j) => Mietobjekt(
        id: j['id'] as String,
        adresse: j['adresse'] as String? ?? '',
        gesamtflaeche: _zahl(j['gesamtflaeche']),
        einheiten: (j['einheiten'] as num?)?.toInt() ?? 1,
      );
}

class Mieter {
  Mieter({
    required this.id,
    required this.objektId,
    required this.name,
    this.wohnung = '',
    this.email = '',
    this.einzug,
    this.auszug,
    this.kaltmiete = 0,
    this.nebenkosten = 0,
    this.flaeche = 0,
    this.personen = 1,
    this.letzteErhoehung,
    this.kaution = 0,
  });

  final String id;
  String objektId;
  String name;
  String wohnung;
  String email;
  DateTime? einzug;
  DateTime? auszug;
  double kaltmiete;

  /// Monatliche Nebenkosten-Vorauszahlung.
  double nebenkosten;
  double flaeche;
  int personen;
  DateTime? letzteErhoehung;
  double kaution;

  double get warmmiete => kaltmiete + nebenkosten;

  Map<String, dynamic> toJson() => {
        'id': id,
        'objektId': objektId,
        'name': name,
        'wohnung': wohnung,
        'email': email,
        'einzug': einzug?.toIso8601String(),
        'auszug': auszug?.toIso8601String(),
        'kaltmiete': kaltmiete,
        'nebenkosten': nebenkosten,
        'flaeche': flaeche,
        'personen': personen,
        'letzteErhoehung': letzteErhoehung?.toIso8601String(),
        'kaution': kaution,
      };

  factory Mieter.fromJson(Map<String, dynamic> j) => Mieter(
        id: j['id'] as String,
        objektId: j['objektId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        wohnung: j['wohnung'] as String? ?? '',
        email: j['email'] as String? ?? '',
        einzug: _datum(j['einzug']),
        auszug: _datum(j['auszug']),
        kaltmiete: _zahl(j['kaltmiete']),
        nebenkosten: _zahl(j['nebenkosten']),
        flaeche: _zahl(j['flaeche']),
        personen: (j['personen'] as num?)?.toInt() ?? 1,
        letzteErhoehung: _datum(j['letzteErhoehung']),
        kaution: _zahl(j['kaution']),
      );
}

/// Umlageschlüssel einer Kostenart.
const umlageSchluessel = {'flaeche': 'nach Fläche', 'personen': 'nach Personen', 'einheiten': 'nach Wohnungen'};

/// Übliche umlagefähige Betriebskosten (§ 2 Betriebskostenverordnung).
const betriebskostenArten = [
  'Grundsteuer',
  'Wasser und Abwasser',
  'Heizung und Warmwasser',
  'Müllabfuhr',
  'Straßenreinigung',
  'Hausreinigung',
  'Gartenpflege',
  'Allgemeinstrom',
  'Schornsteinfeger',
  'Gebäudeversicherung',
  'Hauswart',
  'Aufzug',
  'Kabel / Gemeinschaftsantenne',
];

class Kostenposten {
  Kostenposten({required this.art, required this.betrag, this.schluessel = 'flaeche'});

  String art;
  double betrag;
  String schluessel;

  Map<String, dynamic> toJson() => {'art': art, 'betrag': betrag, 'schluessel': schluessel};

  factory Kostenposten.fromJson(Map<String, dynamic> j) =>
      Kostenposten(art: j['art'] as String? ?? '', betrag: _zahl(j['betrag']), schluessel: j['schluessel'] as String? ?? 'flaeche');
}

/// Nebenkosten eines Objekts für ein Kalenderjahr.
class Nebenkostenjahr {
  Nebenkostenjahr({required this.objektId, required this.jahr, List<Kostenposten>? posten, this.gesamtpersonen = 0})
      : posten = posten ?? [];

  final String objektId;
  final int jahr;
  List<Kostenposten> posten;

  /// Alle Bewohner im Haus (für die Umlage nach Personen).
  int gesamtpersonen;

  Map<String, dynamic> toJson() => {
        'objektId': objektId,
        'jahr': jahr,
        'posten': posten.map((p) => p.toJson()).toList(),
        'gesamtpersonen': gesamtpersonen,
      };

  factory Nebenkostenjahr.fromJson(Map<String, dynamic> j) => Nebenkostenjahr(
        objektId: j['objektId'] as String? ?? '',
        jahr: (j['jahr'] as num?)?.toInt() ?? DateTime.now().year,
        posten: (j['posten'] as List?)?.whereType<Map<String, dynamic>>().map(Kostenposten.fromJson).toList(),
        gesamtpersonen: (j['gesamtpersonen'] as num?)?.toInt() ?? 0,
      );
}

class Vermietung {
  Vermietung({List<Mietobjekt>? objekte, List<Mieter>? mieter, List<Nebenkostenjahr>? nebenkosten})
      : objekte = objekte ?? [],
        mieter = mieter ?? [],
        nebenkosten = nebenkosten ?? [];

  List<Mietobjekt> objekte;
  List<Mieter> mieter;
  List<Nebenkostenjahr> nebenkosten;

  Map<String, dynamic> toJson() => {
        'objekte': objekte.map((o) => o.toJson()).toList(),
        'mieter': mieter.map((m) => m.toJson()).toList(),
        'nebenkosten': nebenkosten.map((n) => n.toJson()).toList(),
      };

  factory Vermietung.fromJson(Map<String, dynamic> j) => Vermietung(
        objekte: (j['objekte'] as List?)?.whereType<Map<String, dynamic>>().map(Mietobjekt.fromJson).toList(),
        mieter: (j['mieter'] as List?)?.whereType<Map<String, dynamic>>().map(Mieter.fromJson).toList(),
        nebenkosten: (j['nebenkosten'] as List?)?.whereType<Map<String, dynamic>>().map(Nebenkostenjahr.fromJson).toList(),
      );
}
