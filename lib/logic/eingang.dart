/// Posteingang: für jedes neue Schreiben genau ein nächster Schritt. Reines Dart, testbar.
library;

import '../data/models.dart';
import 'behoerden.dart';
import 'ordnung.dart';
import 'zeitplan.dart';
import 'format.dart';

class Schritt {
  const Schritt(this.art, this.label, this.text);

  /// widerspruch, bezahlen, unterlagen, antworten, termin, pruefen, ablegen
  final String art;

  /// Beschriftung des Knopfs.
  final String label;

  /// Kurze Begründung.
  final String text;
}

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';
String _e(double b) => '${euroBetrag(b)}';

/// Der wichtigste nächste Schritt für einen Brief.
Schritt naechsterSchritt(Brief b, {DateTime? heute}) {
  final h = heute ?? DateTime.now();
  final rb = (b.typ == 'bescheid' || b.typ == 'mahnbescheid' || b.typ == 'rentenbescheid')
      ? rechtsbehelfFinden(b.text, briefDatum: b.briefDatum)
      : null;
  final zahlen = b.betrag != null && !b.guthaben && b.bezahltAm == null;
  if (b.typ == 'mahnbescheid') {
    return const Schritt('widerspruch', 'Widerspruch prüfen', 'Gerichtlicher Mahnbescheid – 2 Wochen Frist');
  }
  if (b.typ == 'anhoerung') return const Schritt('antworten', 'Antworten', 'Du darfst dich äußern, bevor entschieden wird');
  if (b.typ == 'mitwirkung') {
    return Schritt('unterlagen', 'Unterlagen schicken', b.frist == null ? 'Es werden Unterlagen verlangt' : 'Bis ${_d(b.frist!)}');
  }
  if (zahlen && (b.typ == 'rechnung' || b.typ == 'mahnung' || b.typ == 'abrechnung' || b.frist != null)) {
    return Schritt('bezahlen', 'Bezahlen', '${_e(b.betrag!)}${b.frist == null ? '' : ' bis ${_d(b.frist!)}'}');
  }
  if (rb?.fristEnde != null && !rb!.fristEnde!.isBefore(DateTime(h.year, h.month, h.day))) {
    return Schritt('widerspruch', '${rb.art} prüfen', 'Frist bis ${_d(rb.fristEnde!)}, falls du nicht einverstanden bist');
  }
  final termine = termineFinden(b.text).where((t) => t.zeit.isAfter(h)).toList();
  if (termine.isNotEmpty) return Schritt('termin', 'Termin eintragen', 'Am ${_d(termine.first.zeit)} um ${termine.first.zeit.hour}:${termine.first.zeit.minute.toString().padLeft(2, '0')} Uhr');
  if (b.typ == 'erhoehung') return const Schritt('pruefen', 'Kündigen prüfen', 'Bei Preiserhöhung oft Sonderkündigungsrecht');
  if (b.frist != null) return Schritt('antworten', 'Erledigen', 'Frist ${_d(b.frist!)}');
  return const Schritt('ablegen', 'Ablegen', 'Nur zur Information');
}

/// Neue, noch nicht erledigte Post der letzten [tage] Tage – Dringendes zuerst.
List<Brief> posteingang(List<Brief> briefe, {required DateTime heute, int tage = 30}) {
  final grenze = heute.subtract(Duration(days: tage));
  final l = briefe.where((b) => !b.erledigt && b.erstellt.isAfter(grenze)).toList();
  int rang(Brief b) => switch (dringlichkeit(b)) { Dringlichkeit.hoch => 0, Dringlichkeit.mittel => 1, _ => 2 };
  l.sort((a, c) {
    final r = rang(a).compareTo(rang(c));
    return r != 0 ? r : (a.frist ?? DateTime(9999)).compareTo(c.frist ?? DateTime(9999));
  });
  return l;
}
