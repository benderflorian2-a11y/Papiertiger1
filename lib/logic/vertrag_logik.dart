/// Berechnet, bis wann ein Vertrag gekündigt werden muss.
/// Vereinfachte Regeln; maßgeblich ist immer der eigene Vertrag.
library;

import '../data/models.dart';
import 'datum.dart';

class KuendigungsInfo {
  KuendigungsInfo(this.kuendigenBis, this.endetAm, this.hinweis);

  /// Letzter Tag, an dem die Kündigung beim Anbieter sein muss.
  final DateTime kuendigenBis;

  /// An diesem Tag endet der Vertrag dann.
  final DateTime endetAm;
  final String hinweis;
}

DateTime _minusFrist(DateTime d, Vertrag v) => v.fristInWochen
    ? d.subtract(Duration(days: 7 * v.fristWert))
    : plusMonate(d, -v.fristWert);

DateTime _plusFrist(DateTime d, Vertrag v) => v.fristInWochen
    ? d.add(Duration(days: 7 * v.fristWert))
    : plusMonate(d, v.fristWert);

/// Seit dem 1. März 2022 geschlossene Verträge sind nach der Mindestlaufzeit
/// monatlich kündbar (Gesetz für faire Verbraucherverträge).
final stichtagFaireVertraege = DateTime(2022, 3, 1);

KuendigungsInfo kuendigungsInfo(Vertrag v, {DateTime? heute}) {
  final jetzt = nurTag(heute ?? DateTime.now());

  if (v.laufzeitMonate <= 0) {
    return KuendigungsInfo(jetzt, _plusFrist(jetzt, v),
        'Ohne Mindestlaufzeit: Kündigung jederzeit mit der vereinbarten Frist.');
  }

  final mindestEnde = plusMonate(v.beginn, v.laufzeitMonate);
  final bisMindest = _minusFrist(mindestEnde, v);
  if (!jetzt.isAfter(bisMindest)) {
    return KuendigungsInfo(bisMindest, mindestEnde,
        'Kündigst du rechtzeitig, endet der Vertrag zum Ende der Mindestlaufzeit.');
  }

  if (!v.beginn.isBefore(stichtagFaireVertraege)) {
    // Nach Ende der Mindestlaufzeit höchstens ein Monat Kündigungsfrist.
    final ende = plusMonate(jetzt, 1);
    final mitFrist = _plusFrist(jetzt, v);
    return KuendigungsInfo(jetzt, mitFrist.isBefore(ende) ? mitFrist : ende,
        'Die Mindestlaufzeit ist vorbei. Verträge ab März 2022 kannst du dann jederzeit mit höchstens einem Monat Frist kündigen.');
  }

  // Ältere Verträge verlängern sich meist um je 12 Monate.
  var periodenEnde = mindestEnde;
  while (jetzt.isAfter(_minusFrist(periodenEnde, v))) {
    periodenEnde = plusMonate(periodenEnde, 12);
    if (periodenEnde.year > jetzt.year + 50) break;
  }
  return KuendigungsInfo(_minusFrist(periodenEnde, v), periodenEnde,
      'Ältere Verträge verlängern sich meist automatisch um ein Jahr. Prüfe die genauen Bedingungen in deinem Vertrag.');
}

// ---------------------------------------------------------------- Vertrag aus einem Brief

double? _betrag(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));

DateTime? _tag(String s) {
  final m = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})').firstMatch(s);
  if (m == null) return null;
  var j = int.parse(m.group(3)!);
  if (j < 100) j += 2000;
  final mo = int.parse(m.group(2)!), t = int.parse(m.group(1)!);
  if (mo < 1 || mo > 12 || t < 1 || t > 31) return null;
  return DateTime(j, mo, t);
}

class VertragsVorschlag {
  VertragsVorschlag({
    this.art,
    this.beginn,
    this.laufzeitMonate,
    this.fristWert,
    this.fristInWochen = false,
    this.kostenMonat,
    this.zahlweiseMonate = 1,
    this.nummer,
    this.versicherungsArt,
  });

  final String? art;
  final DateTime? beginn;
  final int? laufzeitMonate;
  final int? fristWert;
  final bool fristInWochen;
  final double? kostenMonat;
  final int zahlweiseMonate;
  final String? nummer;
  final String? versicherungsArt;

  /// Mindestens eine Vertragsangabe gefunden?
  bool get gefunden => laufzeitMonate != null || fristWert != null || nummer != null || kostenMonat != null;

  Vertrag alsVertrag({required String id, required String anbieter, DateTime? heute}) => Vertrag(
        id: id,
        anbieter: anbieter,
        art: art ?? 'Sonstiges',
        beginn: beginn ?? heute ?? DateTime.now(),
        laufzeitMonate: laufzeitMonate ?? 0,
        fristWert: fristWert ?? 1,
        fristInWochen: fristInWochen,
        kostenMonat: kostenMonat,
        zahlweiseMonate: zahlweiseMonate,
        nummer: nummer,
        versicherungsArt: versicherungsArt,
      );
}

