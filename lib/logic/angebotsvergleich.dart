/// Mehrere Angebote (Handwerker, Lieferanten, Versicherungen …) nebeneinanderlegen.
library;

import '../data/models.dart';
import 'brief_analyse.dart';
import 'ordnung.dart';

class AngebotsDaten {
  AngebotsDaten({required this.brief, required this.anbieter, this.summe, this.gueltigBis, this.skonto, this.zahlungsziel});

  final Brief brief;
  final String anbieter;

  /// Endbetrag (brutto, wenn erkennbar).
  final double? summe;
  final DateTime? gueltigBis;

  /// Skonto in Prozent.
  final double? skonto;

  /// Zahlungsziel in Tagen.
  final int? zahlungsziel;
}

final _endbetrag = RegExp(
    r'(gesamtbetrag|endbetrag|angebotssumme|gesamtsumme|bruttobetrag|summe brutto|brutto|gesamt|zu zahlen|gesamtpreis)',
    caseSensitive: false);

double? _summe(String text) {
  final lower = text.toLowerCase();
  final funde = betragsFunde(text);
  // Letzter Betrag, vor dem ein Wort für den Endbetrag steht (meist ganz unten).
  for (final f in funde.reversed) {
    final von = (f.start - 40).clamp(0, lower.length);
    var davor = lower.substring(von, f.start);
    // Nur die eigene Zeile zählt – außer der Betrag steht allein in einer Zeile unter der Bezeichnung.
    final zeile = davor.split('\n').last;
    if (RegExp(r'[a-zäöü]{3}').hasMatch(zeile)) davor = zeile;
    if (_endbetrag.hasMatch(davor) && !davor.contains('netto') && !davor.contains('zwischen')) return f.wert;
  }
  // Ohne €-Zeichen: „Gesamtbetrag 1.234,56“
  final ohne = RegExp(r'(gesamtbetrag|endbetrag|angebotssumme|summe brutto|brutto)[^0-9\n]{0,25}(\d{1,3}(?:\.\d{3})*,\d{2})',
          caseSensitive: false)
      .allMatches(text)
      .lastOrNull;
  if (ohne != null) return double.tryParse(ohne.group(2)!.replaceAll('.', '').replaceAll(',', '.'));
  return summeFinden(text);
}

DateTime? _gueltig(String text, DateTime ab) {
  final m = RegExp(r'(gültig bis|bindefrist|gilt bis|angebot gilt bis|gültigkeit)[^0-9\n]{0,20}(\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4})',
          caseSensitive: false)
      .firstMatch(text);
  if (m != null) return erstesDatum(m.group(2)!);
  final t = RegExp(r'(?:gültig|bindefrist|gilt)[^0-9\n]{0,20}(\d{1,3})\s*(tage|wochen)', caseSensitive: false).firstMatch(text);
  if (t == null) return null;
  final n = int.parse(t.group(1)!) * (t.group(2)!.toLowerCase() == 'wochen' ? 7 : 1);
  return DateTime(ab.year, ab.month, ab.day + n);
}

AngebotsDaten angebotLesenAus(Brief b) {
  final t = b.text;
  final skonto = RegExp(r'(\d{1,2}(?:,\d)?)\s?%\s*skonto|skonto[^0-9\n]{0,15}(\d{1,2}(?:,\d)?)\s?%', caseSensitive: false).firstMatch(t);
  final ziel = RegExp(r'(?:zahlbar|zahlungsziel|innerhalb)[^0-9\n]{0,25}(\d{1,3})\s*tage', caseSensitive: false).firstMatch(t);
  final absender = b.absenderName?.trim();
  return AngebotsDaten(
    brief: b,
    anbieter: (absender != null && absender.isNotEmpty) ? absender : titelVon(b),
    summe: _summe(t),
    gueltigBis: _gueltig(t, b.briefDatum ?? b.erstellt),
    skonto: skonto == null ? null : double.tryParse((skonto.group(1) ?? skonto.group(2))!.replaceAll(',', '.')),
    zahlungsziel: ziel == null ? null : int.tryParse(ziel.group(1)!),
  );
}

