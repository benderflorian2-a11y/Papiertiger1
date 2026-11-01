/// Verknüpftes E-Mail-Postfach und die daraus gemeldeten wichtigen E-Mails.
/// Das Passwort liegt wie alle Daten verschlüsselt auf dem Handy.
library;

class PostfachKonto {
  PostfachKonto({
    required this.adresse,
    required this.benutzer,
    required this.passwort,
    required this.server,
    this.port = 993,
    this.automatisch = true,
    this.uidValidity = 0,
    this.letzteUid = 0,
    this.zuletzt,
    this.fehler,
  });

  String adresse;
  String benutzer;
  String passwort;
  String server;
  int port;

  /// Im Hintergrund regelmäßig nachsehen (Android).
  bool automatisch;

  /// Merker des Servers: Ändert er sich, wurde der Posteingang neu aufgebaut.
  int uidValidity;

  /// Höchste schon angesehene Nachricht.
  int letzteUid;
  DateTime? zuletzt;

  /// Letzter Fehler beim Nachsehen (null = alles gut).
  String? fehler;

  Map<String, dynamic> toJson() => {
        'adresse': adresse,
        'benutzer': benutzer,
        'passwort': passwort,
        'server': server,
        'port': port,
        'automatisch': automatisch,
        'uidValidity': uidValidity,
        'letzteUid': letzteUid,
        'zuletzt': zuletzt?.toIso8601String(),
        'fehler': fehler,
      };

  factory PostfachKonto.fromJson(Map<String, dynamic> j) => PostfachKonto(
        adresse: j['adresse'] as String? ?? '',
        benutzer: j['benutzer'] as String? ?? '',
        passwort: j['passwort'] as String? ?? '',
        server: j['server'] as String? ?? '',
        port: (j['port'] as num?)?.toInt() ?? 993,
        automatisch: j['automatisch'] as bool? ?? true,
        uidValidity: (j['uidValidity'] as num?)?.toInt() ?? 0,
        letzteUid: (j['letzteUid'] as num?)?.toInt() ?? 0,
        zuletzt: DateTime.tryParse(j['zuletzt'] as String? ?? ''),
        fehler: j['fehler'] as String?,
      );
}

/// Eine wichtige E-Mail, die Papiertiger gemeldet hat.
class MailHinweis {
  MailHinweis({
    required this.uid,
    required this.art,
    required this.absender,
    required this.betreff,
    this.datum,
    this.betrag,
    this.frist,
    this.status = 'neu',
    this.anhaenge = 0,
  });

  final int uid;

  /// rechnung, mahnung, behoerde, vertrag, briefankuendigung
  final String art;
  final String absender;
  final String betreff;
  final DateTime? datum;
  final double? betrag;
  final DateTime? frist;
  final int anhaenge;

  /// neu, uebernommen, ignoriert
  String status;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'art': art,
        'absender': absender,
        'betreff': betreff,
        'datum': datum?.toIso8601String(),
        'betrag': betrag,
        'frist': frist?.toIso8601String(),
        'status': status,
        'anhaenge': anhaenge,
      };

  factory MailHinweis.fromJson(Map<String, dynamic> j) => MailHinweis(
        uid: (j['uid'] as num?)?.toInt() ?? 0,
        art: j['art'] as String? ?? 'rechnung',
        absender: j['absender'] as String? ?? '',
        betreff: j['betreff'] as String? ?? '',
        datum: DateTime.tryParse(j['datum'] as String? ?? ''),
        betrag: (j['betrag'] as num?)?.toDouble(),
        frist: DateTime.tryParse(j['frist'] as String? ?? ''),
        status: j['status'] as String? ?? 'neu',
        anhaenge: (j['anhaenge'] as num?)?.toInt() ?? 0,
      );
}

class Postfach {
  Postfach({this.konto, List<MailHinweis>? hinweise}) : hinweise = hinweise ?? [];

  PostfachKonto? konto;
  List<MailHinweis> hinweise;

  List<MailHinweis> get neue => hinweise.where((h) => h.status == 'neu').toList();

  Map<String, dynamic> toJson() => {
        'konto': konto?.toJson(),
        'hinweise': hinweise.map((h) => h.toJson()).toList(),
      };

  factory Postfach.fromJson(Map<String, dynamic> j) => Postfach(
        konto: j['konto'] is Map<String, dynamic> ? PostfachKonto.fromJson(j['konto'] as Map<String, dynamic>) : null,
        hinweise: [
          for (final h in (j['hinweise'] as List? ?? const []))
            if (h is Map<String, dynamic>) MailHinweis.fromJson(h),
        ],
      );
}
