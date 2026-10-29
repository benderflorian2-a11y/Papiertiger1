/// Antrags-Helfer: Vorbelegung aus dem Profil, gespeicherte Angaben, Nachfragen.
library;

import '../data/models.dart';
import 'formular.dart';
import 'inhalte.dart';

String antragSchluessel(AntragsHelfer a, int frage) => 'antrag:${a.key}:$frage';
String antragGestelltSchluessel(AntragsHelfer a) => 'antrag:${a.key}:gestellt';

/// Nur Fragen zur eigenen Person („Dein …“, „Deine …“) werden aus dem Profil vorbelegt,
/// damit z. B. „Name des Kindes“ nie mit deinem Namen gefüllt wird.
String? antragVorbelegen(String frage, Profil p) =>
    RegExp(r'^Deine?\s').hasMatch(frage) ? profilWert(frage, p) : null;

/// Gespeicherte Antwort, sonst Vorbelegung aus dem Profil.
String antragAntwort(AntragsHelfer a, int i, Map<String, String> notizen, Profil p) =>
    notizen[antragSchluessel(a, i)] ?? antragVorbelegen(a.fragen[i], p) ?? '';

String antragAlsText(AntragsHelfer a, Map<String, String> notizen, Profil p) {
  final z = StringBuffer('${a.titel} – meine Angaben\n');
  for (var i = 0; i < a.fragen.length; i++) {
    final w = antragAntwort(a, i, notizen, p);
    z.write('\n${a.fragen[i]}\n${w.isEmpty ? '–' : w}\n');
  }
  z.write('\nZuständig: ${a.stelle}\n${a.wo}\n');
  return z.toString();
}

/// Termin zum Nachfragen, wenn nach einigen Wochen noch kein Bescheid da ist.
Termin antragNachfragen(AntragsHelfer a, DateTime gestellt) => Termin(
      id: 'antrag-${a.key}-${gestellt.millisecondsSinceEpoch}',
      titel: '${a.titel}: Stand nachfragen',
      datum: DateTime(gestellt.year, gestellt.month, gestellt.day + 7 * a.nachfragenWochen, 9),
      art: 'Behörde',
      notiz: 'Antrag gestellt am ${gestellt.day}.${gestellt.month}.${gestellt.year}. '
          'Noch kein Bescheid? Dann bei der ${a.stelle} nach dem Stand fragen.',
    );

class AntragsStand {
  AntragsStand(this.offeneFragen, this.fehlendeUnterlagen);

  final List<String> offeneFragen;
  final List<String> fehlendeUnterlagen;

  bool get vollstaendig => offeneFragen.isEmpty && fehlendeUnterlagen.isEmpty;
}

/// Prüft, ob alle Fragen beantwortet und alle Unterlagen abgehakt sind.
AntragsStand antragPruefen(AntragsHelfer a, Map<String, String> notizen, Profil p, Map<String, bool> checklisten) =>
    AntragsStand(
      [for (var i = 0; i < a.fragen.length; i++) if (antragAntwort(a, i, notizen, p).trim().isEmpty) a.fragen[i]],
      [for (var i = 0; i < a.unterlagen.length; i++) if (checklisten['antrag:${a.key}:$i'] != true) a.unterlagen[i]],
    );
