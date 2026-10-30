/// „Heute erledigen“: Hinweise aus Alltag, Karriere, Stempeluhr und Datensicherung, die
/// nicht in den Fristen stehen. Reines Dart, testbar.
library;

import '../data/alltag.dart';
import '../data/geschaeft.dart';
import '../data/karriere.dart';
import 'alltag.dart';
import 'karriere.dart';

class Hinweis {
  Hinweis(this.art, this.titel, this.text, {this.ref = ''});

  /// vorrat, hausaufgabe, bewerbung, bewerbungsfrist, weiterbildung, stempel, sicherung
  final String art;
  final String titel;
  final String text;
  final String ref;
}

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

List<Hinweis> heuteHinweise({
  required Alltag alltag,
  required Karriere karriere,
  required List<Stempel> stempel,
  required DateTime? letzteSicherung,
  required bool hatDaten,
  required DateTime jetzt,
}) {
  final heute = _tag(jetzt);
  final in3 = heute.add(const Duration(days: 3));
  final out = <Hinweis>[];
  for (final s in stempel) {
    if (jetzt.difference(s.start).inHours >= 10) {
      out.add(Hinweis('stempel', '${s.person}: Stempeluhr läuft noch', 'Seit über 10 Stunden – Feierabend vergessen?'));
    }
  }
  final bald = laeuftBaldAb(alltag.vorraete, heute: heute, tage: 1);
  if (bald.isNotEmpty) {
    out.add(Hinweis('vorrat', 'Verbrauchen: ${bald.map((v) => v.name).take(3).join(', ')}', 'Läuft heute oder morgen ab'));
  }
  for (final a in alltag.hausaufgaben.where((a) => hausaufgabeFaellig(a, heute: heute) && a.zuletzt != null)) {
    final wer = werIstDran(a);
    out.add(Hinweis('hausaufgabe', a.text, wer == null ? 'Ist wieder dran' : '$wer ist dran', ref: a.text));
  }
  for (final b in karriere.bewerbungen) {
    if (nachfassenFaellig(b, heute: heute)) {
      out.add(Hinweis('bewerbung', 'Bei ${b.firma} nachfragen?', 'Seit 2 Wochen keine Antwort auf „${b.stelle}“', ref: b.id));
    } else if (b.beworbenAm == null && b.frist != null && !b.frist!.isBefore(heute) && !b.frist!.isAfter(in3) && b.status == 'Gemerkt') {
      out.add(Hinweis('bewerbungsfrist', 'Bewerbung an ${b.firma}', 'Frist endet bald – Unterlagen fertig machen', ref: b.id));
    }
  }
  for (final w in karriere.weiterbildungen) {
    if (w.status == 'Geplant' && w.anmeldungBis != null && !w.anmeldungBis!.isBefore(heute) && !w.anmeldungBis!.isAfter(in3)) {
      out.add(Hinweis('weiterbildung', 'Anmelden: ${w.titel}', 'Anmeldeschluss in wenigen Tagen', ref: w.id));
    }
  }
  if (hatDaten && (letzteSicherung == null || heute.difference(_tag(letzteSicherung)).inDays > 30)) {
    out.add(Hinweis('sicherung', 'Daten sichern',
        letzteSicherung == null ? 'Noch nie gesichert – dauert eine Minute' : 'Letzte Sicherung ist über einen Monat her'));
  }
  return out;
}
