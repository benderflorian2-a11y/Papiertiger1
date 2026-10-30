/// Kinder-Akte und Vorsorgemappe. Bleibt nur auf dem Handy (und in deiner Datensicherung).
library;

DateTime? _datum(Object? v) => v is String ? DateTime.tryParse(v) : null;
List<String> _texte(Object? v) => (v as List?)?.whereType<String>().toList() ?? [];

class Kind {
  Kind({required this.id, required this.name, this.geburt, this.einrichtung = '', this.notiz = '', List<String>? erledigt, List<String>? briefIds})
      : erledigt = erledigt ?? [],
        briefIds = briefIds ?? [];

  final String id;
  String name;
  DateTime? geburt;

  /// Kita bzw. Schule und Klasse.
  String einrichtung;
  String notiz;

  /// Erledigte Vorsorgeuntersuchungen (U1 … J1).
  List<String> erledigt;

  /// Dokumente aus dem Archiv (Geburtsurkunde, Impfpass, Zeugnisse …).
  List<String> briefIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'geburt': geburt?.toIso8601String(),
        'einrichtung': einrichtung,
        'notiz': notiz,
        'erledigt': erledigt,
        'briefIds': briefIds,
      };

  factory Kind.fromJson(Map<String, dynamic> j) => Kind(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        geburt: _datum(j['geburt']),
        einrichtung: j['einrichtung'] as String? ?? '',
        notiz: j['notiz'] as String? ?? '',
        erledigt: _texte(j['erledigt']),
        briefIds: _texte(j['briefIds']),
      );
}

class Notfallkontakt {
  Notfallkontakt({required this.name, this.telefon = '', this.beziehung = ''});

  String name;
  String telefon;
  String beziehung;

  Map<String, dynamic> toJson() => {'name': name, 'telefon': telefon, 'beziehung': beziehung};

  factory Notfallkontakt.fromJson(Map<String, dynamic> j) => Notfallkontakt(
      name: j['name'] as String? ?? '', telefon: j['telefon'] as String? ?? '', beziehung: j['beziehung'] as String? ?? '');
}

class Vorsorge {
  Vorsorge({
    List<Notfallkontakt>? kontakte,
    Map<String, String>? ablage,
    this.hausarzt = '',
    this.medikamente = '',
    this.allergien = '',
    this.hinweise = '',
  })  : kontakte = kontakte ?? [],
        ablage = ablage ?? {};

  List<Notfallkontakt> kontakte;

  /// Dokument (z. B. „Patientenverfügung“) → wo es liegt bzw. „vorhanden“.
  Map<String, String> ablage;
  String hausarzt;
  String medikamente;
  String allergien;

  /// Weitere Hinweise für Angehörige (Schlüssel, Haustiere, Passwörter-Ort …).
  String hinweise;

  Map<String, dynamic> toJson() => {
        'kontakte': kontakte.map((k) => k.toJson()).toList(),
        'ablage': ablage,
        'hausarzt': hausarzt,
        'medikamente': medikamente,
        'allergien': allergien,
        'hinweise': hinweise,
      };

  factory Vorsorge.fromJson(Map<String, dynamic> j) => Vorsorge(
        kontakte: (j['kontakte'] as List?)?.whereType<Map<String, dynamic>>().map(Notfallkontakt.fromJson).toList(),
        ablage: (j['ablage'] as Map?)?.map((k, v) => MapEntry('$k', '$v')),
        hausarzt: j['hausarzt'] as String? ?? '',
        medikamente: j['medikamente'] as String? ?? '',
        allergien: j['allergien'] as String? ?? '',
        hinweise: j['hinweise'] as String? ?? '',
      );
}

class Familie {
  Familie({List<Kind>? kinder, Vorsorge? vorsorge})
      : kinder = kinder ?? [],
        vorsorge = vorsorge ?? Vorsorge();

  List<Kind> kinder;
  Vorsorge vorsorge;

  Map<String, dynamic> toJson() => {'kinder': kinder.map((k) => k.toJson()).toList(), 'vorsorge': vorsorge.toJson()};

  factory Familie.fromJson(Map<String, dynamic> j) => Familie(
        kinder: (j['kinder'] as List?)?.whereType<Map<String, dynamic>>().map(Kind.fromJson).toList(),
        vorsorge: j['vorsorge'] is Map<String, dynamic> ? Vorsorge.fromJson(j['vorsorge'] as Map<String, dynamic>) : null,
      );
}
