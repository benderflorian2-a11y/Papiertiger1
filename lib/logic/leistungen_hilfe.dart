/// Aus „Was steht mir zu?“ ein fertiges Antragsschreiben machen – mit den Angaben aus dem Profil.
/// Allgemeiner Entwurf: Maßgeblich sind die Formulare und Vorgaben der zuständigen Stelle.
library;

import '../data/models.dart';
import 'inhalte.dart';

const _fehlt = '[bitte ergänzen]';

/// Gründe, die aus den Antworten in „Was steht mir zu?“ stammen.
const _gruende = <String, String>{
  'kinder': 'In meinem Haushalt lebt ein Kind unter 25 Jahren.',
  'baby': 'Ich erwarte ein Kind bzw. mein Kind ist jünger als 14 Monate.',
  'allein': 'Ich bin alleinerziehend.',
  'miete': 'Mein Einkommen ist knapp, sodass Miete und Lebenshaltung schwer zu bezahlen sind.',
  'arbeitslos': 'Ich bin derzeit ohne Arbeit.',
  'ausbildung': 'Ich befinde mich in Ausbildung bzw. im Studium.',
  'rente': 'Ich bin in Rente bzw. im Rentenalter.',
  'pflege': 'Ich pflege einen Angehörigen bzw. bin selbst pflegebedürftig.',
  'behinderung': 'Ich habe eine Behinderung bzw. eine chronische Erkrankung.',
  'schwanger': 'Ich bin schwanger.',
  'krank': 'Ich bin längere Zeit krank bzw. in laufender Behandlung.',
};

/// Welche Angaben im Schreiben noch fehlen (damit der Nutzer sie im Profil ergänzen kann).
List<String> leistungsAngabenFehlen(Profil p) => [
      if (p.name.trim().isEmpty) 'Name',
      if (p.adresse.trim().isEmpty) 'Anschrift',
      if ((p.extra['geburtsdatum'] ?? '').trim().isEmpty) 'Geburtsdatum',
    ];

/// Antragsschreiben für eine Leistung. [antworten] sind die Ja/Nein-Antworten aus „Was steht mir zu?“.
String leistungsSchreiben(Leistung l, Profil p, Map<String, bool> antworten, {required DateTime heute}) {
  String angabe(String? v) => (v ?? '').trim().isEmpty ? _fehlt : v!.trim();
  final tag = '${heute.day.toString().padLeft(2, '0')}.${heute.month.toString().padLeft(2, '0')}.${heute.year}';
  final gruende = [for (final e in _gruende.entries) if (antworten[e.key] == true) e.value];
  final z = StringBuffer()
    ..writeln(angabe(p.name))
    ..writeln(angabe(p.adresse.replaceAll('\n', ', ')))
    ..writeln()
    ..writeln(l.stelle)
    ..writeln()
    ..writeln('Datum: $tag')
    ..writeln()
    ..writeln('Antrag auf ${l.titel}')
    ..writeln()
    ..writeln('Sehr geehrte Damen und Herren,')
    ..writeln()
    ..writeln('hiermit beantrage ich ${l.titel}.')
    ..writeln();
  if (gruende.isNotEmpty) {
    z.writeln('Zu meiner Situation:');
    for (final g in gruende) {
      z.writeln('- $g');
    }
    z.writeln();
  }
  z
    ..writeln('Meine Angaben:')
    ..writeln('- Name: ${angabe(p.name)}')
    ..writeln('- Anschrift: ${angabe(p.adresse.replaceAll('\n', ', '))}')
    ..writeln('- Geburtsdatum: ${angabe(p.extra['geburtsdatum'])}');
  final steuerId = (p.extra['steuerid'] ?? '').trim();
  if (steuerId.isNotEmpty) z.writeln('- Steuer-ID: $steuerId');
  final iban = (p.extra['iban'] ?? '').trim();
  if (iban.isNotEmpty) z.writeln('- Bankverbindung (IBAN): $iban');
  z
    ..writeln()
    ..writeln('Bitte bestätigen Sie mir den Eingang dieses Antrags schriftlich und teilen Sie mir mit, '
        'welche Unterlagen Sie von mir noch benötigen. Ich bitte um einen schriftlichen Bescheid.')
    ..writeln()
    ..writeln('Mit freundlichen Grüßen')
    ..writeln()
    ..writeln(angabe(p.name))
    ..writeln()
    ..writeln('Anlagen: [bitte ergänzen, z. B. Einkommensnachweise, Ausweiskopie]');
  return z.toString();
}

/// Der Weg zur Leistung in vier Schritten – für jede Leistung gleich verständlich.
const leistungsSchritte = [
  'Unterlagen zusammensuchen (Ausweis, Einkommensnachweise, Bescheinigungen).',
  'Antrag bei der genannten Stelle stellen – online, per Post oder vor Ort. Stell ihn möglichst früh: Vieles gilt erst ab dem Antrag.',
  'Eingang schriftlich bestätigen lassen und das Datum notieren.',
  'Kommt ein Ablehnungsbescheid, kannst du innerhalb eines Monats Widerspruch einlegen. Scanne den Bescheid im Papiertiger, der Tiger rechnet die Frist aus.',
];
