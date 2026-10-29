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
    this.email = '',
    this.telefon = '',
    this.zahlungszielTage = 14,
  });

  String name;
  String adresse;
  String steuernummer;
  String ustId;

  /// Kleinunternehmerregelung (§ 19 UStG): keine Umsatzsteuer auf Rechnungen.
  bool kleinunternehmer;
  String iban;
  String bank;
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
        'email': email,
        'telefon': telefon,
        'zahlungszielTage': zahlungszielTage,
      };

  factory Firma.fromJson(Map<String, dynamic> j) => Firma(
        name: j['name'] as String? ?? '',
        adresse: j['adresse'] as String? ?? '',
        steuernummer: j['steuernummer'] as String? ?? '',
        ustId: j['ustId'] as String? ?? '',
        kleinunternehmer: j['kleinunternehmer'] == true,
        iban: j['iban'] as String? ?? '',
        bank: j['bank'] as String? ?? '',
        email: j['email'] as String? ?? '',
        telefon: j['telefon'] as String? ?? '',
        zahlungszielTage: (j['zahlungszielTage'] as num?)?.toInt() ?? 14,
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

class Position {
  Position({required this.text, this.menge = 1, this.einheit = 'Stück', this.preis = 0, this.ustSatz = 19});

  String text;
  double menge;
  String einheit;

  /// Einzelpreis netto.
  double preis;

  /// 19, 7 oder 0 Prozent.
  int ustSatz;

  double get netto => (menge * preis * 100).round() / 100;

  Map<String, dynamic> toJson() =>
      {'text': text, 'menge': menge, 'einheit': einheit, 'preis': preis, 'ustSatz': ustSatz};

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        text: j['text'] as String? ?? '',
        menge: _zahl(j['menge']),
        einheit: j['einheit'] as String? ?? 'Stück',
        preis: _zahl(j['preis']),
        ustSatz: (j['ustSatz'] as num?)?.toInt() ?? 19,
      );
}

/// Rechnung oder Angebot.
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
  }) : positionen = positionen ?? [];

  final String id;

  /// 'rechnung', 'angebot' oder 'kostenvoranschlag'
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

  String get artName => switch (art) { 'angebot' => 'Angebot', 'kostenvoranschlag' => 'Kostenvoranschlag', _ => 'Rechnung' };

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
      );
}
