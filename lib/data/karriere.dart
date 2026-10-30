/// Job, Karriere und Weiterbildung: Lebenslauf, Bewerbungen, Weiterbildungen. Ein JSON im Speicher.
library;

DateTime? _datum(Object? v) => v is String ? DateTime.tryParse(v) : null;
double? _zahl(Object? v) => v is num ? v.toDouble() : null;
List<T> _liste<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    (v as List?)?.whereType<Map<String, dynamic>>().map(f).toList() ?? <T>[];
List<String> _texte(Object? v) => (v as List?)?.whereType<String>().toList() ?? [];

const stationsArten = ['Beruf', 'Ausbildung', 'Weiterbildung', 'Ehrenamt'];

/// Eine Station im Lebenslauf.
class Station {
  Station({required this.art, required this.titel, this.ort = '', this.von, this.bis, this.text = ''});

  String art;

  /// z. B. „Elektroniker“ oder „Realschulabschluss“.
  String titel;

  /// Firma bzw. Schule und Ort.
  String ort;
  DateTime? von;

  /// null = bis heute.
  DateTime? bis;
  String text;

  Map<String, dynamic> toJson() => {
        'art': art,
        'titel': titel,
        'ort': ort,
        'von': von?.toIso8601String(),
        'bis': bis?.toIso8601String(),
        'text': text,
      };

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        art: j['art'] as String? ?? 'Beruf',
        titel: j['titel'] as String? ?? '',
        ort: j['ort'] as String? ?? '',
        von: _datum(j['von']),
        bis: _datum(j['bis']),
        text: j['text'] as String? ?? '',
      );
}

class Lebenslauf {
  Lebenslauf({
    List<Station>? stationen,
    List<String>? kenntnisse,
    List<String>? sprachen,
    this.kurzprofil = '',
    this.foto,
    this.geburtsdatum,
    this.telefon = '',
    this.email = '',
  })  : stationen = stationen ?? [],
        kenntnisse = kenntnisse ?? [],
        sprachen = sprachen ?? [];

  List<Station> stationen;
  List<String> kenntnisse;

  /// z. B. „Englisch – gut“.
  List<String> sprachen;
  String kurzprofil;
  String? foto;

  /// Freiwillig – in Deutschland nicht nötig.
  DateTime? geburtsdatum;
  String telefon;
  String email;

  Map<String, dynamic> toJson() => {
        'stationen': stationen.map((s) => s.toJson()).toList(),
        'kenntnisse': kenntnisse,
        'sprachen': sprachen,
        'kurzprofil': kurzprofil,
        'foto': foto,
        'geburtsdatum': geburtsdatum?.toIso8601String(),
        'telefon': telefon,
        'email': email,
      };

  factory Lebenslauf.fromJson(Map<String, dynamic> j) => Lebenslauf(
        stationen: _liste(j['stationen'], Station.fromJson),
        kenntnisse: _texte(j['kenntnisse']),
        sprachen: _texte(j['sprachen']),
        kurzprofil: j['kurzprofil'] as String? ?? '',
        foto: j['foto'] as String?,
        geburtsdatum: _datum(j['geburtsdatum']),
        telefon: j['telefon'] as String? ?? '',
        email: j['email'] as String? ?? '',
      );
}

const bewerbungsStatus = ['Gemerkt', 'Beworben', 'Gespräch', 'Zusage', 'Absage'];

class Bewerbung {
  Bewerbung({
    required this.id,
    required this.firma,
    required this.stelle,
    this.anzeige = '',
    this.status = 'Gemerkt',
    this.beworbenAm,
    this.frist,
    this.gespraechAm,
    this.kontakt = '',
    this.email = '',
    this.anschreiben = '',
    this.notiz = '',
    List<String>? briefIds,
    List<String>? erledigt,
  })  : briefIds = briefIds ?? [],
        erledigt = erledigt ?? [];

  final String id;
  String firma;
  String stelle;

  /// Text der Stellenanzeige.
  String anzeige;
  String status;
  DateTime? beworbenAm;

  /// Bewerbungsfrist laut Anzeige.
  DateTime? frist;
  DateTime? gespraechAm;
  String kontakt;
  String email;
  String anschreiben;
  String notiz;

  /// Anlagen aus dem Archiv (Zeugnisse, Zertifikate).
  List<String> briefIds;

