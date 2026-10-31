/// Änderungsprotokoll (GoBD): wer hat wann was an Rechnungen und Einstellungen geändert.
/// Die Einträge sind verkettet – wird einer nachträglich geändert oder gelöscht, fällt das auf.
library;

import 'dart:convert';

import 'package:cryptography/dart.dart';

import '../data/geschaeft.dart';

class ProtokollEintrag {
  ProtokollEintrag({required this.zeit, required this.art, required this.objekt, required this.text, required this.hash});

  final DateTime zeit;

  /// z. B. 'erstellt', 'geaendert', 'geloescht', 'storniert', 'warnung', 'sicherheit'.
  final String art;

  /// z. B. 'Rechnung 2026-001'.
  final String objekt;
  final String text;
  final String hash;

  Map<String, dynamic> toJson() => {'zeit': zeit.toIso8601String(), 'art': art, 'objekt': objekt, 'text': text, 'hash': hash};

  factory ProtokollEintrag.fromJson(Map<String, dynamic> j) => ProtokollEintrag(
        zeit: DateTime.tryParse(j['zeit'] as String? ?? '') ?? DateTime(2000),
        art: j['art'] as String? ?? '',
        objekt: j['objekt'] as String? ?? '',
        text: j['text'] as String? ?? '',
        hash: j['hash'] as String? ?? '',
      );
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String eintragHash(String vorher, DateTime zeit, String art, String objekt, String text) =>
    _hex(const DartSha256().hashSync(utf8.encode('$vorher|${zeit.toIso8601String()}|$art|$objekt|$text')).bytes);

void protokollieren(List<ProtokollEintrag> l, {required String art, required String objekt, required String text, DateTime? zeit}) {
  final z = zeit ?? DateTime.now();
  final vorher = l.isEmpty ? '' : l.last.hash;
  l.add(ProtokollEintrag(zeit: z, art: art, objekt: objekt, text: text, hash: eintragHash(vorher, z, art, objekt, text)));
}

/// Index des ersten Eintrags, der nicht zur Kette passt; null, wenn alles stimmt.
int? protokollBruch(List<ProtokollEintrag> l) {
  var vorher = '';
  for (var i = 0; i < l.length; i++) {
    final e = l[i];
    if (eintragHash(vorher, e.zeit, e.art, e.objekt, e.text) != e.hash) return i;
    vorher = e.hash;
  }
  return null;
}

const _felder = {
  'nummer': 'Nummer',
  'kundeId': 'Kunde',
  'datum': 'Datum',
  'leistungVon': 'Leistungszeitraum',
  'leistungBis': 'Leistungszeitraum',
  'positionen': 'Positionen',
  'zahlungszielTage': 'Zahlungsziel',
  'notiz': 'Notiz',
  'rabattProzent': 'Rabatt',
  'rabattBetrag': 'Rabatt',
  'art': 'Belegart',
  'bezahltAm': 'Zahlung',
  'gemahntAm': 'Mahnung',
  'mahnstufe': 'Mahnstufe',
  'versendetAm': 'Versand',
  'festAm': 'Festschreibung',
  'storniert': 'Storno',
  'wiederholungMonate': 'Wiederholung',
  'projektId': 'Projekt',
  'bezugId': 'Bezug',
};

/// Felder, die nach der Festschreibung nicht mehr geändert werden dürfen.
const _inhalt = {'nummer', 'kundeId', 'datum', 'leistungVon', 'leistungBis', 'positionen', 'rabattProzent', 'rabattBetrag', 'art'};

/// Vergleicht den letzten gespeicherten Stand der Rechnungen mit dem jetzigen und liefert Protokolleinträge
/// (art, objekt, text). [vorher]: id → JSON-Text.
List<(String, String, String)> rechnungsAenderungen(Map<String, String> vorher, List<Rechnung> jetzt) {
  final out = <(String, String, String)>[];
  final ids = <String>{};
  for (final r in jetzt) {
    ids.add(r.id);
    final neu = jsonEncode(r.toJson());
    final alt = vorher[r.id];
    final objekt = '${r.artName} ${r.nummer}';
    if (alt == null) {
      out.add(('erstellt', objekt, 'angelegt'));
      continue;
    }
    if (alt == neu) continue;
    final a = jsonDecode(alt) as Map<String, dynamic>, n = r.toJson();
    final geaendert = <String>{
      for (final k in {...a.keys, ...n.keys})
        if (jsonEncode(a[k]) != jsonEncode(n[k])) k,
    };
    if (geaendert.isEmpty) continue;
    final warFest = Rechnung.fromJson(a).festgeschrieben;
    final namen = {for (final k in geaendert) _felder[k] ?? k}.join(', ');
    if (warFest && geaendert.any(_inhalt.contains)) {
      out.add(('warnung', objekt, 'nach der Festschreibung geändert: $namen'));
    } else if (geaendert.contains('storniert') && r.storniert) {
      out.add(('storniert', objekt, 'storniert'));
    } else if (geaendert.contains('bezahltAm') && r.bezahltAm != null) {
      out.add(('geaendert', objekt, 'als bezahlt vermerkt'));
    } else if (geaendert.contains('versendetAm') && r.versendetAm != null) {
      out.add(('geaendert', objekt, 'als verschickt vermerkt'));
    } else if (geaendert.length == 1 && geaendert.contains('festAm') && r.festAm != null) {
      out.add(('geaendert', objekt, 'festgeschrieben'));
    } else {
      out.add(('geaendert', objekt, '$namen geändert'));
    }
  }
  for (final e in vorher.entries) {
    if (ids.contains(e.key)) continue;
    final r = Rechnung.fromJson(jsonDecode(e.value) as Map<String, dynamic>);
    out.add((r.festgeschrieben ? 'warnung' : 'geloescht', '${r.artName} ${r.nummer}',
        r.festgeschrieben ? 'festgeschriebene Rechnung gelöscht' : 'gelöscht'));
  }
  return out;
}

String protokollCsv(List<ProtokollEintrag> l) {
  String q(String s) => '"${s.replaceAll('"', '""')}"';
  return [
    'Zeit;Art;Beleg;Vorgang;Prüfwert',
    for (final e in l) [q(e.zeit.toIso8601String()), q(e.art), q(e.objekt), q(e.text), q(e.hash)].join(';'),
  ].join('\n');
}
