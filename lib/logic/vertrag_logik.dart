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
