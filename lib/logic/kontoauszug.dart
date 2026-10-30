/// Kontoauszug lesen (Text aus PDF oder kopiert), wiederkehrende und doppelte
/// Abbuchungen erkennen. Ohne Bankzugang, nur aus dem, was du importierst.
library;

import '../data/geschaeft.dart';
import '../data/models.dart';
import 'rechnungen.dart';

class Abbuchung {
  Abbuchung({required this.empfaenger, required this.betrag, required this.datum});

  final String empfaenger;

  /// Immer positiv (abgebuchter Betrag).
  final double betrag;
  final DateTime datum;
}

final _datumRe = RegExp(r'(?<!\d)(\d{1,2})\.(\d{1,2})\.(\d{4}|\d{2})?(?!\d)');
// Betrag mit Minus vorne oder hinten bzw. „S“ (Soll) dahinter, z. B. -39,99 · 39,99- · 1.234,50 S
final _betragRe = RegExp(r'(-\s?)?(\d{1,3}(?:\.\d{3})*,\d{2})\s*(-|S\b)?(?:\s*(?:EUR|€))?');
const _buchungsWoerter = [
  'sepa', 'basislastschrift', 'folgelastschrift', 'erstlastschrift', 'lastschrift', 'dauerauftrag', 'kartenzahlung',
  'kartenumsatz', 'überweisung', 'ueberweisung', 'abbuchung', 'einzug', 'girocard', 'debitkarte', 'visa', 'mastercard',
  'online-überweisung', 'eur', 'buchung', 'wert', 'valuta', 'core',
];

double _zahl(String s) => double.parse(s.replaceAll('.', '').replaceAll(',', '.'));

String _empfaengerAus(String zeile) {
  var t = zeile.replaceAll(_datumRe, ' ').replaceAll(_betragRe, ' ');
  t = t
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_buchungsWoerter.contains(w.toLowerCase()) && !RegExp(r'^[\d.,/:-]+$').hasMatch(w))
      .join(' ');
  return t.trim();
}

class _Buchung {
  _Buchung(this.name, this.betrag, this.soll, this.datum, this.text);
  final String name;
  final double betrag;
  final bool soll;
  final DateTime datum;

  /// Ganze Buchung inkl. Verwendungszweck aus der Folgezeile.
  final String text;
}

final _saldoRe = RegExp(r'saldo|kontostand|alter stand|neuer stand|summe', caseSensitive: false);

List<_Buchung> _buchungen(String text, int jahr) {
  final zeilen = text.split('\n').map((z) => z.trim()).toList();
  final out = <_Buchung>[];
  for (var i = 0; i < zeilen.length; i++) {
    var z = zeilen[i];
    final d = _datumRe.firstMatch(z);
    if (d == null || _saldoRe.hasMatch(z)) continue;
    final folge = i + 1 < zeilen.length && _datumRe.firstMatch(zeilen[i + 1]) == null ? zeilen[i + 1] : '';
    var betraege = _betragRe.allMatches(z).toList();
    // Manche Banken schreiben Empfänger und Betrag in die Zeile darunter.
    if (betraege.isEmpty && folge.isNotEmpty) {
      z = '$z $folge';
      betraege = _betragRe.allMatches(z).toList();
    }
    if (betraege.isEmpty) continue;
    final b = betraege.last;
    final soll = b.group(1) != null || b.group(3) != null;
    final j = d.group(3) == null ? jahr : (d.group(3)!.length == 2 ? 2000 + int.parse(d.group(3)!) : int.parse(d.group(3)!));
    final tag = int.parse(d.group(1)!), monat = int.parse(d.group(2)!);
    if (monat < 1 || monat > 12 || tag < 1 || tag > 31) continue;
    var name = _empfaengerAus(z);
    if (name.length < 3 && folge.isNotEmpty) name = _empfaengerAus(folge);
    if (name.length < 3) continue;
    out.add(_Buchung(name, _zahl(b.group(2)!), soll, DateTime(j, monat, tag), z.contains(folge) ? z : '$z $folge'));
  }
  return out;
}

/// Liest Abbuchungen aus dem Text eines Kontoauszugs. Gutschriften (ohne Minus) werden übersprungen.
/// Steht der Empfänger nicht in der Zeile mit dem Betrag, wird die nächste Zeile genommen.
List<Abbuchung> abbuchungenLesen(String text, {DateTime? heute}) => [
      for (final b in _buchungen(text, (heute ?? DateTime.now()).year))
        if (b.soll) Abbuchung(empfaenger: b.name, betrag: b.betrag, datum: b.datum),
    ];

class Gutschrift {
  Gutschrift({required this.von, required this.betrag, required this.datum, required this.text});

  final String von;
  final double betrag;
  final DateTime datum;

  /// Buchungstext mit Verwendungszweck.
  final String text;
}

/// Zahlungseingänge (Beträge ohne Minus), Kontostand-Zeilen ausgenommen.
List<Gutschrift> gutschriftenLesen(String text, {DateTime? heute}) => [
      for (final b in _buchungen(text, (heute ?? DateTime.now()).year))
        if (!b.soll) Gutschrift(von: b.name, betrag: b.betrag, datum: b.datum, text: b.text),
    ];

