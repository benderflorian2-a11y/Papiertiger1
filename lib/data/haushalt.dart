/// Daten für den Haushalt: Zähler mit Ablesungen und Inventar.
library;

DateTime? _datum(Object? v) => v is String ? DateTime.tryParse(v) : null;
double? _zahl(Object? v) => v is num ? v.toDouble() : null;

class Ablesung {
  Ablesung(this.datum, this.stand);

  final DateTime datum;
  final double stand;

  Map<String, dynamic> toJson() => {'datum': datum.toIso8601String(), 'stand': stand};

  factory Ablesung.fromJson(Map<String, dynamic> j) =>
      Ablesung(_datum(j['datum']) ?? DateTime.now(), _zahl(j['stand']) ?? 0);
}

class Zaehler {
  Zaehler({
    required this.id,
    required this.art,
    this.nummer = '',
    this.preis,
    this.grundpreisMonat,
    this.abschlagMonat,
    List<Ablesung>? ablesungen,
  }) : ablesungen = ablesungen ?? [];

  final String id;

  /// Strom, Gas, Wasser, Heizung, Warmwasser
  String art;
  String nummer;

  /// Arbeitspreis pro Einheit (kWh oder m³), brutto.
  double? preis;
  double? grundpreisMonat;
  double? abschlagMonat;
  List<Ablesung> ablesungen;

  String get einheit => switch (art) { 'Strom' || 'Heizung' => 'kWh', 'Gas' || 'Wasser' || 'Warmwasser' => 'm³', _ => '' };

  Map<String, dynamic> toJson() => {
        'id': id,
        'art': art,
        'nummer': nummer,
        'preis': preis,
        'grundpreisMonat': grundpreisMonat,
        'abschlagMonat': abschlagMonat,
        'ablesungen': ablesungen.map((a) => a.toJson()).toList(),
      };

  factory Zaehler.fromJson(Map<String, dynamic> j) => Zaehler(
        id: j['id'] as String,
        art: j['art'] as String? ?? 'Strom',
        nummer: j['nummer'] as String? ?? '',
        preis: _zahl(j['preis']),
        grundpreisMonat: _zahl(j['grundpreisMonat']),
        abschlagMonat: _zahl(j['abschlagMonat']),
        ablesungen: (j['ablesungen'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Ablesung.fromJson)
                .toList() ??
            [],
      );
}

const zaehlerArten = ['Strom', 'Gas', 'Wasser', 'Warmwasser', 'Heizung'];

class Gegenstand {
  Gegenstand({
    required this.id,
    required this.name,
    this.raum = '',
    this.kaufdatum,
    this.preis,
    this.bild,
    this.seriennummer = '',
    this.belegId,
  });

  final String id;
  String name;
  String raum;
  DateTime? kaufdatum;
  double? preis;
  String? bild;
  String seriennummer;
  String? belegId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'raum': raum,
        'kaufdatum': kaufdatum?.toIso8601String(),
        'preis': preis,
        'bild': bild,
        'seriennummer': seriennummer,
        'belegId': belegId,
      };

  factory Gegenstand.fromJson(Map<String, dynamic> j) => Gegenstand(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        raum: j['raum'] as String? ?? '',
        kaufdatum: _datum(j['kaufdatum']),
        preis: _zahl(j['preis']),
        bild: j['bild'] as String?,
        seriennummer: j['seriennummer'] as String? ?? '',
        belegId: j['belegId'] as String?,
      );
}

const raeume = ['Wohnzimmer', 'Küche', 'Schlafzimmer', 'Kinderzimmer', 'Bad', 'Arbeitszimmer', 'Flur', 'Keller', 'Garage', 'Sonstiges'];