const _artWoerter = <String, List<String>>{
  'Versicherung': ['versicherung', 'police', 'versicherungsschein', 'beitrag'],
  'Handy': ['mobilfunk', 'handyvertrag', 'sim-karte', 'tarif'],
  'Internet': ['dsl', 'glasfaser', 'internet', 'festnetz'],
  'Strom': ['strom', 'kwh'],
  'Gas': ['erdgas', 'gaslieferung', 'gastarif'],
  'Fitnessstudio': ['fitness', 'studio', 'mitgliedschaft'],
  'Streaming': ['streaming', 'netflix', 'spotify', 'disney+', 'dazn'],
  'Zeitschrift': ['zeitschrift', 'zeitung', 'magazin', 'abonnement'],
};

const _versicherungsWoerter = <String, List<String>>{
  'Privathaftpflicht': ['privathaftpflicht', 'haftpflichtversicherung'],
  'Hausrat': ['hausrat'],
  'Kfz': ['kfz', 'kraftfahrzeug', 'autoversicherung', 'kasko'],
  'Berufsunfähigkeit': ['berufsunfähigkeit', 'bu-versicherung'],
  'Zahnzusatz': ['zahnzusatz', 'zahnersatz'],
  'Kranken-Zusatz': ['krankenzusatz', 'zusatzversicherung'],
  'Rechtsschutz': ['rechtsschutz'],
  'Wohngebäude': ['wohngebäude', 'gebäudeversicherung'],
  'Unfall': ['unfallversicherung'],
  'Risikoleben': ['risikolebens', 'lebensversicherung'],
  'Reise': ['reiseversicherung', 'auslandskranken', 'reiserücktritt'],
  'Tier': ['tierhalter', 'hundehaftpflicht', 'tierkranken'],
};

String? _ersteArt(String lower, Map<String, List<String>> woerter) {
  var beste = 0;
  String? art;
  woerter.forEach((k, l) {
    final n = l.where(lower.contains).length;
    if (n > beste) {
      beste = n;
      art = k;
    }
  });
  return art;
}

/// Liest Vertragsangaben aus einem Brief: Laufzeit, Frist, Beginn, Beitrag, Nummer.
VertragsVorschlag vertragAusText(String text) {
  final lower = text.toLowerCase();

  int? laufzeit;
  final lz = RegExp(r'(?:mindest)?(?:vertrags)?laufzeit[^\d\n]{0,30}(\d{1,2})\s*(monat|jahr)', caseSensitive: false)
          .firstMatch(text) ??
      RegExp(r'(\d{1,2})\s*(monat|jahr)\w*\s+(?:mindest)?(?:vertrags)?laufzeit', caseSensitive: false).firstMatch(text);
  if (lz != null) {
    laufzeit = int.parse(lz.group(1)!) * (lz.group(2)!.toLowerCase().startsWith('jahr') ? 12 : 1);
  } else if (RegExp(r'monatlich kündbar|keine mindestlaufzeit|ohne mindestlaufzeit').hasMatch(lower)) {
    laufzeit = 0;
  }

  int? frist;
  var wochen = false;
  final kf = RegExp(r'kündigungsfrist[^\d\n]{0,30}(\d{1,2})\s*(woche|monat)', caseSensitive: false).firstMatch(text) ??
      RegExp(r'(\d{1,2})\s*(woche|monat)\w*\s+(?:vor|zum)\s+(?:ablauf|ende)', caseSensitive: false).firstMatch(text);
  if (kf != null) {
    frist = int.parse(kf.group(1)!);
    wochen = kf.group(2)!.toLowerCase().startsWith('woche');
  }

  DateTime? beginn;
  final bg = RegExp(r'(?:vertrags|versicherungs|liefer)?beginn\w*[^\d\n]{0,20}(\d{1,2}\.\d{1,2}\.\d{2,4})', caseSensitive: false)
      .firstMatch(text);
  if (bg != null) beginn = _tag(bg.group(1)!);

  double? monat;
  var zahlweise = 1;
  const geld = r'(\d{1,3}(?:\.\d{3})*,\d{2})\s*(?:€|eur)';
  final perioden = <(String, int)>[
    (r'(?:monatlich|pro monat|/\s*monat|mtl\.?|monatsbeitrag|grundgebühr)', 1),
    (r'(?:vierteljährlich|pro quartal|quartalsbeitrag)', 3),
    (r'(?:halbjährlich|halbjahresbeitrag)', 6),
    (r'(?:jährlich|pro jahr|/\s*jahr|jahresbeitrag|jahresprämie)', 12),
  ];
  for (final (wort, m) in perioden) {
    final vorher = RegExp('$wort[^\\d\\n]{0,30}$geld', caseSensitive: false).firstMatch(text);
    final nachher = RegExp('$geld[^\\d\\n]{0,12}$wort', caseSensitive: false).firstMatch(text);
    final treffer = vorher ?? nachher;
    if (treffer == null) continue;
    final b = _betrag(treffer.group(1)!);
    if (b == null) continue;
    monat = b / m;
    zahlweise = m;
    break;
  }

  String? nummer;
  final nr = RegExp(
          r'(?:vertrags|versicherungs|kunden|policen|mitglieds)[- ]?(?:nummer|nr\.?|schein-nr\.?)\s*:?\s*([A-Z0-9][A-Z0-9./\-]{3,24}(?: \d{2,8}){0,3})',
          caseSensitive: false)
      .firstMatch(text);
  if (nr != null) nummer = nr.group(1)!.trim();

  final art = _ersteArt(lower, _artWoerter);
  return VertragsVorschlag(
    art: art,
    beginn: beginn,
    laufzeitMonate: laufzeit,
    fristWert: frist,
    fristInWochen: wochen,
    kostenMonat: monat == null ? null : (monat * 100).round() / 100,
    zahlweiseMonate: zahlweise,
    nummer: nummer,
    versicherungsArt: art == 'Versicherung' ? _ersteArt(lower, _versicherungsWoerter) : null,
  );
}