/// Günstigstes zuerst; Angebote ohne erkannte Summe ans Ende.
List<AngebotsDaten> angeboteVergleichen(List<Brief> briefe) {
  final l = briefe.map(angebotLesenAus).toList();
  l.sort((a, b) {
    if (a.summe == null) return b.summe == null ? 0 : 1;
    if (b.summe == null) return -1;
    return a.summe!.compareTo(b.summe!);
  });
  return l;
}

/// Hinweise zum Vergleich in einfachen Sätzen.
List<String> vergleichHinweise(List<AngebotsDaten> l, {DateTime? heute}) {
  final h = heute ?? DateTime.now();
  final tag = DateTime(h.year, h.month, h.day);
  final mit = l.where((a) => a.summe != null).toList();
  final out = <String>[];
  if (mit.length >= 2) {
    final diff = mit.last.summe! - mit.first.summe!;
    final proz = mit.first.summe! > 0 ? diff / mit.first.summe! * 100 : 0;
    out.add('Zwischen günstigstem und teuerstem Angebot liegen ${_e(diff)} (${proz.round()} %).');
    if (proz >= 30) {
      out.add('Der Unterschied ist groß. Prüfe, ob alle dasselbe anbieten (Menge, Material, Entsorgung, Anfahrt).');
    }
  }
  for (final a in l.where((a) => a.summe == null)) {
    out.add('${a.anbieter}: Endbetrag nicht erkannt – bitte im Angebot nachsehen.');
  }
  for (final a in l.where((a) => a.gueltigBis != null)) {
    final rest = a.gueltigBis!.difference(tag).inDays;
    if (rest < 0) {
      out.add('${a.anbieter}: Angebot ist seit ${_d(a.gueltigBis!)} abgelaufen – neu anfragen.');
    } else if (rest <= 7) {
      out.add('${a.anbieter}: gilt nur noch bis ${_d(a.gueltigBis!)}.');
    }
  }
  for (final a in l.where((a) => a.skonto != null && a.summe != null)) {
    out.add('${a.anbieter}: ${_p(a.skonto!)} % Skonto – bei schneller Zahlung ${_e(a.summe! * (1 - a.skonto! / 100))}.');
  }
  if (l.length < 3) out.add('Tipp: Mit drei Angeboten siehst du besser, was ein fairer Preis ist.');
  return out;
}

/// Anfrage an die KI: Vergleichstabelle mit Leistungsumfang.
String angebotsvergleichAnfrage(List<Brief> briefe) {
  final b = StringBuffer('''
Vergleiche die folgenden ${briefe.length} Angebote. Antworte auf Deutsch, einfach und kurz, sprich den Leser mit „du“ an.

Antworte in diesem Format:
ÜBERSICHT:
- <Anbieter>: <Endbetrag> – <was enthalten ist, in wenigen Worten>
UNTERSCHIEDE IM UMFANG:
- <was ein Angebot enthält und ein anderes nicht, z. B. Material, Entsorgung, Anfahrt, Gewährleistung, Lieferzeit>
UNKLAR ODER FEHLT:
- <was du beim Anbieter nachfragen solltest>
EINSCHÄTZUNG:
<2 bis 3 Sätze, welches Angebot für den Preis am meisten bietet und warum. Kein Rat, nur eine Einschätzung.>

Übernimm Beträge und Daten genau. Erfinde nichts. Wenn ein Wert fehlt, schreibe „nicht angegeben“.
''');
  var i = 1;
  for (final x in briefe) {
    final t = x.text.length > 2200 ? '${x.text.substring(0, 2200)} …' : x.text;
    b.write('\nAngebot ${i++} („${titelVon(x)}“):\n"""\n$t\n"""\n');
  }
  return b.toString();
}

/// Ist das Schreiben wahrscheinlich ein Angebot oder Kostenvoranschlag?
bool istAngebot(Brief b) => RegExp(r'angebot|kostenvoranschlag|kostenschätzung|offerte|preisangebot', caseSensitive: false)
    .hasMatch('${b.titel ?? ''} ${b.kiArt ?? ''} ${b.text.length > 800 ? b.text.substring(0, 800) : b.text}');

String _e(double v) {
  final s = v.toStringAsFixed(2).split('.');
  final ganz = s[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '$ganz,${s[1]} €';
}

String _p(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