  /// Abgehakte Punkte der Unterlagen-Checkliste.
  List<String> erledigt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'firma': firma,
        'stelle': stelle,
        'anzeige': anzeige,
        'status': status,
        'beworbenAm': beworbenAm?.toIso8601String(),
        'frist': frist?.toIso8601String(),
        'gespraechAm': gespraechAm?.toIso8601String(),
        'kontakt': kontakt,
        'email': email,
        'anschreiben': anschreiben,
        'notiz': notiz,
        'briefIds': briefIds,
        'erledigt': erledigt,
      };

  factory Bewerbung.fromJson(Map<String, dynamic> j) => Bewerbung(
        id: j['id'] as String,
        firma: j['firma'] as String? ?? '',
        stelle: j['stelle'] as String? ?? '',
        anzeige: j['anzeige'] as String? ?? '',
        status: j['status'] as String? ?? 'Gemerkt',
        beworbenAm: _datum(j['beworbenAm']),
        frist: _datum(j['frist']),
        gespraechAm: _datum(j['gespraechAm']),
        kontakt: j['kontakt'] as String? ?? '',
        email: j['email'] as String? ?? '',
        anschreiben: j['anschreiben'] as String? ?? '',
        notiz: j['notiz'] as String? ?? '',
        briefIds: _texte(j['briefIds']),
        erledigt: _texte(j['erledigt']),
      );
}

class Weiterbildung {
  Weiterbildung({
    required this.id,
    required this.titel,
    this.anbieter = '',
    this.von,
    this.bis,
    this.anmeldungBis,
    this.kosten,
    this.foerderung = '',
    this.status = 'Geplant',
    this.zertifikatId,
  });

  final String id;
  String titel;
  String anbieter;
  DateTime? von;
  DateTime? bis;
  DateTime? anmeldungBis;
  double? kosten;
  String foerderung;

  /// Geplant, Angemeldet, Läuft, Abgeschlossen
  String status;

  /// Zertifikat aus dem Archiv.
  String? zertifikatId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'titel': titel,
        'anbieter': anbieter,
        'von': von?.toIso8601String(),
        'bis': bis?.toIso8601String(),
        'anmeldungBis': anmeldungBis?.toIso8601String(),
        'kosten': kosten,
        'foerderung': foerderung,
        'status': status,
        'zertifikatId': zertifikatId,
      };

  factory Weiterbildung.fromJson(Map<String, dynamic> j) => Weiterbildung(
        id: j['id'] as String,
        titel: j['titel'] as String? ?? '',
        anbieter: j['anbieter'] as String? ?? '',
        von: _datum(j['von']),
        bis: _datum(j['bis']),
        anmeldungBis: _datum(j['anmeldungBis']),
        kosten: _zahl(j['kosten']),
        foerderung: j['foerderung'] as String? ?? '',
        status: j['status'] as String? ?? 'Geplant',
        zertifikatId: j['zertifikatId'] as String?,
      );
}

const weiterbildungsStatus = ['Geplant', 'Angemeldet', 'Läuft', 'Abgeschlossen'];

class Karriere {
  Karriere({Lebenslauf? lebenslauf, List<Bewerbung>? bewerbungen, List<Weiterbildung>? weiterbildungen})
      : lebenslauf = lebenslauf ?? Lebenslauf(),
        bewerbungen = bewerbungen ?? [],
        weiterbildungen = weiterbildungen ?? [];

  Lebenslauf lebenslauf;
  List<Bewerbung> bewerbungen;
  List<Weiterbildung> weiterbildungen;

  Map<String, dynamic> toJson() => {
        'lebenslauf': lebenslauf.toJson(),
        'bewerbungen': bewerbungen.map((b) => b.toJson()).toList(),
        'weiterbildungen': weiterbildungen.map((w) => w.toJson()).toList(),
      };

  factory Karriere.fromJson(Map<String, dynamic> j) => Karriere(
        lebenslauf: j['lebenslauf'] is Map<String, dynamic> ? Lebenslauf.fromJson(j['lebenslauf'] as Map<String, dynamic>) : null,
        bewerbungen: _liste(j['bewerbungen'], Bewerbung.fromJson),
        weiterbildungen: _liste(j['weiterbildungen'], Weiterbildung.fromJson),
      );
}