// ---------------------------------------------------------------- Preiserhöhung

class Preisaenderung {
  Preisaenderung({this.ab, this.alt, this.neu});

  final DateTime? ab;
  final double? alt;
  final double? neu;
}

final _erhoehung = RegExp(
    r'preiserhöhung|preisanpassung|beitragserhöhung|beitragsanpassung|neue preise|erhöhen wir|erhöht sich|anpassung (?:der|des|ihrer|ihres) (?:preise|beiträge|beitrags|grundgebühr)',
    caseSensitive: false);

/// Erkennt eine angekündigte Preis- oder Beitragserhöhung.
Preisaenderung? preisaenderungFinden(String text) {
  if (!_erhoehung.hasMatch(text)) return null;
  final ab = RegExp(r'(?:ab dem|ab|zum|mit wirkung zum)\s+(\d{1,2}\.\d{1,2}\.\d{2,4})', caseSensitive: false)
      .firstMatch(text);
  final vonAuf = RegExp(r'von\s+(\d{1,3}(?:\.\d{3})*,\d{2})\s*(?:€|eur)\w*\s+auf\s+(\d{1,3}(?:\.\d{3})*,\d{2})',
          caseSensitive: false)
      .firstMatch(text);
  return Preisaenderung(
    ab: ab == null ? null : _tag(ab.group(1)!),
    alt: vonAuf == null ? null : _betrag(vonAuf.group(1)!),
    neu: vonAuf == null ? null : _betrag(vonAuf.group(2)!),
  );
}

// ---------------------------------------------------------------- Zuordnung und Überblick

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]'), '');

/// Findet den Vertrag, zu dem ein Brief gehört: verknüpft, gleiche Nummer oder gleicher Anbieter.
Vertrag? vertragZuBrief(Brief b, List<Vertrag> vertraege) {
  for (final v in vertraege) {
    if (v.briefIds.contains(b.id)) return v;
  }
  final text = _norm(b.text);
  for (final v in vertraege) {
    final n = v.nummer == null ? '' : _norm(v.nummer!);
    if (n.length >= 5 && text.contains(n)) return v;
  }
  final absender = _norm(b.absenderName ?? '');
  if (absender.length < 4) return null;
  for (final v in vertraege) {
    final a = _norm(v.anbieter);
    if (a.length >= 4 && (absender.contains(a) || a.contains(absender))) return v;
  }
  return null;
}

class KostenUebersicht {
  KostenUebersicht(this.monat, this.nachArt);

  final double monat;
  double get jahr => monat * 12;

  /// Monatliche Kosten je Vertragsart, teuerste zuerst.
  final List<(String, double)> nachArt;
}

KostenUebersicht kostenUebersicht(List<Vertrag> vertraege) {
  final summen = <String, double>{};
  var gesamt = 0.0;
  for (final v in vertraege) {
    if (v.gekuendigt || v.kostenMonat == null) continue;
    gesamt += v.kostenMonat!;
    final art = v.art == 'Versicherung' && v.versicherungsArt != null ? 'Versicherung' : v.art;
    summen[art] = (summen[art] ?? 0) + v.kostenMonat!;
  }
  final l = summen.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  return KostenUebersicht(gesamt, l);
}

/// Tage nach dem Verschicken, nach denen eine fehlende Kündigungsbestätigung auffällt.
const bestaetigungTage = 14;

/// Kündigung verschickt, aber noch keine Bestätigung: ab wann nachhaken?
DateTime? bestaetigungPruefenAb(Vertrag v) =>
    v.gekuendigt && !v.bestaetigt && v.gekuendigtAm != null
        ? nurTag(v.gekuendigtAm!).add(const Duration(days: bestaetigungTage))
        : null;

/// Letzter Tag des üblichen 14-tägigen Widerrufsrechts (online, telefonisch, an der Haustür
/// geschlossene Verträge). Null, wenn es schon vorbei ist.
DateTime? widerrufBis(Vertrag v, {DateTime? heute}) {
  final ende = nurTag(v.beginn).add(const Duration(days: 14));
  return ende.isBefore(nurTag(heute ?? DateTime.now())) ? null : ende;
}