String _kompakt(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Ordnet Zahlungseingänge offenen Rechnungen zu: zuerst über die Rechnungsnummer im
/// Verwendungszweck, sonst über den genauen Betrag (nur wenn er eindeutig ist).
/// Jede Gutschrift wird höchstens einmal verwendet. Es wird nichts automatisch verbucht.
List<(Rechnung, Gutschrift, String)> zahlungenZuordnen(List<Rechnung> rechnungen, List<Gutschrift> eingaenge,
    {required bool kleinunternehmer}) {
  final offen = rechnungen.where(istOffen).toList();
  final frei = [...eingaenge];
  final out = <(Rechnung, Gutschrift, String)>[];
  for (final r in [...offen]) {
    final nr = _kompakt(r.nummer);
    if (nr.length < 3) continue;
    final g = frei.where((g) => _kompakt(g.text).contains(nr)).firstOrNull;
    if (g == null) continue;
    out.add((r, g, 'Rechnungsnummer im Verwendungszweck'));
    frei.remove(g);
    offen.remove(r);
  }
  for (final r in offen) {
    int cent(Rechnung x) => (zuZahlen(x, rechnungen, kleinunternehmer: kleinunternehmer).brutto * 100).round();
    final brutto = cent(r);
    final gleich = offen.where((x) => cent(x) == brutto).length;
    final passend = frei.where((g) => (g.betrag * 100).round() == brutto && !g.datum.isBefore(r.datum)).toList();
    if (gleich != 1 || passend.length != 1) continue;
    out.add((r, passend.single, 'gleicher Betrag'));
    frei.remove(passend.single);
  }
  return out;
}

/// Schlüssel für „derselbe Empfänger“: die ersten zwei Wörter, nur Buchstaben.
String empfaengerSchluessel(String name) => name
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .map((w) => w.replaceAll(RegExp(r'[^a-zäöüß]'), ''))
    .where((w) => w.length > 1 && !const ['gmbh', 'ag', 'kg', 'se', 'co', 'mbh', 'ev', 'und'].contains(w))
    .take(2)
    .join(' ');

class Wiederkehrend {
  Wiederkehrend({required this.empfaenger, required this.buchungen, required this.rhythmusMonate, this.vertrag});

  final String empfaenger;
  final List<Abbuchung> buchungen;

  /// 1 = monatlich, 3 = vierteljährlich, 12 = jährlich, 0 = wöchentlich/unklar.
  final int rhythmusMonate;

  /// Passender Vertrag, falls schon erfasst.
  final Vertrag? vertrag;

  double get letzterBetrag => buchungen.last.betrag;
  bool get preisGeaendert => buchungen.map((b) => b.betrag).toSet().length > 1;
  double get proMonat => rhythmusMonate <= 0 ? letzterBetrag * 4.33 : letzterBetrag / rhythmusMonate;

  String get rhythmus => switch (rhythmusMonate) {
        1 => 'monatlich',
        3 => 'vierteljährlich',
        6 => 'halbjährlich',
        12 => 'jährlich',
        0 => 'wöchentlich',
        _ => 'alle $rhythmusMonate Monate',
      };
}

int? _rhythmus(double tage) {
  if (tage >= 5 && tage <= 9) return 0;
  if (tage >= 25 && tage <= 36) return 1;
  if (tage >= 80 && tage <= 100) return 3;
  if (tage >= 170 && tage <= 195) return 6;
  if (tage >= 350 && tage <= 380) return 12;
  return null;
}

/// Empfänger, die regelmäßig abbuchen (mindestens zweimal, gleichmäßiger Abstand).
/// Kleine Preisänderungen sind erlaubt; Einkäufe mit stark schwankenden Beträgen nicht.
List<Wiederkehrend> wiederkehrendeAbbuchungen(List<Abbuchung> l, {List<Vertrag> vertraege = const []}) {
  final gruppen = <String, List<Abbuchung>>{};
  for (final a in l) {
    final k = empfaengerSchluessel(a.empfaenger);
    if (k.isEmpty) continue;
    gruppen.putIfAbsent(k, () => []).add(a);
  }
  final out = <Wiederkehrend>[];
  for (final e in gruppen.entries) {
    final g = e.value..sort((a, b) => a.datum.compareTo(b.datum));
    if (g.length < 2) continue;
    final betraege = g.map((a) => a.betrag).toList()..sort();
    if (betraege.last > betraege.first * 1.25 + 1) continue; // schwankt zu stark: eher Einkäufe
    final abstaende = [
      for (var i = 1; i < g.length; i++) g[i].datum.toUtc().difference(g[i - 1].datum.toUtc()).inHours / 24,
    ];
    final mittel = abstaende.reduce((a, b) => a + b) / abstaende.length;
    final r = _rhythmus(mittel);
    if (r == null) continue;
    final wort = e.key.split(' ').first;
    Vertrag? v;
    for (final x in vertraege) {
      if (!x.gekuendigt && x.anbieter.toLowerCase().contains(wort)) v = x;
    }
    out.add(Wiederkehrend(empfaenger: g.last.empfaenger, buchungen: g, rhythmusMonate: r, vertrag: v));
  }
  out.sort((a, b) => b.proMonat.compareTo(a.proMonat));
  return out;
}

/// Gleicher Empfänger, gleicher Betrag innerhalb weniger Tage: vielleicht doppelt abgebucht.
List<(Abbuchung, Abbuchung)> doppelteAbbuchungen(List<Abbuchung> l, {int tage = 3}) {
  final s = [...l]..sort((a, b) => a.datum.compareTo(b.datum));
  final out = <(Abbuchung, Abbuchung)>[];
  for (var i = 0; i < s.length; i++) {
    for (var j = i + 1; j < s.length; j++) {
      if (s[j].datum.difference(s[i].datum).inDays > tage) break;
      if (s[i].betrag == s[j].betrag && empfaengerSchluessel(s[i].empfaenger) == empfaengerSchluessel(s[j].empfaenger)) {
        out.add((s[i], s[j]));
      }
    }
  }
  return out;
}
